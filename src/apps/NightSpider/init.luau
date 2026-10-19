-- Night Spider — герой-паук в ночном неоновом городе: полёт на паутине, бег по стенам,
-- бои с бандитами на вызовах и жетоны на крышах. Своя аркадная физика (без физики Roblox):
-- здания — прямоугольные коробки, герой — точка с радиусом.
local Game = {}

local BASE = Vector3.new(-9000, 300, 9000) -- город далеко от чиллзоны
local GY = BASE.Y -- уровень улицы
local N, BLOCK, CELL = 7, 84, 124 -- кварталы N×N, размер квартала, шаг сетки
local HALF = N * CELL / 2
local G = 120
local RUN, JUMP = 44, 58
local MAX_SPEED = 190
local WALL_UP = 52
local R, H = 1.2, 5 -- радиус и рост героя
local TOKENS = 20
local MAX_HP = 100
local Y = Vector3.new(0, 1, 0)

local CRIMSON = Color3.fromRGB(205, 24, 48)
local NAVY = Color3.fromRGB(18, 28, 70)
local WHITE = Color3.new(1, 1, 1)
local AMBER = Color3.fromRGB(255, 190, 40)
local NEONS = {
	Color3.fromRGB(0, 230, 255), Color3.fromRGB(255, 60, 160), Color3.fromRGB(255, 180, 40),
	Color3.fromRGB(140, 90, 255), Color3.fromRGB(60, 255, 150),
}
local CONCRETE = {
	Color3.fromRGB(38, 42, 58), Color3.fromRGB(52, 50, 64), Color3.fromRGB(30, 36, 48),
	Color3.fromRGB(60, 58, 70), Color3.fromRGB(44, 48, 70),
}

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function unitOr(v, fallback)
	local m = v.Magnitude
	if m < 1e-4 then
		return fallback
	end
	return v / m
end

local function part(parent, size, cf, color, material, transparency, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- Детерминированный генератор, чтобы город всегда был одинаковым (жетоны сохраняются по номеру).
local function makeRng(seed)
	local s = seed
	return function()
		s = (s * 16807) % 2147483647
		return s / 2147483647
	end
end

-- Город: кварталы с одним зданием, в центре Night Tower, два парка.
local function buildCity(world)
	local rnd = makeRng(20261019)
	local city = Instance.new("Folder")
	city.Name = "City"
	local size = N * CELL + 240
	part(city, Vector3.new(size + 600, 4, size + 600), CFrame.new(BASE - Vector3.new(0, 8, 0)), Color3.fromRGB(10, 22, 40), Enum.Material.Glass, 0.1)
	part(city, Vector3.new(size, 2, size), CFrame.new(BASE - Vector3.new(0, 1.5, 0)), Color3.fromRGB(22, 22, 28), Enum.Material.Asphalt)

	local buildings = {}
	local tower
	for i = 0, N - 1 do
		for j = 0, N - 1 do
			local c = BASE + Vector3.new((i - (N - 1) / 2) * CELL, 0, (j - (N - 1) / 2) * CELL)
			part(city, Vector3.new(BLOCK, 0.5, BLOCK), CFrame.new(c - Vector3.new(0, 0.25, 0)), Color3.fromRGB(70, 70, 80), Enum.Material.Concrete)
			local park = (i == 1 and j == 5) or (i == 5 and j == 1)
			if park then
				part(city, Vector3.new(BLOCK - 6, 0.6, BLOCK - 6), CFrame.new(c), Color3.fromRGB(30, 90, 50), Enum.Material.Grass)
				for _ = 1, 6 do
					local t = c + Vector3.new((rnd() - 0.5) * 60, 0, (rnd() - 0.5) * 60)
					part(city, Vector3.new(1.4, 8, 1.4), CFrame.new(t + Vector3.new(0, 4, 0)), Color3.fromRGB(70, 45, 30), Enum.Material.Wood)
					part(city, Vector3.new(10, 10, 10), CFrame.new(t + Vector3.new(0, 11, 0)), Color3.fromRGB(30, 110, 60), Enum.Material.Grass, 0, Enum.PartType.Ball)
				end
			else
				local isTower = i == 3 and j == 3
				local w = isTower and 56 or 48 + rnd() * 30
				local d = isTower and 56 or 48 + rnd() * 30
				local h = isTower and 380 or math.floor(60 + rnd() ^ 1.4 * 210)
				local color = CONCRETE[1 + math.floor(rnd() * #CONCRETE)]
				local neon = NEONS[1 + math.floor(rnd() * #NEONS)]
				local center = c + Vector3.new(0, h / 2, 0)
				part(city, Vector3.new(w, h, d), CFrame.new(center), color, isTower and Enum.Material.Glass or Enum.Material.Concrete, 0)
				-- неоновые пояса окон: одна деталь-кольцо на этаж
				local step = isTower and 16 or 22
				for y = step, h - 6, step do
					part(city, Vector3.new(w + 0.6, 1, d + 0.6), CFrame.new(c + Vector3.new(0, y, 0)), neon, Enum.Material.Neon, 0.25)
				end
				part(city, Vector3.new(w + 1, 1.6, d + 1), CFrame.new(c + Vector3.new(0, h + 0.8, 0)), Color3.fromRGB(80, 80, 92), Enum.Material.Concrete)
				local roof = c + Vector3.new(0, h, 0)
				if isTower then
					part(city, Vector3.new(3, 60, 3), CFrame.new(roof + Vector3.new(0, 30, 0)), Color3.fromRGB(90, 90, 100), Enum.Material.Metal)
					local tip = part(city, Vector3.new(4, 4, 4), CFrame.new(roof + Vector3.new(0, 62, 0)), CRIMSON, Enum.Material.Neon, 0, Enum.PartType.Ball)
					local light = Instance.new("PointLight")
					light.Color = CRIMSON
					light.Range = 60
					light.Brightness = 4
					light.Parent = tip
				elseif rnd() < 0.35 then
					local p = roof + Vector3.new((rnd() - 0.5) * (w - 16), 0, (rnd() - 0.5) * (d - 16))
					part(city, Vector3.new(10, 8, 8), CFrame.new(p + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(110, 70, 45), Enum.Material.WoodPlanks, 0, Enum.PartType.Cylinder)
					part(city, Vector3.new(6, 5, 6), CFrame.new(p + Vector3.new(0, 2.5, 0)), Color3.fromRGB(50, 40, 35), Enum.Material.Metal, 0.5)
				elseif rnd() < 0.5 then
					local p = roof + Vector3.new((rnd() - 0.5) * (w - 10), 0, (rnd() - 0.5) * (d - 10))
					part(city, Vector3.new(0.6, 18, 0.6), CFrame.new(p + Vector3.new(0, 9, 0)), Color3.fromRGB(120, 120, 130), Enum.Material.Metal)
					part(city, Vector3.new(1.2, 1.2, 1.2), CFrame.new(p + Vector3.new(0, 18.5, 0)), Color3.fromRGB(255, 40, 40), Enum.Material.Neon, 0, Enum.PartType.Ball)
				end
				local b = {
					min = c - Vector3.new(w / 2, 0, d / 2),
					max = c + Vector3.new(w / 2, h, d / 2),
					top = GY + h,
					center = c,
				}
				table.insert(buildings, b)
				if isTower then
					tower = b
				end
			end
		end
	end

	-- фонари на перекрёстках
	local crossings = {}
	for i = 0, N - 2 do
		for j = 0, N - 2 do
			local p = BASE + Vector3.new((i - (N - 2) / 2) * CELL, 0, (j - (N - 2) / 2) * CELL)
			table.insert(crossings, p)
			if (i + j) % 2 == 0 then
				local lp = p + Vector3.new(14, 0, 14)
				part(city, Vector3.new(0.8, 16, 0.8), CFrame.new(lp + Vector3.new(0, 8, 0)), Color3.fromRGB(40, 40, 48), Enum.Material.Metal)
				local bulb = part(city, Vector3.new(2, 1, 2), CFrame.new(lp + Vector3.new(0, 16.5, 0)), Color3.fromRGB(255, 220, 160), Enum.Material.Neon)
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 210, 150)
				light.Range = 45
				light.Brightness = 2
				light.Parent = bulb
			end
		end
	end
	city.Parent = world
	return buildings, tower, crossings, rnd
end

-- Модель из деталей: размер, смещение от корня, цвет, материал. Конечности поворачиваются вокруг верхней точки.
local function buildFigure(parent, spec)
	local model = Instance.new("Model")
	local parts = {}
	for _, s in spec do
		local p = part(model, s.size, CFrame.new(BASE), s.color, s.material, s.transparency, s.shape)
		p.Name = s.name
		parts[s.name] = { part = p, at = s.at, half = s.size.Y / 2, limb = s.limb }
	end
	model.Parent = parent
	parts.model = model
	return parts
end

local function poseFigure(fig, root, swingA, swingB, armUp)
	for _, e in fig do
		if type(e) == "table" and e.part then
			local cf = root * CFrame.new(e.at)
			if e.limb == "a" then
				cf = cf * CFrame.Angles(swingA, 0, 0) * CFrame.new(0, -e.half, 0)
			elseif e.limb == "b" then
				cf = cf * CFrame.Angles(swingB, 0, 0) * CFrame.new(0, -e.half, 0)
			elseif e.limb == "up" then
				cf = cf * CFrame.Angles(armUp, 0, 0) * CFrame.new(0, -e.half, 0)
			end
			e.part.CFrame = cf
		end
	end
end

local HERO = {
	{ name = "Torso", size = Vector3.new(2, 2.2, 1), at = Vector3.new(0, 3.2, 0), color = CRIMSON },
	{ name = "Emblem", size = Vector3.new(0.9, 0.9, 0.1), at = Vector3.new(0, 3.5, -0.52), color = Color3.fromRGB(10, 10, 14) },
	{ name = "Belt", size = Vector3.new(2.05, 0.35, 1.05), at = Vector3.new(0, 2.2, 0), color = NAVY },
	{ name = "Head", size = Vector3.new(1.3, 1.4, 1.2), at = Vector3.new(0, 5, 0), color = CRIMSON },
	{ name = "EyeL", size = Vector3.new(0.45, 0.3, 0.1), at = Vector3.new(-0.32, 5.15, -0.61), color = WHITE, material = Enum.Material.Neon },
	{ name = "EyeR", size = Vector3.new(0.45, 0.3, 0.1), at = Vector3.new(0.32, 5.15, -0.61), color = WHITE, material = Enum.Material.Neon },
	{ name = "ArmL", size = Vector3.new(0.65, 2.1, 0.65), at = Vector3.new(-1.35, 4.2, 0), color = CRIMSON, limb = "b" },
	{ name = "ArmR", size = Vector3.new(0.65, 2.1, 0.65), at = Vector3.new(1.35, 4.2, 0), color = CRIMSON, limb = "up" },
	{ name = "LegL", size = Vector3.new(0.85, 2.1, 0.85), at = Vector3.new(-0.5, 2.1, 0), color = NAVY, limb = "a" },
	{ name = "LegR", size = Vector3.new(0.85, 2.1, 0.85), at = Vector3.new(0.5, 2.1, 0), color = NAVY, limb = "b" },
	{ name = "Sense", size = Vector3.new(0.6, 0.6, 0.6), at = Vector3.new(0, 6.6, 0), color = AMBER, material = Enum.Material.Neon, transparency = 1, shape = Enum.PartType.Ball },
}

local THUG = {
	{ name = "Torso", size = Vector3.new(2.2, 2.2, 1.2), at = Vector3.new(0, 3.2, 0), color = Color3.fromRGB(70, 72, 80) },
	{ name = "Head", size = Vector3.new(1.2, 1.2, 1.2), at = Vector3.new(0, 4.9, 0), color = Color3.fromRGB(200, 150, 110) },
	{ name = "Mask", size = Vector3.new(1.25, 0.35, 1.25), at = Vector3.new(0, 4.8, 0), color = Color3.fromRGB(255, 120, 20) },
	{ name = "ArmL", size = Vector3.new(0.7, 2.1, 0.7), at = Vector3.new(-1.45, 4.2, 0), color = Color3.fromRGB(70, 72, 80), limb = "b" },
	{ name = "ArmR", size = Vector3.new(0.7, 2.1, 0.7), at = Vector3.new(1.45, 4.2, 0), color = Color3.fromRGB(70, 72, 80), limb = "up" },
	{ name = "LegL", size = Vector3.new(0.9, 2.1, 0.9), at = Vector3.new(-0.55, 2.1, 0), color = Color3.fromRGB(35, 35, 45), limb = "a" },
	{ name = "LegR", size = Vector3.new(0.9, 2.1, 0.9), at = Vector3.new(0.55, 2.1, 0), color = Color3.fromRGB(35, 35, 45), limb = "b" },
	{ name = "Web", size = Vector3.new(3.4, 6, 2.4), at = Vector3.new(0, 3, 0), color = Color3.fromRGB(235, 235, 245), material = Enum.Material.Fabric, transparency = 1 },
}

function Game.launch(ctx)
	local ui = ctx.ui
	local input = ctx.input
	ctx.gui.BackgroundTransparency = 1
	local camera = ctx.camera
	camera.CameraType = Enum.CameraType.Scriptable

	local buildings, tower, crossings, rnd = buildCity(ctx.world)

	-- Сохранения
	local tokenStr = ctx.save:Get("tokens", "")
	if type(tokenStr) ~= "string" or #tokenStr ~= TOKENS then
		tokenStr = string.rep("0", TOKENS)
	end
	local stats = {
		crimes = ctx.save:Get("crimes", 0),
		webbed = ctx.save:Get("webbed", 0),
		topSpeed = ctx.save:Get("topSpeed", 0),
	}

	-- Жетоны на крышах (детерминированно из генератора города)
	local tokens = {}
	do
		local pool = {}
		for _, b in buildings do
			if b ~= tower then
				table.insert(pool, b)
			end
		end
		for k = 1, TOKENS do
			local idx = 1 + math.floor(rnd() * #pool)
			local b = table.remove(pool, idx)
			local pos = Vector3.new(b.center.X, b.top + 3.5, b.center.Z)
			local got = tokenStr:sub(k, k) == "1"
			local p
			if not got then
				p = part(ctx.world, Vector3.new(0.6, 4, 4), CFrame.new(pos), AMBER, Enum.Material.Neon, 0, Enum.PartType.Cylinder)
				local light = Instance.new("PointLight")
				light.Color = AMBER
				light.Range = 18
				light.Brightness = 2
				light.Parent = p
			end
			tokens[k] = { pos = pos, part = p, got = got }
		end
	end
	local function tokenCount()
		local n = 0
		for _, t in tokens do
			if t.got then
				n += 1
			end
		end
		return n
	end

	-- Герой
	local fig = buildFigure(ctx.world, HERO)
	local rope = part(ctx.world, Vector3.new(0.18, 0.18, 1), CFrame.new(BASE), Color3.fromRGB(240, 240, 250), Enum.Material.Neon, 1)
	local START = Vector3.new(tower.max.X + 20, GY, tower.max.Z + 20)
	local hero = {
		pos = START,
		vel = Vector3.zero,
		state = "ground", -- ground | air | swing | wall
		facing = Vector3.new(0, 0, -1),
		hp = MAX_HP,
		sinceHit = 99,
		iframes = 0,
		anchor = nil,
		ropeLen = 0,
		wall = nil,
		wallN = nil,
		climbed = 0,
		attackCd = 0,
		webCd = 0,
		dodgeCd = 0,
		combo = 0,
		comboT = 0,
		punch = 0,
		run = 0,
	}
	local camYaw = math.pi * 1.25
	local camManual = 0
	local camSmooth = nil
	local state = "title" -- title | play | pause
	local clock = 0

	-- Интерфейс
	local canvas = ui.canvas(ctx.gui)
	local hud = ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(1920, 1080), Visible = false, Parent = canvas })
	local hpBack = ui.new("Frame", {
		Position = UDim2.fromOffset(60, 50), Size = UDim2.fromOffset(420, 22),
		BackgroundColor3 = Color3.fromRGB(20, 20, 30), BackgroundTransparency = 0.3, Parent = hud,
	}, { ui.corner(11) })
	local hpFill = ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = CRIMSON, Parent = hpBack }, { ui.corner(11) })
	ui.text("NIGHT SPIDER", { Position = UDim2.fromOffset(60, 80), Size = UDim2.fromOffset(420, 30), TextSize = 22, TextColor3 = Color3.fromRGB(255, 255, 255), TextTransparency = 0.3, Parent = hud })
	local statsLabel = ui.text("", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(1860, 46), Size = UDim2.fromOffset(500, 80),
		TextSize = 28, TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Top, Parent = hud,
	})
	local objective = ui.text("", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 40), Size = UDim2.fromOffset(900, 40),
		TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Parent = hud,
	})
	local arrow = ui.text("▲", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 110), Size = UDim2.fromOffset(60, 60),
		TextSize = 44, TextColor3 = CRIMSON, TextXAlignment = Enum.TextXAlignment.Center, Parent = hud,
	})
	local speedLabel = ui.text("", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromOffset(1860, 1030), Size = UDim2.fromOffset(400, 60),
		TextSize = 44, TextXAlignment = Enum.TextXAlignment.Right, Parent = hud,
	})
	local comboLabel = ui.text("", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 300), Size = UDim2.fromOffset(600, 80),
		TextSize = 56, TextColor3 = AMBER, TextXAlignment = Enum.TextXAlignment.Center, Parent = hud,
	})
	local toast = ui.text("", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 820), Size = UDim2.fromOffset(1200, 70),
		TextSize = 40, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, Parent = hud,
	})
	local hint = ui.text("", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(60, 1030), Size = UDim2.fromOffset(1100, 40),
		TextSize = 22, TextTransparency = 0.35, Parent = hud,
	})
	local toastT = 0
	local function showToast(text)
		toast.Text = text
		toast.TextTransparency = 0
		toastT = 2.6
	end

	local overlay = ui.new("Frame", {
		Size = UDim2.fromOffset(1920, 1080), BackgroundColor3 = Color3.fromRGB(6, 8, 20), BackgroundTransparency = 0.35, Parent = canvas,
	})
	ui.text("NIGHT SPIDER", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 380), Size = UDim2.fromOffset(1400, 160),
		TextSize = 140, Font = Enum.Font.GothamBlack, TextColor3 = CRIMSON, TextXAlignment = Enum.TextXAlignment.Center, Parent = overlay,
	})
	local overlaySub = ui.text("", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 500), Size = UDim2.fromOffset(1400, 50),
		TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, Parent = overlay,
	})
	local overlayHint = ui.text("", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 640), Size = UDim2.fromOffset(1400, 220),
		TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 0.2, Parent = overlay,
	})
	local function g(btn)
		return input:Glyph(btn)
	end
	local function showOverlay(kind)
		overlay.Visible = true
		if kind == "title" then
			overlaySub.Text = "The city never sleeps. Neither do you."
			overlayHint.Text = `{g("cross")} Start      {g("circle")} Quit\n\n`
				.. `Hold {g("cross")} in the air to swing  ·  {g("square")} punch  ·  {g("triangle")} web  ·  run into walls to climb`
		else
			overlaySub.Text = "Paused"
			overlayHint.Text = `{g("cross")} Resume      {g("circle")} Quit to home`
		end
	end
	showOverlay("title")

	-- Мир: столкновения с коробками зданий
	local function floorAt(pos, prevY)
		local floor = GY
		for _, b in buildings do
			if pos.X > b.min.X - 0.3 and pos.X < b.max.X + 0.3 and pos.Z > b.min.Z - 0.3 and pos.Z < b.max.Z + 0.3
				and b.top <= prevY + 0.6 and b.top > floor then
				floor = b.top
			end
		end
		return floor
	end

	-- Выталкивает точку из стен; возвращает новую позицию, нормаль стены и здание.
	local function pushOut(pos, r)
		for _, b in buildings do
			if pos.Y < b.top - 0.05 and pos.X > b.min.X - r and pos.X < b.max.X + r and pos.Z > b.min.Z - r and pos.Z < b.max.Z + r then
				local opts = {
					{ (b.min.X - r) - pos.X, Vector3.new(-1, 0, 0) },
					{ (b.max.X + r) - pos.X, Vector3.new(1, 0, 0) },
					{ (b.min.Z - r) - pos.Z, Vector3.new(0, 0, -1) },
					{ (b.max.Z + r) - pos.Z, Vector3.new(0, 0, 1) },
				}
				local best = opts[1]
				for k = 2, 4 do
					if math.abs(opts[k][1]) < math.abs(best[1]) then
						best = opts[k]
					end
				end
				local n = best[2]
				pos += Vector3.new(math.abs(n.X) * best[1], 0, math.abs(n.Z) * best[1])
				return pos, n, b
			end
		end
		return pos, nil, nil
	end

	local function clampCity(pos)
		local lim = HALF + 100
		return Vector3.new(
			math.clamp(pos.X, BASE.X - lim, BASE.X + lim),
			pos.Y,
			math.clamp(pos.Z, BASE.Z - lim, BASE.Z + lim)
		)
	end

	local function camVectors()
		local fwd = Vector3.new(math.sin(camYaw), 0, math.cos(camYaw))
		local right = Vector3.new(-math.cos(camYaw), 0, math.sin(camYaw))
		return fwd, right
	end

	local function inputDir()
		local a = input:GetAxes()
		local fwd, right = camVectors()
		local v = fwd * a.ly + right * a.lx
		if v.Magnitude > 1 then
			v = v.Unit
		end
		return v
	end

	-- Бандиты и вызовы
	local thugs = {}
	local crime = nil
	local nextCrime = 1.5
	local koTotal = 0

	local function hurtHero(amount, from)
		if hero.iframes > 0 then
			return
		end
		hero.hp -= amount
		hero.sinceHit = 0
		hero.iframes = 0.5
		if crime then
			crime.clean = false
		end
		local away = unitOr(flat(hero.pos - from), -hero.facing)
		if hero.state == "ground" then
			hero.vel = away * 28 + Y * 18
			hero.state = "air"
		end
		input:Rumble(0.6, 0.25)
		ctx.audio:Play("hit", { volume = 0.6 })
	end

	local function spawnThug(pos)
		local t = {
			fig = buildFigure(ctx.world, THUG),
			pos = pos,
			knock = Vector3.zero,
			hp = 3,
			state = "chase",
			t = 0,
			cd = 0.8 + rnd(),
			facing = Vector3.new(0, 0, 1),
			walk = rnd() * 6,
		}
		table.insert(thugs, t)
		return t
	end

	local beacon = part(ctx.world, Vector3.new(500, 10, 10), CFrame.new(BASE), CRIMSON, Enum.Material.Neon, 1, Enum.PartType.Cylinder)
	local function startCrime()
		local options = {}
		for _, p in crossings do
			if (flat(p - hero.pos)).Magnitude > 180 then
				table.insert(options, p)
			end
		end
		if #options == 0 then
			options = crossings
		end
		local p = options[1 + math.floor(rnd() * #options)]
		crime = { pos = p, phase = "travel", clean = true }
		beacon.CFrame = CFrame.new(p + Vector3.new(0, 250, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		beacon.Transparency = 0.55
		showToast("Crime in progress! Follow the red beacon")
		ctx.audio:Play("notify")
	end

	local function clearThugs()
		for _, t in thugs do
			t.fig.model:Destroy()
		end
		table.clear(thugs)
	end

	local function saveAll()
		ctx.save:Set("tokens", tokenStr)
		ctx.save:Set("crimes", stats.crimes)
		ctx.save:Set("webbed", stats.webbed)
		ctx.save:Set("topSpeed", math.floor(stats.topSpeed))
	end

	local function checkCrime()
		if not crime or crime.phase ~= "fight" then
			return
		end
		for _, t in thugs do
			if t.state ~= "down" then
				return
			end
		end
		stats.crimes += 1
		saveAll()
		ctx.trophies:Unlock("first_crime")
		if crime.clean then
			ctx.trophies:Unlock("untouchable")
		end
		if stats.crimes >= 10 then
			ctx.trophies:Unlock("hero")
		end
		hero.hp = MAX_HP
		showToast(crime.clean and "Crime stopped! Flawless" or "Crime stopped!")
		ctx.audio:Play("trophy", { volume = 0.5 })
		crime = nil
		nextCrime = 5
	end

	local function knockOut(t, dir)
		t.state = "down"
		t.t = 0
		t.knock = dir * 40
		t.fig.Web.part.Transparency = 1
		koTotal += 1
		ctx.audio:Play("explosion", { volume = 0.35, pitch = 1.4 })
		input:Rumble(0.8, 0.2)
		checkCrime()
	end

	local function nearestThug(range, needFree)
		local best, bestD = nil, range
		for _, t in thugs do
			if t.state ~= "down" and not (needFree and t.state == "stun") then
				local d = (t.pos + Y * 3 - (hero.pos + Y * 3)).Magnitude
				if d < bestD then
					best, bestD = t, d
				end
			end
		end
		return best, bestD
	end

	-- Действия героя
	local function startSwing()
		local f = unitOr(flat(hero.vel), hero.facing)
		local target = hero.pos + f * 55 + Y * 55
		local best, bestD = nil, math.huge
		for _, b in buildings do
			local c = Vector3.new(
				math.clamp(target.X, b.min.X, b.max.X),
				math.clamp(target.Y, GY, b.top),
				math.clamp(target.Z, b.min.Z, b.max.Z)
			)
			local d = (c - target).Magnitude
			if c.Y > hero.pos.Y + 10 and d < bestD and (flat(c - hero.pos)).Magnitude < 130 then
				best, bestD = c, d
			end
		end
		if not best then
			best = target -- над крышами цепляемся «за небо», чтобы полёт не обрывался
		end
		hero.anchor = best
		hero.ropeLen = (best - hero.pos).Magnitude
		hero.state = "swing"
		rope.Transparency = 0
		ctx.audio:Play("shoot", { volume = 0.35, pitch = 1.6 })
		ctx.trophies:Unlock("first_swing")
	end

	local function endSwing(boost)
		if hero.state ~= "swing" then
			return
		end
		hero.state = "air"
		hero.anchor = nil
		rope.Transparency = 1
		if boost then
			hero.vel += Y * 22 + unitOr(flat(hero.vel), hero.facing) * 10
		end
	end

	local function pressCross()
		if hero.state == "ground" then
			hero.vel += Y * JUMP
			hero.state = "air"
			ctx.audio:Play("move", { pitch = 0.8 })
		elseif hero.state == "wall" then
			hero.vel = hero.wallN * 42 + Y * 48
			hero.state = "air"
			hero.wall = nil
			hero.facing = flat(hero.wallN)
		elseif hero.state == "air" then
			startSwing()
		end
	end

	local function attack()
		if hero.attackCd > 0 then
			return
		end
		hero.attackCd = 0.28
		hero.punch = 0.2
		local range = hero.state == "ground" and 10 or 15
		local t, d = nearestThug(range, false)
		if not t then
			ctx.audio:Play("move", { pitch = 0.6, volume = 0.4 })
			return
		end
		endSwing(false)
		local dir = unitOr(flat(t.pos - hero.pos), hero.facing)
		hero.facing = dir
		if d > 3.5 then
			hero.pos = t.pos - dir * 3
			hero.pos = Vector3.new(hero.pos.X, math.max(hero.pos.Y, t.pos.Y), hero.pos.Z)
			hero.vel = Vector3.zero
		end
		hero.combo += 1
		hero.comboT = 1.6
		local finisher = hero.combo % 3 == 0
		input:Rumble(finisher and 0.7 or 0.35, 0.12)
		ctx.audio:Play("hit", { pitch = finisher and 0.8 or 1.1 })
		if t.state == "stun" or finisher then
			t.hp = 0
		else
			t.hp -= 1
			t.knock = dir * 18
			t.state = "chase"
			t.cd = math.max(t.cd, 0.5)
		end
		if t.hp <= 0 then
			knockOut(t, dir)
		end
	end

	local function shootWeb()
		if hero.webCd > 0 then
			return
		end
		hero.webCd = 0.6
		local t = nearestThug(48, true)
		ctx.audio:Play("shoot", { volume = 0.4, pitch = 1.3 })
		if not t then
			return
		end
		t.state = "stun"
		t.t = 4
		t.fig.Web.part.Transparency = 0.25
		stats.webbed += 1
		if stats.webbed >= 15 then
			ctx.trophies:Unlock("tangled")
		end
	end

	local function dodge()
		if hero.dodgeCd > 0 or hero.state == "swing" or hero.state == "wall" then
			return
		end
		hero.dodgeCd = 0.8
		hero.iframes = 0.45
		local d = inputDir()
		d = d.Magnitude > 0.2 and d.Unit or -hero.facing
		hero.vel = Vector3.new(0, hero.vel.Y, 0) + d * 50
		if hero.state == "ground" then
			hero.vel += Y * 12
			hero.state = "air"
		end
		ctx.audio:Play("move", { pitch = 1.3 })
	end

	local function respawn()
		hero.pos = START
		hero.vel = Vector3.zero
		hero.state = "ground"
		hero.hp = MAX_HP
		endSwing(false)
		clearThugs()
		if crime then
			crime.phase = "travel"
			crime.clean = true
			beacon.Transparency = 0.55
		end
		showToast("You were knocked out. Back at Night Tower")
	end

	-- Ввод
	ctx.input:On("press", function(btn)
		if state == "title" then
			if btn == "cross" then
				state = "play"
				overlay.Visible = false
				hud.Visible = true
				ctx.audio:Play("confirm")
			elseif btn == "circle" then
				ctx:Exit()
			end
			return
		elseif state == "pause" then
			if btn == "cross" or btn == "options" then
				state = "play"
				overlay.Visible = false
				hud.Visible = true
			elseif btn == "circle" then
				saveAll()
				ctx:Exit()
			end
			return
		end
		if btn == "options" then
			state = "pause"
			showOverlay("pause")
			hud.Visible = false
		elseif btn == "cross" then
			pressCross()
		elseif btn == "r2" then
			if hero.state == "air" then
				startSwing()
			end
		elseif btn == "square" then
			attack()
		elseif btn == "triangle" then
			shootWeb()
		elseif btn == "circle" then
			dodge()
		end
	end)
	ctx.input:On("release", function(btn)
		if state == "play" and (btn == "cross" or btn == "r2") and hero.state == "swing"
			and not input:IsDown("cross") and not input:IsDown("r2") then
			endSwing(true)
		end
	end)

	-- Физика героя
	local function enterWall(n, b)
		endSwing(false)
		hero.state = "wall"
		hero.wall = b
		hero.wallN = n
		hero.climbed = 0
		hero.vel = Vector3.zero
		hero.facing = -n
	end

	local function updateHero(dt)
		local dir = inputDir()
		local prevY = hero.pos.Y
		if hero.state == "wall" then
			local n, b = hero.wallN, hero.wall
			local into = dir:Dot(-n)
			if into < 0.2 then
				hero.state = "air"
				hero.vel = n * 10
				hero.wall = nil
			else
				local lateral = (dir + n * into) * 24
				hero.vel = Y * WALL_UP + lateral
				local p = hero.pos + hero.vel * dt
				-- держимся за грань
				if n.X ~= 0 then
					p = Vector3.new(n.X > 0 and b.max.X + R or b.min.X - R, p.Y, p.Z)
				else
					p = Vector3.new(p.X, p.Y, n.Z > 0 and b.max.Z + R or b.min.Z - R)
				end
				hero.pos = p
				hero.climbed += WALL_UP * dt
				if hero.climbed >= 80 then
					ctx.trophies:Unlock("wall_crawler")
				end
				local off = n.X ~= 0 and (p.Z < b.min.Z - R or p.Z > b.max.Z + R) or (n.X == 0 and (p.X < b.min.X - R or p.X > b.max.X + R))
				if p.Y >= b.top then
					hero.pos = Vector3.new(p.X, b.top + 0.2, p.Z)
					hero.vel = Y * 26 - n * 22
					hero.state = "air"
					hero.wall = nil
				elseif off then
					hero.state = "air"
					hero.wall = nil
				end
			end
			return
		end

		if hero.state == "ground" then
			local target = dir * RUN
			local hv = flat(hero.vel)
			hv = hv:Lerp(target, math.min(1, dt * 10))
			hero.vel = hv
		elseif hero.state == "air" then
			hero.vel += dir * 30 * dt - Y * G * dt
		elseif hero.state == "swing" then
			hero.vel += dir * 38 * dt - Y * G * dt
			hero.ropeLen = math.max(hero.ropeLen - 6 * dt, 14)
		end
		if hero.vel.Magnitude > MAX_SPEED then
			hero.vel = hero.vel.Unit * MAX_SPEED
		end

		local pos = hero.pos + hero.vel * dt
		if hero.state == "swing" then
			local d = pos - hero.anchor
			if d.Magnitude > hero.ropeLen then
				local radial = d.Unit
				pos = hero.anchor + radial * hero.ropeLen
				local vr = hero.vel:Dot(radial)
				if vr > 0 then
					hero.vel -= radial * vr
				end
			end
			if pos.Y > hero.anchor.Y - 3 then
				endSwing(true)
			end
		end

		-- пол и крыши
		local floor = floorAt(pos, prevY)
		if pos.Y <= floor then
			pos = Vector3.new(pos.X, floor, pos.Z)
			if hero.state ~= "ground" then
				endSwing(false)
				hero.state = "ground"
				hero.vel = flat(hero.vel) * 0.6
				if hero.vel.Magnitude > 4 then
					input:Rumble(0.2, 0.08)
				end
			end
			hero.vel = flat(hero.vel)
		elseif hero.state == "ground" and pos.Y > floor + 0.05 then
			hero.state = "air"
		end

		-- стены
		local n, b
		pos, n, b = pushOut(pos, R)
		if n then
			local vn = hero.vel:Dot(n)
			if vn < 0 then
				hero.vel -= n * vn
			end
			local into = dir:Dot(-n)
			if into > 0.3 and pos.Y < b.top - 3 then
				enterWall(n, b)
			end
		end
		hero.pos = clampCity(pos)

		local hv = flat(hero.vel)
		if hv.Magnitude > 3 and hero.state ~= "wall" then
			hero.facing = hv.Unit
		end
		if hero.state == "ground" and floor == tower.top then
			ctx.trophies:Unlock("skyline")
		end
	end

	local function updateThugs(dt)
		local senseOn = false
		for i = #thugs, 1, -1 do
			local t = thugs[i]
			t.knock *= math.exp(-6 * dt)
			local root
			if t.state == "down" then
				t.t += dt
				t.pos = pushOut(t.pos + t.knock * dt, 1.2)
				root = CFrame.lookAt(t.pos + Y * 0.6, t.pos + Y * 0.6 + t.facing) * CFrame.Angles(-math.pi / 2, 0, 0)
				if t.t > 3 then
					t.fig.model:Destroy()
					table.remove(thugs, i)
				else
					poseFigure(t.fig, root * CFrame.new(0, -2.5, 0), 0, 0, 0)
				end
				continue
			end
			local toHero = flat(hero.pos - t.pos)
			local dist = toHero.Magnitude
			local dy = math.abs(hero.pos.Y - t.pos.Y)
			local step = Vector3.zero
			t.cd -= dt
			if t.state == "stun" then
				t.t -= dt
				if t.t <= 0 then
					t.state = "chase"
					t.fig.Web.part.Transparency = 1
				end
			elseif t.state == "chase" then
				if dist > 0.1 then
					t.facing = toHero.Unit
				end
				if dy < 7 and dist < 80 and dist > 3.4 then
					step = t.facing * 15
					t.walk += dt * 9
				elseif dy < 6 and dist <= 4.5 and t.cd <= 0 then
					t.state = "windup"
					t.t = 0.55
				end
			elseif t.state == "windup" then
				senseOn = true
				t.t -= dt
				if t.t <= 0 then
					if dist < 5.5 and dy < 5 then
						hurtHero(12, t.pos)
					end
					t.state = "chase"
					t.cd = 1.1 + rnd() * 0.8
				end
			end
			-- не толпиться
			for _, o in thugs do
				if o ~= t and o.state ~= "down" then
					local away = flat(t.pos - o.pos)
					if away.Magnitude < 3 and away.Magnitude > 0.01 then
						step += away.Unit * 6
					end
				end
			end
			local p = t.pos + (step + t.knock) * dt
			t.pos = Vector3.new(p.X, t.pos.Y, p.Z)
			t.pos = pushOut(t.pos, 1.2)
			root = CFrame.lookAt(t.pos, t.pos + t.facing)
			local s = math.sin(t.walk) * 0.7
			local armUp = t.state == "windup" and -2.6 or (t.state == "stun" and 0 or -s)
			poseFigure(t.fig, root, s, -s, armUp)
		end
		return senseOn
	end

	local function updateCrime(dt)
		if not crime then
			nextCrime -= dt
			if nextCrime <= 0 then
				startCrime()
			end
			return
		end
		if crime.phase == "travel" and (flat(crime.pos - hero.pos)).Magnitude < 55 then
			crime.phase = "fight"
			beacon.Transparency = 1
			local count = math.min(3 + math.floor(stats.crimes / 2), 6)
			for k = 1, count do
				local a = k / count * math.pi * 2
				spawnThug(crime.pos + Vector3.new(math.cos(a) * 12, 0, math.sin(a) * 12))
			end
			showToast("Take them down!")
		end
	end

	local function updateTokens()
		for k, t in tokens do
			if not t.got then
				t.part.CFrame = CFrame.new(t.pos + Y * math.sin(clock * 2 + k) * 0.5) * CFrame.Angles(0, clock * 2 + k, 0)
				if (t.pos - (hero.pos + Y * 2.5)).Magnitude < 5 then
					t.got = true
					t.part:Destroy()
					t.part = nil
					tokenStr = tokenStr:sub(1, k - 1) .. "1" .. tokenStr:sub(k + 1)
					saveAll()
					local n = tokenCount()
					showToast(`Spider token {n}/{TOKENS}`)
					ctx.audio:Play("confirm", { pitch = 1.3 })
					if n >= TOKENS then
						ctx.trophies:Unlock("collector")
					end
				end
			end
		end
	end

	local function updateCamera(dt)
		local a = input:GetAxes()
		local turn = a.rx
		if input:IsDown("l1") then
			turn -= 1
		end
		if input:IsDown("r1") then
			turn += 1
		end
		if math.abs(turn) > 0.1 then
			camYaw -= turn * 2.4 * dt
			camManual = 1.2
		else
			camManual -= dt
		end
		local hv = flat(hero.vel)
		if camManual <= 0 and hv.Magnitude > 14 and hero.state ~= "wall" then
			local want = math.atan2(hv.X, hv.Z)
			local diff = (want - camYaw + math.pi) % (math.pi * 2) - math.pi
			camYaw += diff * math.min(1, dt * (hero.state == "swing" and 2.2 or 1.5))
		end
		local fwd = camVectors()
		local speed = hero.vel.Magnitude
		local dist = 16 + speed * 0.06
		local height = hero.state == "wall" and 3 or 6
		local focus = hero.pos + Y * 3.5
		local camPos = focus - fwd * dist + Y * height
		camSmooth = camSmooth and camSmooth:Lerp(camPos, math.min(1, dt * 10)) or camPos
		camera.CFrame = CFrame.lookAt(camSmooth, focus + fwd * 6)
		camera.FieldOfView = 70 + math.min(speed, MAX_SPEED) * 0.12
	end

	local function updateHeroModel(senseOn)
		local up = Y
		if hero.state == "swing" and hero.anchor then
			up = unitOr((hero.anchor - hero.pos).Unit + Y, Y)
		end
		local root = CFrame.lookAt(hero.pos, hero.pos + hero.facing, up)
		local speed = flat(hero.vel).Magnitude
		local legA, legB, armUp = 0, 0, 0
		if hero.state == "ground" then
			hero.run += speed * 0.12 * (1 / 60)
			legA = math.sin(hero.run * 6) * math.min(speed / RUN, 1) * 0.9
			legB = -legA
			armUp = legA
		elseif hero.state == "swing" then
			legA, legB, armUp = 0.5, 0.3, -3.0
		elseif hero.state == "wall" then
			local s = math.sin(clock * 14) * 0.7
			legA, legB, armUp = s, -s, -2.4 + s
		else
			legA, legB, armUp = 0.6, -0.4, -1.2
		end
		if hero.punch > 0 then
			armUp = -1.6
		end
		-- на стене тело наклонено к стене, на тросе — вдоль троса
		if hero.state == "wall" then
			root = root * CFrame.Angles(0.35, 0, 0)
		end
		poseFigure(fig, root, legA, legB, armUp)
		fig.Sense.part.Transparency = senseOn and (math.sin(clock * 30) > 0 and 0 or 0.6) or 1
		if hero.state == "swing" and hero.anchor then
			local hand = hero.pos + up * 6
			local len = (hero.anchor - hand).Magnitude
			rope.Size = Vector3.new(0.18, 0.18, len)
			rope.CFrame = CFrame.lookAt((hand + hero.anchor) / 2, hero.anchor)
		end
	end

	local function updateHud()
		hpFill.Size = UDim2.fromScale(math.clamp(hero.hp / MAX_HP, 0, 1), 1)
		statsLabel.Text = `Crimes stopped: {stats.crimes}\nTokens: {tokenCount()}/{TOKENS}`
		local speed = math.floor(hero.vel.Magnitude)
		speedLabel.Text = `{speed} <font size="24">SPD</font>`
		speedLabel.RichText = true
		local target
		if crime and crime.phase == "travel" then
			target = crime.pos
			objective.Text = `Crime in progress · {math.floor((flat(crime.pos - hero.pos)).Magnitude)} m`
		elseif crime then
			local left = 0
			for _, t in thugs do
				if t.state ~= "down" then
					left += 1
				end
			end
			objective.Text = `Thugs left: {left}`
		else
			objective.Text = "Patrol the city · find spider tokens"
		end
		if target then
			local fwd, right = camVectors()
			local d = flat(target - hero.pos)
			arrow.Visible = true
			arrow.Rotation = math.deg(math.atan2(d:Dot(right), d:Dot(fwd)))
		else
			arrow.Visible = false
		end
		comboLabel.Text = hero.combo >= 2 and `x{hero.combo} COMBO` or ""
		if hero.state == "wall" then
			hint.Text = `{g("cross")} leap off  ·  let go of the stick to drop`
		elseif hero.state == "swing" then
			hint.Text = `Release {g("cross")} to fly`
		elseif hero.state == "air" then
			hint.Text = `Hold {g("cross")} to swing`
		else
			hint.Text = `{g("cross")} jump  ·  {g("square")} punch  ·  {g("triangle")} web  ·  {g("circle")} dodge  ·  {g("options")} pause`
		end
	end

	ctx:Loop(function(dt)
		dt = math.min(dt, 1 / 20)
		clock += dt
		if state == "title" then
			local a = clock * 0.12
			local center = Vector3.new(tower.center.X, GY + 160, tower.center.Z)
			camera.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(a) * 320, 60, math.cos(a) * 320), center)
			updateTokens()
			updateHeroModel(false)
			return
		elseif state == "pause" then
			return
		end
		hero.attackCd -= dt
		hero.webCd -= dt
		hero.dodgeCd -= dt
		hero.iframes -= dt
		hero.punch -= dt
		hero.sinceHit += dt
		hero.comboT -= dt
		if hero.comboT <= 0 then
			hero.combo = 0
		end
		if hero.sinceHit > 4 then
			hero.hp = math.min(MAX_HP, hero.hp + 6 * dt)
		end
		updateHero(dt)
		local senseOn = updateThugs(dt)
		updateCrime(dt)
		updateTokens()
		updateCamera(dt)
		updateHeroModel(senseOn)
		updateHud()
		local speed = hero.vel.Magnitude
		if speed > stats.topSpeed then
			stats.topSpeed = speed
		end
		if speed >= 150 then
			ctx.trophies:Unlock("velocity")
		end
		if hero.hp <= 0 then
			respawn()
		end
		if toastT > 0 then
			toastT -= dt
			if toastT < 0.6 then
				toast.TextTransparency = 1 - math.max(toastT, 0) / 0.6
			end
		end
	end)

	ctx:On("pause", function()
		if state == "play" then
			state = "pause"
			showOverlay("pause")
			hud.Visible = false
		end
	end)
	ctx:On("exit", function()
		saveAll()
		camera.FieldOfView = 70
	end)

	-- Для дымового теста
	Game.debug = setmetatable({ hero = hero, thugs = thugs, buildings = buildings, tower = tower, tokenList = tokens }, {
		__index = function(_, k)
			if k == "state" then
				return state
			elseif k == "crime" then
				return crime
			elseif k == "stats" then
				return stats
			elseif k == "tokens" then
				return tokenCount()
			end
			return nil
		end,
	})
	Game.debug.startCrime = function()
		nextCrime = 0
	end
	Game.debug.look = function(yaw)
		camYaw = yaw
		camManual = 99
	end
	Game.debug.teleport = function(p)
		hero.pos = p
		hero.vel = Vector3.zero
		hero.state = "air"
	end
end

return Game
