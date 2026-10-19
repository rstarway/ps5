-- Арканоид: стена 10×6 кирпичей, 3 жизни; каждая следующая стена — мяч быстрее.
local BrickBreak = {}

local FW, FH, COLS, ROWS = 1400, 900, 10, 6
local BW, BH, PADDLE_W, PADDLE_H, BALL = 128, 40, 200, 22, 22
local ROW_COLORS = { { 255, 89, 94 }, { 255, 146, 76 }, { 255, 202, 58 }, { 138, 201, 38 }, { 25, 130, 196 }, { 106, 76, 147 } }

function BrickBreak.launch(ctx)
	local ui = ctx.ui
	local canvas = ui.canvas(ctx.gui)
	ctx.gui.BackgroundColor3 = Color3.fromRGB(20, 10, 4)
	local field = ui.new("Frame", {
		Size = UDim2.fromOffset(FW, FH), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 590),
		BackgroundColor3 = Color3.fromRGB(36, 20, 10), ClipsDescendants = true, Parent = canvas,
	}, { ui.corner(18), ui.stroke(Color3.fromRGB(251, 133, 0), 2, 0.5) })
	local paddleFrame = ui.new("Frame", { Size = UDim2.fromOffset(PADDLE_W, PADDLE_H), BackgroundColor3 = Color3.new(1, 1, 1), Parent = field }, { ui.corner(UDim.new(0.5, 0)) })
	local ballFrame = ui.new("Frame", { Size = UDim2.fromOffset(BALL, BALL), BackgroundColor3 = Color3.fromRGB(255, 220, 120), Parent = field }, { ui.corner(UDim.new(0.5, 0)) })
	local hud = ui.text("", { Size = UDim2.fromOffset(1920, 60), Position = UDim2.fromOffset(0, 70), TextSize = 40, Font = ctx.theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, Parent = canvas })
	local message = ui.text("", { Size = UDim2.fromOffset(1920, 140), Position = UDim2.fromOffset(0, 620), TextSize = 46, Font = ctx.theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, Parent = canvas })

	local best = ctx.save:Get("best", 0)
	local bricks, px, ball, vel, lives, score, wall, state = {}, FW / 2, nil, nil, 3, 0, 1, "aim"
	local left0 = (FW - COLS * BW) / 2

	local function buildWall()
		for _, b in bricks do
			b.frame:Destroy()
		end
		bricks = {}
		for r = 1, ROWS do
			for c = 1, COLS do
				local rgb = ROW_COLORS[r]
				local x, y = left0 + (c - 1) * BW, 80 + (r - 1) * BH
				table.insert(bricks, {
					x = x, y = y,
					frame = ui.new("Frame", { Size = UDim2.fromOffset(BW - 6, BH - 6), Position = UDim2.fromOffset(x + 3, y + 3), BackgroundColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3]), Parent = field }, { ui.corner(6) }),
				})
			end
		end
	end

	local function aim()
		state = "aim"
		ball = Vector2.new(px, FH - 60 - BALL)
		message.Text = `{ctx.input:Glyph("cross")} launch`
	end

	local function newGame()
		lives, score, wall = 3, 0, 1
		buildWall()
		aim()
	end

	ctx.input:On("press", function(btn)
		if btn == "cross" then
			if state == "aim" then
				state = "play"
				message.Text = ""
				local speed = 560 + (wall - 1) * 90
				vel = Vector2.new(math.random(-40, 40) / 100, -1).Unit * speed
			elseif state == "over" then
				newGame()
			end
		elseif btn == "circle" then
			ctx:Exit()
		end
	end)

	ctx:Loop(function(dt)
		local axis = ctx.input:GetAxes().lx
		px = math.clamp(px + axis * 1100 * dt, PADDLE_W / 2, FW - PADDLE_W / 2)
		if state == "aim" then
			ball = Vector2.new(px, FH - 60 - BALL)
		elseif state == "play" then
			ball += vel * dt
			if ball.X < BALL / 2 or ball.X > FW - BALL / 2 then
				vel = Vector2.new(-vel.X, vel.Y)
				ball = Vector2.new(math.clamp(ball.X, BALL / 2, FW - BALL / 2), ball.Y)
			end
			if ball.Y < BALL / 2 then
				vel = Vector2.new(vel.X, math.abs(vel.Y))
			end
			-- ракетка: угол отскока зависит от точки удара
			local paddleY = FH - 60
			if vel.Y > 0 and ball.Y + BALL / 2 >= paddleY and ball.Y < paddleY + PADDLE_H and math.abs(ball.X - px) <= PADDLE_W / 2 + BALL / 2 then
				local offset = math.clamp((ball.X - px) / (PADDLE_W / 2), -1, 1)
				vel = Vector2.new(offset * 0.8, -1).Unit * vel.Magnitude
				ctx.audio:Play("move", { pitch = 1.2 })
			end
			for i = #bricks, 1, -1 do
				local b = bricks[i]
				if ball.X + BALL / 2 > b.x and ball.X - BALL / 2 < b.x + BW and ball.Y + BALL / 2 > b.y and ball.Y - BALL / 2 < b.y + BH then
					local fromSide = ball.X < b.x or ball.X > b.x + BW
					vel = fromSide and Vector2.new(-vel.X, vel.Y) or Vector2.new(vel.X, -vel.Y)
					b.frame:Destroy()
					table.remove(bricks, i)
					score += 10 * wall
					ctx.audio:Play("hit", { pitch = 1 + math.random() * 0.3 })
					ctx.trophies:Unlock("first_brick")
					break
				end
			end
			if #bricks == 0 then
				ctx.trophies:Unlock("clear")
				wall += 1
				if wall >= 3 then
					ctx.trophies:Unlock("level_3")
				end
				ctx.audio:Play("trophy")
				buildWall()
				aim()
			elseif ball.Y > FH + BALL then
				lives -= 1
				ctx.input:Rumble(0.6, 0.3)
				if lives <= 0 then
					state = "over"
					if score > best then
						best = score
						ctx.save:Set("best", best)
					end
					message.Text = `Game over · {score}\n{ctx.input:Glyph("cross")} play again   {ctx.input:Glyph("circle")} quit`
				else
					aim()
				end
			end
		end
		paddleFrame.Position = UDim2.fromOffset(px - PADDLE_W / 2, FH - 60)
		ballFrame.Position = UDim2.fromOffset(ball.X - BALL / 2, ball.Y - BALL / 2)
		hud.Text = `Wall {wall}     ❤ {lives}     Score {score}     Best {best}`
	end)

	newGame()
end

return BrickBreak
