-- BlockCraft — песочница по образцу Minecraft Java 1.16.5 (Nether Update), со своей графикой и системными звуками.
-- Выживание (здоровье, голод, падение, лава, ночь с монстрами) и творческий режим, инвентарь, верстак и печь,
-- инструменты от дерева до незерита, портал в Незер с пиглинами и хоглинами, бартер за золото, день и ночь.
-- Модули: Content (блоки, предметы, рецепты), Terrain (генерация), World (отрисовка, физика), Mobs (мобы).
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local Content = require(script.Content)
local Terrain = require(script.Terrain)
local World = require(script.World)
local Mobs = require(script.Mobs)
local Textures = require(script.Textures)
local Screens = require(script.Screens)

local BLOCKS, ITEMS = Content.BLOCKS, Content.ITEMS
local SX, SZ = Terrain.SX, Terrain.SZ

local BlockCraft = {}

local B = 4 -- блок в студах
local ORIGIN = Vector3.new(-SX * B / 2, 2000, 4000)
local REACH = 4.5
local DAY = 600 -- сутки в секундах (в Minecraft 20 минут)
local RENDER = 3 -- радиус отрисовки в кусках по 8 блоков
local HALF, TALL = 0.3, 1.8
local SAVE_VERSION = 2

local PIXEL = Enum.Font.Arcade -- пиксельный шрифт интерфейса
local S = 3 -- масштаб интерфейса: пиксель Minecraft = 3 точки холста

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

function BlockCraft.launch(ctx)
	local ui, theme = ctx.ui, ctx.theme
	local camera = ctx.camera
	local canvas = ui.canvas(ctx.gui)
	local G = { state = "title", mobs = {}, edits = {}, gens = {}, dirty = false, stats = {}, furnaces = {} }
	BlockCraft.debug = G

	-- ---------------------------------------------------------------- освещение (возвращается при выходе)
	local savedLighting = {
		ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
		GlobalShadows = Lighting.GlobalShadows, EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale, ExposureCompensation = Lighting.ExposureCompensation,
	}
	-- эффекты чиллзоны (свечение, лучи, размытие) в игре выключены: свет как в Minecraft плоский
	local savedEffects = {}
	for _, e in Lighting:GetChildren() do
		if e:IsA("PostEffect") then
			savedEffects[e] = e.Enabled
			e.Enabled = false
		end
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local savedAtmo, ownAtmo
	if atmosphere then
		savedAtmo = { Density = atmosphere.Density, Color = atmosphere.Color, Decay = atmosphere.Decay, Haze = atmosphere.Haze, Glare = atmosphere.Glare, Offset = atmosphere.Offset }
	else
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
		ownAtmo = atmosphere
	end
	local function restoreLighting()
		for k, v in savedLighting do
			Lighting[k] = v
		end
		for e, on in savedEffects do
			if e.Parent then
				e.Enabled = on
			end
		end
		if ownAtmo then
			ownAtmo:Destroy()
		elseif savedAtmo then
			for k, v in savedAtmo do
				atmosphere[k] = v
			end
		end
	end

	local function clockOf(time)
		return (6 + time / DAY * 24) % 24
	end
	local function isDay()
		local c = clockOf(G.time or 0)
		return c > 5.6 and c < 18.6
	end
	local function applyLighting()
		-- солнце не светит (Brightness 0), всё освещает ровный ambient: цвет текстур как есть,
		-- а тени граней, пещер и факелов уже запечены в цвет текстур (World:decorate)
		Lighting.Brightness = 0
		Lighting.GlobalShadows = false
		Lighting.EnvironmentDiffuseScale = 0
		Lighting.EnvironmentSpecularScale = 0
		Lighting.ExposureCompensation = 0
		if G.dim == "nether" then
			Lighting.ClockTime = 0
			Lighting.Ambient = rgb(255, 236, 226)
			Lighting.OutdoorAmbient = rgb(255, 236, 226)
			atmosphere.Density, atmosphere.Offset, atmosphere.Haze, atmosphere.Glare = 0.5, 0, 1.5, 0
			atmosphere.Color, atmosphere.Decay = rgb(120, 34, 24), rgb(60, 12, 8)
		else
			local c = clockOf(G.time or 0)
			local light = math.clamp(math.sin((c - 6) / 12 * math.pi) * 1.6 + 0.3, 0, 1)
			local v = math.floor(255 * (0.3 + 0.7 * light))
			Lighting.ClockTime = c
			Lighting.Ambient = rgb(v, v, math.min(255, v + 12))
			Lighting.OutdoorAmbient = Lighting.Ambient
			atmosphere.Density, atmosphere.Offset, atmosphere.Haze, atmosphere.Glare = 0.22, 0, 0, 0
			atmosphere.Color = rgb(20, 24, 50):Lerp(rgb(192, 216, 255), light)
			atmosphere.Decay = rgb(10, 12, 30):Lerp(rgb(120, 160, 230), light)
		end
	end

	-- ---------------------------------------------------------------- инвентарь
	local inv = {} -- [1..36] = { n = имя, c = количество, d = прочность }; 1..9 — хотбар, 37..40 — броня, 41 — вторая рука
	local selected = 1
	local hud = {}

	local function give(name, count)
		local max = Content.StackSize(name)
		for i = 1, 36 do
			local s = inv[i]
			if count <= 0 then
				break
			end
			if s and s.n == name and s.c < max then
				local add = math.min(count, max - s.c)
				s.c += add
				count -= add
			end
		end
		for i = 1, 36 do
			if count <= 0 then
				break
			end
			if not inv[i] then
				local add = math.min(count, max)
				inv[i] = { n = name, c = add, d = ITEMS[name] and ITEMS[name].durability }
				count -= add
			end
		end
		G.hudDirty = true
		if name == "ancient_debris" then
			ctx.trophies:Unlock("hidden_in_depths")
		elseif name == "diamond" then
			ctx.trophies:Unlock("diamonds")
		elseif name == "iron_ingot" then
			ctx.trophies:Unlock("acquire_hardware")
		elseif ITEMS[name] and ITEMS[name].tool and string.sub(name, 1, 9) == "netherite" then
			ctx.trophies:Unlock("netherite_tool")
		end
		return count
	end

	local function names(tagOrName)
		return Content.TAGS[tagOrName] or { tagOrName }
	end

	local function countOf(tagOrName)
		local total = 0
		for _, n in names(tagOrName) do
			for i = 1, 36 do
				if inv[i] and inv[i].n == n then
					total += inv[i].c
				end
			end
		end
		return total
	end

	local function take(tagOrName, count)
		for _, n in names(tagOrName) do
			for i = 36, 1, -1 do
				local s = inv[i]
				if count > 0 and s and s.n == n then
					local t = math.min(count, s.c)
					s.c -= t
					count -= t
					if s.c <= 0 then
						inv[i] = nil
					end
				end
			end
		end
		G.hudDirty = true
	end

	local function held()
		return inv[selected]
	end

	-- ---------------------------------------------------------------- мир
	local world -- текущее измерение (World)
	local P = {} -- игрок: pos (ноги, в блоках), vel, yaw, pitch, health, food…

	local function coordKey(x, y, z)
		return `{x},{y},{z}`
	end

	local function generate(dim)
		if not G.gens[dim] then
			local gen = dim == "nether" and Terrain.Nether(G.seed) or Terrain.Overworld(G.seed)
			for k, v in G.edits[dim] or {} do
				local x, y, z = string.match(k, "^(%-?%d+),(%-?%d+),(%-?%d+)$")
				if x then
					gen.blocks[Terrain.key(tonumber(x), tonumber(y), tonumber(z))] = v ~= "" and v or nil
				end
			end
			G.gens[dim] = gen
		end
		return G.gens[dim]
	end

	local function setBlock(x, y, z, id)
		if not world:inside(x, y, z) then
			return
		end
		world:set(x, y, z, id)
		G.edits[G.dim] = G.edits[G.dim] or {}
		G.edits[G.dim][coordKey(x, y, z)] = id or ""
		G.dirty = true
	end

	-- песок и гравий падают, вода затекает в пустую клетку
	local function fall(x, y, z)
		for yy = y, world.H - 1 do
			local id = world:get(x, yy, z)
			if not (id and BLOCKS[id].falls) then
				break
			end
			local ty = yy
			while ty > 1 do
				local below = world:get(x, ty - 1, z)
				if below == nil or BLOCKS[below].liquid then
					ty -= 1
				else
					break
				end
			end
			if ty ~= yy then
				setBlock(x, yy, z, nil)
				setBlock(x, ty, z, id)
			end
		end
	end

	local function afterRemove(x, y, z)
		fall(x, y + 1, z)
		if world:get(x, y, z) == nil then
			for _, d in { { 0, 1, 0 }, { 1, 0, 0 }, { -1, 0, 0 }, { 0, 0, 1 }, { 0, 0, -1 } } do
				if world:get(x + d[1], y + d[2], z + d[3]) == "water" then
					setBlock(x, y, z, "water")
					break
				end
			end
		end
		-- без обсидиана портал гаснет
		for _, d in { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } } do
			local id = world:get(x + d[1], y + d[2], z + d[3])
			if id and BLOCKS[id].portal then
				local stack = { { x + d[1], y + d[2], z + d[3] } }
				while #stack > 0 do
					local c = table.remove(stack)
					local cid = world:get(c[1], c[2], c[3])
					if cid and BLOCKS[cid].portal then
						setBlock(c[1], c[2], c[3], nil)
						for _, e in { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } } do
							table.insert(stack, { c[1] + e[1], c[2] + e[2], c[3] + e[3] })
						end
					end
				end
			end
		end
	end

	-- ---------------------------------------------------------------- интерфейс
	local hudRoot = ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = canvas })
	local tint = ui.new("Frame", { Size = UDim2.fromOffset(1920, 1080), BackgroundColor3 = rgb(255, 0, 0), BackgroundTransparency = 1, Parent = hudRoot })
	-- прицел: тонкий крест, как в Minecraft
	ui.new("Frame", { Size = UDim2.fromOffset(10 * S, S), Position = UDim2.fromOffset(960 - 5 * S, 540 - S / 2), BackgroundColor3 = rgb(230, 230, 230), BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = hudRoot })
	ui.new("Frame", { Size = UDim2.fromOffset(S, 10 * S), Position = UDim2.fromOffset(960 - S / 2, 540 - 5 * S), BackgroundColor3 = rgb(230, 230, 230), BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = hudRoot })
	local breakBar = ui.new("Frame", { Size = UDim2.fromOffset(120, 8), Position = UDim2.fromOffset(900, 560), BackgroundColor3 = rgb(0, 0, 0), BackgroundTransparency = 0.4, Visible = false, Parent = hudRoot }, {})
	local breakFill = ui.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = rgb(255, 255, 255), Parent = breakBar }, {})
	local info = ui.text("", { Size = UDim2.fromOffset(900, 120), Position = UDim2.fromOffset(20, 16), TextSize = 22, TextYAlignment = Enum.TextYAlignment.Top, TextStrokeTransparency = 0.4, Visible = false, Parent = hudRoot })
	local toast = ui.text("", { Size = UDim2.fromOffset(1920, 40), Position = UDim2.fromOffset(0, 840), TextSize = 30, Font = PIXEL, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, Parent = hudRoot })
	local coordsLabel = ui.text("", { Size = UDim2.fromOffset(900, 10 * S), Position = UDim2.fromOffset(2 * S, 2 * S), TextSize = 8 * S, Font = PIXEL, TextStrokeTransparency = 0.5, Visible = false, Parent = hudRoot })
	local toastTimer = 0
	local function say(text)
		toast.Text = text
		toast.TextTransparency, toast.TextStrokeTransparency = 0, 0.3
		toastTimer = 2.5
	end

	-- интерфейс в пропорциях Minecraft при масштабе GUI 3 (1 пиксель текстуры = 3 точки холста 1920×1080)
	local SLOT = 20 * S

	-- текст с тенью, как шрифт Minecraft: тёмная копия со сдвигом на один пиксель
	local function shadowText(text, props)
		local holder = ui.new("Frame", { Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint, BackgroundTransparency = 1, Parent = props.Parent })
		local function label(color, offset)
			return ui.text(text, {
				Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(offset, offset), TextSize = props.TextSize, Font = PIXEL, TextColor3 = color,
				TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left, TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
				TextStrokeTransparency = 1, Parent = holder,
			})
		end
		local shadow = label(props.Shadow or rgb(63, 63, 63), props.ShadowOffset or S)
		local main = label(props.TextColor3 or Color3.new(1, 1, 1), 0)
		holder:SetAttribute("Text", text)
		return holder, main, shadow
	end

	-- кубик блока в изометрии, как значки блоков в инвентаре Minecraft: верх светлый, левая грань темнее, правая ещё темнее
	local function cube(parent, id)
		local info = BLOCKS[id]
		if not info or info.shape or info.liquid or info.portal or not Textures.Face(id, "top") then
			return nil
		end
		local vp = ui.new("ViewportFrame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.new(1, 1, 1), LightColor = Color3.new(0, 0, 0), Parent = parent,
		})
		local part = Instance.new("Part")
		part.Anchored = true
		part.Size = Vector3.one
		part.Color = info.color
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = id == "glass" and 0.9 or 0
		for _, f in { { Enum.NormalId.Top, "top", 1 }, { Enum.NormalId.Right, "side", 0.8 }, { Enum.NormalId.Front, "front", 0.6 } } do
			local decal = Instance.new("Decal")
			decal.Face = f[1]
			decal.TextureContent = Textures.Face(id, f[2])
			decal.Color3 = Color3.new(f[3], f[3], f[3])
			decal.Parent = part
		end
		part.Parent = vp
		local cam = Instance.new("Camera")
		cam.FieldOfView = 12
		cam.CFrame = CFrame.lookAt(Vector3.new(1, 0.82, -1).Unit * 10.5, Vector3.zero)
		cam.Parent = vp
		vp.CurrentCamera = cam
		return vp
	end

	local function icon(parent, stack, size)
		local f = ui.new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, Parent = parent })
		if not stack then
			return f
		end
		local data = Content.Info(stack.n)
		local inner = ui.new("Frame", { Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), BackgroundTransparency = 1, Parent = f })
		-- блок — объёмный кубик, предмет — пиксельный спрайт, иначе запасной значок
		local done = data and data.block and cube(inner, stack.n)
		if not done then
			local tex
			if data and data.block then
				tex = Textures.Icon(Textures.Name(stack.n, "front") or stack.n)
			elseif data then
				tex = Textures.Item(stack.n, data)
			end
			if tex then
				ui.new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ImageContent = tex, ResampleMode = Enum.ResamplerMode.Pixelated, Parent = inner })
			elseif data and data.block then
				ui.new("Frame", { Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.05, 0.05), BackgroundColor3 = data.color, Parent = inner }, {
					ui.stroke(Color3.new(0, 0, 0), 1, 0.6),
				})
			elseif data then
				ui.text(data.icon or "?", { Size = UDim2.fromScale(1, 1), TextScaled = true, TextColor3 = data.color, Font = PIXEL, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5, Parent = inner })
			end
		end
		if stack.c and stack.c > 1 then
			shadowText(tostring(stack.c), {
				Size = UDim2.new(1, -2, 0, size * 0.42), Position = UDim2.new(0, 0, 1, -size * 0.42), TextSize = math.floor(size * 0.38),
				TextXAlignment = Enum.TextXAlignment.Right, ShadowOffset = math.max(2, math.floor(size / 24)), Parent = f,
			})
		end
		local maxD = ITEMS[stack.n] and ITEMS[stack.n].durability
		if maxD and stack.d and stack.d < maxD then
			local k = stack.d / maxD
			local bar = ui.new("Frame", { Size = UDim2.new(0.68, 0, 0, size / 10), Position = UDim2.new(0.14, 0, 0.82, 0), BackgroundColor3 = rgb(0, 0, 0), BorderSizePixel = 0, Parent = f })
			ui.new("Frame", { Size = UDim2.new(k, 0, 0.5, 0), BackgroundColor3 = Color3.fromHSV(k / 3, 1, 1), BorderSizePixel = 0, Parent = bar })
		end
		return f
	end

	-- хотбар 182×22, полоса опыта 182×5, сердца и еда по 9 пикселей с шагом 8, как в Minecraft
	local HOTBAR_W = 182 * S
	local hotbarTop = 1080 - 22 * S - 2
	local hotbar = ui.new("Frame", {
		Size = UDim2.fromOffset(HOTBAR_W, 22 * S), Position = UDim2.fromOffset(960 - HOTBAR_W / 2, hotbarTop),
		BackgroundColor3 = rgb(0, 0, 0), BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = hudRoot,
	}, { ui.stroke(rgb(20, 20, 20), S, 0.2) })
	local slotFrames = {}
	for i = 1, 9 do
		slotFrames[i] = ui.new("Frame", {
			Size = UDim2.fromOffset(SLOT, SLOT), Position = UDim2.fromOffset(S + (i - 1) * SLOT, S), BackgroundColor3 = rgb(60, 60, 60), BackgroundTransparency = 0.45, BorderSizePixel = 0, Parent = hotbar,
		}, { ui.stroke(rgb(140, 140, 140), 2, 0.35) })
	end
	local selector = ui.new("Frame", { Size = UDim2.fromOffset(24 * S, 24 * S), BackgroundTransparency = 1, ZIndex = 3, Parent = hotbar }, {
		ui.stroke(rgb(235, 235, 235), S, 0), ui.stroke(rgb(20, 20, 20), 1, 0.2),
	})

	local xpTop = hotbarTop - 3 * S - 5 * S
	local xpBar = ui.new("Frame", { Size = UDim2.fromOffset(HOTBAR_W, 5 * S), Position = UDim2.fromOffset(960 - HOTBAR_W / 2, xpTop), BackgroundColor3 = rgb(16, 16, 16), BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = hudRoot }, {
		ui.stroke(rgb(0, 0, 0), 2, 0.3),
	})
	local xpFill = ui.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = rgb(128, 255, 32), BorderSizePixel = 0, Parent = xpBar })
	local xpLevelHolder
	local function setXpLevel(level)
		if xpLevelHolder then
			xpLevelHolder:Destroy()
			xpLevelHolder = nil
		end
		if level > 0 then
			xpLevelHolder = shadowText(tostring(level), {
				Size = UDim2.fromOffset(200, 10 * S), Position = UDim2.fromOffset(860, xpTop - 7 * S), TextSize = 9 * S, TextColor3 = rgb(128, 255, 32), Shadow = rgb(0, 0, 0),
				TextXAlignment = Enum.TextXAlignment.Center, Parent = hudRoot,
			})
		end
	end

	local barsTop = xpTop - S - 9 * S
	local bars = ui.new("Frame", { Size = UDim2.fromOffset(HOTBAR_W, 9 * S), Position = UDim2.fromOffset(960 - HOTBAR_W / 2, barsTop), BackgroundTransparency = 1, Parent = hudRoot })
	local hearts = ui.text("", { Size = UDim2.fromScale(0.5, 1), TextSize = 26, RichText = true, Parent = bars })
	local food = ui.text("", { Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.5, 0), TextSize = 26, RichText = true, TextXAlignment = Enum.TextXAlignment.Right, Parent = bars })
	-- ряды по 10 пиксельных сердец и окорочков (из спрайта 16×16 вырезается рисунок 9×9); если картинки недоступны, остаются символы
	local function iconRow(right)
		local list = {}
		for i = 1, 10 do
			list[i] = ui.new("ImageLabel", {
				Size = UDim2.fromOffset(9 * S, 9 * S), Position = right and UDim2.new(1, -9 * S - (i - 1) * 8 * S, 0, 0) or UDim2.fromOffset((i - 1) * 8 * S, 0),
				BackgroundTransparency = 1, ResampleMode = Enum.ResamplerMode.Pixelated, ImageRectOffset = Vector2.new(3, 3), ImageRectSize = Vector2.new(9, 9), Parent = bars,
			})
		end
		return list
	end
	local heartIcons, foodIcons = iconRow(false), iconRow(true)
	local function paintIcons(list, kind, n)
		for i = 1, 10 do
			local v = n - (i - 1) * 2
			local tex = Textures.Hud(kind, v >= 2 and "full" or v == 1 and "half" or "empty")
			if not tex then
				return false
			end
			list[i].ImageContent = tex
		end
		return true
	end
	local heldName = ui.text("", { Size = UDim2.fromOffset(1920, 34), Position = UDim2.fromOffset(0, barsTop - 16 * S), TextSize = 9 * S, Font = PIXEL, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4, Parent = hudRoot })
	local hand = ui.new("Frame", { Size = UDim2.fromOffset(380, 380), Position = UDim2.fromOffset(1560, 780), Rotation = -18, BackgroundTransparency = 1, Parent = hudRoot })
	local swingT = 0

	local function row(n, full, half, empty)
		local out = {}
		for i = 1, 10 do
			local v = n - (i - 1) * 2
			table.insert(out, v >= 2 and full or v == 1 and half or empty)
		end
		return table.concat(out, "")
	end

	function hud.refresh()
		G.hudDirty = false
		for i = 1, 9 do
			slotFrames[i]:ClearAllChildren()
			ui.stroke(rgb(140, 140, 140), 2, 0.35).Parent = slotFrames[i]
			icon(slotFrames[i], inv[i], SLOT)
		end
		selector.Position = UDim2.fromOffset(S + (selected - 1) * SLOT - 2 * S, -S)
		local need = 2 * (P.level or 0) + 7
		xpFill.Size = UDim2.fromScale(math.clamp((P.xp or 0) / need, 0, 1), 1)
		setXpLevel(P.level or 0)
		local creative = G.mode == "creative"
		bars.Visible = not creative
		xpBar.Visible = not creative
		if paintIcons(heartIcons, "heart", math.ceil(P.health or 20)) and paintIcons(foodIcons, "food", math.ceil(P.food or 20)) then
			hearts.Text, food.Text = "", ""
		else
			hearts.Text = row(math.ceil(P.health or 20), '<font color="#ff3040">♥</font>', '<font color="#ff9aa8">♥</font>', '<font color="#3a2a2a">♥</font>')
			food.Text = row(math.ceil(P.food or 20), '<font color="#c8823c">🍗</font>', '<font color="#8a6040">🍗</font>', '<font color="#3a3030">🍗</font>')
		end
		hand:ClearAllChildren()
		if inv[selected] then
			icon(hand, { n = inv[selected].n, c = 1 }, 380)
		else
			-- пустая рука: рука персонажа
			ui.new("Frame", { Size = UDim2.fromOffset(130, 420), Position = UDim2.fromOffset(170, 60), Rotation = -30, BackgroundColor3 = rgb(196, 140, 104), BorderSizePixel = 0, Parent = hand }, {
				ui.gradient({ rgb(255, 255, 255), rgb(190, 190, 190) }, 0),
			})
		end
		local s = inv[selected]
		heldName.Text = s and Content.Info(s.n).label or ""
	end

	-- ---------------------------------------------------------------- настройки игрока (общие для всех миров)
	local DEFAULT_OPTIONS = { fov = 70, render = RENDER, sensitivity = 100, bobbing = true, coords = false, difficulty = "Normal", recipeBook = true }
	local options = table.clone(DEFAULT_OPTIONS)
	local storedOptions = ctx.save:Get("options")
	if type(storedOptions) == "table" then
		for k, v in storedOptions do
			if DEFAULT_OPTIONS[k] ~= nil and type(v) == type(DEFAULT_OPTIONS[k]) then
				options[k] = v
			end
		end
	end
	G.options = options
	local DAMAGE_SCALE = { Peaceful = 0, Easy = 0.5, Normal = 1, Hard = 1.5 }

	-- крафт по списку рецептов (для тестов; в игре крафт идёт по сетке в окнах)
	local function nearStation(kind)
		local p = P.pos
		for x = math.floor(p.X) - 4, math.floor(p.X) + 4 do
			for y = math.floor(p.Y) - 2, math.floor(p.Y) + 3 do
				for z = math.floor(p.Z) - 4, math.floor(p.Z) + 4 do
					local id = world:get(x, y, z)
					if id and BLOCKS[id].station == kind then
						return true
					end
				end
			end
		end
		return false
	end

	local function crafted(name, count)
		G.stats.crafted = (G.stats.crafted or 0) + count
		if name == "stone_pickaxe" then
			ctx.trophies:Unlock("getting_upgrade")
		elseif name == "iron_ingot" then
			ctx.trophies:Unlock("acquire_hardware")
		elseif ITEMS[name] and ITEMS[name].tool and string.sub(name, 1, 9) == "netherite" then
			ctx.trophies:Unlock("netherite_tool")
		end
		G.hudDirty = true
	end

	local function craft(r)
		if r.station and not nearStation(r.station) then
			ctx.audio:Play("error")
			return false
		end
		for name, n in r.inputs do
			if countOf(name) < n then
				ctx.audio:Play("error")
				return false
			end
		end
		for name, n in r.inputs do
			take(name, n)
		end
		give(r.output, r.count)
		crafted(r.output, r.count)
		ctx.audio:Play("confirm")
		return true
	end
	G.craft, G.give, G.inv = craft, give, inv

	-- фигурка игрока в окне инвентаря
	local function playerView(frame)
		local vp = ui.new("ViewportFrame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = rgb(170, 170, 170), LightColor = rgb(255, 255, 255),
			LightDirection = Vector3.new(-0.4, -1, 0.6), Parent = frame,
		})
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		cam.CFrame = CFrame.lookAt(Vector3.new(22, 26, -66), Vector3.new(0, 16, 0))
		cam.Parent = vp
		vp.CurrentCamera = cam
		local SKIN, HAIR, SHIRT, PANTS, SHOES = rgb(214, 158, 118), rgb(74, 48, 28), rgb(64, 132, 84), rgb(58, 62, 120), rgb(70, 70, 76)
		local function part(sx, sy, sz, x, y, z, color)
			local p = Instance.new("Part")
			p.Anchored = true
			p.Size = Vector3.new(sx, sy, sz)
			p.CFrame = CFrame.new(x, y, z)
			p.Color = color
			p.Material = Enum.Material.SmoothPlastic
			p.Parent = vp
			return p
		end
		part(8, 8, 8, 0, 28, 0, SKIN)
		part(8.2, 2.2, 8.2, 0, 31, 0, HAIR)
		part(8.2, 6, 2, 0, 28, 3.2, HAIR)
		part(2, 1, 0.2, -2, 27.5, -4.05, rgb(245, 245, 245))
		part(2, 1, 0.2, 2, 27.5, -4.05, rgb(245, 245, 245))
		part(1, 1, 0.3, -1.5, 27.5, -4.1, rgb(60, 60, 140))
		part(1, 1, 0.3, 2.5, 27.5, -4.1, rgb(60, 60, 140))
		part(4, 1, 0.2, 0, 25, -4.05, rgb(130, 80, 60))
		part(8, 12, 4, 0, 18, 0, SHIRT)
		part(4, 12, 4, -6, 18, 0, SKIN)
		part(4, 4, 4.2, -6, 22, 0, SHIRT)
		part(4, 12, 4, 6, 18, 0, SKIN)
		part(4, 4, 4.2, 6, 22, 0, SHIRT)
		part(4, 12, 4, -2, 6, 0, PANTS)
		part(4, 12, 4, 2, 6, 0, PANTS)
		part(4.1, 2, 4.1, -2, 1, 0, SHOES)
		part(4.1, 2, 4.1, 2, 1, 0, SHOES)
	end

	-- ---------------------------------------------------------------- миры: список, сохранения по ключам world_<id>
	local function listWorlds()
		local list = ctx.save:Get("worlds")
		if type(list) ~= "table" then
			list = {}
			-- перенос старого единственного мира
			local old = ctx.save:Get("world")
			if type(old) == "table" and old.v == SAVE_VERSION then
				table.insert(list, { id = 1, name = "My World", mode = old.mode, last = os.time(), difficulty = "Normal" })
				ctx.save:Set("world_1", old)
				ctx.save:Set("edits_overworld_1", ctx.save:Get("edits_overworld", {}))
				ctx.save:Set("edits_nether_1", ctx.save:Get("edits_nether", {}))
			end
			ctx.save:Set("worlds", list)
		end
		local out = table.clone(list)
		table.sort(out, function(a, b)
			return (a.last or 0) > (b.last or 0)
		end)
		return out
	end

	local function storeWorldEntry(entry)
		local list = ctx.save:Get("worlds", {})
		local copy = {}
		local found = false
		for _, w in list do
			if w.id == entry.id then
				table.insert(copy, entry)
				found = true
			else
				table.insert(copy, w)
			end
		end
		if not found then
			table.insert(copy, entry)
		end
		ctx.save:Set("worlds", copy)
	end

	local function deleteWorld(id)
		local copy = {}
		for _, w in ctx.save:Get("worlds", {}) do
			if w.id ~= id then
				table.insert(copy, w)
			end
		end
		ctx.save:Set("worlds", copy)
		ctx.save:Remove("world_" .. id)
		ctx.save:Remove("edits_overworld_" .. id)
		ctx.save:Remove("edits_nether_" .. id)
	end

	local screens -- окна в стиле Minecraft (Screens.luau), создаются ниже

	-- ---------------------------------------------------------------- игрок: урон, смерть, еда
	local function die(cause)
		screens.close()
		G.state = "dead"
		G.stats.deaths = (G.stats.deaths or 0) + 1
		ctx.audio:Play("explosion", { pitch = 0.6 })
		if G.mode ~= "creative" then
			table.clear(inv)
		end
		screens.open("death", { score = G.score or 0, cause = cause })
	end

	local PLAYER_NAME = "Player"
	pcall(function()
		PLAYER_NAME = game:GetService("Players").LocalPlayer.Name
	end)
	local MOB_NAMES = { zombie = "Zombie", creeper = "Creeper", piglin = "Piglin", zombified_piglin = "Zombified Piglin", hoglin = "Hoglin", pig = "Pig" }
	local CAUSES = {
		lava = "tried to swim in lava", fall = "fell from a high place", void = "fell out of the world", cactus = "was pricked to death",
		magma = "discovered the floor was lava", starve = "starved to death", explosion = "was blown up by Creeper",
	}

	-- cause: ключ из CAUSES или моб (тогда урон зависит от сложности)
	local function damage(amount, fromPos, cause)
		if type(cause) == "table" or cause == "explosion" then
			amount *= DAMAGE_SCALE[options.difficulty] or 1
		end
		if G.mode == "creative" or G.state ~= "play" or (P.hurtCd or 0) > 0 or amount <= 0 then
			return
		end
		P.health = math.max(0, P.health - amount)
		P.hurtCd = 0.5
		tint.BackgroundColor3 = rgb(255, 0, 0)
		tint.BackgroundTransparency = 0.6
		ctx.audio:Play("hit", { pitch = 0.8 })
		ctx.input:Rumble(0.5, 0.2)
		if fromPos then
			local away = (P.pos - fromPos) * Vector3.new(1, 0, 1)
			if away.Magnitude > 0.01 then
				P.vel = away.Unit * 6 + Vector3.new(0, 5, 0)
				P.knock = 0.25
			end
		end
		G.hudDirty = true
		if P.health <= 0 then
			local text
			if type(cause) == "table" then
				text = `was slain by {MOB_NAMES[cause.kind] or "a mob"}`
			else
				text = CAUSES[cause] or "died"
			end
			die(PLAYER_NAME .. " " .. text)
		end
	end
	G.damage = damage

	local function exhaust(amount)
		if G.mode == "creative" or options.difficulty == "Peaceful" then
			return
		end
		P.exhaustion = (P.exhaustion or 0) + amount
		while P.exhaustion >= 4 do
			P.exhaustion -= 4
			P.food = math.max(0, P.food - 1)
			G.hudDirty = true
		end
	end

	-- ---------------------------------------------------------------- измерения и порталы
	local function clearMobs()
		for _, m in G.mobs do
			m:destroy()
		end
		table.clear(G.mobs)
	end

	local function enterDimension(dim, pos)
		if world then
			world:destroy()
		end
		clearMobs()
		G.dim = dim
		world = World.new(generate(dim), ctx.world, ORIGIN, B)
		P.pos = pos or world.gen.spawn
		P.vel = Vector3.zero
		P.fallFrom = nil
		world:focus(P.pos, options.render)
		-- ближайшие куски сразу, остальные по одному за кадр
		world:step(9)
		applyLighting()
		if dim == "nether" then
			ctx.trophies:Unlock("we_need_to_go_deeper")
		end
	end

	-- рамка 4×5 из обсидиана, внутри 2×3 портала; ось x или z
	local function framePortal(ox, oy, oz, axis, build)
		local dx, dz = axis == "x" and 1 or 0, axis == "z" and 1 or 0
		local portal = axis == "x" and "nether_portal_x" or "nether_portal_z"
		for i = 0, 3 do
			for j = 0, 4 do
				local x, y, z = ox + dx * i, oy + j, oz + dz * i
				local frame = i == 0 or i == 3 or j == 0 or j == 4
				local corner = (i == 0 or i == 3) and (j == 0 or j == 4)
				if build then
					setBlock(x, y, z, frame and "obsidian" or portal)
				elseif frame and not corner then
					if world:get(x, y, z) ~= "obsidian" then
						return false
					end
				elseif not frame then
					local id = world:get(x, y, z)
					if id ~= nil and id ~= "fire" then
						return false
					end
				end
			end
		end
		return true
	end

	local function tryLight(cell)
		for _, axis in { "x", "z" } do
			for ofs = 0, 1 do
				for up = 1, 3 do
					local ox = cell.X - (axis == "x" and ofs + 1 or 0)
					local oz = cell.Z - (axis == "z" and ofs + 1 or 0)
					local oy = cell.Y - up
					if framePortal(ox, oy, oz, axis, false) then
						local dx, dz = axis == "x" and 1 or 0, axis == "z" and 1 or 0
						for i = 1, 2 do
							for j = 1, 3 do
								setBlock(ox + dx * i, oy + j, oz + dz * i, axis == "x" and "nether_portal_x" or "nether_portal_z")
							end
						end
						return true
					end
				end
			end
		end
		return false
	end

	local function travel()
		local target = G.dim == "nether" and "overworld" or "nether"
		local from = P.pos
		generate(target)
		local gen = G.gens[target]
		-- ищем портал рядом в целевом мире, иначе строим новый на твёрдой площадке
		local found
		for k, id in gen.blocks do
			if BLOCKS[id].portal then
				local y = k // (SX * SZ)
				local rest = k % (SX * SZ)
				local x, z = rest % SX, rest // SX
				if not found or math.abs(x - from.X) + math.abs(z - from.Z) < math.abs(found.X - from.X) + math.abs(found.Z - from.Z) then
					found = Vector3.new(x, y, z)
				end
			end
		end
		local arrive
		if found then
			local id = gen.blocks[Terrain.key(found.X, found.Y, found.Z)]
			local off = BLOCKS[id].portal == "x" and Vector3.new(0, 0, 1) or Vector3.new(1, 0, 0)
			-- встаём перед порталом, на нижнюю клетку
			local y = found.Y
			while y > 1 and gen.blocks[Terrain.key(found.X, y - 1, found.Z)] and BLOCKS[gen.blocks[Terrain.key(found.X, y - 1, found.Z)]].portal do
				y -= 1
			end
			arrive = Vector3.new(found.X + 0.5, y + 0.01, found.Z + 0.5) + off
			enterDimension(target, arrive)
		else
			local cx = math.clamp(math.floor(from.X), 4, SX - 8)
			local cz = math.clamp(math.floor(from.Z), 4, SZ - 8)
			local stand = Terrain.FindStand(gen, cx, cz, target == "nether" and 11 or 13) or gen.spawn
			enterDimension(target, stand)
			local ox, oy, oz = math.floor(stand.X) - 1, math.floor(stand.Y) - 1, math.floor(stand.Z) + 1
			-- площадка и воздух вокруг портала
			for i = -1, 4 do
				for k = -1, 1 do
					setBlock(ox + i, oy, oz + k, "obsidian")
					for j = 1, 4 do
						if k ~= 0 then
							setBlock(ox + i, oy + j, oz + k, nil)
						end
					end
				end
			end
			framePortal(ox, oy, oz, "x", true)
			P.pos = Vector3.new(ox + 1.5, oy + 1.01, oz + 1.5)
		end
		P.portalLock = true -- не уходим обратно, пока не выйдем из портала
		ctx.audio:Play("trophy", { pitch = 0.6 })
	end
	G.travel = travel

	-- ---------------------------------------------------------------- взрыв крипера
	local function explode(center)
		ctx.audio:Play("explosion")
		ctx.input:Rumble(1, 0.4)
		local r = 2.6
		for x = math.floor(center.X - r), math.floor(center.X + r) do
			for y = math.floor(center.Y - r), math.floor(center.Y + r) do
				for z = math.floor(center.Z - r), math.floor(center.Z + r) do
					local id = world:get(x, y, z)
					local d = (Vector3.new(x + 0.5, y + 0.5, z + 0.5) - center).Magnitude
					if id and d <= r and BLOCKS[id].hardness >= 0 and BLOCKS[id].hardness < 30 and not BLOCKS[id].liquid then
						setBlock(x, y, z, nil)
					end
				end
			end
		end
		local dist = (P.pos + Vector3.new(0, 0.9, 0) - center).Magnitude
		if dist < 6 then
			damage(math.floor(22 * (1 - dist / 6)), center, "explosion")
		end
		for _, m in G.mobs do
			local md = (m.pos - center).Magnitude
			if md < 5 then
				m:hurt(15 * (1 - md / 5), center)
			end
		end
		local flash = Instance.new("Part")
		flash.Anchored, flash.CanCollide, flash.CanQuery = true, false, false
		flash.Shape = Enum.PartType.Ball
		flash.Material = Enum.Material.SmoothPlastic
		flash.Color = rgb(255, 240, 200)
		flash.Size = Vector3.one * B * 2
		flash.Position = world:toWorld(center)
		flash.Parent = ctx.world
		ui.tween(flash, 0.5, { Size = Vector3.one * B * 6, Transparency = 1 })
		task.delay(0.6, function()
			flash:Destroy()
		end)
	end

	-- ---------------------------------------------------------------- мобы: появление
	local spawnTimer = 0
	local function trySpawn()
		local cap = 8
		if #G.mobs >= cap then
			return
		end
		local a = math.random() * math.pi * 2
		local r = math.random(12, 24)
		local x = math.floor(P.pos.X + math.cos(a) * r)
		local z = math.floor(P.pos.Z + math.sin(a) * r)
		if x < 1 or z < 1 or x >= SX - 1 or z >= SZ - 1 then
			return
		end
		-- сверху вниз до первой опоры
		local top = world.H - 2
		if G.dim == "nether" then
			top = math.random(12, 34)
		end
		for y = top, 2, -1 do
			local below = world:get(x, y - 1, z)
			if below and BLOCKS[below].solid ~= false and not world:get(x, y, z) and not world:get(x, y + 1, z) then
				local kind
				if G.dim == "nether" then
					if below == "crimson_nylium" then
						kind = math.random() < 0.5 and "hoglin" or "piglin"
					elseif below == "netherrack" or below == "warped_nylium" or below == "magma_block" then
						kind = math.random() < 0.7 and "zombified_piglin" or "piglin"
					end
				elseif isDay() then
					if below == "grass_block" then
						kind = "pig"
					end
				else
					local roll = math.random()
					kind = roll < 0.55 and "zombie" or roll < 0.9 and "creeper" or (below == "grass_block" and "pig" or nil)
				end
				if kind and options.difficulty == "Peaceful" and Mobs.DEFS[kind].hostile then
					kind = nil
				end
				if kind then
					table.insert(G.mobs, Mobs.new(kind, Vector3.new(x + 0.5, y, z + 0.5), ctx.world, B, ORIGIN))
				end
				return
			end
		end
	end

	-- ---------------------------------------------------------------- сохранение
	local function packStack(s)
		return s and { n = s.n, c = s.c, d = s.d } or nil
	end

	local function saveAll()
		if not G.seed or not G.worldId then
			return
		end
		local id = G.worldId
		local packed = {}
		for i = 1, 41 do
			if inv[i] then
				packed[tostring(i)] = packStack(inv[i])
			end
		end
		local furnaces = {}
		for k, f in G.furnaces do
			if f.input or f.fuel or f.output then
				furnaces[k] = { input = packStack(f.input), fuel = packStack(f.fuel), output = packStack(f.output), burn = f.burn, burnMax = f.burnMax, cook = f.cook }
			end
		end
		ctx.save:Set("world_" .. id, {
			v = SAVE_VERSION, seed = G.seed, mode = G.mode, dim = G.dim, time = G.time,
			x = P.pos.X, y = P.pos.Y, z = P.pos.Z, yaw = P.yaw, pitch = P.pitch, health = P.health, food = P.food, xp = P.xp, level = P.level, inv = packed,
			furnaces = furnaces, stats = G.stats, score = G.score,
		})
		if G.dirty then
			for dim, e in G.edits do
				ctx.save:Set(`edits_{dim}_{id}`, e)
			end
			G.dirty = false
		end
		storeWorldEntry({ id = id, name = G.worldName, mode = G.mode, last = os.time(), difficulty = options.difficulty })
		ctx.save:Set("best", math.max(ctx.save:Get("best", 0), G.mined or 0))
	end
	G.saveAll = saveAll

	-- ---------------------------------------------------------------- панорама за главным меню
	local panorama
	local panoramaAngle = 0
	local function showPanorama()
		if panorama then
			return
		end
		local gen = Terrain.Overworld(20201)
		panorama = World.new(gen, ctx.world, ORIGIN, B)
		panorama:focus(gen.spawn, 2)
		panorama:step(9)
	end
	local function hidePanorama()
		if panorama then
			panorama:destroy()
			panorama = nil
		end
	end

	-- ---------------------------------------------------------------- старт мира
	-- fresh = { name, mode, seed, difficulty } для нового мира
	local function startWorld(id, fresh)
		screens.close()
		hidePanorama()
		local saved = not fresh and ctx.save:Get("world_" .. id)
		if type(saved) ~= "table" or saved.v ~= SAVE_VERSION then
			saved = nil
		end
		G.worldId = id
		local entry
		for _, w in listWorlds() do
			if w.id == id then
				entry = w
			end
		end
		G.worldName = fresh and fresh.name or entry and entry.name or "World"
		if fresh then
			options.difficulty = fresh.difficulty or options.difficulty
		elseif entry and entry.difficulty then
			options.difficulty = entry.difficulty
		end
		table.clear(inv)
		table.clear(G.furnaces)
		G.stats = {}
		if not saved then
			G.seed = fresh and fresh.seed or math.random(1, 2 ^ 30)
			G.mode = fresh and fresh.mode or (entry and entry.mode) or "survival"
			G.time = 0
			G.edits = { overworld = {}, nether = {} }
			G.mined, G.score = 0, 0
			P.health, P.food, P.yaw, P.pitch = 20, 20, 0, 0
			P.xp, P.level = 0, 0
			ctx.save:Set("edits_overworld_" .. id, {})
			ctx.save:Set("edits_nether_" .. id, {})
		else
			G.seed, G.mode, G.time = saved.seed, saved.mode, saved.time or 0
			G.edits = { overworld = ctx.save:Get("edits_overworld_" .. id, {}), nether = ctx.save:Get("edits_nether_" .. id, {}) }
			for k, st in saved.inv or {} do
				inv[tonumber(k)] = packStack(st)
			end
			for k, f in saved.furnaces or {} do
				G.furnaces[k] = { input = packStack(f.input), fuel = packStack(f.fuel), output = packStack(f.output), burn = f.burn or 0, burnMax = f.burnMax or 0, cook = f.cook or 0 }
			end
			for k, v in saved.stats or {} do
				G.stats[k] = v
			end
			G.mined, G.score = G.stats.mined or 0, saved.score or 0
			P.health, P.food, P.yaw, P.pitch = saved.health or 20, saved.food or 20, saved.yaw or 0, saved.pitch or 0
			P.xp, P.level = saved.xp or 0, saved.level or 0
		end
		G.gens = {}
		P.exhaustion, P.hurtCd, P.regen, P.flying = 0, 0, 0, false
		enterDimension(saved and saved.dim or "overworld", saved and Vector3.new(saved.x, saved.y, saved.z) or nil)
		if G.mode == "creative" and not saved then
			for i, name in { "grass_block", "oak_planks", "stone_bricks", "glass", "oak_log", "torch", "obsidian", "flint_and_steel", "netherite_pickaxe" } do
				inv[i] = { n = name, c = Content.StackSize(name), d = ITEMS[name] and ITEMS[name].durability }
			end
		end
		G.state = "play"
		hudRoot.Visible = true
		G.hudDirty = true
		G.dirty = true
		saveAll()
	end

	local function createWorld(name, mode, seed, difficulty)
		local id = 1
		for _, w in listWorlds() do
			id = math.max(id, w.id + 1)
		end
		startWorld(id, { name = name, mode = mode, seed = seed, difficulty = difficulty })
	end
	G.createWorld = createWorld

	function G.respawn()
		P.health, P.food, P.exhaustion = 20, 20, 0
		P.xp, P.level = 0, 0
		G.state = "play"
		enterDimension("overworld", nil)
		G.hudDirty = true
	end

	function G.toTitle()
		screens.close()
		if world then
			world:destroy()
			world = nil
		end
		clearMobs()
		hudRoot.Visible = false
		G.state = "title"
		G.worldId, G.seed = nil, nil
		G.time = DAY * 0.12 -- утро: панорама в дневном свете
		G.dim = "overworld"
		applyLighting()
		showPanorama()
		screens.open("title")
	end

	local function pause()
		if G.state ~= "play" then
			return
		end
		screens.close()
		G.state = "paused"
		saveAll()
		screens.open("pause")
	end

	screens = Screens.new({
		ui = ui, S = S, PIXEL = PIXEL, Content = Content, Textures = Textures, ctx = ctx, G = G, inv = inv, canvas = canvas,
		icon = icon, countOf = countOf, take = take, crafted = crafted, playerView = playerView,
		options = options,
		saveOptions = function()
			ctx.save:Set("options", options)
			if options.difficulty == "Peaceful" then
				for i = #G.mobs, 1, -1 do
					if G.mobs[i].def.hostile then
						G.mobs[i]:destroy()
						table.remove(G.mobs, i)
					end
				end
			end
		end,
		listWorlds = listWorlds,
		playWorld = function(id)
			startWorld(id, nil)
		end,
		createWorld = createWorld,
		deleteWorld = deleteWorld,
		quit = function()
			ctx:Exit()
		end,
		resume = function()
			G.state = "play"
		end,
		saveAndQuit = function()
			saveAll()
			G.toTitle()
		end,
		respawn = function()
			G.respawn()
		end,
	})
	G.screens = screens

	-- ---------------------------------------------------------------- действия: ломать, ставить, использовать
	local mining = { target = nil, progress = 0 }
	local attackHeld, useHeld = false, false
	local attackCd, useCd = 0, 0
	local aim = {}

	local crack = Instance.new("Part")
	crack.Name = "Crack"
	crack.Anchored, crack.CanCollide, crack.CanQuery, crack.CastShadow = true, false, false, false
	crack.Size = Vector3.one * (B + 0.08)
	crack.Color = rgb(0, 0, 0)
	crack.Transparency = 1
	crack.Parent = ctx.world
	local outline = Instance.new("SelectionBox")
	outline.Adornee = crack
	outline.Color3 = rgb(0, 0, 0)
	outline.LineThickness = 0.025
	outline.Transparency = 0.3
	outline.SurfaceTransparency = 1
	outline.Parent = crack

	local function breakTime(id)
		local def = BLOCKS[id]
		if def.hardness < 0 then
			return math.huge, false
		end
		if G.mode == "creative" then
			return 0, false
		end
		local s = held()
		local tool = s and ITEMS[s.n] and ITEMS[s.n].tool
		local canHarvest = not def.tier or (tool ~= nil and tool.kind == "pickaxe" and tool.tier >= def.tier)
		local speed = (tool and def.tool == tool.kind) and tool.speed or 1
		return def.hardness * (canHarvest and 1.5 or 5) / speed, canHarvest
	end

	local function wearTool(amount)
		local s = held()
		if s and s.d and G.mode ~= "creative" then
			s.d -= amount
			if s.d <= 0 then
				inv[selected] = nil
				ctx.audio:Play("hit", { pitch = 1.6 })
				say("Your tool broke!")
			end
			G.hudDirty = true
		end
	end

	-- опыт: уровень растёт, когда шкала заполнена (2 × уровень + 7 очков, как в Minecraft)
	local function addXp(n)
		P.xp = (P.xp or 0) + n
		P.level = P.level or 0
		while P.xp >= 2 * P.level + 7 do
			P.xp -= 2 * P.level + 7
			P.level += 1
			ctx.audio:Play("trophy", { pitch = 1.4 })
		end
		G.hudDirty = true
	end
	local ORE_XP = { coal_ore = { 0, 2 }, diamond_ore = { 3, 7 }, lapis_ore = { 2, 5 }, redstone_ore = { 1, 5 }, nether_quartz_ore = { 2, 5 }, nether_gold_ore = { 0, 1 } }

	local function finishBreak(cell, id)
		local _, canHarvest = breakTime(id)
		-- сломанная печь отдаёт всё, что в ней лежало
		local fkey = coordKey(cell.X, cell.Y, cell.Z)
		local furnace = G.furnaces[fkey]
		if furnace then
			for _, st in { furnace.input, furnace.fuel, furnace.output } do
				if st and st.c > 0 then
					give(st.n, st.c)
				end
			end
			G.furnaces[fkey] = nil
		end
		G.stats.mined = (G.stats.mined or 0) + 1
		setBlock(cell.X, cell.Y, cell.Z, nil)
		afterRemove(cell.X, cell.Y, cell.Z)
		ctx.audio:Play("hit", { pitch = 0.85 + math.random() * 0.3 })
		swingT = 0.25
		if G.mode == "creative" then
			return
		end
		local def = BLOCKS[id]
		G.mined = (G.mined or 0) + 1
		if canHarvest and def.drop ~= false then
			local drop, count = def.drop or id, 1
			if def.dropChance and math.random() > def.dropChance then
				drop = nil
			end
			if id == "gravel" and math.random() < 0.1 then
				drop = "flint"
			end
			if def.dropCount then
				count = math.random(def.dropCount[1], def.dropCount[2])
			end
			if drop then
				give(drop, count)
			end
		end
		local xp = canHarvest and ORE_XP[id]
		if xp then
			addXp(math.random(xp[1], xp[2]))
		end
		if id == "stone" then
			local s = held()
			if s and string.find(s.n, "pickaxe") then
				ctx.trophies:Unlock("stone_age")
			end
		end
		wearTool(1)
		exhaust(0.005)
	end

	local function killMob(m, byPlayer)
		for i, other in G.mobs do
			if other == m then
				table.remove(G.mobs, i)
				break
			end
		end
		m:destroy()
		if byPlayer then
			for _, d in m.def.drops do
				local n = math.random(d[2], d[3])
				if n > 0 then
					give(d[1], n)
				end
			end
			if m.def.hostile then
				ctx.trophies:Unlock("monster_hunter")
			end
			addXp(m.def.hostile and 5 or math.random(1, 3))
			G.score = (G.score or 0) + 1
			G.stats.kills = (G.stats.kills or 0) + 1
		end
	end

	local function attack()
		if attackCd > 0 then
			return
		end
		swingT = 0.25
		if aim.mob then
			attackCd = 0.5
			local s = held()
			local tool = s and ITEMS[s.n] and ITEMS[s.n].tool
			local dmg = tool and tool.damage or 1
			if not P.onGround and P.vel.Y < 0 then
				dmg *= 1.5 -- критический удар в падении
			end
			ctx.audio:Play("hit")
			if aim.mob:hurt(dmg, P.pos) then
				killMob(aim.mob, true)
			end
			wearTool(tool and tool.kind == "sword" and 1 or 2)
			exhaust(0.1)
		elseif aim.block and G.mode == "creative" then
			attackCd = 0.2
			finishBreak(aim.block, aim.id)
		end
	end

	local function insidePlayer(c)
		local p = P.pos
		return c.X + 1 > p.X - HALF and c.X < p.X + HALF and c.Z + 1 > p.Z - HALF and c.Z < p.Z + HALF and c.Y + 1 > p.Y and c.Y < p.Y + TALL
	end

	local function use()
		if useCd > 0 then
			return
		end
		useCd = 0.25
		local s = held()
		-- бартер с пиглином
		if aim.mob and aim.mob.def.barter and s and s.n == "gold_ingot" then
			take("gold_ingot", 1)
			ctx.audio:Play("confirm", { pitch = 0.7 })
			task.delay(1, function()
				local pick = Content.BARTER[math.random(#Content.BARTER)]
				give(pick[1], math.random(pick[2], pick[3]))
				say(`Piglin gave you {Content.Info(pick[1]).label}`)
				ctx.trophies:Unlock("oh_shiny")
			end)
			return
		end
		-- еда
		local item = s and ITEMS[s.n]
		if item and item.food and (P.food < 20 or item.heal) and G.mode ~= "creative" then
			P.food = math.min(20, P.food + item.food)
			if item.heal then
				P.health = math.min(20, P.health + item.heal)
			end
			take(s.n, 1)
			ctx.audio:Play("confirm", { pitch = 1.3 })
			swingT = 0.25
			return
		end
		-- огниво зажигает портал
		if s and s.n == "flint_and_steel" and aim.free then
			if tryLight(aim.free) then
				ctx.audio:Play("trophy", { pitch = 1.4 })
				say("The portal is lit!")
			else
				ctx.audio:Play("error")
			end
			wearTool(1)
			return
		end
		-- верстак и печь открывают окно крафта
		local station = aim.block and BLOCKS[aim.id].station
		if station and not (s and Content.Info(s.n).block and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)) then
			attackHeld, useHeld = false, false
			if station == "furnace" then
				screens.open("furnace", { key = coordKey(aim.block.X, aim.block.Y, aim.block.Z) })
			else
				screens.open("table")
			end
			ctx.audio:Play("confirm", { pitch = 0.8 })
			return
		end
		-- поставить блок
		if s and Content.Info(s.n).block and aim.block and aim.free and world:inside(aim.free.X, aim.free.Y, aim.free.Z) then
			local f = aim.free
			local there = world:get(f.X, f.Y, f.Z)
			if (there == nil or BLOCKS[there].liquid) and (not insidePlayer(f) or BLOCKS[s.n].solid == false) then
				setBlock(f.X, f.Y, f.Z, s.n)
				fall(f.X, f.Y, f.Z)
				G.stats.placed = (G.stats.placed or 0) + 1
				if G.mode ~= "creative" then
					take(s.n, 1)
				end
				ctx.audio:Play("move", { pitch = 0.7 })
				swingT = 0.2
			end
		end
	end

	-- ---------------------------------------------------------------- ввод
	local function selectSlot(i)
		selected = (i - 1) % 9 + 1
		G.hudDirty = true
	end

	-- E / △: инвентарь (в творческом режиме — творческий), повторно — закрыть
	local function toggleInventory()
		if screens.isContainer() then
			screens.close()
		elseif G.state == "play" and not screens.isOpen() then
			attackHeld, useHeld = false, false
			screens.open(G.mode == "creative" and "creative" or "inventory")
		end
	end

	local lastJump = 0
	ctx.input:On("press", function(btn)
		if screens.isOpen() then
			if screens.isContainer() and (btn == "options" or (btn == "triangle" and ctx.input:Device() == "gamepad")) then
				screens.close()
			else
				screens.press(btn)
			end
			return
		end
		if btn == "options" then
			pause()
			return
		end
		if G.state ~= "play" then
			return
		end
		if btn == "cross" then
			G.stats.jumps = (G.stats.jumps or 0) + (P.onGround and 1 or 0)
		end
		if btn == "cross" and G.mode == "creative" then
			local now = os.clock()
			if now - lastJump < 0.3 then
				P.flying = not P.flying
				say(P.flying and "Flying" or "Walking")
			end
			lastJump = now
		end
		-- кнопки геймпада; клавиатуру читаем напрямую (E, 1–9, мышь), чтобы F и R не мешали
		if ctx.input:Device() == "gamepad" then
			if btn == "r2" then
				attack()
			elseif btn == "l2" then
				use()
			elseif btn == "l1" then
				selectSlot(selected - 1)
			elseif btn == "r1" then
				selectSlot(selected + 1)
			elseif btn == "triangle" then
				toggleInventory()
			end
		end
	end)

	local NUMBER_KEYS = {
		[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5,
		[Enum.KeyCode.Six] = 6, [Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8, [Enum.KeyCode.Nine] = 9,
	}
	ctx:Connect(UserInputService.InputBegan, function(input, processed)
		if ctx.paused or processed then
			return
		end
		local t = input.UserInputType
		if input.KeyCode == Enum.KeyCode.E then
			toggleInventory()
		elseif screens.isOpen() then
			return
		elseif NUMBER_KEYS[input.KeyCode] then
			selectSlot(NUMBER_KEYS[input.KeyCode])
		elseif input.KeyCode == Enum.KeyCode.F3 then
			info.Visible = not info.Visible
		elseif t == Enum.UserInputType.MouseButton1 then
			attackHeld = true
			attack()
		elseif t == Enum.UserInputType.MouseButton2 then
			useHeld = true
			use()
		end
	end)
	ctx:Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			attackHeld = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			useHeld = false
		end
	end)
	ctx:Connect(UserInputService.InputChanged, function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel and G.state == "play" and not screens.isOpen() then
			selectSlot(selected - (input.Position.Z > 0 and 1 or -1))
		end
	end)

	local function keyDown(k)
		local ok, down = pcall(UserInputService.IsKeyDown, UserInputService, k)
		return ok and down
	end

	ctx:On("pause", function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		saveAll()
	end)
	ctx:On("exit", function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		if G.state ~= "title" then
			saveAll()
		end
		restoreLighting()
	end)

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 70

	-- ---------------------------------------------------------------- кадр
	local saveTimer = 0
	ctx:Loop(function(dt)
		if toastTimer > 0 then
			toastTimer -= dt
			if toastTimer <= 0 then
				toast.TextTransparency, toast.TextStrokeTransparency = 1, 1
			end
		end
		if G.state == "title" or not world then
			-- панорама: камера медленно вращается над точкой появления, как в меню Minecraft
			if panorama then
				panorama:step(1)
				panoramaAngle += dt * 0.05
				local eye = panorama.gen.spawn + Vector3.new(0, 6, 0)
				camera.FieldOfView = 80
				camera.CFrame = CFrame.new(panorama:toWorld(eye)) * CFrame.fromOrientation(-0.12, panoramaAngle, 0)
			end
			return
		end
		applyLighting()
		world:step(1)
		if G.state ~= "play" then
			return
		end
		local creative = G.mode == "creative"
		G.time += dt
		G.stats.played = (G.stats.played or 0) + dt
		screens.tickFurnaces(dt)
		local windowOpen = screens.isOpen()

		-- обзор
		if not windowOpen then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
			local delta = UserInputService:GetMouseDelta()
			local axes = ctx.input:GetAxes()
			local sens = options.sensitivity / 100
			P.yaw -= (delta.X * 0.0045 + axes.rx * 2.8 * dt) * sens
			P.pitch = math.clamp(P.pitch - (delta.Y * 0.0045 - axes.ry * 2.2 * dt) * sens, -1.55, 1.55)
		end

		-- движение
		local axes = ctx.input:GetAxes()
		if windowOpen then
			axes = { lx = 0, ly = 0 }
		end
		local feet = world:at(P.pos + Vector3.new(0, 0.1, 0))
		local head = world:at(P.pos + Vector3.new(0, 1.6, 0))
		local inWater = feet == "water" or head == "water"
		local inLava = feet == "lava" or head == "lava"
		local sneak = keyDown(Enum.KeyCode.LeftShift) or ctx.input:IsDown("circle")
		local wantsSprint = (keyDown(Enum.KeyCode.LeftControl) or ctx.input:IsDown("l3")) and axes.ly > 0.5
		P.sprint = wantsSprint and (P.food > 6 or creative) and not sneak
		local speed = P.flying and 11 or (sneak and 1.3) or (P.sprint and 5.6) or 4.3
		if inWater or inLava then
			speed *= 0.5
		end
		local below = world:get(math.floor(P.pos.X), math.floor(P.pos.Y - 0.1), math.floor(P.pos.Z))
		if below and BLOCKS[below].slow then
			speed *= 0.45
		end
		local forward = Vector3.new(-math.sin(P.yaw), 0, -math.cos(P.yaw))
		local right = Vector3.new(math.cos(P.yaw), 0, -math.sin(P.yaw))
		local wish = forward * axes.ly + right * axes.lx
		if wish.Magnitude > 1 then
			wish = wish.Unit
		end
		local horizontal = wish * speed
		if P.knock and P.knock > 0 then
			P.knock -= dt
			horizontal = Vector3.new(P.vel.X, 0, P.vel.Z)
		end
		local vy = P.vel.Y
		local jump = ctx.input:IsDown("cross") and not windowOpen
		if P.flying then
			vy = jump and 7 or (sneak and -7 or 0)
		elseif inWater or inLava then
			vy = jump and 3.2 or math.max(vy - 12 * dt, -2.5)
			P.fallFrom = nil
		else
			vy = math.max(vy - 30 * dt, -60)
			if jump and P.onGround then
				vy = 8.6
				exhaust(P.sprint and 0.2 or 0.05)
			end
		end
		-- крадясь, не падаем с края
		if sneak and P.onGround and not P.flying then
			local function supported(p)
				return world:collides(Vector3.new(p.X, P.pos.Y - 0.1, p.Z), HALF, 0.1)
			end
			local step = horizontal * dt
			if not supported(P.pos + Vector3.new(step.X, 0, 0)) then
				horizontal = Vector3.new(0, 0, horizontal.Z)
			end
			if not supported(P.pos + Vector3.new(0, 0, step.Z)) then
				horizontal = Vector3.new(horizontal.X, 0, 0)
			end
		end
		local oldPos = P.pos
		local newPos, onGround, _, ceiling = world:moveBox(P.pos, Vector3.new(horizontal.X, vy, horizontal.Z) * dt, HALF, TALL)
		P.pos = newPos
		if ceiling and vy > 0 then
			vy = 0
		end
		if onGround then
			if P.fallFrom and not creative then
				local fallen = P.fallFrom - P.pos.Y
				if fallen > 3.5 and not inWater then
					damage(math.floor(fallen - 3), nil, "fall")
				end
			end
			P.fallFrom = nil
			vy = 0
			if P.flying and sneak then
				P.flying = false
			end
		elseif not P.flying and not inWater then
			P.fallFrom = math.max(P.fallFrom or P.pos.Y, P.pos.Y)
		end
		P.onGround = onGround
		P.vel = Vector3.new(horizontal.X, vy, horizontal.Z)
		if onGround then
			G.stats.walked = (G.stats.walked or 0) + ((P.pos - oldPos) * Vector3.new(1, 0, 1)).Magnitude
		end
		if P.sprint then
			exhaust(0.1 * (P.pos - oldPos).Magnitude)
		end

		-- опасности
		P.hurtCd = math.max(0, (P.hurtCd or 0) - dt)
		if inLava then
			damage(4, nil, "lava")
		end
		if below and BLOCKS[below].hurts and below == "magma_block" and not sneak then
			damage(1, nil, "magma")
		end
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			if world:get(math.floor(P.pos.X + d[1] * (HALF + 0.05)), math.floor(P.pos.Y + 0.5), math.floor(P.pos.Z + d[2] * (HALF + 0.05))) == "cactus" then
				damage(1, nil, "cactus")
			end
		end
		if P.pos.Y < -4 then
			damage(4, nil, "void")
			if creative then
				P.pos = world.gen.spawn
			end
		end
		-- голод и восстановление
		if not creative then
			P.regen = (P.regen or 0) + dt
			if P.regen >= 4 then
				P.regen = 0
				if (P.food >= 18 or options.difficulty == "Peaceful") and P.health < 20 then
					P.health += 1
					exhaust(3)
					G.hudDirty = true
				elseif P.food <= 0 and P.health > 1 then
					damage(1, nil, "starve")
				end
			end
		end

		-- портал
		local portalHere = (feet and BLOCKS[feet].portal) or (head and BLOCKS[head].portal)
		if portalHere then
			if not P.portalLock then
				P.portalTime = (P.portalTime or 0) + dt
				tint.BackgroundColor3 = rgb(140, 60, 230)
				tint.BackgroundTransparency = 1 - math.min(P.portalTime / 2.5, 1) * 0.6
				if P.portalTime >= (creative and 0.5 or 2.5) then
					P.portalTime = 0
					travel()
				end
			end
		else
			P.portalLock = false
			P.portalTime = 0
		end

		-- камера
		local eyeH = sneak and 1.45 or 1.62
		local eye = P.pos + Vector3.new(0, eyeH, 0)
		local look = CFrame.fromOrientation(P.pitch, P.yaw, 0)
		camera.CFrame = CFrame.new(world:toWorld(eye)) * look
		camera.FieldOfView = options.fov + (P.sprint and 10 or 0)
		world:focus(P.pos, options.render)

		-- прицел: моб или блок
		local dir = look.LookVector
		local cell, free, dist, id = world:raycast(eye, dir, REACH)
		aim.block, aim.free, aim.id, aim.mob = cell, free, id, nil
		local best = cell and dist or REACH
		for _, m in G.mobs do
			local t = m:rayHit(eye, dir, 3.5)
			if t and t < best then
				best = t
				aim.mob = m
				aim.block = nil
			end
		end
		if aim.block then
			crack.Position = world:toWorld(aim.block + Vector3.new(0.5, 0.5, 0.5))
			outline.Visible = true
		else
			outline.Visible = false
			crack.Transparency = 1
		end

		-- копание (удержание)
		attackCd = math.max(0, attackCd - dt)
		useCd = math.max(0, useCd - dt)
		local attacking = attackHeld or (ctx.input:Device() == "gamepad" and ctx.input:IsDown("r2"))
		if attacking and aim.block and not creative and not windowOpen then
			local k = coordKey(aim.block.X, aim.block.Y, aim.block.Z)
			if mining.target ~= k then
				mining.target, mining.progress = k, 0
			end
			local t = breakTime(aim.id)
			mining.progress += dt / math.max(t, 0.05)
			swingT = math.max(swingT, 0.12)
			crack.Transparency = 1 - math.min(mining.progress, 1) * 0.55
			breakBar.Visible = t ~= math.huge
			breakFill.Size = UDim2.fromScale(math.min(mining.progress, 1), 1)
			if mining.progress >= 1 then
				finishBreak(aim.block, aim.id)
				mining.target, mining.progress = nil, 0
			end
		else
			mining.target, mining.progress = nil, 0
			crack.Transparency = 1
			breakBar.Visible = false
		end
		local using = useHeld or (ctx.input:Device() == "gamepad" and ctx.input:IsDown("l2"))
		if using and useCd <= 0 and not windowOpen then
			use()
		end

		-- мобы
		spawnTimer += dt
		if spawnTimer > 2 then
			spawnTimer = 0
			trySpawn()
		end
		local env = {
			world = world, player = P.pos, day = isDay(), dead = G.state ~= "play", creative = creative,
			damagePlayer = damage, explode = explode,
			skyAt = function(pos)
				for y = math.floor(pos.Y) + 2, world.H - 1 do
					if world:get(math.floor(pos.X), y, math.floor(pos.Z)) then
						return false
					end
				end
				return true
			end,
		}
		for i = #G.mobs, 1, -1 do
			local m = G.mobs[i]
			if m and m.model.Parent then
				local result = m:update(dt, env)
				if result == "exploded" then
					killMob(m, false)
				elseif result == "died" then
					killMob(m, true)
				elseif result or (m.pos - P.pos).Magnitude > 40 then
					killMob(m, false)
				else
					m:render()
				end
			end
		end

		-- интерфейс
		if tint.BackgroundTransparency < 1 and not portalHere then
			tint.BackgroundTransparency = math.min(1, tint.BackgroundTransparency + dt * 2)
		end
		if inWater and head == "water" then
			tint.BackgroundColor3, tint.BackgroundTransparency = rgb(30, 60, 200), 0.7
		elseif inLava then
			tint.BackgroundColor3, tint.BackgroundTransparency = rgb(255, 110, 0), 0.4
		end
		swingT = math.max(0, swingT - dt)
		hand.Rotation = -18 - math.sin(swingT / 0.25 * math.pi) * 35
		local bob = options.bobbing and wish.Magnitude > 0.1 and P.onGround and 12 or 0
		hand.Position = UDim2.fromOffset(1560 - math.sin(swingT / 0.25 * math.pi) * 60, 780 + math.abs(math.sin(G.time * (P.sprint and 9 or 6))) * bob)
		if G.hudDirty then
			hud.refresh()
		end
		coordsLabel.Visible = options.coords and not info.Visible
		if coordsLabel.Visible then
			coordsLabel.Text = string.format("Position: %d, %d, %d", math.floor(P.pos.X), math.floor(P.pos.Y), math.floor(P.pos.Z))
		end
		if info.Visible then
			local c = clockOf(G.time)
			info.Text = `BlockCraft 1.16.5 style  ·  {G.dim == "nether" and "The Nether" or "Overworld"}\nXYZ: {string.format("%.1f / %.1f / %.1f", P.pos.X, P.pos.Y, P.pos.Z)}\nTime: {string.format("%02d:%02d", math.floor(c), math.floor(c % 1 * 60))}  ·  Day {math.floor(G.time / DAY) + 1}\nMobs: {#G.mobs}  ·  Seed: {G.seed}`
		end
		saveTimer += dt
		if saveTimer > 15 then
			saveTimer = 0
			saveAll()
		end
	end)

	G.toTitle()
end

return BlockCraft
