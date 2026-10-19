-- Манифест читается системой без запуска игры (плитка, магазин, трофеи, сервер).
return {
	id = "brick_break",
	title = "Brick Break",
	category = "game",
	genre = "Arcade",
	developer = "PS5 Sandbox",
	version = "1.0",
	order = 14,
	description = "Bounce the ball off your paddle and smash every brick on the wall.",
	icon = "🧱",
	cover = "",
	art = "",
	colors = { "#FB8500", "#3D1400" },
	controls = {
		{ "Stick / ←→ / A D", "Move paddle" },
		{ "✕ / Enter", "Launch ball" },
		{ "○", "Quit" },
	},
	trophies = {
		{ id = "first_brick", name = "Crack", description = "Break a brick", grade = "bronze" },
		{ id = "clear", name = "Wrecking Ball", description = "Clear a whole wall", grade = "silver" },
		{ id = "level_3", name = "Demolition Crew", description = "Reach wall 3", grade = "gold" },
		{ id = "platinum", name = "Brick Legend", description = "Earn every Brick Break trophy", grade = "platinum" },
	},
}
