-- Сервер данных PS5: хранит профиль каждого игрока (пользователи, настройки,
-- сохранения игр, трофеи) в DataStore. В Studio без доступа к API работает в памяти.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local STORE_NAME = "PS5Sandbox_v1"
local AUTOSAVE_SECONDS = 60
local MAX_BYTES = 3_500_000
local ROOTS = { settings = true, users = true, data = true }

Players.CharacterAutoLoads = true

local remotes = Instance.new("Folder")
remotes.Name = "PS5Remotes"
local getProfile = Instance.new("RemoteFunction")
getProfile.Name = "GetProfile"
getProfile.Parent = remotes
local mutate = Instance.new("RemoteEvent")
mutate.Name = "Mutate"
mutate.Parent = remotes
local getPublicProfile = Instance.new("RemoteFunction")
getPublicProfile.Name = "GetPublicProfile"
getPublicProfile.Parent = remotes
remotes.Parent = ReplicatedStorage

local Progress = require(ReplicatedStorage:WaitForChild("PS5"):WaitForChild("Progress"))

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[PS5] DataStore unavailable (enable Studio Access to API Services). Data is kept in memory only.")
	end
end

local profiles = {} -- player -> { data, dirty, loaded }

local function key(player)
	return "player_" .. player.UserId
end

local function defaultProfile(player)
	return {
		version = 1,
		settings = {},
		users = { { id = "u1", name = player.DisplayName, color = "#2D7CF6" } },
		data = {},
	}
end

local publish -- публичный профиль, ниже

local function load(player)
	local entry = { data = nil, dirty = false, loaded = false }
	profiles[player] = entry
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(key(player))
			end)
			if ok then
				entry.data = result
				break
			end
			warn(`[PS5] Load failed ({attempt}/3): {result}`)
			task.wait(attempt)
		end
	end
	entry.data = type(entry.data) == "table" and entry.data or defaultProfile(player)
	entry.loaded = true
	publish(player)
	return entry
end

local function save(player)
	local entry = profiles[player]
	if not (store and entry and entry.loaded and entry.dirty) then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(key(player), entry.data, { player.UserId })
	end)
	if ok then
		entry.dirty = false
	else
		warn("[PS5] Save failed:", err)
	end
end

-- Публичный профиль: трофеи, награды и игры. Его видят другие игроки (профиль по наведению, витрина
-- в чужой чиллзоне), а уровень чиллзоны (атрибут PS5Tier) читает сервер чиллзоны.
local manifests
local function appManifests()
	if manifests then
		return manifests
	end
	manifests = {}
	local folder = ReplicatedStorage:WaitForChild("PS5Apps")
	for _, module in folder:GetChildren() do
		local m = module:FindFirstChild("manifest")
		if m then
			local ok, manifest = pcall(require, m)
			if ok and type(manifest) == "table" and type(manifest.id) == "string" and not manifest.hidden then
				table.insert(manifests, manifest)
			end
		end
	end
	return manifests
end

function publish(player)
	local entry = profiles[player]
	if not (entry and entry.loaded) then
		return
	end
	local summary = Progress.Summarize(entry.data, appManifests())
	summary.userId = player.UserId
	summary.name = player.Name
	summary.displayName = player.DisplayName
	entry.summary = summary
	player:SetAttribute("PS5Points", summary.points)
	player:SetAttribute("PS5Trophies", summary.trophies.got)
	player:SetAttribute("PS5Games", summary.gamesOwned)
	player:SetAttribute("PS5Tier", summary.tier)
	player:SetAttribute("PS5ProfileVersion", (player:GetAttribute("PS5ProfileVersion") or 0) + 1)
end

local function schedulePublish(player)
	local entry = profiles[player]
	if not entry or entry.publishQueued then
		return
	end
	entry.publishQueued = true
	task.delay(1, function()
		entry.publishQueued = false
		if profiles[player] == entry then
			publish(player)
		end
	end)
end

getPublicProfile.OnServerInvoke = function(_, userId)
	local target = typeof(userId) == "number" and Players:GetPlayerByUserId(userId)
	local entry = target and profiles[target]
	if not entry then
		return nil
	end
	while not entry.loaded do
		task.wait(0.1)
	end
	if not entry.summary then
		publish(target)
	end
	return entry.summary
end

local function validPath(path)
	if type(path) ~= "table" or #path < 1 or #path > 8 or not ROOTS[path[1]] then
		return false
	end
	for _, part in path do
		if type(part) ~= "string" or #part == 0 or #part > 64 then
			return false
		end
	end
	return true
end

getProfile.OnServerInvoke = function(player)
	local entry = profiles[player]
	while entry and not entry.loaded do
		task.wait(0.1)
	end
	return entry and entry.data
end

mutate.OnServerEvent:Connect(function(player, path, value)
	local entry = profiles[player]
	if not (entry and entry.loaded and validPath(path)) then
		return
	end
	local okEncode = pcall(HttpService.JSONEncode, HttpService, { v = value })
	if not okEncode then
		return
	end
	local node = entry.data
	for i = 1, #path - 1 do
		if type(node[path[i]]) ~= "table" then
			node[path[i]] = {}
		end
		node = node[path[i]]
	end
	local previous = node[path[#path]]
	node[path[#path]] = value
	if #HttpService:JSONEncode(entry.data) > MAX_BYTES then
		node[path[#path]] = previous
		warn("[PS5] Profile size limit exceeded, change rejected")
		return
	end
	entry.dirty = true
	schedulePublish(player)
end)

Players.PlayerAdded:Connect(load)
for _, player in Players:GetPlayers() do
	task.spawn(load, player)
end

Players.PlayerRemoving:Connect(function(player)
	save(player)
	profiles[player] = nil
end)

game:BindToClose(function()
	for player in profiles do
		task.spawn(save, player)
	end
	task.wait(2)
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		for player in profiles do
			task.spawn(save, player)
		end
	end
end)
