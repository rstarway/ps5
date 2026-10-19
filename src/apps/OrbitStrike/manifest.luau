-- Манифест читается системой без запуска игры (плитка, магазин, трофеи, сервер).
return {
	id = "orbit_strike",
	title = "Orbit Strike",
	category = "game", -- game | media | app
	genre = "Shooter",
	developer = "PS5 Sandbox",
	version = "1.0",
	order = 4,
	description = "Defend the space station from waves of drones in this twin-stick shooter.",
	icon = "🛰",
	cover = "cover",
	art = "art", -- фон главного экрана (blender/game_art.py)
	colors = { "#F8961E", "#5A1F00" },
	controls = {
		{ "Left stick / WASD / arrows", "Move" },
		{ "Right stick", "Aim and fire" },
		{ "✕ / R2 / Space", "Fire (auto-aims at the nearest drone)" },
		{ "L1 / Q", "Pulse bomb (charges as you destroy drones)" },
		{ "OPTIONS / O", "Pause" },
		{ "PS / H", "Control Center" },
	},
	trophies = {
		{ id = "first_kill", name = "Contact", description = "Destroy your first drone", grade = "bronze" },
		{ id = "wave_5", name = "Holding the Line", description = "Reach wave 5", grade = "bronze" },
		{ id = "pulse_5", name = "Shockwave", description = "Destroy 5 drones with a single pulse bomb", grade = "bronze" },
		{ id = "mothership", name = "Mothership Down", description = "Destroy a drone mothership", grade = "silver" },
		{ id = "flawless", name = "Not a Scratch", description = "Clear a wave from wave 3 on without the station taking damage", grade = "silver", hidden = true },
		{ id = "combo_20", name = "Chain Reaction", description = "Reach a x20 combo", grade = "silver" },
		{ id = "wave_10", name = "Station Guardian", description = "Reach wave 10", grade = "gold" },
		{ id = "score_10000", name = "Orbital Legend", description = "Score 10,000 points in one game", grade = "gold" },
		{ id = "platinum", name = "Master of Orbit", description = "Earn every Orbit Strike trophy", grade = "platinum" },
	},
}
