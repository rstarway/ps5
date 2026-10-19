-- Манифест Pixel Quest: читается системой без запуска игры (плитка, магазин, трофеи, сервер).
return {
	id = "pixel_quest",
	title = "Pixel Quest",
	category = "game",
	genre = "Platformer",
	developer = "PS5 Sandbox",
	version = "1.0",
	order = 3,
	description = "A cosy pixel platformer with coins, secrets and a boss at the end.",
	icon = "🍄",
	cover = "cover",
	art = "art", -- фон главного экрана (blender/game_art.py)
	colors = { "#43AA8B", "#0B3D2E" },
	controls = {
		{ "Stick / arrows / A D", "Move" },
		{ "✕ / Space / W / ↑", "Jump (hold to jump higher)" },
		{ "□ / F (hold)", "Run" },
		{ "OPTIONS / O", "Pause" },
		{ "PS / H", "Control Center" },
	},
	trophies = {
		{ id = "first_clear", name = "First Steps", description = "Clear Green Meadow", grade = "bronze" },
		{ id = "coins_100", name = "Pocket Money", description = "Collect 100 coins in total", grade = "bronze" },
		{ id = "stomp_30", name = "Slime Squasher", description = "Stomp 30 enemies", grade = "bronze" },
		{ id = "secret_gem", name = "Secret Keeper", description = "Find a hidden gem", grade = "silver", hidden = true },
		{ id = "no_damage", name = "Not a Scratch", description = "Clear a level without taking damage", grade = "silver" },
		{ id = "all_gems", name = "Treasure Hunter", description = "Find all three hidden gems", grade = "gold" },
		{ id = "boss", name = "Crown Breaker", description = "Defeat the Moss King", grade = "gold" },
		{ id = "platinum", name = "Pixel Legend", description = "Earn every Pixel Quest trophy", grade = "platinum" },
	},
}
