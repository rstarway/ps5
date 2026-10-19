-- Star Pilot — пример 2D-игры на GUI. Использует ctx.input, ctx.save, ctx.trophies, ctx.audio, ctx:Loop.
local Game = {}

local W, H = 1920, 1080
local SHIP_SPEED = 720
local BULLET_SPEED = 1400

function Game.launch(ctx)
	local ui = ctx.ui
	ctx.gui.BackgroundColor3 = Color3.fromRGB(4, 5, 16)
	ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = ctx.gui,
	}, { ui.gradient({ Color3.fromRGB(10, 8, 40), Color3.fromRGB(2, 2, 10) }, 90) })
	local canvas = ui.canvas(ctx.gui, W, H)
	canvas.ClipsDescendants = true

	-- Звёзды
	local stars = {}
	for _ = 1, 90 do
		local size = math.random(2, 4)
		local star = ui.new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = math.random() * 0.6,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(size, size),
			Parent = canvas,
		})
		table.insert(stars, { frame = star, x = math.random() * W, y = math.random() * H, speed = 40 + size * 60 })
	end

	-- HUD
	local hud = ui.text("", { Size = UDim2.fromOffset(1200, 40), Position = UDim2.fromOffset(40, 24), TextSize = 30, Font = ctx.theme.FontBold, ZIndex = 10, Parent = canvas })
	local centerText = ui.text("", {
		Size = UDim2.fromOffset(W, 300), Position = UDim2.fromOffset(0, H / 2 - 150), TextSize = 40, Font = ctx.theme.FontBold,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 20, Parent = canvas,
	})

	local ship = ui.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Size = UDim2.fromOffset(70, 70), ZIndex = 5, Parent = canvas })
	ui.text("▲", { Size = UDim2.fromScale(1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(90, 220, 255), ZIndex = 5, Parent = ship })

	local state, menuIndex = "play", 1
	local x, y, lives, score, elapsed, cooldown, spawnTimer, invuln, wasHit
	local bullets, rocks = {}, {}
	local best = ctx.save:Get("best", 0)

	local function clearEntities()
		for _, list in { bullets, rocks } do
			for _, e in list do
				e.frame:Destroy()
			end
			table.clear(list)
		end
	end

	local function reset()
		clearEntities()
		x, y = W / 2, H - 160
		lives, score, elapsed, cooldown, spawnTimer, invuln, wasHit = 3, 0, 0, 0, 0, 0, false
		state = "play"
		centerText.Text = ""
	end

	local MENU = { "Resume", "Restart", "Quit to PS5 Menu" }
	local function drawMenu()
		local lines = { "PAUSED", "" }
		for i, item in MENU do
			table.insert(lines, (i == menuIndex and "▶  " or "    ") .. item)
		end
		centerText.Text = table.concat(lines, "\n")
	end

	local function gameOver()
		state = "over"
		ctx.input:Rumble(1, 0.5)
		ctx.audio:Play("explosion", { volume = 0.8, pitch = 0.6 })
		if score > best then
			best = score
			ctx.save:Set("best", best)
		end
		ctx.save:Set("games", ctx.save:Get("games", 0) + 1)
		centerText.Text = `GAME OVER\nScore: {score}   Best: {best}\n\n{ctx.input:Glyph("cross")} — play again    {ctx.input:Glyph("circle")} — quit`
	end

	local function spawnRock()
		local r = math.random(30, 70)
		local rock = ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromHSV(0.07, 0.3, 0.35 + math.random() * 0.25),
			Size = UDim2.fromOffset(r * 2, r * 2),
			ZIndex = 4,
			Parent = canvas,
		}, { ui.corner(UDim.new(0.5, 0)), ui.stroke(Color3.fromRGB(255, 150, 90), 2, 0.5) })
		local speed = 160 + elapsed * 4 + math.random() * 120
		table.insert(rocks, { frame = rock, x = math.random(60, W - 60), y = -r, vx = (math.random() - 0.5) * 120, vy = speed, r = r, hp = r > 50 and 2 or 1 })
	end

	local function checkTrophies()
		if score >= 100 then
			ctx.trophies:Unlock("score_100")
		end
		if score >= 500 then
			ctx.trophies:Unlock("score_500")
		end
		if score >= 200 and not wasHit then
			ctx.trophies:Unlock("untouchable")
		end
		if elapsed >= 60 then
			ctx.trophies:Unlock("survivor")
		end
	end

	ctx.input:On("press", function(btn)
		if state == "play" then
			if btn == "options" then
				state, menuIndex = "paused", 1
				drawMenu()
			end
		elseif state == "paused" then
			if btn == "up" or btn == "down" then
				menuIndex = (menuIndex - 1 + (btn == "down" and 1 or -1)) % #MENU + 1
				ctx.audio:Play("move", { volume = 0.3, pitch = 1.6 })
				drawMenu()
			elseif btn == "circle" or btn == "options" then
				state = "play"
				centerText.Text = ""
			elseif btn == "cross" then
				if menuIndex == 1 then
					state = "play"
					centerText.Text = ""
				elseif menuIndex == 2 then
					reset()
				else
					ctx:Exit()
				end
			end
		elseif state == "over" then
			if btn == "cross" then
				reset()
			elseif btn == "circle" then
				ctx:Exit()
			end
		end
	end)

	-- Пауза системы (кнопка PS): ctx:Loop останавливается сам, здесь — ставим и игровое меню.
	ctx:On("pause", function()
		if state == "play" then
			state, menuIndex = "paused", 1
			drawMenu()
		end
	end)

	reset()

	ctx:Loop(function(dt)
		for _, s in stars do
			s.y = (s.y + s.speed * dt) % H
			s.frame.Position = UDim2.fromOffset(s.x, s.y)
		end
		if state ~= "play" then
			return
		end
		elapsed += dt
		local axes = ctx.input:GetAxes()
		x = math.clamp(x + axes.lx * SHIP_SPEED * dt, 40, W - 40)
		y = math.clamp(y - axes.ly * SHIP_SPEED * dt, 80, H - 40)
		ship.Position = UDim2.fromOffset(x, y)
		invuln = math.max(0, invuln - dt)
		ship.Visible = invuln == 0 or math.floor(invuln * 10) % 2 == 0

		cooldown -= dt
		if (ctx.input:IsDown("cross") or ctx.input:IsDown("r2")) and cooldown <= 0 then
			cooldown = 0.16
			local b = ui.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(120, 240, 255), BorderSizePixel = 0,
				Size = UDim2.fromOffset(6, 26), ZIndex = 3, Parent = canvas,
			}, { ui.corner(3) })
			table.insert(bullets, { frame = b, x = x, y = y - 40 })
			ctx.audio:Play("shoot", { volume = 0.15, pitch = 1.8 })
		end

		spawnTimer -= dt
		if spawnTimer <= 0 then
			spawnTimer = math.max(0.25, 1.1 - elapsed * 0.012)
			spawnRock()
		end

		for i = #bullets, 1, -1 do
			local b = bullets[i]
			b.y -= BULLET_SPEED * dt
			b.frame.Position = UDim2.fromOffset(b.x, b.y)
			if b.y < -30 then
				b.frame:Destroy()
				table.remove(bullets, i)
			end
		end

		for i = #rocks, 1, -1 do
			local r = rocks[i]
			r.x += r.vx * dt
			r.y += r.vy * dt
			r.frame.Position = UDim2.fromOffset(r.x, r.y)
			local destroyed = false
			for j = #bullets, 1, -1 do
				local b = bullets[j]
				if (b.x - r.x) ^ 2 + (b.y - r.y) ^ 2 < r.r ^ 2 then
					b.frame:Destroy()
					table.remove(bullets, j)
					r.hp -= 1
					if r.hp <= 0 then
						destroyed = true
						score += r.r > 50 and 20 or 10
						ctx.audio:Play("explosion", { volume = 0.35, pitch = 1.4 })
						ctx.trophies:Unlock("first_blood")
						break
					end
				end
			end
			if not destroyed and invuln == 0 and (x - r.x) ^ 2 + (y - r.y) ^ 2 < (r.r + 26) ^ 2 then
				destroyed = true
				lives -= 1
				wasHit = true
				invuln = 2
				ctx.input:Rumble(0.8, 0.3)
				ctx.audio:Play("hit", { volume = 0.6, pitch = 0.8 })
				if lives <= 0 then
					r.frame:Destroy()
					table.remove(rocks, i)
					gameOver()
					return
				end
			end
			if destroyed or r.y > H + 100 then
				r.frame:Destroy()
				table.remove(rocks, i)
			end
		end

		checkTrophies()
		hud.Text = `Score: {score}    Best: {math.max(best, score)}    Lives: {string.rep("♥", lives)}    {math.floor(elapsed)} s`
	end)
end

return Game
