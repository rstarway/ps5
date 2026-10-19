-- Beat Rush — ритм-игра на GUI: 4 дорожки, ноты падают к линии удара.
-- Музыку играет сама игра: бочка и хэт по долям, а каждая попавшая нота звучит нотой мелодии.
local Game = {}

local W, H = 1920, 1080
local LANES = 4
local LANE_W = 150
local HW_W = LANES * LANE_W
local HW_X = (W - HW_W) / 2
local HIT_Y = 880
local NOTE_W, NOTE_H = 124, 42

-- Окна попадания (секунды от идеального момента), очки, вклад в точность и в шкалу Groove
local JUDGES = {
	{ name = "PERFECT", window = 0.05, points = 300, acc = 1, groove = 0.03, color = "#FFFFFF" },
	{ name = "GREAT", window = 0.1, points = 200, acc = 0.7, groove = 0.015, color = "#7CFFB2" },
	{ name = "GOOD", window = 0.15, points = 100, acc = 0.4, groove = 0, color = "#4CC9F0" },
}
local MISS_WINDOW = JUDGES[#JUDGES].window
local MISS_GROOVE = -0.08

local LANE_COLORS = { "#4CC9F0", "#F72585", "#FFD166", "#7CFFB2" }
local LANE_ARROWS = { "←", "↓", "↑", "→" }
local LANE_KEYS = { "A", "S", "W", "D" }
local LANE_PAD = { "□", "✕", "△", "○" }
local LANE_OF = { left = 1, square = 1, down = 2, cross = 2, up = 3, triangle = 3, right = 4, circle = 4 }
local SPEEDS = { 520, 650, 780, 910, 1040, 1170, 1300 } -- скорость нот, пикс/с

-- Аккорды по тактам (полутона от тоники) и ноты дорожек внутри аккорда
local PROGRESSION = { 0, -4, -2, -5 }
local LANE_TONES = { 0, 3, 7, 12 }

-- Ритм такта: доли от 0 до 3.75
local PATTERNS = {
	easy = { { 0, 2 }, { 0, 1, 2, 3 }, { 0, 2, 3 }, { 0, 1, 2 }, { 1, 3 } },
	normal = { { 0, 1, 2, 3 }, { 0, 0.5, 1, 2, 3 }, { 0, 1, 1.5, 2, 3 }, { 0, 1, 2, 2.5, 3, 3.5 }, { 0, 0.5, 1.5, 2, 3 } },
	hard = {
		{ 0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5 }, { 0, 0.5, 1, 1.5, 2, 3, 3.25, 3.5 }, { 0, 0.75, 1.5, 2, 2.5, 3, 3.5 },
		{ 0, 0.25, 0.5, 1, 2, 2.25, 2.5, 3 }, { 0, 0.5, 1, 2, 2.5, 3, 3.5 },
	},
}

local SONGS = {
	{ id = "neon_pulse", title = "Neon Pulse", bpm = 96, level = "EASY", stars = 1, bars = 24, seed = 11, root = 0,
		patterns = "easy", chordEvery = 0, snare = false, trophy = "clear_easy", color = "#4CC9F0" },
	{ id = "velvet_night", title = "Velvet Night", bpm = 120, level = "NORMAL", stars = 3, bars = 30, seed = 27, root = -3,
		patterns = "normal", chordEvery = 4, snare = true, trophy = "clear_normal", color = "#F72585" },
	{ id = "hyper_bloom", title = "Hyper Bloom", bpm = 150, level = "HARD", stars = 5, bars = 40, seed = 53, root = 2,
		patterns = "hard", chordEvery = 2, snare = true, trophy = "clear_hard", color = "#FFD166" },
}
local ARTIST = "Beat Rush Crew"

local function laneX(lane)
	return HW_X + (lane - 0.5) * LANE_W
end

-- Нотная партия песни: детерминированная (одинаковая при каждом запуске)
local function buildChart(song)
	local rng = Random.new(song.seed)
	local patterns = PATTERNS[song.patterns]
	local beatLen = 60 / song.bpm
	local notes = {}
	local lastLane, lastBeat = 0, -10
	local function add(beat, lane, bar)
		local semis = song.root + PROGRESSION[bar % #PROGRESSION + 1] + LANE_TONES[lane]
		table.insert(notes, { time = beat * beatLen, beat = beat, lane = lane, pitch = math.clamp(2 ^ (semis / 12), 0.5, 2.2) })
	end
	for bar = 1, song.bars - 2 do
		local pattern
		if bar % 8 == 0 then
			pattern = PATTERNS.easy[1] -- передышка
		else
			pattern = patterns[rng:NextInteger(1, #patterns)]
		end
		for _, offset in pattern do
			local beat = bar * 4 + offset
			local lane = rng:NextInteger(1, LANES)
			if lane == lastLane and beat - lastBeat < 0.75 then
				lane = lane % LANES + 1
			end
			add(beat, lane, bar)
			if offset == 0 and song.chordEvery > 0 and bar % song.chordEvery == 0 then
				add(beat, (lane + 1) % LANES + 1, bar)
			end
			lastLane, lastBeat = lane, beat
		end
	end
	-- финальный аккорд
	local last = song.bars - 1
	add(last * 4, 1, last)
	add(last * 4, 4, last)
	table.sort(notes, function(a, b)
		return a.time < b.time
	end)
	return notes
end

local function rankOf(acc, failed)
	if failed then
		return "F"
	elseif acc >= 0.95 then
		return "S"
	elseif acc >= 0.88 then
		return "A"
	elseif acc >= 0.76 then
		return "B"
	elseif acc >= 0.6 then
		return "C"
	end
	return "D"
end

local RANK_COLORS = { S = "#FFD166", A = "#7CFFB2", B = "#4CC9F0", C = "#F72585", D = "#B8B8D0", F = "#FF4D6D" }

function Game.launch(ctx)
	local ui = ctx.ui
	local hex = ui.hex
	local theme = ctx.theme

	-- Фон на весь экран + вспышка на долю
	ctx.gui.BackgroundColor3 = hex("#240046")
	ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = ctx.gui },
		{ ui.gradient({ hex("#B5179E"), hex("#5A189A"), hex("#240046") }, 90) })
	local flash = ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = ctx.gui })

	local canvas = ui.canvas(ctx.gui, W, H)
	canvas.ClipsDescendants = true

	-- Декор: эквалайзер внизу и вращающиеся рамки
	local EQ_COUNT = 40
	local eqBars = {}
	for i = 1, EQ_COUNT do
		local bar = ui.new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromOffset((i - 1) * 48 + 6, H),
			Size = UDim2.fromOffset(36, 40),
			BackgroundColor3 = hex(LANE_COLORS[(i - 1) % LANES + 1]),
			BackgroundTransparency = 0.78,
			BorderSizePixel = 0,
			Parent = canvas,
		}, { ui.corner(8) })
		table.insert(eqBars, { frame = bar, h = 40, target = 40 })
	end
	local rings = {}
	for i, spec in { { 330, 540, 300 }, { 1590, 540, 300 }, { 330, 540, 200 }, { 1590, 540, 200 } } do
		local ring = ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(spec[1], spec[2]),
			Size = UDim2.fromOffset(spec[3], spec[3]),
			Rotation = i * 20,
			BackgroundTransparency = 1,
			Parent = canvas,
		}, { ui.corner(spec[3] * 0.18), ui.stroke(hex(LANE_COLORS[i]), 3, 0.75) })
		table.insert(rings, { frame = ring, speed = (i % 2 == 0 and -1 or 1) * (12 + i * 4), size = spec[3] })
	end

	local function layer(z)
		return ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = z, Parent = canvas })
	end
	local menuLayer, playLayer, resultsLayer, pauseLayer = layer(2), layer(2), layer(3), layer(10)

	------------------------------------------------------------------ меню
	local logo = ui.text("BEAT RUSH", {
		Position = UDim2.fromOffset(120, 70), Size = UDim2.fromOffset(1000, 140), TextSize = 128, Font = theme.FontHeavy,
		TextColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = menuLayer,
	}, nil)
	ui.gradient({ hex("#FFFFFF"), hex("#FFB3E6"), hex("#4CC9F0") }, 0).Parent = logo
	ui.text("Choose a track and hit the notes on the beat.", {
		Position = UDim2.fromOffset(126, 210), Size = UDim2.fromOffset(1000, 40), TextSize = 32, TextTransparency = 0.25, ZIndex = 2, Parent = menuLayer,
	})

	local cards = {}
	for i, song in SONGS do
		local card = ui.new("Frame", {
			Position = UDim2.fromOffset(120, 300 + (i - 1) * 175),
			Size = UDim2.fromOffset(780, 150),
			BackgroundColor3 = hex("#12002A"),
			BackgroundTransparency = 0.45,
			ZIndex = 2,
			Parent = menuLayer,
		}, { ui.corner(22) })
		local stroke = ui.stroke(hex(song.color), 2, 0.6)
		stroke.Parent = card
		ui.new("Frame", { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 12, 1, 0), BackgroundColor3 = hex(song.color), BorderSizePixel = 0, ZIndex = 3, Parent = card }, { ui.corner(6) })
		ui.text(song.title, { Position = UDim2.fromOffset(44, 22), Size = UDim2.fromOffset(500, 56), TextSize = 50, Font = theme.FontBold, ZIndex = 3, Parent = card })
		ui.text(`{ARTIST}  ·  {song.bpm} BPM`, { Position = UDim2.fromOffset(46, 86), Size = UDim2.fromOffset(500, 34), TextSize = 28, TextTransparency = 0.3, ZIndex = 3, Parent = card })
		ui.text(song.level, {
			Position = UDim2.fromOffset(540, 26), Size = UDim2.fromOffset(210, 44), TextSize = 34, Font = theme.FontBold,
			TextColor3 = hex(song.color), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3, Parent = card,
		})
		ui.text(string.rep("★", song.stars) .. string.rep("☆", 5 - song.stars), {
			Position = UDim2.fromOffset(540, 80), Size = UDim2.fromOffset(210, 40), TextSize = 30,
			TextColor3 = hex(song.color), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3, Parent = card,
		})
		table.insert(cards, { frame = card, stroke = stroke })
	end

	local detail = ui.new("Frame", {
		Position = UDim2.fromOffset(1000, 300), Size = UDim2.fromOffset(800, 500), BackgroundColor3 = hex("#12002A"),
		BackgroundTransparency = 0.4, ZIndex = 2, Parent = menuLayer,
	}, { ui.corner(28), ui.stroke(Color3.new(1, 1, 1), 1, 0.85) })
	local detailTitle = ui.text("", { Position = UDim2.fromOffset(48, 36), Size = UDim2.fromOffset(700, 60), TextSize = 54, Font = theme.FontHeavy, ZIndex = 3, Parent = detail })
	local detailInfo = ui.text("", { Position = UDim2.fromOffset(50, 100), Size = UDim2.fromOffset(700, 36), TextSize = 28, TextTransparency = 0.3, ZIndex = 3, Parent = detail })
	local detailRank = ui.text("", {
		Position = UDim2.fromOffset(500, 150), Size = UDim2.fromOffset(250, 250), TextSize = 220, Font = theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Parent = detail,
	})
	local detailStats = ui.text("", {
		Position = UDim2.fromOffset(50, 170), Size = UDim2.fromOffset(450, 260), TextSize = 34, TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.25, ZIndex = 3, Parent = detail,
	})
	local speedLabel = ui.text("", {
		Position = UDim2.fromOffset(50, 430), Size = UDim2.fromOffset(700, 40), TextSize = 32, Font = theme.FontBold, ZIndex = 3, Parent = detail,
	})
	local menuHint = ui.text("", {
		Position = UDim2.fromOffset(0, 950), Size = UDim2.fromOffset(W, 40), TextSize = 30, TextTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2, Parent = menuLayer,
	})

	------------------------------------------------------------------ игра
	local highway = ui.new("Frame", {
		Position = UDim2.fromOffset(HW_X, 0), Size = UDim2.fromOffset(HW_W, H), BackgroundColor3 = hex("#07000F"),
		BackgroundTransparency = 0.35, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 2, Parent = playLayer,
	}, { ui.stroke(hex("#B5179E"), 3, 0.3) })
	local laneTints = {}
	for lane = 1, LANES do
		local tint = ui.new("Frame", {
			Position = UDim2.fromOffset((lane - 1) * LANE_W, 0), Size = UDim2.fromOffset(LANE_W, H),
			BackgroundColor3 = hex(LANE_COLORS[lane]), BackgroundTransparency = 0.95, BorderSizePixel = 0, ZIndex = 2, Parent = highway,
		}, { ui.gradient({ Color3.new(1, 1, 1), Color3.new(1, 1, 1) }, 90, NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })) })
		table.insert(laneTints, tint)
		if lane > 1 then
			ui.new("Frame", {
				Position = UDim2.fromOffset((lane - 1) * LANE_W - 1, 0), Size = UDim2.fromOffset(2, H),
				BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.85, BorderSizePixel = 0, ZIndex = 3, Parent = highway,
			})
		end
	end
	ui.new("Frame", {
		Position = UDim2.fromOffset(0, HIT_Y - 2), Size = UDim2.fromOffset(HW_W, 4),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 4, Parent = highway,
	})
	local receptors, laneHints = {}, {}
	for lane = 1, LANES do
		local r = ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((lane - 0.5) * LANE_W, HIT_Y),
			Size = UDim2.fromOffset(NOTE_W, NOTE_H + 8), BackgroundColor3 = hex(LANE_COLORS[lane]), BackgroundTransparency = 0.85, ZIndex = 5, Parent = highway,
		}, { ui.corner(12), ui.stroke(hex(LANE_COLORS[lane]), 3, 0) })
		local scale = ui.new("UIScale", { Parent = r })
		ui.text(LANE_ARROWS[lane], {
			Size = UDim2.fromScale(1, 1), TextSize = 36, Font = theme.FontBold, TextColor3 = hex(LANE_COLORS[lane]),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = r,
		})
		table.insert(receptors, { frame = r, scale = scale, glow = 0 })
		table.insert(laneHints, ui.text("", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(laneX(lane), HIT_Y + 50), Size = UDim2.fromOffset(LANE_W, 40),
			TextSize = 30, Font = theme.FontBold, TextTransparency = 0.35, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = playLayer,
		}))
	end
	local noteLayer = ui.new("Frame", { Name = "BeatRushNotes", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 7, Parent = highway })

	local progressBack = ui.new("Frame", {
		Position = UDim2.fromOffset(HW_X, 18), Size = UDim2.fromOffset(HW_W, 8), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 8, Parent = playLayer,
	}, { ui.corner(4) })
	local progressFill = ui.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = hex("#F72585"), BorderSizePixel = 0, ZIndex = 9, Parent = progressBack }, { ui.corner(4) })

	local comboText = ui.text("", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, 380), Size = UDim2.fromOffset(HW_W, 130),
		TextSize = 120, Font = theme.FontHeavy, TextTransparency = 0.15, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8, Parent = playLayer,
	})
	local comboScale = ui.new("UIScale", { Parent = comboText })
	local comboLabel = ui.text("COMBO", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, 460), Size = UDim2.fromOffset(HW_W, 40),
		TextSize = 32, Font = theme.FontBold, TextTransparency = 0.4, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8, Parent = playLayer,
	})
	local judgeText = ui.text("", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, 640), Size = UDim2.fromOffset(HW_W, 90),
		TextSize = 72, Font = theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8, Parent = playLayer,
	})
	local judgeScale = ui.new("UIScale", { Parent = judgeText })
	local countdownText = ui.text("", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, 420), Size = UDim2.fromOffset(HW_W, 220),
		TextSize = 200, Font = theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9, Parent = playLayer,
	})
	local countdownScale = ui.new("UIScale", { Parent = countdownText })

	local songTitle = ui.text("", { Position = UDim2.fromOffset(80, 80), Size = UDim2.fromOffset(500, 60), TextSize = 52, Font = theme.FontHeavy, ZIndex = 8, Parent = playLayer })
	local songInfo = ui.text("", { Position = UDim2.fromOffset(82, 146), Size = UDim2.fromOffset(500, 70), TextSize = 28, TextTransparency = 0.3, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 8, Parent = playLayer })
	local countsText = ui.text("", {
		Position = UDim2.fromOffset(82, 640), Size = UDim2.fromOffset(460, 220), TextSize = 30, LineHeight = 1.25,
		TextYAlignment = Enum.TextYAlignment.Top, TextTransparency = 0.2, ZIndex = 8, Parent = playLayer,
	})

	local RIGHT_X = HW_X + HW_W + 110
	ui.text("SCORE", { Position = UDim2.fromOffset(RIGHT_X, 80), Size = UDim2.fromOffset(500, 34), TextSize = 28, Font = theme.FontBold, TextTransparency = 0.4, ZIndex = 8, Parent = playLayer })
	local scoreText = ui.text("0", { Position = UDim2.fromOffset(RIGHT_X, 112), Size = UDim2.fromOffset(500, 84), TextSize = 80, Font = theme.FontHeavy, ZIndex = 8, Parent = playLayer })
	local accText = ui.text("", { Position = UDim2.fromOffset(RIGHT_X, 206), Size = UDim2.fromOffset(500, 40), TextSize = 34, Font = theme.FontBold, ZIndex = 8, Parent = playLayer })
	local multText = ui.text("", { Position = UDim2.fromOffset(RIGHT_X, 252), Size = UDim2.fromOffset(500, 40), TextSize = 34, Font = theme.FontBold, TextColor3 = hex("#FFD166"), ZIndex = 8, Parent = playLayer })

	ui.text("GROOVE", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(HW_X + HW_W + 40, 186), Size = UDim2.fromOffset(120, 30),
		TextSize = 22, Font = theme.FontBold, TextTransparency = 0.4, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8, Parent = playLayer,
	})
	local grooveBack = ui.new("Frame", {
		Position = UDim2.fromOffset(HW_X + HW_W + 28, 220), Size = UDim2.fromOffset(24, 640), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.82, ZIndex = 8, Parent = playLayer,
	}, { ui.corner(12) })
	local grooveFill = ui.new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.5), BackgroundColor3 = hex("#7CFFB2"),
		BorderSizePixel = 0, ZIndex = 9, Parent = grooveBack,
	}, { ui.corner(12) })

	------------------------------------------------------------------ итоги и пауза
	local panel = ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, 500), Size = UDim2.fromOffset(1200, 720),
		BackgroundColor3 = hex("#12002A"), BackgroundTransparency = 0.25, ZIndex = 3, Parent = resultsLayer,
	}, { ui.corner(32), ui.stroke(hex("#B5179E"), 3, 0.2) })
	local panelScale = ui.new("UIScale", { Parent = panel })
	local resTitle = ui.text("", { Position = UDim2.fromOffset(60, 40), Size = UDim2.fromOffset(1080, 70), TextSize = 64, Font = theme.FontHeavy, ZIndex = 4, Parent = panel })
	local resSong = ui.text("", { Position = UDim2.fromOffset(62, 112), Size = UDim2.fromOffset(1080, 40), TextSize = 32, TextTransparency = 0.3, ZIndex = 4, Parent = panel })
	local resRank = ui.text("", {
		Position = UDim2.fromOffset(40, 170), Size = UDim2.fromOffset(420, 420), TextSize = 360, Font = theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = panel,
	})
	local resStats = ui.text("", {
		Position = UDim2.fromOffset(520, 190), Size = UDim2.fromOffset(640, 400), TextSize = 38, LineHeight = 1.25,
		TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 4, Parent = panel,
	})
	local resBadge = ui.text("", {
		Position = UDim2.fromOffset(60, 600), Size = UDim2.fromOffset(1080, 50), TextSize = 40, Font = theme.FontHeavy,
		TextColor3 = hex("#FFD166"), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = panel,
	})
	local resHint = ui.text("", {
		Position = UDim2.fromOffset(0, 920), Size = UDim2.fromOffset(W, 40), TextSize = 30, TextTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Parent = resultsLayer,
	})

	ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 10, Parent = pauseLayer })
	local pauseText = ui.text("", {
		Size = UDim2.fromOffset(W, 500), Position = UDim2.fromOffset(0, 290), TextSize = 46, Font = theme.FontBold, LineHeight = 1.3,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11, Parent = pauseLayer,
	})

	------------------------------------------------------------------ состояние
	local state = "menu" -- menu | play | paused | results
	local selected = 1
	local speedIndex = math.clamp(ctx.save:Get("speed", 4), 1, #SPEEDS)
	local records = ctx.save:Get("records", {})
	if type(records) ~= "table" then
		records = {}
	end

	local song, chart, beatLen, songEnd
	local songTime, frameClock = 0, os.clock()
	local nextSpawn, active = 1, {}
	local lastHalfBeat = -100
	local score, combo, maxCombo, judged, accSum, groove, failed
	local counts = {}
	local judgeTimer = 0
	local pulse, menuClock = 0, 0
	local effects = {}
	local pauseIndex = 1
	local PAUSE_MENU = { "Resume", "Restart", "Song Select", "Quit to PS5 Menu" }

	local function setLayer(name)
		menuLayer.Visible = name == "menu"
		playLayer.Visible = name == "play"
		resultsLayer.Visible = name == "results"
	end

	local function glyph(btn)
		return ctx.input:Glyph(btn)
	end

	local function renderMenu()
		for i, card in cards do
			local on = i == selected
			card.stroke.Thickness = on and 4 or 2
			card.stroke.Transparency = on and 0 or 0.6
			card.frame.BackgroundTransparency = on and 0.15 or 0.45
			ui.tween(card.frame, 0.25, { Position = UDim2.fromOffset(on and 150 or 120, 300 + (i - 1) * 175) })
		end
		local s = SONGS[selected]
		local rec = records[s.id]
		local noteCount = #buildChart(s)
		detailTitle.Text = s.title
		detailTitle.TextColor3 = hex(s.color)
		detailInfo.Text = `{s.level}  ·  {s.bpm} BPM  ·  {noteCount} notes  ·  {math.floor(s.bars * 4 * 60 / s.bpm)} s`
		if rec then
			detailStats.Text = `Best score: {rec.score}\nBest accuracy: {string.format("%.1f", (rec.acc or 0) * 100)}%\nMax combo: {rec.combo}\nPlays: {rec.plays or 0}{rec.fc and "\nFULL COMBO" or ""}`
			detailRank.Text = rec.rank or ""
			detailRank.TextColor3 = hex(RANK_COLORS[rec.rank] or "#FFFFFF")
		else
			detailStats.Text = "Not played yet.\nClear the track to set\nyour first record."
			detailRank.Text = ""
		end
		speedLabel.Text = `Note speed   ◀  {speedIndex}  ▶`
		menuHint.Text = `↑ ↓  Track      ← →  Note speed      {glyph("cross")}  Play      {glyph("circle")}  Quit`
	end

	local function clearNotes()
		for _, n in active do
			if n.frame then
				n.frame:Destroy()
			end
		end
		table.clear(active)
	end

	local function showMenu()
		clearNotes()
		state = "menu"
		pauseLayer.Visible = false
		setLayer("menu")
		renderMenu()
	end

	local function updateHud()
		scoreText.Text = tostring(score)
		local acc = judged > 0 and accSum / judged or 1
		accText.Text = `{string.format("%.1f", acc * 100)}%`
		local mult = 1 + math.min(3, combo // 30)
		multText.Text = mult > 1 and `x{mult} MULTIPLIER` or ""
		comboText.Text = combo >= 3 and tostring(combo) or ""
		comboLabel.Visible = combo >= 3
		grooveFill.Size = UDim2.fromScale(1, math.clamp(groove, 0, 1))
		grooveFill.BackgroundColor3 = hex(groove < 0.25 and "#FF4D6D" or groove < 0.5 and "#FFD166" or "#7CFFB2")
		countsText.Text = `PERFECT  {counts.PERFECT}\nGREAT  {counts.GREAT}\nGOOD  {counts.GOOD}\nMISS  {counts.MISS}`
	end

	local function startSong(index)
		clearNotes()
		song = SONGS[index]
		chart = buildChart(song)
		beatLen = 60 / song.bpm
		songEnd = song.bars * 4 * beatLen
		songTime = -4 * beatLen - 0.4
		lastHalfBeat = math.floor(songTime / (beatLen / 2))
		nextSpawn = 1
		score, combo, maxCombo, judged, accSum, groove, failed = 0, 0, 0, 0, 0, 0.5, false
		counts = { PERFECT = 0, GREAT = 0, GOOD = 0, MISS = 0 }
		judgeText.Text, countdownText.Text = "", ""
		songTitle.Text = song.title
		songTitle.TextColor3 = hex(song.color)
		songInfo.Text = `{ARTIST}\n{song.level}  ·  {song.bpm} BPM`
		local gamepad = ctx.input:Device() == "gamepad"
		for lane = 1, LANES do
			laneHints[lane].Text = gamepad and LANE_PAD[lane] or LANE_KEYS[lane]
		end
		progressFill.BackgroundColor3 = hex(song.color)
		progressFill.Size = UDim2.fromScale(0, 1)
		state = "play"
		pauseLayer.Visible = false
		setLayer("play")
		updateHud()
	end

	local function finish()
		state = "results"
		clearNotes()
		setLayer("results")
		local acc = judged > 0 and accSum / judged or 0
		local rank = rankOf(acc, failed)
		local fullCombo = not failed and counts.MISS == 0 and judged == #chart
		local rec = table.clone(records[song.id] or { score = 0, combo = 0, acc = 0, plays = 0 })
		local newBest = not failed and score > (rec.score or 0)
		rec.plays = (rec.plays or 0) + 1
		if newBest then
			rec.score, rec.rank, rec.acc = score, rank, acc
		end
		rec.combo = math.max(rec.combo or 0, maxCombo)
		rec.fc = rec.fc or fullCombo
		records = table.clone(records)
		records[song.id] = rec
		ctx.save:Set("records", records)
		ctx.save:Set("plays", ctx.save:Get("plays", 0) + 1)

		if not failed then
			ctx.trophies:Unlock(song.trophy)
			if rank == "S" then
				ctx.trophies:Unlock("rank_s")
			end
			if fullCombo then
				ctx.trophies:Unlock("full_combo")
			end
			ctx.audio:Play("trophy", { volume = 0.5 })
		else
			ctx.audio:Play("error", { volume = 0.6, pitch = 0.7 })
			ctx.input:Rumble(0.7, 0.4)
		end

		resTitle.Text = failed and "TRACK FAILED" or fullCombo and "FULL COMBO!" or "TRACK CLEAR"
		resTitle.TextColor3 = hex(failed and "#FF4D6D" or "#FFFFFF")
		resSong.Text = `{song.title}  ·  {song.level}`
		resRank.Text = rank
		resRank.TextColor3 = hex(RANK_COLORS[rank])
		resStats.Text = `Score  {score}\nAccuracy  {string.format("%.1f", acc * 100)}%\nMax combo  {maxCombo}\n\nPERFECT {counts.PERFECT}   GREAT {counts.GREAT}\nGOOD {counts.GOOD}   MISS {counts.MISS}`
		resBadge.Text = newBest and "NEW BEST SCORE!" or (failed and "Keep the groove bar up to finish the track." or "")
		resHint.Text = `{glyph("cross")}  Song select      {glyph("triangle")}  Retry      {glyph("circle")}  Quit`
		panelScale.Scale = 0.85
		ui.tween(panelScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	end

	local function spawnEffect(lane, color)
		local f = ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((lane - 0.5) * LANE_W, HIT_Y),
			Size = UDim2.fromOffset(NOTE_W, NOTE_H), BackgroundColor3 = color, BackgroundTransparency = 0.2, ZIndex = 8, Parent = highway,
		}, { ui.corner(14) })
		table.insert(effects, { frame = f, life = 0, duration = 0.3 })
	end

	local function showJudge(name, color)
		judgeText.Text = name
		judgeText.TextColor3 = color
		judgeText.TextTransparency = 0
		judgeScale.Scale = 1.35
		judgeTimer = 0.6
	end

	local function judge(note, j)
		note.judged = true
		if note.frame then
			note.frame:Destroy()
			note.frame = nil
		end
		judged += 1
		accSum += j.acc
		counts[j.name] += 1
		combo += 1
		maxCombo = math.max(maxCombo, combo)
		local mult = 1 + math.min(3, combo // 30)
		score += j.points * mult
		groove = math.min(1, groove + j.groove)
		ctx.audio:Play("confirm", { volume = 0.35, pitch = note.pitch })
		spawnEffect(note.lane, hex(LANE_COLORS[note.lane]))
		showJudge(j.name, hex(j.color))
		comboScale.Scale = 1.15
		ctx.trophies:Unlock("first_hit")
		if combo >= 50 then
			ctx.trophies:Unlock("combo_50")
		end
		if combo >= 150 then
			ctx.trophies:Unlock("combo_150")
		end
		updateHud()
	end

	local function miss(note)
		note.judged = true
		if note.frame then
			note.frame:Destroy()
			note.frame = nil
		end
		judged += 1
		counts.MISS += 1
		combo = 0
		groove += MISS_GROOVE
		showJudge("MISS", hex("#FF4D6D"))
		ctx.input:Rumble(0.4, 0.12)
		updateHud()
		if groove <= 0 then
			failed = true
			finish()
		end
	end

	local function currentTime()
		return songTime + math.clamp(os.clock() - frameClock, 0, 1 / 30)
	end

	local function hitLane(lane)
		local rec = receptors[lane]
		rec.glow = 1
		laneTints[lane].BackgroundTransparency = 0.75
		local t = currentTime()
		local best, bestDiff
		for _, n in active do
			if not n.judged and n.lane == lane then
				local diff = math.abs(n.time - t)
				if diff <= MISS_WINDOW and (not best or n.time < best.time) then
					best, bestDiff = n, diff
				end
			end
		end
		if not best then
			return
		end
		for _, j in JUDGES do
			if bestDiff <= j.window then
				judge(best, j)
				return
			end
		end
	end

	local function drawPause()
		local lines = { "PAUSED", "" }
		for i, item in PAUSE_MENU do
			table.insert(lines, (i == pauseIndex and "▶  " or "    ") .. item)
		end
		pauseText.Text = table.concat(lines, "\n")
	end

	local function pause()
		if state == "play" then
			state, pauseIndex = "paused", 1
			pauseLayer.Visible = true
			drawPause()
		end
	end

	local function resume()
		state = "play"
		pauseLayer.Visible = false
		frameClock = os.clock()
	end

	ctx.input:On("press", function(btn)
		if ctx.paused then
			return
		end
		if state == "play" then
			if btn == "options" then
				pause()
			elseif LANE_OF[btn] then
				hitLane(LANE_OF[btn])
			end
		elseif state == "menu" then
			if btn == "up" or btn == "down" then
				selected = (selected - 1 + (btn == "down" and 1 or -1)) % #SONGS + 1
				ctx.audio:Play("move", { volume = 0.3 })
				renderMenu()
			elseif btn == "left" or btn == "right" then
				speedIndex = math.clamp(speedIndex + (btn == "right" and 1 or -1), 1, #SPEEDS)
				ctx.save:Set("speed", speedIndex)
				ctx.audio:Play("move", { volume = 0.3, pitch = 1.3 })
				renderMenu()
			elseif btn == "cross" then
				ctx.audio:Play("confirm", { volume = 0.5 })
				startSong(selected)
			elseif btn == "circle" then
				ctx:Exit()
			end
		elseif state == "paused" then
			if btn == "up" or btn == "down" then
				pauseIndex = (pauseIndex - 1 + (btn == "down" and 1 or -1)) % #PAUSE_MENU + 1
				ctx.audio:Play("move", { volume = 0.3, pitch = 1.6 })
				drawPause()
			elseif btn == "circle" or btn == "options" then
				resume()
			elseif btn == "cross" then
				if pauseIndex == 1 then
					resume()
				elseif pauseIndex == 2 then
					startSong(selected)
				elseif pauseIndex == 3 then
					showMenu()
				else
					ctx:Exit()
				end
			end
		elseif state == "results" then
			if btn == "cross" then
				ctx.audio:Play("back", { volume = 0.4 })
				showMenu()
			elseif btn == "triangle" then
				startSong(selected)
			elseif btn == "circle" then
				ctx:Exit()
			end
		end
	end)

	-- Пауза системы (кнопка PS): ctx:Loop останавливается сам, здесь ставим и игровое меню.
	ctx:On("pause", pause)

	-- Барабаны: бочка на каждую долю, хэт на слабые, хлопок на 2 и 4; до начала — отсчёт
	local COUNTDOWN = { [-4] = "3", [-3] = "2", [-2] = "1", [-1] = "GO!" }
	local function onHalfBeat(half)
		local beat = half / 2
		local whole = half % 2 == 0
		if beat < 0 then
			if whole then
				countdownText.Text = COUNTDOWN[beat] or ""
				countdownScale.Scale = 1.4
				ctx.audio:Play("move", { volume = 0.45, pitch = beat == -1 and 2 or 1.4 })
				pulse = 0.6
			end
			return
		end
		if beat >= song.bars * 4 then
			return
		end
		if beat == 0 then
			countdownText.Text = ""
		end
		if whole then
			ctx.audio:Play("hit", { volume = 0.32, pitch = 0.5 })
			if song.snare and beat % 2 == 1 then
				ctx.audio:Play("shoot", { volume = 0.12, pitch = 1.3 })
			end
			pulse = beat % 4 == 0 and 1 or 0.65
		else
			ctx.audio:Play("move", { volume = 0.1, pitch = 2.4 })
		end
	end

	local function spawnNote(n)
		local color = hex(LANE_COLORS[n.lane])
		n.frame = ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((n.lane - 0.5) * LANE_W, -NOTE_H),
			Size = UDim2.fromOffset(NOTE_W, NOTE_H), BackgroundColor3 = color, ZIndex = 7, Parent = noteLayer,
		}, {
			ui.corner(12),
			ui.stroke(Color3.new(1, 1, 1), 2, 0.35),
			ui.text(LANE_ARROWS[n.lane], {
				Size = UDim2.fromScale(1, 1), TextSize = 30, Font = theme.FontBold, TextColor3 = hex("#240046"),
				TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8,
			}),
		})
		table.insert(active, n)
	end

	local function beatPulse(beatPos)
		local whole = math.floor(beatPos)
		if whole ~= menuClock then
			menuClock = whole
			pulse = 0.5
		end
	end

	ctx:Loop(function(dt)
		frameClock = os.clock()

		-- декор (работает во всех состояниях)
		if state == "menu" then
			beatPulse(os.clock() * SONGS[selected].bpm / 60)
		end
		local hasBeat = pulse > 0.45
		pulse = math.max(0, pulse - dt * 3)
		flash.BackgroundTransparency = 1 - pulse * 0.1
		for i, b in eqBars do
			if hasBeat and pulse > 0.4 and math.random() < 0.5 then
				b.target = 60 + math.random() * 220 * pulse
			end
			b.target = math.max(30, b.target - dt * 260)
			b.h += (b.target - b.h) * math.min(1, dt * 14)
			b.frame.Size = UDim2.fromOffset(36, b.h)
			b.frame.BackgroundTransparency = 0.8 - pulse * 0.2 + (i % 2) * 0.05
		end
		for _, r in rings do
			r.frame.Rotation = (r.frame.Rotation + r.speed * dt) % 360
			local s = r.size * (1 + pulse * 0.06)
			r.frame.Size = UDim2.fromOffset(s, s)
		end
		for i = #effects, 1, -1 do
			local e = effects[i]
			e.life += dt
			local k = e.life / e.duration
			if k >= 1 then
				e.frame:Destroy()
				table.remove(effects, i)
			else
				e.frame.Size = UDim2.fromOffset(NOTE_W * (1 + k * 0.6), NOTE_H * (1 + k * 1.4))
				e.frame.BackgroundTransparency = 0.2 + k * 0.8
			end
		end
		if judgeTimer > 0 then
			judgeTimer -= dt
			judgeScale.Scale += (1 - judgeScale.Scale) * math.min(1, dt * 16)
			judgeText.TextTransparency = judgeTimer < 0.2 and 1 - judgeTimer / 0.2 or 0
		end
		comboScale.Scale += (1 - comboScale.Scale) * math.min(1, dt * 12)
		countdownScale.Scale += (1 - countdownScale.Scale) * math.min(1, dt * 10)
		for lane, rec in receptors do
			rec.glow = math.max(0, rec.glow - dt * 6)
			rec.scale.Scale = 1 + rec.glow * 0.12 + pulse * 0.04
			rec.frame.BackgroundTransparency = 0.85 - rec.glow * 0.6
			local tint = laneTints[lane]
			tint.BackgroundTransparency = math.min(0.95, tint.BackgroundTransparency + dt * 1.2)
		end

		if state ~= "play" then
			return
		end

		songTime += dt
		local half = math.floor(songTime / (beatLen / 2))
		while lastHalfBeat < half do
			lastHalfBeat += 1
			onHalfBeat(lastHalfBeat)
		end

		local speed = SPEEDS[speedIndex]
		local lead = (HIT_Y + NOTE_H) / speed
		while nextSpawn <= #chart and chart[nextSpawn].time - songTime <= lead do
			spawnNote(chart[nextSpawn])
			nextSpawn += 1
		end

		for i = #active, 1, -1 do
			local n = active[i]
			if n.judged then
				table.remove(active, i)
			elseif songTime - n.time > MISS_WINDOW then
				table.remove(active, i)
				miss(n)
				if state ~= "play" then
					return
				end
			else
				n.frame.Position = UDim2.fromOffset((n.lane - 0.5) * LANE_W, HIT_Y - (n.time - songTime) * speed)
			end
		end

		progressFill.Size = UDim2.fromScale(math.clamp(songTime / songEnd, 0, 1), 1)
		if songTime >= songEnd + 0.8 and nextSpawn > #chart and #active == 0 then
			finish()
		end
	end)

	showMenu()
end

return Game
