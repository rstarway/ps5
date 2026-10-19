-- Клиентская сторона данных: профиль игрока грузится с сервера (DataStore),
-- изменения сразу применяются локально и отправляются на сервер.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Signal = require(script.Parent.Signal)

local Data = {}
Data.Changed = Signal.new() -- (path)
Data.SettingChanged = Signal.new() -- (key, value)
Data.UserChanged = Signal.new() -- (user)

Data.DefaultSettings = {
	volume = 0.7,
	uiSounds = true,
	menuMusic = true,
	background = "aurora",
	reduceMotion = false,
	clock24 = true,
	vibration = true,
	showFps = false,
	bootAnimation = true,
}

local profile = nil
local mutate = nil
local currentUserId = nil

local USER_COLORS = { "#2D7CF6", "#E5484D", "#30A46C", "#F5A524", "#8E4EC6", "#12A594", "#E54D9C" }

local function defaultProfile()
	local player = Players.LocalPlayer
	return {
		version = 1,
		settings = {},
		users = { { id = "u1", name = player and player.DisplayName or "Player", color = USER_COLORS[1] } },
		data = {},
	}
end

function Data.Load()
	local remotes = ReplicatedStorage:WaitForChild("PS5Remotes", 10)
	if remotes then
		mutate = remotes:WaitForChild("Mutate", 5)
		local getProfile = remotes:WaitForChild("GetProfile", 5)
		if getProfile then
			local ok, result = pcall(function()
				return getProfile:InvokeServer()
			end)
			if ok and type(result) == "table" then
				profile = result
			end
		end
	else
		warn("[PS5] Data server not found, saves last until you leave")
	end
	profile = profile or defaultProfile()
	profile.settings = profile.settings or {}
	profile.data = profile.data or {}
	if not profile.users or #profile.users == 0 then
		profile.users = defaultProfile().users
	end
	-- последний выбранный пользователь (для трофеев и игр в доме до входа в PS5)
	currentUserId = profile.settings.lastUser
	if not Data.User(currentUserId) then
		currentUserId = profile.users[1].id
	end
end

local function walk(path, create)
	local node = profile
	for i = 1, #path - 1 do
		local key = path[i]
		if type(node[key]) ~= "table" then
			if not create then
				return nil
			end
			node[key] = {}
		end
		node = node[key]
	end
	return node
end

function Data.Get(path)
	local parent = walk(path, false)
	return parent and parent[path[#path]]
end

-- Путь — массив строк, например {"data", "u1", "saves", "star_pilot", "best"}. value = nil удаляет.
function Data.Set(path, value)
	walk(path, true)[path[#path]] = value
	if mutate then
		mutate:FireServer(path, value)
	end
	Data.Changed:Fire(path)
end

-- Настройки системы
function Data.Setting(key)
	local value = profile.settings[key]
	if value == nil then
		return Data.DefaultSettings[key]
	end
	return value
end

function Data.SetSetting(key, value)
	Data.Set({ "settings", key }, value)
	Data.SettingChanged:Fire(key, value)
end

-- Пользователи (локальные профили внутри аккаунта Roblox)
function Data.Users()
	return profile.users
end

function Data.User(id)
	for _, user in profile.users do
		if user.id == id then
			return user
		end
	end
	return nil
end

function Data.CurrentUser()
	return currentUserId and Data.User(currentUserId)
end

function Data.SetCurrentUser(id)
	currentUserId = id
	Data.Set({ "settings", "lastUser" }, id)
	Data.UserChanged:Fire(Data.User(id))
end

function Data.AddUser(name)
	local maxId = 0
	for _, user in profile.users do
		maxId = math.max(maxId, tonumber(string.sub(user.id, 2)) or 0)
	end
	local user = {
		id = "u" .. (maxId + 1),
		name = name or ("Player " .. (#profile.users + 1)),
		color = USER_COLORS[(#profile.users % #USER_COLORS) + 1],
	}
	local users = table.clone(profile.users)
	table.insert(users, user)
	Data.Set({ "users" }, users)
	return user
end

function Data.RenameUser(id, name)
	local users = table.clone(profile.users)
	for i, user in users do
		if user.id == id then
			local copy = table.clone(user)
			copy.name = name
			users[i] = copy
		end
	end
	Data.Set({ "users" }, users)
	if id == currentUserId then
		Data.UserChanged:Fire(Data.User(id))
	end
end

function Data.RemoveUser(id)
	if #profile.users <= 1 then
		return false
	end
	local users = {}
	for _, user in profile.users do
		if user.id ~= id then
			table.insert(users, user)
		end
	end
	Data.Set({ "users" }, users)
	Data.Set({ "data", id }, nil)
	return true
end

-- Данные приложений текущего пользователя
function Data.UserPath(...)
	return { "data", currentUserId or "u1", ... }
end

function Data.AppSaves(appId)
	return Data.Get(Data.UserPath("saves", appId)) or {}
end

function Data.Trophies(appId)
	return Data.Get(Data.UserPath("trophies", appId)) or {}
end

function Data.LastPlayed(appId)
	return Data.Get(Data.UserPath("played", appId))
end

function Data.MarkPlayed(appId)
	Data.Set(Data.UserPath("played", appId), os.time())
end

function Data.ClearAppData(appId)
	Data.Set(Data.UserPath("saves", appId), nil)
	Data.Set(Data.UserPath("trophies", appId), nil)
end

function Data.FactoryReset()
	local fresh = defaultProfile()
	Data.Set({ "settings" }, {})
	Data.Set({ "data" }, {})
	Data.Set({ "users" }, fresh.users)
end

return Data
