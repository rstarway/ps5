-- Живой мир чиллзоны на клиенте (сам дом из Blender строит сервер): светлячки, искры и дым костра, дым из трубы, переливы неона,
-- мерцание гирлянд и пролёт камеры при входе.
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

local function chimney(zone, folder)
	local marker = zone:FindFirstChild("ChimneyTop")
	local top = anchor("ChimneySmoke", marker and marker.Position or Vector3.new(22, 29, -8), folder)
	emitter(top, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(120, 116, 130)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 7) }),
		Lifetime = NumberRange.new(5, 7),
		Rate = 2,
		Speed = NumberRange.new(2, 3),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-15, 15),
		Acceleration = Vector3.new(2, 0.3, 0),
	})
end

-- Светлячки над двором и прудом
local function fireflies(zone, folder)
	local origin = zone:GetAttribute("Origin") or Vector3.zero
	local pondMarker = zone:FindFirstChild("Pond")
	local pondAt = pondMarker and pondMarker.Position * Vector3.new(1, 0, 1) + Vector3.new(0, 3, 0) or origin + Vector3.new(42, 3, 52)
	local list = {}
	local rng = Random.new(11)
	for i = 1, 40 do
		local nearPond = i % 3 == 0
		local center = nearPond and pondAt or origin + Vector3.new(rng:NextNumber(-50, 50), 3, rng:NextNumber(30, 100))
		local fly = Instance.new("Part")
		fly.Name = "Firefly"
		fly.Shape = Enum.PartType.Ball
		fly.Size = Vector3.one * 0.28
		fly.Material = Enum.Material.Neon
		fly.Color = Color3.fromRGB(210, 255, 120)
		fly.Anchored = true
		fly.CanCollide = false
		fly.CanQuery = false
		fly.CanTouch = false
		fly.CastShadow = false
		fly.Parent = folder
		if i % 8 == 0 then
			local l = Instance.new("PointLight")
			l.Color = fly.Color
			l.Range = 6
			l.Brightness = 0.8
			l.Parent = fly
		end
		table.insert(list, {
			part = fly,
			center = center,
			radius = rng:NextNumber(3, nearPond and 12 or 9),
			speed = rng:NextNumber(0.15, 0.4),
			phase = rng:NextNumber(0, math.pi * 2),
			blink = rng:NextNumber(0.6, 1.6),
		})
	end
	return list
end

local function shift(color, t, amount)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV((h + math.sin(t) * amount) % 1, s, v)
end

-- Эффекты уровней чиллзоны: брызги фонтана, пар над джакузи, фейерверки, вращение небесного трофея.
-- Детали уровня появляются позже (при повышении), поэтому их ловит DescendantAdded.
local function upgradeFX(zone, folder)
	local state = { trophy = {}, fireworks = {}, nextFirework = 0 }
	local function hook(d)
		if not d:IsA("BasePart") then
			return
		end
		if d.Name == "FountainSpout" then
			emitter(d, {
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
				Color = ColorSequence.new(Color3.fromRGB(170, 225, 255)),
				LightEmission = 0.6,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.1) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(0.9, 1.3),
				Rate = 60,
				Speed = NumberRange.new(5, 7),
				SpreadAngle = Vector2.new(18, 18),
				Acceleration = Vector3.new(0, -14, 0),
				EmissionDirection = Enum.NormalId.Top,
			})
		elseif d.Name == "HotTub" then
			emitter(d, {
				Texture = "rbxasset://textures/particles/smoke_main.dds",
				Color = ColorSequence.new(Color3.fromRGB(230, 240, 255)),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(2, 3.5),
				Rate = 6,
				Speed = NumberRange.new(1, 2),
				EmissionDirection = Enum.NormalId.Top,
			})
		elseif d.Name == "SkyTrophy" or d.Name == "SkyTrophyCore" then
			table.insert(state.trophy, { part = d, base = d.CFrame })
		elseif d.Name == "Fireworks" then
			table.insert(state.fireworks, d)
		end
	end
	for _, d in zone:GetDescendants() do
		hook(d)
	end
	zone.DescendantAdded:Connect(hook)
	local colors = { Color3.fromRGB(255, 90, 140), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 214, 90), Color3.fromRGB(150, 255, 160) }
	local function launch(spot)
		if not spot:IsDescendantOf(zone) then
			return
		end
		local top = anchor("Firework", spot.Position + Vector3.new(math.random(-6, 6), math.random(45, 65), math.random(-6, 6)), folder)
		local burst = emitter(top, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(colors[math.random(#colors)]),
			LightEmission = 1,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(1.2, 1.8),
			Rate = 0,
			Speed = NumberRange.new(16, 22),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -9, 0),
			Drag = 1.5,
		})
		local flash = Instance.new("PointLight")
		flash.Color = burst.Color.Keypoints[1].Value
		flash.Range = 40
		flash.Brightness = 3
		flash.Parent = top
		burst:Emit(90)
		Util.tween(flash, 1.2, { Brightness = 0 })
		task.delay(2.5, function()
			top:Destroy()
		end)
	end
	return function(t)
		for _, item in state.trophy do
			if item.part.Parent then
				local core = state.trophy[1].base.Position
				local pivot = CFrame.new(core.X, core.Y, core.Z) * CFrame.new(0, math.sin(t * 0.8) * 0.8, 0) * CFrame.Angles(0, t * 0.4, 0)
				item.part.CFrame = pivot * (CFrame.new(core.X, core.Y, core.Z):Inverse() * item.base)
			end
		end
		if #state.fireworks > 0 and t >= state.nextFirework then
			state.nextFirework = t + math.random(25, 45) / 10
			launch(state.fireworks[math.random(#state.fireworks)])
		end
	end
end

-- Запуск всех эффектов мира. Возвращает функцию остановки.
function WorldFX.Start(zone)
	local folder = Instance.new("Folder")
	folder.Name = "WorldFX"
	folder.Parent = zone
	local fireLight = campfire(zone, folder)
	chimney(zone, folder)
	local flies = fireflies(zone, folder)
	local upgrades = upgradeFX(zone, folder)
	local bulbs = {}
	for _, d in zone:GetChildren() do
		if d.Name == "Bulb" and d:IsA("BasePart") then
			table.insert(bulbs, { part = d, phase = math.random() * 6 })
		end
	end
	local neon = {}
	local flicker = {}
	for _, d in zone:GetDescendants() do
		if d:IsA("Light") and d:GetAttribute("Flicker") then
			table.insert(flicker, { light = d, base = d.Brightness, seed = math.random() * 10 })
		end
	end
	local scenery = zone:FindFirstChild("Scenery")
	if scenery then
		for _, p in scenery:GetChildren() do
			if p:IsA("BasePart") and (p.Name == "NeonPurple" or p.Name == "NeonBlue") then
				table.insert(neon, { part = p, base = p.Color })
			end
		end
	end
	local t = 0
	local connection = RunService.Heartbeat:Connect(function(dt)
		t += dt
		for _, f in flies do
			local a = t * f.speed + f.phase
			local pos = f.center + Vector3.new(math.cos(a) * f.radius, math.sin(a * 2.3) * 1.5 + math.sin(a * 0.7) * 1.2, math.sin(a * 1.3) * f.radius)
			f.part.Position = pos
			f.part.Transparency = 0.15 + 0.85 * math.max(0, math.sin(t * f.blink + f.phase)) ^ 4
		end
		for _, b in bulbs do
			b.part.Transparency = 0.25 * (0.5 + 0.5 * math.sin(t * 2 + b.phase))
		end
		for _, n in neon do
			n.part.Color = shift(n.base, t * 0.25, 0.06)
		end
		for _, f in flicker do
			f.light.Brightness = f.base * (0.8 + 0.35 * math.noise(t * 4, f.seed))
		end
		upgrades(t)
		if fireLight then
			fireLight.Brightness = 2.6 + math.noise(t * 3, 0.5) * 1.6
			fireLight.Range = 32 + math.noise(t * 2, 3.1) * 4
		end
	end)
	return function()
		connection:Disconnect()
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
	local shots = {
		{ CFrame.lookAt(origin + Vector3.new(80, 70, 160), origin + Vector3.new(0, 6, 34)), 0 },
		{ CFrame.lookAt(origin + Vector3.new(26, 24, 104), origin + Vector3.new(0, 6, 30)), 3.2 },
		{ CFrame.lookAt(origin + Vector3.new(0, 9, 86), origin + Vector3.new(0, 6, 20)), 2.6 },
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
