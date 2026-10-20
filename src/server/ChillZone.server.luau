-- Чиллзона целиком из Blender: дом, двор, столкновения, свет, таблички и метки описаны в blender/chillzone.py
-- и выгружены в Assets/ChillZoneParts (python3 blender/export_luau.py chillzone). Сервер только кладёт землю (Terrain),
-- строит детали из этого модуля и настраивает освещение. Планировка: вход прямо по дорожке от точки появления,
-- в доме по центру PLAY (телевизор и PS5), слева MY GAMES, справа MY TROPHIES; во дворе костёр слева и пруд справа.
-- У каждого игрока своя чиллзона (Workspace.ChillZones.Zone_<UserId>) на своём участке. Она растёт вместе с уровнем
-- игрока (атрибут PS5Tier от PS5Server): детали уровня выше текущего лежат в ServerStorage и появляются при повышении.
-- Игроки ходят в гости через RemoteEvent PS5Remotes.VisitZone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

-- Сборка шаблона (меши из Creator Store) занимает секунды; без этого персонаж
-- появлялся над пустотой и разбивался ниже FallenPartsDestroyHeight. Спавн ниже, в createZone.
game:GetService("Players").CharacterAutoLoads = false

local zone = Instance.new("Model")
zone.Name = "ChillZone"

local rgb = Color3.fromRGB
local M = Enum.Material

local function part(name, size, at, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = typeof(at) == "CFrame" and at or CFrame.new(at)
	p.Color = color or rgb(200, 200, 200)
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = zone
	return p
end

local function sign(p, face, text, color, size)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.PixelsPerStud = 50
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.BuilderSansExtraBold
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = size or 3
	stroke.Transparency = 0.6
	stroke.Parent = label
	gui.Parent = p
	return gui
end

-- Земля: Terrain из утоптанной земли без травы (верх на y = 0) и пруд с живой водой.
-- Под домом и верандой земля вырезана: гладкий Terrain поднимается до полувокселя и лез бы сквозь пол.
local terrain = Workspace.Terrain
local function fillTerrain(origin)
	local function at(x, y, z)
		return CFrame.new(origin + Vector3.new(x, y, z))
	end
	-- воксели 4×4: блок до y = -2 даёт гладкую поверхность ровно на y ≈ 0
	terrain:FillBlock(at(0, -8, 40), Vector3.new(400, 12, 400), M.Ground)
	terrain:FillBlock(at(0, 3, 0), Vector3.new(62, 10, 42), M.Air)
	terrain:FillBlock(at(0, 3, 25.5), Vector3.new(26, 10, 11), M.Air)
	terrain:FillBlock(at(0, -9, 4), Vector3.new(62, 10, 54), M.Ground)
	-- пруд: сначала вырезаем воздух, иначе верхний слой вокселей остаётся землёй
	terrain:FillCylinder(at(42, 0, 52), 6, 13, M.Air)
	terrain:FillCylinder(at(42, -3, 52), 6, 12.6, M.Water)
end
terrain.WaterColor = rgb(36, 96, 128)
terrain.WaterTransparency = 0.45
terrain.WaterReflectance = 0.7
terrain.WaterWaveSize = 0.12
terrain.WaterWaveSpeed = 8
pcall(function()
	terrain:SetMaterialColor(M.Ground, rgb(84, 72, 58))
end)


-- Детали из Blender. Обычные идут в модель Scenery; особые (метки, свет, таблички, огонь) кладутся прямо в ChillZone
-- под своими именами, их ищет клиент (ConsoleSpot, TVScreen, TrophySlot, GameSlot, StatsBoard, Bulb, GuideArrow…).
local SHAPES = { Enum.PartType.Block, Enum.PartType.Cylinder, Enum.PartType.Ball }
local function color3(c)
	return rgb(c[1], c[2], c[3])
end

local function addLight(p, info)
	local l
	if info.surface then
		l = Instance.new("SurfaceLight")
		l.Face = Enum.NormalId[info.surface]
		l.Angle = info.angle
	else
		l = Instance.new("PointLight")
	end
	l.Color = color3(info.color)
	l.Range = info.range
	l.Brightness = info.brightness
	l.Shadows = info.shadows == true
	if info.flicker then
		l:SetAttribute("Flicker", true)
	end
	l.Parent = p
end

local function buildScenery(data)
	local scenery = Instance.new("Model")
	scenery.Name = "Scenery"
	local built = {}
	for i, row in data.parts do
		local style = data.styles[row[1]]
		local shape = row[2]
		local cf = CFrame.new(row[3], row[4], row[5], row[6], row[7], row[8], row[9], row[10], row[11], row[12], row[13], row[14])
		local size = Vector3.new(row[15], row[16], row[17])
		local p = shape == 4 and Instance.new("WedgePart") or Instance.new("Part")
		if shape == 2 then
			p.Shape = SHAPES[2]
			cf *= CFrame.Angles(0, 0, math.pi / 2)
			size = Vector3.new(size.Y, size.X, size.Z)
		elseif shape == 3 then
			if math.abs(size.X - size.Y) < 0.01 and math.abs(size.X - size.Z) < 0.01 then
				p.Shape = SHAPES[3]
			else
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = p
			end
		end
		local solid = row[18] == 1
		p.Name = style.name
		p.Anchored = true
		p.CanCollide = solid
		p.CanQuery = solid
		p.CanTouch = false
		p.Size = size
		p.CFrame = cf
		p.Color = color3(style.color)
		p.Material = M[style.material]
		p.Transparency = style.transparency
		p.CastShadow = style.material ~= "Neon" and style.material ~= "Glass" and size.Magnitude > 1.2
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if (row[19] or 1) > 1 then
			p:SetAttribute("Tier", row[19])
		end
		p.Parent = scenery
		built[i] = p
	end
	for _, info in data.specials or {} do
		local p = built[info.row]
		p.Name = info.name
		if info.hidden then
			p.Transparency = 1
			p.CanCollide = false
			p.CanQuery = false
			p.CastShadow = false
		end
		if info.index then
			p:SetAttribute("Index", info.index)
		end
		for k, v in info.attrs or {} do
			p:SetAttribute(k, v)
		end
		if info.light then
			addLight(p, info.light)
		end
		if info.sign then
			sign(p, Enum.NormalId[info.sign.face], info.sign.text, color3(info.sign.color), 4)
		end
		if info.fire then
			local fire = Instance.new("Fire")
			fire.Size = 6
			fire.Heat = 9
			fire.Color = rgb(255, 140, 50)
			fire.SecondaryColor = rgb(255, 60, 20)
			fire.Parent = p
		end
		p.Parent = zone
	end
	return scenery
end

local okScenery, sceneryData = pcall(function()
	return require(ReplicatedStorage:WaitForChild("PS5"):WaitForChild("Assets"):WaitForChild("ChillZoneParts"))
end)
if okScenery then
	buildScenery(sceneryData).Parent = zone
else
	-- запасной вид: пол, телевизор и место консоли, чтобы PS5 всё равно запускалась
	warn("[PS5] Chill zone scenery missing:", sceneryData)
	part("Floor", Vector3.new(40, 1, 30), Vector3.new(0, 0.5, 0), rgb(150, 104, 70), M.WoodPlanks)
	part("TVScreen", Vector3.new(14, 8, 0.1), Vector3.new(0, 9, -14), rgb(4, 6, 12), M.Glass)
	part("ConsoleSpot", Vector3.one, Vector3.new(-5, 2, -12), nil, nil, { Transparency = 1, CanCollide = false })
	part("SpawnPoint", Vector3.one, Vector3.new(0, 1.5, 8), nil, nil, { Transparency = 1, CanCollide = false })
end

-- Красивые модели из Creator Store (Assets/CreatorStore): меши собираются на сервере,
-- если все детали модели загрузились, её запасные детали из Blender убираются.
local AssetService = game:GetService("AssetService")
local function buildStoreModel(info)
	local model = Instance.new("Model")
	model.Name = info.name
	local pivot = CFrame.new(info.pivot[1], info.pivot[2], info.pivot[3])
	-- меши качаются параллельно: по очереди это несколько секунд, и всё это время игрок ждёт спавна
	local meshes, pending, failure = {}, 0, nil
	for i, d in info.parts do
		if d.class ~= "Seat" then
			pending += 1
			task.spawn(function()
				local ok, result = pcall(function()
					return AssetService:CreateMeshPartAsync(d.mesh, { CollisionFidelity = Enum.CollisionFidelity.Box })
				end)
				if ok and result then
					meshes[i] = result
				else
					failure = failure or result or "no mesh"
				end
				pending -= 1
			end)
		end
	end
	while pending > 0 do
		task.wait()
	end
	if failure then
		for _, m in meshes do
			m:Destroy()
		end
		model:Destroy()
		warn("[PS5] Creator Store model failed, keeping the Blender one:", info.name, failure)
		return nil
	end
	for i, d in info.parts do
		local p
		if d.class == "Seat" then
			p = Instance.new("Seat")
			p.Transparency = 1
			p.CanCollide = false
		else
			p = meshes[i]
			if d.texture ~= "" then
				p.TextureID = d.texture
			end
			p.Color = d.color and color3(d.color) or rgb(163, 162, 165)
			p.CanCollide = d.solid == true
			p.CanQuery = d.solid == true
		end
		p.Name = d.name
		p.Anchored = true
		p.CanTouch = d.class == "Seat"
		p.Size = Vector3.new(d.size[1], d.size[2], d.size[3])
		p.CFrame = pivot * CFrame.new(d.cf[1], d.cf[2], d.cf[3]) * CFrame.Angles(0, math.rad(d.yaw or 0), 0)
		p.Parent = model
	end
	return model
end

local okStore, storeModels = pcall(function()
	return require(ReplicatedStorage.PS5.Assets:WaitForChild("CreatorStore"))
end)
if okStore then
	for _, info in storeModels do
		local model = buildStoreModel(info)
		if model then
			model.Parent = zone
			for _, d in zone:GetChildren() do
				if d.Name == info.fallback then
					d:Destroy()
				end
			end
		end
	end
end

-- Точка появления из Blender: перед домом, лицом к входу
local spawnPoint = zone:FindFirstChild("SpawnPoint")
local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn"
spawn.Anchored = true
spawn.Size = Vector3.new(6, 1, 6)
spawn.CFrame = CFrame.lookAt(spawnPoint.Position, spawnPoint.Position - Vector3.new(0, 0, 1))
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Neutral = true
spawn.Duration = 0
spawn.Parent = zone

-- Шаблон готов: каждая чиллзона игрока — его копия на своём участке
zone.WorldPivot = CFrame.new()

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local PLOT_SPACING = 520
local zonesFolder = Instance.new("Folder")
zonesFolder.Name = "ChillZones"
zonesFolder.Parent = Workspace
local hiddenRoot = Instance.new("Folder")
hiddenRoot.Name = "ChillZoneTiers"
hiddenRoot.Parent = ServerStorage

local remotes = ReplicatedStorage:WaitForChild("PS5Remotes")
local visitRemote = Instance.new("RemoteEvent")
visitRemote.Name = "VisitZone"
visitRemote.Parent = remotes

local slots = {} -- номер участка -> userId
local terrainReady = {}
local zones = {} -- userId -> { zone, slot, hidden, parts, tier }
local lastVisit = {}

-- участки по очереди справа и слева от первого: 0, +1, -1, +2, -2…
local function slotOrigin(slot)
	local k = slot % 2 == 1 and (slot + 1) / 2 or -slot / 2
	return Vector3.new(k * PLOT_SPACING, 0, 0)
end

-- показать детали своего уровня и спрятать те, что выше (очки могут и уменьшиться, если удалить игру)
local function applyTier(state, level, animate)
	state.tier = level
	state.zone:SetAttribute("Tier", level)
	for p, info in state.parts do
		local show = info.tier <= level
		if show and p.Parent == state.hidden then
			p.Parent = info.home
			if animate then
				p.Transparency = 1
				TweenService:Create(p, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = info.transparency }):Play()
			end
		elseif not show and p.Parent ~= state.hidden then
			p.Parent = state.hidden
		end
	end
end

local function setOwnerSign(z, player)
	local signPart = z:FindFirstChild("ChillSign")
	local gui = signPart and signPart:FindFirstChildOfClass("SurfaceGui")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = string.upper(player.DisplayName) .. "'S CHILL ZONE"
	end
end

local function spawnCFrame(state)
	return state.zone.Spawn.CFrame * CFrame.new(0, 3, 0)
end

local function sendTo(player, state)
	local character = player.Character
	if character and state then
		character:PivotTo(spawnCFrame(state))
	end
end

local function createZone(player)
	if zones[player.UserId] then
		return zones[player.UserId]
	end
	local slot = 0
	while slots[slot] do
		slot += 1
	end
	slots[slot] = player.UserId
	local origin = slotOrigin(slot)
	if not terrainReady[slot] then
		terrainReady[slot] = true
		fillTerrain(origin)
	end
	local z = zone:Clone()
	z.Name = "Zone_" .. player.UserId
	z:SetAttribute("OwnerId", player.UserId)
	z:SetAttribute("OwnerName", player.DisplayName)
	z:SetAttribute("Origin", origin)
	z:PivotTo(CFrame.new(origin))
	local hidden = Instance.new("Folder")
	hidden.Name = z.Name
	hidden.Parent = hiddenRoot
	local state = { zone = z, slot = slot, hidden = hidden, parts = {}, tier = 1 }
	for _, p in z:GetDescendants() do
		local level = p:IsA("BasePart") and p:GetAttribute("Tier")
		if level then
			state.parts[p] = { tier = level, home = p.Parent, transparency = p.Transparency }
		end
	end
	setOwnerSign(z, player)
	applyTier(state, player:GetAttribute("PS5Tier") or 1, false)
	z.Parent = zonesFolder
	zones[player.UserId] = state
	player.RespawnLocation = z.Spawn
	sendTo(player, state)
	player:GetAttributeChangedSignal("PS5Tier"):Connect(function()
		local level = player:GetAttribute("PS5Tier") or 1
		if zones[player.UserId] == state and level ~= state.tier then
			applyTier(state, level, level > state.tier)
		end
	end)
	player.CharacterAdded:Connect(function()
		player:SetAttribute("VisitingZone", nil)
	end)
	return state
end

local function onPlayerAdded(player)
	-- автоспавн выключен, поэтому возрождение после смерти тоже на нас
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid").Died:Once(function()
			task.wait(Players.RespawnTime)
			if player.Parent and player.Character == character then
				player:LoadCharacter()
			end
		end)
	end)
	local ok, err = pcall(createZone, player)
	if not ok then
		warn("[PS5] Chill zone failed for", player.Name, err)
	end
	if player.Parent and not player.Character then
		player:LoadCharacter()
	end
end

local function removeZone(player)
	local state = zones[player.UserId]
	if not state then
		return
	end
	zones[player.UserId] = nil
	slots[state.slot] = nil
	-- гости этой чиллзоны возвращаются к себе
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("VisitingZone") == player.UserId then
			other:SetAttribute("VisitingZone", nil)
			sendTo(other, zones[other.UserId])
		end
	end
	state.zone:Destroy()
	state.hidden:Destroy()
end

-- в гости: VisitZone(userId) — к другому игроку, VisitZone() — домой
visitRemote.OnServerEvent:Connect(function(player, targetUserId)
	local now = os.clock()
	if lastVisit[player] and now - lastVisit[player] < 1.5 then
		return
	end
	lastVisit[player] = now
	local own = zones[player.UserId]
	local target = typeof(targetUserId) == "number" and zones[targetUserId] or own
	if not target then
		return
	end
	player:SetAttribute("VisitingZone", target ~= own and targetUserId or nil)
	sendTo(player, target)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	removeZone(player)
	lastVisit[player] = nil
end)
for _, plr in Players:GetPlayers() do
	task.spawn(onPlayerAdded, plr)
end

-- Вечернее освещение и постобработка
Lighting.ClockTime = 19.3
Lighting.Brightness = 1.6
Lighting.Ambient = rgb(55, 50, 75)
Lighting.OutdoorAmbient = rgb(90, 80, 115)
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.8
if not Lighting:FindFirstChildOfClass("Atmosphere") then
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.2
	atmosphere.Color = rgb(150, 130, 200)
	atmosphere.Decay = rgb(90, 70, 140)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.5
	atmosphere.Parent = Lighting
end
local function effect(className, props)
	if Lighting:FindFirstChildOfClass(className) then
		return
	end
	local e = Instance.new(className)
	for k, v in props do
		e[k] = v
	end
	e.Parent = Lighting
end
effect("BloomEffect", { Intensity = 0.9, Size = 28, Threshold = 1.6 })
effect("ColorCorrectionEffect", { Brightness = 0.02, Contrast = 0.12, Saturation = 0.12, TintColor = rgb(255, 244, 236) })
effect("SunRaysEffect", { Intensity = 0.05, Spread = 0.6 })
