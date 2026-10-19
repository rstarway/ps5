-- Манифест читается системой без запуска игры (плитка, магазин, трофеи, сервер).
return {
	id = "game_2048",
	title = "2048",
	category = "game",
	genre = "Puzzle",
	developer = "PS5 Sandbox",
	version = "1.0",
	order = 12,
	description = "Slide the tiles, merge equal numbers and reach 2048.",
	icon = "🔢",
	cover = "",
	art = "",
	colors = { "#FFB703", "#5C3A00" },
	controls = {
		{ "Stick / D-pad / arrows / WASD", "Slide tiles" },
		{ "△ / R", "New game" },
		{ "○", "Quit" },
	},
	trophies = {
		{ id = "tile_128", name = "Warming Up", description = "Make a 128 tile", grade = "bronze" },
		{ id = "tile_512", name = "Getting There", description = "Make a 512 tile", grade = "silver" },
		{ id = "tile_2048", name = "2048!", description = "Make the 2048 tile", grade = "gold" },
		{ id = "platinum", name = "Number Master", description = "Earn every 2048 trophy", grade = "platinum" },
	},
}
