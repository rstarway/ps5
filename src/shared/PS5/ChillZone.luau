-- Клиентская часть чиллзоны: консоль у телевизора (подошёл → E → интерфейс PS5),
-- экран телевизора, стенд трофеев, полка игр и табло. У каждого игрока своя чиллзона
-- (Workspace.ChillZones.Zone_<UserId>): своя заполняется из локальных данных, чужие — из публичного
-- профиля хозяина (PS5Remotes.GetPublicProfile), чтобы в гостях была видна его коллекция.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Util = require(script.Parent.Util)
local Theme = require(script.Parent.Theme)
local Data = require(script.Parent.Data)
local Registry = require(script.Parent.Registry)
local Trophies = require(script.Parent.Trophies)
local Embedded = require(script.Parent.Embedded)
local Audio = require(script.Parent.Audio)
local WorldFX = require(script.Parent.WorldFX)
local Progress = require(script.Parent.Progress)
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local ChillZone = {}

local player = Players.LocalPlayer
local zone -- своя чиллзона
local zonesFolder
local displays = {} -- чиллзона -> папка с коллекцией
local decorated = {}
local active = false
local shell

local spinning = {} -- полученные трофеи медленно вращаются и покачиваются
local glows = {}

local function remote(name)
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("PS5Remotes")
	return folder and folder:FindFirstChild(name)
end

-- Публичный профиль игрока (трофеи, награды, игры, уровень чиллзоны)
function ChillZone.FetchProfile(userId)
	local fn = remote("GetPublicProfile")
	if not fn then
		return nil
	end
	local ok, result = pcall(fn.InvokeServer, fn, userId)
	return ok and type(result) == "table" and result or nil
end

-- Свой профиль по локальным данным (без задержки сервера)
function ChillZone.OwnSummary()
	local summary = Progress.Summarize({ settings = Data.Get({ "settings" }), data = Data.Get({ "data" }) }, Registry.All())
	summary.userId = player.UserId
	summary.name = player.Name
	summary.displayName = player.DisplayName
	return summary
end

local function controls()
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)):GetControls()
	end)
	return ok and module or nil
end

local function prompt(parent, action, object, onTrigger, distance)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0.25
	p.MaxActivationDistance = distance or 10
	p.RequiresLineOfSight = false
	p.Parent = parent
	p.Triggered:Connect(onTrigger)
	return p
end

local function surface(partInstance, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = partInstance
	return gui
end

-- Звуки мира: сверчки везде, треск костра, вода у пруда, музыка в гостиной
local function ambience(z, own)
	local where = { night = false, campfire = "FireCore", pond = "Pond", radio = "Rug" }
	for key, info in Theme.Ambience do
		local parent = SoundService
		if where[key] then
			parent = z:FindFirstChild(where[key], true)
		elseif not own then
			parent = nil -- общий фон звучит один раз, от своей чиллзоны
		end
		if parent then
			local sound = Instance.new("Sound")
			sound.Name = "Ambience_" .. key
			sound.SoundId = info.id
			sound.Volume = info.volume
			sound.Looped = true
			sound.SoundGroup = Audio.World
			if info.radius > 0 then
				sound.RollOffMode = Enum.RollOffMode.InverseTapered
				sound.RollOffMinDistance = info.radius * 0.25
				sound.RollOffMaxDistance = info.radius
			end
			sound.Parent = parent
			sound:Play()
		end
	end
end

-- Консоль и геймпад: модель из Blender (встроенная) или простая из деталей
local function placeConsole(z, spot)
	local model = Embedded.Model(script.Parent.Assets:FindFirstChild("ConsoleMesh"), "PS5")
	if model then
		model:ScaleTo(0.32)
	else
		model = Instance.new("Model")
		model.Name = "PS5"
		for i, data in {
			{ Vector3.new(0.7, 3.1, 2.4), Vector3.new(0, 1.55, 0), Color3.fromRGB(16, 16, 20) },
			{ Vector3.new(0.12, 3.4, 2.6), Vector3.new(-0.42, 1.7, 0), Color3.fromRGB(238, 240, 245) },
			{ Vector3.new(0.12, 3.4, 2.6), Vector3.new(0.42, 1.7, 0), Color3.fromRGB(238, 240, 245) },
		} do
			local p = Instance.new("Part")
			p.Name = i == 1 and "Black" or "White"
			p.Anchored = true
			p.Size, p.Position, p.Color = data[1], data[2], data[3]
			p.Parent = model
		end
		model.WorldPivot = CFrame.new()
	end
	model:PivotTo(spot.CFrame)
	model.Parent = z
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(0, 120, 255)
	glow.Range = 6
	glow.Brightness = 1.5
	glow.Parent = spot
	table.insert(glows, glow)
	return model
end

local function placeController(z, spot)
	local model = Embedded.Model(script.Parent.Assets:FindFirstChild("ControllerMesh"), "DualSense")
	if not model then
		return
	end
	model:ScaleTo(0.28)
	model:PivotTo(spot.CFrame * CFrame.Angles(0, math.rad(200), 0))
	model.Parent = z
end

-- Экран телевизора, когда PS5 выключена
local function buildTV(z, own)
	local screen = z:FindFirstChild("TVScreen")
	if not screen then
		return
	end
	local gui = surface(screen, Enum.NormalId.Back)
	gui.Name = "TVGui"
	local bg = Util.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = gui }, {
		Util.gradient({ Color3.fromRGB(6, 14, 48), Color3.fromRGB(18, 60, 140), Color3.fromRGB(4, 8, 24) }, 120),
	})
	local image = Util.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop, ImageTransparency = 0.2, Parent = bg })
	if not Embedded.ApplyImage(image, Theme.Images.HomeBackground ~= "" and Theme.Images.HomeBackground or "HomeBackground", script.Parent.Assets) then
		image:Destroy()
	end
	Util.text("△ ○ ✕ □", { Size = UDim2.fromScale(1, 0.2), Position = UDim2.fromScale(0, 0.25), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.FontBold, Parent = bg })
	Util.text("PS5 SANDBOX", { Size = UDim2.fromScale(1, 0.14), Position = UDim2.fromScale(0, 0.47), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.FontHeavy, Parent = bg })
	Util.text(own and "Walk up to the console and press E" or `{z:GetAttribute("OwnerName") or "Player"}'s PS5`, { Size = UDim2.fromScale(1, 0.07), Position = UDim2.fromScale(0, 0.72), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Theme.Colors.SubText, Parent = bg })
end

-- Трофей на полке: подставка + кубок цвета ранга; закрытые — тёмные и полупрозрачные
local function trophyModel(spot, trophy, manifest)
	local model = Instance.new("Model")
	model.Name = trophy.id
	local color = Theme.TrophyColors[trophy.grade] or Theme.Colors.Bronze
	local unlocked = trophy.unlocked
	local function piece(shape, size, offset, pieceColor, material)
		local p = Instance.new("Part")
		p.Shape = shape
		p.Anchored = true
		p.CanCollide = false
		p.Size = size
		p.CFrame = spot.CFrame * offset
		p.Color = unlocked and pieceColor or Color3.fromRGB(40, 42, 50)
		p.Material = unlocked and material or Enum.Material.Glass
		p.Transparency = unlocked and 0 or 0.55
		p.Reflectance = unlocked and 0.25 or 0
		p.Parent = model
		return p
	end
	local up = CFrame.Angles(0, 0, math.rad(90))
	piece(Enum.PartType.Block, Vector3.new(1.2, 0.35, 1.2), CFrame.new(0, 0.2, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Marble)
	piece(Enum.PartType.Cylinder, Vector3.new(0.9, 0.3, 0.3), CFrame.new(0, 0.8, 0) * up, color, Enum.Material.Metal)
	piece(Enum.PartType.Cylinder, Vector3.new(1, 1, 1), CFrame.new(0, 1.65, 0) * up, color, trophy.grade == "platinum" and Enum.Material.Neon or Enum.Material.Metal)
	if unlocked and (trophy.grade == "gold" or trophy.grade == "platinum") then
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = 5
		l.Brightness = 1.2
		l.Parent = model.PrimaryPart or model:GetChildren()[3]
	end
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(220, 46)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
	tag.MaxDistance = 9
	tag.AlwaysOnTop = true
	tag.Adornee = model:GetChildren()[3]
	tag.Parent = model
	if unlocked then
		table.insert(spinning, { model = model, base = model:GetPivot(), phase = #spinning * 0.7 })
		if trophy.grade == "platinum" or trophy.grade == "gold" then
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			sparkle.Color = ColorSequence.new(color)
			sparkle.LightEmission = 1
			sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
			sparkle.Lifetime = NumberRange.new(0.8, 1.4)
			sparkle.Rate = 4
			sparkle.Speed = NumberRange.new(0.4, 1)
			sparkle.SpreadAngle = Vector2.new(180, 180)
			sparkle.Parent = model:GetChildren()[3]
		end
	end
	local hidden = trophy.hidden and not unlocked
	Util.text((hidden and "Hidden trophy" or trophy.name) .. "\n" .. manifest.title, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 15,
		Font = Theme.FontBold,
		TextColor3 = unlocked and color or Theme.Colors.Muted,
		TextStrokeTransparency = 0.4,
		Parent = tag,
	})
	return model
end

-- Коробка игры на полке; E — сразу включить PS5 и запустить игру
local function gameCase(spot, manifest, display, own)
	local box = Instance.new("Part")
	box.Name = manifest.id
	box.Anchored = true
	box.Size = Vector3.new(1.7, 2.4, 0.35)
	box.CFrame = spot.CFrame * CFrame.new(0, 1.2, 0.3)
	box.Color = Color3.fromRGB(0, 70, 170)
	box.Material = Enum.Material.SmoothPlastic
	local gui = surface(box, Enum.NormalId.Back)
	gui.PixelsPerStud = 100
	local colors = Util.appColors(manifest)
	local cover = Util.new("Frame", { Size = UDim2.new(1, 0, 0.86, 0), Position = UDim2.fromScale(0, 0.14), BackgroundColor3 = Color3.new(1, 1, 1), Parent = gui }, {
		Util.gradient({ colors[1], colors[2] or colors[1] }, 135),
	})
	local image = Util.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop, Parent = cover })
	if not Embedded.ApplyImage(image, manifest.cover, manifest.module) then
		image:Destroy()
		local icon = Util.appIcon(manifest, UDim2.fromScale(0.6, 0.45))
		icon.Position = UDim2.fromScale(0.2, 0.15)
		icon.Parent = cover
	end
	Util.text(manifest.title, { Size = UDim2.new(1, -10, 0.16, 0), Position = UDim2.new(0, 5, 0.82, 0), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.FontBold, TextStrokeTransparency = 0.5, Parent = cover })
	Util.text("PS5", { Size = UDim2.fromScale(1, 0.14), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.FontHeavy, Parent = gui })
	box.Parent = display
	if not own then
		return -- в гостях коробки только для красоты
	end
	local rest = box.CFrame
	local p = prompt(box, "Play", manifest.title, function()
		ChillZone.Activate({ launch = manifest.id })
	end, 7)
	-- коробка выезжает с полки и поворачивается к игроку
	p.PromptShown:Connect(function()
		Util.tween(box, 0.35, { CFrame = rest * CFrame.new(0, 0.25, 0.9) * CFrame.Angles(math.rad(-8), math.rad(12), 0) }, Enum.EasingStyle.Back)
	end)
	p.PromptHidden:Connect(function()
		Util.tween(box, 0.3, { CFrame = rest })
	end)
end

local function statsBoard(board, summary)
	local gui = surface(board, Enum.NormalId.Left)
	local t = summary.trophies
	local panel = Util.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 18, 34), Parent = gui }, { Util.padding(16) })
	Util.text(summary.displayName or "Player", { Size = UDim2.fromScale(1, 0.18), TextScaled = true, Font = Theme.FontHeavy, Parent = panel })
	Util.text(`Chill Zone LV {summary.tier} · {summary.tierName}`, { Size = UDim2.fromScale(1, 0.13), Position = UDim2.fromScale(0, 0.22), TextScaled = true, TextColor3 = Theme.Colors.AccentLight, Font = Theme.FontBold, Parent = panel })
	Util.text(`🏆 {t.got} of {t.total}\n🥉 {t.bronze}   🥈 {t.silver}\n🥇 {t.gold}   💎 {t.platinum}\n🎮 games: {summary.gamesOwned}`, {
		Size = UDim2.fromScale(1, 0.58), Position = UDim2.fromScale(0, 0.4), TextScaled = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = panel,
	})
end

-- Коллекция для витрины: своя из локальных данных, чужая из публичного профиля
local function ownCollection()
	local list = {}
	for _, manifest in Registry.List() do
		for _, t in Trophies.List(manifest) do
			table.insert(list, { trophy = t, manifest = manifest })
		end
	end
	local games = table.clone(Registry.List())
	table.sort(games, function(a, b)
		return (Data.LastPlayed(a.id) or 0) > (Data.LastPlayed(b.id) or 0)
	end)
	return list, games, ChillZone.OwnSummary()
end

local function publicCollection(summary)
	local list, games = {}, {}
	for _, g in summary.games do
		local manifest = Registry.Get(g.id)
		if manifest and g.installed then
			table.insert(games, manifest)
			for _, t in manifest.trophies do
				local item = table.clone(t)
				item.grade = item.grade or "bronze"
				item.unlocked = g.unlocked[t.id] == true
				table.insert(list, { trophy = item, manifest = manifest })
			end
		end
	end
	return list, games, summary
end

local function fillZone(z, own, summary)
	if displays[z] then
		displays[z]:Destroy()
	end
	local kept = {}
	for _, item in spinning do
		if item.model.Parent and item.model:IsDescendantOf(Workspace) then
			table.insert(kept, item)
		end
	end
	spinning = kept
	local display = Instance.new("Folder")
	display.Name = own and "MyCollection" or "Collection"
	displays[z] = display
	local trophySlots, gameSlots = {}, {}
	for _, child in z:GetChildren() do
		if child.Name == "TrophySlot" then
			trophySlots[child:GetAttribute("Index")] = child
		elseif child.Name == "GameSlot" then
			gameSlots[child:GetAttribute("Index")] = child
		end
	end
	local list, games, stats
	if own then
		list, games, stats = ownCollection()
	else
		list, games, stats = publicCollection(summary)
	end
	-- сначала полученные, затем закрытые; платина первой
	local order = { platinum = 1, gold = 2, silver = 3, bronze = 4 }
	table.sort(list, function(a, b)
		if a.trophy.unlocked ~= b.trophy.unlocked then
			return a.trophy.unlocked
		end
		return (order[a.trophy.grade] or 5) < (order[b.trophy.grade] or 5)
	end)
	for i, item in list do
		local spot = trophySlots[i]
		if not spot then
			break
		end
		trophyModel(spot, item.trophy, item.manifest).Parent = display
	end
	for i, manifest in games do
		if gameSlots[i] then
			gameCase(gameSlots[i], manifest, display, own)
		end
	end
	local board = z:FindFirstChild("StatsBoard")
	if board then
		for _, g in board:GetChildren() do
			if g:IsA("SurfaceGui") then
				g:Destroy()
			end
		end
		statsBoard(board, stats)
	end
	display.Parent = z
end

-- Чужая чиллзона: консоль, телевизор, эффекты и витрина хозяина
local function refreshGuestZone(z)
	local summary = ChillZone.FetchProfile(z:GetAttribute("OwnerId"))
	if summary and z.Parent then
		fillZone(z, false, summary)
	end
end

local function decorate(z, own)
	if decorated[z] then
		return
	end
	decorated[z] = true
	WorldFX.Start(z)
	local spot = z:WaitForChild("ConsoleSpot", 10)
	if spot then
		placeConsole(z, spot)
	end
	local controllerSpot = z:FindFirstChild("ControllerSpot")
	if controllerSpot then
		placeController(z, controllerSpot)
	end
	buildTV(z, own)
	ambience(z, own)
	if own then
		return spot
	end
	refreshGuestZone(z)
	local owner = Players:GetPlayerByUserId(z:GetAttribute("OwnerId") or 0)
	if owner then
		local queued = false
		owner:GetAttributeChangedSignal("PS5ProfileVersion"):Connect(function()
			if queued then
				return
			end
			queued = true
			task.delay(2, function()
				queued = false
				refreshGuestZone(z)
			end)
		end)
	end
	z.AncestryChanged:Connect(function()
		if not z.Parent then
			decorated[z] = nil
			displays[z] = nil
		end
	end)
	return spot
end

-- Перерисовать свои трофеи, игры и табло
function ChillZone.Refresh()
	if zone then
		fillZone(zone, true)
	end
end

function ChillZone.Zone()
	return zone
end

function ChillZone.IsActive()
	return active
end

-- Подойти к PS5: камера наезжает на телевизор, включается интерфейс
function ChillZone.Activate(opts)
	if active or not shell then
		return
	end
	active = true
	-- пока PS5 включена, подсказки мира («Play on PS5» и т.п.) не всплывают поверх игр
	game:GetService("ProximityPromptService").Enabled = false
	local ctrl = controls()
	if ctrl then
		ctrl:Disable()
	end
	local camera = Workspace.CurrentCamera
	local screen = zone and zone:FindFirstChild("TVScreen")
	camera.CameraType = Enum.CameraType.Scriptable
	Audio.Ui("open")
	if screen then
		-- плавный облёт к дивану, затем «нырок» в экран с размытием и вспышкой
		local target = screen.Position
		local first = CFrame.lookAt(target + Vector3.new(-4, -1, 21), target)
		TweenService:Create(camera, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = first, FieldOfView = 60 }):Play()
		task.wait(1.1)
		local blur = Instance.new("BlurEffect")
		blur.Size = 0
		blur.Parent = Lighting
		TweenService:Create(camera, TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { CFrame = CFrame.lookAt(target + Vector3.new(0, 0, 4), target), FieldOfView = 40 }):Play()
		TweenService:Create(blur, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = 28 }):Play()
		task.wait(0.65)
		task.delay(0.1, function()
			Util.tween(blur, 0.6, { Size = 0 }).Completed:Connect(function()
				blur:Destroy()
			end)
		end)
	end
	shell.PowerOn(opts)
end

local function onExit()
	game:GetService("ProximityPromptService").Enabled = true
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	if humanoid then
		camera.CameraSubject = humanoid
	end
	local ctrl = controls()
	if ctrl then
		ctrl:Enable()
	end
	active = false
	ChillZone.Refresh()
end

function ChillZone.Start(ui)
	shell = ui
	zonesFolder = Workspace:WaitForChild("ChillZones", 30)
	zone = zonesFolder and zonesFolder:WaitForChild("Zone_" .. player.UserId, 30)
	if not zone then
		warn("[PS5] Chill zone not found, powering on the UI right away")
		ui.standalone = true
		ui.PowerOn()
		return
	end
	local spot = decorate(zone, true)
	for _, z in zonesFolder:GetChildren() do
		if z ~= zone then
			task.spawn(decorate, z, false)
		end
	end
	zonesFolder.ChildAdded:Connect(function(z)
		task.wait(1)
		decorate(z, false)
	end)
	prompt(spot, "Play on PS5", "PlayStation 5", function()
		ChillZone.Activate()
	end, 12)
	ChillZone.Refresh()
	ui.Exited:Connect(onExit)
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, item in spinning do
			if item.model.Parent then
				item.model:PivotTo(item.base * CFrame.new(0, 0.12 + math.sin(t * 1.6 + item.phase) * 0.1, 0) * CFrame.Angles(0, t * 0.8 + item.phase, 0))
			end
		end
		for _, glow in glows do
			glow.Brightness = 1 + 0.8 * (0.5 + 0.5 * math.sin(t * 1.4))
		end
	end)
	-- пролёт камеры при первом появлении персонажа
	task.spawn(function()
		local character = player.Character or player.CharacterAdded:Wait()
		if character and not active then
			local ctrl = controls()
			if ctrl then
				ctrl:Disable()
			end
			WorldFX.Intro(zone:GetAttribute("Origin"), function()
				local c = controls()
				if c and not active then
					c:Enable()
				end
			end)
		end
	end)
	Trophies.Unlocked:Connect(function()
		task.delay(2, ChillZone.Refresh)
	end)
	Data.UserChanged:Connect(function()
		if not active then
			ChillZone.Refresh()
		end
	end)
end

return ChillZone
