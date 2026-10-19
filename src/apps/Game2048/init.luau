-- 2048: поле 4×4, ход — сдвиг строки и слияние равных соседей. Партия сохраняется.
local Game = {}

local N, TILE, GAP = 4, 170, 16
local COLORS = {
	[2] = { 238, 228, 218 }, [4] = { 237, 224, 200 }, [8] = { 242, 177, 121 }, [16] = { 245, 149, 99 },
	[32] = { 246, 124, 95 }, [64] = { 246, 94, 59 }, [128] = { 237, 207, 114 }, [256] = { 237, 204, 97 },
	[512] = { 237, 200, 80 }, [1024] = { 237, 197, 63 }, [2048] = { 237, 194, 46 },
}

function Game.launch(ctx)
	local ui = ctx.ui
	local canvas = ui.canvas(ctx.gui)
	ctx.gui.BackgroundColor3 = Color3.fromRGB(30, 24, 14)
	local size = N * TILE + (N + 1) * GAP
	local board = ui.new("Frame", {
		Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 590),
		BackgroundColor3 = Color3.fromRGB(120, 105, 90), Parent = canvas,
	}, { ui.corner(20) })
	local labels = {}
	for r = 1, N do
		labels[r] = {}
		for c = 1, N do
			labels[r][c] = ui.text("", {
				Size = UDim2.fromOffset(TILE, TILE), Position = UDim2.fromOffset(GAP + (c - 1) * (TILE + GAP), GAP + (r - 1) * (TILE + GAP)),
				BackgroundTransparency = 0, TextSize = 64, Font = ctx.theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, Parent = board,
			})
			ui.corner(12).Parent = labels[r][c]
		end
	end
	local scoreLabel = ui.text("", { Size = UDim2.fromOffset(1920, 60), Position = UDim2.fromOffset(0, 110), TextSize = 44, Font = ctx.theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, Parent = canvas })
	local message = ui.text("", { Size = UDim2.fromOffset(1920, 60), Position = UDim2.fromOffset(0, 990), TextSize = 32, TextColor3 = ctx.theme.Colors.SubText, TextXAlignment = Enum.TextXAlignment.Center, Parent = canvas })

	local grid, score
	local best = ctx.save:Get("best", 0)

	local function spawnTile()
		local empty = {}
		for r = 1, N do
			for c = 1, N do
				if grid[r][c] == 0 then
					table.insert(empty, { r, c })
				end
			end
		end
		if #empty > 0 then
			local cell = empty[math.random(#empty)]
			grid[cell[1]][cell[2]] = math.random() < 0.9 and 2 or 4
		end
	end

	local function canMove()
		for r = 1, N do
			for c = 1, N do
				local v = grid[r][c]
				if v == 0 or (c < N and grid[r][c + 1] == v) or (r < N and grid[r + 1][c] == v) then
					return true
				end
			end
		end
		return false
	end

	local function draw()
		for r = 1, N do
			for c = 1, N do
				local v, label = grid[r][c], labels[r][c]
				local rgb = COLORS[v] or { 60, 58, 50 }
				label.Text = v > 0 and tostring(v) or ""
				label.BackgroundColor3 = v > 0 and Color3.fromRGB(rgb[1], rgb[2], rgb[3]) or Color3.fromRGB(150, 135, 120)
				label.TextColor3 = v <= 4 and Color3.fromRGB(100, 90, 80) or Color3.new(1, 1, 1)
				label.TextSize = v >= 1024 and 50 or 64
			end
		end
		scoreLabel.Text = `Score {score}     Best {best}`
		message.Text = canMove() and `{ctx.input:Glyph("triangle")} new game   {ctx.input:Glyph("circle")} quit`
			or `No moves left · {ctx.input:Glyph("triangle")} new game`
		ctx.save:Set("board", { grid = grid, score = score })
	end

	local function newGame()
		grid, score = {}, 0
		for r = 1, N do
			grid[r] = { 0, 0, 0, 0 }
		end
		spawnTile()
		spawnTile()
		draw()
	end

	-- сдвиг одной линии к началу со слиянием
	local function slide(line)
		local out, merged = {}, false
		for _, v in line do
			if v ~= 0 then
				if not merged and out[#out] == v then
					out[#out] *= 2
					score += out[#out]
					merged = true
					local made = out[#out]
					for _, t in { { 128, "tile_128" }, { 512, "tile_512" }, { 2048, "tile_2048" } } do
						if made >= t[1] then
							ctx.trophies:Unlock(t[2])
						end
					end
				else
					table.insert(out, v)
					merged = false
				end
			end
		end
		while #out < N do
			table.insert(out, 0)
		end
		return out
	end

	local function move(dr, dc)
		local moved = false
		for i = 1, N do
			local cells = {}
			for k = 1, N do
				-- k-я клетка линии, считая от края, к которому сдвигаем
				local idx = (dr + dc) < 0 and k or N + 1 - k
				table.insert(cells, dr ~= 0 and { idx, i } or { i, idx })
			end
			local line = {}
			for _, p in cells do
				table.insert(line, grid[p[1]][p[2]])
			end
			local result = slide(line)
			for k, p in cells do
				if grid[p[1]][p[2]] ~= result[k] then
					moved = true
				end
				grid[p[1]][p[2]] = result[k]
			end
		end
		if moved then
			spawnTile()
			if score > best then
				best = score
				ctx.save:Set("best", best)
			end
			ctx.audio:Play("move")
			draw()
		end
	end

	local MOVES = { up = { -1, 0 }, down = { 1, 0 }, left = { 0, -1 }, right = { 0, 1 } }
	ctx.input:On("press", function(btn)
		if MOVES[btn] then
			move(MOVES[btn][1], MOVES[btn][2])
		elseif btn == "triangle" then
			newGame()
		elseif btn == "circle" then
			ctx:Exit()
		end
	end)

	local saved = ctx.save:Get("board")
	if type(saved) == "table" and type(saved.grid) == "table" and #saved.grid == N then
		grid, score = saved.grid, saved.score or 0
		draw()
	else
		newGame()
	end
end

return Game
