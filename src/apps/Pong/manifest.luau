-- Манифест читается системой без запуска игры (плитка, магазин, трофеи, сервер).
return {
	id = "pong",
	title = "Pong",
	category = "game",
	genre = "Classic",
	developer = "PS5 Sandbox",
	version = "1.0",
	order = 11,
	description = "Paddle duel against the computer. First to 7 points wins.",
	icon = "🏓",
	cover = "",
	art = "",
	colors = { "#F72585", "#1B0033" },
	controls = {
		{ "Stick / ↑↓ / W S", "Move paddle" },
		{ "✕ / Enter", "Serve / start again" },
		{ "○", "Quit" },
	},
	trophies = {
		{ id = "first_point", name = "On the Board", description = "Score a point", grade = "bronze" },
		{ id = "win", name = "Champion", description = "Win a match", grade = "silver" },
		{ id = "shutout", name = "Untouchable", description = "Win a match 7–0", grade = "gold" },
		{ id = "platinum", name = "Table Legend", description = "Earn every Pong trophy", grade = "platinum" },
	},
}
