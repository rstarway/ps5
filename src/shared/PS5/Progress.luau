-- Прогресс игрока: очки за трофеи, скачанные и сыгранные игры, и уровень чиллзоны.
-- Используется сервером (PS5Server считает публичный профиль) и клиентом (профиль игрока, табло).
-- Модуль не зависит от Data: ему передают сырой профиль из DataStore и список манифестов.
local Progress = {}

Progress.GRADE_POINTS = { bronze = 15, silver = 30, gold = 90, platinum = 300 }
Progress.GAME_POINTS = 40 -- за каждую скачанную игру
Progress.PLAYED_POINTS = 20 -- за каждую игру, в которую играли

-- Уровни чиллзоны. Детали уровня описаны в blender/chillzone.py (with tier(n)).
Progress.TIERS = {
	{ at = 0, name = "Home", unlocks = "A modern house with a pool, a fire lounge and a carport" },
	{ at = 60, name = "Cozy", unlocks = "Planters and a rug on the terrace, olive trees at the gate" },
	{ at = 200, name = "Garden", unlocks = "A still-water basin, lavender and cherry trees" },
	{ at = 500, name = "Lounge", unlocks = "A hot tub by the pool and an outdoor kitchen" },
	{ at = 1000, name = "Luxury", unlocks = "A sports car, a pool daybed and a bronze sculpture" },
	{ at = 1800, name = "Legend", unlocks = "A rooftop terrace and a golden trophy statue" },
}

function Progress.Tier(points)
	local level = 1
	for i, t in Progress.TIERS do
		if points >= t.at then
			level = i
		end
	end
	local nextTier = Progress.TIERS[level + 1]
	return level, Progress.TIERS[level], nextTier and nextTier.at or nil
end

local function isInstalled(settings, manifest)
	local flag = type(settings.installed) == "table" and settings.installed[manifest.id] or nil
	if manifest.preinstalled then
		return flag ~= false
	end
	return flag == true
end

-- profile: { settings, users, data = { [userId] = { trophies, played, saves } } }
-- manifests: список манифестов приложений (без скрытых).
-- Трофеи всех пользователей консоли объединяются: это одна приставка одного игрока.
function Progress.Summarize(profile, manifests)
	profile = type(profile) == "table" and profile or {}
	local settings = type(profile.settings) == "table" and profile.settings or {}
	local users = type(profile.data) == "table" and profile.data or {}
	local summary = {
		points = 0,
		trophies = { got = 0, total = 0, bronze = 0, silver = 0, gold = 0, platinum = 0 },
		gamesOwned = 0,
		gamesPlayed = 0,
		games = {},
	}
	for _, manifest in manifests do
		local unlocked, lastPlayed, best = {}, nil, nil
		for _, user in users do
			if type(user) == "table" then
				local trophies = type(user.trophies) == "table" and user.trophies[manifest.id]
				if type(trophies) == "table" then
					for id in trophies do
						unlocked[id] = true
					end
				end
				local played = type(user.played) == "table" and user.played[manifest.id]
				if type(played) == "number" then
					lastPlayed = math.max(lastPlayed or 0, played)
				end
				local saves = type(user.saves) == "table" and user.saves[manifest.id]
				if type(saves) == "table" and type(saves.best) == "number" then
					best = math.max(best or 0, saves.best)
				end
			end
		end
		local installed = isInstalled(settings, manifest)
		local isGame = (manifest.category or "game") == "game"
		local game = { id = manifest.id, title = manifest.title, installed = installed, got = 0, total = 0, platinum = false, best = best, lastPlayed = lastPlayed, unlocked = {} }
		for _, t in manifest.trophies or {} do
			local grade = t.grade or "bronze"
			game.total += 1
			summary.trophies.total += 1
			if unlocked[t.id] then
				game.got += 1
				game.unlocked[t.id] = true
				summary.trophies.got += 1
				summary.trophies[grade] = (summary.trophies[grade] or 0) + 1
				summary.points += Progress.GRADE_POINTS[grade] or 0
				if grade == "platinum" then
					game.platinum = true
				end
			end
		end
		if isGame and installed then
			summary.gamesOwned += 1
			summary.points += Progress.GAME_POINTS
		end
		if isGame and lastPlayed then
			summary.gamesPlayed += 1
			summary.points += Progress.PLAYED_POINTS
		end
		if installed or game.got > 0 or lastPlayed then
			table.insert(summary.games, game)
		end
	end
	table.sort(summary.games, function(a, b)
		if a.got ~= b.got then
			return a.got > b.got
		end
		return (a.lastPlayed or 0) > (b.lastPlayed or 0)
	end)
	local level, info, nextAt = Progress.Tier(summary.points)
	summary.tier = level
	summary.tierName = info.name
	summary.tierAt = info.at
	summary.nextAt = nextAt
	return summary
end

return Progress
