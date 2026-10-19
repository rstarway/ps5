-- Neon Drive — 3D-гонка по ночному неоновому городу. Две гонки: Clock Run (3 круга, чекпоинты
-- добавляют время) и Time Trial (свободные круги против призрака лучшего круга).
-- Машина едет по своей аркадной физике (без физики Roblox): газ, тормоз, занос, ускорение.
local Track = require(script.Track)

local Game = {}

local BASE = Vector3.new(9000, 300, 0) -- трасса далеко от чиллзоны
local LAPS = 3
local MAX_SPEED, BOOST_SPEED, REVERSE_SPEED = 150, 205, 35
local ACCEL, BRAKE, DRAG = 110, 170, 0.32
local TURN = 2.0
local GRIP, DRIFT_GRIP = 8, 3.2
local KMH = 1.3 -- studs/s → «км/ч» на спидометре
local CAR_HALF = 3.6
local CLOCK_START, CLOCK_BONUS = 24, 9
local ACE_LAP = 30
local DRIFT_KING = 12000
local GHOST_STEP = 0.1
local PAD_SPOTS = {
	{ index = 64, offset = 0 }, { index = 92, offset = -8 }, { index = 148, offset = 8 },
	{ index = 170, offset = 0 }, { index = 210, offset = -10 },
}

local PINK = Track.Colors.pink
local VIOLET = Track.Colors.violet
local CYAN = Track.Colors.cyan
local AMBER = Track.Colors.amber
local WHITE = Color3.new(1, 1, 1)

local function cross(a, b)
	return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end

local function fmtTime(t)
	if not t then
		return "--:--.--"
	end
	local m = math.floor(t / 60)
	local s = t - m * 60
	return string.format("%d:%05.2f", m, s)
end

local function fmtNumber(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- Детали машины: размер, смещение (вправо, вверх, вперёд), цвет, материал, прозрачность, форма
local CAR_PARTS = {
	{ name = "Body", size = Vector3.new(7, 1.6, 13), at = Vector3.new(0, 1.7, 0), color = PINK, material = Enum.Material.SmoothPlastic },
	{ name = "Nose", size = Vector3.new(6.4, 0.9, 3), at = Vector3.new(0, 1.3, 7.2), color = PINK, material = Enum.Material.SmoothPlastic },
	{ name = "Cabin", size = Vector3.new(5.6, 1.5, 5.5), at = Vector3.new(0, 3.2, -0.8), color = Color3.fromRGB(14, 10, 26), material = Enum.Material.Glass, transparency = 0.15 },
	{ name = "Spoiler", size = Vector3.new(7.2, 0.3, 1.6), at = Vector3.new(0, 3.7, -6), color = Color3.fromRGB(20, 14, 36), material = Enum.Material.SmoothPlastic },
	{ name = "SpoilerL", size = Vector3.new(0.3, 1.2, 0.6), at = Vector3.new(-2.6, 3, -6), color = Color3.fromRGB(20, 14, 36) },
	{ name = "SpoilerR", size = Vector3.new(0.3, 1.2, 0.6), at = Vector3.new(2.6, 3, -6), color = Color3.fromRGB(20, 14, 36) },
	{ name = "StripeL", size = Vector3.new(0.15, 0.3, 11), at = Vector3.new(-3.56, 1.7, 0), color = CYAN, material = Enum.Material.Neon },
	{ name = "StripeR", size = Vector3.new(0.15, 0.3, 11), at = Vector3.new(3.56, 1.7, 0), color = CYAN, material = Enum.Material.Neon },
	{ name = "Glow", size = Vector3.new(6.4, 0.2, 12), at = Vector3.new(0, 0.6, 0), color = CYAN, material = Enum.Material.Neon, transparency = 0.2 },
	{ name = "HeadL", size = Vector3.new(1.6, 0.4, 0.2), at = Vector3.new(-2.3, 1.6, 8.75), color = WHITE, material = Enum.Material.Neon },
	{ name = "HeadR", size = Vector3.new(1.6, 0.4, 0.2), at = Vector3.new(2.3, 1.6, 8.75), color = WHITE, material = Enum.Material.Neon },
	{ name = "TailL", size = Vector3.new(2, 0.4, 0.2), at = Vector3.new(-2.2, 2.1, -6.55), color = Color3.fromRGB(150, 0, 30), material = Enum.Material.Neon },
	{ name = "TailR", size = Vector3.new(2, 0.4, 0.2), at = Vector3.new(2.2, 2.1, -6.55), color = Color3.fromRGB(150, 0, 30), material = Enum.Material.Neon },
	{ name = "FlameL", size = Vector3.new(0.9, 0.7, 3), at = Vector3.new(-1.5, 1.4, -8.2), color = AMBER, material = Enum.Material.Neon, transparency = 1 },
	{ name = "FlameR", size = Vector3.new(0.9, 0.7, 3), at = Vector3.new(1.5, 1.4, -8.2), color = AMBER, material = Enum.Material.Neon, transparency = 1 },
	{ name = "WheelFL", size = Vector3.new(1.4, 2.6, 2.6), at = Vector3.new(-3.6, 1.3, 4.2), color = Color3.fromRGB(12, 12, 16), shape = Enum.PartType.Cylinder },
	{ name = "WheelFR", size = Vector3.new(1.4, 2.6, 2.6), at = Vector3.new(3.6, 1.3, 4.2), color = Color3.fromRGB(12, 12, 16), shape = Enum.PartType.Cylinder },
	{ name = "WheelRL", size = Vector3.new(1.4, 2.6, 2.6), at = Vector3.new(-3.6, 1.3, -4.2), color = Color3.fromRGB(12, 12, 16), shape = Enum.PartType.Cylinder },
	{ name = "WheelRR", size = Vector3.new(1.4, 2.6, 2.6), at = Vector3.new(3.6, 1.3, -4.2), color = Color3.fromRGB(12, 12, 16), shape = Enum.PartType.Cylinder },
}

local GHOST_PARTS = {
	{ name = "Body", size = Vector3.new(7, 1.6, 13), at = Vector3.new(0, 1.7, 0), color = CYAN, material = Enum.Material.Neon, transparency = 0.75 },
	{ name = "Cabin", size = Vector3.new(5.6, 1.5, 5.5), at = Vector3.new(0, 3.2, -0.8), color = CYAN, material = Enum.Material.Neon, transparency = 0.8 },
	{ name = "Glow", size = Vector3.new(6.4, 0.2, 12), at = Vector3.new(0, 0.6, 0), color = CYAN, material = Enum.Material.Neon, transparency = 0.6 },
}

local function buildCar(parent, spec, name)
	local model = Instance.new("Model")
	model.Name = name
	local parts = {}
	for _, s in spec do
		local p = Track.part(model, s.size, CFrame.new(BASE), s.color, s.material, s.transparency)
		p.Name = s.name
		if s.shape then
			p.Shape = s.shape
		end
		parts[s.name] = p
		table.insert(parts, { part = p, at = s.at })
	end
	model.Parent = parent
	parts.model = model
	return parts
end

-- Ставит модель машины: pos — точка на дороге, f — горизонтальное направление, slope — уклон.
local function placeCar(parts, pos, f, slope)
	local f3 = Vector3.new(f.X, slope, f.Z).Unit
	local r = Vector3.new(-f.Z, 0, f.X)
	local u = cross(r, f3)
	for _, e in ipairs(parts) do
		local wp = pos + r * e.at.X + u * e.at.Y + f3 * e.at.Z
		e.part.CFrame = CFrame.lookAt(wp, wp + f3, u)
	end
end

local function encodeGhost(frames)
	local out = table.create(#frames)
	for i, fr in frames do
		out[i] = string.format("%d,%d,%d,%d", fr[1], fr[2], fr[3], fr[4])
	end
	return table.concat(out, ";")
end

local function decodeGhost(str)
	if type(str) ~= "string" or str == "" then
		return nil
	end
	local frames = {}
	for a, b, c, d in str:gmatch("([%-%d]+),([%-%d]+),([%-%d]+),([%-%d]+)") do
		table.insert(frames, { tonumber(a), tonumber(b), tonumber(c), tonumber(d) })
	end
	return #frames > 1 and frames or nil
end

function Game.launch(ctx)
	local ui = ctx.ui
	local theme = ctx.theme
	ctx.gui.BackgroundTransparency = 1

	-- Мир
	local track = Track.new(BASE)
	local N = track.N
	local SECTOR = N / 4
	local checkpoints = { 1, SECTOR + 1, SECTOR * 2 + 1, SECTOR * 3 + 1 }
	local built = track:build(ctx.world, checkpoints, PAD_SPOTS)
	local carParts = buildCar(ctx.world, CAR_PARTS, "Car")
	local ghostParts = buildCar(ctx.world, GHOST_PARTS, "Ghost")
	local glowLight = Instance.new("PointLight")
	glowLight.Color = CYAN
	glowLight.Range = 16
	glowLight.Brightness = 3
	glowLight.Parent = carParts.Glow
	local headLight = Instance.new("SpotLight")
	headLight.Range = 60
	headLight.Angle = 50
	headLight.Brightness = 3
	headLight.Face = Enum.NormalId.Front
	headLight.Parent = carParts.Nose
	local cam = ctx.camera
	cam.CameraType = Enum.CameraType.Scriptable

	-- Сохранения
	local bestLap = ctx.save:Get("best_lap", nil)
	local bestClock = ctx.save:Get("best_clock", nil)
	local bestDrift = ctx.save:Get("best_drift", 0)
	local ghost = decodeGhost(ctx.save:Get("ghost", nil))

	-- HUD
	local canvas = ui.canvas(ctx.gui)
	local function label(props)
		props.Parent = props.Parent or canvas
		props.Font = props.Font or theme.FontHeavy
		props.TextStrokeTransparency = props.TextStrokeTransparency or 0.6
		return ui.text(props.Text or "", props)
	end
	local hud = ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = canvas })
	local lapLabel = label({ Parent = hud, Size = UDim2.fromOffset(500, 70), Position = UDim2.fromOffset(60, 40), TextSize = 64 })
	local timeLabel = label({ Parent = hud, Size = UDim2.fromOffset(600, 40), Position = UDim2.fromOffset(62, 112), TextSize = 34, Font = theme.FontBold })
	local bestLabel = label({ Parent = hud, Size = UDim2.fromOffset(600, 34), Position = UDim2.fromOffset(62, 152), TextSize = 26, Font = theme.FontMedium, TextColor3 = Color3.fromRGB(200, 190, 255) })
	local clockLabel = label({ Parent = hud, Size = UDim2.fromOffset(600, 110), Position = UDim2.fromOffset(660, 30), TextSize = 96, TextXAlignment = Enum.TextXAlignment.Center })
	local clockBonus = label({ Parent = hud, Size = UDim2.fromOffset(600, 50), Position = UDim2.fromOffset(660, 136), TextSize = 40, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = CYAN, TextTransparency = 1, TextStrokeTransparency = 1 })
	local speedLabel = label({ Parent = hud, Size = UDim2.fromOffset(420, 130), Position = UDim2.fromOffset(1440, 820), TextSize = 128, TextXAlignment = Enum.TextXAlignment.Right })
	label({ Parent = hud, Text = "KM/H", Size = UDim2.fromOffset(420, 34), Position = UDim2.fromOffset(1440, 940), TextSize = 28, Font = theme.FontBold, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 150, 190) })
	local boostBack = ui.new("Frame", {
		Size = UDim2.fromOffset(420, 18), Position = UDim2.fromOffset(1440, 990), BackgroundColor3 = Color3.fromRGB(30, 20, 60), BackgroundTransparency = 0.2, Parent = hud,
	}, { ui.corner(9), ui.stroke(CYAN, 2, 0.4) })
	local boostFill = ui.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = CYAN, Parent = boostBack }, { ui.corner(9), ui.gradient({ CYAN, PINK }, 0) })
	label({ Parent = hud, Text = "BOOST", Size = UDim2.fromOffset(200, 26), Position = UDim2.fromOffset(1440, 1012), TextSize = 22, Font = theme.FontBold, TextColor3 = CYAN })
	local driftLabel = label({ Parent = hud, Size = UDim2.fromOffset(800, 60), Position = UDim2.fromOffset(560, 700), TextSize = 52, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = AMBER })
	local bigLabel = label({ Size = UDim2.fromOffset(1920, 200), Position = UDim2.fromOffset(0, 300), TextSize = 150, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
	local msgLabel = label({ Size = UDim2.fromOffset(1920, 60), Position = UDim2.fromOffset(0, 230), TextSize = 48, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })

	-- Мини-карта
	local MAP_SIZE = 260
	local minimap = ui.new("Frame", {
		Size = UDim2.fromOffset(MAP_SIZE + 40, MAP_SIZE + 40), Position = UDim2.fromOffset(50, 730),
		BackgroundColor3 = Color3.fromRGB(10, 6, 24), BackgroundTransparency = 0.35, Parent = hud,
	}, { ui.corner(20), ui.stroke(VIOLET, 2, 0.3) })
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, s in track.samples do
		minX, maxX = math.min(minX, s.X), math.max(maxX, s.X)
		minZ, maxZ = math.min(minZ, s.Z), math.max(maxZ, s.Z)
	end
	local mapScale = MAP_SIZE / math.max(maxX - minX, maxZ - minZ)
	local function mapPos(p)
		local ox = (MAP_SIZE - (maxX - minX) * mapScale) / 2
		local oz = (MAP_SIZE - (maxZ - minZ) * mapScale) / 2
		return UDim2.fromOffset(20 + ox + (p.X - minX) * mapScale, 20 + oz + (p.Z - minZ) * mapScale)
	end
	for i = 1, N, 2 do
		ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5, 5), Position = mapPos(track.samples[i]),
			BackgroundColor3 = (i - 1) % SECTOR == 0 and WHITE or Color3.fromRGB(150, 110, 255), BorderSizePixel = 0, Parent = minimap,
		})
	end
	local ghostDot = ui.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = CYAN, Visible = false, ZIndex = 2, Parent = minimap }, { ui.corner(6) })
	local carDot = ui.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = PINK, ZIndex = 3, Parent = minimap }, { ui.corner(8), ui.stroke(WHITE, 2) })

	-- Меню (заставка, пауза, итоги)
	local menuFrame = ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 600), Size = UDim2.fromOffset(760, 560),
		BackgroundColor3 = Color3.fromRGB(14, 6, 34), BackgroundTransparency = 0.15, ZIndex = 10, Parent = canvas,
	}, { ui.corner(28), ui.stroke(PINK, 3, 0.2), ui.gradient({ Color3.fromRGB(80, 20, 120), Color3.fromRGB(20, 6, 50) }, 90) })
	local menuTitle = label({ Parent = menuFrame, Size = UDim2.new(1, 0, 0, 90), Position = UDim2.fromOffset(0, 26), TextSize = 72, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11 })
	local menuSub = label({ Parent = menuFrame, Size = UDim2.new(1, -60, 0, 90), Position = UDim2.fromOffset(30, 112), TextSize = 28, Font = theme.FontMedium, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(220, 200, 255), ZIndex = 11 })
	local menuRows = {}
	for i = 1, 4 do
		local row = ui.new("Frame", {
			Size = UDim2.new(1, -120, 0, 64), Position = UDim2.fromOffset(60, 200 + (i - 1) * 76),
			BackgroundColor3 = PINK, BackgroundTransparency = 1, ZIndex = 11, Parent = menuFrame,
		}, { ui.corner(16) })
		local text = label({ Parent = row, Size = UDim2.fromScale(1, 1), TextSize = 36, Font = theme.FontBold, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 12 })
		menuRows[i] = { frame = row, text = text }
	end
	local menuHint = label({ Parent = menuFrame, Size = UDim2.new(1, -60, 0, 36), Position = UDim2.new(0, 30, 1, -56), TextSize = 22, Font = theme.FontMedium, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(190, 170, 230), ZIndex = 11 })
	local logo = label({ Size = UDim2.fromOffset(1920, 170), Position = UDim2.fromOffset(0, 90), Text = "NEON DRIVE", TextSize = 160, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, ZIndex = 9 })
	ui.gradient({ PINK, Color3.fromRGB(255, 140, 200), CYAN }, 0).Parent = logo
	local tagline = label({ Size = UDim2.fromOffset(1920, 40), Position = UDim2.fromOffset(0, 250), Text = "Drift, boost and beat the clock", TextSize = 34, Font = theme.FontBold, TextColor3 = Color3.fromRGB(230, 210, 255), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9 })

	local menu = { items = {}, index = 1 }
	local function drawMenu()
		for i, row in menuRows do
			local item = menu.items[i]
			row.frame.Visible = item ~= nil
			if item then
				local selected = i == menu.index
				row.text.Text = item.label
				row.frame.BackgroundTransparency = selected and 0.1 or 0.85
				row.text.TextColor3 = selected and WHITE or Color3.fromRGB(220, 200, 255)
			end
		end
		local item = menu.items[menu.index]
		menuHint.Text = (item and item.hint) or `{ctx.input:Glyph("cross")} select    {ctx.input:Glyph("circle")} back`
	end
	local function openMenu(title, sub, items, onBack)
		menu.items, menu.index, menu.onBack = items, 1, onBack
		menuTitle.Text = title
		menuSub.Text = sub or ""
		menuFrame.Visible = true
		drawMenu()
	end
	local function closeMenu()
		menuFrame.Visible = false
		menu.items = {}
	end

	-- Состояние машины и заезда
	local car = { pos = BASE, yaw = 0, vx = 0, vz = 0, idx = 1, lateral = 0, slope = 0, fwd = 0, lat = 0 }
	local race = {}
	local state = "title" -- title | countdown | race | paused | results
	local pausedFrom = nil
	local mode = "clock"
	local camPos = BASE + Vector3.new(0, 30, -60)
	local orbit = 0
	local messageTimer, bonusTimer = 0, 0
	Game._debug = { car = car, race = race, track = track, getState = function()
		return state
	end }

	local function message(text, color, seconds)
		msgLabel.Text = text
		msgLabel.TextColor3 = color or WHITE
		messageTimer = seconds or 1.6
	end

	local function placeAt(index)
		local p = track:sample(index)
		local t = track.tangents[(index - 1) % N + 1]
		car.pos, car.yaw, car.vx, car.vz = p, math.atan2(t.Z, t.X), 0, 0
		car.idx = (index - 1) % N + 1
		car.slope, car.lateral, car.fwd, car.lat = 0, 0, 0, 0
		placeCar(carParts, car.pos, Vector3.new(math.cos(car.yaw), 0, math.sin(car.yaw)), 0)
	end

	local function setGhostVisible(v)
		for _, e in ipairs(ghostParts) do
			e.part.Parent = v and ghostParts.model or nil
		end
		ghostDot.Visible = v
	end

	local function flashGate(index, color)
		local bars = built.gates[index]
		if not bars then
			return
		end
		for _, b in bars do
			local original = b.Color
			b.Color = color
			task.delay(0.6, function()
				if b.Parent then
					b.Color = original
				end
			end)
		end
	end

	local titleScreen -- объявлено ниже

	local function startRace(newMode)
		mode = newMode or mode
		closeMenu()
		logo.Visible, tagline.Visible = false, false
		hud.Visible = true
		placeAt(2)
		table.clear(race)
		race.lap, race.lapTime, race.raceTime = 1, 0, 0
		race.timeLeft = CLOCK_START
		race.sector = 0
		race.lapClean, race.lapPads = true, {}
		race.drift, race.driftChain, race.driftTime, race.driftOff = 0, 0, 0, 0
		race.boost, race.boostPad, race.boosting = 0, 0, false
		race.countdown, race.lastCount = 3.5, 4
		race.frames, race.recordTimer = {}, 0
		race.hitCooldown = 0
		race.ghostBeaten = false
		clockLabel.Visible = mode == "clock"
		setGhostVisible(mode == "trial" and ghost ~= nil)
		bigLabel.Text = ""
		driftLabel.Text = ""
		camPos = car.pos + Vector3.new(0, 30, 0) - track.tangents[2] * 60
		state = "countdown"
	end

	local function finishRace(success)
		state = "results"
		local lines
		if mode == "clock" then
			if success then
				ctx.trophies:Unlock("beat_clock")
				local record = bestClock == nil or race.raceTime < bestClock
				if record then
					bestClock = race.raceTime
					ctx.save:Set("best_clock", bestClock)
				end
				ctx.audio:Play("trophy", { volume = 0.5 })
				lines = `Total {fmtTime(race.raceTime)}{record and "   NEW RECORD!" or ""}\nTime left {string.format("%.1f", race.timeLeft)} s   Drift {fmtNumber(race.drift)}`
			else
				ctx.audio:Play("error", { volume = 0.6, pitch = 0.7 })
				ctx.input:Rumble(0.8, 0.5)
				lines = `Out of time on lap {race.lap} of {LAPS}\nDrift {fmtNumber(race.drift)}   Best lap {fmtTime(bestLap)}`
			end
		else
			lines = `Best lap {fmtTime(bestLap)}   Drift {fmtNumber(race.drift)}`
		end
		if race.drift > bestDrift then
			bestDrift = math.floor(race.drift)
			ctx.save:Set("best_drift", bestDrift)
		end
		ctx.save:Set("races", ctx.save:Get("races", 0) + 1)
		bigLabel.Text = ""
		local title = mode == "clock" and (success and "FINISH!" or "TIME UP") or "SESSION OVER"
		openMenu(title, lines, {
			{ label = "Race Again", action = function()
				startRace(mode)
			end },
			{ label = "Main Menu", action = function()
				titleScreen()
			end },
		}, function()
			titleScreen()
		end)
	end

	local function lapDone()
		local t = race.lapTime
		ctx.trophies:Unlock("green_light")
		if race.lapClean then
			ctx.trophies:Unlock("clean_line")
		end
		local allPads = true
		for _, spot in PAD_SPOTS do
			if not race.lapPads[spot.index] then
				allPads = false
			end
		end
		if allPads then
			ctx.trophies:Unlock("pad_hopper")
		end
		if t < ACE_LAP then
			ctx.trophies:Unlock("neon_ace")
		end
		local hadGhost = ghost ~= nil
		if bestLap == nil or t < bestLap then
			if mode == "trial" and hadGhost then
				ctx.trophies:Unlock("ghost_buster")
			end
			bestLap = t
			ctx.save:Set("best_lap", bestLap)
			if #race.frames > 1 then
				ghost = race.frames
				ctx.save:Set("ghost", encodeGhost(ghost))
			end
			message(`BEST LAP {fmtTime(t)}`, AMBER, 2.2)
			ctx.audio:Play("notify", { volume = 0.6, pitch = 1.2 })
		else
			message(`LAP {fmtTime(t)}`, WHITE, 1.8)
			ctx.audio:Play("notify", { volume = 0.5 })
		end
		race.lap += 1
		race.lapTime = 0
		race.lapClean = true
		race.lapPads = {}
		race.frames, race.recordTimer = {}, 0
		if mode == "trial" then
			setGhostVisible(ghost ~= nil)
		end
		if mode == "clock" and race.lap > LAPS then
			race.lap = LAPS
			finishRace(true)
			return true
		end
		if mode == "clock" and race.lap == LAPS then
			message("FINAL LAP", PINK, 2)
		end
		return false
	end

	local function endDrift()
		if race.driftChain > 0 then
			local pts = math.floor(race.driftChain)
			race.drift += pts
			driftLabel.Text = `+{fmtNumber(pts)} DRIFT`
			driftLabel.TextTransparency = 0
			task.delay(1.2, function()
				if driftLabel.Parent and race.driftChain == 0 then
					driftLabel.Text = ""
				end
			end)
			if mode == "clock" and race.drift >= DRIFT_KING then
				ctx.trophies:Unlock("drift_king")
			end
		end
		race.driftChain, race.driftTime = 0, 0
	end

	-- Физика и правила одного кадра заезда
	local function drive(dt, controls)
		local f = Vector3.new(math.cos(car.yaw), 0, math.sin(car.yaw))
		local r = Vector3.new(-f.Z, 0, f.X)
		local fwd = car.vx * f.X + car.vz * f.Z
		local lat = car.vx * r.X + car.vz * r.Z
		local boosting = race.boostPad > 0 or (controls.boost and race.boost > 0)
		if boosting and not race.boosting then
			ctx.audio:Play("shoot", { volume = 0.35, pitch = 0.45 })
			ctx.input:Rumble(0.4, 0.2)
		end
		race.boosting = boosting
		if race.boostPad > 0 then
			race.boostPad -= dt
		elseif boosting then
			race.boost = math.max(0, race.boost - 0.5 * dt)
		end
		local maxNow = boosting and BOOST_SPEED or MAX_SPEED

		-- газ, тормоз, сопротивление
		if boosting then
			fwd += 160 * dt * math.max(0, 1 - fwd / maxNow)
		end
		if controls.throttle > 0 and fwd >= -1 then
			fwd += controls.throttle * ACCEL * dt * math.max(0, 1 - fwd / maxNow)
		end
		if controls.brake > 0 then
			if fwd > 1 then
				fwd = math.max(0, fwd - controls.brake * BRAKE * dt)
			else
				fwd = math.max(-REVERSE_SPEED, fwd - controls.brake * 40 * dt)
			end
		elseif controls.throttle > 0 and fwd < 0 then
			fwd = math.min(0, fwd + BRAKE * dt)
		end
		fwd -= fwd * DRAG * dt
		if fwd > maxNow then
			fwd -= (fwd - maxNow) * 1.5 * dt
		end

		-- руль: на месте не поворачивает, на скорости чуть тупее, в заносе острее
		local speedFactor = math.clamp(math.abs(fwd) / 25, 0, 1) * (1 - 0.4 * math.clamp(math.abs(fwd) / MAX_SPEED, 0, 1))
		local drifting = controls.drift and fwd > 35
		local turn = controls.steer * TURN * speedFactor * (drifting and 1.3 or 1) * (fwd < 0 and -1 or 1)
		car.yaw += turn * dt

		-- сцепление: боковая скорость гаснет; в заносе медленно, и часть её уходит в скорость вперёд
		local latBefore = math.abs(lat)
		lat *= math.exp(-(drifting and DRIFT_GRIP or GRIP) * dt)
		if drifting then
			fwd += (latBefore - math.abs(lat)) * 0.85
		end
		local nf = Vector3.new(math.cos(car.yaw), 0, math.sin(car.yaw))
		local nr = Vector3.new(-nf.Z, 0, nf.X)
		if drifting then
			-- в заносе скорость сохраняет прежнее направление, а машина поворачивается: её несёт боком
			car.vx = f.X * fwd + r.X * lat
			car.vz = f.Z * fwd + r.Z * lat
		else
			car.vx = nf.X * fwd + nr.X * lat
			car.vz = nf.Z * fwd + nr.Z * lat
		end
		local nlat = car.vx * nr.X + car.vz * nr.Z
		car.fwd, car.lat = car.vx * nf.X + car.vz * nf.Z, nlat

		-- движение и проекция на трассу
		local newPos = car.pos + Vector3.new(car.vx, 0, car.vz) * dt
		local idx, t, lateral, point, tangent, slope = track:project(newPos, car.idx)
		local limit = Track.WIDTH / 2 - CAR_HALF
		if math.abs(lateral) > limit then
			local side = lateral > 0 and 1 or -1
			local n = Vector3.new(-tangent.Z, 0, tangent.X) * side
			newPos -= n * (math.abs(lateral) - limit)
			local vn = car.vx * n.X + car.vz * n.Z
			if vn > 0 then
				local loss = 1 - math.clamp(vn / 160, 0.02, 0.45)
				car.vx = (car.vx - n.X * vn * 1.3) * loss
				car.vz = (car.vz - n.Z * vn * 1.3) * loss
				if vn > 12 and race.hitCooldown <= 0 then
					race.hitCooldown = 0.4
					race.lapClean = false
					race.driftChain, race.driftTime = 0, 0
					driftLabel.Text = ""
					ctx.audio:Play("hit", { volume = math.clamp(vn / 80, 0.2, 0.8), pitch = 0.9 })
					ctx.input:Rumble(math.clamp(vn / 80, 0.3, 1), 0.2)
				end
			end
			lateral = side * limit
		end
		race.hitCooldown -= dt
		car.pos = Vector3.new(newPos.X, point.Y, newPos.Z)
		car.idx, car.lateral, car.slope = idx, lateral, slope

		local speed = math.sqrt(car.vx ^ 2 + car.vz ^ 2)
		if state ~= "race" then
			return speed
		end

		-- ускорители на дороге
		for _, pad in built.pads do
			if idx == pad.index or idx == pad.index - 1 then
				if math.abs(lateral - pad.offset) < 7 and race.boostPad <= 0 then
					race.boostPad = 1.3
					race.lapPads[pad.index] = true
					message("BOOST!", CYAN, 0.8)
				end
			end
		end

		-- занос: очки и заряд ускорения
		local slip = math.abs(nlat)
		if slip > 9 and speed > 35 then
			race.driftTime += dt
			race.driftOff = 0
			race.driftChain += slip * dt * 10
			race.boost = math.min(1, race.boost + dt * 0.12)
			driftLabel.Text = `DRIFT {fmtNumber(race.driftChain)}`
			if race.driftTime >= 3 then
				ctx.trophies:Unlock("sideways")
			end
		elseif race.driftChain > 0 then
			race.driftOff += dt
			if race.driftOff > 0.35 then
				endDrift()
			end
		end

		-- сектора, круги и время
		local sector = math.floor((idx - 1) / SECTOR)
		if sector == (race.sector + 1) % 4 then
			race.sector = sector
			flashGate(checkpoints[sector + 1], sector == 0 and AMBER or PINK)
			if sector == 0 then
				if lapDone() then
					return speed
				end
			end
			if mode == "clock" then
				race.timeLeft += CLOCK_BONUS
				clockBonus.Text = `+{CLOCK_BONUS} s`
				clockBonus.TextTransparency, clockBonus.TextStrokeTransparency = 0, 0.6
				bonusTimer = 1.4
				if sector ~= 0 then
					ctx.audio:Play("confirm", { volume = 0.4, pitch = 1.3 })
				end
			end
		end
		return speed
	end

	local function readControls()
		local axes = ctx.input:GetAxes()
		local keyboard = ctx.input:Device() ~= "gamepad"
		local throttle = math.max(axes.r2, ctx.input:IsDown("cross") and 1 or 0, (keyboard and axes.ly > 0.3) and axes.ly or 0)
		local brake = math.max(axes.l2, ctx.input:IsDown("square") and 1 or 0, (keyboard and axes.ly < -0.3) and -axes.ly or 0)
		return {
			throttle = throttle,
			brake = brake,
			steer = math.clamp(axes.lx, -1, 1),
			drift = ctx.input:IsDown("circle") or ctx.input:IsDown("l1"),
			boost = ctx.input:IsDown("triangle") or ctx.input:IsDown("r1"),
		}
	end

	local IDLE = { throttle = 0, brake = 0.3, steer = 0, drift = false, boost = false }

	local function updateCamera(dt, speed)
		local f = Vector3.new(math.cos(car.yaw), 0, math.sin(car.yaw))
		local back = 17 + speed * 0.03
		local target = car.pos - f * back + Vector3.new(0, 6.5, 0)
		camPos = camPos:Lerp(target, 1 - math.exp(-7 * dt))
		local look = car.pos + f * 10 + Vector3.new(0, 2.5, 0)
		cam.CFrame = CFrame.lookAt(camPos, look)
		cam.FieldOfView = 68 + math.clamp(speed / MAX_SPEED, 0, 1.4) * 14
	end

	local function updateCarVisual()
		local f = Vector3.new(math.cos(car.yaw), 0, math.sin(car.yaw))
		placeCar(carParts, car.pos, f, car.slope)
		local flame = race.boosting and 0.05 + math.random() * 0.3 or 1
		carParts.FlameL.Transparency, carParts.FlameR.Transparency = flame, flame
		local braking = state == "race" and race.braking
		local tail = braking and Color3.fromRGB(255, 30, 60) or Color3.fromRGB(150, 0, 30)
		carParts.TailL.Color, carParts.TailR.Color = tail, tail
		carDot.Position = mapPos(car.pos)
	end

	local function updateGhost()
		if mode ~= "trial" or not ghost or state ~= "race" then
			return
		end
		local k = race.lapTime / GHOST_STEP + 1
		local i = math.floor(k)
		local a, b = ghost[i], ghost[i + 1]
		if not a or not b then
			setGhostVisible(false)
			return
		end
		if not ghostDot.Visible then
			setGhostVisible(true)
		end
		local w = k - i
		local x = (a[1] + (b[1] - a[1]) * w) / 2 + BASE.X
		local z = (a[2] + (b[2] - a[2]) * w) / 2 + BASE.Z
		local y = (a[3] + (b[3] - a[3]) * w) / 4 + BASE.Y
		local yaw = (a[4] + (b[4] - a[4]) * w) / 100
		local pos = Vector3.new(x, y, z)
		placeCar(ghostParts, pos, Vector3.new(math.cos(yaw), 0, math.sin(yaw)), 0)
		ghostDot.Position = mapPos(pos)
	end

	local function recordFrame(dt)
		race.recordTimer -= dt
		if race.recordTimer <= 0 then
			race.recordTimer += GHOST_STEP
			if #race.frames < 1200 then
				table.insert(race.frames, {
					math.floor((car.pos.X - BASE.X) * 2 + 0.5), math.floor((car.pos.Z - BASE.Z) * 2 + 0.5),
					math.floor((car.pos.Y - BASE.Y) * 4 + 0.5), math.floor(car.yaw * 100 + 0.5),
				})
			end
		end
	end

	local function updateHud(speed)
		if mode == "clock" then
			lapLabel.Text = `LAP {race.lap}/{LAPS}`
			local tl = math.max(0, race.timeLeft)
			clockLabel.Text = string.format("%.1f", tl)
			clockLabel.TextColor3 = tl < 5 and Color3.fromRGB(255, 70, 90) or WHITE
		else
			lapLabel.Text = `LAP {race.lap}`
		end
		timeLabel.Text = `TIME {fmtTime(race.lapTime)}`
		bestLabel.Text = `BEST {fmtTime(bestLap)}`
		speedLabel.Text = tostring(math.floor(speed * KMH))
		speedLabel.TextColor3 = race.boosting and CYAN or WHITE
		boostFill.Size = UDim2.fromScale(race.boost, 1)
	end

	-- Экраны меню
	local pauseMenu
	function titleScreen()
		state = "title"
		hud.Visible = false
		logo.Visible, tagline.Visible = true, true
		bigLabel.Text, msgLabel.Text = "", ""
		setGhostVisible(false)
		placeAt(2)
		local records = `Best lap {fmtTime(bestLap)}    Clock Run {fmtTime(bestClock)}    Drift {fmtNumber(bestDrift)}`
		openMenu("", records, {
			{ label = "Clock Run", hint = `{LAPS} laps. Every checkpoint adds {CLOCK_BONUS} seconds.`, action = function()
				startRace("clock")
			end },
			{ label = "Time Trial", hint = "Free laps against the ghost of your best lap.", action = function()
				startRace("trial")
			end },
			{ label = "Quit to PS5 Menu", action = function()
				ctx:Exit()
			end },
		}, function()
			ctx:Exit()
		end)
		menuTitle.Text = "MAIN MENU"
	end

	function pauseMenu()
		if state ~= "race" and state ~= "countdown" then
			return
		end
		pausedFrom = state
		state = "paused"
		local items = {
			{ label = "Resume", action = function()
				closeMenu()
				state = pausedFrom
			end },
			{ label = "Restart", action = function()
				startRace(mode)
			end },
		}
		if mode == "trial" then
			table.insert(items, { label = "End Session", action = function()
				finishRace(false)
			end })
		else
			table.insert(items, { label = "Main Menu", action = function()
				titleScreen()
			end })
		end
		table.insert(items, { label = "Quit to PS5 Menu", action = function()
			ctx:Exit()
		end })
		openMenu("PAUSED", mode == "clock" and "Clock Run" or "Time Trial", items, items[1].action)
	end

	ctx.input:On("press", function(btn)
		if menuFrame.Visible then
			if btn == "up" or btn == "down" then
				menu.index = (menu.index - 1 + (btn == "down" and 1 or -1)) % #menu.items + 1
				ctx.audio:Play("move", { volume = 0.3, pitch = 1.4 })
				drawMenu()
			elseif btn == "cross" then
				local item = menu.items[menu.index]
				if item then
					ctx.audio:Play("confirm", { volume = 0.4 })
					item.action()
				end
			elseif btn == "circle" and menu.onBack then
				ctx.audio:Play("back", { volume = 0.4 })
				menu.onBack()
			elseif btn == "options" and state == "paused" then
				menu.items[1].action()
			end
		elseif btn == "options" then
			pauseMenu()
		end
	end)

	-- Кнопка PS ставит игру на паузу системой; показываем и своё меню паузы
	ctx:On("pause", function()
		pauseMenu()
	end)

	ctx:Loop(function(dt)
		dt = math.min(dt, 1 / 20)
		if messageTimer > 0 then
			messageTimer -= dt
			if messageTimer <= 0 then
				msgLabel.Text = ""
			end
		end
		if bonusTimer > 0 then
			bonusTimer -= dt
			local a = 1 - math.clamp(bonusTimer / 0.6, 0, 1)
			clockBonus.TextTransparency, clockBonus.TextStrokeTransparency = a, 0.6 + a * 0.4
		end

		if state == "title" then
			orbit += dt * 0.22
			local center = car.pos + Vector3.new(0, 3, 0)
			camPos = center + Vector3.new(math.cos(orbit) * 30, 9 + math.sin(orbit * 0.7) * 3, math.sin(orbit) * 30)
			cam.CFrame = CFrame.lookAt(camPos, center)
			cam.FieldOfView = 60
			return
		elseif state == "paused" then
			return
		elseif state == "countdown" then
			race.countdown -= dt
			local n = math.ceil(race.countdown - 0.5)
			if n < race.lastCount then
				race.lastCount = n
				if n >= 1 then
					bigLabel.Text = tostring(n)
					bigLabel.TextColor3 = n == 1 and AMBER or PINK
					ctx.audio:Play("move", { volume = 0.7, pitch = 0.8 })
				end
			end
			if race.countdown <= 0.5 then
				bigLabel.Text = "GO!"
				bigLabel.TextColor3 = CYAN
				ctx.audio:Play("confirm", { volume = 0.8, pitch = 1.5 })
				state = "race"
				task.delay(0.8, function()
					if bigLabel.Parent and bigLabel.Text == "GO!" then
						bigLabel.Text = ""
					end
				end)
			end
			updateCamera(dt, 0)
			updateCarVisual()
			updateHud(0)
			return
		end

		local controls = state == "race" and readControls() or IDLE
		race.braking = controls.brake > 0.1
		if state == "race" then
			race.lapTime += dt
			race.raceTime += dt
			recordFrame(dt)
		end
		local speed = drive(dt, controls)
		if state == "race" and mode == "clock" then
			race.timeLeft -= dt
			if race.timeLeft <= 0 then
				race.timeLeft = 0
				finishRace(false)
			end
		end
		updateCamera(dt, speed)
		updateCarVisual()
		updateGhost()
		if state == "race" then
			updateHud(speed)
		end
	end)

	titleScreen()
end

return Game
