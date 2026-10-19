-- Манифест читается системой без запуска игры (плитка, магазин, трофеи, сервер).
return {
	id = "beat_rush",
	title = "Beat Rush",
	category = "game", -- game | media | app
	genre = "Rhythm",
	developer = "PS5 Sandbox",
	version = "1.0",
	order = 6,
	description = "Hit the notes to the beat and chase the perfect combo.",
	icon = "🎧",
	cover = "cover",
	art = "art", -- фон главного экрана (blender/game_art.py)
	colors = { "#B5179E", "#240046" },
	controls = {
		{ "← ↓ ↑ → / A S W D", "Hit lanes 1-4" },
		{ "□ ✕ △ ○", "Hit lanes 1-4 (gamepad)" },
		{ "↑ ↓ / ← →", "Pick a song / note speed" },
		{ "✕ / Enter", "Start song" },
		{ "OPTIONS / O", "Pause" },
		{ "PS / H", "Control Center" },
	},
	trophies = {
		{ id = "first_hit", name = "First Beat", description = "Hit your first note", grade = "bronze" },
		{ id = "clear_easy", name = "Warm Up", description = "Clear Neon Pulse", grade = "bronze" },
		{ id = "combo_50", name = "In the Zone", description = "Reach a 50 note combo", grade = "bronze" },
		{ id = "clear_normal", name = "Night Groove", description = "Clear Velvet Night", grade = "silver" },
		{ id = "combo_150", name = "Groove Machine", description = "Reach a 150 note combo", grade = "silver" },
		{ id = "clear_hard", name = "Full Bloom", description = "Clear Hyper Bloom", grade = "gold" },
		{ id = "rank_s", name = "Superstar", description = "Get an S rank on any song", grade = "gold" },
		{ id = "full_combo", name = "Perfect Flow", description = "Finish a song without missing a note", grade = "gold", hidden = true },
		{ id = "platinum", name = "Beat Master", description = "Earn every Beat Rush trophy", grade = "platinum" },
	},
}
