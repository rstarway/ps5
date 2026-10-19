-- Манифест читается системой без запуска игры (плитка, магазин, трофеи, сервер).
return {
	id = "sky_hop",
	title = "Sky Hop",
	category = "game",
	genre = "Arcade",
	developer = "PS5 Sandbox",
	version = "1.0",
	order = 13,
	description = "Tap to flap and fly through the gaps between the pillars.",
	icon = "🐤",
	cover = "",
	art = "",
	colors = { "#8ECAE6", "#023047" },
	controls = {
		{ "✕ / Space / Enter / ↑", "Flap" },
		{ "○", "Quit" },
	},
	trophies = {
		{ id = "score_1", name = "Lift Off", description = "Pass your first pillar", grade = "bronze" },
		{ id = "score_10", name = "Frequent Flyer", description = "Pass 10 pillars in one flight", grade = "silver" },
		{ id = "score_30", name = "Sky Captain", description = "Pass 30 pillars in one flight", grade = "gold" },
		{ id = "platinum", name = "King of the Sky", description = "Earn every Sky Hop trophy", grade = "platinum" },
	},
}
