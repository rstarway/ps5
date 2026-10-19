-- Манифест Rocket Ball: читается системой без запуска игры (плитка, магазин, трофеи, сервер).
return {
	id = "rocket_ball",
	title = "Rocket Ball",
	category = "game", -- game | media | app
	genre = "Sports",
	developer = "PS5 Sandbox",
	version = "1.0",
	order = 20,
	description = "Car football: jump, boost and smash the giant ball into the goal.",
	icon = "⚽",
	cover = "cover",
	art = "art", -- фон главного экрана (blender/game_art.py)
	colors = { "#00B4D8", "#03045E" },
	transparentGui = true, -- 3D-стадион виден сквозь интерфейс
	controls = {
		{ "R2 / Stick up / W", "Drive" },
		{ "L2 / Stick down / S", "Brake & reverse" },
		{ "Stick / A, D", "Steer" },
		{ "✕ / Space", "Jump, press again in the air to flip" },
		{ "□ / F", "Boost" },
		{ "△ / R", "Ball cam on/off" },
		{ "OPTIONS / O", "Pause" },
		{ "PS / H", "Control Center" },
	},
	trophies = {
		{ id = "first_goal", name = "Back of the Net", description = "Score your first goal", grade = "bronze" },
		{ id = "first_win", name = "Full Time", description = "Win a match", grade = "bronze" },
		{ id = "hat_trick", name = "Hat Trick", description = "Score 3 goals in one match", grade = "silver" },
		{ id = "sky_high", name = "Sky High", description = "Score with a touch made in the air", grade = "silver" },
		{ id = "clean_sheet", name = "Clean Sheet", description = "Win a match without conceding a goal", grade = "silver" },
		{ id = "overtime_hero", name = "Golden Goal", description = "Win a match in overtime", grade = "gold", hidden = true },
		{ id = "all_star", name = "All-Star", description = "Beat the All-Star bot", grade = "gold" },
		{ id = "platinum", name = "Rocket Legend", description = "Earn every Rocket Ball trophy", grade = "platinum" },
	},
}
