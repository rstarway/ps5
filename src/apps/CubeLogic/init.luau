-- Cube Logic — 3D-головоломка: кати куб по клеткам, светящаяся грань должна смотреть вверх на выходе.
-- 3D-поле в ctx.world, интерфейс в ctx.gui (прозрачный), прогресс в ctx.save.
local Levels = require(script.levels)

local Game = {}

local W, H = 1920, 1080
local TILE = 4
local ORIGIN = Vector3.new(0, 300, 0)
local ROLL_TIME = 0.16
local SLIDE_TIME = 0.09

-- куда уходит светящаяся грань при перекате в сторону
local ROLL = {
	east = { top = "east", east = "bottom", bottom = "west", west = "top" },
	west = { top = "west", west = "bottom", bottom = "east", east = "top" },
	north = { top = "north", north = "bottom", bottom = "south", south = "top" },
	south = { top = "south", south = "bottom", bottom = "north", north = "top" },
}
local DIRS = {
	up = { name = "north", dx = 0, dy = -1 },
	down = { name = "south", dx = 0, dy = 1 },
	left = { name = "west", dx = -1, dy = 0 },
	right = { name = "east", dx = 1, dy = 0 },
}
local START_ROT = {
	top = CFrame.new(),
	bottom = CFrame.Angles(math.pi, 0, 0),
	east = CFrame.Angles(0, 0, -math.pi / 2),
	west = CFrame.Angles(0, 0, math.pi / 2),
	north = CFrame.Angles(-math.pi / 2, 0, 0),
	south = CFrame.Angles(math.pi / 2, 0, 0),
}

local function key(x, y)
	return x .. "," .. y
end

-- убирает накопленную погрешность после поворота на 90°
local function snap(cf)
	local c = { cf:GetComponents() }
	for i = 4, 12 do
		c[i] = math.round(c[i])
	end
	return CFrame.new(0, 0, 0, table.unpack(c, 4, 12))
end

function Game.launch(ctx)
	local ui = ctx.ui
	local hex = ui.hex
	local ACCENT = hex("#4CC9F0")
	local NAVY = hex("#14213D")

	ctx.gui.BackgroundTransparency = 1
	local canvas = ui.canvas(ctx.gui, W, H)

	-- сохранения: best["L3"] = лучший результат в ходах
	local best = ctx.save:Get("best", {})
	local lastLevel = ctx.save:Get("last", 1)

	local function cleared(i)
		return best["L" .. i] ~= nil
	end
	local function atPar(i)
		return cleared(i) and best["L" .. i] <= Levels[i].par
	end
	local function unlocked(i)
		return i == 1 or cleared(i - 1) or cleared(i)
	end
	local function clearedCount()
		local n = 0
		for i = 1, #Levels do
			if cleared(i) then
				n += 1
			end
		end
		return n
	end

	------------------------------------------------------------------ 3D
	ctx.camera.CameraType = Enum.CameraType.Scriptable
	ctx.camera.FieldOfView = 50

	local function part(props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = Enum.Material.SmoothPlastic
		for k, v in props do
			p[k] = v
		end
		p.Parent = props.Parent or ctx.world
		return p
	end

	-- бездна под полем
	part({ Name = "Abyss", Size = Vector3.new(600, 1, 600), Position = ORIGIN - Vector3.new(0, 80, 0), Color = hex("#070B18") })
	for i = 1, 40 do
		local r = math.random()
		part({
			Name = "Spark",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (0.4 + r * 0.8),
			Position = ORIGIN + Vector3.new(math.random(-160, 160), -math.random(15, 70), math.random(-160, 160)),
			Color = i % 3 == 0 and hex("#7B6CF6") or ACCENT,
			Material = Enum.Material.Neon,
			Transparency = 0.3,
		})
	end

	local board = Instance.new("Folder")
	board.Name = "Board"
	board.Parent = ctx.world

	local cube = part({ Name = "Cube", Size = Vector3.new(TILE, TILE, TILE), Color = hex("#E9F2FF"), Material = Enum.Material.SmoothPlastic })
	local markPart = part({ Name = "Mark", Size = Vector3.new(TILE * 0.72, 0.12, TILE * 0.72), Color = ACCENT, Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Color = ACCENT
	light.Range = 14
	light.Brightness = 1.5
	light.Parent = markPart

	------------------------------------------------------------------ состояние уровня
	local level, levelIndex
	local grid = {} -- key -> символ карты
	local tiles = {} -- key -> Part
	local crumbleTweens = {} -- key -> Tween падающей клетки
	local cx, cy = 0, 0
	local state -- { x, y, mark, bridges, crumbled = {key=true}, moves }
	local rot = CFrame.new()
	local history = {}
	local anim = nil
	local queued = nil
	local mode = "menu" -- menu | play | paused | win
	local undone, fell = false, false

	local function cellPos(x, y)
		return ORIGIN + Vector3.new((x - cx) * TILE, 0, (y - cy) * TILE)
	end
	local function cubeCenter(x, y)
		return cellPos(x, y) + Vector3.new(0, TILE / 2 + 0.5, 0)
	end

	-- что сейчас лежит в клетке: "." пол, " " пустота, "#" стена, E I T C
	local function tileAt(x, y, s)
		local c = grid[key(x, y)] or " "
		if c == "B" or c == "b" then
			local on = (c == "b") ~= s.bridges
			return on and "." or " "
		end
		if c == "C" and s.crumbled[key(x, y)] then
			return " "
		end
		if c == "S" then
			return "."
		end
		return c
	end

	local function placeCube(c)
		cube.CFrame = c
		markPart.CFrame = c * CFrame.new(0, TILE / 2 + 0.03, 0)
	end

	local function refreshTiles()
		for k, p in tiles do
			local c = grid[k]
			if c == "B" or c == "b" then
				local on = (c == "b") ~= state.bridges
				p.Transparency = on and 0 or 0.85
				p.Material = on and Enum.Material.SmoothPlastic or Enum.Material.ForceField
			elseif c == "C" then
				local x, y = string.match(k, "(-?%d+),(-?%d+)")
				local home = cellPos(tonumber(x), tonumber(y)) - Vector3.new(0, 0.5, 0)
				if state.crumbled[k] then
					if not crumbleTweens[k] then
						crumbleTweens[k] = ui.tween(p, 0.5, { Position = home - Vector3.new(0, 12, 0), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					end
				else
					if crumbleTweens[k] then
						crumbleTweens[k]:Cancel()
						crumbleTweens[k] = nil
					end
					p.Position = home
					p.Transparency = 0
				end
			end
		end
	end

	local function frameCamera()
		local w, h = level.w, level.h
		local span = math.max(w * 1.15, h * 1.6, 6) * TILE
		local target = ORIGIN + Vector3.new(0, 0, TILE * 0.4)
		ctx.camera.CFrame = CFrame.lookAt(target + Vector3.new(0, span * 0.95, span * 0.7), target)
	end

	------------------------------------------------------------------ интерфейс
	local hud = ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H), Visible = false, Parent = canvas })
	local title = ui.text("", { Size = UDim2.fromOffset(1200, 60), Position = UDim2.fromOffset(60, 40), TextSize = 46, Font = ctx.theme.FontHeavy, Parent = hud })
	local stats = ui.text("", { Size = UDim2.fromOffset(1200, 40), Position = UDim2.fromOffset(60, 104), TextSize = 30, TextColor3 = ctx.theme.Colors.SubText, Parent = hud })
	local tip = ui.text("", {
		AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(1400, 50), Position = UDim2.fromOffset(W / 2, 880),
		TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, Parent = hud,
	})
	local keys = ui.text("", {
		AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(1600, 40), Position = UDim2.fromOffset(W / 2, 990),
		TextSize = 26, TextColor3 = ctx.theme.Colors.Muted, TextXAlignment = Enum.TextXAlignment.Center, Parent = hud,
	})
	local banner = ui.text("", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(W, 300), Position = UDim2.fromOffset(W / 2, 420),
		TextSize = 44, Font = ctx.theme.FontBold, TextXAlignment = Enum.TextXAlignment.Center, Visible = false, Parent = canvas,
		TextStrokeTransparency = 0.4,
	})

	-- меню выбора уровня
	local menu = ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H), Parent = canvas })
	ui.new("Frame", { Size = UDim2.fromOffset(W, H), BackgroundColor3 = NAVY, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = menu })
	ui.text("CUBE LOGIC", {
		Size = UDim2.fromOffset(W, 110), Position = UDim2.fromOffset(0, 70), TextSize = 96, Font = ctx.theme.FontHeavy,
		TextColor3 = ACCENT, TextXAlignment = Enum.TextXAlignment.Center, Parent = menu,
	})
	local menuSub = ui.text("", {
		Size = UDim2.fromOffset(W, 40), Position = UDim2.fromOffset(0, 190), TextSize = 30,
		TextColor3 = ctx.theme.Colors.SubText, TextXAlignment = Enum.TextXAlignment.Center, Parent = menu,
	})
	ui.text("", {
		Name = "Keys", Size = UDim2.fromOffset(W, 40), Position = UDim2.fromOffset(0, 990), TextSize = 26,
		TextColor3 = ctx.theme.Colors.Muted, TextXAlignment = Enum.TextXAlignment.Center, Parent = menu,
	})
	local COLS, CARD_W, CARD_H, GAP = 4, 330, 170, 34
	local gridLeft = (W - (COLS * CARD_W + (COLS - 1) * GAP)) / 2
	local cards = {}
	local selected = math.clamp(lastLevel, 1, #Levels)
	for i, lv in Levels do
		local col, row = (i - 1) % COLS, (i - 1) // COLS
		local card = ui.new("TextButton", {
			Text = "", AutoButtonColor = false, BorderSizePixel = 0,
			Size = UDim2.fromOffset(CARD_W, CARD_H),
			Position = UDim2.fromOffset(gridLeft + col * (CARD_W + GAP), 290 + row * (CARD_H + GAP)),
			BackgroundColor3 = ctx.theme.Colors.Card, Parent = menu,
		}, { ui.corner(18) })
		local stroke = ui.stroke(ACCENT, 4, 1)
		stroke.Parent = card
		local num = ui.text(tostring(i), { Size = UDim2.fromOffset(120, 70), Position = UDim2.fromOffset(24, 16), TextSize = 60, Font = ctx.theme.FontHeavy, Parent = card })
		local name = ui.text(lv.name, { Size = UDim2.fromOffset(CARD_W - 48, 36), Position = UDim2.fromOffset(24, 88), TextSize = 28, Font = ctx.theme.FontBold, Parent = card })
		local info = ui.text("", { Size = UDim2.fromOffset(CARD_W - 48, 30), Position = UDim2.fromOffset(24, 124), TextSize = 24, TextColor3 = ctx.theme.Colors.SubText, Parent = card })
		local stars = ui.text("", {
			Size = UDim2.fromOffset(150, 50), Position = UDim2.fromOffset(CARD_W - 174, 22), TextSize = 40,
			TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = ctx.theme.Colors.Gold, Parent = card,
		})
		cards[i] = { frame = card, stroke = stroke, num = num, name = name, info = info, stars = stars }
	end

	local function drawMenu()
		menuSub.Text = `{clearedCount()} / {#Levels} cleared · Roll onto the exit with the glowing face up`
		menu.Keys.Text = `Arrows / stick — choose    {ctx.input:Glyph("cross")} — play    {ctx.input:Glyph("circle")} — quit`
		for i, c in cards do
			local open = unlocked(i)
			local isSel = i == selected
			c.stroke.Transparency = isSel and 0 or 1
			c.frame.BackgroundColor3 = isSel and ctx.theme.Colors.CardLight or ctx.theme.Colors.Card
			c.frame.Size = UDim2.fromOffset(isSel and CARD_W + 10 or CARD_W, isSel and CARD_H + 10 or CARD_H)
			c.num.TextTransparency = open and 0 or 0.6
			c.name.TextTransparency = open and 0 or 0.6
			if not open then
				c.info.Text = "Locked"
				c.stars.Text = "🔒"
			elseif cleared(i) then
				c.info.Text = `Best {best["L" .. i]} · Par {Levels[i].par}`
				c.stars.Text = atPar(i) and "★★" or "★☆"
			else
				c.info.Text = `Par {Levels[i].par}`
				c.stars.Text = "☆☆"
			end
		end
	end

	local function drawHud()
		title.Text = `{levelIndex}. {level.name}`
		local b = best["L" .. levelIndex]
		stats.Text = `Moves {state.moves}    Par {level.par}` .. (b and `    Best {b}` or "")
		keys.Text = `{ctx.input:Glyph("square")} undo    {ctx.input:Glyph("triangle")} restart    {ctx.input:Glyph("circle")} levels    {ctx.input:Glyph("options")} pause`
	end

	local bannerToken = 0
	local function showBanner(text, seconds)
		bannerToken += 1
		local token = bannerToken
		banner.Text = text
		banner.Visible = true
		if seconds then
			task.delay(seconds, function()
				if token == bannerToken then
					banner.Visible = false
				end
			end)
		end
	end
	local function hideBanner()
		bannerToken += 1
		banner.Visible = false
	end

	------------------------------------------------------------------ сборка уровня
	local function buildBoard()
		board:ClearAllChildren()
		tiles = {}
		for _, tw in crumbleTweens do
			tw:Cancel()
		end
		crumbleTweens = {}
		for k, c in grid do
			local x, y = string.match(k, "(-?%d+),(-?%d+)")
			x, y = tonumber(x), tonumber(y)
			local base = cellPos(x, y)
			if c == "#" then
				part({ Name = "Wall", Size = Vector3.new(TILE, TILE * 0.9, TILE), Position = base + Vector3.new(0, TILE * 0.45 - 1, 0), Color = hex("#2B3A67"), Parent = board })
			elseif c ~= " " then
				local color, material = hex("#24345E"), Enum.Material.SmoothPlastic
				if c == "I" then
					color, material = hex("#A8E6FF"), Enum.Material.Glass
				elseif c == "C" then
					color, material = hex("#C9844A"), Enum.Material.Slate
				elseif c == "T" then
					color = hex("#F7B32B")
				elseif c == "B" or c == "b" then
					color = hex("#9D7BFF")
				elseif c == "E" then
					color = hex("#0B132B")
				end
				local p = part({ Name = "Tile", Size = Vector3.new(TILE - 0.2, 1, TILE - 0.2), Position = base - Vector3.new(0, 0.5, 0), Color = color, Material = material, Parent = board })
				if c == "I" then
					p.Transparency = 0.15
				end
				tiles[k] = p
				if c == "E" then
					-- светящаяся рамка выхода и стрелка «грань вверх»
					for _, o in { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } } do
						local len = o[1] == 0 and TILE - 0.2 or 0.35
						local dep = o[1] == 0 and 0.35 or TILE - 0.2
						part({
							Name = "ExitGlow", Size = Vector3.new(len, 0.2, dep), Material = Enum.Material.Neon, Color = ACCENT,
							Position = base + Vector3.new(o[1] * (TILE / 2 - 0.27), 0.05, o[2] * (TILE / 2 - 0.27)), Parent = board,
						})
					end
					local beam = part({ Name = "ExitBeam", Size = Vector3.new(TILE * 0.5, 0.1, TILE * 0.5), Material = Enum.Material.Neon, Color = ACCENT, Transparency = 0.4, Position = base + Vector3.new(0, 0.02, 0), Parent = board })
					local l = Instance.new("PointLight")
					l.Color = ACCENT
					l.Range = 12
					l.Parent = beam
				elseif c == "T" then
					part({ Name = "Button", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, TILE * 0.55, TILE * 0.55), CFrame = CFrame.new(base + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = hex("#FFD166"), Material = Enum.Material.Neon, Parent = board })
				elseif c == "C" then
					p.Name = "Crumble"
				end
			end
		end
	end

	local function startLevel(i)
		levelIndex = i
		level = Levels[i]
		grid = {}
		local sx, sy = 1, 1
		level.w, level.h = 0, #level.map
		for y, row in level.map do
			level.w = math.max(level.w, #row)
			for x = 1, #row do
				local c = string.sub(row, x, x)
				if c ~= " " then
					grid[key(x, y)] = c
				end
				if c == "S" then
					sx, sy = x, y
				end
			end
		end
		cx, cy = (level.w + 1) / 2, (level.h + 1) / 2
		state = { x = sx, y = sy, mark = level.mark or "top", bridges = false, crumbled = {}, moves = 0 }
		history = {}
		anim, queued = nil, nil
		undone, fell = false, false
		rot = START_ROT[state.mark]
		cube.Transparency = 0
		buildBoard()
		refreshTiles()
		placeCube(CFrame.new(cubeCenter(sx, sy)) * rot)
		frameCamera()
		mode = "play"
		menu.Visible = false
		hud.Visible = true
		hideBanner()
		tip.Text = level.tip or ""
		drawHud()
		lastLevel = i
		ctx.save:Set("last", i)
	end

	local function openMenu()
		mode = "menu"
		anim, queued = nil, nil
		hud.Visible = false
		hideBanner()
		menu.Visible = true
		drawMenu()
	end

	local function copyState(s)
		local crumbled = {}
		for k in s.crumbled do
			crumbled[k] = true
		end
		return { x = s.x, y = s.y, mark = s.mark, bridges = s.bridges, crumbled = crumbled, moves = s.moves }
	end

	------------------------------------------------------------------ победа
	local function winLevel()
		mode = "win"
		local k = "L" .. levelIndex
		local moves = state.moves
		local newBest = best[k] == nil or moves < best[k]
		if newBest then
			best[k] = moves
			ctx.save:Set("best", best)
		end
		ctx.audio:Play("trophy", { volume = 0.5, pitch = 1.2 })
		ctx.input:Rumble(0.4, 0.2)

		if levelIndex == 1 then
			ctx.trophies:Unlock("first_roll")
		end
		if levelIndex == 6 then
			ctx.trophies:Unlock("skater")
		end
		if moves <= level.par then
			ctx.trophies:Unlock("perfect")
		end
		if levelIndex >= 7 and not undone and not fell then
			ctx.trophies:Unlock("sure_footed")
		end
		local n = clearedCount()
		if n >= 6 then
			ctx.trophies:Unlock("halfway")
		end
		if n >= #Levels then
			ctx.trophies:Unlock("cube_master")
			local all = true
			for i = 1, #Levels do
				all = all and atPar(i)
			end
			if all then
				ctx.trophies:Unlock("flawless")
			end
		end

		local parText = moves <= level.par and "★★  Par!" or `★☆  Par is {level.par}`
		local nextText = levelIndex < #Levels and `{ctx.input:Glyph("cross")} next level` or `{ctx.input:Glyph("cross")} levels — you solved them all!`
		showBanner(`Level clear in {moves} moves{newBest and " · new best" or ""}\n{parText}\n\n{nextText}    {ctx.input:Glyph("triangle")} retry`)
		-- куб уходит в выход
		local from = cube.CFrame
		anim = { t = 0, dur = 0.6, kind = "sink", from = from }
	end

	------------------------------------------------------------------ ходы
	local function tryMove(dirName)
		local d = DIRS[dirName]
		local s = state
		local nx, ny = s.x + d.dx, s.y + d.dy
		if tileAt(nx, ny, s) == "#" then
			ctx.audio:Play("error", { volume = 0.25, pitch = 1.6 })
			ctx.input:Rumble(0.2, 0.08)
			return
		end
		table.insert(history, { state = copyState(s), rot = rot })
		local leaving = key(s.x, s.y)
		if grid[leaving] == "C" then
			s.crumbled[leaving] = true
		end
		s.moves += 1
		s.mark = ROLL[d.name][s.mark] or s.mark
		s.x, s.y = nx, ny

		-- путь: перекат на одну клетку, затем скольжение по льду
		local steps = { { kind = "roll", x = nx, y = ny } }
		local result = "ok"
		local cx2, cy2 = nx, ny
		while true do
			local t = tileAt(cx2, cy2, s)
			if t == " " then
				result = "fall"
				break
			end
			if t == "T" then
				s.bridges = not s.bridges
				steps[#steps].toggle = true
			end
			if t == "E" and s.mark == "top" then
				result = "win"
				break
			end
			if t ~= "I" then
				break
			end
			local fx, fy = cx2 + d.dx, cy2 + d.dy
			if tileAt(fx, fy, s) == "#" then
				break
			end
			cx2, cy2 = fx, fy
			s.x, s.y = fx, fy
			table.insert(steps, { kind = "slide", x = fx, y = fy })
		end
		if result == "ok" and tileAt(s.x, s.y, s) == "E" then
			result = "wrongside"
		end

		ctx.audio:Play("move", { volume = 0.5, pitch = 0.8 + math.random() * 0.2 })
		refreshTiles()
		anim = { steps = steps, i = 1, t = 0, dir = d, result = result, from = cube.CFrame }
		drawHud()
	end

	local function undo()
		local last = table.remove(history)
		if not last then
			return
		end
		undone = true
		anim, queued = nil, nil
		state = last.state
		rot = last.rot
		refreshTiles()
		placeCube(CFrame.new(cubeCenter(state.x, state.y)) * rot)
		hideBanner()
		ctx.audio:Play("back", { volume = 0.5 })
		drawHud()
	end

	local function finishSteps()
		local result = anim.result
		anim = nil
		if result == "fall" then
			fell = true
			ctx.trophies:Unlock("off_edge")
			ctx.audio:Play("hit", { volume = 0.5, pitch = 0.6 })
			ctx.input:Rumble(0.7, 0.3)
			anim = { kind = "fall", t = 0, dur = 0.9, from = cube.CFrame }
		elseif result == "win" then
			winLevel()
		elseif result == "wrongside" then
			ctx.audio:Play("error", { volume = 0.3 })
			showBanner("The glowing face must point up on the exit", 2.2)
		end
	end

	------------------------------------------------------------------ кадр
	ctx:Loop(function(dt)
		if not anim then
			if mode == "play" and queued then
				local q = queued
				queued = nil
				tryMove(q)
			end
			return
		end
		anim.t += dt
		if anim.kind == "fall" then
			local a = math.min(anim.t / anim.dur, 1)
			placeCube(anim.from * CFrame.new(0, -60 * a * a, 0) * CFrame.Angles(a * 2, 0, a * 1.3))
			if a >= 1 then
				anim = nil
				-- перезапуск уровня, ходы с начала
				local f = fell
				startLevel(levelIndex)
				fell = f
				showBanner("Into the void! Try again", 1.4)
			end
			return
		elseif anim.kind == "sink" then
			local a = math.min(anim.t / anim.dur, 1)
			placeCube(anim.from * CFrame.new(0, -TILE * 1.1 * a, 0))
			cube.Transparency = a * 0.8
			if a >= 1 then
				anim = nil
			end
			return
		end

		local step = anim.steps[anim.i]
		local dur = step.kind == "roll" and ROLL_TIME or SLIDE_TIME
		local a = math.min(anim.t / dur, 1)
		local d = anim.dir
		if step.kind == "roll" then
			local dirV = Vector3.new(d.dx, 0, d.dy)
			local center = anim.from.Position
			local pivot = center + dirV * (TILE / 2) - Vector3.new(0, TILE / 2, 0)
			local axis = Vector3.new(0, 1, 0):Cross(dirV)
			local r = CFrame.fromAxisAngle(axis, a * math.pi / 2)
			local rel = center - pivot
			local newCenter = pivot + r:VectorToWorldSpace(rel)
			local newRot = r * rot
			placeCube(CFrame.new(newCenter) * newRot)
			if a >= 1 then
				rot = snap(newRot)
			end
		else
			local target = cubeCenter(step.x, step.y)
			placeCube(CFrame.new(anim.from.Position:Lerp(target, a)) * rot)
		end
		if a >= 1 then
			placeCube(CFrame.new(cubeCenter(step.x, step.y)) * rot)
			if step.toggle then
				ctx.audio:Play("confirm", { volume = 0.6, pitch = 0.7 })
			end
			anim.i += 1
			anim.t = 0
			anim.from = cube.CFrame
			if anim.i > #anim.steps then
				finishSteps()
			end
		end
	end)

	------------------------------------------------------------------ пауза
	local pauseFrame = ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, H / 2), Size = UDim2.fromOffset(560, 420),
		BackgroundColor3 = ctx.theme.Colors.Panel, BackgroundTransparency = 0.05, Visible = false, ZIndex = 20, Parent = canvas,
	}, { ui.corner(24) })
	ui.text("Paused", { Size = UDim2.fromOffset(560, 80), Position = UDim2.fromOffset(0, 20), TextSize = 48, Font = ctx.theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 21, Parent = pauseFrame })
	local PAUSE_ITEMS = { "Resume", "Restart level", "Level select", "Quit game" }
	local pauseLabels = {}
	for i, label in PAUSE_ITEMS do
		pauseLabels[i] = ui.text(label, {
			Size = UDim2.fromOffset(460, 60), Position = UDim2.fromOffset(50, 100 + i * 66), TextSize = 34,
			TextXAlignment = Enum.TextXAlignment.Center, BackgroundColor3 = ACCENT, ZIndex = 21, Parent = pauseFrame,
		})
		ui.corner(14).Parent = pauseLabels[i]
	end
	local pauseIndex = 1
	local function drawPause()
		for i, l in pauseLabels do
			l.BackgroundTransparency = i == pauseIndex and 0.2 or 1
			l.TextColor3 = i == pauseIndex and NAVY or Color3.new(1, 1, 1)
		end
	end
	local resumeMode = "play"
	local function openPause()
		if mode == "paused" or mode == "menu" then
			return
		end
		resumeMode = mode
		mode = "paused"
		pauseIndex = 1
		pauseFrame.Visible = true
		drawPause()
	end
	local function closePause()
		pauseFrame.Visible = false
		mode = resumeMode
	end

	------------------------------------------------------------------ ввод
	ctx.input:On("press", function(btn)
		if mode == "menu" then
			local col = (selected - 1) % COLS
			if btn == "left" and col > 0 then
				selected -= 1
			elseif btn == "right" and col < COLS - 1 and selected < #Levels then
				selected += 1
			elseif btn == "up" and selected > COLS then
				selected -= COLS
			elseif btn == "down" and selected + COLS <= #Levels then
				selected += COLS
			elseif btn == "cross" then
				if unlocked(selected) then
					ctx.audio:Play("confirm")
					startLevel(selected)
				else
					ctx.audio:Play("error")
					ctx:Notify("Cube Logic", "Clear the previous level to unlock this one")
				end
				return
			elseif btn == "circle" then
				ctx:Exit()
				return
			else
				return
			end
			ctx.audio:Play("move")
			drawMenu()
		elseif mode == "paused" then
			if btn == "up" then
				pauseIndex = (pauseIndex - 2) % #PAUSE_ITEMS + 1
				ctx.audio:Play("move")
				drawPause()
			elseif btn == "down" then
				pauseIndex = pauseIndex % #PAUSE_ITEMS + 1
				ctx.audio:Play("move")
				drawPause()
			elseif btn == "circle" or btn == "options" then
				closePause()
			elseif btn == "cross" then
				closePause()
				if pauseIndex == 2 then
					startLevel(levelIndex)
				elseif pauseIndex == 3 then
					openMenu()
				elseif pauseIndex == 4 then
					ctx:Exit()
				end
			end
		elseif mode == "play" or mode == "win" then
			if btn == "options" then
				openPause()
			elseif btn == "circle" then
				ctx.audio:Play("back")
				selected = levelIndex
				openMenu()
			elseif btn == "triangle" then
				startLevel(levelIndex)
			elseif mode == "win" then
				if btn == "cross" and not anim then
					if levelIndex < #Levels then
						startLevel(levelIndex + 1)
					else
						selected = levelIndex
						openMenu()
					end
				end
			elseif btn == "square" then
				undo()
			elseif DIRS[btn] then
				if anim then
					queued = btn
				else
					tryMove(btn)
				end
			end
		end
	end)

	ctx:On("pause", function()
		openPause()
	end)

	-- ровно поставить куб и камеру на фон меню
	startLevel(math.clamp(lastLevel, 1, #Levels))
	if not unlocked(levelIndex) then
		startLevel(1)
	end
	openMenu()
end

return Game
