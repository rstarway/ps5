-- Манифест читается системой без запуска игры (плитка, магазин, трофеи, сервер).
return {
	id = "star_pilot",
	title = "Star Pilot",
	category = "game", -- game | media | app
	genre = "Arcade",
	developer = "PS5 Sandbox",
	version = "1.0",
	order = 1,
	preinstalled = true, -- стоит на консоли сразу, остальные игры скачиваются в PS Store
	description = "Sandbox sample game: blast asteroids and dodge them. Shows off input, saves, trophies and sound.",
	icon = "🚀", -- символ или "rbxassetid://..."
	art = "art", -- фон главного экрана (blender/game_art.py)
	cover = "cover", -- модуль cover.luau в этой папке (рендер из Blender) или "rbxassetid://..."
	colors = { "#FF6B35", "#2B0F54" },
	controls = {
		{ "Stick / arrows / WASD", "Move" },
		{ "✕ / Enter / Space", "Fire" },
		{ "OPTIONS / O", "Pause" },
		{ "PS / H", "Control Center" },
	},
	trophies = {
		{ id = "first_blood", name = "First Shot", description = "Destroy your first asteroid", grade = "bronze" },
		{ id = "score_100", name = "Pilot", description = "Score 100 points", grade = "bronze" },
		{ id = "score_500", name = "Ace", description = "Score 500 points", grade = "silver" },
		{ id = "untouchable", name = "Untouchable", description = "Score 200 points without losing a life", grade = "silver", hidden = true },
		{ id = "survivor", name = "Survivor", description = "Survive for 60 seconds", grade = "gold" },
		{ id = "platinum", name = "King of Space", description = "Earn every Star Pilot trophy", grade = "platinum" },
	},
}
