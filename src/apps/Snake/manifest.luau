-- Манифест читается системой без запуска игры (плитка, магазин, трофеи, сервер).
return {
	id = "snake",
	title = "Snake",
	category = "game",
	genre = "Classic",
	developer = "PS5 Sandbox",
	version = "1.0",
	order = 10,
	description = "The classic: eat apples, grow longer and don't bite your own tail.",
	icon = "🐍",
	cover = "",
	art = "",
	colors = { "#80ED99", "#0B3D20" },
	controls = {
		{ "D-pad / arrows / WASD", "Turn" },
		{ "✕ / Enter", "Start again" },
		{ "○", "Quit" },
	},
	trophies = {
		{ id = "first_apple", name = "Snack Time", description = "Eat your first apple", grade = "bronze" },
		{ id = "score_20", name = "Long Boi", description = "Eat 20 apples in one run", grade = "silver" },
		{ id = "score_50", name = "Anaconda", description = "Eat 50 apples in one run", grade = "gold" },
		{ id = "platinum", name = "Snake Charmer", description = "Earn every Snake trophy", grade = "platinum" },
	},
}
