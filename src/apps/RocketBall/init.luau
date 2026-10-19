-- Rocket Ball — футбол на машинах 1 на 1 против бота. 3D-стадион в ctx.world, HUD в ctx.gui.
-- Физика своя (анкерные детали, ручной расчёт), поэтому игра одинаково ведёт себя в Studio и в дымовом тесте.
local Game = {}

-- Стадион стоит далеко от чиллзоны, чтобы её не было видно
local OX, OY, OZ = 0, 600, 3200

-- Поле: x от -FIELD_X до FIELD_X, z от -FIELD_Z до FIELD_Z. Синие защищают ворота на -z, оранжевые на +z.
local FIELD_X, FIELD_Z = 50, 80
local CEILING = 34
local GOAL_W, GOAL_H, GOAL_D = 16, 14, 12 -- полуширина, высота, глубина ворот
local BALL_R = 4

-- Машина: x, y — центр днища; передом смотрит в локальную -Z (как LookVector в Roblox)
local CAR_HX, CAR_HY, CAR_HZ = 2.6, 1.9, 4.4 -- полуразмеры корпуса для ударов по мячу
local CAR_R = 3.6 -- радиус для столкновений со стенами
local ACCEL, BRAKE, MAX_SPEED, MAX_REVERSE = 55, 110, 62, 30
local BOOST_ACCEL, MAX_BOOST_SPEED, BOOST_USE = 80, 100, 34
local TURN_RATE, AIR_TURN, GRIP = 2.7, 2.2, 7
local GRAVITY, JUMP_SPEED, DODGE_SPEED = 70, 30, 36
local BALL_GRAVITY, BALL_MAX_SPEED = 42, 115

local BLUE = Color3.fromRGB(0, 180, 216)
local ORANGE = Color3.fromRGB(255, 140, 40)

local DIFFICULTIES = {
	{ name = "Rookie", throttle = 0.72, react = 0.45, predict = 0.4, boost = 0.25, jump = 0.15, aim = 9 },
	{ name = "Pro", throttle = 0.88, react = 0.25, predict = 0.8, boost = 0.6, jump = 0.5, aim = 5 },
	{ name = "All-Star", throttle = 1, react = 0.1, predict = 1, boost = 1, jump = 0.9, aim = 2 },
}
local LENGTHS = { 120, 180, 300 }

local function wrapAngle(a)
	return (a + math.pi) % (2 * math.pi) - math.pi
end

local function at(x, y, z)
	return CFrame.new(OX + x, OY + y, OZ + z)
end

local function vec(x, y, z)
	return Vector3.new(OX + x, OY + y, OZ + z)
end

function Game.launch(ctx)
	local ui = ctx.ui
	local world = ctx.world
	local manifest = ctx.manifest

	---------------------------------------------------------------- стадион
	local function part(props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = Enum.Material.SmoothPlastic
		for k, v in props do
			p[k] = v
		end
		p.Parent = props.Parent or world
		return p
	end

	local arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena.Parent = world

	-- Земля вокруг и полосатый газон
	part({ Name = "Ground", Size = Vector3.new(420, 2, 520), CFrame = at(0, -1.6, 0), Color = Color3.fromRGB(14, 18, 32), Parent = arena })
	local STRIPES = 10
	for i = 0, STRIPES - 1 do
		local len = FIELD_Z * 2 / STRIPES
		part({
			Name = "Grass",
			Size = Vector3.new(FIELD_X * 2, 1, len),
			CFrame = at(0, -0.5, -FIELD_Z + len * (i + 0.5)),
			Material = Enum.Material.Grass,
			Color = i % 2 == 0 and Color3.fromRGB(46, 140, 72) or Color3.fromRGB(38, 122, 62),
			Parent = arena,
		})
	end

	-- Разметка
	local LINE = Color3.fromRGB(235, 245, 255)
	local function line(x, z, sx, sz)
		part({ Name = "Line", Size = Vector3.new(sx, 0.1, sz), CFrame = at(x, 0.02, z), Material = Enum.Material.Neon, Color = LINE, Transparency = 0.25, Parent = arena })
	end
	line(0, 0, FIELD_X * 2, 0.6)
	line(-FIELD_X + 0.6, 0, 0.6, FIELD_Z * 2)
	line(FIELD_X - 0.6, 0, 0.6, FIELD_Z * 2)
	for _, s in { -1, 1 } do
		line(0, s * (FIELD_Z - 0.6), FIELD_X * 2, 0.6)
		line(0, s * (FIELD_Z - 18), 48, 0.6)
		line(-24, s * (FIELD_Z - 9), 0.6, 18)
		line(24, s * (FIELD_Z - 9), 0.6, 18)
	end
	for i = 1, 36 do
		local a = i / 36 * math.pi * 2
		part({
			Name = "Circle", Size = Vector3.new(0.6, 0.1, 2.9),
			CFrame = at(math.cos(a) * 14, 0.02, math.sin(a) * 14) * CFrame.Angles(0, -a, 0),
			Material = Enum.Material.Neon, Color = LINE, Transparency = 0.25, Parent = arena,
		})
	end

	-- Стены из стекла с неоновой кромкой цвета команды
	local GLASS = Color3.fromRGB(150, 210, 255)
	local function wall(x, y, z, sx, sy, sz)
		part({ Name = "Wall", Size = Vector3.new(sx, sy, sz), CFrame = at(x, y, z), Material = Enum.Material.Glass, Color = GLASS, Transparency = 0.82, Parent = arena })
	end
	local function rail(x, y, z, sx, sz, color)
		part({ Name = "Rail", Size = Vector3.new(sx, 0.6, sz), CFrame = at(x, y, z), Material = Enum.Material.Neon, Color = color, Parent = arena })
	end
	for _, s in { -1, 1 } do
		wall(s * (FIELD_X + 0.5), CEILING / 2, 0, 1, CEILING, FIELD_Z * 2)
		rail(s * (FIELD_X + 0.5), CEILING, -FIELD_Z / 2, 1.2, FIELD_Z, BLUE)
		rail(s * (FIELD_X + 0.5), CEILING, FIELD_Z / 2, 1.2, FIELD_Z, ORANGE)
		rail(s * (FIELD_X + 0.5), 0.3, -FIELD_Z / 2, 1.2, FIELD_Z, BLUE)
		rail(s * (FIELD_X + 0.5), 0.3, FIELD_Z / 2, 1.2, FIELD_Z, ORANGE)
		local color = s < 0 and BLUE or ORANGE
		local side = (FIELD_X - GOAL_W) / 2
		wall(-FIELD_X + side, CEILING / 2, s * (FIELD_Z + 0.5), side * 2, CEILING, 1)
		wall(FIELD_X - side, CEILING / 2, s * (FIELD_Z + 0.5), side * 2, CEILING, 1)
		wall(0, (CEILING + GOAL_H) / 2, s * (FIELD_Z + 0.5), GOAL_W * 2, CEILING - GOAL_H, 1)
		rail(0, CEILING, s * (FIELD_Z + 0.5), FIELD_X * 2, 1.2, color)

		-- Ворота: неоновая рамка, сетка из силового поля, тёмный пол
		local zFront, zBack = s * FIELD_Z, s * (FIELD_Z + GOAL_D)
		local zMid = (zFront + zBack) / 2
		for _, px in { -GOAL_W, GOAL_W } do
			part({ Name = "Post", Size = Vector3.new(1, GOAL_H, 1), CFrame = at(px, GOAL_H / 2, zFront), Material = Enum.Material.Neon, Color = color, Parent = arena })
			part({ Name = "Net", Size = Vector3.new(0.4, GOAL_H, GOAL_D), CFrame = at(px, GOAL_H / 2, zMid), Material = Enum.Material.ForceField, Color = color, Parent = arena })
		end
		part({ Name = "Crossbar", Size = Vector3.new(GOAL_W * 2 + 1, 1, 1), CFrame = at(0, GOAL_H, zFront), Material = Enum.Material.Neon, Color = color, Parent = arena })
		part({ Name = "Net", Size = Vector3.new(GOAL_W * 2, GOAL_H, 0.4), CFrame = at(0, GOAL_H / 2, zBack), Material = Enum.Material.ForceField, Color = color, Parent = arena })
		part({ Name = "Net", Size = Vector3.new(GOAL_W * 2, 0.4, GOAL_D), CFrame = at(0, GOAL_H, zMid), Material = Enum.Material.ForceField, Color = color, Parent = arena })
		part({ Name = "GoalFloor", Size = Vector3.new(GOAL_W * 2, 1, GOAL_D), CFrame = at(0, -0.5, zMid), Color = color:Lerp(Color3.new(0, 0, 0), 0.6), Parent = arena })
		local glow = part({ Name = "GoalGlow", Size = Vector3.new(GOAL_W * 2, 0.1, 1.2), CFrame = at(0, 0.03, zFront), Material = Enum.Material.Neon, Color = color, Parent = arena })
		glow.Transparency = 0.1
	end

	-- Трибуны со зрителями и мачты освещения
	local CROWD = { Color3.fromRGB(0, 180, 216), Color3.fromRGB(255, 140, 40), Color3.fromRGB(240, 240, 250), Color3.fromRGB(255, 214, 10), Color3.fromRGB(120, 90, 220) }
	for _, s in { -1, 1 } do
		for tier = 1, 4 do
			local x = s * (FIELD_X + 6 + tier * 6)
			part({ Name = "Stand", Size = Vector3.new(6, tier * 4, FIELD_Z * 2 + 20), CFrame = at(x, tier * 2, 0), Color = Color3.fromRGB(28, 34, 58), Parent = arena })
			for _ = 1, 14 do
				part({
					Name = "Fan", Size = Vector3.new(1.4, 2.2, 1.4),
					CFrame = at(x + (math.random() - 0.5) * 3, tier * 4 + 1.1, (math.random() - 0.5) * (FIELD_Z * 2 + 10)),
					Color = CROWD[math.random(#CROWD)], Parent = arena,
				})
			end
		end
		for _, z in { -FIELD_Z - 6, FIELD_Z + 6 } do
			local x = s * (FIELD_X + 40)
			part({ Name = "Mast", Size = Vector3.new(1.5, 60, 1.5), CFrame = at(x, 30, z), Color = Color3.fromRGB(60, 66, 90), Parent = arena })
			local lamp = part({ Name = "Lamp", Size = Vector3.new(10, 5, 1), CFrame = CFrame.lookAt(vec(x, 60, z), vec(0, 0, 0)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 250, 230), Parent = arena })
			local spot = Instance.new("SpotLight")
			spot.Range = 60
			spot.Angle = 70
			spot.Brightness = 3
			spot.Parent = lamp
		end
	end
	-- Свет над полем
	for _, z in { -55, 0, 55 } do
		for _, x in { -25, 25 } do
			local holder = part({ Name = "FieldLight", Size = Vector3.new(1, 1, 1), CFrame = at(x, CEILING + 6, z), Transparency = 1, Parent = arena })
			local light = Instance.new("PointLight")
			light.Range = 60
			light.Brightness = 1.6
			light.Color = Color3.fromRGB(235, 240, 255)
			light.Parent = holder
		end
	end

	---------------------------------------------------------------- подборы буста
	local pads = {}
	local function addPad(x, z, big)
		local p = part({
			Name = big and "BigBoost" or "Boost",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, big and 6 or 3.4, big and 6 or 3.4),
			CFrame = at(x, 0.1, z) * CFrame.Angles(0, 0, math.pi / 2),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 196, 40),
			Parent = arena,
		})
		local orb
		if big then
			orb = part({ Name = "BoostOrb", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), CFrame = at(x, 2.5, z), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 160, 20), Parent = arena })
		end
		table.insert(pads, { x = x, z = z, big = big, timer = 0, part = p, orb = orb })
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			addPad(sx * 42, sz * 70, true)
			addPad(sx * 24, sz * 30, false)
			addPad(sx * 34, sz * 52, false)
			addPad(sx * 8, sz * 62, false)
		end
		addPad(sx * 44, 0, true)
		addPad(sx * 18, 0, false)
		addPad(0, sx * 44, false)
	end

	---------------------------------------------------------------- мяч
	local ballPart = part({
		Name = "Ball", Shape = Enum.PartType.Ball, Size = Vector3.new(BALL_R * 2, BALL_R * 2, BALL_R * 2),
		Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(240, 244, 255),
	})
	local ballRing = part({
		Name = "BallRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, BALL_R * 2 + 0.1, BALL_R * 2 + 0.1), -- светящийся пояс вокруг мяча
		Material = Enum.Material.Neon, Color = Color3.fromRGB(0, 220, 255),
	})
	local ballLight = Instance.new("PointLight")
	ballLight.Range = 14
	ballLight.Brightness = 1
	ballLight.Color = Color3.fromRGB(150, 230, 255)
	ballLight.Parent = ballPart
	local shadow = part({
		Name = "BallShadow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, BALL_R * 2, BALL_R * 2),
		Color = Color3.new(0, 0, 0), Transparency = 0.5,
	})
	local ball = { x = 0, y = BALL_R, z = 0, vx = 0, vy = 0, vz = 0, spin = CFrame.new() }

	---------------------------------------------------------------- машины
	local function newCar(team, color)
		local dark = color:Lerp(Color3.new(0, 0, 0), 0.45)
		local car = { team = team, color = color, parts = {}, boost = 33, x = 0, y = 0, z = 0, vx = 0, vy = 0, vz = 0, yaw = 0 }
		local function piece(name, size, offset, props)
			local p = part({ Name = name, Size = size, Color = props.Color or color, Material = props.Material or Enum.Material.SmoothPlastic, Shape = props.Shape or Enum.PartType.Block })
			table.insert(car.parts, { part = p, offset = offset })
			return p
		end
		piece("Body", Vector3.new(5, 1.5, 8.4), CFrame.new(0, 1.45, 0), {})
		piece("Nose", Vector3.new(4.6, 0.8, 2), CFrame.new(0, 1.0, -4.6), { Color = dark })
		piece("Cabin", Vector3.new(4, 1.3, 3.8), CFrame.new(0, 2.85, 0.9), { Color = Color3.fromRGB(20, 26, 40), Material = Enum.Material.Glass })
		piece("Stripe", Vector3.new(1, 0.1, 8.5), CFrame.new(0, 2.22, 0), { Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon })
		piece("Spoiler", Vector3.new(5.2, 0.3, 1.3), CFrame.new(0, 3.1, 3.7), { Color = dark })
		piece("SpoilerPost", Vector3.new(0.3, 0.9, 0.5), CFrame.new(-1.8, 2.5, 3.7), { Color = dark })
		piece("SpoilerPost", Vector3.new(0.3, 0.9, 0.5), CFrame.new(1.8, 2.5, 3.7), { Color = dark })
		for _, hx in { -1.6, 1.6 } do
			piece("Headlight", Vector3.new(0.9, 0.4, 0.2), CFrame.new(hx, 1.6, -4.25), { Color = Color3.fromRGB(255, 250, 220), Material = Enum.Material.Neon })
		end
		for _, wx in { -2.6, 2.6 } do
			for _, wz in { -2.9, 2.9 } do
				piece("Wheel", Vector3.new(1.1, 2.2, 2.2), CFrame.new(wx, 1.1, wz), { Color = Color3.fromRGB(18, 18, 22), Shape = Enum.PartType.Cylinder })
			end
		end
		car.flame = piece("Flame", Vector3.new(1.8, 1, 2.6), CFrame.new(0, 1.5, 5.6), { Color = Color3.fromRGB(255, 120, 30), Material = Enum.Material.Neon })
		local flameLight = Instance.new("PointLight")
		flameLight.Range = 10
		flameLight.Brightness = 2
		flameLight.Color = Color3.fromRGB(255, 150, 60)
		flameLight.Parent = car.flame
		car.flameLight = flameLight
		return car
	end

	local player = newCar("blue", BLUE)
	local bot = newCar("orange", ORANGE)
	local cars = { player, bot }

	---------------------------------------------------------------- HUD
	local canvas = ui.canvas(ctx.gui)
	local font = ctx.theme.FontBold

	local board = ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 24), Size = UDim2.fromOffset(560, 96),
		BackgroundColor3 = Color3.fromRGB(6, 10, 30), BackgroundTransparency = 0.25, Parent = canvas,
	}, { ui.corner(18), ui.stroke(Color3.new(1, 1, 1), 2, 0.8) })
	local function scoreBox(x, color)
		local box = ui.new("Frame", { Position = UDim2.fromOffset(x, 10), Size = UDim2.fromOffset(110, 76), BackgroundColor3 = color, Parent = board }, { ui.corner(12) })
		return ui.text("0", { Size = UDim2.fromScale(1, 1), TextSize = 56, Font = font, TextXAlignment = Enum.TextXAlignment.Center, Parent = box })
	end
	local blueScore = scoreBox(10, BLUE)
	local orangeScore = scoreBox(440, ORANGE)
	local clock = ui.text("3:00", { Position = UDim2.fromOffset(120, 6), Size = UDim2.fromOffset(320, 60), TextSize = 50, Font = font, TextXAlignment = Enum.TextXAlignment.Center, Parent = board })
	local clockSub = ui.text("", { Position = UDim2.fromOffset(120, 60), Size = UDim2.fromOffset(320, 30), TextSize = 22, TextColor3 = Color3.fromRGB(180, 200, 230), TextXAlignment = Enum.TextXAlignment.Center, Parent = board })

	local boostFrame = ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromOffset(1880, 1040), Size = UDim2.fromOffset(200, 200),
		BackgroundColor3 = Color3.fromRGB(6, 10, 30), BackgroundTransparency = 0.25, Parent = canvas,
	}, { ui.corner(UDim.new(0.5, 0)), ui.stroke(Color3.fromRGB(255, 196, 40), 4, 0.2) })
	local boostText = ui.text("33", { Position = UDim2.fromOffset(0, 40), Size = UDim2.fromOffset(200, 80), TextSize = 72, Font = font, TextXAlignment = Enum.TextXAlignment.Center, Parent = boostFrame })
	ui.text("BOOST", { Position = UDim2.fromOffset(0, 118), Size = UDim2.fromOffset(200, 30), TextSize = 24, TextColor3 = Color3.fromRGB(255, 196, 40), TextXAlignment = Enum.TextXAlignment.Center, Parent = boostFrame })
	local boostBarBack = ui.new("Frame", { Position = UDim2.fromOffset(40, 152), Size = UDim2.fromOffset(120, 10), BackgroundColor3 = Color3.fromRGB(40, 46, 70), Parent = boostFrame }, { ui.corner(5) })
	local boostBar = ui.new("Frame", { Size = UDim2.fromScale(0.33, 1), BackgroundColor3 = Color3.fromRGB(255, 196, 40), Parent = boostBarBack }, { ui.corner(5) })

	local camLabel = ui.text("", { Position = UDim2.fromOffset(40, 1000), Size = UDim2.fromOffset(600, 40), TextSize = 24, TextColor3 = Color3.fromRGB(200, 215, 240), Parent = canvas })

	local bigText = ui.text("", {
		Position = UDim2.fromOffset(0, 330), Size = UDim2.fromOffset(1920, 200), TextSize = 150, Font = font,
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4, ZIndex = 5, Parent = canvas,
	})
	local subText = ui.text("", {
		Position = UDim2.fromOffset(0, 530), Size = UDim2.fromOffset(1920, 60), TextSize = 40, Font = font,
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5, ZIndex = 5, Parent = canvas,
	})

	-- Окно меню (титульный экран, пауза, итог матча)
	local overlay = ui.new("Frame", { Size = UDim2.fromOffset(1920, 1080), BackgroundColor3 = Color3.fromRGB(2, 4, 20), BackgroundTransparency = 0.45, ZIndex = 10, Visible = false, Parent = canvas })
	local panel = ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 540), Size = UDim2.fromOffset(820, 640),
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 11, Parent = overlay,
	}, {
		ui.corner(28),
		ui.gradient({ ui.hex(manifest.colors[1]):Lerp(Color3.new(0, 0, 0), 0.35), ui.hex(manifest.colors[2]) }, 90),
		ui.stroke(Color3.new(1, 1, 1), 2, 0.7),
	})
	local panelTitle = ui.text("", { Position = UDim2.fromOffset(0, 40), Size = UDim2.fromOffset(820, 90), TextSize = 76, Font = font, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 12, Parent = panel })
	local panelSub = ui.text("", { Position = UDim2.fromOffset(0, 134), Size = UDim2.fromOffset(820, 70), TextSize = 28, TextColor3 = Color3.fromRGB(200, 225, 245), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, ZIndex = 12, Parent = panel })
	local itemsFrame = ui.new("Frame", { Position = UDim2.fromOffset(110, 230), Size = UDim2.fromOffset(600, 340), BackgroundTransparency = 1, ZIndex = 12, Parent = panel }, { ui.list(nil, 14, Enum.HorizontalAlignment.Center) })
	local panelHint = ui.text("", { Position = UDim2.fromOffset(0, 580), Size = UDim2.fromOffset(820, 40), TextSize = 22, TextColor3 = Color3.fromRGB(170, 195, 225), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 12, Parent = panel })

	---------------------------------------------------------------- состояние матча
	local save = ctx.save
	local difficulty = math.clamp(save:Get("difficulty", 2), 1, #DIFFICULTIES)
	local lengthIndex = math.clamp(save:Get("length", 2), 1, #LENGTHS)

	local state = "menu" -- menu | kickoff | play | goal | paused | over
	local pausedFrom = nil
	local score = { blue = 0, orange = 0 }
	local timeLeft, overtime, overtimeTime = LENGTHS[lengthIndex], false, 0
	local stateTimer = 0
	local lastTouch, touchInAir = nil, false
	local playerGoals = 0
	local ballCam = save:Get("ballCam", true)
	local jumpQueued = false
	local effects = {}
	local ai = { tx = 0, tz = 0, think = 0, stuck = 0, reverse = 0 }

	local menuItems, menuIndex = {}, 1

	local function playSound(name, volume, pitch)
		ctx.audio:Play(name, { volume = volume or 0.5, pitch = pitch or 1 })
	end

	local function formatTime(t)
		t = math.max(0, math.ceil(t))
		return string.format("%d:%02d", t // 60, t % 60)
	end

	local function renderMenu()
		itemsFrame:ClearAllChildren()
		ui.list(nil, 14, Enum.HorizontalAlignment.Center).Parent = itemsFrame
		for i, item in menuItems do
			local selected = i == menuIndex
			local label = type(item.label) == "function" and item.label() or item.label
			local row = ui.new("Frame", {
				Size = UDim2.fromOffset(600, 64), LayoutOrder = i, ZIndex = 12,
				BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = selected and 0 or 0.88, Parent = itemsFrame,
			}, { ui.corner(14) })
			ui.text(item.cycle and `◀  {label}  ▶` or label, {
				Size = UDim2.fromScale(1, 1), TextSize = 32, Font = font, ZIndex = 13,
				TextColor3 = selected and Color3.fromRGB(3, 4, 60) or Color3.new(1, 1, 1),
				TextXAlignment = Enum.TextXAlignment.Center, Parent = row,
			})
		end
	end

	local function openMenu(title, sub, items)
		overlay.Visible = true
		panelTitle.Text = title
		panelSub.Text = sub or ""
		menuItems, menuIndex = items, 1
		panelHint.Text = `{ctx.input:Glyph("cross")} select    {ctx.input:Glyph("left")} {ctx.input:Glyph("right")} change`
		renderMenu()
	end

	local function closeMenu()
		overlay.Visible = false
	end

	---------------------------------------------------------------- расстановка
	local function placeCar(car, z)
		car.x, car.y, car.z = 0, 0, z
		car.vx, car.vy, car.vz = 0, 0, 0
		car.yaw = z < 0 and math.pi or 0 -- оба смотрят в центр
		car.onGround, car.jumps, car.airTime, car.flip, car.hitCooldown = true, 0, 0, 0, 0
		car.boost = math.max(car.boost, 33)
		car.boosting = false
	end

	local function resetKickoff()
		ball.x, ball.y, ball.z = 0, BALL_R, 0
		ball.vx, ball.vy, ball.vz = 0, 0, 0
		player.boost, bot.boost = 33, 33
		placeCar(player, -60)
		placeCar(bot, 60)
		lastTouch, touchInAir = nil, false
		jumpQueued = false
		state, stateTimer = "kickoff", 3
		ai.think, ai.stuck, ai.reverse = 0, 0, 0
	end

	local showMainMenu -- объявлено ниже

	local function startMatch()
		closeMenu()
		score.blue, score.orange = 0, 0
		playerGoals = 0
		timeLeft, overtime, overtimeTime = LENGTHS[lengthIndex], false, 0
		for _, pad in pads do
			pad.timer = 0
		end
		resetKickoff()
		playSound("confirm", 0.6)
	end

	local function endMatch()
		state = "over"
		local won = score.blue > score.orange
		save:Set("matches", save:Get("matches", 0) + 1)
		save:Set("goals", save:Get("goals", 0) + playerGoals)
		if won then
			save:Set("wins", save:Get("wins", 0) + 1)
			ctx.trophies:Unlock("first_win")
			if score.orange == 0 then
				ctx.trophies:Unlock("clean_sheet")
			end
			if overtime then
				ctx.trophies:Unlock("overtime_hero")
			end
			if difficulty == 3 then
				ctx.trophies:Unlock("all_star")
			end
			playSound("trophy", 0.6)
		else
			save:Set("losses", save:Get("losses", 0) + 1)
			playSound("error", 0.5, 0.7)
		end
		bigText.Text, subText.Text = "", ""
		openMenu(won and "VICTORY!" or "DEFEAT", `Blue {score.blue} : {score.orange} Orange{overtime and "  (overtime)" or ""}\nYour goals: {playerGoals}`, {
			{ label = "Rematch", action = startMatch },
			{ label = "Main Menu", action = function() showMainMenu() end },
			{ label = "Quit to PS5 Menu", action = function() ctx:Exit() end },
		})
	end

	function showMainMenu()
		state = "menu"
		bigText.Text, subText.Text = "", ""
		resetKickoff()
		state = "menu"
		local wins, losses = save:Get("wins", 0), save:Get("losses", 0)
		openMenu("ROCKET BALL", `{ctx.user.name}  ·  Record {wins}W - {losses}L  ·  Goals {save:Get("goals", 0)}`, {
			{ label = "Kick Off", action = startMatch },
			{
				label = function()
					return "Bot: " .. DIFFICULTIES[difficulty].name
				end,
				cycle = function(dir)
					difficulty = (difficulty - 1 + dir) % #DIFFICULTIES + 1
					save:Set("difficulty", difficulty)
				end,
			},
			{
				label = function()
					return "Match: " .. LENGTHS[lengthIndex] // 60 .. " min"
				end,
				cycle = function(dir)
					lengthIndex = (lengthIndex - 1 + dir) % #LENGTHS + 1
					save:Set("length", lengthIndex)
				end,
			},
			{ label = "Quit to PS5 Menu", action = function() ctx:Exit() end },
		})
	end

	local function pauseGame()
		if state == "paused" or state == "menu" or state == "over" then
			return
		end
		pausedFrom = state
		state = "paused"
		openMenu("PAUSED", `Blue {score.blue} : {score.orange} Orange  ·  {formatTime(timeLeft)}`, {
			{ label = "Resume", action = function()
				closeMenu()
				state = pausedFrom
			end },
			{ label = "Restart Match", action = startMatch },
			{ label = "Main Menu", action = function() showMainMenu() end },
			{ label = "Quit to PS5 Menu", action = function() ctx:Exit() end },
		})
	end

	---------------------------------------------------------------- эффекты
	local function goalBurst(z, color)
		local burst = part({ Name = "GoalBurst", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = at(0, GOAL_H / 2, z), Material = Enum.Material.Neon, Color = color })
		table.insert(effects, { part = burst, t = 0, life = 1.2, grow = 70 })
		for _ = 1, 24 do
			local bit = part({ Name = "Confetti", Size = Vector3.new(0.8, 0.8, 0.8), CFrame = at(0, GOAL_H / 2, z), Material = Enum.Material.Neon, Color = CROWD[math.random(#CROWD)] })
			table.insert(effects, {
				part = bit, t = 0, life = 2,
				x = 0, y = GOAL_H / 2, z = z,
				vx = (math.random() - 0.5) * 60, vy = 20 + math.random() * 30, vz = -math.sign(z) * (10 + math.random() * 40),
			})
		end
	end

	local function updateEffects(dt)
		for i = #effects, 1, -1 do
			local e = effects[i]
			e.t += dt
			local k = e.t / e.life
			if k >= 1 then
				e.part:Destroy()
				table.remove(effects, i)
			elseif e.grow then
				local s = 2 + e.grow * k
				e.part.Size = Vector3.new(s, s, s)
				e.part.Transparency = 0.2 + 0.8 * k
			else
				e.vy -= 40 * dt
				e.x += e.vx * dt
				e.y = math.max(0.4, e.y + e.vy * dt)
				e.z += e.vz * dt
				e.part.CFrame = at(e.x, e.y, e.z) * CFrame.Angles(e.t * 5, e.t * 3, 0)
				e.part.Transparency = math.max(0, k * 2 - 1)
			end
		end
	end

	---------------------------------------------------------------- физика машины
	local function updateCar(car, c, dt)
		car.hitCooldown = math.max(0, car.hitCooldown - dt)
		car.flip = math.max(0, car.flip - dt)
		car.boosting = c.boost and car.boost > 0
		if car.boosting then
			car.boost = math.max(0, car.boost - BOOST_USE * dt)
		end
		local fx, fz = -math.sin(car.yaw), -math.cos(car.yaw)

		if car.onGround then
			local speed = car.vx * fx + car.vz * fz
			local dir = speed >= 0 and 1 or -1
			-- поворот зависит от скорости; газ даёт немного поворота, даже если машина упёрлась в стену
			local grip = math.max(math.abs(speed), math.abs(c.throttle) * 8)
			if c.throttle < -0.05 and math.abs(speed) < 2 then
				dir = -1
			end
			car.yaw -= c.steer * TURN_RATE * math.clamp(grip / 16, 0, 1) * dir * dt
			fx, fz = -math.sin(car.yaw), -math.cos(car.yaw)
			local rx, rz = math.cos(car.yaw), -math.sin(car.yaw)
			local lateral = car.vx * rx + car.vz * rz

			-- аналоговый газ задаёт желаемую скорость: отпустил курок наполовину — машина едет медленнее
			local accel
			if c.throttle > 0.05 and speed > c.throttle * MAX_SPEED and not car.boosting then
				accel = -math.min(speed - c.throttle * MAX_SPEED, 30)
			elseif c.throttle > 0.05 then
				accel = speed < -1 and BRAKE or ACCEL
			elseif c.throttle < -0.05 then
				accel = c.throttle * (speed > 1 and BRAKE or ACCEL * 0.7)
			else
				accel = -speed * 1.6
			end
			if car.boosting then
				accel += BOOST_ACCEL
			end
			speed += accel * dt
			local cap = car.boosting and MAX_BOOST_SPEED or MAX_SPEED
			if speed > cap then
				speed = math.max(cap, speed - 90 * dt)
			end
			speed = math.max(speed, -MAX_REVERSE)
			lateral *= math.exp(-GRIP * dt)
			car.vx = fx * speed + rx * lateral
			car.vz = fz * speed + rz * lateral
			car.vy = 0
			if c.jump then
				car.vy = JUMP_SPEED
				car.onGround, car.jumps, car.airTime = false, 1, 0
			end
		else
			car.airTime += dt
			car.yaw -= c.steer * AIR_TURN * dt
			fx, fz = -math.sin(car.yaw), -math.cos(car.yaw)
			car.vy -= GRAVITY * dt
			if car.boosting then
				-- в воздухе буст тянет вперёд и немного вверх: так можно долететь до высокого мяча
				car.vx += fx * BOOST_ACCEL * dt
				car.vz += fz * BOOST_ACCEL * dt
				car.vy += GRAVITY * 0.8 * dt + BOOST_ACCEL * 0.25 * dt
			end
			if c.jump and car.jumps == 1 and car.airTime < 1.6 then
				-- второй прыжок в воздухе: рывок с сальто вперёд
				car.vx += fx * DODGE_SPEED
				car.vz += fz * DODGE_SPEED
				car.vy = math.max(car.vy, 6)
				car.jumps, car.flip = 2, 0.5
			end
			local h = math.sqrt(car.vx * car.vx + car.vz * car.vz)
			if h > MAX_BOOST_SPEED + 20 then
				local k = (MAX_BOOST_SPEED + 20) / h
				car.vx *= k
				car.vz *= k
			end
		end

		car.x += car.vx * dt
		car.y += car.vy * dt
		car.z += car.vz * dt

		-- пол и потолок
		if car.y <= 0 then
			car.y = 0
			if not car.onGround then
				car.onGround, car.jumps, car.flip = true, 0, 0
				if car == player then
					ctx.input:Rumble(0.2, 0.08)
				end
			end
			car.vy = 0
		end
		if car.y > CEILING - 3 then
			car.y = CEILING - 3
			car.vy = math.min(car.vy, 0)
		end
		-- стены и ворота
		local az = math.abs(car.z)
		if az > FIELD_Z - 0.5 then
			-- внутри ворот: боковые сетки, перекладина и задняя сетка
			local gx = GOAL_W - CAR_R
			car.x = math.clamp(car.x, -gx, gx)
			car.y = math.min(car.y, GOAL_H - 4)
			local back = FIELD_Z + GOAL_D - CAR_R
			if az > back then
				car.z = math.sign(car.z) * back
				if car.vz * car.z > 0 then
					car.vz *= -0.2
				end
			end
		elseif az > FIELD_Z - CAR_R then
			local inMouth = math.abs(car.x) < GOAL_W - CAR_R and car.y < GOAL_H - 4
			if not inMouth then
				car.z = math.sign(car.z) * (FIELD_Z - CAR_R)
				if car.vz * car.z > 0 then
					car.vz *= -0.2
				end
			end
		end
		local xl = FIELD_X - CAR_R
		if math.abs(car.x) > xl then
			car.x = math.sign(car.x) * xl
			if car.vx * car.x > 0 then
				car.vx *= -0.2
			end
		end
	end

	---------------------------------------------------------------- мяч
	local function updateBall(dt)
		ball.vy -= BALL_GRAVITY * dt
		local drag = math.exp(-0.15 * dt)
		ball.vx *= drag
		ball.vy *= drag
		ball.vz *= drag
		ball.x += ball.vx * dt
		ball.y += ball.vy * dt
		ball.z += ball.vz * dt

		if ball.y < BALL_R then
			ball.y = BALL_R
			if ball.vy < 0 then
				ball.vy = -ball.vy * 0.62
				if ball.vy < 4 then
					ball.vy = 0
				elseif ball.vy > 12 then
					playSound("hit", math.min(0.4, ball.vy / 120), 0.6)
				end
			end
			local roll = math.exp(-0.5 * dt)
			ball.vx *= roll
			ball.vz *= roll
		end
		if ball.y > CEILING - BALL_R then
			ball.y = CEILING - BALL_R
			ball.vy = -math.abs(ball.vy) * 0.7
		end
		local xl = FIELD_X - BALL_R
		if math.abs(ball.x) > xl then
			ball.x = math.sign(ball.x) * xl
			ball.vx = -ball.vx * 0.65
		end
		local zl = FIELD_Z - BALL_R
		if math.abs(ball.z) > zl then
			local inMouth = math.abs(ball.x) < GOAL_W and ball.y < GOAL_H
			if math.abs(ball.z) > FIELD_Z or inMouth then
				-- внутри ворот: сетка со всех сторон
				if math.abs(ball.z) > FIELD_Z - 1 then
					local gx = GOAL_W - BALL_R
					if math.abs(ball.x) > gx then
						ball.x = math.sign(ball.x) * gx
						ball.vx = -ball.vx * 0.4
					end
					if ball.y > GOAL_H - BALL_R then
						ball.y = GOAL_H - BALL_R
						ball.vy = -math.abs(ball.vy) * 0.4
					end
				end
				local back = FIELD_Z + GOAL_D - BALL_R
				if math.abs(ball.z) > back then
					ball.z = math.sign(ball.z) * back
					ball.vz = -ball.vz * 0.3
				end
			else
				ball.z = math.sign(ball.z) * zl
				ball.vz = -ball.vz * 0.65
			end
		end
		local speed = math.sqrt(ball.vx ^ 2 + ball.vy ^ 2 + ball.vz ^ 2)
		if speed > BALL_MAX_SPEED then
			local k = BALL_MAX_SPEED / speed
			ball.vx *= k
			ball.vy *= k
			ball.vz *= k
		end
	end

	-- Удар машины по мячу: ближайшая точка корпуса (повёрнутый ящик) к центру мяча
	local function hitBall(car)
		local c, s = math.cos(car.yaw), math.sin(car.yaw)
		local cy = car.y + CAR_HY
		local dx, dy, dz = ball.x - car.x, ball.y - cy, ball.z - car.z
		local lx = dx * c - dz * s
		local lz = dx * s + dz * c
		local ex = lx - math.clamp(lx, -CAR_HX, CAR_HX)
		local ey = dy - math.clamp(dy, -CAR_HY, CAR_HY)
		local ez = lz - math.clamp(lz, -CAR_HZ, CAR_HZ)
		local dist = math.sqrt(ex * ex + ey * ey + ez * ez)
		if dist >= BALL_R then
			return
		end
		local nx, ny, nz
		if dist < 0.01 then
			nx, ny, nz = -s, 0.3, -c
			dist = 0
		else
			nx, ny, nz = (ex * c + ez * s) / dist, ey / dist, (-ex * s + ez * c) / dist
		end
		ball.x += nx * (BALL_R - dist)
		ball.y += ny * (BALL_R - dist)
		ball.z += nz * (BALL_R - dist)
		local vn = (ball.vx - car.vx) * nx + (ball.vy - car.vy) * ny + (ball.vz - car.vz) * nz
		if vn < 0 then
			ball.vx -= 1.25 * vn * nx
			ball.vy -= 1.25 * vn * ny
			ball.vz -= 1.25 * vn * nz
		end
		if car.hitCooldown <= 0 then
			-- аркадный пинок: чем быстрее машина, тем сильнее удар, сальто бьёт ещё сильнее
			local carSpeed = math.sqrt(car.vx ^ 2 + car.vy ^ 2 + car.vz ^ 2)
			local power = 6 + carSpeed * 0.25
			if car.flip > 0 then
				power *= 1.7
			end
			ball.vx += nx * power
			ball.vy += (ny + 0.15) * power
			ball.vz += nz * power
			car.vx *= 0.85
			car.vz *= 0.85
			car.hitCooldown = 0.15
			lastTouch, touchInAir = car, not car.onGround
			playSound("hit", math.clamp(power / 60, 0.25, 0.9), 1.1 + math.random() * 0.2)
			if car == player then
				ctx.input:Rumble(math.clamp(power / 50, 0.3, 1), 0.12)
			end
		end
	end

	local function carsBump()
		local dx, dy, dz = bot.x - player.x, bot.y - player.y, bot.z - player.z
		local d = math.sqrt(dx * dx + dy * dy + dz * dz)
		local min = 6.5
		if d >= min or d < 0.01 then
			return
		end
		local nx, ny, nz = dx / d, dy / d, dz / d
		local push = (min - d) / 2
		player.x -= nx * push
		player.z -= nz * push
		bot.x += nx * push
		bot.z += nz * push
		local vn = (bot.vx - player.vx) * nx + (bot.vy - player.vy) * ny + (bot.vz - player.vz) * nz
		if vn < 0 then
			local j = -vn * 0.7
			player.vx -= nx * j
			player.vz -= nz * j
			bot.vx += nx * j
			bot.vz += nz * j
			playSound("hit", 0.4, 0.5)
			ctx.input:Rumble(0.6, 0.15)
		end
	end

	local function updatePads(dt)
		for _, pad in pads do
			if pad.timer > 0 then
				pad.timer -= dt
				if pad.timer <= 0 then
					pad.part.Transparency = 0
					if pad.orb then
						pad.orb.Transparency = 0
					end
				end
			else
				for _, car in cars do
					local r = pad.big and 4 or 3
					if car.y < 4 and (car.x - pad.x) ^ 2 + (car.z - pad.z) ^ 2 < r * r and car.boost < 100 then
						car.boost = pad.big and 100 or math.min(100, car.boost + 12)
						pad.timer = pad.big and 10 or 4
						pad.part.Transparency = 0.85
						if pad.orb then
							pad.orb.Transparency = 1
						end
						if car == player then
							playSound("move", 0.35, pad.big and 1.4 or 2)
						end
						break
					end
				end
			end
		end
	end

	---------------------------------------------------------------- бот
	local function botControl(dt)
		local level = DIFFICULTIES[difficulty]
		local own = FIELD_Z -- оранжевые защищают +z
		local attack = -FIELD_Z
		ai.think -= dt
		if ai.think <= 0 then
			ai.think = level.react
			local dist = math.sqrt((ball.x - bot.x) ^ 2 + (ball.z - bot.z) ^ 2)
			local t = math.clamp(dist / 60, 0, 1.2) * level.predict
			local bx = math.clamp(ball.x + ball.vx * t, -FIELD_X + 4, FIELD_X - 4)
			local bz = math.clamp(ball.z + ball.vz * t, -FIELD_Z - 6, FIELD_Z + 6)
			if bz > bot.z + 3 then
				-- мяч между ботом и его воротами: объезжаем сбоку и встаём за мяч
				local side = bot.x >= bx and 1 or -1
				ai.tx, ai.tz = math.clamp(bx + side * 16, -FIELD_X + 6, FIELD_X - 6), math.min(bz + 12, own - 6)
			else
				-- заходим за мяч по линии «ворота соперника — мяч»
				local gx, gz = bx - (math.random() - 0.5) * level.aim, bz - attack
				local len = math.sqrt(gx * gx + gz * gz)
				if len < 0.01 then
					len = 1
				end
				-- издалека выходим на линию удара, вблизи целимся сквозь мяч
				local offset = dist > 20 and 7 or -4
				ai.tx, ai.tz = bx + gx / len * offset, bz + gz / len * offset
			end
		end
		local dx, dz = ai.tx - bot.x, ai.tz - bot.z
		-- упёрся (в стену или в соперника): сдаём назад с вывернутыми колёсами
		local moving = math.sqrt(bot.vx * bot.vx + bot.vz * bot.vz)
		if bot.onGround and moving < 4 then
			ai.stuck += dt
		else
			ai.stuck = 0
		end
		if ai.stuck > 0.7 then
			ai.reverse = 0.8
			ai.stuck = 0
		end
		if ai.reverse > 0 then
			ai.reverse -= dt
			local want = math.atan2(-dx, -dz)
			return { throttle = -1, steer = wrapAngle(want - bot.yaw) > 0 and 1 or -1, boost = false, jump = false }
		end
		local want = math.atan2(-dx, -dz)
		local diff = wrapAngle(want - bot.yaw)
		local dist = math.sqrt(dx * dx + dz * dz)
		local ballDist = math.sqrt((ball.x - bot.x) ^ 2 + (ball.y - bot.y) ^ 2 + (ball.z - bot.z) ^ 2)
		-- на крутом повороте сбрасываем газ: на малой скорости радиус разворота меньше
		local throttle = level.throttle
		if dist < 35 then
			throttle *= math.clamp(1 - math.abs(diff) / 1.5, 0.25, 1)
		elseif math.abs(diff) > 2 then
			throttle *= 0.45
		end
		local jump = false
		if bot.onGround and ballDist < 13 and ball.y > 6 and ball.y < 18 and math.abs(diff) < 0.6 then
			jump = math.random() < level.jump
		elseif not bot.onGround and bot.jumps == 1 and ballDist < 8 and bot.airTime > 0.15 then
			jump = math.random() < level.jump
		end
		return {
			throttle = throttle,
			steer = math.clamp(-diff * 3, -1, 1),
			boost = math.abs(diff) < 0.3 and (dist > 25 or ballDist > 15) and bot.boost > 10 and math.random() < level.boost,
			jump = jump,
		}
	end

	local function playerControl()
		local axes = ctx.input:GetAxes()
		local forward = math.max(axes.r2, axes.ly, ctx.input:IsDown("r2") and 1 or 0)
		local back = math.max(axes.l2, -axes.ly, ctx.input:IsDown("l2") and 1 or 0)
		local jump = jumpQueued
		jumpQueued = false
		return {
			throttle = forward - back,
			steer = axes.lx,
			boost = ctx.input:IsDown("square"),
			jump = jump,
		}
	end

	local IDLE = { throttle = 0, steer = 0, boost = false, jump = false }

	---------------------------------------------------------------- голы
	local function scoreGoal(team)
		score[team] += 1
		state, stateTimer = "goal", 3
		local scoredByPlayer = team == "blue" and lastTouch == player
		bigText.Text = "GOAL!"
		bigText.TextColor3 = team == "blue" and BLUE or ORANGE
		if team == "blue" then
			subText.Text = lastTouch == bot and "Own goal by the bot!" or `{ctx.user.name} scores!`
		else
			subText.Text = lastTouch == player and "Own goal..." or "The bot scores"
		end
		goalBurst(team == "blue" and FIELD_Z + GOAL_D / 2 or -FIELD_Z - GOAL_D / 2, team == "blue" and BLUE or ORANGE)
		playSound("explosion", 0.9, 0.8)
		playSound("notify", 0.5)
		ctx.input:Rumble(1, 0.5)
		if scoredByPlayer then
			playerGoals += 1
			ctx.trophies:Unlock("first_goal")
			if playerGoals >= 3 then
				ctx.trophies:Unlock("hat_trick")
			end
			if touchInAir then
				ctx.trophies:Unlock("sky_high")
			end
		end
	end

	---------------------------------------------------------------- отрисовка
	local function drawCar(car, t)
		local pitch, roll = 0, 0
		if car.flip > 0 then
			pitch = -(1 - car.flip / 0.5) * math.pi * 2
		elseif not car.onGround then
			pitch = math.clamp(car.vy / 80, -0.3, 0.3)
		end
		local base = at(car.x, car.y, car.z) * CFrame.Angles(0, car.yaw, 0) * CFrame.new(0, 1.4, 0) * CFrame.Angles(pitch, 0, roll) * CFrame.new(0, -1.4, 0)
		for _, p in car.parts do
			p.part.CFrame = base * p.offset
		end
		car.flame.Transparency = car.boosting and (0.1 + math.sin(t * 40) * 0.1) or 1
		car.flameLight.Enabled = car.boosting
	end

	local camPos = nil
	local function updateCamera(dt)
		local fx, fz = -math.sin(player.yaw), -math.cos(player.yaw)
		local hx, hz = fx, fz
		local lookX, lookY, lookZ = player.x + fx * 20, player.y + 3, player.z + fz * 20
		if ballCam then
			local bx, bz = ball.x - player.x, ball.z - player.z
			local len = math.sqrt(bx * bx + bz * bz)
			if len > 4 then
				hx, hz = bx / len, bz / len
			end
			lookX, lookY, lookZ = (player.x + ball.x) / 2, (player.y + 3 + ball.y) / 2, (player.z + ball.z) / 2
		end
		local tx, ty, tz = player.x - hx * 24, player.y + 9, player.z - hz * 24
		if state == "menu" then
			-- титульный экран: камера медленно кружит над полем
			local a = os.clock() * 0.15
			tx, ty, tz = math.sin(a) * 90, 45, math.cos(a) * 110
			lookX, lookY, lookZ = 0, 4, 0
		end
		if not camPos then
			camPos = { tx, ty, tz }
		end
		local k = 1 - math.exp(-7 * dt)
		camPos[1] += (tx - camPos[1]) * k
		camPos[2] += (ty - camPos[2]) * k
		camPos[3] += (tz - camPos[3]) * k
		ctx.camera.CameraType = Enum.CameraType.Scriptable
		ctx.camera.CFrame = CFrame.lookAt(vec(camPos[1], camPos[2], camPos[3]), vec(lookX, lookY, lookZ))
		local targetFov = player.boosting and 86 or 76
		ctx.camera.FieldOfView += (targetFov - ctx.camera.FieldOfView) * k
	end

	local function render(dt, t)
		local speed = math.sqrt(ball.vx ^ 2 + ball.vz ^ 2)
		if speed > 0.5 then
			-- мяч катится: крутим вокруг оси, перпендикулярной движению
			ball.spin = CFrame.Angles(ball.vz / BALL_R * dt, 0, -ball.vx / BALL_R * dt) * ball.spin
		end
		local cf = at(ball.x, ball.y, ball.z) * ball.spin
		ballPart.CFrame = cf
		ballRing.CFrame = cf
		local touchColor = lastTouch and lastTouch.color or Color3.fromRGB(0, 220, 255)
		ballRing.Color = touchColor
		ballLight.Color = touchColor
		local shadowSize = math.max(2, BALL_R * 2 - ball.y * 0.15)
		shadow.Size = Vector3.new(0.1, shadowSize, shadowSize)
		shadow.CFrame = at(ball.x, 0.06, ball.z) * CFrame.Angles(0, 0, math.pi / 2)
		shadow.Transparency = math.clamp(0.4 + ball.y / 60, 0.4, 0.9)
		for _, car in cars do
			drawCar(car, t)
		end
		for _, pad in pads do
			if pad.orb and pad.timer <= 0 then
				pad.orb.CFrame = at(pad.x, 2.5 + math.sin(t * 3 + pad.x) * 0.4, pad.z)
			end
		end

		blueScore.Text = tostring(score.blue)
		orangeScore.Text = tostring(score.orange)
		clock.Text = overtime and "+" .. formatTime(overtimeTime) or formatTime(timeLeft)
		clockSub.Text = overtime and "OVERTIME" or DIFFICULTIES[difficulty].name .. " bot"
		boostText.Text = tostring(math.floor(player.boost))
		boostBar.Size = UDim2.fromScale(player.boost / 100, 1)
		camLabel.Text = `{ctx.input:Glyph("triangle")}  {ballCam and "Ball cam" or "Car cam"}`
		local inMatch = state ~= "menu"
		board.Visible = inMatch
		boostFrame.Visible = inMatch
		camLabel.Visible = inMatch and state ~= "over"
	end

	---------------------------------------------------------------- ввод
	ctx.input:On("press", function(btn)
		if overlay.Visible then
			local item = menuItems[menuIndex]
			if btn == "up" or btn == "down" then
				menuIndex = (menuIndex - 1 + (btn == "down" and 1 or -1)) % #menuItems + 1
				playSound("move", 0.3, 1.6)
				renderMenu()
			elseif (btn == "left" or btn == "right") and item and item.cycle then
				item.cycle(btn == "right" and 1 or -1)
				playSound("move", 0.3, 1.3)
				renderMenu()
			elseif btn == "cross" and item then
				if item.cycle then
					item.cycle(1)
					renderMenu()
				else
					item.action()
				end
				playSound("confirm", 0.4)
			elseif btn == "circle" or btn == "options" then
				if state == "paused" then
					closeMenu()
					state = pausedFrom
				elseif state == "menu" and btn == "circle" then
					ctx:Exit()
				end
			end
			return
		end
		if btn == "options" then
			pauseGame()
		elseif btn == "triangle" then
			ballCam = not ballCam
			save:Set("ballCam", ballCam)
			playSound("move", 0.3, 1.2)
		elseif btn == "cross" and (state == "play" or state == "goal") then
			jumpQueued = true
		end
	end)

	-- Пауза системы (кнопка PS): ctx:Loop остановится сам, а в игре открываем меню паузы
	ctx:On("pause", pauseGame)

	---------------------------------------------------------------- цикл
	local elapsed = 0
	showMainMenu()

	ctx:Loop(function(dt)
		elapsed += dt
		if state == "kickoff" then
			local before = math.ceil(stateTimer)
			stateTimer -= dt
			local now = math.ceil(stateTimer)
			if stateTimer <= 0 then
				state = "play"
				bigText.Text, subText.Text = "GO!", ""
				bigText.TextColor3 = Color3.new(1, 1, 1)
				playSound("confirm", 0.7, 1.2)
				task.delay(0.8, function()
					if bigText.Parent and bigText.Text == "GO!" then
						bigText.Text = ""
					end
				end)
			else
				bigText.Text = tostring(now)
				bigText.TextColor3 = Color3.new(1, 1, 1)
				subText.Text = overtime and "OVERTIME · next goal wins" or ""
				if now ~= before then
					playSound("move", 0.6, 1)
				end
			end
		elseif state == "play" or state == "goal" then
			local playing = state == "play"
			updateCar(player, playerControl(), dt)
			updateCar(bot, playing and botControl(dt) or IDLE, dt)
			carsBump()
			updateBall(dt)
			if playing then
				hitBall(player)
				hitBall(bot)
				updatePads(dt)
				if math.abs(ball.z) > FIELD_Z + BALL_R then
					scoreGoal(ball.z > 0 and "blue" or "orange")
				elseif overtime then
					overtimeTime += dt
				else
					timeLeft -= dt
					if timeLeft <= 0 then
						timeLeft = 0
						if score.blue == score.orange then
							overtime = true
							resetKickoff()
						else
							endMatch()
						end
					end
				end
			else
				stateTimer -= dt
				if stateTimer <= 0 then
					bigText.Text, subText.Text = "", ""
					if overtime or (timeLeft <= 0 and score.blue ~= score.orange) then
						endMatch()
					else
						resetKickoff()
					end
				end
			end
		end
		updateEffects(dt)
		updateCamera(dt)
		render(dt, elapsed)
	end)
end

return Game
