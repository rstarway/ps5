-- Шахматы: партия с компьютером (3 уровня) или вдвоём за одной консолью. Правила и компьютер в Engine.luau,
-- фигуры отрендерены в Blender (blender/chess_art.py → pieces.luau). Незаконченная партия сохраняется.
local AssetService = game:GetService("AssetService")

local Engine = require(script.Engine)

local Game = {}

local CELL = 108
local BOARD_X, BOARD_Y = 150, 108
local LEVELS = {
	{ name = "Easy", depth = 2, time = 0.4, noise = 90 },
	{ name = "Medium", depth = 3, time = 1.0, noise = 15 },
	{ name = "Hard", depth = 5, time = 2.0, noise = 0 },
}
local COLORS = { "White", "Black", "Random" }
local KIND_NAMES = { "pawn", "knight", "bishop", "rook", "queen", "king" }
local GLYPH = { "♟", "♞", "♝", "♜", "♛", "♚" }
local RESULT_TEXT = {
	stalemate = "Stalemate",
	fifty = "Draw by the 50-move rule",
	repetition = "Draw by threefold repetition",
	material = "Draw: not enough material",
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local LIGHT, DARK = rgb(206, 214, 232), rgb(70, 92, 140)

-- base64 RGBA → буфер для EditableImage
local B64 = {}
do
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, #alphabet do
		B64[string.byte(alphabet, i)] = i - 1
	end
end
local function decode(data, bytes)
	local out = buffer.create(bytes)
	local o = 0
	for i = 1, #data, 4 do
		local a, b, c, d = string.byte(data, i, i + 3)
		local n = B64[a] * 262144 + B64[b] * 4096 + (B64[c] or 0) * 64 + (B64[d] or 0)
		for k, v in { bit32.rshift(n, 16), bit32.band(bit32.rshift(n, 8), 255), bit32.band(n, 255) } do
			if o < bytes and (k == 1 or (k == 2 and c ~= 61) or (k == 3 and d ~= 61)) then
				buffer.writeu8(out, o, v)
				o += 1
			end
		end
	end
	return out
end

local spriteCache = nil
local function loadSprites()
	if spriteCache ~= nil then
		return spriteCache or nil
	end
	local ok, result = pcall(function()
		local data = require(script.pieces)
		local size = Vector2.new(data.size, data.size)
		local out = {}
		for key, b64 in data.sprites do
			local image = AssetService:CreateEditableImage({ Size = size })
			image:WritePixelsBuffer(Vector2.zero, size, decode(b64, data.size * data.size * 4))
			out[key] = Content.fromObject(image)
		end
		return out
	end)
	if not ok then
		warn("[Chess] piece sprites unavailable, using glyphs:", result)
	end
	spriteCache = ok and result or false
	return ok and result or nil
end

function Game.launch(ctx)
	local ui, theme, input = ctx.ui, ctx.theme, ctx.input
	ctx.gui.BackgroundColor3 = rgb(8, 12, 26)
	ui.gradient({ rgb(10, 18, 44), rgb(6, 8, 18) }, 90).Parent = ctx.gui
	local canvas = ui.canvas(ctx.gui)
	local sprites = loadSprites()

	local pos = Engine.new()
	local history = {} -- { move, san }
	local mode = "cpu" -- cpu | two
	local level, colorChoice = ctx.save:Get("level", 2), ctx.save:Get("color", 1)
	local human = 1 -- цвет игрока в режиме cpu
	local flipped = false
	local state = "menu" -- menu | play | promo | pause | over
	local cursor = { col = 4, row = 6 }
	local selected = nil
	local targets = {} -- [to] = { moves }
	local legal = {}
	local thinking, generation, exited = false, 0, false
	local hint = nil
	local status = "play"

	-- ===== доска =====
	local boardSize = CELL * 8
	local frameBack = ui.new("Frame", {
		Position = UDim2.fromOffset(BOARD_X - 40, BOARD_Y - 40), Size = UDim2.fromOffset(boardSize + 80, boardSize + 80),
		BackgroundColor3 = rgb(14, 20, 38), Parent = canvas,
	}, { ui.corner(18), ui.stroke(rgb(0, 112, 240), 3, 0.2) })
	local board = ui.new("Frame", {
		Position = UDim2.fromOffset(BOARD_X, BOARD_Y), Size = UDim2.fromOffset(boardSize, boardSize),
		BackgroundTransparency = 1, ClipsDescendants = false, Parent = canvas,
	})
	local fileLabels, rankLabels = {}, {}
	for i = 0, 7 do
		fileLabels[i] = ui.text("", {
			Size = UDim2.fromOffset(CELL, 34), Position = UDim2.fromOffset(BOARD_X + i * CELL, BOARD_Y + boardSize + 3),
			TextSize = 24, TextColor3 = theme.Colors.SubText, Font = theme.FontBold, TextXAlignment = Enum.TextXAlignment.Center, Parent = canvas,
		})
		rankLabels[i] = ui.text("", {
			Size = UDim2.fromOffset(34, CELL), Position = UDim2.fromOffset(BOARD_X - 37, BOARD_Y + i * CELL),
			TextSize = 24, TextColor3 = theme.Colors.SubText, Font = theme.FontBold, TextXAlignment = Enum.TextXAlignment.Center, Parent = canvas,
		})
	end

	local cells, pieceLabels = {}, {}
	local onCellClick -- задаётся ниже
	for row = 0, 7 do
		for col = 0, 7 do
			local i = row * 8 + col
			local cell = ui.new("TextButton", {
				Text = "", AutoButtonColor = false, BorderSizePixel = 0,
				Position = UDim2.fromOffset(col * CELL, row * CELL), Size = UDim2.fromOffset(CELL, CELL),
				BackgroundColor3 = (row + col) % 2 == 0 and LIGHT or DARK, Parent = board,
			})
			local tint = ui.new("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundTransparency = 1, Parent = cell })
			local dot = ui.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30),
				BackgroundColor3 = rgb(10, 20, 50), BackgroundTransparency = 0.55, Visible = false, ZIndex = 3, Parent = cell,
			}, { ui.corner(UDim.new(0.5, 0)) })
			local ring = ui.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(CELL - 14, CELL - 14),
				BackgroundTransparency = 1, Visible = false, ZIndex = 3, Parent = cell,
			}, { ui.corner(UDim.new(0.5, 0)), ui.stroke(rgb(10, 20, 50), 7, 0.45) })
			cells[i] = { frame = cell, tint = tint, dot = dot, ring = ring, base = cell.BackgroundColor3 }
			cell.Activated:Connect(function()
				if onCellClick then
					onCellClick(col, row)
				end
			end)
			local piece = ui.new("ImageLabel", {
				BackgroundTransparency = 1, Size = UDim2.fromOffset(CELL, CELL), Position = UDim2.fromOffset(col * CELL, row * CELL),
				ZIndex = 4, Parent = board,
			})
			ui.text("", {
				Name = "Glyph", Size = UDim2.fromScale(1, 1), TextSize = 82, Font = theme.FontBold,
				TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Visible = sprites == nil, Parent = piece,
			})
			pieceLabels[i] = piece
		end
	end
	local cursorFrame = ui.new("Frame", {
		Size = UDim2.fromOffset(CELL, CELL), BackgroundTransparency = 1, ZIndex = 6, Parent = board,
	}, { ui.corner(8), ui.stroke(rgb(255, 255, 255), 5, 0) })

	local function setPieceImage(label, piece)
		local glyph = label:FindFirstChild("Glyph")
		if piece == 0 then
			label.ImageTransparency = 1
			if glyph then glyph.Text = "" end
			return
		end
		local key = (piece > 0 and "w" or "b") .. KIND_NAMES[math.abs(piece)]
		if sprites and sprites[key] then
			label.ImageContent = sprites[key]
			label.ImageTransparency = 0
		elseif glyph then
			glyph.Text = GLYPH[math.abs(piece)]
			glyph.TextColor3 = piece > 0 and rgb(250, 246, 236) or rgb(20, 20, 26)
			glyph.TextStrokeColor3 = piece > 0 and rgb(20, 20, 26) or rgb(200, 210, 230)
			glyph.TextStrokeTransparency = 0.2
		end
	end

	local function sqAt(col, row)
		local file = flipped and 7 - col or col
		local rank = flipped and row or 7 - row
		return Engine.square(file, rank)
	end
	local function cellOf(sq)
		local f, r = Engine.fileRank(sq)
		if flipped then
			return 7 - f, r
		end
		return f, 7 - r
	end

	-- ===== правая панель =====
	local panel = ui.new("Frame", {
		Position = UDim2.fromOffset(1110, BOARD_Y - 40), Size = UDim2.fromOffset(680, boardSize + 80),
		BackgroundColor3 = theme.Colors.Panel, BackgroundTransparency = 0.1, Parent = canvas,
	}, { ui.corner(18) })
	ui.text("CHESS", { Position = UDim2.fromOffset(40, 30), Size = UDim2.fromOffset(600, 60), TextSize = 56, Font = theme.FontHeavy, Parent = panel })
	local modeLabel = ui.text("", { Position = UDim2.fromOffset(40, 92), Size = UDim2.fromOffset(600, 34), TextSize = 28, TextColor3 = theme.Colors.SubText, Parent = panel })
	local playerRows = {}
	for i, side in { -1, 1 } do
		local row = ui.new("Frame", {
			Position = UDim2.fromOffset(30, 150 + (i - 1) * 100), Size = UDim2.fromOffset(620, 86),
			BackgroundColor3 = theme.Colors.Card, Parent = panel,
		}, { ui.corner(14) })
		local stroke = ui.stroke(theme.Colors.Accent, 3, 1)
		stroke.Parent = row
		ui.new("Frame", {
			Position = UDim2.fromOffset(20, 25), Size = UDim2.fromOffset(36, 36),
			BackgroundColor3 = side > 0 and rgb(240, 236, 226) or rgb(20, 20, 26), Parent = row,
		}, { ui.corner(UDim.new(0.5, 0)), ui.stroke(rgb(120, 130, 155), 2, 0) })
		local name = ui.text("", { Position = UDim2.fromOffset(74, 8), Size = UDim2.fromOffset(380, 40), TextSize = 30, Font = theme.FontBold, Parent = row })
		local captured = ui.text("", { Position = UDim2.fromOffset(74, 46), Size = UDim2.fromOffset(530, 30), TextSize = 24, TextColor3 = theme.Colors.SubText, Parent = row })
		playerRows[side] = { stroke = stroke, name = name, captured = captured }
	end
	local statusLabel = ui.text("", {
		Position = UDim2.fromOffset(40, 360), Size = UDim2.fromOffset(600, 50), TextSize = 38, Font = theme.FontHeavy, Parent = panel,
	})
	ui.text("MOVES", { Position = UDim2.fromOffset(40, 430), Size = UDim2.fromOffset(600, 30), TextSize = 22, Font = theme.FontBold, TextColor3 = theme.Colors.Muted, Parent = panel })
	local movesLabel = ui.text("", {
		Position = UDim2.fromOffset(40, 466), Size = UDim2.fromOffset(600, 330), TextSize = 28, TextColor3 = theme.Colors.Text,
		TextYAlignment = Enum.TextYAlignment.Top, Font = theme.Font, Parent = panel,
	})
	local hintsLabel = ui.text("", {
		Position = UDim2.fromOffset(40, boardSize + 80 - 110), Size = UDim2.fromOffset(600, 80), TextSize = 22, TextWrapped = true,
		TextColor3 = theme.Colors.SubText, TextYAlignment = Enum.TextYAlignment.Top, Parent = panel,
	})

	-- ===== всплывающее окно (меню, превращение, итог) =====
	local overlay = ui.new("Frame", {
		Size = UDim2.fromOffset(1920, 1080), BackgroundColor3 = rgb(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 20, Visible = false, Parent = canvas,
	})
	local dialog = ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(BOARD_X + boardSize / 2, 540), Size = UDim2.fromOffset(640, 600),
		BackgroundColor3 = theme.Colors.Panel, ZIndex = 21, Parent = overlay,
	}, { ui.corner(22), ui.stroke(theme.Colors.Accent, 3, 0.2) })
	local dialogTitle = ui.text("", {
		Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 60), TextSize = 46, Font = theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 22, Parent = dialog,
	})
	local dialogBody = ui.new("Frame", { Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 1, -104), BackgroundTransparency = 1, ZIndex = 22, Parent = dialog })

	local menuRows, menuFocus = {}, 1
	local menuItems = {}

	local function renderMenu()
		for i, item in menuItems do
			local row = menuRows[i]
			local focus = i == menuFocus
			row.BackgroundColor3 = focus and theme.Colors.Accent or theme.Colors.Card
			local label = item.label
			if item.values then
				label = `{item.label}:  ‹ {item.values[item.get()]} ›`
			end
			row.Text = label
		end
	end

	local function openDialog(title, items, width)
		for _, r in menuRows do
			r:Destroy()
		end
		table.clear(menuRows)
		for _, c in dialogBody:GetChildren() do
			c:Destroy()
		end
		menuItems = items
		menuFocus = 1
		dialogTitle.Text = title
		dialog.Size = UDim2.fromOffset(width or 640, 140 + #items * 84)
		for i, item in items do
			local row = ui.new("TextButton", {
				Position = UDim2.fromOffset(40, (i - 1) * 84), Size = UDim2.new(1, -80, 0, 70), AutoButtonColor = false,
				Text = "", TextSize = 32, Font = theme.FontBold, TextColor3 = theme.Colors.Text, ZIndex = 23, Parent = dialogBody,
			}, { ui.corner(14) })
			row.Activated:Connect(function()
				menuFocus = i
				if item.values then
					item.set(item.get() % #item.values + 1)
					ctx.audio:Play("move")
					renderMenu()
				elseif item.action then
					ctx.audio:Play("confirm")
					item.action()
				end
			end)
			menuRows[i] = row
		end
		overlay.Visible = true
		renderMenu()
	end

	local function closeDialog()
		overlay.Visible = false
	end

	-- ===== отрисовка =====
	local function sideName(side)
		if mode == "two" then
			return side > 0 and "White" or "Black"
		end
		return side == human and ctx.user.name or `Computer · {LEVELS[level].name}`
	end

	local function capturedText(side)
		-- фигуры стороны side, которые она взяла (то есть недостающие у соперника)
		local start = { 8, 2, 2, 2, 1 }
		local have = { 0, 0, 0, 0, 0 }
		local mine, theirs = 0, 0
		local VALUES = { 1, 3, 3, 5, 9 }
		for sq = 0, 119 do
			if bit32.band(sq, 0x88) == 0 then
				local p = pos.board[sq]
				local k = math.abs(p)
				if k >= 1 and k <= 5 then
					if p * side < 0 then
						have[k] += 1
						theirs += VALUES[k]
					else
						mine += VALUES[k]
					end
				end
			end
		end
		local s = ""
		for k = 5, 1, -1 do
			s ..= string.rep(GLYPH[k], math.max(0, start[k] - have[k]))
		end
		if mine > theirs then
			s ..= `  +{mine - theirs}`
		end
		return s
	end

	local function statusText()
		if state == "over" or status ~= "play" then
			if status == "checkmate" then
				return `Checkmate! {pos.side > 0 and "Black" or "White"} wins`
			end
			return RESULT_TEXT[status] or ""
		end
		local who = pos.side > 0 and "White" or "Black"
		if thinking then
			return "Computer is thinking…"
		end
		local check = pos:inCheck() and "Check! " or ""
		if mode == "cpu" then
			return check .. (pos.side == human and "Your move" or `{who} to move`)
		end
		return check .. `{who} to move`
	end

	local function redraw(anim)
		local last = history[#history]
		local lastFrom, lastTo
		if last then
			local f, t = Engine.decode(last.move)
			lastFrom, lastTo = f, t
		end
		local checkSq = pos:inCheck() and (pos.side > 0 and pos.wk or pos.bk) or nil
		local selSq = selected
		for row = 0, 7 do
			for col = 0, 7 do
				local i = row * 8 + col
				local sq = sqAt(col, row)
				local cell = cells[i]
				local tint = cell.tint
				if sq == selSq then
					tint.BackgroundColor3, tint.BackgroundTransparency = rgb(0, 112, 240), 0.35
				elseif checkSq == sq then
					tint.BackgroundColor3, tint.BackgroundTransparency = rgb(230, 50, 60), 0.3
				elseif hint and (sq == hint[1] or sq == hint[2]) then
					tint.BackgroundColor3, tint.BackgroundTransparency = rgb(60, 220, 140), 0.4
				elseif sq == lastFrom or sq == lastTo then
					tint.BackgroundColor3, tint.BackgroundTransparency = rgb(255, 214, 90), 0.5
				else
					tint.BackgroundTransparency = 1
				end
				local target = targets[sq] ~= nil
				local occupied = pos.board[sq] ~= 0
				cell.dot.Visible = target and not occupied
				cell.ring.Visible = target and occupied
				local label = pieceLabels[i]
				setPieceImage(label, pos.board[sq])
				label.Position = UDim2.fromOffset(col * CELL, row * CELL)
				label.ZIndex = 4
			end
		end
		if anim then
			local fc, fr = cellOf(anim[1])
			local tc, tr = cellOf(anim[2])
			local label = pieceLabels[tr * 8 + tc]
			label.Position = UDim2.fromOffset(fc * CELL, fr * CELL)
			label.ZIndex = 5
			ui.tween(label, 0.22, { Position = UDim2.fromOffset(tc * CELL, tr * CELL) }, Enum.EasingStyle.Quad)
		end
		cursorFrame.Position = UDim2.fromOffset(cursor.col * CELL, cursor.row * CELL)
		cursorFrame.Visible = state == "play" and not thinking and input:Device() ~= "touch"
		for i = 0, 7 do
			fileLabels[i].Text = string.char(97 + (flipped and 7 - i or i))
			rankLabels[i].Text = tostring(flipped and i + 1 or 8 - i)
		end
		modeLabel.Text = mode == "cpu" and `vs Computer · {LEVELS[level].name}` or "Two players"
		local rowOrder = flipped and { 1, -1 } or { -1, 1 }
		for i, side in rowOrder do
			local r = playerRows[side]
			r.name.Text = sideName(side)
			r.captured.Text = capturedText(side)
			r.stroke.Transparency = (pos.side == side and status == "play") and 0 or 1
			r.stroke.Parent.Position = UDim2.fromOffset(30, 150 + (i - 1) * 100)
		end
		statusLabel.Text = statusText()
		statusLabel.TextColor3 = (status == "checkmate" or pos:inCheck()) and theme.Colors.Danger or theme.Colors.Text
		local lines = {}
		local first = math.max(1, #history - 19)
		if first % 2 == 0 then
			first -= 1
		end
		for i = first, #history, 2 do
			local white, black = history[i], history[i + 1]
			table.insert(lines, `{(i + 1) // 2}.  {white.san}{black and "     " .. black.san or ""}`)
		end
		movesLabel.Text = #lines > 0 and table.concat(lines, "\n") or "—"
		local g = function(b)
			return input:Glyph(b)
		end
		hintsLabel.Text = `{g("cross")} pick / move     {g("triangle")} undo     {g("square")} hint\n{g("options")} or {g("circle")} menu`
	end

	local function save()
		if status ~= "play" then
			ctx.save:Remove("game")
			return
		end
		local moves = {}
		for _, h in history do
			table.insert(moves, Engine.uci(h.move))
		end
		ctx.save:Set("game", { mode = mode, level = level, human = human, flipped = flipped, moves = moves })
	end

	local function refreshLegal()
		legal = pos:legalMoves()
		selected, targets = nil, {}
	end

	local thinkCpu -- ниже

	local function finishGame()
		state = "over"
		local won = status == "checkmate" and -pos.side or 0
		if mode == "two" then
			ctx.trophies:Unlock("two_player")
		elseif won == human then
			ctx.trophies:Unlock("first_win")
			if level >= 2 then ctx.trophies:Unlock("beat_medium") end
			if level >= 3 then ctx.trophies:Unlock("beat_hard") end
			local humanMoves = math.ceil(#history / 2)
			if humanMoves <= 30 then ctx.trophies:Unlock("quick_mate") end
			local wins = ctx.save:Get("wins", { 0, 0, 0 })
			wins[level] = (wins[level] or 0) + 1
			ctx.save:Set("wins", wins)
		end
		ctx.audio:Play(won ~= 0 and (mode == "two" or won == human) and "trophy" or "notify")
		task.delay(0.9, function()
			if exited or state ~= "over" then
				return
			end
			local title
			if status == "checkmate" then
				title = mode == "cpu" and (won == human and "You win!" or "Computer wins") or `{won > 0 and "White" or "Black"} wins!`
			else
				title = RESULT_TEXT[status]
			end
			local showMenu
			openDialog(title, {
				{ label = "New game", action = function() showMenu() end },
				{ label = "Look at the board", action = function() closeDialog() end },
			}, 720)
			showMenu = function()
				Game._showMenu()
			end
		end)
	end

	local function applyMove(m, byHuman)
		local san = pos:san(m)
		local from, to, promo, flag = Engine.decode(m)
		local capture = pos.board[to] ~= 0 or flag == 1
		pos:make(m)
		table.insert(history, { move = m, san = san })
		hint = nil
		if byHuman or mode == "two" then
			if flag == 2 then ctx.trophies:Unlock("castle") end
			if flag == 1 then ctx.trophies:Unlock("en_passant") end
			if promo > 0 then
				ctx.trophies:Unlock("promotion")
				if promo == Engine.KNIGHT then ctx.trophies:Unlock("knight_promo") end
			end
		end
		status = pos:status()
		refreshLegal()
		if pos:inCheck() then
			ctx.audio:Play("notify", { volume = 0.6 })
			input:Rumble(0.3, 0.15)
		else
			ctx.audio:Play(capture and "hit" or "move", { pitch = capture and 1 or 0.85 })
		end
		redraw({ from, to })
		save()
		if status ~= "play" then
			finishGame()
		elseif mode == "cpu" and pos.side ~= human then
			thinkCpu()
		end
	end

	thinkCpu = function()
		generation += 1
		local myGen = generation
		thinking = true
		redraw()
		task.spawn(function()
			local started = os.clock()
			local frame = os.clock()
			local cfg = LEVELS[level]
			local move = Engine.search(pos, {
				depth = cfg.depth, time = cfg.time, noise = cfg.noise,
				yield = function()
					if os.clock() - frame > 0.01 then
						task.wait()
						frame = os.clock()
					end
				end,
				cancel = function()
					return exited or myGen ~= generation
				end,
			})
			local waitLeft = 0.45 - (os.clock() - started)
			if waitLeft > 0 then
				task.wait(waitLeft)
			end
			while ctx.paused and not exited and myGen == generation do
				task.wait(0.1)
			end
			if exited or myGen ~= generation then
				return
			end
			thinking = false
			if move then
				applyMove(move, false)
			end
		end)
	end

	local function newGame(m, savedMoves)
		generation += 1
		thinking = false
		mode = m
		pos = Engine.new()
		history = {}
		hint = nil
		if savedMoves then
			for _, u in savedMoves do
				local mv = pos:fromUci(u)
				if not mv then
					break
				end
				table.insert(history, { move = mv, san = pos:san(mv) })
				pos:make(mv)
			end
		end
		status = pos:status()
		refreshLegal()
		cursor.col, cursor.row = 4, 6
		state = status == "play" and "play" or "over"
		closeDialog()
		redraw()
		save()
		if state == "play" and mode == "cpu" and pos.side ~= human then
			thinkCpu()
		end
	end

	local function undo()
		if #history == 0 then
			ctx.audio:Play("error")
			return
		end
		generation += 1
		thinking = false
		closeDialog()
		repeat
			pos:unmake()
			table.remove(history)
		until #history == 0 or mode == "two" or pos.side == human
		if mode == "cpu" and pos.side ~= human then
			-- компьютер начинает партию белыми: его первый ход нельзя «отдать назад»
			status = pos:status()
			refreshLegal()
			state = "play"
			thinkCpu()
			return
		end
		status = pos:status()
		refreshLegal()
		state = "play"
		closeDialog()
		ctx.audio:Play("back")
		redraw()
		save()
	end

	-- ===== меню =====
	local function startCpu()
		human = colorChoice == 3 and (math.random(2) == 1 and 1 or -1) or (colorChoice == 1 and 1 or -1)
		flipped = human < 0
		ctx.save:Set("level", level)
		ctx.save:Set("color", colorChoice)
		newGame("cpu")
	end

	function Game._showMenu()
		generation += 1
		thinking = false
		state = "menu"
		local items = {}
		local saved = ctx.save:Get("game")
		if type(saved) == "table" and type(saved.moves) == "table" and #saved.moves > 0 then
			table.insert(items, {
				label = "Continue game",
				action = function()
					level = tonumber(saved.level) or 2
					human = saved.human == -1 and -1 or 1
					flipped = saved.flipped == true
					newGame(saved.mode == "two" and "two" or "cpu", saved.moves)
				end,
			})
		end
		table.insert(items, { label = "Play vs Computer", action = startCpu })
		table.insert(items, {
			label = "Level", values = { "Easy", "Medium", "Hard" },
			get = function() return level end, set = function(v) level = v end,
		})
		table.insert(items, {
			label = "Play as", values = COLORS,
			get = function() return colorChoice end, set = function(v) colorChoice = v end,
		})
		table.insert(items, {
			label = "Two players", action = function()
				human, flipped = 1, false
				newGame("two")
			end,
		})
		table.insert(items, { label = "Quit", action = function() ctx:Exit() end })
		openDialog("Chess", items)
		redraw()
	end

	local function showPause()
		state = "pause"
		openDialog("Paused", {
			{ label = "Resume", action = function()
				state = "play"
				closeDialog()
				redraw()
			end },
			{ label = "Undo move", action = undo },
			{ label = "Flip board", action = function()
				flipped = not flipped
				state = "play"
				closeDialog()
				redraw()
				save()
			end },
			{ label = "New game", action = function() Game._showMenu() end },
			{ label = "Quit", action = function() ctx:Exit() end },
		})
	end

	local promoChoices = nil
	local function showPromotion(moves)
		state = "promo"
		promoChoices = moves
		local items = {}
		for _, m in moves do
			local _, _, promo = Engine.decode(m)
			table.insert(items, { label = ({ "", "Knight", "Bishop", "Rook", "Queen" })[promo], action = function()
				state = "play"
				closeDialog()
				applyMove(m, true)
			end })
		end
		openDialog("Promote pawn to", items)
	end

	-- ===== ход игрока =====
	local function humanTurn()
		return state == "play" and status == "play" and not thinking and (mode == "two" or pos.side == human)
	end

	local function selectSquare(sq)
		selected, targets = sq, {}
		for _, m in legal do
			local from, to = Engine.decode(m)
			if from == sq then
				targets[to] = targets[to] or {}
				table.insert(targets[to], m)
			end
		end
	end

	local function activate()
		if not humanTurn() then
			if state == "play" and thinking then
				ctx.audio:Play("error")
			end
			return
		end
		local sq = sqAt(cursor.col, cursor.row)
		local p = pos.board[sq]
		if selected and targets[sq] then
			local moves = targets[sq]
			if #moves > 1 then
				showPromotion(moves)
			else
				applyMove(moves[1], true)
			end
		elseif p ~= 0 and p * pos.side > 0 then
			selectSquare(sq)
			if next(targets) == nil then
				ctx.audio:Play("error")
			else
				ctx.audio:Play("confirm", { volume = 0.5 })
			end
			redraw()
		elseif selected then
			selected, targets = nil, {}
			ctx.audio:Play("back", { volume = 0.5 })
			redraw()
		end
	end

	onCellClick = function(col, row)
		if state ~= "play" then
			return
		end
		cursor.col, cursor.row = col, row
		activate()
	end

	local function showHint()
		if not humanTurn() then
			return
		end
		local myGen = generation
		thinking = true
		redraw()
		task.spawn(function()
			local frame = os.clock()
			local m = Engine.search(pos, {
				depth = 3, time = 0.8,
				yield = function()
					if os.clock() - frame > 0.01 then
						task.wait()
						frame = os.clock()
					end
				end,
				cancel = function() return exited or myGen ~= generation end,
			})
			if exited or myGen ~= generation then
				return
			end
			thinking = false
			if m then
				local f, t = Engine.decode(m)
				hint = { f, t }
				ctx.audio:Play("notify", { volume = 0.4 })
			end
			redraw()
		end)
	end

	local MOVE = { up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 } }
	local function onDirection(btn)
		local d = MOVE[btn]
		if state == "play" then
			cursor.col = (cursor.col + d[1]) % 8
			cursor.row = (cursor.row + d[2]) % 8
			ctx.audio:Play("move", { volume = 0.35 })
			redraw()
		elseif overlay.Visible and #menuItems > 0 then
			if d[2] ~= 0 then
				menuFocus = (menuFocus - 1 + d[2]) % #menuItems + 1
				ctx.audio:Play("move", { volume = 0.5 })
			elseif menuItems[menuFocus].values then
				local item = menuItems[menuFocus]
				item.set((item.get() - 1 + d[1]) % #item.values + 1)
				ctx.audio:Play("move", { volume = 0.5 })
			end
			renderMenu()
		end
	end

	input:On("press", function(btn)
		if MOVE[btn] then
			onDirection(btn)
		elseif btn == "cross" then
			if overlay.Visible then
				local item = menuItems[menuFocus]
				if item and item.action then
					ctx.audio:Play("confirm")
					item.action()
				elseif item and item.values then
					item.set(item.get() % #item.values + 1)
					renderMenu()
				end
			else
				activate()
			end
		elseif btn == "circle" then
			if state == "menu" then
				ctx:Exit()
			elseif state == "pause" or state == "promo" then
				state = "play"
				closeDialog()
				redraw()
			elseif state == "over" then
				Game._showMenu()
			elseif selected then
				selected, targets = nil, {}
				redraw()
			else
				showPause()
			end
		elseif btn == "options" then
			if state == "play" then
				showPause()
			elseif state == "pause" then
				state = "play"
				closeDialog()
				redraw()
			end
		elseif btn == "triangle" then
			if state == "play" or state == "over" then
				undo()
			end
		elseif btn == "square" then
			showHint()
		end
	end)
	input:On("repeat", function(btn)
		if MOVE[btn] then
			onDirection(btn)
		end
	end)

	ctx:On("exit", function()
		exited = true
		generation += 1
	end)

	Game._showMenu()
	Game.debug = {
		pos = function() return pos end,
		state = function() return state end,
		history = function() return history end,
		thinking = function() return thinking end,
		sprites = function() return sprites ~= nil end,
		status = function() return status end,
		click = function(name) -- "e2": как щелчок мышью по клетке
			local col, row = cellOf(Engine.square(string.byte(name, 1) - 97, tonumber(string.sub(name, 2, 2)) - 1))
			onCellClick(col, row)
		end,
	}
end

return Game
