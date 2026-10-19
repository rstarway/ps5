-- Реестр приложений: каждая папка (ModuleScript) в ReplicatedStorage.PS5Apps
-- с дочерним модулем manifest регистрируется автоматически.
-- Установлены только игры, скачанные в PS Store (или с preinstalled = true в манифесте);
-- Registry.List() отдаёт установленные, Registry.All() — все, что есть в песочнице (для магазина).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(script.Parent.Data)
local Signal = require(script.Parent.Signal)

local Registry = {}
Registry.Changed = Signal.new()

local apps = {}
local byId = {}

local VALID_CATEGORIES = { game = true, media = true, app = true }

local function validate(manifest, module)
	assert(type(manifest) == "table", "manifest must return a table")
	assert(type(manifest.id) == "string" and manifest.id:match("^[%w_%-]+$"), "manifest.id: latin letters, digits, _ and -")
	assert(type(manifest.title) == "string", "manifest.title is required")
	manifest.category = manifest.category or "game"
	assert(VALID_CATEGORIES[manifest.category], "manifest.category: game, media or app")
	manifest.trophies = manifest.trophies or {}
	manifest.colors = manifest.colors or { "#1b2a5a", "#0a1024" }
	manifest.description = manifest.description or ""
	manifest.developer = manifest.developer or "Unknown developer"
	manifest.version = manifest.version or "1.0"
	manifest.module = module
	return manifest
end

function Registry.Load()
	table.clear(apps)
	table.clear(byId)
	local folder = ReplicatedStorage:WaitForChild("PS5Apps")
	for _, module in folder:GetChildren() do
		local manifestModule = module:FindFirstChild("manifest")
		if module:IsA("ModuleScript") and manifestModule then
			local ok, result = pcall(function()
				return validate(table.clone(require(manifestModule)), module)
			end)
			if not ok then
				warn(`[PS5] App {module.Name} failed to load: {result}`)
			elseif byId[result.id] then
				warn(`[PS5] Duplicate app id: {result.id}`)
			elseif not result.hidden then
				table.insert(apps, result)
				byId[result.id] = result
			end
		end
	end
	table.sort(apps, function(a, b)
		local oa, ob = a.order or 100, b.order or 100
		if oa ~= ob then
			return oa < ob
		end
		return a.title < b.title
	end)
	return apps
end

local function installPath(id)
	return { "settings", "installed", id }
end

function Registry.IsInstalled(id)
	local manifest = byId[id]
	if not manifest then
		return false
	end
	local ok, flag = pcall(Data.Get, installPath(id))
	if not ok then
		flag = nil
	end
	if manifest.preinstalled then
		return flag ~= false
	end
	return flag == true
end

function Registry.Install(id)
	if byId[id] then
		Data.Set(installPath(id), true)
		Registry.Changed:Fire(id, true)
	end
end

function Registry.Uninstall(id)
	if byId[id] then
		Data.Set(installPath(id), false)
		Registry.Changed:Fire(id, false)
	end
end

local function filter(list, category, installedOnly)
	local result = {}
	for _, app in list do
		if (not category or app.category == category) and (not installedOnly or Registry.IsInstalled(app.id)) then
			table.insert(result, app)
		end
	end
	return result
end

-- Установленные приложения (домашний экран, библиотека, трофеи, дом)
function Registry.List(category)
	return filter(apps, category, true)
end

-- Все приложения песочницы, включая не скачанные (магазин)
function Registry.All(category)
	return filter(apps, category, false)
end

function Registry.Get(id)
	return byId[id]
end

return Registry
