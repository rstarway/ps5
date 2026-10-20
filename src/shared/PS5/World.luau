-- 3D-сцена для заставки: консоль на подиуме в тёмной студии под одним прожектором.
-- Если в ReplicatedStorage.PS5Assets лежит модель "Console" (импорт FBX из Blender),
-- используется она, иначе консоль собирается из деталей.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Embedded = require(script.Parent.Embedded)

local World = {}

local scene = nil
-- Студия заставки висит высоко над чиллзоной, чтобы не пересекаться с домом
local ORIGIN = Vector3.new(0, 600, 0)
local consoleCenter = Vector3.new(0, 6, 0)

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		p[k] = v
	end
	p.Parent = scene
	return p
end

local function buildConsole()
	local white = Color3.fromRGB(238, 240, 245)
	local black = Color3.fromRGB(16, 16, 20)
	local blue = Color3.fromRGB(0, 120, 255)
	part({ Name = "Core", Size = Vector3.new(2.2, 9.4, 7.4), Color = black, Position = Vector3.new(0, 5.9, 0), Reflectance = 0.15 })
	for _, side in { -1, 1 } do
		part({
			Name = "Fin",
			Size = Vector3.new(0.35, 10.4, 8.2),
			Color = white,
			Reflectance = 0.05,
			CFrame = CFrame.new(side * 1.45, 6.1, 0) * CFrame.Angles(0, 0, math.rad(-side * 3)),
		})
		part({
			Name = "LightStrip",
			Size = Vector3.new(0.08, 9.6, 7.2),
			Color = blue,
			CFrame = CFrame.new(side * 1.18, 5.9, 0) * CFrame.Angles(0, 0, math.rad(-side * 3)),
		})
	end
	part({ Name = "Disc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 5, 5), Color = black, CFrame = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)) })
	local glow = Instance.new("PointLight")
	glow.Color = blue
	glow.Brightness = 3
	glow.Range = 14
	glow.Parent = part({ Name = "Glow", Size = Vector3.one * 0.2, Transparency = 1, Position = Vector3.new(0, 6, 0) })
end

function World.Build()
	if scene then
		return scene
	end
	scene = Instance.new("Model")
	scene.Name = "PS5Showroom"
	scene.Parent = Workspace

	part({ Name = "Floor", Size = Vector3.new(200, 1, 200), Position = Vector3.new(0, 0, 0), Color = Color3.fromRGB(8, 10, 18), Reflectance = 0.35, Material = Enum.Material.Glass })
	part({ Name = "Wall", Size = Vector3.new(200, 80, 1), Position = Vector3.new(0, 40, -30), Color = Color3.fromRGB(6, 8, 16) })
	local spot = part({ Name = "Spot", Size = Vector3.one, Transparency = 1, Position = Vector3.new(0, 30, 10) })
	local light = Instance.new("SpotLight")
	light.Angle = 40
	light.Brightness = 6
	light.Range = 60
	light.Face = Enum.NormalId.Bottom
	light.Parent = spot
	-- студийный свет как на продуктовой съёмке: мягкий фронтальный и два контровых,
	-- иначе белые боковины консоли без неона уходят в чёрное
	for _, info in {
		{ Vector3.new(0, 9, 24), 2.2, Color3.fromRGB(255, 246, 236) },
		{ Vector3.new(-18, 14, -6), 1.6, Color3.fromRGB(205, 220, 255) },
		{ Vector3.new(18, 14, -6), 1.6, Color3.fromRGB(205, 220, 255) },
	} do
		local holder = part({ Name = "StudioLight", Size = Vector3.one, Transparency = 1, Position = info[1] })
		local fill = Instance.new("PointLight")
		fill.Range = 34
		fill.Brightness = info[2]
		fill.Color = info[3]
		fill.Shadows = false
		fill.Parent = holder
	end

	local function paint(model)
		-- Части из Blender названы по цвету: *_White, *_Black, *Light_Blue*
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				if string.find(p.Name, "Light") then
					p.Color = Color3.fromRGB(70, 130, 220)
					p.Material = Enum.Material.SmoothPlastic
				elseif string.find(p.Name, "White") then
					p.Color = Color3.fromRGB(238, 240, 245)
					p.Material = Enum.Material.SmoothPlastic
				elseif string.find(p.Name, "Black") then
					p.Color = Color3.fromRGB(16, 16, 20)
					p.Material = Enum.Material.SmoothPlastic
					p.Reflectance = 0.1
				end
			end
		end
	end

	local assets = ReplicatedStorage:FindFirstChild("PS5Assets")
	local model = assets and assets:FindFirstChild("Console")
	if model then
		local clone = model:Clone()
		paint(clone)
		clone.Parent = scene
		if clone:IsA("Model") then
			local _, size = clone:GetBoundingBox()
			clone:PivotTo(CFrame.new(0, size.Y / 2 + 0.5, 0))
			consoleCenter = Vector3.new(0, size.Y / 2 + 0.5, 0)
		end
	else
		-- модель из Blender, встроенная в код; если не вышло — консоль из деталей
		local assetsFolder = script.Parent:FindFirstChild("Assets")
		local console = Embedded.Model(assetsFolder and assetsFolder:FindFirstChild("ConsoleMesh"), "Console")
		if console then
			console:PivotTo(CFrame.new(0, 0.5, 0))
			console.Parent = scene
			consoleCenter = Vector3.new(0, 6, 0)
		else
			buildConsole()
		end
		local controller = Embedded.Model(assetsFolder and assetsFolder:FindFirstChild("ControllerMesh"), "Controller")
		if controller then
			controller.Parent = scene
			controller:PivotTo(CFrame.new(5.5, 0.9, 5) * CFrame.Angles(0, math.rad(-25), 0))
			pcall(function()
				controller:ScaleTo(0.75)
			end)
		end
	end

	scene.WorldPivot = CFrame.new()
	scene:PivotTo(CFrame.new(ORIGIN))
	consoleCenter += ORIGIN
	return scene
end

-- Пролёт камеры вокруг консоли для заставки.
function World.PlayBoot(duration)
	World.Build()
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 40
	local value = Instance.new("NumberValue")
	value.Value = 0
	local conn = value.Changed:Connect(function(t)
		local angle = math.rad(-60 + t * 80)
		local radius = 26 - t * 8
		local pos = consoleCenter + Vector3.new(math.sin(angle) * radius, 2 + t * 2, math.cos(angle) * radius)
		camera.CFrame = CFrame.lookAt(pos, consoleCenter)
	end)
	local tween = TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = 1 })
	tween:Play()
	tween.Completed:Once(function()
		conn:Disconnect()
		value:Destroy()
	end)
	return tween
end

return World
