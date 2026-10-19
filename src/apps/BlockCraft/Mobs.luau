-- Мобы: свинья, зомби, крипер (Верхний мир), пиглин, зомби-пиглин и хоглин (Незер 1.16).
-- Модели из кубов, своя физика коробки через World:moveBox, простой ИИ: бродить, гнаться, бить, взрываться.
local Textures = require(script.Parent.Textures)

local Mobs = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- детали модели: размер и центр в блоках относительно ног (вперёд = −Z), leg = фаза качания
local function humanoid(skin, shirt, pants, head)
	return {
		{ size = { 0.25, 0.75, 0.25 }, at = { -0.13, 0.375, 0 }, color = pants, leg = 1 },
		{ size = { 0.25, 0.75, 0.25 }, at = { 0.13, 0.375, 0 }, color = pants, leg = -1 },
		{ size = { 0.5, 0.75, 0.26 }, at = { 0, 1.125, 0 }, color = shirt },
		{ size = { 0.25, 0.75, 0.25 }, at = { -0.375, 1.125, 0 }, color = skin, leg = -1, arm = true },
		{ size = { 0.25, 0.75, 0.25 }, at = { 0.375, 1.125, 0 }, color = skin, leg = 1, arm = true },
		{ size = head or { 0.5, 0.5, 0.5 }, at = { 0, 1.75, 0 }, color = skin, head = true },
	}
end

local function quadruped(body, head, legColor, bodySize, headSize, legH, extra)
	local w, h, l = bodySize[1], bodySize[2], bodySize[3]
	local parts = {
		{ size = bodySize, at = { 0, legH + h / 2, 0 }, color = body },
		{ size = headSize, at = { 0, legH + h * 0.7, -l / 2 - headSize[3] / 2 + 0.05 }, color = head, head = true },
	}
	for _, p in { { -1, -1, 1 }, { 1, -1, -1 }, { -1, 1, -1 }, { 1, 1, 1 } } do
		table.insert(parts, { size = { 0.22, legH, 0.22 }, at = { p[1] * (w / 2 - 0.12), legH / 2, p[2] * (l / 2 - 0.15) }, color = legColor, leg = p[3] })
	end
	for _, e in extra or {} do
		table.insert(parts, e)
	end
	return parts
end

Mobs.DEFS = {
	pig = {
		hp = 10, speed = 2.2, half = 0.45, tall = 0.9, drops = { { "porkchop", 1, 3 } }, dim = "overworld", spawn = "day",
		parts = quadruped(rgb(240, 160, 160), rgb(240, 160, 160), rgb(230, 150, 150), { 0.6, 0.5, 0.9 }, { 0.5, 0.5, 0.45 }, 0.35,
			{ { size = { 0.25, 0.15, 0.06 }, at = { 0, 0.62, -0.95 }, color = rgb(250, 120, 140) } }),
	},
	zombie = {
		hp = 20, speed = 2.5, half = 0.3, tall = 1.95, hostile = true, damage = 3, drops = { { "rotten_flesh", 0, 2 } },
		dim = "overworld", spawn = "night", burns = true, armsForward = true,
		parts = humanoid(rgb(96, 146, 84), rgb(0, 166, 166), rgb(62, 58, 160)),
	},
	creeper = {
		hp = 20, speed = 2.3, half = 0.3, tall = 1.7, hostile = true, explode = true, drops = { { "gunpowder", 0, 2 } },
		dim = "overworld", spawn = "night",
		parts = {
			{ size = { 0.25, 0.375, 0.25 }, at = { -0.13, 0.19, -0.2 }, color = rgb(80, 170, 70), leg = 1 },
			{ size = { 0.25, 0.375, 0.25 }, at = { 0.13, 0.19, -0.2 }, color = rgb(80, 170, 70), leg = -1 },
			{ size = { 0.25, 0.375, 0.25 }, at = { -0.13, 0.19, 0.2 }, color = rgb(80, 170, 70), leg = -1 },
			{ size = { 0.25, 0.375, 0.25 }, at = { 0.13, 0.19, 0.2 }, color = rgb(80, 170, 70), leg = 1 },
			{ size = { 0.5, 0.75, 0.26 }, at = { 0, 0.75, 0 }, color = rgb(96, 190, 82) },
			{ size = { 0.5, 0.5, 0.5 }, at = { 0, 1.375, 0 }, color = rgb(96, 190, 82), head = true },
		},
	},
	piglin = {
		hp = 16, speed = 2.6, half = 0.3, tall = 1.95, neutral = true, damage = 5, barter = true, drops = { { "gold_nugget", 0, 2 } },
		dim = "nether", spawn = "any",
		parts = humanoid(rgb(236, 168, 150), rgb(120, 82, 50), rgb(70, 50, 36), { 0.62, 0.5, 0.5 }),
	},
	zombified_piglin = {
		hp = 20, speed = 2.6, half = 0.3, tall = 1.95, neutral = true, damage = 5, drops = { { "rotten_flesh", 0, 1 }, { "gold_nugget", 0, 1 } },
		dim = "nether", spawn = "any",
		parts = humanoid(rgb(222, 150, 140), rgb(110, 150, 90), rgb(90, 70, 60), { 0.62, 0.5, 0.5 }),
	},
	hoglin = {
		hp = 40, speed = 2.6, half = 0.65, tall = 1.4, hostile = true, damage = 4, drops = { { "porkchop", 2, 4 } },
		dim = "nether", spawn = "crimson",
		parts = quadruped(rgb(176, 112, 92), rgb(196, 128, 104), rgb(150, 96, 80), { 1.1, 0.8, 1.4 }, { 0.8, 0.6, 0.8 }, 0.55,
			{ { size = { 0.08, 0.3, 0.08 }, at = { -0.3, 0.95, -1.35 }, color = rgb(240, 236, 220) }, { size = { 0.08, 0.3, 0.08 }, at = { 0.3, 0.95, -1.35 }, color = rgb(240, 236, 220) } }),
	},
}

local Mob = {}
Mob.__index = Mob

function Mobs.new(kind, pos, parent, B, origin)
	local def = Mobs.DEFS[kind]
	local self = setmetatable({ kind = kind, def = def, pos = pos, vel = Vector3.zero, yaw = math.random() * math.pi * 2, hp = def.hp, B = B, origin = CFrame.new(origin) }, Mob)
	self.model = Instance.new("Model")
	self.model.Name = kind
	self.parts = {}
	for _, d in def.parts do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = Vector3.new(d.size[1], d.size[2], d.size[3]) * B
		p.Color = d.color
		p.Material = Enum.Material.SmoothPlastic
		if d.head then
			-- пиксельное лицо спереди (вперёд = −Z)
			local face = Textures.MobFace(kind, d.color)
			if face then
				local decal = Instance.new("Decal")
				decal.Face = Enum.NormalId.Front
				decal.TextureContent = face
				decal.Parent = p
			end
		end
		p.Parent = self.model
		table.insert(self.parts, { part = p, def = d, color = d.color })
	end
	self.model.Parent = parent
	self.wanderTimer, self.attackTimer, self.walk = 0, 0, 0
	return self
end

function Mob:render()
	local B = self.B
	local root = CFrame.new(self.pos * B) * CFrame.Angles(0, self.yaw, 0)
	local swing = math.sin(self.walk * 6) * 0.6
	for _, item in self.parts do
		local d = item.def
		local cf = CFrame.new(d.at[1] * B, d.at[2] * B, d.at[3] * B)
		if d.arm and self.def.armsForward then
			-- руки зомби вытянуты вперёд
			cf = CFrame.new(d.at[1] * B, (d.at[2] + 0.3) * B, d.at[3] * B) * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, -0.3 * B, 0)
		elseif d.leg then
			local pivot = (d.size[2] / 2) * B
			cf = CFrame.new(d.at[1] * B, d.at[2] * B + pivot, d.at[3] * B) * CFrame.Angles(swing * d.leg, 0, 0) * CFrame.new(0, -pivot, 0)
		end
		item.part.CFrame = self.origin * root * cf
	end
end

function Mob:flash(color)
	for _, item in self.parts do
		item.part.Color = color or item.color
	end
end

function Mob:hurt(amount, fromPos)
	self.hp -= amount
	self.hurtTimer = 0.35
	self.angry = true
	self.fleeTimer = 4
	self:flash(Color3.fromRGB(255, 70, 70))
	local away = (self.pos - fromPos) * Vector3.new(1, 0, 1)
	if away.Magnitude > 0 then
		self.vel = away.Unit * 7 + Vector3.new(0, 5, 0)
	end
	return self.hp <= 0
end

function Mob:destroy()
	self.model:Destroy()
end

-- env: world, player (позиция ног), night, damagePlayer(amount, fromPos), explode(pos)
function Mob:update(dt, env)
	local def = self.def
	local world = env.world
	local toPlayer = (env.player - self.pos) * Vector3.new(1, 0, 1)
	local dist = toPlayer.Magnitude
	local move = Vector3.zero
	local chasing = (def.hostile or (def.neutral and self.angry)) and dist < 16 and not env.dead and not env.creative
	if chasing then
		move = dist > 0.01 and toPlayer.Unit or Vector3.zero
	elseif self.fleeTimer and self.fleeTimer > 0 and not def.hostile then
		self.fleeTimer -= dt
		move = dist > 0.01 and -toPlayer.Unit or Vector3.zero
	else
		self.wanderTimer -= dt
		if self.wanderTimer <= 0 then
			self.wanderTimer = math.random(2, 6)
			local a = math.random() * math.pi * 2
			self.wanderDir = math.random() < 0.4 and Vector3.zero or Vector3.new(math.cos(a), 0, math.sin(a))
		end
		move = (self.wanderDir or Vector3.zero) * 0.5
	end
	if move.Magnitude > 0.01 then
		local target = math.atan2(-move.X, -move.Z)
		self.yaw += math.clamp((target - self.yaw + math.pi) % (math.pi * 2) - math.pi, -6 * dt, 6 * dt)
		self.walk += dt * move.Magnitude
	end
	local inLiquid = world:at(self.pos + Vector3.new(0, 0.2, 0))
	local speed = def.speed * (chasing and 1 or 0.8)
	local vy = self.vel.Y - 28 * dt
	if inLiquid == "water" then
		vy = math.max(vy, 1.5) -- всплывают
	end
	local knock = Vector3.new(self.vel.X, 0, self.vel.Z) * math.max(0, 1 - 6 * dt)
	local horizontal = knock.Magnitude > 1 and knock or move * speed
	local newPos, onGround, blocked = world:moveBox(self.pos, Vector3.new(horizontal.X, vy, horizontal.Z) * dt, def.half, def.tall)
	self.pos = newPos
	if onGround then
		vy = 0
		if blocked and move.Magnitude > 0.01 then
			vy = 8 -- запрыгивают на ступеньку
		end
	end
	self.vel = Vector3.new(knock.Magnitude > 1 and knock.X or 0, vy, knock.Magnitude > 1 and knock.Z or 0)

	if self.hurtTimer then
		self.hurtTimer -= dt
		if self.hurtTimer <= 0 then
			self.hurtTimer = nil
			self:flash()
		end
	end
	-- атака
	self.attackTimer -= dt
	local close = dist < def.half + 0.9 and math.abs(env.player.Y - self.pos.Y) < 1.8
	if def.explode and chasing then
		if dist < 2.6 then
			self.fuse = (self.fuse or 0) + dt
			self:flash(math.floor(self.fuse * 8) % 2 == 0 and Color3.new(1, 1, 1) or nil)
			if self.fuse >= 1.5 then
				env.explode(self.pos + Vector3.new(0, 0.8, 0))
				return "exploded"
			end
		elseif self.fuse then
			self.fuse = nil
			self:flash()
		end
	elseif chasing and close and self.attackTimer <= 0 and def.damage then
		self.attackTimer = 1
		env.damagePlayer(def.damage, self.pos, self)
	end
	-- огонь и лава
	if inLiquid == "lava" then
		if self:hurt(4 * dt, self.pos) then
			return "died"
		end
	end
	if def.burns and env.day and env.skyAt(self.pos) then
		self.burn = (self.burn or 0) + dt
		if self.burn > 3 then
			return "burned"
		end
	end
	if self.pos.Y < -10 then
		return "fell"
	end
	return nil
end

-- луч против коробки моба (в блоках): расстояние или nil
function Mob:rayHit(origin, dir, reach)
	local def = self.def
	local minB = self.pos - Vector3.new(def.half, 0, def.half)
	local maxB = self.pos + Vector3.new(def.half, def.tall, def.half)
	local tmin, tmax = 0, reach
	for _, axis in { "X", "Y", "Z" } do
		local o, d = origin[axis], dir[axis]
		if math.abs(d) < 1e-6 then
			if o < minB[axis] or o > maxB[axis] then
				return nil
			end
		else
			local t1, t2 = (minB[axis] - o) / d, (maxB[axis] - o) / d
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
			if tmin > tmax then
				return nil
			end
		end
	end
	return tmin
end

return Mobs
