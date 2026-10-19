-- Sky Hop: птичка падает, ✕ — взмах; столбы едут справа налево, между ними щель.
local SkyHop = {}

local FW, FH, BIRD, PILLAR, GAP_H = 1920, 1080, 56, 130, 300
local GRAVITY, FLAP, SPEED, SPACING = 2400, -820, 380, 520

function SkyHop.launch(ctx)
	local ui = ctx.ui
	local canvas = ui.canvas(ctx.gui)
	ctx.gui.BackgroundColor3 = Color3.new(1, 1, 1)
	ui.gradient({ Color3.fromRGB(120, 200, 240), Color3.fromRGB(220, 240, 255) }, 90).Parent = ctx.gui
	local ground = ui.new("Frame", { Size = UDim2.fromOffset(FW, 80), Position = UDim2.fromOffset(0, FH - 80), BackgroundColor3 = Color3.fromRGB(110, 190, 90), ZIndex = 3, Parent = canvas })
	ui.new("Frame", { Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = Color3.fromRGB(80, 150, 60), ZIndex = 3, Parent = ground })
	local bird = ui.text("🐤", { Size = UDim2.fromOffset(BIRD, BIRD), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = canvas })
	local scoreLabel = ui.text("", { Size = UDim2.fromOffset(FW, 100), Position = UDim2.fromOffset(0, 60), TextSize = 90, Font = ctx.theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.2, ZIndex = 5, Parent = canvas })
	local message = ui.text("", { Size = UDim2.fromOffset(FW, 160), Position = UDim2.fromOffset(0, 420), TextSize = 50, Font = ctx.theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.2, ZIndex = 5, Parent = canvas })

	local best = ctx.save:Get("best", 0)
	local y, vy, pillars, score, state, distance

	local function pillarPair()
		local top = ui.new("Frame", { Size = UDim2.fromOffset(PILLAR, 0), BackgroundColor3 = Color3.fromRGB(70, 170, 90), ZIndex = 2, Parent = canvas }, { ui.corner(10), ui.stroke(Color3.fromRGB(30, 100, 50), 4) })
		local bottom = top:Clone()
		bottom.Parent = canvas
		return { top = top, bottom = bottom }
	end

	local function placePillar(p, x)
		p.x = x
		p.gapY = math.random(260, FH - 80 - 260)
		p.passed = false
	end

	local function reset()
		for _, p in pillars or {} do
			p.top:Destroy()
			p.bottom:Destroy()
		end
		pillars = {}
		for i = 1, 5 do
			local p = pillarPair()
			placePillar(p, FW + 200 + (i - 1) * SPACING)
			table.insert(pillars, p)
		end
		y, vy, score, state, distance = FH / 2, 0, 0, "ready", 0
		message.Text = `{ctx.input:Glyph("cross")} to flap`
	end

	local function flap()
		if state == "ready" then
			state = "fly"
			message.Text = ""
		elseif state == "dead" then
			reset()
			return
		end
		vy = FLAP
		ctx.audio:Play("move", { pitch = 1.4 })
	end

	ctx.input:On("press", function(btn)
		if btn == "cross" or btn == "up" then
			flap()
		elseif btn == "circle" then
			ctx:Exit()
		end
	end)

	local function die()
		state = "dead"
		ctx.audio:Play("hit")
		ctx.input:Rumble(0.7, 0.25)
		if score > best then
			best = score
			ctx.save:Set("best", best)
		end
		message.Text = `Score {score}\n{ctx.input:Glyph("cross")} fly again   {ctx.input:Glyph("circle")} quit`
	end

	ctx:Loop(function(dt)
		distance = (distance or 0) + dt
		if state == "fly" then
			vy += GRAVITY * dt
			y += vy * dt
			for _, p in pillars do
				p.x -= SPEED * dt
				if p.x < -PILLAR then
					local far = 0
					for _, q in pillars do
						far = math.max(far, q.x)
					end
					placePillar(p, far + SPACING)
				end
				local birdX = 520
				if not p.passed and p.x + PILLAR < birdX - BIRD / 2 then
					p.passed = true
					score += 1
					ctx.audio:Play("confirm")
					for _, t in { { 1, "score_1" }, { 10, "score_10" }, { 30, "score_30" } } do
						if score >= t[1] then
							ctx.trophies:Unlock(t[2])
						end
					end
				end
				local overlapX = birdX + BIRD / 2 - 8 > p.x and birdX - BIRD / 2 + 8 < p.x + PILLAR
				if overlapX and (y - BIRD / 2 + 8 < p.gapY - GAP_H / 2 or y + BIRD / 2 - 8 > p.gapY + GAP_H / 2) then
					die()
				end
			end
			if y > FH - 80 - BIRD / 2 or y < -BIRD then
				die()
			end
		elseif state == "ready" then
			y = FH / 2 + math.sin(distance * 4) * 14
		end
		for _, p in pillars do
			p.top.Position = UDim2.fromOffset(p.x, -10)
			p.top.Size = UDim2.fromOffset(PILLAR, p.gapY - GAP_H / 2 + 10)
			p.bottom.Position = UDim2.fromOffset(p.x, p.gapY + GAP_H / 2)
			p.bottom.Size = UDim2.fromOffset(PILLAR, FH - (p.gapY + GAP_H / 2))
		end
		bird.Position = UDim2.fromOffset(520 - BIRD / 2, y - BIRD / 2)
		bird.Rotation = state == "fly" and math.clamp(vy / 20, -25, 70) or 0
		scoreLabel.Text = state == "ready" and `Best {best}` or tostring(score)
	end)

	reset()
end

return SkyHop
