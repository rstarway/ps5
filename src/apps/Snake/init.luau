-- Змейка на сетке 24×15: каждая клетка — Frame, раз в шаг перекрашиваем.
local Snake = {}

local W, H, CELL = 24, 15, 44
local DIRS = { up = Vector2.new(0, -1), down = Vector2.new(0, 1), left = Vector2.new(-1, 0), right = Vector2.new(1, 0) }

function Snake.launch(ctx)
	local ui = ctx.ui
	local canvas = ui.canvas(ctx.gui)
	ctx.gui.BackgroundColor3 = Color3.fromRGB(8, 20, 14)
	local board = ui.new("Frame", {
		Size = UDim2.fromOffset(W * CELL, H * CELL), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 580),
		BackgroundColor3 = Color3.fromRGB(16, 40, 28), Parent = canvas,
	}, { ui.corner(16) })
	local cells = {}
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			cells[y * W + x] = ui.new("Frame", {
				Size = UDim2.fromOffset(CELL - 4, CELL - 4), Position = UDim2.fromOffset(x * CELL + 2, y * CELL + 2),
				BackgroundTransparency = 1, Parent = board,
			}, { ui.corner(8) })
		end
	end
	local scoreLabel = ui.text("", { Size = UDim2.fromOffset(1920, 60), Position = UDim2.fromOffset(0, 120), TextSize = 44, Font = ctx.theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, Parent = canvas })
	local message = ui.text("", { Size = UDim2.fromOffset(1920, 120), Position = UDim2.fromOffset(0, 520), TextSize = 50, Font = ctx.theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, Parent = canvas })

	local best = ctx.save:Get("best", 0)
	local body, dir, nextDir, apple, timer, score, alive

	local function placeApple()
		repeat
			apple = Vector2.new(math.random(0, W - 1), math.random(0, H - 1))
			local free = true
			for _, p in body do
				if p == apple then
					free = false
				end
			end
		until free
	end

	local function draw()
		for _, c in cells do
			c.BackgroundTransparency = 1
		end
		for i, p in body do
			local c = cells[p.Y * W + p.X]
			c.BackgroundTransparency = 0
			c.BackgroundColor3 = i == 1 and Color3.fromRGB(200, 255, 140) or Color3.fromRGB(80, 220, 120):Lerp(Color3.fromRGB(30, 140, 80), i / #body)
		end
		local a = cells[apple.Y * W + apple.X]
		a.BackgroundTransparency = 0
		a.BackgroundColor3 = Color3.fromRGB(255, 70, 80)
		scoreLabel.Text = `🍎 {score}     Best {best}`
	end

	local function reset()
		body = { Vector2.new(8, 7), Vector2.new(7, 7), Vector2.new(6, 7) }
		dir, nextDir, timer, score, alive = DIRS.right, DIRS.right, 0, 0, true
		message.Text = ""
		placeApple()
		draw()
	end

	ctx.input:On("press", function(btn)
		local d = DIRS[btn]
		if d and alive and d ~= -dir then
			nextDir = d
		elseif btn == "cross" and not alive then
			reset()
		elseif btn == "circle" then
			ctx:Exit()
		end
	end)

	ctx:Loop(function(dt)
		if not alive then
			return
		end
		timer += dt
		local stepTime = math.max(0.06, 0.13 - score * 0.0015)
		if timer < stepTime then
			return
		end
		timer = 0
		dir = nextDir
		local head = body[1] + dir
		local hit = head.X < 0 or head.Y < 0 or head.X >= W or head.Y >= H
		for i = 1, #body - 1 do
			if body[i] == head then
				hit = true
			end
		end
		if hit then
			alive = false
			ctx.audio:Play("explosion")
			ctx.input:Rumble(0.6, 0.3)
			if score > best then
				best = score
				ctx.save:Set("best", best)
			end
			message.Text = `Game over · {score} 🍎\n{ctx.input:Glyph("cross")} play again   {ctx.input:Glyph("circle")} quit`
			return
		end
		table.insert(body, 1, head)
		if head == apple then
			score += 1
			ctx.audio:Play("confirm", { pitch = 1 + math.min(score, 30) * 0.02 })
			ctx.trophies:Unlock("first_apple")
			if score >= 20 then
				ctx.trophies:Unlock("score_20")
			end
			if score >= 50 then
				ctx.trophies:Unlock("score_50")
			end
			placeApple()
		else
			table.remove(body)
		end
		draw()
	end)

	reset()
end

return Snake
