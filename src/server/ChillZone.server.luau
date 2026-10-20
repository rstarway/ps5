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
	-- табличка освещается как обычная поверхность: никакого свечения
	gui.LightInfluence = 1
	gui.Brightness = 1
	gui.PixelsPerStud = 50
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.BuilderSansMedium
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.18, 0)
	padding.PaddingBottom = UDim.new(0.18, 0)
	padding.Parent = label
	gui.Parent = p
	return gui
end

-- Земля: участок идеально ровный (поверхность ровно на y = 0, по границе вокселей, поэтому Terrain нигде
-- не вылезает сквозь дорожки и полы), за живой изгородью рельеф плавно поднимается в лесистые холмы.
-- Бассейн: Terrain-вода в плиточной чаше из Blender (метка Pool с координатами).
local terrain = Workspace.Terrain
local VOXEL = 4
local PLOT_HALF_X, PLOT_Z0, PLOT_Z1 = 92, -57, 128 -- ровная зона (изгородь + 12 студов газона за ней)
local HILL_X, HILL_Z0, HILL_Z1 = 256, -228, 296 -- куда тянутся холмы (участки соседей через 520 по X)

local function smoothstep(a, b, x)
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- высота земли относительно начала участка
local function groundHeight(x, z)
	local dx = math.max(math.abs(x) - PLOT_HALF_X, 0)
	local dz = math.max(z - PLOT_Z1, PLOT_Z0 - z, 0)
	local d = math.sqrt(dx * dx + dz * dz)
	if d <= 0 then
		return 0
	end
	local big = 0.65 + 0.35 * math.noise(x / 90, z / 90, 0.37)
	local small = math.noise(x / 28, z / 28, 1.91) * 5
	return 46 * smoothstep(6, 130, d) * big + small * smoothstep(0, 40, d)
end

local function fillTerrain(origin)
	-- WriteVoxels требует области, выровненной по сетке 4 студа
	local x0, x1 = origin.X - HILL_X, origin.X + HILL_X
	local z0, z1 = origin.Z + HILL_Z0, origin.Z + HILL_Z1
	local y0, y1 = -16, 64
	local nx, ny, nz = (x1 - x0) / VOXEL, (y1 - y0) / VOXEL, (z1 - z0) / VOXEL
	local materials, occupancy = table.create(nx), table.create(nx)
	for i = 1, nx do
		local mi, oi = table.create(ny), table.create(ny)
		for j = 1, ny do
			mi[j], oi[j] = table.create(nz), table.create(nz)
		end
		local x = x0 + (i - 0.5) * VOXEL - origin.X
		for k = 1, nz do
			local z = z0 + (k - 0.5) * VOXEL - origin.Z
			local h = groundHeight(x, z)
			local mat = (h > 6 and math.noise(x / 40, z / 40, 7.3) > 0.15) and M.LeafyGrass or M.Grass
			for j = 1, ny do
				-- гладкий Terrain рисует поверхность по центрам вокселей: занятость 0.5 у вокселя [-4, 0]
				-- даёт поверхность ровно на y = 0 (полностью занятый воксель поднял бы газон на 2 студа)
				local vy = y0 + (j - 1) * VOXEL
				local occ = math.clamp((h - vy - VOXEL / 2) / VOXEL, 0, 1)
				mi[j][k] = occ > 0 and mat or M.Air
				oi[j][k] = occ
			end
		end
		materials[i], occupancy[i] = mi, oi
	end
	terrain:WriteVoxels(Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x1, y1, z1)), VOXEL, materials, occupancy)
	-- бассейн: сначала воздух под чашей, потом вода до уровня Surface
	local pool = zone:FindFirstChild("Pool")
	if pool then
		local px0, px1 = pool:GetAttribute("X0"), pool:GetAttribute("X1")
		local pz0, pz1 = pool:GetAttribute("Z0"), pool:GetAttribute("Z1")
		local bottom, surface = pool:GetAttribute("Bottom"), pool:GetAttribute("Surface")
		local center = origin + Vector3.new((px0 + px1) / 2, 0, (pz0 + pz1) / 2)
		-- вырезаем глубоко: полузаполненный воксель под дном поднял бы грунт выше плиток
		terrain:FillBlock(CFrame.new(center + Vector3.new(0, -6, 0)), Vector3.new(px1 - px0 + 2, 12, pz1 - pz0 + 2), M.Air)
		terrain:FillBlock(CFrame.new(center + Vector3.new(0, (bottom + surface) / 2, 0)),
			Vector3.new(px1 - px0, surface - bottom, pz1 - pz0), M.Water)
	end
end
terrain.WaterColor = rgb(40, 118, 140)
terrain.WaterTransparency = 0.6
terrain.WaterReflectance = 0.6
terrain.WaterWaveSize = 0.05
terrain.WaterWaveSpeed = 6
pcall(function()
	terrain:SetMaterialColor(M.Grass, rgb(82, 110, 58))
	terrain:SetMaterialColor(M.LeafyGrass, rgb(70, 98, 52))
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
		-- неон в проекте не используем: старые стили из Blender становятся пластиком
		p.Material = style.material == "Neon" and M.SmoothPlastic or M[style.material]
		p.Transparency = style.transparency
		p.CastShadow = style.material ~= "Glass" and size.Magnitude > 1.2
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

-- Модели из Hunyuan3D (assets/roblox/*.rbxm → ServerStorage.ChillZoneAssets) ставятся на метки AssetSpot из Blender:
-- низ модели по центру на метку, поворот Yaw, масштаб под Size по высоте (Fit = "height") или по длинной стороне.
-- Модели нормализованы при импорте: опора внизу по центру, «перед» смотрит на +Z.
local assetLibrary = game:GetService("ServerStorage"):FindFirstChild("ChillZoneAssets")

local function placeAsset(name, cf, size, fit, tier)
	local source = assetLibrary and assetLibrary:FindFirstChild(name)
	if not source then
		return nil
	end
	local model = source:Clone()
	local _, box = model:GetBoundingBox()
	local current = fit == "length" and math.max(box.X, box.Z) or box.Y
	if size and current > 0 then
		model:ScaleTo(model:GetScale() * size / current)
	end
	model:PivotTo(cf)
	if tier and tier > 1 then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p:SetAttribute("Tier", tier)
			end
		end
	end
	return model
end

local function placeAssets(z)
	local missing = {}
	for _, spot in z:GetChildren() do
		if spot.Name == "AssetSpot" then
			local name = spot:GetAttribute("Asset")
			local cf = CFrame.new(spot.Position) * CFrame.Angles(0, math.rad(spot:GetAttribute("Yaw") or 0), 0)
			local model = placeAsset(name, cf, spot:GetAttribute("Size"), spot:GetAttribute("Fit"), spot:GetAttribute("Tier"))
			if model then
				model.Parent = z
				spot:Destroy()
			else
				missing[name] = true
			end
		end
	end
	local names = {}
	for name in missing do
		table.insert(names, name)
	end
	if #names > 0 then
		table.sort(names)
		warn("[PS5] Chill zone models not imported yet:", table.concat(names, ", "))
	end
end

-- Лес на холмах вокруг участка (свой для каждого участка, живёт вместе с Terrain)
local hillsFolder = Instance.new("Folder")
hillsFolder.Name = "ChillHills"
hillsFolder.Parent = Workspace

local function plantHills(origin, slot)
	local folder = Instance.new("Folder")
	folder.Name = "Hills_" .. slot
	local rng = Random.new(1000 + slot)
	-- лёгкие версии деревьев (~3 тыс. треугольников): лес видно только издалека, полные модели тут не нужны
	-- только хвойные: лиственные кроны на склонах издалека выглядят как грибы
	local kinds = { "HillPine" }
	local placed = {}
	for _ = 1, 260 do
		if #placed >= 40 then
			break
		end
		local x = rng:NextNumber(-HILL_X + 20, HILL_X - 20)
		local z = rng:NextNumber(HILL_Z0 + 20, HILL_Z1 - 20)
		local h = groundHeight(x, z)
		local far = h > 4
		local free = true
		for _, p in placed do
			if (p - Vector3.new(x, 0, z)).Magnitude < 22 then
				free = false
				break
			end
		end
		if far and free then
			local kind = kinds[rng:NextInteger(1, #kinds)]
			local size = (kind == "HillPine" and 24 or 20) * rng:NextNumber(0.8, 1.25)
			local cf = CFrame.new(origin + Vector3.new(x, h - 0.8, z)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			local tree = placeAsset(kind, cf, size, "height")
			if tree then
				tree.Parent = folder
				table.insert(placed, Vector3.new(x, 0, z))
			end
		end
	end
	folder.Parent = hillsFolder
end

placeAssets(zone)

-- Точка появления из Blender: у калитки, лицом к дому
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
		plantHills(origin, slot)
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

-- Тёплый вечер: солнце только что село, небо ещё светлое, во дворе горят обычные тёплые лампы
Lighting.ClockTime = 17.88
Lighting.GeographicLatitude = 25
Lighting.Brightness = 1.8
Lighting.Ambient = rgb(46, 44, 52)
Lighting.OutdoorAmbient = rgb(128, 118, 120)
Lighting.EnvironmentDiffuseScale = 0.55
Lighting.EnvironmentSpecularScale = 0.7
Lighting.ShadowSoftness = 0.25
Lighting.ExposureCompensation = 0.15
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Offset = 0.15
atmosphere.Color = rgb(236, 196, 168)
atmosphere.Decay = rgb(186, 116, 98) -- тёплый закатный горизонт (с холодным небо в сумерках зеленело)
atmosphere.Glare = 0.4
atmosphere.Haze = 1.2
atmosphere.Parent = Lighting
-- Без Bloom/SunRays/цветокоррекции: со свечением мир и игры пересвечивались
for _, e in Lighting:GetChildren() do
	if e:IsA("BloomEffect") or e:IsA("SunRaysEffect") or e:IsA("ColorCorrectionEffect") then
		e:Destroy()
	end
end
