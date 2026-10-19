-- Манифест читается системой без запуска игры (плитка, магазин, трофеи, сервер).
return {
	id = "neon_drive",
	title = "Neon Drive",
	category = "game", -- game | media | app
	genre = "Racing",
	developer = "PS5 Sandbox",
	version = "1.0",
	order = 2,
	description = "Night racing through a neon city: drift, boost and beat the clock.",
	icon = "🏎",
	cover = "cover",
	art = "art", -- фон главного экрана (blender/game_art.py)
	colors = { "#FF3D7F", "#3A0CA3" },
	controls = {
		{ "✕ / R2 / W", "Accelerate" },
		{ "□ / L2 / S", "Brake / reverse" },
		{ "Stick / A, D", "Steer" },
		{ "○ / L1 / Backspace, Q", "Drift" },
		{ "△ / R1 / R, E", "Boost" },
		{ "OPTIONS / O", "Pause" },
		{ "PS / H", "Control Center" },
	},
	trophies = {
		{ id = "green_light", name = "Green Light", description = "Complete your first lap", grade = "bronze" },
		{ id = "sideways", name = "Sideways", description = "Hold a single drift for 3 seconds", grade = "bronze" },
		{ id = "pad_hopper", name = "Pad Hopper", description = "Hit every boost pad in a single lap", grade = "bronze" },
		{ id = "beat_clock", name = "Beat the Clock", description = "Finish a Clock Run", grade = "silver" },
		{ id = "drift_king", name = "Drift King", description = "Score 12,000 drift points in one Clock Run", grade = "silver" },
		{ id = "ghost_buster", name = "Ghost Buster", description = "Beat your own ghost in Time Trial", grade = "silver" },
		{ id = "clean_line", name = "Clean Line", description = "Complete a lap without touching a wall", grade = "silver", hidden = true },
		{ id = "neon_ace", name = "Neon Ace", description = "Set a lap time under 30 seconds", grade = "gold" },
		{ id = "platinum", name = "Neon Legend", description = "Earn every Neon Drive trophy", grade = "platinum" },
	},
}
