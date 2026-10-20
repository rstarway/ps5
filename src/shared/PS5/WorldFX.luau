-- Живой мир чиллзоны на клиенте (дом, двор и модели строит сервер): искры и дым очага, мерцание свечей,
-- пар над джакузи и пролёт камеры при входе. Никакого неона и цветного свечения.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local WorldFX = {}

local player = Players.LocalPlayer

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		e[k] = v
	end
	e.Parent = parent
	return e
end

local function anchor(name, position, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = position
	p.Parent = parent
	return p
end

-- Костёр: искры, дым, живой свет
local function campfire(zone, folder)
	local core = zone:FindFirstChild("FireCore")
	if not core then
		return
	end
	emitter(core, {
		Name = "Sparks",
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 120), Color3.fromRGB(255, 90, 30)),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(1.2, 2.4),
		Rate = 14,
		Speed = NumberRange.new(4, 9),
		SpreadAngle = Vector2.new(18, 18),
		Acceleration = Vector3.new(0, 2, 0),
		Drag = 1.2,
	})
	emitter(core, {
		Name = "Smoke",
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(70, 66, 80)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.75), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 8) }),
		Lifetime = NumberRange.new(4, 6),
		Rate = 3,
		Speed = NumberRange.new(3, 5),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
		Acceleration = Vector3.new(1.5, 0.5, 0),
	})
	local light = core:FindFirstChildOfClass("PointLight")
	return light
end

-- Пар над джакузи (уровень 4): деталь появляется позже, при повышении, поэтому её ловит DescendantAdded
local function upgradeFX(zone)
	local function hook(d)
		if d:IsA("BasePart") and d.Name == "HotTub" and not d:FindFirstChild("Steam") then
			emitter(d, {
				Name = "Steam",
				Texture = "rbxasset://textures/particles/smoke_main.dds",
				Color = ColorSequence.new(Color3.fromRGB(230, 236, 240)),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(2, 3.5),
				Rate = 5,
				Speed = NumberRange.new(1, 2),
				EmissionDirection = Enum.NormalId.Top,
			})
		end
	end
	for _, d in zone:GetDescendants() do
		hook(d)
	end
	return zone.DescendantAdded:Connect(hook)
end

-- Запуск всех эффектов мира. Возвращает функцию остановки.
function WorldFX.Start(zone)
	local folder = Instance.new("Folder")
	folder.Name = "WorldFX"
	folder.Parent = zone
	local fireLight = campfire(zone, folder)
	local upgrades = upgradeFX(zone)
	local flicker = {}
	for _, d in zone:GetDescendants() do
		if d:IsA("Light") and d:GetAttribute("Flicker") then
			table.insert(flicker, { light = d, base = d.Brightness, seed = math.random() * 10 })
		end
	end
	local t = 0
	local connection = RunService.Heartbeat:Connect(function(dt)
		t += dt
		for _, f in flicker do
			f.light.Brightness = f.base * (0.8 + 0.35 * math.noise(t * 4, f.seed))
		end
		if fireLight then
			fireLight.Brightness = 2.6 + math.noise(t * 3, 0.5) * 1.6
			fireLight.Range = 32 + math.noise(t * 2, 3.1) * 4
		end
	end)
	return function()
		connection:Disconnect()
		upgrades:Disconnect()
		folder:Destroy()
	end
end

-- Пролёт камеры при появлении: с неба над двором к дому и за спину игрока.
-- Любая кнопка пропускает. done() вызывается в конце.
function WorldFX.Intro(origin, done)
	origin = origin or Vector3.zero
	local camera = Workspace.CurrentCamera
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChillIntro"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")
	local root = Util.canvas(gui)
	local title = Util.text("CHILL ZONE", {
		Size = UDim2.fromOffset(1920, 160),
		Position = UDim2.fromOffset(0, 380),
		TextSize = 140,
		Font = Theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		TextStrokeColor3 = Color3.fromRGB(80, 60, 200),
		Parent = root,
	})
	local spacing = Instance.new("UIScale")
	spacing.Scale = 1.25
	spacing.Parent = title
	local sub = Util.text("Head inside and press E at the PS5", {
		Size = UDim2.fromOffset(1920, 50),
		Position = UDim2.fromOffset(0, 550),
		TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Colors.SubText,
		TextTransparency = 1,
		Parent = root,
	})
	local finished = false
	local skip
	local function finish()
		if finished then
			return
		end
		finished = true
		if skip then
			skip:Disconnect()
		end
		Util.tween(title, 0.6, { TextTransparency = 1, TextStrokeTransparency = 1 })
		Util.tween(sub, 0.6, { TextTransparency = 1 })
		task.delay(0.7, function()
			gui:Destroy()
		end)
		-- персонаж мог смениться за время пролёта: привязываем камеру к текущему
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		camera.CameraType = Enum.CameraType.Custom
		done()
	end
	skip = UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType ~= Enum.UserInputType.MouseMovement then
			finish()
		end
	end)
	camera.CameraType = Enum.CameraType.Scriptable
	-- с высоты над улицей через участок к дому, затем за спину игрока у калитки
	local shots = {
		{ CFrame.lookAt(origin + Vector3.new(70, 60, 190), origin + Vector3.new(0, 6, 40)), 0 },
		{ CFrame.lookAt(origin + Vector3.new(24, 22, 140), origin + Vector3.new(0, 8, 30)), 3.4 },
		{ CFrame.lookAt(origin + Vector3.new(0, 9, 118), origin + Vector3.new(0, 7, 28)), 2.8 },
	}
	camera.CFrame = shots[1][1]
	camera.FieldOfView = 55
	Util.tween(title, 1.2, { TextTransparency = 0, TextStrokeTransparency = 0.3 })
	Util.tween(spacing, 2.6, { Scale = 1 })
	task.delay(0.9, function()
		Util.tween(sub, 1, { TextTransparency = 0 })
	end)
	task.spawn(function()
		for i = 2, #shots do
			if finished then
				return
			end
			local tween = TweenService:Create(camera, TweenInfo.new(shots[i][2], Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = shots[i][1], FieldOfView = 70 })
			tween:Play()
			tween.Completed:Wait()
		end
		finish()
	end)
end

return WorldFX
