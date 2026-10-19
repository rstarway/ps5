-- Pixel Quest — 2D-платформер на GUI: уровни из плиток, монеты, секретные кристаллы, враги и босс.
-- Всё рисуется в ctx.gui на холсте 1920×1080, мир прокручивается по горизонтали.
local Game = {}

local SW, SH = 1920, 1080
local T = 60 -- размер плитки
local ROWS = 18 -- 18 × 60 = 1080: уровень ровно в высоту экрана
local CHUNK = 16 -- столбцов в куске; невидимые куски скрываются

local GRAVITY = 2700
local JUMP_SPEED = 1080
local WALK, RUN = 430, 620
local ACCEL_GROUND, ACCEL_AIR, FRICTION = 3200, 2200, 3600
local MAX_FALL = 1500
local COYOTE, BUFFER = 0.1, 0.12
local P_W, P_H = 38, 54

local SOLID = { ["#"] = true, B = true, ["?"] = true, U = true }
local ENTITY = { S = true, C = true, G = true, o = true, ["*"] = true, h = true, E = true, F = true, M = true, K = true }

-- Пиксельные спрайты: строки, символ = цвет из палитры, "." = пусто
local PLAYER_A = {
	"...kkkk...",
	"..kggggk..",
	".kggggggk.",
	".kgsssssk.",
	".kgsksksk.",
	".kgsssssk.",
	"..kddddk..",
	".kddddddk.",
	"ksddyyddsk",
	".kddddddk.",
	"..kb..bk..",
	"..kk..kk..",
}
local PLAYER_B = table.clone(PLAYER_A)
PLAYER_B[11] = ".kb....bk."
PLAYER_B[12] = ".kk....kk."
local PLAYER_COLORS = { k = "#1B1B2F", g = "#43AA8B", s = "#FFD6A5", d = "#F9844A", y = "#F9C74F", b = "#6D4C41" }

local SLIME = {
	"...kkkk...",
	"..kppppk..",
	".kpplpppk.",
	"kpwkppwkpk",
	"kppppppppk",
	"kppppppppk",
	".kkkkkkkk.",
}
local SLIME_COLORS = { k = "#240046", p = "#9B5DE5", l = "#CDB4DB", w = "#FFFFFF" }

local BAT_A = {
	"....kkkk....",
	"k..kbbbbk..k",
	"kbkbwbbwbkbk",
	".kbbbbbbbbk.",
	"..kk.kk.kk..",
}
local BAT_B = {
	"kk..kkkk..kk",
	"kbk.kbbk.kbk",
	".kbkbwwbkbk.",
	"..kbbbbbbk..",
	"....kkkk....",
}
local BAT_COLORS = { k = "#10002B", b = "#6A4C93", w = "#FFD166" }

local KING = {
	"....y.y.y.y....",
	"....yyyyyyy....",
	"....yryyyry....",
	"...kkkkkkkkk...",
	"..kgggggggggk..",
	".kgglgggggglgk.",
	".kgwwkgggwwkgk.",
	"kggwwkgggwwkggk",
	"kgggggggggggggk",
	"kggggkkkkkggggk",
	"kgggggggggggggk",
	".kdddddddddddk.",
	"..kkkkkkkkkkk..",
}
local KING_COLORS = { k = "#081C15", g = "#52B788", l = "#95D5B2", d = "#2D6A4F", w = "#FFFFFF", y = "#FFD166", r = "#EF476F" }

local SPIKES = {
	"..w...w...w.",
	".www.www.www",
	".sss.sss.sss",
	"ssssssssssss",
}
local SPIKE_COLORS = { w = "#E9ECEF", s = "#ADB5BD" }

local HEART = {
	".rr.rr.",
	"rrrrrrr",
	"rrrrrrr",
	".rrrrr.",
	"..rrr..",
	"...r...",
}

local THEMES = {
	meadow = { sky = { "#8EE3F5", "#E9F5DB" }, dirt = "#7F5539", speck = "#6B4423", grass = "#57CC99", grassTop = "#80ED99", far = "#B7E4C7", near = "#74C69D", cloud = "#FFFFFF", cloudT = 0.1 },
	caves = { sky = { "#240046", "#0B0014" }, dirt = "#3C096C", speck = "#5A189A", grass = "#9D4EDD", grassTop = "#C77DFF", far = "#2B0A4A", near = "#3A0F5C", cloud = "#C77DFF", cloudT = 0.8 },
	sunset = { sky = { "#F28482", "#F6BD60" }, dirt = "#8D5524", speck = "#6F4518", grass = "#84A98C", grassTop = "#CAD2C5", far = "#E5989B", near = "#B56576", cloud = "#FFE5D9", cloudT = 0.2 },
	throne = { sky = { "#0B3D2E", "#03140E" }, dirt = "#1B4332", speck = "#081C15", grass = "#2D6A4F", grassTop = "#43AA8B", far = "#123326", near = "#1B4332", cloud = "#43AA8B", cloudT = 0.8 },
}

-- Построитель уровней: x — столбец слева, y — ряд снизу (1 = нижний)
local function makeGrid(width)
	local grid = {}
	for r = 1, ROWS do
		grid[r] = table.create(width, ".")
	end
	return { width = width, grid = grid, ranges = {} }
end
local function set(L, x, y, c)
	local r = ROWS + 1 - y
	if r >= 1 and r <= ROWS and x >= 1 and x <= L.width then
		L.grid[r][x] = c
	end
end
local function fill(L, x1, y1, x2, y2, c)
	for x = x1, x2 do
		for y = y1, y2 do
			set(L, x, y, c)
		end
	end
end
local function ground(L, x1, x2, h)
	fill(L, x1, 1, x2, h, "#")
end
local function row(L, x1, x2, y, c)
	fill(L, x1, y, x2, y, c)
end
-- движущаяся платформа шириной 3 плитки, верх на высоте y, ездит вправо на range плиток
local function mover(L, x, y, range)
	set(L, x, y + 1, "M")
	L.ranges[(ROWS - y) * 10000 + x] = range
end

local LEVELS = {
	{
		name = "GREEN MEADOW", theme = "meadow", width = 124,
		build = function(L)
			ground(L, 1, 30, 3)
			set(L, 3, 4, "S")
			row(L, 8, 12, 6, "o")
			set(L, 14, 6, "?"); set(L, 15, 6, "B"); set(L, 16, 6, "?"); set(L, 17, 6, "B"); set(L, 18, 6, "?")
			set(L, 16, 10, "?")
			set(L, 22, 4, "E")
			ground(L, 26, 30, 5)
			set(L, 31, 7, "o"); set(L, 32, 8, "o"); set(L, 33, 7, "o")
			ground(L, 34, 58, 3)
			set(L, 37, 4, "E")
			ground(L, 40, 45, 5)
			row(L, 41, 44, 6, "o")
			row(L, 47, 50, 7, "="); row(L, 47, 50, 8, "o")
			set(L, 52, 4, "E"); set(L, 56, 4, "E")
			mover(L, 59, 3, 5)
			row(L, 61, 64, 7, "o")
			ground(L, 67, 124, 3)
			set(L, 70, 4, "C")
			row(L, 74, 80, 6, "B"); set(L, 77, 6, "?"); row(L, 74, 80, 7, "o")
			set(L, 78, 4, "E"); set(L, 82, 4, "E")
			ground(L, 85, 86, 5)
			ground(L, 88, 96, 7)
			row(L, 88, 92, 4, "H") -- ложная стена: проход в холме
			set(L, 93, 4, "*")
			row(L, 89, 95, 8, "o")
			set(L, 99, 4, "E")
			row(L, 101, 103, 4, "^"); row(L, 101, 103, 7, "o")
			ground(L, 108, 109, 4); ground(L, 110, 111, 5); ground(L, 112, 113, 6)
			set(L, 118, 4, "G")
		end,
	},
	{
		name = "CRYSTAL CAVES", theme = "caves", width = 130,
		build = function(L)
			fill(L, 1, 16, 130, 18, "#")
			ground(L, 1, 130, 2)
			-- секрет за спиной: ложная стена слева от старта
			fill(L, 1, 3, 1, 15, "#"); fill(L, 2, 5, 4, 15, "#"); fill(L, 4, 3, 4, 4, "H")
			set(L, 2, 3, "*")
			set(L, 7, 3, "S")
			row(L, 10, 13, 5, "="); row(L, 10, 13, 6, "o")
			set(L, 16, 3, "E")
			fill(L, 20, 1, 23, 2, "."); row(L, 20, 23, 5, "o")
			row(L, 26, 28, 3, "^")
			set(L, 32, 6, "F")
			ground(L, 36, 40, 4); ground(L, 38, 40, 6); set(L, 39, 7, "o")
			set(L, 44, 3, "E"); set(L, 47, 3, "E")
			set(L, 46, 6, "?"); set(L, 48, 6, "?")
			fill(L, 52, 1, 56, 2, "."); row(L, 53, 55, 4, "="); row(L, 53, 55, 5, "o")
			set(L, 60, 3, "C")
			row(L, 66, 72, 3, "^"); row(L, 66, 67, 5, "="); row(L, 70, 72, 5, "=")
			row(L, 66, 67, 6, "o"); row(L, 70, 72, 6, "o")
			set(L, 69, 8, "F")
			set(L, 76, 3, "h")
			ground(L, 78, 84, 4); set(L, 81, 5, "E"); row(L, 79, 83, 6, "o")
			fill(L, 88, 1, 91, 2, "."); set(L, 89, 7, "F")
			fill(L, 95, 10, 110, 15, "#")
			for x = 96, 108, 2 do
				set(L, x, 3, "o")
			end
			set(L, 100, 3, "E"); set(L, 104, 3, "E"); set(L, 108, 3, "E")
			row(L, 114, 115, 3, "^")
			ground(L, 118, 119, 3); ground(L, 120, 121, 4)
			set(L, 126, 3, "G")
		end,
	},
	{
		name = "SUNSET CLIFFS", theme = "sunset", width = 140,
		build = function(L)
			ground(L, 1, 14, 3)
			set(L, 3, 4, "S")
			row(L, 6, 10, 6, "o")
			mover(L, 15, 3, 3)
			ground(L, 21, 32, 4)
			set(L, 25, 5, "E"); set(L, 29, 5, "E")
			row(L, 26, 28, 7, "?")
			row(L, 34, 35, 5, "=")
			ground(L, 38, 48, 3)
			set(L, 42, 8, "F")
			-- секрет: невидимый блок, с него — на высокую полку с кристаллом
			set(L, 45, 7, "I"); set(L, 45, 5, "o")
			row(L, 43, 47, 10, "="); set(L, 45, 11, "*")
			mover(L, 49, 3, 4)
			ground(L, 56, 71, 3)
			set(L, 58, 4, "C"); set(L, 60, 7, "?")
			set(L, 62, 4, "E"); set(L, 66, 4, "E"); set(L, 64, 7, "F")
			ground(L, 72, 74, 5); ground(L, 78, 80, 5); ground(L, 84, 86, 5)
			set(L, 73, 7, "o"); set(L, 79, 7, "o"); set(L, 85, 7, "o")
			ground(L, 88, 100, 3)
			set(L, 90, 4, "h"); set(L, 92, 4, "^"); set(L, 94, 4, "E"); set(L, 97, 4, "E")
			mover(L, 101, 3, 5)
			set(L, 105, 7, "F")
			ground(L, 109, 140, 3)
			set(L, 112, 4, "C")
			row(L, 116, 118, 4, "^")
			set(L, 121, 4, "E"); set(L, 124, 4, "E"); set(L, 127, 4, "E")
			row(L, 120, 128, 7, "o")
			ground(L, 129, 130, 4); ground(L, 131, 132, 5); ground(L, 133, 134, 6)
			set(L, 137, 4, "G")
		end,
	},
	{
		name = "MOSS THRONE", theme = "throne", width = 32, boss = true,
		build = function(L)
			ground(L, 1, 32, 3)
			fill(L, 1, 4, 1, 15, "#"); fill(L, 32, 4, 32, 15, "#")
			row(L, 6, 9, 6, "="); row(L, 24, 27, 6, "=")
			set(L, 4, 4, "S"); set(L, 24, 4, "K")
			set(L, 7, 7, "h"); set(L, 26, 7, "h")
		end,
	},
}
local GEM_LEVELS = 3

local function approach(value, target, step)
	if value < target then
		return math.min(value + step, target)
	end
	return math.max(value - step, target)
end

local function fmtTime(sec)
	sec = math.floor(sec or 0)
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local function colOf(px)
	return math.floor(px / T) + 1
end
local rowOf = colOf

local function overlap(a, b)
	return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

function Game.launch(ctx)
	local ui = ctx.ui
	local hex = ui.hex
	local ARCADE = Enum.Font.Arcade
	local BOLD = ctx.theme.FontBold

	ctx.gui.BackgroundColor3 = Color3.fromRGB(11, 61, 46)
	local canvas = ui.canvas(ctx.gui, SW, SH)
	canvas.ClipsDescendants = true

	-- Спрайт из строк: куски одного цвета в ряду сливаются в один Frame; размеры в долях,
	-- поэтому спрайт можно растягивать и сплющивать через Size.
	local function sprite(parent, rows, palette, z, props)
		local h, w = #rows, #rows[1]
		local holder = ui.new("Frame", { BackgroundTransparency = 1, ZIndex = z, Parent = parent })
		for key, value in props or {} do
			holder[key] = value
		end
		local colors = {}
		for k, v in palette do
			colors[k] = hex(v)
		end
		for r, line in rows do
			local c = 1
			while c <= w do
				local ch = string.sub(line, c, c)
				if ch ~= "." and colors[ch] then
					local len = 1
					while c + len <= w and string.sub(line, c + len, c + len) == ch do
						len += 1
					end
					ui.new("Frame", {
						BackgroundColor3 = colors[ch],
						BorderSizePixel = 0,
						Position = UDim2.fromScale((c - 1) / w, (r - 1) / h),
						Size = UDim2.fromScale(len / w + 0.004, 1 / h + 0.004),
						ZIndex = z,
						Parent = holder,
					})
					c += len
				else
					c += 1
				end
			end
		end
		return holder
	end
	local function mirror(rows)
		local out = {}
		for i, line in rows do
			out[i] = string.reverse(line)
		end
		return out
	end

	-- Сохранения
	local unlocked = ctx.save:Get("unlocked", 1)
	local gemsFound = ctx.save:Get("gems", {})
	local bestTimes = ctx.save:Get("best", {})
	local totalCoins = ctx.save:Get("coins", 0)
	local totalStomps = ctx.save:Get("stomps", 0)

	local function gemCount()
		local n = 0
		for i = 1, GEM_LEVELS do
			if gemsFound["l" .. i] then
				n += 1
			end
		end
		return n
	end
	local function saveProgress()
		ctx.save:Set("coins", totalCoins)
		ctx.save:Set("stomps", totalStomps)
	end

	-- Слои: фон → мир → HUD → меню → титульный экран
	local bg = ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 1, Parent = canvas })
	local bgGradient = ui.gradient({ hex("#8EE3F5"), hex("#E9F5DB") }, 90)
	bgGradient.Parent = bg
	local bgDecor = {}

	local hud = ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 50, Visible = false, Parent = canvas })
	ui.new("Frame", {
		Size = UDim2.fromOffset(SW, 96), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.65, BorderSizePixel = 0, ZIndex = 50, Parent = hud,
	})
	local heartSlots = {}
	for i = 1, 3 do
		local x = 36 + (i - 1) * 58
		local empty = sprite(hud, HEART, { r = "#3A3A4A" }, 51, { Position = UDim2.fromOffset(x, 26), Size = UDim2.fromOffset(49, 42) })
		local full = sprite(hud, HEART, { r = "#EF476F" }, 52, { Position = UDim2.fromOffset(x, 26), Size = UDim2.fromOffset(49, 42) })
		heartSlots[i] = { empty = empty, full = full }
	end
	ui.new("Frame", {
		Position = UDim2.fromOffset(240, 30), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = hex("#F9C74F"), ZIndex = 51, Parent = hud,
	}, { ui.corner(UDim.new(0.5, 0)), ui.stroke(hex("#B07D0B"), 3) })
	local coinText = ui.text("x 0", { Position = UDim2.fromOffset(286, 24), Size = UDim2.fromOffset(200, 46), Font = ARCADE, TextSize = 40, ZIndex = 51, Parent = hud })
	local gemIcon = ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(460, 47), Size = UDim2.fromOffset(28, 28), Rotation = 45,
		BackgroundColor3 = hex("#3A3A4A"), ZIndex = 51, Parent = hud,
	}, { ui.stroke(Color3.new(1, 1, 1), 2, 0.4) })
	local levelText = ui.text("", {
		Position = UDim2.fromOffset(560, 24), Size = UDim2.fromOffset(800, 46), Font = ARCADE, TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 51, Parent = hud,
	})
	local timeText = ui.text("0:00", {
		Position = UDim2.fromOffset(SW - 340, 24), Size = UDim2.fromOffset(300, 46), Font = ARCADE, TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 51, Parent = hud,
	})
	local bossBar = ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(SW / 2, 130), Size = UDim2.fromOffset(640, 28),
		BackgroundColor3 = hex("#081C15"), Visible = false, ZIndex = 51, Parent = hud,
	}, { ui.corner(6), ui.stroke(hex("#FFD166"), 3) })
	local bossFill = ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = hex("#EF476F"), ZIndex = 52, Parent = bossBar }, { ui.corner(6) })
	ui.text("THE MOSS KING", {
		Position = UDim2.fromOffset(0, -44), Size = UDim2.new(1, 0, 0, 40), Font = ARCADE, TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 52, Parent = bossBar,
	})
	local banner = ui.text("", {
		Position = UDim2.fromOffset(0, 300), Size = UDim2.fromOffset(SW, 140), Font = ARCADE, TextSize = 76,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = hex("#FFFFFF"), TextStrokeTransparency = 0, TextStrokeColor3 = hex("#0B3D2E"),
		ZIndex = 53, Parent = hud,
	})

	-- Меню поверх игры (пауза, итоги уровня, финал)
	local dim = ui.new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0,
		Visible = false, ZIndex = 59, Parent = canvas,
	})
	local panel = ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(SW / 2, SH / 2), Size = UDim2.fromOffset(1000, 660),
		BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 60, Parent = canvas,
	}, { ui.corner(24), ui.stroke(hex("#43AA8B"), 4), ui.gradient({ hex("#14594A"), hex("#0B3D2E") }, 90) })
	local panelTitle = ui.text("", {
		Position = UDim2.fromOffset(0, 40), Size = UDim2.fromOffset(1000, 100), Font = ARCADE, TextSize = 70,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = hex("#F9C74F"), ZIndex = 61, Parent = panel,
	})
	local panelBody = ui.text("", {
		Position = UDim2.fromOffset(60, 170), Size = UDim2.fromOffset(880, 450), Font = BOLD, TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 61, Parent = panel,
	})
	local menu = nil
	local function drawMenu()
		local lines = {}
		if menu.info ~= "" then
			table.insert(lines, menu.info)
			table.insert(lines, "")
		end
		for i, item in menu.items do
			table.insert(lines, (i == menu.index and "▶  " or "    ") .. item .. (i == menu.index and "  ◀" or "    "))
		end
		panelBody.Text = table.concat(lines, "\n")
	end
	local function showMenu(title, info, items, onSelect, onBack)
		menu = { items = items, index = 1, onSelect = onSelect, onBack = onBack, info = info }
		panelTitle.Text = title
		dim.Visible, panel.Visible = true, true
		drawMenu()
	end
	local function hideMenu()
		menu = nil
		dim.Visible, panel.Visible = false, false
	end

	-- Состояние уровня
	local state = "title"
	local levelIndex, def, theme, L, W
	local layer, chunks, tileFrames
	local coins, gems, hearts, enemies, platforms, checkpoints, particles
	local goal, boss
	local p, playerFrame, playerSprites
	local spawnX, spawnY
	local camX, shake = 0, 0
	local levelTime, levelCoins, levelCoinMax, deaths, tookDamage, gemThisRun = 0, 0, 0, 0, false, false
	local bannerTime, dyingTime, clock = 0, 0, 0

	local function tileAt(c, r)
		if c < 1 or c > W then
			return "#"
		end
		if r < 1 or r > ROWS then
			return "."
		end
		return L.grid[r][c]
	end

	local function chunkFor(x)
		local i = math.clamp(math.floor(x / (CHUNK * T)) + 1, 1, #chunks)
		return chunks[i], (i - 1) * CHUNK * T
	end

	local function addCoins(n)
		levelCoins += n
		totalCoins += n
		if totalCoins >= 100 then
			ctx.trophies:Unlock("coins_100")
		end
	end

	-- Частицы: кусочки, всплывающие монеты и текст
	local function particle(x, y, props)
		local frame
		if props.text then
			frame = ui.text(props.text, {
				AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(160, 40), Font = ARCADE, TextSize = props.size or 30,
				TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = props.color or Color3.new(1, 1, 1),
				TextStrokeTransparency = 0.3, ZIndex = 8, Parent = layer,
			})
		else
			frame = ui.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(props.w or 10, props.h or 10),
				BackgroundColor3 = props.color or Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 8, Parent = layer,
			}, props.round and { ui.corner(UDim.new(0.5, 0)) } or nil)
		end
		table.insert(particles, {
			frame = frame, x = x, y = y, vx = props.vx or 0, vy = props.vy or 0, g = props.g or 0, life = props.life or 0.5,
		})
	end
	local function burst(x, y, color, n, speed)
		for _ = 1, n do
			local a = math.random() * math.pi * 2
			local s = (speed or 300) * (0.5 + math.random() * 0.5)
			particle(x, y, { color = color, vx = math.cos(a) * s, vy = math.sin(a) * s - 200, g = 1800, life = 0.45 + math.random() * 0.2 })
		end
	end

	-- Плитки
	local function isGround(t)
		return t == "#" or t == "H"
	end
	local function styleBlock(entry, t)
		local f = entry.frame
		f.Visible = t ~= "I"
		if t == "?" then
			f.BackgroundColor3 = hex("#F9C74F")
			entry.stroke.Color = hex("#B07D0B")
			entry.label.Text = "?"
		else
			f.BackgroundColor3 = hex("#8D6E63")
			entry.stroke.Color = hex("#4E342E")
			entry.label.Text = ""
		end
	end
	local function drawTiles()
		local dirt, speck, grass, grassTop = hex(theme.dirt), hex(theme.speck), hex(theme.grass), hex(theme.grassTop)
		for ci, chunk in chunks do
			local c0 = (ci - 1) * CHUNK + 1
			local c1 = math.min(W, c0 + CHUNK - 1)
			for r = 1, ROWS do
				local c = c0
				while c <= c1 do
					local t = L.grid[r][c]
					local lx, y = (c - c0) * T, (r - 1) * T
					if isGround(t) then
						local top = r > 1 and not isGround(L.grid[r - 1][c])
						local len = 1
						while c + len <= c1 do
							local t2 = L.grid[r][c + len]
							if t2 ~= t or (r > 1 and not isGround(L.grid[r - 1][c + len])) ~= top then
								break
							end
							len += 1
						end
						local f = ui.new("Frame", {
							BackgroundColor3 = dirt, BorderSizePixel = 0, BackgroundTransparency = t == "H" and 0.12 or 0,
							Position = UDim2.fromOffset(lx, y), Size = UDim2.fromOffset(len * T, T), ZIndex = 3, Parent = chunk,
						})
						for i = 0, len - 1 do
							local h = ((c + i) * 37 + r * 91) % 97
							ui.new("Frame", {
								BackgroundColor3 = speck, BorderSizePixel = 0, Position = UDim2.fromOffset(i * T + 8 + h % 34, 24 + (h // 5) % 24),
								Size = UDim2.fromOffset(10, 10), ZIndex = 3, Parent = f,
							})
						end
						if top then
							ui.new("Frame", { BackgroundColor3 = grass, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 16), ZIndex = 3, Parent = f })
							ui.new("Frame", { BackgroundColor3 = grassTop, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 5), ZIndex = 3, Parent = f })
						end
						c += len
					elseif t == "=" then
						local len = 1
						while c + len <= c1 and L.grid[r][c + len] == "=" do
							len += 1
						end
						ui.new("Frame", {
							BackgroundColor3 = hex("#C08552"), BorderSizePixel = 0, Position = UDim2.fromOffset(lx, y), Size = UDim2.fromOffset(len * T, 18),
							ZIndex = 3, Parent = chunk,
						}, { ui.stroke(hex("#5E3023"), 3) })
						c += len
					else
						if t == "B" then
							ui.new("Frame", {
								BackgroundColor3 = hex("#BC6C25"), BorderSizePixel = 0, Position = UDim2.fromOffset(lx + 1, y + 1), Size = UDim2.fromOffset(T - 2, T - 2),
								ZIndex = 3, Parent = chunk,
							}, {
								ui.stroke(hex("#6F4518"), 3),
								ui.new("Frame", { BackgroundColor3 = hex("#6F4518"), BorderSizePixel = 0, Position = UDim2.fromOffset(0, 27), Size = UDim2.new(1, 0, 0, 4), ZIndex = 3 }),
								ui.new("Frame", { BackgroundColor3 = hex("#6F4518"), BorderSizePixel = 0, Position = UDim2.fromOffset(28, 0), Size = UDim2.fromOffset(4, 27), ZIndex = 3 }),
							})
						elseif t == "?" or t == "I" or t == "U" then
							local stroke = ui.stroke(hex("#B07D0B"), 4)
							local f = ui.new("Frame", {
								BorderSizePixel = 0, Position = UDim2.fromOffset(lx + 2, y + 2), Size = UDim2.fromOffset(T - 4, T - 4), ZIndex = 3, Parent = chunk,
							}, { ui.corner(6), stroke })
							local label = ui.text("?", {
								Size = UDim2.fromScale(1, 1), Font = ARCADE, TextSize = 44, TextXAlignment = Enum.TextXAlignment.Center,
								TextColor3 = hex("#FFFFFF"), TextStrokeTransparency = 0.2, ZIndex = 3, Parent = f,
							})
							local entry = { frame = f, stroke = stroke, label = label }
							tileFrames[r * 10000 + c] = entry
							styleBlock(entry, t)
						elseif t == "^" then
							sprite(chunk, SPIKES, SPIKE_COLORS, 3, { Position = UDim2.fromOffset(lx, y + 30), Size = UDim2.fromOffset(T, 30) })
						end
						c += 1
					end
				end
			end
		end
	end

	local function paintBackground()
		for _, d in bgDecor do
			d.frame:Destroy()
		end
		table.clear(bgDecor)
		bgGradient.Color = ColorSequence.new(hex(theme.sky[1]), hex(theme.sky[2]))
		local function add(color, transparency, size, x, y, factor)
			local f = ui.new("Frame", {
				BackgroundColor3 = hex(color), BackgroundTransparency = transparency, BorderSizePixel = 0,
				Size = UDim2.fromOffset(size.X, size.Y), Position = UDim2.fromOffset(x, y), ZIndex = 1, Parent = bg,
			}, { ui.corner(UDim.new(0.5, 0)) })
			table.insert(bgDecor, { frame = f, x = x, y = y, w = size.X, factor = factor })
		end
		local rng = Random.new(levelIndex * 17)
		for i = 1, 6 do
			add(theme.cloud, theme.cloudT, Vector2.new(rng:NextInteger(180, 300), rng:NextInteger(50, 80)), i * 480, rng:NextInteger(140, 380), 0.08)
		end
		for i = 1, 7 do
			local s = rng:NextInteger(500, 800)
			add(theme.far, 0, Vector2.new(s, s), i * 420 - 300, SH - 260 - s * 0.25, 0.2)
		end
		for i = 1, 6 do
			local s = rng:NextInteger(400, 600)
			add(theme.near, 0, Vector2.new(s, s), i * 520 - 200, SH - 160 - s * 0.2, 0.45)
		end
	end

	local function makeEnemy(kind, x, y)
		local e = { kind = kind, alive = true, t = math.random() * 3, vy = 0 }
		if kind == "E" then
			e.w, e.h = 44, 34
			e.x, e.y = x + (T - e.w) / 2, y + T - e.h
			e.vx = -90
			e.frame = sprite(layer, SLIME, SLIME_COLORS, 5, { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(50, 35) })
		else
			e.w, e.h = 50, 26
			e.x, e.y = x + 5, y + 17
			e.x0, e.y0 = e.x, e.y
			e.frame = ui.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Size = UDim2.fromOffset(60, 25), ZIndex = 5, Parent = layer })
			e.a = sprite(e.frame, BAT_A, BAT_COLORS, 5, { Size = UDim2.fromScale(1, 1) })
			e.b = sprite(e.frame, BAT_B, BAT_COLORS, 5, { Size = UDim2.fromScale(1, 1), Visible = false })
		end
		table.insert(enemies, e)
		return e
	end

	local function spawnEntity(ch, c, r)
		local x, y = (c - 1) * T, (r - 1) * T
		if ch == "S" then
			spawnX, spawnY = x + (T - P_W) / 2, r * T - P_H
		elseif ch == "o" then
			local chunk, ox = chunkFor(x)
			local f = ui.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x + T / 2 - ox, y + T / 2), Size = UDim2.fromOffset(30, 36),
				BackgroundColor3 = hex("#F9C74F"), ZIndex = 4, Parent = chunk,
			}, { ui.corner(UDim.new(0.5, 0)), ui.stroke(hex("#B07D0B"), 3) })
			table.insert(coins, { x = x + T / 2, y = y + T / 2, frame = f })
			levelCoinMax += 1
		elseif ch == "*" then
			local chunk, ox = chunkFor(x)
			local f = ui.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x + T / 2 - ox, y + T / 2), Size = UDim2.fromOffset(34, 34), Rotation = 45,
				BackgroundColor3 = hex("#4CC9F0"), ZIndex = 4, Parent = chunk,
			}, { ui.stroke(Color3.new(1, 1, 1), 3, 0.2) })
			table.insert(gems, { x = x + T / 2, y = y + T / 2, frame = f, ox = ox })
		elseif ch == "h" then
			local chunk, ox = chunkFor(x)
			local f = sprite(chunk, HEART, { r = "#EF476F" }, 4, {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x + T / 2 - ox, y + T / 2), Size = UDim2.fromOffset(42, 36),
			})
			table.insert(hearts, { x = x + T / 2, y = y + T / 2, frame = f, ox = ox })
		elseif ch == "C" then
			local chunk, ox = chunkFor(x)
			ui.new("Frame", {
				BackgroundColor3 = hex("#DDDDDD"), BorderSizePixel = 0, Position = UDim2.fromOffset(x + 27 - ox, y - 2 * T), Size = UDim2.fromOffset(6, 3 * T),
				ZIndex = 4, Parent = chunk,
			})
			local flag = ui.new("Frame", {
				BackgroundColor3 = hex("#6C757D"), BorderSizePixel = 0, Position = UDim2.fromOffset(x + 33 - ox, y - 2 * T), Size = UDim2.fromOffset(50, 34),
				ZIndex = 4, Parent = chunk,
			})
			table.insert(checkpoints, { x = x, sx = x + (T - P_W) / 2, sy = r * T - P_H, flag = flag, active = false })
		elseif ch == "G" then
			local chunk, ox = chunkFor(x)
			ui.new("Frame", {
				BackgroundColor3 = hex("#F1FAEE"), BorderSizePixel = 0, Position = UDim2.fromOffset(x + 26 - ox, y - 4 * T), Size = UDim2.fromOffset(8, 5 * T),
				ZIndex = 4, Parent = chunk,
			})
			ui.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = hex("#F9C74F"), Position = UDim2.fromOffset(x + 30 - ox, y - 4 * T), Size = UDim2.fromOffset(26, 26),
				ZIndex = 4, Parent = chunk,
			}, { ui.corner(UDim.new(0.5, 0)) })
			local flag = ui.new("Frame", {
				BackgroundColor3 = hex("#43AA8B"), BorderSizePixel = 0, Position = UDim2.fromOffset(x + 34 - ox, y - 4 * T + 16), Size = UDim2.fromOffset(90, 60),
				ZIndex = 4, Parent = chunk,
			}, { ui.stroke(hex("#0B3D2E"), 3) })
			ui.text("PQ", { Size = UDim2.fromScale(1, 1), Font = ARCADE, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = flag })
			goal = { x = x + 14, y = y - 4 * T, w = 32, h = 5 * T }
		elseif ch == "E" or ch == "F" then
			makeEnemy(ch, x, y)
		elseif ch == "M" then
			local range = L.ranges[r * 10000 + c] or 4
			local pl = { x = x, y = r * T, w = 3 * T, h = 20, x0 = x, x1 = x + range * T, dir = 1, speed = 140, dx = 0 }
			pl.frame = ui.new("Frame", {
				BackgroundColor3 = hex("#C08552"), BorderSizePixel = 0, Size = UDim2.fromOffset(pl.w, 22), ZIndex = 5, Parent = layer,
			}, { ui.stroke(hex("#5E3023"), 3), ui.corner(4) })
			table.insert(platforms, pl)
		elseif ch == "K" then
			boss = { x = x, y = y + T - 110, w = 140, h = 110, vx = 0, vy = 0, hp = 5, maxHp = 5, state = "intro", t = 2, inv = 0, onGround = false }
			boss.frame = sprite(layer, KING, KING_COLORS, 5, { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(150, 130) })
		end
	end

	-- Движение с проверкой плиток. Возвращает, во что упёрлись.
	local function moveX(e, dx)
		if dx == 0 then
			return false
		end
		e.x += dx
		local r0, r1 = rowOf(e.y), rowOf(e.y + e.h - 0.01)
		if dx > 0 then
			local c = colOf(e.x + e.w - 0.01)
			for r = r0, r1 do
				if SOLID[tileAt(c, r)] then
					e.x = (c - 1) * T - e.w
					return true
				end
			end
		else
			local c = colOf(e.x)
			for r = r0, r1 do
				if SOLID[tileAt(c, r)] then
					e.x = c * T
					return true
				end
			end
		end
		return false
	end

	local function moveY(e, dy, isPlayer)
		if dy == 0 then
			return nil
		end
		local prevBottom = e.y + e.h
		e.y += dy
		local c0, c1 = colOf(e.x), colOf(e.x + e.w - 0.01)
		if dy > 0 then
			local r = rowOf(e.y + e.h - 0.01)
			for c = c0, c1 do
				local t = tileAt(c, r)
				if SOLID[t] or (t == "=" and prevBottom <= (r - 1) * T + 0.5) then
					e.y = (r - 1) * T - e.h
					return "floor"
				end
			end
			if isPlayer then
				for _, pl in platforms do
					if e.x + e.w > pl.x and e.x < pl.x + pl.w and prevBottom <= pl.y + 0.5 and e.y + e.h >= pl.y then
						e.y = pl.y - e.h
						return "floor", pl
					end
				end
			end
		else
			local r = rowOf(e.y)
			local hits = {}
			for c = c0, c1 do
				local t = tileAt(c, r)
				if SOLID[t] or (isPlayer and t == "I") then
					table.insert(hits, c)
				end
			end
			if #hits > 0 then
				e.y = r * T
				return "ceil", r, hits
			end
		end
		return nil
	end

	local function bump(r, cols)
		local center = p.x + p.w / 2
		local best, bestD = nil, math.huge
		for _, c in cols do
			local d = math.abs((c - 0.5) * T - center)
			if d < bestD then
				best, bestD = c, d
			end
		end
		if not best or best < 1 or best > W then
			return
		end
		local t = L.grid[r][best]
		local bx, by = (best - 0.5) * T, (r - 1) * T
		if t == "?" or t == "I" then
			L.grid[r][best] = "U"
			local entry = tileFrames[r * 10000 + best]
			if entry then
				styleBlock(entry, "U")
			end
			addCoins(1)
			ctx.audio:Play("confirm", { volume = 0.4, pitch = 2 })
			particle(bx, by - 20, { w = 28, h = 34, round = true, color = hex("#F9C74F"), vy = -700, g = 2200, life = 0.45 })
			particle(bx, by - 60, { text = "+1", vy = -120, life = 0.6 })
			if t == "I" then
				burst(bx, by + T / 2, hex("#FFFFFF"), 8, 260)
			end
		else
			ctx.audio:Play("hit", { volume = 0.25, pitch = 0.7 })
			burst(bx, by + T, hex(theme.dirt), 4, 160)
		end
	end

	-- Игрок
	local function buildPlayer()
		playerFrame = ui.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Size = UDim2.fromOffset(50, 60), ZIndex = 6, Parent = layer })
		playerSprites = {
			ra = sprite(playerFrame, PLAYER_A, PLAYER_COLORS, 6, { Size = UDim2.fromScale(1, 1) }),
			rb = sprite(playerFrame, PLAYER_B, PLAYER_COLORS, 6, { Size = UDim2.fromScale(1, 1) }),
			la = sprite(playerFrame, mirror(PLAYER_A), PLAYER_COLORS, 6, { Size = UDim2.fromScale(1, 1) }),
			lb = sprite(playerFrame, mirror(PLAYER_B), PLAYER_COLORS, 6, { Size = UDim2.fromScale(1, 1) }),
		}
	end

	local function placePlayer(x, y)
		p = { x = x, y = y, w = P_W, h = P_H, vx = 0, vy = 0, onGround = false, onPlat = nil, face = 1, coyote = 0, buffer = 0, hp = 3, invuln = 1, animT = 0 }
		playerFrame.Rotation = 0
	end

	local function showBanner(text, seconds)
		banner.Text = text
		bannerTime = seconds or 2.5
	end

	local function loadLevel(index)
		if layer then
			layer:Destroy()
		end
		hideMenu()
		levelIndex = index
		def = LEVELS[index]
		theme = THEMES[def.theme]
		L = makeGrid(def.width)
		def.build(L)
		W = def.width
		coins, gems, hearts, enemies, platforms, checkpoints, particles = {}, {}, {}, {}, {}, {}, {}
		goal, boss = nil, nil
		tileFrames = {}
		levelTime, levelCoins, levelCoinMax, deaths, tookDamage, gemThisRun = 0, 0, 0, 0, false, false
		layer = ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(W * T, SH), ZIndex = 2, Parent = canvas })
		chunks = {}
		for i = 1, math.ceil(W / CHUNK) do
			chunks[i] = ui.new("Frame", {
				BackgroundTransparency = 1, Position = UDim2.fromOffset((i - 1) * CHUNK * T, 0), Size = UDim2.fromOffset(CHUNK * T, SH), ZIndex = 2, Parent = layer,
			})
		end
		for r = 1, ROWS do
			for c = 1, W do
				local ch = L.grid[r][c]
				if ENTITY[ch] then
					L.grid[r][c] = "."
					spawnEntity(ch, c, r)
				elseif ch == "?" or ch == "I" then
					levelCoinMax += 1
				end
			end
		end
		drawTiles()
		paintBackground()
		buildPlayer()
		placePlayer(spawnX or T, spawnY or 0)
		camX = 0
		gemIcon.BackgroundColor3 = gemsFound["l" .. index] and hex("#4CC9F0") or hex("#3A3A4A")
		gemIcon.Visible = index <= GEM_LEVELS
		levelText.Text = `{index}  {def.name}`
		bossBar.Visible = boss ~= nil
		hud.Visible = true
		state = "play"
		showBanner(def.boss and "THE MOSS KING AWAITS" or `WORLD {index}\n{def.name}`)
	end

	-- Титульный экран
	local title = ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 70, Parent = canvas }, {
		ui.gradient({ hex("#43AA8B"), hex("#0B3D2E") }, 90),
	})
	for i = 0, 5 do
		ui.new("Frame", {
			BackgroundColor3 = hex("#2D6A4F"), BackgroundTransparency = 0.3, BorderSizePixel = 0, Position = UDim2.fromOffset(i * 360 - 120, 760),
			Size = UDim2.fromOffset(600, 600), ZIndex = 70, Parent = title,
		}, { ui.corner(UDim.new(0.5, 0)) })
	end
	ui.new("Frame", { BackgroundColor3 = hex("#7F5539"), BorderSizePixel = 0, Position = UDim2.fromOffset(0, SH - 90), Size = UDim2.fromOffset(SW, 90), ZIndex = 71, Parent = title }, {
		ui.new("Frame", { BackgroundColor3 = hex("#57CC99"), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 18), ZIndex = 71 }),
	})
	ui.text("PIXEL QUEST", {
		Position = UDim2.fromOffset(8, 98), Size = UDim2.fromOffset(SW, 160), Font = ARCADE, TextSize = 140,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = hex("#0B3D2E"), ZIndex = 71, Parent = title,
	})
	ui.text("PIXEL QUEST", {
		Position = UDim2.fromOffset(0, 90), Size = UDim2.fromOffset(SW, 160), Font = ARCADE, TextSize = 140,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = hex("#F9C74F"), ZIndex = 72, Parent = title,
	})
	ui.text("A COSY PIXEL ADVENTURE", {
		Position = UDim2.fromOffset(0, 250), Size = UDim2.fromOffset(SW, 50), Font = ARCADE, TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = hex("#D8F3DC"), ZIndex = 72, Parent = title,
	})
	local titleMenu = ui.text("", {
		Position = UDim2.fromOffset(460, 340), Size = UDim2.fromOffset(1000, 420), Font = BOLD, TextSize = 42,
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 72, Parent = title,
	})
	local titleStats = ui.text("", {
		Position = UDim2.fromOffset(0, SH - 62), Size = UDim2.fromOffset(SW, 40), Font = BOLD, TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 73, Parent = title,
	})
	local titleHero = ui.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Size = UDim2.fromOffset(75, 90), ZIndex = 72, Parent = title })
	local heroA = sprite(titleHero, PLAYER_A, PLAYER_COLORS, 72, { Size = UDim2.fromScale(1, 1) })
	local heroB = sprite(titleHero, PLAYER_B, PLAYER_COLORS, 72, { Size = UDim2.fromScale(1, 1), Visible = false })
	local titleSlime = sprite(title, SLIME, SLIME_COLORS, 72, { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(70, 49) })
	local titleIndex = 1

	local function drawTitle()
		local lines = {}
		for i, lv in LEVELS do
			local label
			if i > unlocked then
				label = `{i}.  ?????   (locked)`
			else
				local extra = ""
				if bestTimes["l" .. i] then
					extra ..= `   best {fmtTime(bestTimes["l" .. i])}`
				end
				if i <= GEM_LEVELS and gemsFound["l" .. i] then
					extra ..= "   ◆"
				end
				label = `{i}.  {lv.name}{extra}`
			end
			table.insert(lines, (i == titleIndex and "▶  " or "    ") .. label)
		end
		table.insert(lines, "")
		table.insert(lines, (titleIndex == #LEVELS + 1 and "▶  " or "    ") .. "Quit to PS5 Menu")
		titleMenu.Text = table.concat(lines, "\n")
		titleStats.Text = `Coins {totalCoins}     Gems {gemCount()}/{GEM_LEVELS}     Stomps {totalStomps}        {ctx.input:Glyph("cross")} Select     {ctx.input:Glyph("circle")} Quit`
	end

	local function showTitle()
		if layer then
			layer:Destroy()
			layer = nil
		end
		saveProgress()
		hideMenu()
		hud.Visible = false
		title.Visible = true
		state = "title"
		titleIndex = math.min(unlocked, #LEVELS)
		drawTitle()
	end

	local function startLevel(index)
		title.Visible = false
		loadLevel(index)
	end

	-- Урон, смерть, победа
	local function die()
		if state ~= "play" then
			return
		end
		state = "dying"
		dyingTime = 1.3
		deaths += 1
		p.vy, p.vx = -1000, 0
		ctx.input:Rumble(0.8, 0.4)
		ctx.audio:Play("error", { volume = 0.6, pitch = 0.7 })
		saveProgress()
	end

	local function hurt(fromX)
		if p.invuln > 0 or state ~= "play" then
			return
		end
		p.hp -= 1
		tookDamage = true
		p.invuln = 1.5
		p.vy = -600
		p.vx = (p.x + p.w / 2 < fromX) and -380 or 380
		ctx.input:Rumble(0.6, 0.25)
		ctx.audio:Play("hit", { volume = 0.6, pitch = 0.8 })
		if p.hp <= 0 then
			die()
		end
	end

	local function respawn()
		if def.boss then
			local falls = deaths
			loadLevel(levelIndex)
			deaths, tookDamage = falls, true
			return
		end
		local sx, sy = spawnX, spawnY
		for _, cp in checkpoints do
			if cp.active then
				sx, sy = cp.sx, cp.sy
			end
		end
		placePlayer(sx, sy)
		state = "play"
	end

	local function finishLevel()
		state = "clear"
		saveProgress()
		ctx.audio:Play("notify", { volume = 0.8, pitch = 1.2 })
		local key = "l" .. levelIndex
		local newBest = not bestTimes[key] or levelTime < bestTimes[key]
		if newBest then
			bestTimes[key] = math.floor(levelTime * 10) / 10
			ctx.save:Set("best", bestTimes)
		end
		if levelIndex + 1 > unlocked and levelIndex < #LEVELS then
			unlocked = levelIndex + 1
			ctx.save:Set("unlocked", unlocked)
		end
		ctx.save:Set("clears", ctx.save:Get("clears", 0) + 1)
		if levelIndex == 1 then
			ctx.trophies:Unlock("first_clear")
		end
		if not tookDamage and deaths == 0 then
			ctx.trophies:Unlock("no_damage")
		end
		if def.boss then
			ctx.trophies:Unlock("boss")
			showMenu(
				"THE END",
				`You defeated the Moss King!\nThe pixel kingdom is cosy again.\n\nTotal coins: {totalCoins}     Gems: {gemCount()}/{GEM_LEVELS}\nBoss time: {fmtTime(levelTime)}`,
				{ "Back to Title" },
				function()
					showTitle()
				end
			)
			return
		end
		local gemLine = gemsFound[key] and "Secret gem: found ◆" or "Secret gem: still hidden somewhere..."
		showMenu(
			"LEVEL CLEAR",
			`Coins {levelCoins}/{levelCoinMax}\n{gemLine}\nTime {fmtTime(levelTime)}{newBest and "   NEW BEST!" or ""}\nFalls {deaths}`,
			{ "Next Level", "Replay", "Level Select" },
			function(i)
				if i == 1 then
					loadLevel(math.min(levelIndex + 1, #LEVELS))
				elseif i == 2 then
					loadLevel(levelIndex)
				else
					showTitle()
				end
			end,
			showTitle
		)
	end

	local function openPause()
		state = "paused"
		showMenu("PAUSED", `{levelIndex}  {def.name}`, { "Resume", "Restart Level", "Level Select", "Quit to PS5 Menu" }, function(i)
			if i == 1 then
				hideMenu()
				state = "play"
			elseif i == 2 then
				loadLevel(levelIndex)
			elseif i == 3 then
				showTitle()
			else
				ctx:Exit()
			end
		end, function()
			hideMenu()
			state = "play"
		end)
	end

	local function stomp(e)
		e.alive = false
		e.deadT = 0.35
		totalStomps += 1
		if totalStomps >= 30 then
			ctx.trophies:Unlock("stomp_30")
		end
		p.vy = (ctx.input:IsDown("cross") or ctx.input:IsDown("up")) and -1050 or -720
		ctx.audio:Play("hit", { volume = 0.5, pitch = 1.5 })
		ctx.input:Rumble(0.3, 0.1)
		burst(e.x + e.w / 2, e.y + e.h / 2, e.kind == "E" and hex("#9B5DE5") or hex("#6A4C93"), 8, 260)
		particle(e.x + e.w / 2, e.y - 20, { text = "STOMP", size = 26, color = hex("#FFD166"), vy = -140, life = 0.6 })
	end

	local function bossHit()
		boss.hp -= 1
		boss.inv = 1
		boss.state, boss.t = "hurt", 0.6
		boss.vx = 0
		p.vy = -1150
		ctx.audio:Play("explosion", { volume = 0.6, pitch = 1.3 })
		ctx.input:Rumble(0.7, 0.2)
		burst(boss.x + boss.w / 2, boss.y, hex("#52B788"), 14, 420)
		if boss.hp <= 0 then
			boss.state, boss.t = "dead", 1.6
			shake = 0.6
			for _, e in enemies do
				if e.alive then
					e.alive, e.deadT = false, 0.35
				end
			end
			addCoins(10)
			for _ = 1, 10 do
				particle(boss.x + boss.w / 2, boss.y + 40, {
					w = 26, h = 30, round = true, color = hex("#F9C74F"), vx = (math.random() - 0.5) * 900, vy = -600 - math.random() * 600, g = 2000, life = 1.1,
				})
			end
			showBanner("YOU WIN!", 2.5)
		end
	end

	-- Обновление мира за кадр
	local function updatePlatforms(dt)
		for _, pl in platforms do
			local nx = pl.x + pl.dir * pl.speed * dt
			if nx > pl.x1 then
				nx, pl.dir = pl.x1, -1
			elseif nx < pl.x0 then
				nx, pl.dir = pl.x0, 1
			end
			pl.dx = nx - pl.x
			pl.x = nx
			if p.onPlat == pl and state == "play" then
				moveX(p, pl.dx)
			end
		end
	end

	local function updateEnemies(dt)
		local center = camX + SW / 2
		for i = #enemies, 1, -1 do
			local e = enemies[i]
			if not e.alive then
				e.deadT -= dt
				e.frame.Size = UDim2.fromOffset(60, 12)
				if e.deadT <= 0 then
					e.frame:Destroy()
					table.remove(enemies, i)
				end
			elseif math.abs(e.x - center) < SW then
				e.t += dt
				if e.kind == "E" then
					e.vy = math.min(e.vy + GRAVITY * dt, MAX_FALL)
					if moveX(e, e.vx * dt) then
						e.vx = -e.vx
					end
					local hit = moveY(e, e.vy * dt, false)
					if hit == "floor" then
						e.vy = 0
						local frontC = colOf(e.vx > 0 and e.x + e.w + 2 or e.x - 2)
						local below = tileAt(frontC, rowOf(e.y + e.h + 2))
						if not SOLID[below] and below ~= "=" and not boss then
							e.vx = -e.vx
						end
					end
					local squash = math.sin(e.t * 8) * 3
					e.frame.Size = UDim2.fromOffset(50 + squash, 35 - squash)
					if e.y > SH + 200 then
						e.frame:Destroy()
						table.remove(enemies, i)
						continue
					end
				else
					e.x = e.x0 + math.sin(e.t * 0.9) * 2 * T
					e.y = e.y0 + math.sin(e.t * 3) * 22
					local flap = math.floor(e.t * 8) % 2 == 0
					e.a.Visible, e.b.Visible = flap, not flap
				end
			end
			if e.frame.Parent then
				e.frame.Position = UDim2.fromOffset(e.x + e.w / 2, e.y + e.h)
			end
		end
	end

	local function spawnMinion()
		local alive = 0
		for _, e in enemies do
			if e.alive then
				alive += 1
			end
		end
		if alive < 3 then
			local e = makeEnemy("E", (math.random() < 0.5 and 3 or W - 4) * T, 6 * T)
			e.vx = e.x < W * T / 2 and 110 or -110
		end
	end

	local function updateBoss(dt)
		local b = boss
		b.inv = math.max(0, b.inv - dt)
		b.t -= dt
		if b.state == "dead" then
			b.frame.Visible = math.floor(b.t * 12) % 2 == 0
			b.frame.Size = UDim2.fromOffset(150 + (1.6 - b.t) * 60, math.max(10, 130 * b.t / 1.6))
			b.frame.Position = UDim2.fromOffset(b.x + b.w / 2, b.y + b.h)
			if b.t <= 0 then
				b.frame:Destroy()
				boss = nil
				bossBar.Visible = false
				-- флаг победы в центре арены
				spawnEntity("G", 16, ROWS - 3)
			end
			return
		end
		local speed = 140 + (b.maxHp - b.hp) * 45
		local px = p.x + p.w / 2
		local bx = b.x + b.w / 2
		if b.state == "intro" then
			b.vx = 0
			if b.t <= 0 then
				b.state, b.t = "walk", 1.5
			end
		elseif b.state == "walk" then
			b.vx = (px < bx and -1 or 1) * speed
			if b.t <= 0 then
				b.state, b.t = "crouch", 0.45
			end
		elseif b.state == "crouch" then
			b.vx = 0
			if b.t <= 0 then
				b.state = "air"
				b.vy = -1350
				b.vx = math.clamp((px - bx) / 1.0, -650, 650)
				b.onGround = false
				ctx.audio:Play("move", { volume = 0.5, pitch = 0.5 })
			end
		elseif b.state == "hurt" then
			if b.t <= 0 then
				b.state, b.t = "walk", 1
			end
		end
		b.vy = math.min(b.vy + GRAVITY * dt, MAX_FALL)
		if moveX(b, b.vx * dt) then
			b.vx = -b.vx
		end
		local hit = moveY(b, b.vy * dt, false)
		if hit == "floor" then
			b.vy = 0
			if b.state == "air" then
				b.state, b.t = "walk", 1 + b.hp * 0.2
				shake = 0.35
				ctx.input:Rumble(0.9, 0.3)
				ctx.audio:Play("explosion", { volume = 0.7, pitch = 0.5 })
				burst(b.x + b.w / 2, b.y + b.h, hex(theme.grass), 10, 380)
				if b.hp <= 3 then
					spawnMinion()
				end
			end
		end
		local w, h = 150, 130
		if b.state == "crouch" then
			w, h = 172, 104
		elseif b.state == "air" then
			w, h = 136, 146
		end
		b.frame.Size = UDim2.fromOffset(w, h)
		b.frame.Visible = b.inv == 0 or math.floor(b.inv * 12) % 2 == 0
		b.frame.Position = UDim2.fromOffset(b.x + b.w / 2, b.y + b.h)
		bossFill.Size = UDim2.fromScale(math.max(b.hp, 0) / b.maxHp, 1)
	end

	local function interact(prevBottom)
		for _, e in enemies do
			if e.alive and overlap(p, e) then
				if p.vy > 0 and prevBottom <= e.y + 16 then
					stomp(e)
				else
					hurt(e.x + e.w / 2)
				end
			end
		end
		if boss and boss.state ~= "dead" and overlap(p, boss) then
			if p.vy > 0 and prevBottom <= boss.y + 26 then
				if boss.inv == 0 then
					bossHit()
				else
					p.vy = -700
				end
			elseif boss.state ~= "hurt" then
				hurt(boss.x + boss.w / 2)
			end
		end
	end

	local function pickups()
		local cx, cy = p.x + p.w / 2, p.y + p.h / 2
		local function near(item, radius)
			return math.abs(item.x - cx) < p.w / 2 + radius and math.abs(item.y - cy) < p.h / 2 + radius
		end
		for i = #coins, 1, -1 do
			local c = coins[i]
			if near(c, 14) then
				c.frame:Destroy()
				table.remove(coins, i)
				addCoins(1)
				ctx.audio:Play("confirm", { volume = 0.35, pitch = 2 })
				burst(c.x, c.y, hex("#F9C74F"), 4, 180)
			end
		end
		for i = #gems, 1, -1 do
			local g = gems[i]
			if near(g, 16) then
				g.frame:Destroy()
				table.remove(gems, i)
				gemsFound["l" .. levelIndex] = true
				gemThisRun = true
				ctx.save:Set("gems", gemsFound)
				gemIcon.BackgroundColor3 = hex("#4CC9F0")
				ctx.audio:Play("notify", { volume = 0.8, pitch = 1.6 })
				burst(g.x, g.y, hex("#4CC9F0"), 14, 360)
				particle(g.x, g.y - 50, { text = "SECRET GEM!", size = 34, color = hex("#4CC9F0"), vy = -90, life = 1.4 })
				ctx.trophies:Unlock("secret_gem")
				if gemCount() >= GEM_LEVELS then
					ctx.trophies:Unlock("all_gems")
				end
			end
		end
		for i = #hearts, 1, -1 do
			local h = hearts[i]
			if near(h, 12) then
				h.frame:Destroy()
				table.remove(hearts, i)
				p.hp = math.min(3, p.hp + 1)
				ctx.audio:Play("confirm", { volume = 0.5, pitch = 1.4 })
				particle(h.x, h.y - 40, { text = "HEART +1", size = 26, color = hex("#EF476F"), vy = -100, life = 0.8 })
			end
		end
		for _, cp in checkpoints do
			if not cp.active and cx > cp.x then
				cp.active = true
				cp.flag.BackgroundColor3 = hex("#43AA8B")
				ctx.audio:Play("confirm", { volume = 0.5, pitch = 1.1 })
				particle(cp.x + 50, cp.sy - 120, { text = "CHECKPOINT", size = 26, vy = -80, life = 1 })
				saveProgress()
			end
		end
		-- шипы: нижняя половина плитки
		local bottom = p.y + p.h
		for c = colOf(p.x + 6), colOf(p.x + p.w - 6) do
			for r = rowOf(p.y), rowOf(bottom - 1) do
				if tileAt(c, r) == "^" and bottom > (r - 1) * T + 32 then
					hurt((c - 0.5) * T)
					if state == "play" then
						p.vy = -800
					end
					return
				end
			end
		end
		if goal and overlap(p, goal) then
			finishLevel()
		end
	end

	local function updatePlay(dt)
		levelTime += dt
		local axes = ctx.input:GetAxes()
		local move = math.abs(axes.lx) > 0.2 and axes.lx or 0
		local running = ctx.input:IsDown("square") or ctx.input:IsDown("r2") or ctx.input:IsDown("l2")
		local jumpHeld = ctx.input:IsDown("cross") or (ctx.input:Device() == "keyboard" and ctx.input:IsDown("up"))

		p.buffer = math.max(0, p.buffer - dt)
		p.invuln = math.max(0, p.invuln - dt)
		p.coyote = p.onGround and COYOTE or math.max(0, p.coyote - dt)
		if move ~= 0 then
			p.face = move > 0 and 1 or -1
		end
		local accel = p.onGround and (move == 0 and FRICTION or ACCEL_GROUND) or ACCEL_AIR
		p.vx = approach(p.vx, move * (running and RUN or WALK), accel * dt)
		if p.buffer > 0 and p.coyote > 0 then
			p.vy = -JUMP_SPEED
			p.buffer, p.coyote = 0, 0
			p.onGround, p.onPlat = false, nil
			ctx.audio:Play("move", { volume = 0.35, pitch = 1.8 })
		end
		local g = GRAVITY
		if p.vy < 0 and not jumpHeld then
			g *= 2.6 -- отпустил прыжок — прыжок ниже
		end
		p.vy = math.min(p.vy + g * dt, MAX_FALL)

		updateEnemies(dt)
		if boss then
			updateBoss(dt)
		end

		local steps = math.max(1, math.ceil(dt * 120))
		local sdt = dt / steps
		local grounded, standOn = false, nil
		for _ = 1, steps do
			updatePlatforms(sdt)
			local prevBottom = p.y + p.h
			if moveX(p, p.vx * sdt) then
				p.vx = 0
			end
			local hit, info, cols = moveY(p, p.vy * sdt, true)
			if hit == "floor" then
				p.vy = 0
				grounded, standOn = true, info
			elseif hit == "ceil" then
				p.vy = 0
				bump(info, cols)
			end
			p.onPlat = standOn
			interact(prevBottom)
			if state ~= "play" then
				return
			end
		end
		p.onGround = grounded
		if not grounded then
			p.onPlat = nil
		end
		pickups()
		if state == "play" and p.y > SH + 60 then
			p.hp = 0
			die()
		end
	end

	local function updateDying(dt)
		dyingTime -= dt
		p.vy += GRAVITY * dt
		p.y += p.vy * dt
		playerFrame.Rotation += 400 * dt
		updateEnemies(dt)
		if dyingTime <= 0 then
			respawn()
		end
	end

	local function render(dt)
		-- камера
		local target = p.x + p.w / 2 - SW * 0.42
		camX += (target - camX) * math.min(1, dt * 8)
		camX = math.clamp(camX, 0, math.max(0, W * T - SW))
		local sx, sy = 0, 0
		if shake > 0 then
			shake -= dt
			sx, sy = math.random(-9, 9), math.random(-9, 9)
		end
		layer.Position = UDim2.fromOffset(-math.floor(camX) + sx, sy)
		local first = math.floor((camX - T) / (CHUNK * T)) + 1
		local last = math.floor((camX + SW + T) / (CHUNK * T)) + 1
		for i, chunk in chunks do
			chunk.Visible = i >= first and i <= last
		end
		for _, d in bgDecor do
			local span = SW + d.w + 400
			d.frame.Position = UDim2.fromOffset((d.x - camX * d.factor) % span - d.w - 200, d.y)
		end
		-- игрок
		p.animT += dt
		local walking = p.onGround and math.abs(p.vx) > 40 and math.floor(p.animT * 9) % 2 == 1
		local frameB = not p.onGround or walking
		local right = p.face > 0
		playerSprites.ra.Visible = right and not frameB
		playerSprites.rb.Visible = right and frameB
		playerSprites.la.Visible = not right and not frameB
		playerSprites.lb.Visible = not right and frameB
		playerFrame.Position = UDim2.fromOffset(p.x + p.w / 2, p.y + p.h + 2)
		playerFrame.Visible = state == "dying" or p.invuln == 0 or math.floor(p.invuln * 14) % 2 == 0
		for _, pl in platforms do
			pl.frame.Position = UDim2.fromOffset(pl.x, pl.y)
		end
		-- монеты крутятся, кристаллы покачиваются
		local spin = math.abs(math.cos(clock * 4))
		for _, c in coins do
			c.frame.Size = UDim2.fromOffset(6 + 26 * spin, 36)
		end
		for _, g in gems do
			g.frame.Position = UDim2.fromOffset(g.x - g.ox, g.y + math.sin(clock * 3) * 6)
		end
		for _, h in hearts do
			h.frame.Position = UDim2.fromOffset(h.x - h.ox, h.y + math.sin(clock * 4) * 4)
		end
		for i = #particles, 1, -1 do
			local q = particles[i]
			q.life -= dt
			q.vy += q.g * dt
			q.x += q.vx * dt
			q.y += q.vy * dt
			q.frame.Position = UDim2.fromOffset(q.x, q.y)
			if q.life <= 0 then
				q.frame:Destroy()
				table.remove(particles, i)
			end
		end
		-- HUD
		for i, slot in heartSlots do
			slot.full.Visible = p.hp >= i
		end
		coinText.Text = `x {levelCoins}`
		timeText.Text = fmtTime(levelTime)
		if bannerTime > 0 then
			bannerTime -= dt
			banner.Visible = bannerTime > 0
		end
	end

	ctx.input:On("press", function(btn)
		if state == "title" then
			local count = #LEVELS + 1
			if btn == "up" or btn == "down" then
				titleIndex = (titleIndex - 1 + (btn == "down" and 1 or -1)) % count + 1
				ctx.audio:Play("move", { volume = 0.3, pitch = 1.6 })
				drawTitle()
			elseif btn == "cross" then
				if titleIndex == count then
					ctx:Exit()
				elseif titleIndex <= unlocked then
					ctx.audio:Play("confirm")
					startLevel(titleIndex)
				else
					ctx.audio:Play("error")
				end
			elseif btn == "circle" then
				ctx:Exit()
			end
		elseif state == "play" then
			if btn == "options" then
				openPause()
			elseif btn == "cross" or (btn == "up" and ctx.input:Device() == "keyboard") then
				p.buffer = BUFFER
			end
		elseif menu then
			if btn == "up" or btn == "down" then
				menu.index = (menu.index - 1 + (btn == "down" and 1 or -1)) % #menu.items + 1
				ctx.audio:Play("move", { volume = 0.3, pitch = 1.6 })
				drawMenu()
			elseif btn == "cross" then
				ctx.audio:Play("confirm", { volume = 0.5 })
				menu.onSelect(menu.index)
			elseif (btn == "circle" or btn == "options") and menu.onBack then
				menu.onBack()
			end
		end
	end)

	-- Кнопка PS ставит систему на паузу: открываем и своё меню паузы
	ctx:On("pause", function()
		if state == "play" then
			openPause()
		end
	end)
	ctx:On("exit", saveProgress)

	ctx:Loop(function(dt)
		clock += dt
		if state == "title" then
			local x = (clock * 160) % (SW + 300) - 150
			titleHero.Position = UDim2.fromOffset(x, SH - 90)
			local step = math.floor(clock * 8) % 2 == 0
			heroA.Visible, heroB.Visible = step, not step
			titleSlime.Position = UDim2.fromOffset((x + 900) % (SW + 300) - 150, SH - 90)
			titleSlime.Size = UDim2.fromOffset(70 + math.sin(clock * 8) * 4, 49 - math.sin(clock * 8) * 4)
			return
		end
		if not layer then
			return
		end
		if state == "play" then
			updatePlay(dt)
		elseif state == "dying" then
			updateDying(dt)
		end
		if layer then
			render(dt)
		end
	end)

	-- состояние для проверки без Studio (tools/mock)
	Game.probe = function()
		return { state = state, p = p, level = levelIndex, coins = levelCoins, boss = boss, deaths = deaths, enemies = enemies, L = L, platforms = platforms }
	end

	showTitle()
end

return Game
