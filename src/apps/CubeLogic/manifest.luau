-- Манифест читается системой без запуска игры (плитка, магазин, трофеи, сервер).
return {
	id = "cube_logic",
	title = "Cube Logic",
	category = "game", -- game | media | app
	genre = "Puzzle",
	developer = "PS5 Sandbox",
	version = "1.0",
	order = 4,
	description = "Roll the cube onto the exit in short brain teasers.",
	icon = "🧩",
	cover = "cover",
	art = "art", -- фон главного экрана (blender/game_art.py)
	colors = { "#4CC9F0", "#14213D" },
	transparentGui = true, -- 3D-поле видно сквозь интерфейс
	controls = {
		{ "Stick / D-pad / arrows / WASD", "Roll the cube" },
		{ "□ / F", "Undo move" },
		{ "△ / R", "Restart level" },
		{ "✕ / Enter", "Select" },
		{ "○ / Backspace", "Back to levels" },
		{ "OPTIONS / O", "Pause" },
		{ "PS / H", "Control Center" },
	},
	trophies = {
		{ id = "first_roll", name = "First Roll", description = "Clear the first level", grade = "bronze" },
		{ id = "perfect", name = "Perfect Path", description = "Clear a level in par moves", grade = "bronze" },
		{ id = "skater", name = "Skater", description = "Clear Thin Ice", grade = "bronze" },
		{ id = "off_edge", name = "Leap of Faith", description = "Roll off the edge into the void", grade = "bronze", hidden = true },
		{ id = "halfway", name = "Halfway There", description = "Clear 6 levels", grade = "silver" },
		{ id = "sure_footed", name = "Sure Footed", description = "Clear level 7 or later without falling or undoing", grade = "silver", hidden = true },
		{ id = "cube_master", name = "Cube Master", description = "Clear all 12 levels", grade = "gold" },
		{ id = "flawless", name = "Flawless Logic", description = "Clear every level in par moves", grade = "gold" },
		{ id = "platinum", name = "Grand Cube", description = "Earn every Cube Logic trophy", grade = "platinum" },
	},
}
