-- Orbit Strike: 2D twin-stick shooter on the canvas. Protect the space station in the centre from waves of drones.
-- Uses ctx.input (sticks, buttons, rumble), ctx.save, ctx.trophies, ctx.audio and ctx:Loop.
local Game = {}

local W, H = 1920, 1080
local CX, CY = W / 2, H / 2 + 40 -- station centre (HUD takes the top band)
local TOP = 110
local SHIP_R = 24
local SHIP_SPEED = 640
local BULLET_SPEED = 1500
local ENEMY_BULLET_SPEED = 420
local STATION_R = 72
local STATION_MAX = 100
local PULSE_RADIUS = 440
local COMBO_TIME = 2.5
local MAX_PARTICLES = 220

local ORANGE = Color3.fromRGB(248, 150, 30)
local CYAN = Color3.fromRGB(110, 230, 255)
local WHITE = Color3.new(1, 1, 1)

local DRONES = {
	scout = { r = 18, hp = 1, speed = 240, score = 50, damage = 6, charge = 6, color = Color3.fromRGB(255, 176, 64) },
	brute = { r = 34, hp = 6, speed = 105, score = 150, damage = 15, charge = 12, color = Color3.fromRGB(255, 84, 60) },
	gunner = { r = 24, hp = 3, speed = 170, score = 120, damage = 8, charge = 10, color = Color3.fromRGB(186, 110, 255), orbit = 380 },
	mother = { r = 84, hp = 70, speed = 60, score = 2500, damage = 40, charge = 40, color = Color3.fromRGB(255, 60, 120), orbit = 470 },
}

local PICKUPS = {
	repair = { glyph = "+", color = Color3.fromRGB(90, 255, 140), label = "Station repaired" },
	rapid = { glyph = "»", color = CYAN, label = "Rapid fire" },
	shield = { glyph = "▲", color = Color3.fromRGB(255, 220, 90), label = "Extra ship" },
}

local function dist2(ax, ay, bx, by)
	return (ax - bx) ^ 2 + (ay - by) ^ 2
end

-- Rotation of a "▲" glyph pointing along (dx, dy) in screen space.
local function angleOf(dx, dy)
	return math.deg(math.atan2(dx, -dy))
end

function Game.launch(ctx)
	local ui = ctx.ui
	local input = ctx.input
	local font, fontBold = ctx.theme.FontMedium, ctx.theme.FontBold

	ctx.gui.BackgroundColor3 = Color3.fromRGB(3, 3, 12)
	ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = ctx.gui,
	}, { ui.gradient({ Color3.fromRGB(30, 11, 4), Color3.fromRGB(3, 3, 14) }, 90) })
	local canvas = ui.canvas(ctx.gui, W, H)
	canvas.ClipsDescendants = true
	-- Everything that shakes lives in field; the HUD sits on the canvas itself.
	local field = ui.new("Frame", { Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Parent = canvas })

	local function circle(size, color, props, children)
		props = props or {}
		props.AnchorPoint = Vector2.new(0.5, 0.5)
		props.Size = UDim2.fromOffset(size, size)
		props.BackgroundColor3 = color
		props.BorderSizePixel = 0
		props.Parent = props.Parent or field
		children = children or {}
		table.insert(children, ui.corner(UDim.new(0.5, 0)))
		return ui.new("Frame", props, children)
	end

	-- Background: stars and a distant planet
	local stars = {}
	for _ = 1, 110 do
		local size = math.random(1, 3)
		local star = ui.new("Frame", {
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.2 + math.random() * 0.6,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(size, size),
			Parent = field,
		})
		table.insert(stars, { frame = star, x = math.random() * W, y = math.random() * H, speed = 6 + size * 8 })
	end
	circle(900, Color3.fromRGB(200, 90, 20), { Position = UDim2.fromOffset(-120, H + 260), BackgroundTransparency = 0.1 }, {
		ui.gradient({ Color3.fromRGB(255, 170, 70), Color3.fromRGB(60, 15, 0) }, 315),
	})
	circle(1100, ORANGE, { Position = UDim2.fromOffset(-120, H + 260), BackgroundTransparency = 1 }, {
		ui.stroke(ORANGE, 3, 0.75),
	})

	-- Station: core, orbit ring and solar panels that circle around it
	local stationRing = circle(STATION_R * 2 + 90, ORANGE, { Position = UDim2.fromOffset(CX, CY), BackgroundTransparency = 1, ZIndex = 2 }, {
		ui.stroke(ORANGE, 3, 0.45),
	})
	local stationCore = circle(STATION_R * 2, ORANGE, { Position = UDim2.fromOffset(CX, CY), ZIndex = 3 }, {
		ui.gradient({ Color3.fromRGB(255, 220, 160), Color3.fromRGB(150, 60, 10) }, 45),
		ui.stroke(WHITE, 3, 0.3),
	})
	circle(STATION_R, Color3.fromRGB(40, 16, 4), { Position = UDim2.fromOffset(CX, CY), ZIndex = 4 }, { ui.stroke(ORANGE, 2, 0.2) })
	local stationLight = circle(26, CYAN, { Position = UDim2.fromOffset(CX, CY), ZIndex = 5 })
	local panels = {}
	for i = 1, 4 do
		panels[i] = ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(56, 22),
			BackgroundColor3 = Color3.fromRGB(40, 80, 160),
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = field,
		}, { ui.stroke(CYAN, 2, 0.3), ui.corner(3) })
	end

	-- Player ship
	local ship = ui.text("▲", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(SHIP_R * 2 + 10, SHIP_R * 2 + 10),
		TextScaled = true,
		Font = fontBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = CYAN,
		ZIndex = 8,
		Parent = field,
	})
	local shipGlow = circle(SHIP_R * 3, CYAN, { BackgroundTransparency = 0.85, ZIndex = 7 })
	local aimDot = circle(10, CYAN, { BackgroundTransparency = 0.3, ZIndex = 7 })

	-- HUD
	local function hudText(props)
		props.Font = props.Font or fontBold
		props.ZIndex = 20
		props.Parent = canvas
		return ui.text("", props)
	end
	ui.new("Frame", {
		Size = UDim2.fromOffset(W, 90),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 19,
		Parent = canvas,
	})
	local scoreText = hudText({ Size = UDim2.fromOffset(600, 44), Position = UDim2.fromOffset(40, 10), TextSize = 38 })
	local comboText = hudText({ Size = UDim2.fromOffset(600, 30), Position = UDim2.fromOffset(40, 52), TextSize = 24, TextColor3 = ORANGE })
	local waveText = hudText({
		Size = UDim2.fromOffset(600, 44), Position = UDim2.fromOffset(W / 2 - 300, 10), TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local leftText = hudText({
		Size = UDim2.fromOffset(600, 30), Position = UDim2.fromOffset(W / 2 - 300, 52), TextSize = 22, Font = font,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(200, 200, 210),
	})
	hudText({ Text = "STATION", Size = UDim2.fromOffset(160, 30), Position = UDim2.fromOffset(W - 520, 14), TextSize = 22 })
	local hpBack = ui.new("Frame", {
		Size = UDim2.fromOffset(340, 18), Position = UDim2.fromOffset(W - 380, 20),
		BackgroundColor3 = Color3.fromRGB(40, 40, 50), BorderSizePixel = 0, ZIndex = 20, Parent = canvas,
	}, { ui.corner(9) })
	local hpBar = ui.new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(90, 255, 140), BorderSizePixel = 0, ZIndex = 21, Parent = hpBack,
	}, { ui.corner(9) })
	local livesText = hudText({
		Size = UDim2.fromOffset(480, 30), Position = UDim2.fromOffset(W - 520, 50), TextSize = 24, TextColor3 = CYAN,
	})
	local pulseLabel = hudText({
		Size = UDim2.fromOffset(500, 30), Position = UDim2.fromOffset(W / 2 - 250, H - 76), TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local pulseBack = ui.new("Frame", {
		Size = UDim2.fromOffset(420, 12), Position = UDim2.fromOffset(W / 2 - 210, H - 40),
		BackgroundColor3 = Color3.fromRGB(40, 40, 50), BorderSizePixel = 0, ZIndex = 20, Parent = canvas,
	}, { ui.corner(6) })
	local pulseBar = ui.new("Frame", {
		Size = UDim2.fromScale(0, 1), BackgroundColor3 = CYAN, BorderSizePixel = 0, ZIndex = 21, Parent = pulseBack,
	}, { ui.corner(6) })
	local banner = hudText({
		Size = UDim2.fromOffset(W, 120), Position = UDim2.fromOffset(0, CY - 290), TextSize = 64, Font = ctx.theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = ORANGE, TextStrokeTransparency = 0.4,
	})
	local subBanner = hudText({
		Size = UDim2.fromOffset(W, 40), Position = UDim2.fromOffset(0, CY - 180), TextSize = 28, Font = font,
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5,
	})
	local menuBack = ui.new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
		BorderSizePixel = 0, ZIndex = 29, Visible = false, Parent = canvas,
	})
	local centerText = hudText({
		Size = UDim2.fromOffset(W, 460), Position = UDim2.fromOffset(0, H / 2 - 230), TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	centerText.ZIndex = 30

	-- Game state
	local state, menuIndex = "play", 1
	local phase, phaseTimer -- "intro" | "fight" | "clear"
	local x, y, vx, vy, aimX, aimY
	local lives, score, wave, stationHp, stationHitThisWave
	local cooldown, invuln, rapidTime, pulse, combo, comboTimer, shake, elapsed
	local spawnQueue, spawnTimer, spawnInterval
	local bullets, enemyBullets, drones, pickups, particles, rings = {}, {}, {}, {}, {}, {}
	local best = ctx.save:Get("best", 0)
	local bestWave = ctx.save:Get("bestWave", 0)

	local function clearEntities()
		for _, list in { bullets, enemyBullets, drones, pickups, particles, rings } do
			for _, e in list do
				e.frame:Destroy()
			end
			table.clear(list)
		end
	end

	-- Effects
	local function burst(px, py, color, count, speed)
		for _ = 1, count do
			if #particles >= MAX_PARTICLES then
				break
			end
			local size = math.random(4, 9)
			local a = math.random() * math.pi * 2
			local s = speed * (0.4 + math.random() * 0.8)
			local f = ui.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = color, BorderSizePixel = 0,
				Size = UDim2.fromOffset(size, size), Position = UDim2.fromOffset(px, py), ZIndex = 6, Parent = field,
			})
			table.insert(particles, { frame = f, x = px, y = py, vx = math.cos(a) * s, vy = math.sin(a) * s, life = 0.4 + math.random() * 0.4, t = 0 })
		end
	end

	local function ring(px, py, radius, color, duration)
		local f = circle(10, color, { Position = UDim2.fromOffset(px, py), BackgroundTransparency = 1, ZIndex = 6 }, { ui.stroke(color, 4, 0) })
		table.insert(rings, { frame = f, stroke = f:FindFirstChildOfClass("UIStroke"), radius = radius, t = 0, duration = duration })
	end

	local function floatText(px, py, txt, color)
		local f = ui.text(txt, {
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(300, 30), Position = UDim2.fromOffset(px, py),
			TextSize = 24, Font = fontBold, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9, Parent = field,
		})
		table.insert(particles, { frame = f, x = px, y = py, vx = 0, vy = -60, life = 0.9, t = 0, text = true })
	end

	-- Drones
	local function spawnDrone(kind, px, py)
		local def = DRONES[kind]
		local size = def.r * 2
		local frame
		if kind == "scout" then
			frame = ui.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size * 0.75, size * 0.75), Rotation = 45,
				BackgroundColor3 = def.color, BorderSizePixel = 0, ZIndex = 5, Parent = field,
			}, { ui.corner(4), ui.stroke(WHITE, 2, 0.5) })
		elseif kind == "brute" then
			frame = ui.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size, size),
				BackgroundColor3 = def.color, BorderSizePixel = 0, ZIndex = 5, Parent = field,
			}, { ui.corner(10), ui.stroke(Color3.fromRGB(255, 200, 160), 3, 0.3) })
			circle(size * 0.45, Color3.fromRGB(60, 10, 0), { Position = UDim2.fromScale(0.5, 0.5), ZIndex = 6, Parent = frame })
		elseif kind == "gunner" then
			frame = circle(size, def.color, { ZIndex = 5 }, { ui.stroke(WHITE, 3, 0.35) })
			circle(size * 0.4, WHITE, { Position = UDim2.fromScale(0.5, 0.5), ZIndex = 6, Parent = frame })
		else
			frame = circle(size, def.color, { ZIndex = 5 }, {
				ui.gradient({ Color3.fromRGB(255, 120, 170), Color3.fromRGB(110, 10, 50) }, 45),
				ui.stroke(WHITE, 4, 0.3),
			})
			circle(size * 0.5, Color3.fromRGB(30, 0, 15), { Position = UDim2.fromScale(0.5, 0.5), ZIndex = 6, Parent = frame }, { ui.stroke(def.color, 3, 0) })
			circle(size * 0.18, Color3.fromRGB(255, 220, 90), { Position = UDim2.fromScale(0.5, 0.5), ZIndex = 7, Parent = frame })
		end
		local hpScale = 1 + math.max(0, wave - 4) * 0.08
		local drone = {
			kind = kind, def = def, frame = frame, color = def.color, x = px, y = py, r = def.r,
			hp = math.ceil(def.hp * hpScale), maxHp = math.ceil(def.hp * hpScale),
			speed = def.speed * (1 + math.min(wave, 15) * 0.025),
			angle = math.atan2(py - CY, px - CX), dir = math.random() < 0.5 and -1 or 1,
			fireTimer = 1 + math.random() * 1.5, spawnTimer = 3, flash = 0, wobble = math.random() * 10,
		}
		frame.Position = UDim2.fromOffset(px, py)
		table.insert(drones, drone)
		return drone
	end

	local function edgePoint()
		local a = math.random() * math.pi * 2
		return CX + math.cos(a) * 1080, CY + math.sin(a) * 640
	end

	local function buildWave(n)
		local queue = {}
		for _ = 1, 4 + n * 2 do
			table.insert(queue, "scout")
		end
		for _ = 1, math.floor(n / 2) do
			table.insert(queue, "brute")
		end
		for _ = 1, math.max(0, math.floor((n - 1) / 2)) do
			table.insert(queue, "gunner")
		end
		-- shuffle, then the mothership arrives in the middle of every fifth wave
		for i = #queue, 2, -1 do
			local j = math.random(1, i)
			queue[i], queue[j] = queue[j], queue[i]
		end
		if n % 5 == 0 then
			table.insert(queue, math.floor(#queue / 2) + 1, "mother")
		end
		return queue
	end

	local function showBanner(title, sub)
		banner.Text = title
		subBanner.Text = sub or ""
	end

	local function startWave(n)
		wave = n
		phase, phaseTimer = "intro", 2.4
		spawnQueue = buildWave(n)
		spawnInterval = math.max(0.32, 1.25 - n * 0.07)
		spawnTimer = 0
		stationHitThisWave = false
		if n >= 5 then
			ctx.trophies:Unlock("wave_5")
		end
		if n >= 10 then
			ctx.trophies:Unlock("wave_10")
		end
		local sub = n % 5 == 0 and "Warning: mothership incoming" or `{#spawnQueue} drones inbound`
		if n == 1 then
			sub = `Protect the station!   Fire: {input:Glyph("cross")}   Pulse bomb: {input:Glyph("l1")}`
		end
		showBanner(`WAVE {n}`, sub)
		ctx.audio:Play("notify", { volume = 0.5, pitch = 0.9 })
	end

	local function reset()
		clearEntities()
		x, y, vx, vy = CX, CY + 240, 0, 0
		aimX, aimY = 0, -1
		lives, score, stationHp = 3, 0, STATION_MAX
		cooldown, invuln, rapidTime, pulse, combo, comboTimer, shake, elapsed = 0, 2, 0, 0, 0, 0, 0, 0
		state = "play"
		centerText.Text = ""
		menuBack.Visible = false
		startWave(1)
	end

	local MENU = { "Resume", "Restart", "Quit to PS5 Menu" }
	local function drawMenu()
		local lines = { "PAUSED", "" }
		for i, item in MENU do
			table.insert(lines, (i == menuIndex and "▶  " or "    ") .. item)
		end
		centerText.Text = table.concat(lines, "\n")
		menuBack.Visible = true
	end

	local function resume()
		state = "play"
		centerText.Text = ""
		menuBack.Visible = false
	end

	local function gameOver(reason)
		state = "over"
		input:Rumble(1, 0.6)
		ctx.audio:Play("explosion", { volume = 0.9, pitch = 0.5 })
		local newBest = score > best
		if newBest then
			best = score
			ctx.save:Set("best", best)
		end
		if wave > bestWave then
			bestWave = wave
			ctx.save:Set("bestWave", bestWave)
		end
		ctx.save:Set("games", ctx.save:Get("games", 0) + 1)
		showBanner("", "")
		menuBack.Visible = true
		centerText.Text = `{reason}\n\nScore: {score}{newBest and "   NEW BEST!" or ""}\nWave reached: {wave}   Best: {best} (wave {bestWave})\n\n{input:Glyph("cross")} — play again    {input:Glyph("circle")} — quit`
	end

	local function addScore(points, px, py)
		local mult = math.min(1 + combo // 5, 8)
		local gained = points * mult
		score += gained
		if px then
			floatText(px, py - 30, `+{gained}`, mult > 1 and ORANGE or WHITE)
		end
		if score >= 10000 then
			ctx.trophies:Unlock("score_10000")
		end
	end

	local function dropPickup(px, py, kind)
		if not kind then
			local roll = math.random()
			if roll < 0.4 then
				kind = "repair"
			elseif roll < 0.85 then
				kind = "rapid"
			else
				kind = "shield"
			end
		end
		local def = PICKUPS[kind]
		local f = circle(44, def.color, { Position = UDim2.fromOffset(px, py), BackgroundTransparency = 0.3, ZIndex = 6 }, { ui.stroke(WHITE, 2, 0.2) })
		ui.text(def.glyph, {
			Size = UDim2.fromScale(1, 1), TextScaled = true, Font = fontBold, TextColor3 = Color3.new(0, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7, Parent = f,
		})
		table.insert(pickups, { frame = f, kind = kind, x = px, y = py, life = 10 })
	end

	local function killDrone(i, byPulse)
		local d = drones[i]
		table.remove(drones, i)
		d.frame:Destroy()
		burst(d.x, d.y, d.color, d.kind == "mother" and 40 or (d.kind == "brute" and 16 or 9), d.kind == "mother" and 500 or 300)
		ring(d.x, d.y, d.r * 3, d.color, 0.35)
		combo += 1
		comboTimer = COMBO_TIME
		if combo >= 20 then
			ctx.trophies:Unlock("combo_20")
		end
		addScore(d.def.score, d.x, d.y)
		pulse = math.min(100, pulse + d.def.charge)
		ctx.trophies:Unlock("first_kill")
		if d.kind == "mother" then
			ctx.trophies:Unlock("mothership")
			ctx.audio:Play("explosion", { volume = 1, pitch = 0.45 })
			input:Rumble(1, 0.8)
			shake = 0.6
			dropPickup(d.x - 40, d.y, "repair")
			dropPickup(d.x + 40, d.y, "rapid")
			showBanner("MOTHERSHIP DOWN", "")
			phaseTimer = math.max(phaseTimer or 0, 0)
		else
			if not byPulse then
				ctx.audio:Play("explosion", { volume = 0.3, pitch = 1.3 + math.random() * 0.3 })
			end
			local chance = d.kind == "brute" and 0.25 or (d.kind == "gunner" and 0.15 or 0.05)
			if math.random() < chance then
				dropPickup(d.x, d.y)
			end
		end
	end

	local function damageDrone(i, amount)
		local d = drones[i]
		d.hp -= amount
		d.flash = 0.06
		if d.hp <= 0 then
			killDrone(i, false)
			return true
		end
		ctx.audio:Play("hit", { volume = 0.15, pitch = 1.6 })
		return false
	end

	local function hurtStation(amount)
		stationHp = math.max(0, stationHp - amount)
		stationHitThisWave = true
		shake = math.max(shake, 0.25)
		input:Rumble(0.5, 0.2)
		ctx.audio:Play("hit", { volume = 0.5, pitch = 0.6 })
		stationCore.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
		if stationHp <= 0 then
			burst(CX, CY, ORANGE, 50, 600)
			gameOver("STATION DESTROYED")
		end
	end

	local function hurtShip()
		if invuln > 0 or state ~= "play" then
			return
		end
		lives -= 1
		invuln = 2
		combo = 0
		shake = 0.4
		input:Rumble(0.9, 0.35)
		ctx.audio:Play("explosion", { volume = 0.6, pitch = 0.8 })
		burst(x, y, CYAN, 20, 400)
		if lives <= 0 then
			gameOver("SHIP DESTROYED")
		end
	end

	local function firePulse()
		if pulse < 100 or state ~= "play" then
			return
		end
		pulse = 0
		ring(x, y, PULSE_RADIUS, CYAN, 0.45)
		ring(x, y, PULSE_RADIUS * 0.6, WHITE, 0.3)
		ctx.audio:Play("explosion", { volume = 0.8, pitch = 0.7 })
		input:Rumble(1, 0.4)
		shake = 0.35
		local killed = 0
		for i = #drones, 1, -1 do
			local d = drones[i]
			if dist2(d.x, d.y, x, y) < (PULSE_RADIUS + d.r) ^ 2 then
				if d.kind == "mother" then
					d.hp -= 15
					d.flash = 0.1
					if d.hp <= 0 then
						killDrone(i, true)
						killed += 1
					end
				else
					killDrone(i, true)
					killed += 1
				end
			end
		end
		for i = #enemyBullets, 1, -1 do
			local b = enemyBullets[i]
			if dist2(b.x, b.y, x, y) < PULSE_RADIUS ^ 2 then
				b.frame:Destroy()
				table.remove(enemyBullets, i)
			end
		end
		if killed >= 5 then
			ctx.trophies:Unlock("pulse_5")
		end
	end

	local function shoot(dx, dy)
		local spread = rapidTime > 0 and { -0.12, 0, 0.12 } or { 0 }
		local base = math.atan2(dy, dx)
		for _, off in spread do
			local a = base + off
			local b = ui.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = rapidTime > 0 and WHITE or CYAN, BorderSizePixel = 0,
				Size = UDim2.fromOffset(24, 6), Rotation = math.deg(a), ZIndex = 6, Parent = field,
			}, { ui.corner(3) })
			table.insert(bullets, { frame = b, x = x + math.cos(a) * 30, y = y + math.sin(a) * 30, vx = math.cos(a) * BULLET_SPEED, vy = math.sin(a) * BULLET_SPEED })
		end
		ctx.audio:Play("shoot", { volume = 0.12, pitch = 1.9 + math.random() * 0.2 })
	end

	local function enemyShoot(d, tx, ty, spread)
		local base = math.atan2(ty - d.y, tx - d.x)
		for _, off in spread do
			local a = base + off
			local f = circle(14, Color3.fromRGB(255, 90, 200), { Position = UDim2.fromOffset(d.x, d.y), ZIndex = 6 }, { ui.stroke(WHITE, 2, 0.3) })
			table.insert(enemyBullets, { frame = f, x = d.x, y = d.y, vx = math.cos(a) * ENEMY_BULLET_SPEED, vy = math.sin(a) * ENEMY_BULLET_SPEED })
		end
	end

	local function nearestDrone()
		local bestD, bestDist = nil, math.huge
		for _, d in drones do
			local onScreen = d.x > 0 and d.x < W and d.y > TOP - 40 and d.y < H
			local dd = dist2(d.x, d.y, x, y)
			if onScreen and dd < bestDist then
				bestD, bestDist = d, dd
			end
		end
		return bestD
	end

	-- Input
	input:On("press", function(btn)
		if state == "play" then
			if btn == "options" then
				state, menuIndex = "paused", 1
				drawMenu()
			elseif btn == "l1" or btn == "r1" then
				firePulse()
			end
		elseif state == "paused" then
			if btn == "up" or btn == "down" then
				menuIndex = (menuIndex - 1 + (btn == "down" and 1 or -1)) % #MENU + 1
				ctx.audio:Play("move", { volume = 0.3, pitch = 1.6 })
				drawMenu()
			elseif btn == "circle" or btn == "options" then
				resume()
			elseif btn == "cross" then
				ctx.audio:Play("confirm", { volume = 0.4 })
				if menuIndex == 1 then
					resume()
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

	-- System pause (PS button): ctx:Loop stops by itself, and the game menu is waiting on return.
	ctx:On("pause", function()
		if state == "play" then
			state, menuIndex = "paused", 1
			drawMenu()
		end
	end)

	reset()

	local stationSpin = 0
	ctx:Loop(function(dt)
		dt = math.min(dt, 1 / 20)
		for _, s in stars do
			s.x = (s.x - s.speed * dt) % W
			s.frame.Position = UDim2.fromOffset(s.x, s.y)
		end
		stationSpin += dt * 0.5
		for i, p in panels do
			local a = stationSpin + (i - 1) * math.pi / 2
			p.Position = UDim2.fromOffset(CX + math.cos(a) * (STATION_R + 70), CY + math.sin(a) * (STATION_R + 70))
			p.Rotation = math.deg(a)
		end
		stationLight.BackgroundTransparency = 0.2 + 0.4 * (0.5 + 0.5 * math.sin(stationSpin * 8))
		stationRing.Rotation = math.deg(stationSpin)

		-- effects run even after game over
		for i = #particles, 1, -1 do
			local p = particles[i]
			p.t += dt
			p.x += p.vx * dt
			p.y += p.vy * dt
			p.vx *= 0.94
			if not p.text then
				p.vy *= 0.94
			end
			local k = p.t / p.life
			p.frame.Position = UDim2.fromOffset(p.x, p.y)
			if p.text then
				p.frame.TextTransparency = k
			else
				p.frame.BackgroundTransparency = k
			end
			if k >= 1 then
				p.frame:Destroy()
				table.remove(particles, i)
			end
		end
		for i = #rings, 1, -1 do
			local r = rings[i]
			r.t += dt
			local k = math.min(r.t / r.duration, 1)
			local size = 10 + (r.radius * 2 - 10) * (1 - (1 - k) ^ 3)
			r.frame.Size = UDim2.fromOffset(size, size)
			if r.stroke then
				r.stroke.Transparency = k
			end
			if k >= 1 then
				r.frame:Destroy()
				table.remove(rings, i)
			end
		end
		if shake > 0 then
			shake = math.max(0, shake - dt)
			local m = shake * 30
			field.Position = UDim2.fromOffset((math.random() - 0.5) * m, (math.random() - 0.5) * m)
		else
			field.Position = UDim2.fromOffset(0, 0)
		end
		stationCore.BackgroundColor3 = stationCore.BackgroundColor3:Lerp(ORANGE, math.min(1, dt * 6))

		if state ~= "play" then
			return
		end
		elapsed += dt

		-- Waves
		if phase == "intro" then
			phaseTimer -= dt
			if phaseTimer <= 0 then
				phase = "fight"
				showBanner("", "")
			end
		elseif phase == "fight" then
			spawnTimer -= dt
			if #spawnQueue > 0 and spawnTimer <= 0 then
				spawnTimer = spawnInterval
				local kind = table.remove(spawnQueue, 1)
				local px, py = edgePoint()
				spawnDrone(kind, px, py)
				if kind == "mother" then
					showBanner("MOTHERSHIP", "Bring it down!")
					ctx.audio:Play("notify", { volume = 0.7, pitch = 0.6 })
				end
			end
			if #spawnQueue == 0 and #drones == 0 then
				phase, phaseTimer = "clear", 2.2
				local bonus = 250 * wave
				score += bonus
				stationHp = math.min(STATION_MAX, stationHp + 10)
				if wave >= 3 and not stationHitThisWave then
					ctx.trophies:Unlock("flawless")
				end
				if score >= 10000 then
					ctx.trophies:Unlock("score_10000")
				end
				showBanner(`WAVE {wave} CLEAR`, `Bonus +{bonus}   Station repaired +10`)
				ctx.audio:Play("confirm", { volume = 0.6, pitch = 0.9 })
			end
		elseif phase == "clear" then
			phaseTimer -= dt
			if phaseTimer <= 0 then
				startWave(wave + 1)
			end
		end

		-- Ship movement
		local axes = input:GetAxes()
		local mx, my = axes.lx, -axes.ly
		local mag = math.sqrt(mx * mx + my * my)
		if mag > 1 then
			mx, my = mx / mag, my / mag
		end
		vx += (mx * SHIP_SPEED - vx) * math.min(1, dt * 12)
		vy += (my * SHIP_SPEED - vy) * math.min(1, dt * 12)
		x = math.clamp(x + vx * dt, 40, W - 40)
		y = math.clamp(y + vy * dt, TOP, H - 40)
		local sd = math.sqrt(dist2(x, y, CX, CY))
		local minD = STATION_R + SHIP_R + 10
		if sd < minD and sd > 0 then
			x = CX + (x - CX) / sd * minD
			y = CY + (y - CY) / sd * minD
		end

		-- Aim: right stick wins, otherwise auto-aim at the nearest drone while firing
		local firing = input:IsDown("cross") or input:IsDown("r2") or axes.r2 > 0.3
		local rmag = math.sqrt(axes.rx * axes.rx + axes.ry * axes.ry)
		if rmag > 0.35 then
			aimX, aimY = axes.rx / rmag, -axes.ry / rmag
			firing = true
		elseif firing then
			local target = nearestDrone()
			if target then
				local dx, dy = target.x - x, target.y - y
				local len = math.sqrt(dx * dx + dy * dy)
				if len > 0 then
					aimX, aimY = dx / len, dy / len
				end
			end
		elseif mag > 0.2 then
			aimX, aimY = mx / math.max(mag, 1e-3), my / math.max(mag, 1e-3)
		end
		ship.Position = UDim2.fromOffset(x, y)
		ship.Rotation = angleOf(aimX, aimY)
		shipGlow.Position = ship.Position
		aimDot.Position = UDim2.fromOffset(x + aimX * 70, y + aimY * 70)
		invuln = math.max(0, invuln - dt)
		ship.Visible = invuln == 0 or math.floor(invuln * 10) % 2 == 0
		rapidTime = math.max(0, rapidTime - dt)
		ship.TextColor3 = rapidTime > 0 and WHITE or CYAN

		cooldown -= dt
		if firing and cooldown <= 0 then
			cooldown = rapidTime > 0 and 0.07 or 0.13
			shoot(aimX, aimY)
		end

		comboTimer -= dt
		if comboTimer <= 0 then
			combo = 0
		end

		-- Player bullets
		for i = #bullets, 1, -1 do
			local b = bullets[i]
			b.x += b.vx * dt
			b.y += b.vy * dt
			local gone = b.x < -40 or b.x > W + 40 or b.y < -40 or b.y > H + 40
			if not gone then
				for j = #drones, 1, -1 do
					local d = drones[j]
					if dist2(b.x, b.y, d.x, d.y) < (d.r + 6) ^ 2 then
						damageDrone(j, 1)
						gone = true
						break
					end
				end
			end
			if gone then
				b.frame:Destroy()
				table.remove(bullets, i)
			else
				b.frame.Position = UDim2.fromOffset(b.x, b.y)
			end
		end

		-- Drones
		for i = #drones, 1, -1 do
			local d = drones[i]
			if state ~= "play" then
				break
			end
			local dx, dy = CX - d.x, CY - d.y
			local dc = math.sqrt(dx * dx + dy * dy)
			local orbit = d.def.orbit
			if orbit and dc < orbit + 20 then
				-- circle the station and shoot
				d.angle = math.atan2(d.y - CY, d.x - CX) + d.dir * d.speed / orbit * dt * 0.6
				local radius = dc + (orbit - dc) * math.min(1, dt * 2)
				d.x = CX + math.cos(d.angle) * radius
				d.y = CY + math.sin(d.angle) * radius
				d.fireTimer -= dt
				if d.fireTimer <= 0 then
					if d.kind == "mother" then
						d.fireTimer = math.max(1.4, 3 - wave * 0.08)
						enemyShoot(d, x, y, { -0.25, 0, 0.25 })
					else
						d.fireTimer = math.max(1.3, 2.6 - wave * 0.06)
						local atShip = math.random() < 0.6
						enemyShoot(d, atShip and x or CX, atShip and y or CY, { 0 })
					end
				end
				if d.kind == "mother" then
					d.spawnTimer -= dt
					if d.spawnTimer <= 0 then
						d.spawnTimer = 4
						spawnDrone("scout", d.x + 60, d.y)
						spawnDrone("scout", d.x - 60, d.y)
					end
				end
			else
				local wob = math.sin(elapsed * 3 + d.wobble) * 0.35
				local ux, uy = dx / dc, dy / dc
				local px, py = -uy, ux
				d.x += (ux + px * wob) * d.speed * dt
				d.y += (uy + py * wob) * d.speed * dt
			end
			if d.kind == "scout" then
				d.frame.Rotation += 240 * dt
			elseif d.kind == "mother" then
				d.frame.Rotation += 20 * dt
			end
			d.frame.Position = UDim2.fromOffset(d.x, d.y)
			if d.flash > 0 then
				d.flash -= dt
				d.frame.BackgroundColor3 = WHITE
			else
				d.frame.BackgroundColor3 = d.color
			end

			if dc < STATION_R + d.r then
				-- rammed the station
				table.remove(drones, i)
				d.frame:Destroy()
				burst(d.x, d.y, d.color, 10, 300)
				hurtStation(d.def.damage)
			elseif invuln == 0 and dist2(d.x, d.y, x, y) < (d.r + SHIP_R) ^ 2 then
				hurtShip()
				if drones[i] == d then
					damageDrone(i, d.kind == "scout" and 99 or 2)
				end
			end
		end

		-- Enemy bullets
		for i = #enemyBullets, 1, -1 do
			local b = enemyBullets[i]
			if state ~= "play" then
				break
			end
			b.x += b.vx * dt
			b.y += b.vy * dt
			local gone = b.x < -40 or b.x > W + 40 or b.y < -40 or b.y > H + 40
			if not gone and dist2(b.x, b.y, CX, CY) < (STATION_R + 7) ^ 2 then
				gone = true
				hurtStation(2)
			elseif not gone and invuln == 0 and dist2(b.x, b.y, x, y) < (SHIP_R) ^ 2 then
				gone = true
				hurtShip()
			end
			if gone then
				b.frame:Destroy()
				table.remove(enemyBullets, i)
			else
				b.frame.Position = UDim2.fromOffset(b.x, b.y)
			end
		end

		-- Pickups
		for i = #pickups, 1, -1 do
			local p = pickups[i]
			p.life -= dt
			p.frame.BackgroundTransparency = p.life < 3 and (math.floor(p.life * 6) % 2 == 0 and 0.3 or 0.8) or 0.3
			local taken = dist2(p.x, p.y, x, y) < (SHIP_R + 26) ^ 2
			if taken then
				if p.kind == "repair" then
					stationHp = math.min(STATION_MAX, stationHp + 15)
				elseif p.kind == "rapid" then
					rapidTime = 8
				elseif p.kind == "shield" then
					lives = math.min(5, lives + 1)
				end
				floatText(p.x, p.y - 30, PICKUPS[p.kind].label, PICKUPS[p.kind].color)
				ctx.audio:Play("confirm", { volume = 0.5, pitch = 1.4 })
			end
			if taken or p.life <= 0 then
				p.frame:Destroy()
				table.remove(pickups, i)
			end
		end

		-- HUD
		if state ~= "play" then
			return
		end
		scoreText.Text = `SCORE {score}`
		comboText.Text = combo >= 5 and `COMBO {combo}   x{math.min(1 + combo // 5, 8)}` or (rapidTime > 0 and `RAPID FIRE {math.ceil(rapidTime)}s` or `BEST {math.max(best, score)}`)
		waveText.Text = `WAVE {wave}`
		leftText.Text = phase == "fight" and `Drones left: {#spawnQueue + #drones}` or ""
		hpBar.Size = UDim2.fromScale(stationHp / STATION_MAX, 1)
		hpBar.BackgroundColor3 = stationHp > 50 and Color3.fromRGB(90, 255, 140) or (stationHp > 25 and ORANGE or Color3.fromRGB(255, 70, 70))
		livesText.Text = "SHIPS " .. string.rep("▲ ", lives)
		pulseBar.Size = UDim2.fromScale(pulse / 100, 1)
		pulseBar.BackgroundColor3 = pulse >= 100 and WHITE or CYAN
		pulseLabel.Text = pulse >= 100 and `PULSE READY — press {input:Glyph("l1")}` or `PULSE {math.floor(pulse)}%`
	end)
end

return Game
