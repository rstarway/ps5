-- Трофеи: описываются в manifest.trophies, разблокируются через ctx.trophies:Unlock(id).
local Data = require(script.Parent.Data)
local Signal = require(script.Parent.Signal)
local Audio = require(script.Parent.Audio)

local Trophies = {}
Trophies.Unlocked = Signal.new() -- (manifest, trophy)

local function find(manifest, id)
	for _, trophy in manifest.trophies do
		if trophy.id == id then
			return trophy
		end
	end
	return nil
end

function Trophies.IsUnlocked(manifest, id)
	return Data.Trophies(manifest.id)[id] ~= nil
end

function Trophies.Unlock(manifest, id)
	local trophy = find(manifest, id)
	if not trophy then
		warn(`[PS5] {manifest.id}: trophy "{id}" is not listed in manifest.trophies`)
		return false
	end
	if Trophies.IsUnlocked(manifest, id) then
		return false
	end
	Data.Set(Data.UserPath("trophies", manifest.id, id), os.time())
	Audio.Ui("trophy")
	Trophies.Unlocked:Fire(manifest, trophy)
	-- платина выдаётся автоматически, когда собраны все остальные
	if trophy.grade ~= "platinum" then
		local platinum, allDone = nil, true
		for _, t in manifest.trophies do
			if t.grade == "platinum" then
				platinum = t
			elseif not Trophies.IsUnlocked(manifest, t.id) then
				allDone = false
			end
		end
		if platinum and allDone then
			task.delay(1.5, function()
				Trophies.Unlock(manifest, platinum.id)
			end)
		end
	end
	return true
end

-- Список с состоянием: { {id, name, description, grade, hidden, unlocked, unlockedAt}, ... }
function Trophies.List(manifest)
	local unlocked = Data.Trophies(manifest.id)
	local list = {}
	for _, t in manifest.trophies do
		local item = table.clone(t)
		item.grade = item.grade or "bronze"
		item.unlockedAt = unlocked[t.id]
		item.unlocked = item.unlockedAt ~= nil
		table.insert(list, item)
	end
	return list
end

function Trophies.Progress(manifest)
	local total = #manifest.trophies
	if total == 0 then
		return 0, 0, 0
	end
	local count = 0
	for _, t in manifest.trophies do
		if Trophies.IsUnlocked(manifest, t.id) then
			count += 1
		end
	end
	return count, total, math.floor(count / total * 100)
end

return Trophies
