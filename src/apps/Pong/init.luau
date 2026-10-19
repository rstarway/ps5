-- Пинг-понг против компьютера: игрок слева, до 7 очков.
local Pong = {}

local FW, FH, PW, PH, BALL = 1400, 800, 22, 150, 24
local TARGET = 7

function Pong.launch(ctx)
	local ui = ctx.ui
	local canvas = ui.canvas(ctx.gui)
	ctx.gui.BackgroundColor3 = Color3.fromRGB(14, 4, 26)
	local field = ui.new("Frame", {
		Size = UDim2.fromOffset(FW, FH), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 580),
		BackgroundColor3 = Color3.fromRGB(28, 10, 50), Parent = canvas,
	}, { ui.corner(20), ui.stroke(Color3.fromRGB(247, 37, 133), 2, 0.4) })
	ui.new("Frame", { Size = UDim2.fromOffset(4, FH - 40), Position = UDim2.fromOffset(FW / 2 - 2, 20), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.8, Parent = field })
	local function paddle(color)
		return ui.new("Frame", { Size = UDim2.fromOffset(PW, PH), BackgroundColor3 = color, Parent = field }, { ui.corner(8) })
	end
	local left, right = paddle(Color3.fromRGB(80, 200, 255)), paddle(Color3.fromRGB(247, 37, 133))
	local ballFrame = ui.new("Frame", { Size = UDim2.fromOffset(BALL, BALL), BackgroundColor3 = Color3.new(1, 1, 1), Parent = field }, { ui.corner(UDim.new(0.5, 0)) })
	local scoreLabel = ui.text("", { Size = UDim2.fromOffset(1920, 80), Position = UDim2.fromOffset(0, 70), TextSize = 72, Font = ctx.theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, Parent = canvas })
	local message = ui.text("", { Size = UDim2.fromOffset(1920, 140), Position = UDim2.fromOffset(0, 510), TextSize = 46, Font = ctx.theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, Parent = canvas })

	local ly, ry, ball, vel, you, cpu, state

	local function serve(towardsPlayer)
		ball = Vector2.new(FW / 2, FH / 2)
		local angle = math.rad(math.random(-30, 30))
		vel = Vector2.new(math.cos(angle) * (towardsPlayer and -1 or 1), math.sin(angle)) * 620
		state = "serve"
		message.Text = `{ctx.input:Glyph("cross")} serve`
	end

	local function newMatch()
		ly, ry, you, cpu = FH / 2, FH / 2, 0, 0
		serve(false)
	end

	local function draw()
		left.Position = UDim2.fromOffset(30, ly - PH / 2)
		right.Position = UDim2.fromOffset(FW - 30 - PW, ry - PH / 2)
		ballFrame.Position = UDim2.fromOffset(ball.X - BALL / 2, ball.Y - BALL / 2)
		scoreLabel.Text = `{you}   :   {cpu}`
	end

	local function point(playerScored)
		if playerScored then
			you += 1
			ctx.trophies:Unlock("first_point")
			ctx.audio:Play("confirm")
		else
			cpu += 1
			ctx.audio:Play("hit")
		end
		if you >= TARGET or cpu >= TARGET then
			state = "over"
			local won = you >= TARGET
			if won then
				ctx.trophies:Unlock("win")
				if cpu == 0 then
					ctx.trophies:Unlock("shutout")
				end
				ctx.save:Set("wins", ctx.save:Get("wins", 0) + 1)
				ctx.save:Set("best", math.max(ctx.save:Get("best", 0), you - cpu))
			end
			message.Text = `{won and "You win! 🏆" or "Computer wins"}\n{ctx.input:Glyph("cross")} new match   {ctx.input:Glyph("circle")} quit`
		else
			serve(not playerScored)
		end
	end

	ctx.input:On("press", function(btn)
		if btn == "cross" then
			if state == "serve" then
				state = "play"
				message.Text = ""
			elseif state == "over" then
				newMatch()
			end
		elseif btn == "circle" then
			ctx:Exit()
		end
	end)

	ctx:Loop(function(dt)
		local axis = ctx.input:GetAxes().ly
		if ctx.input:IsDown("up") then
			axis = 1
		elseif ctx.input:IsDown("down") then
			axis = -1
		end
		ly = math.clamp(ly - axis * 900 * dt, PH / 2, FH - PH / 2)
		if state == "play" then
			-- компьютер догоняет мяч с ограниченной скоростью, чтобы его можно было обыграть
			local target = vel.X > 0 and ball.Y or FH / 2
			ry += math.clamp(target - ry, -520 * dt, 520 * dt)
			ry = math.clamp(ry, PH / 2, FH - PH / 2)
			ball += vel * dt
			if ball.Y < BALL / 2 or ball.Y > FH - BALL / 2 then
				vel = Vector2.new(vel.X, -vel.Y)
				ball = Vector2.new(ball.X, math.clamp(ball.Y, BALL / 2, FH - BALL / 2))
			end
			local function bounce(py, x, dirSign)
				if math.abs(ball.Y - py) <= PH / 2 + BALL / 2 then
					local offset = (ball.Y - py) / (PH / 2)
					local speed = math.min(vel.Magnitude * 1.06, 1500)
					vel = Vector2.new(dirSign * math.cos(offset * 0.9), math.sin(offset * 0.9)).Unit * speed
					ball = Vector2.new(x, ball.Y)
					ctx.audio:Play("move", { pitch = 1.3 })
				end
			end
			if vel.X < 0 and ball.X <= 30 + PW + BALL / 2 and ball.X > 20 then
				bounce(ly, 30 + PW + BALL / 2, 1)
			elseif vel.X > 0 and ball.X >= FW - 30 - PW - BALL / 2 and ball.X < FW - 20 then
				bounce(ry, FW - 30 - PW - BALL / 2, -1)
			end
			if ball.X < 0 then
				point(false)
			elseif ball.X > FW then
				point(true)
			end
		end
		draw()
	end)

	newMatch()
	draw()
end

return Pong
