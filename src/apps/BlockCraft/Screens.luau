-- Экраны BlockCraft в духе интерфейса Minecraft Java 1.16: главное меню, выбор и создание мира, настройки,
-- пауза, достижения, статистика, смерть и контейнеры (инвентарь 2×2, верстак 3×3, печь, творческий инвентарь).
-- Всё рисуется своими средствами (кнопки из каменной текстуры, панели со скосами), без файлов Mojang.
-- Масштаб: 1 пиксель интерфейса Minecraft = S точек холста 1920×1080.
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Screens = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local SPLASHES = {
	"Also try the PS5 Sandbox!", "100% blocks!", "Now with piglins!", "Made in Roblox!", "Hot nether action!",
	"Gold for everyone!", "Don't dig straight down!", "Punch a tree!", "Ancient debris inside!", "Square sun!",
	"Pixels included!", "Crafted with care!", "Watch out for creepers!", "Lava is hot!", "Bring a torch!",
}

-- топливо: сколько секунд горит (как в Minecraft: уголь 80 с, бревно и доски 15 с, палка 5 с)
local FUEL_TIME = {
	coal = 80, oak_log = 15, birch_log = 15, crimson_stem = 15, warped_stem = 15, oak_planks = 15, crimson_planks = 15,
	warped_planks = 15, stick = 5, crafting_table = 15,
}
local COOK_TIME = 10

function Screens.new(env)
	local ui, S, PIXEL, Content, Textures = env.ui, env.S, env.PIXEL, env.Content, env.Textures
	local ctx, G, inv = env.ctx, env.G, env.inv
	local canvas = env.canvas
	local api = {}
	local scr -- открытый экран
	local cursor -- стопка «в руке мыши»

	-- переплавка из рецептов печи: сырьё -> выход
	local SMELT = {}
	for _, r in Content.RECIPES do
		if r.station == "furnace" then
			local input, need
			local single = true
			for name, n in r.inputs do
				if name ~= "fuel" then
					if input then
						single = false
					end
					input, need = name, n
				end
			end
			if single and input then
				SMELT[input] = { output = r.output, count = r.count, need = need }
			end
		end
	end
	api.SMELT = SMELT
	local function fuelTime(name)
		return name and FUEL_TIME[name] or nil
	end

	-- ---------------------------------------------------------------- основа: текст, фон, кнопки
	local function new(class, props, children)
		return ui.new(class, props, children)
	end

	-- текст с тенью, как шрифт Minecraft
	local function stext(parent, text, props)
		props = props or {}
		local holder = new("Frame", {
			Size = props.Size or UDim2.fromOffset(600, 9 * S), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint,
			BackgroundTransparency = 1, Rotation = props.Rotation or 0, Parent = parent,
		})
		local function label(color, offset)
			return ui.text(text, {
				Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(offset, offset), TextSize = props.TextSize or 8 * S, Font = PIXEL,
				TextColor3 = color, TextXAlignment = props.X or Enum.TextXAlignment.Center, TextYAlignment = props.Y or Enum.TextYAlignment.Center,
				TextStrokeTransparency = 1, TextWrapped = props.Wrap or false, Parent = holder,
			})
		end
		local shadow = props.NoShadow and nil or label(props.Shadow or rgb(63, 63, 63), props.ShadowOffset or S)
		local main = label(props.Color or Color3.new(1, 1, 1), 0)
		local t = { holder = holder, main = main, shadow = shadow }
		function t.set(value, color)
			main.Text = value
			if shadow then
				shadow.Text = value
			end
			if color then
				main.TextColor3 = color
			end
		end
		return t
	end

	-- тёмный текст на серой панели (без тени)
	local function plain(parent, text, x, y, props)
		props = props or {}
		return ui.text(text, {
			Size = UDim2.fromOffset(props.w or 400, 9 * S), Position = UDim2.fromOffset(x, y), TextSize = props.TextSize or 8 * S, Font = PIXEL,
			TextColor3 = props.Color or rgb(64, 64, 64), TextXAlignment = props.X or Enum.TextXAlignment.Left, TextStrokeTransparency = 1, Parent = parent,
		})
	end

	local function tiled(parent, texName, tint, tile)
		local tex = Textures.Icon(texName)
		if tex then
			return new("ImageLabel", {
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ImageContent = tex, ScaleType = Enum.ScaleType.Tile,
				TileSize = UDim2.fromOffset(tile or 16 * S * 2, tile or 16 * S * 2), ResampleMode = Enum.ResamplerMode.Pixelated, ImageColor3 = tint, Parent = parent,
			})
		end
		return nil
	end

	-- скос: светлая кромка сверху-слева, тёмная снизу-справа
	local function bevel(parent, light, dark, width, lt, dt)
		width = width or S
		new("Frame", { Size = UDim2.new(1, 0, 0, width), BackgroundColor3 = light, BackgroundTransparency = lt or 0, BorderSizePixel = 0, Parent = parent })
		new("Frame", { Size = UDim2.new(0, width, 1, 0), BackgroundColor3 = light, BackgroundTransparency = lt or 0, BorderSizePixel = 0, Parent = parent })
		new("Frame", { Size = UDim2.new(1, 0, 0, width), Position = UDim2.new(0, 0, 1, -width), BackgroundColor3 = dark, BackgroundTransparency = dt or 0, BorderSizePixel = 0, Parent = parent })
		new("Frame", { Size = UDim2.new(0, width, 1, 0), Position = UDim2.new(1, -width, 0, 0), BackgroundColor3 = dark, BackgroundTransparency = dt or 0, BorderSizePixel = 0, Parent = parent })
	end

	-- серая панель окна (инвентарь, верстак, печь)
	local function panel(parent, x, y, w, h)
		local f = new("Frame", { Size = UDim2.fromOffset(w * S, h * S), Position = UDim2.fromOffset(x, y), BackgroundColor3 = rgb(198, 198, 198), BorderSizePixel = 0, Parent = parent }, {
			ui.stroke(rgb(0, 0, 0), S, 0),
		})
		bevel(f, rgb(255, 255, 255), rgb(85, 85, 85), 2 * S)
		return f
	end

	local function sprite(parent, name, rows, palette, x, y, size)
		local tex = Textures.Sprite(name, rows, palette)
		if not tex then
			return nil
		end
		return new("ImageLabel", {
			Size = UDim2.fromOffset(size, size), Position = UDim2.fromOffset(x, y), BackgroundTransparency = 1, ImageContent = tex,
			ResampleMode = Enum.ResamplerMode.Pixelated, Parent = parent,
		})
	end

	local ARROW = {
		"................", "................", "................", "................", ".........x......", ".........xx.....",
		"xxxxxxxxxxxxx...", "xxxxxxxxxxxxxx..", "xxxxxxxxxxxxx...", ".........xx.....", ".........x......",
	}
	local FLAME = {
		"................", "......x.........", ".....xx.....x...", ".....xxx...xx...", "....xxxx...xxx..", "...xxxxxx.xxxx..",
		"...xxxxxxxxxxx..", "..xxxxxxxxxxxxx.", "..xxxxxyyxxxxxx.", "..xxxxyyyyxxxxx.", "..xxxyyyyyyxxxx.", "...xxyyyyyyxxx..",
		"...xxxyyyyxxxx..", "....xxxxxxxxx...",
	}
	local BOOK = {
		"................", "..gggggggggggg..", "..gGGGGGGGGGGg..", "..gGwwwwwwwwGg..", "..gGwwwwwwwwGg..", "..gGGGGGGGGGGg..",
		"..gGwwwwwwwwGg..", "..gGwwwwwwwwGg..", "..gGGGGGGGGGGg..", "..gGwwwwwwwwGg..", "..gGGGGGGGGGGg..", "..gggggggggggg..",
	}

	-- ---------------------------------------------------------------- экран и фокус
	local function setFocus(w)
		if not scr or scr.focus == w then
			return
		end
		if scr.focus and scr.focus.paintFocus then
			scr.focus.paintFocus(false)
		end
		scr.focus = w
		if w and w.paintFocus then
			w.paintFocus(true)
		end
		if w and w.onFocus then
			w.onFocus()
		end
		if scr.onFocusChanged then
			scr.onFocusChanged(w)
		end
	end

	local function addFocusable(w)
		table.insert(scr.focusables, w)
		local g = w.gui
		g.MouseEnter:Connect(function()
			setFocus(w)
		end)
		return w
	end

	local function button(parent, text, x, y, w, onClick, opts)
		opts = opts or {}
		local h = opts.h or 20
		local b = new("TextButton", {
			Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(w * S, h * S), Position = UDim2.fromOffset(x, y),
			BackgroundColor3 = rgb(111, 111, 111), BorderSizePixel = 0, Parent = parent,
		})
		local stroke = ui.stroke(rgb(0, 0, 0), 2, 0)
		stroke.Parent = b
		local img = tiled(b, "stone", rgb(150, 150, 150), 16 * S)
		bevel(b, rgb(255, 255, 255), rgb(0, 0, 0), S, 0.6, 0.55)
		local label = stext(b, text, { Size = UDim2.fromScale(1, 1) })
		local wd = { gui = b, enabled = not opts.disabled, label = label }
		function wd.paintFocus(on)
			local hot = on and wd.enabled
			if img then
				img.ImageColor3 = not wd.enabled and rgb(60, 60, 60) or hot and rgb(160, 172, 235) or rgb(150, 150, 150)
			end
			b.BackgroundColor3 = not wd.enabled and rgb(44, 44, 44) or hot and rgb(126, 136, 191) or rgb(111, 111, 111)
			stroke.Color = hot and Color3.new(1, 1, 1) or rgb(0, 0, 0)
			label.main.TextColor3 = not wd.enabled and rgb(160, 160, 160) or hot and rgb(255, 255, 160) or Color3.new(1, 1, 1)
		end
		function wd.setText(t)
			label.set(t)
		end
		function wd.setEnabled(on)
			wd.enabled = on
			wd.paintFocus(scr and scr.focus == wd)
		end
		function wd.activate()
			if wd.enabled then
				ctx.audio:Play("confirm")
				onClick(wd)
			end
		end
		b.Activated:Connect(wd.activate)
		wd.paintFocus(false)
		return addFocusable(wd)
	end

	-- ползунок: подпись внутри, ручка из кнопки, тянется мышью, геймпадом — влево/вправо
	local function slider(parent, x, y, w, min, max, step, value, labelFn, onChange)
		local b = new("TextButton", {
			Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(w * S, 20 * S), Position = UDim2.fromOffset(x, y),
			BackgroundColor3 = rgb(40, 40, 40), BorderSizePixel = 0, Parent = parent,
		})
		local stroke = ui.stroke(rgb(0, 0, 0), 2, 0)
		stroke.Parent = b
		tiled(b, "stone", rgb(60, 60, 60), 16 * S)
		local knob = new("Frame", { Size = UDim2.fromOffset(8 * S, 20 * S), BackgroundColor3 = rgb(111, 111, 111), BorderSizePixel = 0, Parent = b })
		local knobImg = tiled(knob, "stone", rgb(150, 150, 150), 16 * S)
		bevel(knob, rgb(255, 255, 255), rgb(0, 0, 0), S, 0.6, 0.4)
		local label = stext(b, "", { Size = UDim2.fromScale(1, 1) })
		local wd = { gui = b, value = value, slider = true }
		local function paint()
			local k = (wd.value - min) / (max - min)
			knob.Position = UDim2.new(k, -k * 8 * S, 0, 0)
			label.set(labelFn(wd.value))
		end
		local function set(v)
			v = math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
			if v ~= wd.value then
				wd.value = v
				paint()
				onChange(v)
			end
		end
		function wd.paintFocus(on)
			stroke.Color = on and Color3.new(1, 1, 1) or rgb(0, 0, 0)
			if knobImg then
				knobImg.ImageColor3 = on and rgb(160, 172, 235) or rgb(150, 150, 150)
			end
		end
		function wd.nudge(dir)
			set(wd.value + dir * step)
		end
		function wd.activate() end
		local dragging = false
		local function fromMouse(px)
			local a, s = b.AbsolutePosition.X, b.AbsoluteSize.X
			if s > 0 then
				set(min + (max - min) * math.clamp((px - a) / s, 0, 1))
			end
		end
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				fromMouse(input.Position.X)
			end
		end)
		scr.connections = scr.connections or {}
		table.insert(scr.connections, UserInputService.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				fromMouse(input.Position.X)
			end
		end))
		table.insert(scr.connections, UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end))
		paint()
		return addFocusable(wd)
	end

	local function textField(parent, x, y, w, text, placeholder)
		local box = new("Frame", { Size = UDim2.fromOffset(w * S, 20 * S), Position = UDim2.fromOffset(x, y), BackgroundColor3 = rgb(0, 0, 0), BorderSizePixel = 0, Parent = parent }, {
			ui.stroke(rgb(160, 160, 160), S, 0),
		})
		local tb = new("TextBox", {
			Size = UDim2.new(1, -8 * S, 1, 0), Position = UDim2.fromOffset(4 * S, 0), BackgroundTransparency = 1, Text = text or "", PlaceholderText = placeholder or "",
			PlaceholderColor3 = rgb(112, 112, 112), Font = PIXEL, TextSize = 8 * S, TextColor3 = rgb(224, 224, 224), TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false, Parent = box,
		})
		local wd = { gui = tb, box = box }
		function wd.paintFocus(on)
			box:FindFirstChildOfClass("UIStroke").Color = on and Color3.new(1, 1, 1) or rgb(160, 160, 160)
		end
		function wd.activate()
			pcall(tb.CaptureFocus, tb)
		end
		return addFocusable(wd)
	end

	-- корень экрана
	local function begin(name, opts)
		opts = opts or {}
		local root = new("Frame", { Name = "Screen_" .. name, Size = UDim2.fromOffset(1920, 1080), BackgroundTransparency = 1, ZIndex = 20, Parent = canvas })
		if opts.bg == "dirt" then
			root.BackgroundColor3 = rgb(40, 30, 20)
			root.BackgroundTransparency = 0
			tiled(root, "dirt", rgb(64, 64, 64))
		elseif opts.bg == "dim" then
			root.BackgroundColor3 = rgb(16, 16, 16)
			root.BackgroundTransparency = 0.3
		elseif opts.bg == "red" then
			root.BackgroundTransparency = 1
			new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = root }, {
				ui.gradient({ rgb(80, 0, 0), rgb(160, 48, 48) }, 90, NumberSequence.new(0.4, 0.38)),
			})
		end
		scr = { name = name, root = root, focusables = {}, connections = {}, blocks = opts.blocks ~= false, pausesGame = opts.pausesGame, container = opts.container }
		return root
	end

	local function title(root, text, y)
		stext(root, text, { Size = UDim2.fromOffset(1920, 9 * S), Position = UDim2.fromOffset(0, y or 20 * S) })
	end

	function api.close()
		if not scr then
			return
		end
		local old = scr
		if old.onClose then
			old.onClose()
		end
		for _, c in old.connections do
			c:Disconnect()
		end
		old.root:Destroy()
		if scr == old then
			scr = nil
		end
		G.hudDirty = true
		if env.onScreenClosed then
			env.onScreenClosed(old.name)
		end
	end

	local builders = {}
	function api.open(name, args)
		if scr then
			api.close()
		end
		builders[name](args or {})
		if scr then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
			if not scr.focus and scr.focusables[scr.firstFocus or 1] then
				setFocus(scr.focusables[scr.firstFocus or 1])
			end
		end
	end

	function api.current()
		return scr and scr.name or nil
	end
	function api.isOpen()
		return scr ~= nil
	end
	function api.isContainer()
		return scr ~= nil and scr.container == true
	end
	function api.focusables()
		return scr and scr.focusables or {}
	end
	function api.focus()
		return scr and scr.focus
	end

	-- ---------------------------------------------------------------- геймпад и клавиши: перемещение фокуса по геометрии
	local function center(w)
		local g = w.gui
		return g.AbsolutePosition + g.AbsoluteSize / 2
	end
	local function visible(w)
		local g = w.gui
		while g and g:IsA("GuiObject") do
			if not g.Visible then
				return false
			end
			g = g.Parent
		end
		return true
	end
	local function navigate(dx, dy)
		if not scr then
			return
		end
		local list = {}
		for _, w in scr.focusables do
			if visible(w) and (not w.enabledCheck or w.enabledCheck()) then
				table.insert(list, w)
			end
		end
		local cur = scr.focus
		if not cur then
			setFocus(list[1])
			return
		end
		local c = center(cur)
		local best, bestScore
		for _, w in list do
			if w ~= cur then
				local d = center(w) - c
				local along = d.X * dx + d.Y * dy
				if along > 2 then
					local perp = math.abs(d.X * dy - d.Y * dx)
					local score = along + perp * 2.5
					if not bestScore or score < bestScore then
						best, bestScore = w, score
					end
				end
			end
		end
		if not best then
			-- без раскладки (тест без экрана): просто по списку
			local idx = table.find(list, cur) or 1
			local zero = c.Magnitude < 1
			if zero then
				best = list[math.clamp(idx + ((dx + dy) > 0 and 1 or -1), 1, #list)]
			end
		end
		if best then
			setFocus(best)
			ctx.audio:Play("move")
		end
	end

	-- ✕ / Enter / Space: нажать; квадрат: правый клик по ячейке; ○ / Backspace: назад
	function api.press(btn)
		if not scr then
			return false
		end
		local ok, focused = pcall(UserInputService.GetFocusedTextBox, UserInputService)
		if ok and focused then
			return true
		end
		local f = scr.focus
		if btn == "up" then
			navigate(0, -1)
		elseif btn == "down" then
			navigate(0, 1)
		elseif btn == "left" then
			if f and f.slider then
				f.nudge(-1)
			else
				navigate(-1, 0)
			end
		elseif btn == "right" then
			if f and f.slider then
				f.nudge(1)
			else
				navigate(1, 0)
			end
		elseif btn == "cross" then
			if f then
				if f.slot then
					f.click(1, false)
				else
					f.activate()
				end
			end
		elseif btn == "square" then
			if f and f.slot then
				f.click(2, false)
			end
		elseif btn == "triangle" then
			if f and f.slot then
				f.click(1, true)
			elseif scr.back then
				scr.back()
			end
		elseif btn == "circle" or btn == "options" then
			if scr.back then
				scr.back()
			end
		elseif btn == "l1" or btn == "r1" then
			if scr.tab then
				scr.tab(btn == "l1" and -1 or 1)
			end
		end
		return true
	end

	-- ---------------------------------------------------------------- главное меню
	local LOGO_Y = 30 * S
	builders.title = function()
		local root = begin("title", { pausesGame = false })
		-- лёгкое затемнение поверх панорамы мира
		new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(0, 0, 0), BorderSizePixel = 0, Parent = root }, {
			ui.gradient({ rgb(0, 0, 0), rgb(0, 0, 0) }, 90, NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 0.6) })),
		})
		-- логотип: каменные буквы с тёмной обводкой и объёмной тенью
		local logo = new("Frame", { Size = UDim2.fromOffset(1200, 160), Position = UDim2.fromOffset(360, LOGO_Y), BackgroundTransparency = 1, Parent = root })
		for i = 3, 1, -1 do
			ui.text("BLOCKCRAFT", {
				Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(i * 4, i * 4), TextSize = 150, Font = PIXEL, TextColor3 = rgb(30, 30, 30),
				TextXAlignment = Enum.TextXAlignment.Center, Parent = logo,
			})
		end
		local face = ui.text("BLOCKCRAFT", {
			Size = UDim2.fromScale(1, 1), TextSize = 150, Font = PIXEL, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0, TextStrokeColor3 = rgb(20, 20, 20), Parent = logo,
		})
		ui.gradient({ rgb(220, 220, 220), rgb(150, 150, 150), rgb(110, 110, 110) }, 90).Parent = face
		local edition = new("Frame", { Size = UDim2.fromOffset(420, 40), Position = UDim2.fromOffset(750, LOGO_Y + 168), BackgroundTransparency = 1, Parent = root })
		stext(edition, "SANDBOX EDITION", { Size = UDim2.fromScale(1, 1), TextSize = 9 * S, Color = rgb(220, 200, 150), Shadow = rgb(60, 40, 20) })
		-- жёлтая надпись-сплэш, наклонена и пульсирует
		local splash = stext(root, SPLASHES[math.random(#SPLASHES)], {
			Size = UDim2.fromOffset(600, 40), Position = UDim2.fromOffset(1440, LOGO_Y + 150), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = -20,
			TextSize = 8 * S, Color = rgb(255, 255, 0), Shadow = rgb(63, 63, 0),
		})
		local scale = new("UIScale", { Parent = splash.holder })
		local t0 = os.clock()
		table.insert(scr.connections, RunService.RenderStepped:Connect(function()
			local t = (os.clock() - t0) % 1
			scale.Scale = 1 - math.abs(math.sin(t * math.pi * 2)) * 0.08
		end))

		local cx = 960 - 100 * S
		local y0 = 138 * S - 20
		button(root, "Singleplayer", cx, y0, 200, function()
			api.open("worlds")
		end)
		button(root, "Multiplayer", cx, y0 + 24 * S, 200, function() end, { disabled = true })
		button(root, "Achievements", cx, y0 + 48 * S, 200, function()
			api.open("advancements", { back = "title" })
		end)
		button(root, "Options...", cx, y0 + 84 * S, 98, function()
			api.open("options", { back = "title" })
		end)
		button(root, "Quit Game", cx + 102 * S, y0 + 84 * S, 98, function()
			env.quit()
		end)
		stext(root, "BlockCraft 1.16.5", { Size = UDim2.fromOffset(600, 10 * S), Position = UDim2.fromOffset(2 * S, 1080 - 11 * S), X = Enum.TextXAlignment.Left })
		stext(root, "Fan-made in PS5 Sandbox. Not affiliated with Mojang.", {
			Size = UDim2.fromOffset(1200, 10 * S), Position = UDim2.fromOffset(1920 - 1200 - 2 * S, 1080 - 11 * S), X = Enum.TextXAlignment.Right,
		})
		scr.back = function()
			env.quit()
		end
	end

	-- ---------------------------------------------------------------- выбор мира
	local function dateText(t)
		local ok, s = pcall(os.date, "%m/%d/%y %I:%M %p", t or 0)
		return ok and s or ""
	end

	builders.worlds = function()
		local root = begin("worlds", { bg = "dirt" })
		title(root, "Select World", 8 * S)
		-- тёмная область списка между шапкой и подвалом
		local listTop, listBottom = 32 * S, 1080 - 64 * S
		local area = new("Frame", { Size = UDim2.fromOffset(1920, listBottom - listTop), Position = UDim2.fromOffset(0, listTop), BackgroundColor3 = rgb(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, Parent = root })
		new("Frame", { Size = UDim2.new(1, 0, 0, S), BackgroundColor3 = rgb(0, 0, 0), BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = area })
		new("Frame", { Size = UDim2.new(1, 0, 0, S), Position = UDim2.new(0, 0, 1, -S), BackgroundColor3 = rgb(0, 0, 0), BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = area })
		local list = new("ScrollingFrame", {
			Size = UDim2.fromOffset(270 * S + 40, listBottom - listTop - 8), Position = UDim2.fromOffset(960 - 135 * S, 4), BackgroundTransparency = 1, BorderSizePixel = 0,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2 * S, ScrollBarImageColor3 = rgb(192, 192, 192), Parent = area,
		}, { ui.list(Enum.FillDirection.Vertical, 0) })
		local selectedId
		local playBtn, deleteBtn
		local entries = {}
		local worlds = env.listWorlds()
		local function paintEntries()
			for _, e in entries do
				local on = e.id == selectedId
				e.frame.BackgroundTransparency = on and 0.6 or 1
				e.stroke.Transparency = on and 0 or 1
			end
			playBtn.setEnabled(selectedId ~= nil)
			deleteBtn.setEnabled(selectedId ~= nil)
		end
		for i, w in worlds do
			local f = new("TextButton", {
				Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(270 * S, 36 * S), BackgroundColor3 = rgb(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
				LayoutOrder = i, Parent = list,
			})
			local stroke = ui.stroke(rgb(128, 128, 128), S, 1)
			stroke.Parent = f
			local iconBox = new("Frame", { Size = UDim2.fromOffset(32 * S, 32 * S), Position = UDim2.fromOffset(2 * S, 2 * S), BackgroundColor3 = rgb(30, 30, 30), BorderSizePixel = 0, Parent = f })
			env.icon(iconBox, { n = w.mode == "creative" and "diamond_block" or "grass_block", c = 1 }, 32 * S)
			stext(f, w.name, { Size = UDim2.fromOffset(230 * S, 10 * S), Position = UDim2.fromOffset(36 * S, 2 * S), X = Enum.TextXAlignment.Left })
			stext(f, `World {w.id} ({dateText(w.last)})`, { Size = UDim2.fromOffset(230 * S, 10 * S), Position = UDim2.fromOffset(36 * S, 13 * S), X = Enum.TextXAlignment.Left, Color = rgb(128, 128, 128), NoShadow = true })
			stext(f, (w.mode == "creative" and "Creative Mode" or "Survival Mode") .. (w.difficulty and (", " .. w.difficulty) or ""), {
				Size = UDim2.fromOffset(230 * S, 10 * S), Position = UDim2.fromOffset(36 * S, 23 * S), X = Enum.TextXAlignment.Left, Color = rgb(128, 128, 128), NoShadow = true,
			})
			local e = { id = w.id, frame = f, stroke = stroke, gui = f }
			local lastClick = 0
			function e.activate()
				if selectedId == w.id and os.clock() - lastClick < 0.4 then
					env.playWorld(w.id)
					return
				end
				lastClick = os.clock()
				selectedId = w.id
				paintEntries()
			end
			function e.paintFocus(on)
				if on then
					selectedId = w.id
					paintEntries()
				end
			end
			f.Activated:Connect(e.activate)
			table.insert(entries, e)
			addFocusable(e)
		end
		local by = 1080 - 52 * S
		playBtn = button(root, "Play Selected World", 960 - 154 * S, by, 150, function()
			if selectedId then
				env.playWorld(selectedId)
			end
		end)
		button(root, "Create New World", 960 + 4 * S, by, 150, function()
			api.open("create")
		end)
		button(root, "Edit", 960 - 154 * S, by + 24 * S, 72, function() end, { disabled = true })
		deleteBtn = button(root, "Delete", 960 - 76 * S, by + 24 * S, 72, function()
			if selectedId then
				api.open("confirmDelete", { id = selectedId })
			end
		end)
		button(root, "Re-Create", 960 + 4 * S, by + 24 * S, 72, function() end, { disabled = true })
		button(root, "Cancel", 960 + 82 * S, by + 24 * S, 72, function()
			api.open("title")
		end)
		if worlds[1] then
			selectedId = worlds[1].id
		end
		paintEntries()
		scr.firstFocus = #worlds > 0 and 1 or (table.find(scr.focusables, playBtn) or 1) + 1
		scr.back = function()
			api.open("title")
		end
	end

	builders.confirmDelete = function(args)
		local root = begin("confirmDelete", { bg = "dirt" })
		local name = "this world"
		for _, w in env.listWorlds() do
			if w.id == args.id then
				name = w.name
			end
		end
		stext(root, "Are you sure you want to delete this world?", { Size = UDim2.fromOffset(1920, 10 * S), Position = UDim2.fromOffset(0, 70 * S) })
		stext(root, `'{name}' will be lost forever! (A long time!)`, { Size = UDim2.fromOffset(1920, 10 * S), Position = UDim2.fromOffset(0, 90 * S) })
		button(root, "Delete", 960 - 154 * S, 140 * S, 150, function()
			env.deleteWorld(args.id)
			api.open("worlds")
		end)
		button(root, "Cancel", 960 + 4 * S, 140 * S, 150, function()
			api.open("worlds")
		end)
		scr.firstFocus = 2
		scr.back = function()
			api.open("worlds")
		end
	end

	-- ---------------------------------------------------------------- создание мира
	local MODE_TEXT = {
		survival = { "Search for resources, craft, gain", "levels, health and hunger" },
		creative = { "Unlimited resources, free flying and", "destroy blocks instantly" },
	}
	local DIFFICULTIES = { "Peaceful", "Easy", "Normal", "Hard" }
	builders.create = function()
		local root = begin("create", { bg = "dirt" })
		title(root, "Create New World", 20 * S)
		local cx = 960 - 100 * S
		plain(root, "World Name", cx, 47 * S, { Color = rgb(160, 160, 160) })
		local nameField = textField(root, cx, 60 * S, 200, "New World")
		local savedAs = plain(root, "Will be saved in: New World", cx, 85 * S, { Color = rgb(160, 160, 160), w = 600 })
		nameField.gui:GetPropertyChangedSignal("Text"):Connect(function()
			savedAs.Text = "Will be saved in: " .. (nameField.gui.Text ~= "" and nameField.gui.Text or "World")
		end)
		local mode, diff = "survival", "Normal"
		local desc1 = stext(root, MODE_TEXT.survival[1], { Size = UDim2.fromOffset(1920, 10 * S), Position = UDim2.fromOffset(0, 123 * S), Color = rgb(160, 160, 160) })
		local desc2 = stext(root, MODE_TEXT.survival[2], { Size = UDim2.fromOffset(1920, 10 * S), Position = UDim2.fromOffset(0, 134 * S), Color = rgb(160, 160, 160) })
		button(root, "Game Mode: Survival", cx, 100 * S, 200, function(b)
			mode = mode == "survival" and "creative" or "survival"
			b.setText("Game Mode: " .. (mode == "creative" and "Creative" or "Survival"))
			desc1.set(MODE_TEXT[mode][1])
			desc2.set(MODE_TEXT[mode][2])
		end)
		button(root, "Difficulty: Normal", cx, 148 * S, 200, function(b)
			diff = DIFFICULTIES[(table.find(DIFFICULTIES, diff) or 3) % #DIFFICULTIES + 1]
			b.setText("Difficulty: " .. diff)
		end)
		local seedLabel = plain(root, "Seed for the world generator", cx, 196 * S, { Color = rgb(160, 160, 160), w = 600 })
		local seedField = textField(root, cx, 208 * S, 200, "", "Leave blank for a random seed")
		seedLabel.Visible, seedField.box.Visible = false, false
		button(root, "More World Options...", cx, 172 * S, 200, function(b)
			local show = not seedField.box.Visible
			seedLabel.Visible, seedField.box.Visible = show, show
			b.setText(show and "Done" or "More World Options...")
		end)
		local by = 1080 - 28 * S
		local createBtn = button(root, "Create New World", 960 - 154 * S, by, 150, function()
			local seedText = seedField.gui.Text
			local seed = tonumber(seedText)
			if not seed and seedText ~= "" then
				-- текстовый сид превращается в число, как в Minecraft
				seed = 0
				for i = 1, #seedText do
					seed = (seed * 31 + string.byte(seedText, i)) % 1000000007
				end
			end
			env.createWorld(nameField.gui.Text ~= "" and nameField.gui.Text or "New World", mode, seed, diff)
		end)
		button(root, "Cancel", 960 + 4 * S, by, 150, function()
			api.open("worlds")
		end)
		-- с геймпада сразу «Create New World»: имя и режим можно поменять стрелками
		scr.firstFocus = table.find(scr.focusables, createBtn) or 1
		scr.back = function()
			api.open("worlds")
		end
	end

	-- ---------------------------------------------------------------- настройки
	builders.options = function(args)
		local fromGame = args.back == "pause"
		local root = begin("options", { bg = fromGame and "dim" or "dirt" })
		title(root, "Options", 15 * S)
		local o = env.options
		local lx, rx = 960 - 155 * S, 960 + 5 * S
		local y = 1080 / 6 - 12 * S
		slider(root, lx, y, 150, 30, 110, 1, o.fov, function(v)
			return v == 70 and "FOV: Normal" or v == 110 and "FOV: Quake Pro" or `FOV: {v}`
		end, function(v)
			o.fov = v
			env.saveOptions()
		end)
		button(root, "Difficulty: " .. (o.difficulty or "Normal"), rx, y, 150, function(b)
			o.difficulty = DIFFICULTIES[(table.find(DIFFICULTIES, o.difficulty or "Normal") or 3) % #DIFFICULTIES + 1]
			b.setText("Difficulty: " .. o.difficulty)
			env.saveOptions()
		end)
		slider(root, lx, y + 24 * S, 150, 2, 6, 1, o.render, function(v)
			return `Render Distance: {v} chunks`
		end, function(v)
			o.render = v
			env.saveOptions()
		end)
		slider(root, rx, y + 24 * S, 150, 10, 200, 5, o.sensitivity, function(v)
			return `Sensitivity: {v}%`
		end, function(v)
			o.sensitivity = v
			env.saveOptions()
		end)
		button(root, "View Bobbing: " .. (o.bobbing and "ON" or "OFF"), lx, y + 48 * S, 150, function(b)
			o.bobbing = not o.bobbing
			b.setText("View Bobbing: " .. (o.bobbing and "ON" or "OFF"))
			env.saveOptions()
		end)
		button(root, "Show Coordinates: " .. (o.coords and "ON" or "OFF"), rx, y + 48 * S, 150, function(b)
			o.coords = not o.coords
			b.setText("Show Coordinates: " .. (o.coords and "ON" or "OFF"))
			env.saveOptions()
		end)
		local function back()
			api.open(args.back or "title")
		end
		button(root, "Done", 960 - 100 * S, 1080 / 6 + 156 * S, 200, back)
		scr.back = back
	end

	-- ---------------------------------------------------------------- пауза
	builders.pause = function()
		local root = begin("pause", { bg = "dim", pausesGame = true })
		title(root, "Game Menu", 40 * S)
		local cx = 960 - 102 * S
		local y = 1080 / 4 + 8 * S
		local function resume()
			api.close()
			env.resume()
		end
		button(root, "Back to Game", cx, y, 204, resume)
		button(root, "Advancements", cx, y + 24 * S, 98, function()
			api.open("advancements", { back = "pause" })
		end)
		button(root, "Statistics", cx + 106 * S, y + 24 * S, 98, function()
			api.open("statistics")
		end)
		button(root, "Give Feedback", cx, y + 48 * S, 98, function() end, { disabled = true })
		button(root, "Report Bugs", cx + 106 * S, y + 48 * S, 98, function() end, { disabled = true })
		button(root, "Options...", cx, y + 72 * S, 98, function()
			api.open("options", { back = "pause" })
		end)
		button(root, "Open to LAN", cx + 106 * S, y + 72 * S, 98, function() end, { disabled = true })
		button(root, "Save and Quit to Title", cx, y + 96 * S, 204, function()
			env.saveAndQuit()
		end)
		scr.back = resume
	end

	-- ---------------------------------------------------------------- достижения (трофеи игры)
	builders.advancements = function(args)
		local root = begin("advancements", { bg = args.back == "pause" and "dim" or "dirt", pausesGame = args.back == "pause" })
		local w, h = 252, 140
		local x, y = 960 - w * S / 2, 540 - h * S / 2
		local win = panel(root, x, y, w, h)
		plain(win, "Advancements", 8 * S, 5 * S)
		-- земля фоном под списком (отдельно: внутри списка она заняла бы первую строку)
		local back = new("Frame", { Size = UDim2.fromOffset((w - 18) * S, (h - 27) * S), Position = UDim2.fromOffset(9 * S, 18 * S), BackgroundColor3 = rgb(40, 30, 20), BorderSizePixel = 0, Parent = win })
		tiled(back, "dirt", rgb(90, 90, 90))
		local inner = new("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2 * S, Parent = back,
		}, { ui.list(Enum.FillDirection.Vertical, S), ui.padding(2 * S) })
		local list = ctx.trophies:List() or {}
		for i, t in list do
			local row = new("Frame", { Size = UDim2.new(1, -4 * S, 0, 24 * S), BackgroundColor3 = t.unlocked and rgb(196, 160, 30) or rgb(60, 60, 60), BorderSizePixel = 0, LayoutOrder = i, Parent = inner }, {
				ui.stroke(rgb(0, 0, 0), 2, 0),
			})
			local frameBox = new("Frame", { Size = UDim2.fromOffset(22 * S, 22 * S), Position = UDim2.fromOffset(S, S), BackgroundColor3 = t.unlocked and rgb(240, 200, 60) or rgb(160, 160, 160), BorderSizePixel = 0, Parent = row })
			local ICONS = {
				stone_age = "wooden_pickaxe", getting_upgrade = "stone_pickaxe", acquire_hardware = "iron_ingot", diamonds = "diamond",
				we_need_to_go_deeper = "obsidian", hidden_in_depths = "ancient_debris", netherite_tool = "netherite_pickaxe",
				monster_hunter = "iron_sword", oh_shiny = "gold_ingot", platinum = "netherite_block",
			}
			env.icon(frameBox, { n = ICONS[t.id] or "grass_block", c = 1 }, 22 * S)
			stext(row, t.name, { Size = UDim2.new(1, -30 * S, 0, 10 * S), Position = UDim2.fromOffset(26 * S, 2 * S), X = Enum.TextXAlignment.Left, Color = t.unlocked and rgb(255, 255, 85) or Color3.new(1, 1, 1) })
			stext(row, t.description or "", { Size = UDim2.new(1, -30 * S, 0, 10 * S), Position = UDim2.fromOffset(26 * S, 12 * S), X = Enum.TextXAlignment.Left, TextSize = 7 * S, Color = rgb(200, 200, 200) })
		end
		local function back()
			api.open(args.back or "title")
		end
		button(root, "Done", 960 - 100 * S, y + h * S + 8 * S, 200, back)
		scr.back = back
	end

	-- ---------------------------------------------------------------- статистика
	builders.statistics = function()
		local root = begin("statistics", { bg = "dim", pausesGame = true })
		title(root, "Statistics", 20 * S)
		local st = G.stats or {}
		local function minutes(s)
			s = math.floor(s or 0)
			return string.format("%dh %dm", s // 3600, (s % 3600) // 60)
		end
		local rows = {
			{ "Time Played", minutes(st.played) },
			{ "Blocks Mined", tostring(st.mined or 0) },
			{ "Blocks Placed", tostring(st.placed or 0) },
			{ "Mobs Killed", tostring(st.kills or 0) },
			{ "Deaths", tostring(st.deaths or 0) },
			{ "Distance Walked", string.format("%.1f km", (st.walked or 0) / 1000) },
			{ "Items Crafted", tostring(st.crafted or 0) },
			{ "Jumps", tostring(st.jumps or 0) },
		}
		local box = new("Frame", { Size = UDim2.fromOffset(220 * S, #rows * 12 * S + 6 * S), Position = UDim2.fromOffset(960 - 110 * S, 40 * S), BackgroundColor3 = rgb(0, 0, 0), BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = root })
		for i, r in rows do
			local y = 3 * S + (i - 1) * 12 * S
			if i % 2 == 0 then
				new("Frame", { Size = UDim2.new(1, 0, 0, 12 * S), Position = UDim2.fromOffset(0, y), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.92, BorderSizePixel = 0, Parent = box })
			end
			stext(box, r[1], { Size = UDim2.new(1, -8 * S, 0, 12 * S), Position = UDim2.fromOffset(4 * S, y), X = Enum.TextXAlignment.Left })
			stext(box, r[2], { Size = UDim2.new(1, -8 * S, 0, 12 * S), Position = UDim2.fromOffset(4 * S, y), X = Enum.TextXAlignment.Right })
		end
		local function back()
			api.open("pause")
		end
		button(root, "Done", 960 - 100 * S, 1080 - 30 * S, 200, back)
		scr.back = back
	end

	-- ---------------------------------------------------------------- смерть
	builders.death = function(args)
		local root = begin("death", { bg = "red", pausesGame = true })
		local big = new("Frame", { Size = UDim2.fromOffset(1920, 20 * S), Position = UDim2.fromOffset(0, 60 * S), BackgroundTransparency = 1, Parent = root })
		stext(big, "You Died!", { Size = UDim2.fromScale(1, 1), TextSize = 16 * S, ShadowOffset = 2 * S })
		if args.cause then
			stext(root, args.cause, { Size = UDim2.fromOffset(1920, 10 * S), Position = UDim2.fromOffset(0, 85 * S) })
		end
		local score = new("Frame", { Size = UDim2.fromOffset(1920, 10 * S), Position = UDim2.fromOffset(0, 100 * S), BackgroundTransparency = 1, Parent = root })
		-- «Score:» белым, число жёлтым; у тени тот же текст без разметки
		local scoreText = stext(score, `Score: {args.score or 0}`, { Size = UDim2.fromScale(1, 1) })
		scoreText.main.RichText = true
		scoreText.main.Text = `Score: <font color="#FFFF55">{args.score or 0}</font>`
		local r = button(root, "Respawn", 960 - 100 * S, 1080 / 4 + 72 * S, 200, function()
			api.close()
			env.respawn()
		end)
		local t = button(root, "Title Screen", 960 - 100 * S, 1080 / 4 + 96 * S, 200, function()
			env.saveAndQuit()
		end)
		-- кнопки оживают через секунду, чтобы не нажать случайно
		r.setEnabled(false)
		t.setEnabled(false)
		task.delay(1, function()
			if scr and scr.name == "death" then
				r.setEnabled(true)
				t.setEnabled(true)
			end
		end)
		scr.back = nil
	end

	-- ================================================================ контейнеры
	local SLOT = 18 * S
	local function stackSize(name)
		return Content.StackSize(name)
	end
	local function same(a, b)
		return a and b and a.n == b.n
	end
	local function copy(s)
		return s and { n = s.n, c = s.c, d = s.d } or nil
	end

	-- общий каркас окна-контейнера: затемнение, курсор-стопка, подсказка
	local function beginContainer(name)
		local root = begin(name, { bg = "dim", container = true, pausesGame = false })
		root.BackgroundTransparency = 0.35
		scr.slots = {}
		return root
	end

	local cursorFrame, tooltip
	local function paintCursor()
		if not cursorFrame then
			return
		end
		cursorFrame:ClearAllChildren()
		if cursor then
			env.icon(cursorFrame, cursor, 16 * S)
		end
	end

	local function itemLabel(stack)
		local info = Content.Info(stack.n)
		return info and info.label or stack.n
	end

	local function showTooltip(w)
		if not tooltip then
			return
		end
		local s = w and w.slot and w.get()
		if not s or cursor then
			tooltip.Visible = false
			return
		end
		tooltip.Visible = true
		local lines = { itemLabel(s) }
		local info = Content.ITEMS[s.n]
		if info and info.durability and s.d then
			table.insert(lines, `Durability: {s.d} / {info.durability}`)
		end
		if info and info.food then
			table.insert(lines, `Food: +{info.food}`)
		end
		local label = tooltip:FindFirstChild("Text")
		local text = lines[1]
		for i = 2, #lines do
			text ..= `\n<font color="#AAAAAA">{lines[i]}</font>`
		end
		label.Text = text
		tooltip.Size = UDim2.fromOffset(math.max(120, #lines[1] * 6 * S + 12 * S), (#lines * 10 + 6) * S)
		local g = w.gui
		local inset = canvas.AbsolutePosition
		local scaleObj = canvas:FindFirstChildOfClass("UIScale")
		local k = scaleObj and scaleObj.Scale or 1
		local p = (g.AbsolutePosition - inset) / k
		tooltip.Position = UDim2.fromOffset(p.X + SLOT + 4 * S, p.Y - 12 * S)
	end

	local function setupOverlay(root)
		cursorFrame = new("Frame", { Name = "Cursor", Size = UDim2.fromOffset(16 * S, 16 * S), BackgroundTransparency = 1, ZIndex = 5, Parent = root })
		tooltip = new("Frame", { Name = "Tooltip", Visible = false, BackgroundColor3 = rgb(16, 0, 16), BackgroundTransparency = 0.06, BorderSizePixel = 0, ZIndex = 6, Parent = root }, {
			ui.stroke(rgb(40, 0, 110), S, 0),
		})
		ui.text("", {
			Name = "Text", Size = UDim2.new(1, -6 * S, 1, -4 * S), Position = UDim2.fromOffset(3 * S, 2 * S), TextSize = 8 * S, Font = PIXEL, RichText = true,
			TextColor3 = Color3.new(1, 1, 1), TextYAlignment = Enum.TextYAlignment.Top, TextStrokeTransparency = 1, ZIndex = 6, Parent = tooltip,
		})
		local follow = RunService.RenderStepped:Connect(function()
			if not cursorFrame.Parent then
				return
			end
			local okType, lastType = pcall(UserInputService.GetLastInputType, UserInputService)
			if okType and lastType == Enum.UserInputType.Gamepad1 and scr and scr.focus and scr.focus.slot then
				local g = scr.focus.gui
				local inset = canvas.AbsolutePosition
				local scaleObj = canvas:FindFirstChildOfClass("UIScale")
				local k = scaleObj and scaleObj.Scale or 1
				local p = (g.AbsolutePosition - inset) / k
				cursorFrame.Position = UDim2.fromOffset(p.X + 8 * S, p.Y + 8 * S)
				return
			end
			local ok, mouse = pcall(UserInputService.GetMouseLocation, UserInputService)
			if ok and mouse then
				local inset = canvas.AbsolutePosition
				local scaleObj = canvas:FindFirstChildOfClass("UIScale")
				local k = scaleObj and scaleObj.Scale or 1
				cursorFrame.Position = UDim2.fromOffset((mouse.X - inset.X) / k - 8 * S, (mouse.Y - 36 - inset.Y) / k - 8 * S)
			end
		end)
		table.insert(scr.connections, follow)
		scr.onFocusChanged = showTooltip
	end

	local function shiftDown()
		local ok, down = pcall(UserInputService.IsKeyDown, UserInputService, Enum.KeyCode.LeftShift)
		return ok and down
	end

	-- ячейка: get/set — где лежит стопка; kind: nil (обычная), "output", "palette", "trash"
	local function slot(parent, x, y, get, set, opts)
		opts = opts or {}
		local big = opts.big
		local size = big and 26 * S or SLOT
		local b = new("TextButton", {
			Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(size, size), Position = UDim2.fromOffset(x - (big and 4 * S or 0), y - (big and 4 * S or 0)),
			BackgroundColor3 = rgb(139, 139, 139), BorderSizePixel = 0, Parent = parent,
		})
		if not opts.flat then
			bevel(b, rgb(55, 55, 55), rgb(255, 255, 255), S)
		end
		local holder = new("Frame", { Size = UDim2.fromOffset(16 * S, 16 * S), Position = UDim2.fromOffset((size - 16 * S) / 2, (size - 16 * S) / 2), BackgroundTransparency = 1, Parent = b })
		local hover = new("Frame", { Size = UDim2.fromOffset(16 * S, 16 * S), Position = holder.Position, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2, Parent = b })
		local ghost = opts.ghost and sprite(b, "ghost_" .. opts.ghost, opts.ghostRows, { x = rgb(110, 110, 110) }, (size - 16 * S) / 2, (size - 16 * S) / 2, 16 * S)
		local w = { gui = b, slot = true, get = get, set = set, kind = opts.kind, accept = opts.accept }
		function w.paint()
			holder:ClearAllChildren()
			local s = get()
			if ghost then
				ghost.Visible = s == nil
			end
			if s then
				env.icon(holder, s, 16 * S)
			end
		end
		function w.paintFocus(on)
			hover.BackgroundTransparency = on and 0.55 or 1
			if on then
				showTooltip(w)
			end
		end
		function w.click(button, shift)
			scr.clickSlot(w, button, shift or shiftDown())
		end
		b.MouseButton1Click:Connect(function()
			w.click(1)
		end)
		b.MouseButton2Click:Connect(function()
			w.click(2)
		end)
		table.insert(scr.slots, w)
		w.paint()
		return addFocusable(w)
	end

	local function paintAll()
		if not scr or not scr.slots then
			return
		end
		for _, w in scr.slots do
			w.paint()
		end
		paintCursor()
		if scr.afterPaint then
			scr.afterPaint()
		end
		if scr.focus then
			showTooltip(scr.focus)
		end
		G.hudDirty = true
	end
	api.paint = paintAll

	-- в инвентарь: сначала дополнить стопки, потом в пустые; order — порядок ячеек
	local function moveInto(stack, order)
		local max = stackSize(stack.n)
		for _, i in order do
			local s = inv[i]
			if stack.c <= 0 then
				break
			end
			if s and s.n == stack.n and s.c < max then
				local add = math.min(stack.c, max - s.c)
				s.c += add
				stack.c -= add
			end
		end
		for _, i in order do
			if stack.c <= 0 then
				break
			end
			if not inv[i] then
				inv[i] = copy(stack)
				inv[i].c = math.min(stack.c, max)
				stack.c -= inv[i].c
			end
		end
		return stack.c
	end
	local MAIN, HOTBAR, ALL = {}, {}, {}
	for i = 10, 36 do
		table.insert(MAIN, i)
	end
	for i = 1, 9 do
		table.insert(HOTBAR, i)
	end
	for i = 1, 36 do
		table.insert(ALL, i)
	end
	api.moveInto = moveInto

	-- обычная логика ячейки Minecraft: левый клик — взять/положить/обменять/сложить, правый — половину или по одному
	local function defaultClick(w, button, shift)
		if w.kind == "output" then
			scr.takeOutput(shift)
			return
		end
		if w.kind == "palette" then
			local s = w.get()
			if cursor then
				cursor = nil
			elseif s then
				if shift then
					moveInto({ n = s.n, c = stackSize(s.n), d = s.d }, ALL)
				else
					cursor = { n = s.n, c = button == 2 and 1 or stackSize(s.n), d = s.d }
				end
			end
			paintAll()
			return
		end
		if w.kind == "trash" then
			cursor = nil
			paintAll()
			return
		end
		local s = w.get()
		if shift and s then
			if scr.quickMove then
				scr.quickMove(w)
			end
			paintAll()
			return
		end
		if cursor and w.accept and not w.accept(cursor) then
			return
		end
		if button == 1 then
			if cursor and s and same(cursor, s) then
				local max = stackSize(s.n)
				local add = math.min(cursor.c, max - s.c)
				s.c += add
				cursor.c -= add
				if cursor.c <= 0 then
					cursor = nil
				end
				w.set(s)
			else
				w.set(cursor)
				cursor = s
			end
		else
			if not cursor and s then
				local half = math.ceil(s.c / 2)
				cursor = { n = s.n, c = half, d = s.d }
				s.c -= half
				w.set(s.c > 0 and s or nil)
			elseif cursor and not s then
				w.set({ n = cursor.n, c = 1, d = cursor.d })
				cursor.c -= 1
				if cursor.c <= 0 then
					cursor = nil
				end
			elseif cursor and s and same(cursor, s) and s.c < stackSize(s.n) then
				s.c += 1
				cursor.c -= 1
				if cursor.c <= 0 then
					cursor = nil
				end
				w.set(s)
			elseif cursor and s then
				w.set(cursor)
				cursor = s
			end
		end
		ctx.audio:Play("move")
		paintAll()
	end

	-- закрыть окно: курсор и сетка возвращаются в инвентарь (лишнее падает «на землю» — пропадает)
	local function returnStack(s)
		if s and s.c > 0 then
			moveInto(s, ALL)
		end
	end

	local function invSlots(root, ox, oy)
		-- 27 ячеек рюкзака и хотбар, как в Minecraft (у 8,84 и 8,142)
		for i = 10, 36 do
			local col, row = (i - 10) % 9, (i - 10) // 9
			slot(root, ox + (8 + col * 18) * S, oy + (84 + row * 18) * S, function()
				return inv[i]
			end, function(v)
				inv[i] = v
			end)
		end
		for i = 1, 9 do
			slot(root, ox + (8 + (i - 1) * 18) * S, oy + 142 * S, function()
				return inv[i]
			end, function(v)
				inv[i] = v
			end)
		end
	end

	-- ---------------------------------------------------------------- крафт по сетке (рецепты без формы: важно, сколько клеток чем занято)
	local function cellsOf(grid, n)
		local counts, used = {}, 0
		for i = 1, n do
			local s = grid[i]
			if s then
				counts[s.n] = (counts[s.n] or 0) + 1
				used += 1
			end
		end
		return counts, used
	end

	local function matchRecipe(grid, n)
		local counts, used = cellsOf(grid, n)
		if used == 0 then
			return nil
		end
		for _, r in Content.RECIPES do
			if r.station ~= "furnace" and (r.station ~= "table" or n >= 9) then
				local need, ok = 0, true
				local left = table.clone(counts)
				for name, k in r.inputs do
					need += k
					local list = Content.TAGS[name] or { name }
					local have = 0
					for _, item in list do
						if left[item] then
							local t = math.min(left[item], k - have)
							have += t
							left[item] -= t
							if left[item] == 0 then
								left[item] = nil
							end
						end
					end
					if have ~= k then
						ok = false
						break
					end
				end
				if ok and need == used and next(left) == nil then
					return r
				end
			end
		end
		return nil
	end
	api.matchRecipe = matchRecipe

	local function craftedFrom(r)
		local info = Content.ITEMS[r.output]
		return { n = r.output, c = r.count, d = info and info.durability }
	end

	-- книга рецептов: слева от окна; нажатие раскладывает ингредиенты из инвентаря в сетку
	local function recipeBook(root, x, y, grid, n, onFill)
		local book = panel(root, x, y, 147, 166)
		plain(book, "Recipe Book", 8 * S, 5 * S)
		local list = new("ScrollingFrame", {
			Size = UDim2.fromOffset(131 * S, 140 * S), Position = UDim2.fromOffset(8 * S, 18 * S), BackgroundTransparency = 1, BorderSizePixel = 0,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2 * S, Parent = book,
		}, { new("UIGridLayout", { CellSize = UDim2.fromOffset(25 * S, 25 * S), CellPadding = UDim2.fromOffset(S, S), SortOrder = Enum.SortOrder.LayoutOrder }) })
		local function have(name)
			return env.countOf(name)
		end
		local entries = {}
		for _, r in Content.RECIPES do
			if r.station ~= "furnace" and (r.station ~= "table" or n >= 9) then
				table.insert(entries, r)
			end
		end
		local function craftable(r)
			for name, k in r.inputs do
				local total = have(name)
				for i = 1, n do
					local s = grid[i]
					if s and table.find(Content.TAGS[name] or { name }, s.n) then
						total += s.c
					end
				end
				if total < k then
					return false
				end
			end
			return true
		end
		table.sort(entries, function(a, b)
			local ca, cb = craftable(a), craftable(b)
			if ca ~= cb then
				return ca
			end
			return itemLabel({ n = a.output }) < itemLabel({ n = b.output })
		end)
		local buttons = {}
		for i, r in entries do
			local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = rgb(139, 139, 139), BorderSizePixel = 0, LayoutOrder = i, Parent = list })
			bevel(b, rgb(255, 255, 255), rgb(85, 85, 85), S)
			local holder = new("Frame", { Size = UDim2.fromOffset(16 * S, 16 * S), Position = UDim2.fromOffset(4.5 * S, 4.5 * S), BackgroundTransparency = 1, Parent = b })
			env.icon(holder, { n = r.output, c = r.count }, 16 * S)
			local w = { gui = b, recipe = r }
			function w.paintFocus(on)
				b.BackgroundColor3 = on and rgb(180, 190, 255) or (craftable(r) and rgb(139, 139, 139) or rgb(190, 90, 90))
				if on and tooltip then
					tooltip.Visible = true
					local parts = {}
					for name, k in r.inputs do
						local label = Content.TAGS[name] and (name:sub(1, 1):upper() .. name:sub(2)) or itemLabel({ n = name })
						table.insert(parts, `{k}× {label}`)
					end
					table.sort(parts)
					tooltip:FindFirstChild("Text").Text = itemLabel({ n = r.output }) .. `\n<font color="#AAAAAA">{table.concat(parts, ", ")}</font>`
					tooltip.Size = UDim2.fromOffset(math.max(#itemLabel({ n = r.output }), #table.concat(parts, ", ")) * 6 * S + 12 * S, 26 * S)
					local p = (b.AbsolutePosition - canvas.AbsolutePosition) / ((canvas:FindFirstChildOfClass("UIScale") or { Scale = 1 }).Scale)
					tooltip.Position = UDim2.fromOffset(p.X + 26 * S, p.Y)
				end
			end
			function w.activate()
				if not craftable(r) then
					ctx.audio:Play("error")
					return
				end
				onFill(r)
			end
			b.Activated:Connect(w.activate)
			w.paintFocus(false)
			table.insert(buttons, w)
			addFocusable(w)
		end
		return {
			frame = book,
			repaint = function()
				for _, w in buttons do
					w.paintFocus(scr.focus == w)
				end
			end,
		}
	end

	-- раскладка рецепта: вернуть сетку в инвентарь, затем положить по одному предмету в клетку
	local function fillGrid(grid, n, r)
		for i = 1, n do
			returnStack(grid[i])
			grid[i] = nil
		end
		local cell = 1
		local order = {}
		for name, k in r.inputs do
			table.insert(order, { name = name, k = k })
		end
		table.sort(order, function(a, b)
			return a.name < b.name
		end)
		-- инструменты — головка сверху, палки по центру, как выглядит в Minecraft
		for _, it in order do
			for _ = 1, it.k do
				for _, item in Content.TAGS[it.name] or { it.name } do
					if env.countOf(item) > 0 then
						env.take(item, 1)
						while grid[cell] and cell <= n do
							cell += 1
						end
						grid[cell] = { n = item, c = 1, d = Content.ITEMS[item] and Content.ITEMS[item].durability }
						break
					end
				end
			end
		end
	end

	-- общий крафтовый экран (n = 4 или 9)
	local function craftingScreen(name, n)
		local root = beginContainer(name)
		local grid = {}
		local pw, ph = 176, 166
		local showBook = env.options.recipeBook ~= false
		local ox = 960 - pw * S / 2 + (showBook and 77 * S or 0)
		local oy = 540 - ph * S / 2
		local win = panel(root, ox, oy, pw, ph)
		local result
		local book
		local function refresh()
			local r = matchRecipe(grid, n)
			result = r and craftedFrom(r) or nil
			scr.recipe = r
		end
		local function consume()
			for i = 1, n do
				local s = grid[i]
				if s then
					s.c -= 1
					if s.c <= 0 then
						grid[i] = nil
					end
				end
			end
		end
		scr.takeOutput = function(shift)
			if not result then
				return
			end
			if shift then
				-- столько раз, сколько хватает ингредиентов
				local guard = 0
				while result and guard < 64 do
					guard += 1
					local made = copy(result)
					if moveInto(made, { 9, 8, 7, 6, 5, 4, 3, 2, 1, 36, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10 }) > 0 then
						break
					end
					consume()
					env.crafted(made.n, made.c)
					refresh()
				end
			else
				if cursor and (not same(cursor, result) or cursor.c + result.c > stackSize(result.n)) then
					return
				end
				if cursor then
					cursor.c += result.c
				else
					cursor = copy(result)
				end
				env.crafted(result.n, result.c)
				consume()
				refresh()
			end
			ctx.audio:Play("confirm")
			paintAll()
		end
		scr.clickSlot = function(w, button, shift)
			defaultClick(w, button, shift)
			refresh()
			paintAll()
		end
		scr.quickMove = function(w)
			local s = w.get()
			if not s then
				return
			end
			if w.grid then
				w.set(nil)
				local left = moveInto(s, ALL)
				if left > 0 then
					w.set(s)
				end
			else
				local idx = table.find(scr.invIndex, w)
				local order = (idx and idx <= 27) and HOTBAR or MAIN
				w.set(nil)
				local left = moveInto(s, order)
				if left > 0 then
					w.set(s)
				end
			end
			refresh()
		end
		if n == 4 then
			plain(win, "Crafting", 97 * S, 6 * S)
			-- окошко с персонажем
			local view = new("Frame", { Size = UDim2.fromOffset(49 * S, 70 * S), Position = UDim2.fromOffset(26 * S, 8 * S), BackgroundColor3 = rgb(0, 0, 0), BorderSizePixel = 0, Parent = win })
			if env.playerView then
				env.playerView(view)
			end
			-- броня и вторая рука
			local ARMOR = {
				{ "................", ".xxxx....xxxx...", ".x..xxxxxx..x...", ".x..........x...", ".xxx......xxx...", "...x......x.....", "...xxxxxxxx....." },
				{ "................", ".xxx......xxx...", "xx.xxxxxxxx.xx..", "x............x..", "xxx.........xxx.", "..x.........x...", "..x.........x...", "..x.........x...", "..xxxxxxxxxxx..." },
				{ "................", "..xxxxxxxxxx....", "..x........x....", "..x...xx...x....", "..x...xx...x....", "..x...xx...x....", "..xxx.xx.xxx...." },
				{ "................", "................", "................", "...xxx...xxx....", "...x.x...x.x....", "..xx.x...x.xx...", ".x...x...x...x..", ".xxxxx...xxxxx.." },
			}
			for k = 0, 3 do
				local idx = 37 + k
				slot(win, 8 * S, (8 + k * 18) * S, function()
					return inv[idx]
				end, function(v)
					inv[idx] = v
				end, { ghost = "armor" .. k, ghostRows = ARMOR[k + 1] })
			end
			slot(win, 77 * S, 62 * S, function()
				return inv[41]
			end, function(v)
				inv[41] = v
			end, { ghost = "shield", ghostRows = { "................", "...xxxxxxxxx....", "...x.......x....", "...x.......x....", "...x.......x....", "....x.....x.....", ".....x...x......", "......xxx......." } })
			for i = 1, 4 do
				local col, row = (i - 1) % 2, (i - 1) // 2
				local w = slot(win, (98 + col * 18) * S, (18 + row * 18) * S, function()
					return grid[i]
				end, function(v)
					grid[i] = v
				end)
				w.grid = true
			end
			sprite(win, "arrow_bg", ARROW, { x = rgb(139, 139, 139) }, 134 * S, 28 * S - 6 * S, 16 * S)
			slot(win, 154 * S, 28 * S, function()
				return result
			end, function() end, { kind = "output", big = false })
		else
			plain(win, "Crafting", 28 * S, 6 * S)
			for i = 1, 9 do
				local col, row = (i - 1) % 3, (i - 1) // 3
				local w = slot(win, (30 + col * 18) * S, (17 + row * 18) * S, function()
					return grid[i]
				end, function(v)
					grid[i] = v
				end)
				w.grid = true
			end
			sprite(win, "arrow_bg", ARROW, { x = rgb(139, 139, 139) }, 90 * S, 35 * S - 6 * S, 22 * S)
			slot(win, 124 * S, 35 * S, function()
				return result
			end, function() end, { kind = "output", big = true })
		end
		if n == 9 then
			plain(win, "Inventory", 8 * S, 72 * S)
		end
		local before = #scr.slots
		invSlots(win, 0, 0)
		scr.invIndex = {}
		for i = before + 1, #scr.slots do
			table.insert(scr.invIndex, scr.slots[i])
		end
		-- кнопка книги рецептов
		local bookBtn = new("TextButton", {
			Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(20 * S, 18 * S), Position = UDim2.fromOffset((n == 4 and 104 or 5) * S, (n == 4 and 61 or 34) * S),
			BackgroundColor3 = rgb(139, 139, 139), BorderSizePixel = 0, Parent = win,
		})
		bevel(bookBtn, rgb(255, 255, 255), rgb(85, 85, 85), S)
		sprite(bookBtn, "recipe_book", BOOK, { g = rgb(40, 110, 40), G = rgb(70, 160, 60), w = rgb(230, 225, 200) }, 2 * S, S, 16 * S)
		local bookWidget = { gui = bookBtn }
		function bookWidget.paintFocus(on)
			bookBtn.BackgroundColor3 = on and rgb(180, 190, 255) or rgb(139, 139, 139)
		end
		function bookWidget.activate()
			env.options.recipeBook = not showBook
			env.saveOptions()
			-- перестроить окно с тем же содержимым сетки
			local keep = grid
			grid = {}
			api.close()
			api.open(name == "inventory" and "inventory" or "table", { grid = keep })
		end
		bookBtn.Activated:Connect(bookWidget.activate)
		addFocusable(bookWidget)
		if showBook then
			book = recipeBook(root, ox - 151 * S, oy, grid, n, function(r)
				fillGrid(grid, n, r)
				refresh()
				paintAll()
			end)
		end
		scr.afterPaint = function()
			if book then
				book.repaint()
			end
		end
		scr.onClose = function()
			for i = 1, n do
				returnStack(grid[i])
				grid[i] = nil
			end
			returnStack(cursor)
			cursor = nil
		end
		scr.back = api.close
		scr.restoreGrid = function(g)
			for i = 1, n do
				grid[i] = g[i]
			end
			refresh()
		end
		setupOverlay(root)
		-- первый фокус — первая ячейка рюкзака
		scr.firstFocus = table.find(scr.focusables, scr.invIndex[28]) or 1
		refresh()
		paintAll()
	end

	builders.inventory = function(args)
		craftingScreen("inventory", 4)
		if args.grid then
			scr.restoreGrid(args.grid)
			paintAll()
		end
	end
	builders.table = function(args)
		craftingScreen("table", 9)
		if args.grid then
			scr.restoreGrid(args.grid)
			paintAll()
		end
	end

	-- ---------------------------------------------------------------- печь
	function api.furnaceState(key)
		G.furnaces = G.furnaces or {}
		local f = G.furnaces[key]
		if not f then
			f = { burn = 0, burnMax = 0, cook = 0 }
			G.furnaces[key] = f
		end
		return f
	end

	local function canSmelt(f)
		local s = f.input
		local rule = s and SMELT[s.n]
		if not rule or s.c < rule.need then
			return nil
		end
		if f.output and (f.output.n ~= rule.output or f.output.c + rule.count > stackSize(rule.output)) then
			return nil
		end
		return rule
	end

	-- печи работают и при закрытом окне, как в Minecraft
	function api.tickFurnaces(dt)
		for _, f in G.furnaces or {} do
			local rule = canSmelt(f)
			if f.burn > 0 then
				f.burn = math.max(0, f.burn - dt)
			end
			if rule and f.burn <= 0 and f.fuel and fuelTime(f.fuel.n) then
				f.burnMax = fuelTime(f.fuel.n)
				f.burn = f.burnMax
				f.fuel.c -= 1
				if f.fuel.c <= 0 then
					f.fuel = nil
				end
			end
			if rule and f.burn > 0 then
				f.cook += dt
				if f.cook >= COOK_TIME then
					f.cook = 0
					f.input.c -= rule.need
					if f.input.c <= 0 then
						f.input = nil
					end
					if f.output then
						f.output.c += rule.count
					else
						f.output = { n = rule.output, c = rule.count }
					end
				end
			else
				f.cook = math.max(0, f.cook - dt * 2)
			end
		end
		if scr and scr.name == "furnace" and scr.tick then
			scr.tick()
		end
	end

	builders.furnace = function(args)
		local root = beginContainer("furnace")
		local f = api.furnaceState(args.key)
		local pw, ph = 176, 166
		local ox, oy = 960 - pw * S / 2, 540 - ph * S / 2
		local win = panel(root, ox, oy, pw, ph)
		plain(win, "Furnace", 0, 6 * S, { w = pw * S, X = Enum.TextXAlignment.Center })
		slot(win, 56 * S, 17 * S, function()
			return f.input
		end, function(v)
			f.input = v
		end, {
			accept = function(s)
				return true
			end,
		})
		slot(win, 56 * S, 53 * S, function()
			return f.fuel
		end, function(v)
			f.fuel = v
		end, {
			accept = function(s)
				return fuelTime(s.n) ~= nil
			end,
		})
		slot(win, 116 * S, 35 * S, function()
			return f.output
		end, function(v)
			f.output = v
		end, { big = true, kind = "furnaceOut" })
		-- огонь (сгорает сверху вниз) и стрелка (заполняется слева направо)
		local flameBox = new("Frame", { Size = UDim2.fromOffset(14 * S, 14 * S), Position = UDim2.fromOffset(57 * S, 36 * S), BackgroundTransparency = 1, Parent = win })
		sprite(flameBox, "flame_off", FLAME, { x = rgb(139, 139, 139), y = rgb(139, 139, 139) }, -S, 0, 16 * S)
		local flameClip = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Parent = flameBox })
		local flameImg = sprite(flameClip, "flame_on", FLAME, { x = rgb(255, 120, 20), y = rgb(255, 230, 80) }, -S, 0, 16 * S)
		local arrowBox = new("Frame", { Size = UDim2.fromOffset(22 * S, 16 * S), Position = UDim2.fromOffset(79 * S, 34 * S - 3 * S), BackgroundTransparency = 1, Parent = win })
		sprite(arrowBox, "arrow_bg", ARROW, { x = rgb(139, 139, 139) }, 0, -3 * S, 22 * S)
		local arrowClip = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 1, ClipsDescendants = true, Parent = arrowBox })
		sprite(arrowClip, "arrow_fill", ARROW, { x = Color3.new(1, 1, 1) }, 0, -3 * S, 22 * S)
		plain(win, "Inventory", 8 * S, 72 * S)
		local before = #scr.slots
		invSlots(win, 0, 0)
		scr.invIndex = {}
		for i = before + 1, #scr.slots do
			table.insert(scr.invIndex, scr.slots[i])
		end
		local lastSig
		scr.tick = function()
			local burnK = f.burnMax > 0 and f.burn / f.burnMax or 0
			flameClip.Size = UDim2.fromScale(1, burnK)
			if flameImg then
				flameImg.Position = UDim2.new(0, -S, 1, -16 * S)
				flameImg.AnchorPoint = Vector2.new(0, 0)
			end
			arrowClip.Size = UDim2.fromScale(f.cook / COOK_TIME, 1)
			-- ячейки перерисовываются, только когда печь что-то сожгла или выплавила
			local function sig(st)
				return st and `{st.n}:{st.c}` or "-"
			end
			local now = sig(f.input) .. sig(f.fuel) .. sig(f.output)
			if now ~= lastSig then
				lastSig = now
				for _, w in scr.slots do
					w.paint()
				end
			end
		end
		scr.clickSlot = function(w, button, shift)
			if w.kind == "furnaceOut" then
				local s = f.output
				if not s then
					return
				end
				if shift then
					f.output = nil
					local left = moveInto(s, ALL)
					if left > 0 then
						f.output = s
					end
					env.crafted(s.n, s.c - left)
				elseif not cursor or (same(cursor, s) and cursor.c + s.c <= stackSize(s.n)) then
					if cursor then
						cursor.c += s.c
					else
						cursor = s
					end
					f.output = nil
					env.crafted(s.n, s.c)
				end
				paintAll()
				return
			end
			defaultClick(w, button, shift)
		end
		scr.quickMove = function(w)
			local s = w.get()
			local idx = table.find(scr.invIndex, w)
			if idx then
				-- из инвентаря: сырьё в печь, топливо в топку, иначе между рюкзаком и хотбаром
				w.set(nil)
				if SMELT[s.n] and (not f.input or same(f.input, s)) then
					if f.input then
						local add = math.min(s.c, stackSize(s.n) - f.input.c)
						f.input.c += add
						s.c -= add
					else
						f.input = copy(s)
						s.c = 0
					end
				elseif fuelTime(s.n) and (not f.fuel or same(f.fuel, s)) then
					if f.fuel then
						local add = math.min(s.c, stackSize(s.n) - f.fuel.c)
						f.fuel.c += add
						s.c -= add
					else
						f.fuel = copy(s)
						s.c = 0
					end
				else
					moveInto(s, idx <= 27 and HOTBAR or MAIN)
				end
				if s.c > 0 then
					w.set(s)
				end
			else
				w.set(nil)
				local left = moveInto(s, ALL)
				if left > 0 then
					w.set(s)
				end
			end
		end
		scr.onClose = function()
			returnStack(cursor)
			cursor = nil
		end
		scr.back = api.close
		setupOverlay(root)
		scr.firstFocus = 1
		scr.tick()
		paintAll()
	end

	-- ---------------------------------------------------------------- творческий инвентарь
	local function creativeTabs()
		local blocks, tools, food, materials = {}, {}, {}, {}
		local seen = {}
		for _, name in Content.CREATIVE do
			table.insert(blocks, name)
			seen[name] = true
		end
		local extra = {}
		for name, b in Content.BLOCKS do
			if not seen[name] and not b.liquid and not b.portal then
				table.insert(extra, name)
			end
		end
		table.sort(extra)
		for _, n in extra do
			table.insert(blocks, n)
		end
		local items = {}
		for name in Content.ITEMS do
			table.insert(items, name)
		end
		table.sort(items)
		local TIER = { wooden = 1, stone = 2, iron = 3, golden = 4, diamond = 5, netherite = 6 }
		for _, name in items do
			local it = Content.ITEMS[name]
			if it.tool or name == "flint_and_steel" then
				table.insert(tools, name)
			elseif it.food then
				table.insert(food, name)
			else
				table.insert(materials, name)
			end
		end
		table.sort(tools, function(a, b)
			local ta, tb = Content.ITEMS[a].tool, Content.ITEMS[b].tool
			if not ta or not tb then
				return a < b
			end
			if ta.kind ~= tb.kind then
				return ta.kind < tb.kind
			end
			return (TIER[a:match("^(%a+)_")] or 0) < (TIER[b:match("^(%a+)_")] or 0)
		end)
		return {
			{ name = "Building Blocks", icon = "bricks", list = blocks },
			{ name = "Tools & Combat", icon = "diamond_pickaxe", list = tools },
			{ name = "Foodstuffs", icon = "apple", list = food },
			{ name = "Materials", icon = "iron_ingot", list = materials },
			{ name = "Search Items", icon = "search", list = nil },
		}
	end

	builders.creative = function(args)
		local root = beginContainer("creative")
		local tabs = creativeTabs()
		local all = {}
		for i = 1, 4 do
			for _, n in tabs[i].list do
				table.insert(all, n)
			end
		end
		tabs[5].list = all
		local tabIndex = args.tab or 1
		local pw, ph = 195, 136
		local ox, oy = 960 - pw * S / 2, 540 - ph * S / 2 + 10 * S
		-- вкладки сверху
		for i, t in tabs do
			local active = i == tabIndex
			local tb = new("TextButton", {
				Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(28 * S, (active and 32 or 28) * S), Position = UDim2.fromOffset(ox + (i - 1) * 29 * S, oy - (active and 28 or 28) * S),
				BackgroundColor3 = active and rgb(198, 198, 198) or rgb(150, 150, 150), BorderSizePixel = 0, ZIndex = active and 3 or 1, Parent = root,
			}, { ui.stroke(rgb(0, 0, 0), S, 0) })
			bevel(tb, rgb(255, 255, 255), rgb(85, 85, 85), S)
			local holder = new("Frame", { Size = UDim2.fromOffset(16 * S, 16 * S), Position = UDim2.fromOffset(6 * S, 7 * S), BackgroundTransparency = 1, Parent = tb })
			if t.icon == "search" then
				ui.text("?", { Size = UDim2.fromScale(1, 1), TextSize = 14 * S, Font = PIXEL, TextColor3 = rgb(60, 60, 60), TextXAlignment = Enum.TextXAlignment.Center, Parent = holder })
			else
				env.icon(holder, { n = t.icon, c = 1 }, 16 * S)
			end
			local w = { gui = tb }
			function w.paintFocus(on)
				tb.BackgroundColor3 = on and rgb(180, 190, 255) or (active and rgb(198, 198, 198) or rgb(150, 150, 150))
				if on and tooltip then
					tooltip.Visible = true
					tooltip:FindFirstChild("Text").Text = t.name
					tooltip.Size = UDim2.fromOffset(#t.name * 6 * S + 12 * S, 14 * S)
					tooltip.Position = UDim2.fromOffset(ox + (i - 1) * 29 * S, oy - 44 * S)
				end
			end
			function w.activate()
				api.open("creative", { tab = i })
			end
			tb.Activated:Connect(w.activate)
			addFocusable(w)
		end
		local win = panel(root, ox, oy, pw, ph)
		plain(win, tabs[tabIndex].name, 8 * S, 6 * S)
		local search
		local list = tabs[tabIndex].list
		if tabIndex == 5 then
			search = new("TextBox", {
				Size = UDim2.fromOffset(89 * S, 12 * S), Position = UDim2.fromOffset(82 * S, 5 * S), BackgroundColor3 = rgb(0, 0, 0), BorderSizePixel = 0, Text = args.query or "",
				PlaceholderText = "Search...", Font = PIXEL, TextSize = 8 * S, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = win,
			}, { ui.stroke(rgb(160, 160, 160), S, 0) })
		end
		local grid = new("ScrollingFrame", {
			Size = UDim2.fromOffset(162 * S + 14 * S, 90 * S), Position = UDim2.fromOffset(9 * S, 18 * S), BackgroundTransparency = 1, BorderSizePixel = 0,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 12 * S, ScrollBarImageColor3 = rgb(198, 198, 198),
			VerticalScrollBarInset = Enum.ScrollBarInset.None, Parent = win,
		})
		new("UIGridLayout", { CellSize = UDim2.fromOffset(SLOT, SLOT), CellPadding = UDim2.new(), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		local paletteSlots = {}
		local function fillPalette(filter)
			for _, w in paletteSlots do
				local i = table.find(scr.focusables, w)
				if i then
					table.remove(scr.focusables, i)
				end
				local j = table.find(scr.slots, w)
				if j then
					table.remove(scr.slots, j)
				end
				w.gui:Destroy()
			end
			table.clear(paletteSlots)
			local order = 0
			for _, name in list do
				local label = itemLabel({ n = name })
				if not filter or filter == "" or string.find(string.lower(label), string.lower(filter), 1, true) then
					order += 1
					local stack = { n = name, c = 1, d = Content.ITEMS[name] and Content.ITEMS[name].durability }
					local w = slot(grid, 0, 0, function()
						return stack
					end, function() end, { kind = "palette" })
					w.gui.LayoutOrder = order
					table.insert(paletteSlots, w)
					-- держать фокус в видимой части списка
					w.onFocus = function()
						local y = (math.ceil(order / 9) - 1) * SLOT
						local view = grid.CanvasPosition.Y
						if y < view then
							grid.CanvasPosition = Vector2.new(0, y)
						elseif y + SLOT > view + 90 * S then
							grid.CanvasPosition = Vector2.new(0, y + SLOT - 90 * S)
						end
					end
				end
			end
		end
		fillPalette(args.query)
		if search then
			search:GetPropertyChangedSignal("Text"):Connect(function()
				fillPalette(search.Text)
				paintAll()
			end)
		end
		for i = 1, 9 do
			slot(win, (9 + (i - 1) * 18) * S, 112 * S, function()
				return inv[i]
			end, function(v)
				inv[i] = v
			end)
		end
		-- корзина
		slot(win, 173 * S, 112 * S, function()
			return nil
		end, function() end, {
			kind = "trash",
			ghost = "trash",
			ghostRows = { "................", "...xxxxxxxxxx...", ".....x....x.....", "..xxxxxxxxxxxx..", "...x........x...", "...x.x.xx.x.x...", "...x.x.xx.x.x...", "...x.x.xx.x.x...", "...x.x.xx.x.x...", "...x........x...", "....xxxxxxxx...." },
		})
		scr.clickSlot = function(w, button, shift)
			defaultClick(w, button, shift)
		end
		scr.quickMove = function(w)
			w.set(nil)
		end
		scr.tab = function(dir)
			api.open("creative", { tab = (tabIndex - 1 + dir) % #tabs + 1 })
		end
		scr.onClose = function()
			cursor = nil
		end
		scr.back = api.close
		setupOverlay(root)
		scr.firstFocus = #tabs + 1
		paintAll()
	end

	-- ---------------------------------------------------------------- для тестов
	api.debug = {
		cursor = function()
			return cursor
		end,
		click = function(i, button, shift)
			local w = scr and scr.slots and scr.slots[i]
			if w then
				scr.clickSlot(w, button or 1, shift or false)
			end
		end,
		slots = function()
			return scr and scr.slots or {}
		end,
		focusables = function()
			return scr and scr.focusables or {}
		end,
		activate = function(text)
			for _, w in scr and scr.focusables or {} do
				if w.label and w.label.main.Text == text then
					w.activate()
					return true
				end
			end
			return false
		end,
	}
	return api
end

return Screens
