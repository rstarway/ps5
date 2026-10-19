-- Генерация миров BlockCraft по зерну: Верхний мир (равнины, леса, пустыня, снега, пещеры, руды, озёра,
-- разрушенный портал) и Незер 1.16 (пустоши, багровый и искажённый леса, долина душ, древние обломки).
-- Мир — таблица key -> имя блока; key = x + z*SX + y*SX*SZ.
local Terrain = {}

local SX, SZ = 64, 64
Terrain.SX, Terrain.SZ = SX, SZ

function Terrain.key(x, y, z)
	return x + z * SX + y * SX * SZ
end
local key = Terrain.key

local function newWorld(H)
	local w = { H = H, blocks = {} }
	function w.inside(x, y, z)
		return x >= 0 and z >= 0 and y >= 0 and x < SX and z < SZ and y < H
	end
	function w.get(x, y, z)
		if not w.inside(x, y, z) then
			return nil
		end
		return w.blocks[key(x, y, z)]
	end
	function w.set(x, y, z, v)
		if w.inside(x, y, z) then
			w.blocks[key(x, y, z)] = v
		end
	end
	return w
end

-- рудные жилы: случайное блуждание, заменяем только «хозяина» (камень или незерак)
local function veins(w, rng, host, ore, count, minY, maxY, size)
	for _ = 1, count do
		local x, y, z = rng:NextInteger(0, SX - 1), rng:NextInteger(minY, maxY), rng:NextInteger(0, SZ - 1)
		for _ = 1, size do
			if w.get(x, y, z) == host then
				w.set(x, y, z, ore)
			end
			x += rng:NextInteger(-1, 1)
			y += rng:NextInteger(-1, 1)
			z += rng:NextInteger(-1, 1)
		end
	end
end

local function sphere(w, cx, cy, cz, r, fn)
	local ri = math.ceil(r)
	for dx = -ri, ri do
		for dy = -ri, ri do
			for dz = -ri, ri do
				if dx * dx + dy * dy + dz * dz <= r * r then
					fn(math.floor(cx) + dx, math.floor(cy) + dy, math.floor(cz) + dz, dy)
				end
			end
		end
	end
end

local function oakTree(w, rng, x, y, z, log, leaves)
	local h = rng:NextInteger(4, 6)
	for dy = 1, h do
		w.set(x, y + dy, z, log)
	end
	for dy = h - 2, h + 1 do
		local r = dy >= h and 1 or 2
		for dx = -r, r do
			for dz = -r, r do
				local corner = math.abs(dx) == r and math.abs(dz) == r
				if not (corner and (dy == h + 1 or rng:NextNumber(0, 1) < 0.5)) and not w.get(x + dx, y + dy, z + dz) then
					w.set(x + dx, y + dy, z + dz, leaves)
				end
			end
		end
	end
end

function Terrain.Overworld(seed)
	local H, SEA = 56, 12
	local w = newWorld(H)
	w.sea = SEA
	local rng = Random.new(seed)
	local ox, oz = rng:NextNumber(-5000, 5000), rng:NextNumber(-5000, 5000)
	local tops, biomes = {}, {}
	for x = 0, SX - 1 do
		for z = 0, SZ - 1 do
			local nx, nz = x + ox, z + oz
			local temp = math.noise(nx / 64, nz / 64, 0.37)
			local hills = math.noise(nx / 34, nz / 34, 1.71) * 18 + math.noise(nx / 11, nz / 11, 2.93) * 4
			local biome = temp > 0.2 and "desert" or temp < -0.22 and "snowy" or (math.noise(nx / 24, nz / 24, 5.13) > 0.05 and "forest" or "plains")
			if biome == "desert" then
				hills *= 0.45
			end
			local h = math.clamp(math.floor(SEA + 2 + hills), 4, H - 14)
			tops[x + z * SX], biomes[x + z * SX] = h, biome
			w.set(x, 0, z, "bedrock")
			for y = 1, h do
				local id = "stone"
				if y <= 2 and rng:NextNumber(0, 1) < (y == 1 and 0.6 or 0.3) then
					id = "bedrock"
				elseif y > h - 4 then
					if biome == "desert" then
						id = y > h - 3 and "sand" or "sandstone"
					elseif h <= SEA + 1 then
						id = (h < SEA - 2 and y == h) and "gravel" or "sand"
					else
						id = y == h and (biome == "snowy" and "snow_block" or "grass_block") or "dirt"
					end
				end
				w.set(x, y, z, id)
			end
			for y = h + 1, SEA do
				w.set(x, y, z, (biome == "snowy" and y == SEA) and "ice" or "water")
			end
		end
	end
	-- пещеры-«черви»
	for _ = 1, 8 do
		local x, z = rng:NextNumber(4, SX - 4), rng:NextNumber(4, SZ - 4)
		local y = rng:NextNumber(6, 22)
		local yaw, pitch = rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.3, 0.3)
		for step = 1, 80 do
			local r = 1.4 + math.sin(step / 7) * 0.6
			local lavaHere = y < 10 and step % 23 == 0
			sphere(w, x, y, z, r, function(cx, cy, cz, dy)
				local b = w.get(cx, cy, cz)
				if b and b ~= "bedrock" and b ~= "water" and b ~= "ice" and cy > 0 then
					w.set(cx, cy, cz, (lavaHere and dy <= -1) and "lava" or nil)
				end
			end)
			if lavaHere then
				-- застывшая кромка лавового озера: обсидиан для портала
				for _ = 1, 3 do
					local ax, az = math.floor(x) + rng:NextInteger(-2, 2), math.floor(z) + rng:NextInteger(-2, 2)
					local ay = math.floor(y) - 2
					if w.get(ax, ay, az) == "stone" then
						w.set(ax, ay, az, "obsidian")
					end
				end
			end
			yaw += rng:NextNumber(-0.35, 0.35)
			pitch = math.clamp(pitch + rng:NextNumber(-0.2, 0.2), -0.5, 0.5)
			x = math.clamp(x + math.cos(yaw) * math.cos(pitch), 2, SX - 3)
			z = math.clamp(z + math.sin(yaw) * math.cos(pitch), 2, SZ - 3)
			y = math.clamp(y + math.sin(pitch), 4, 30)
		end
	end
	veins(w, rng, "stone", "coal_ore", 70, 4, 40, 8)
	veins(w, rng, "stone", "iron_ore", 45, 2, 32, 6)
	veins(w, rng, "stone", "gold_ore", 10, 2, 16, 5)
	veins(w, rng, "stone", "redstone_ore", 10, 2, 12, 6)
	veins(w, rng, "stone", "lapis_ore", 6, 2, 16, 5)
	veins(w, rng, "stone", "diamond_ore", 7, 2, 11, 4)
	veins(w, rng, "stone", "gravel", 12, 4, 36, 10)
	-- деревья и кактусы
	for x = 2, SX - 3 do
		for z = 2, SZ - 3 do
			local h, biome = tops[x + z * SX], biomes[x + z * SX]
			local top = w.get(x, h, z)
			local roll = rng:NextNumber(0, 1)
			if top == "grass_block" or (top == "snow_block" and biome == "snowy") then
				local chance = biome == "forest" and 0.05 or biome == "snowy" and 0.012 or 0.008
				if roll < chance then
					local birch = biome == "forest" and rng:NextNumber(0, 1) < 0.35
					oakTree(w, rng, x, h, z, birch and "birch_log" or "oak_log", birch and "birch_leaves" or "oak_leaves")
				end
			elseif top == "sand" and biome == "desert" and roll < 0.008 then
				for dy = 1, rng:NextInteger(1, 3) do
					w.set(x, h + dy, z, "cactus")
				end
			end
		end
	end
	-- разрушенный портал (1.16): неполная рамка из обсидиана, вокруг незерак, рядом блок золота
	do
		local px, pz = rng:NextInteger(10, SX - 14), rng:NextInteger(10, SZ - 14)
		local h = tops[px + pz * SX]
		if h > SEA then
			for dx = -2, 5 do
				for dz = -2, 2 do
					if rng:NextNumber(0, 1) < 0.55 then
						w.set(px + dx, h, pz + dz, rng:NextNumber(0, 1) < 0.2 and "magma_block" or "netherrack")
					end
				end
			end
			local missing = { [rng:NextInteger(1, 14)] = true, [rng:NextInteger(1, 14)] = true }
			local n = 0
			for dx = 0, 3 do
				for dy = 1, 5 do
					if dx == 0 or dx == 3 or dy == 1 or dy == 5 then
						n += 1
						w.set(px + dx, h + dy, pz, not missing[n] and "obsidian" or nil)
					else
						w.set(px + dx, h + dy, pz, nil)
					end
				end
			end
			w.set(px - 1, h + 1, pz + 2, "obsidian")
			w.set(px + 4, h + 1, pz - 2, "obsidian")
			w.set(px + 5, h + 1, pz + 1, "gold_block")
			w.ruinedPortal = Vector3.new(px, h + 1, pz)
		end
	end
	-- точка появления: суша ближе к центру
	local best, bestD = Vector3.new(SX / 2, H - 2, SZ / 2), math.huge
	for x = 8, SX - 9 do
		for z = 8, SZ - 9 do
			local h = tops[x + z * SX]
			local d = (x - SX / 2) ^ 2 + (z - SZ / 2) ^ 2
			if h > SEA and d < bestD and w.get(x, h + 1, z) == nil and w.get(x, h + 2, z) == nil then
				best, bestD = Vector3.new(x + 0.5, h + 1.01, z + 0.5), d
			end
		end
	end
	w.spawn = best
	w.tops = tops
	return w
end

function Terrain.Nether(seed)
	local H, LAVA = 48, 9
	local w = newWorld(H)
	w.lava = LAVA
	w.sky = false
	local rng = Random.new(seed + 666)
	local ox, oz = rng:NextNumber(-5000, 5000), rng:NextNumber(-5000, 5000)
	local floors, biomes = {}, {}
	for x = 0, SX - 1 do
		for z = 0, SZ - 1 do
			local nx, nz = x + ox, z + oz
			local f = math.floor(13 + math.noise(nx / 22, nz / 22, 0.5) * 16)
			local c = math.floor(36 + math.noise(nx / 18, nz / 18, 3.3) * 10)
			local b = math.noise(nx / 40, nz / 40, 7.7)
			local biome = b > 0.14 and "crimson" or b < -0.14 and "warped" or (math.noise(nx / 30, nz / 30, 9.1) > 0.12 and "soul" or "wastes")
			floors[x + z * SX], biomes[x + z * SX] = f, biome
			for y = 0, H - 1 do
				local id
				if y == 0 or y == H - 1 then
					id = "bedrock"
				elseif y <= f or y >= c or math.noise(nx / 12, y / 9, nz / 12) > 0.36 then
					id = "netherrack"
					if y == f then
						if biome == "crimson" then
							id = "crimson_nylium"
						elseif biome == "warped" then
							id = "warped_nylium"
						elseif biome == "soul" then
							id = rng:NextNumber(0, 1) < 0.6 and "soul_sand" or "soul_soil"
						elseif y <= LAVA + 1 and rng:NextNumber(0, 1) < 0.3 then
							id = "magma_block"
						end
					elseif biome == "soul" and y < f and y > f - 3 then
						id = "soul_soil"
					end
				elseif y <= LAVA then
					id = "lava"
				end
				w.blocks[key(x, y, z)] = id
			end
		end
	end
	-- огромные грибы в лесах, базальтовые столбы в долине душ
	for x = 3, SX - 4 do
		for z = 3, SZ - 4 do
			local f, biome = floors[x + z * SX], biomes[x + z * SX]
			local top = w.get(x, f, z)
			local roll = rng:NextNumber(0, 1)
			if (biome == "crimson" or biome == "warped") and roll < 0.03 and top ~= "lava" and f > LAVA then
				local h = rng:NextInteger(4, 8)
				local stem = biome == "crimson" and "crimson_stem" or "warped_stem"
				local wart = biome == "crimson" and "nether_wart_block" or "warped_wart_block"
				if not w.get(x, f + h + 2, z) then
					for dy = 1, h do
						w.set(x, f + dy, z, stem)
					end
					for dx = -2, 2 do
						for dz = -2, 2 do
							for dy = h - 1, h + 1 do
								if math.abs(dx) + math.abs(dz) <= (dy == h + 1 and 2 or 3) and not w.get(x + dx, f + dy, z + dz) then
									w.set(x + dx, f + dy, z + dz, rng:NextNumber(0, 1) < 0.1 and "shroomlight" or wart)
								end
							end
						end
					end
				end
			elseif biome == "soul" and roll < 0.012 and f > LAVA then
				for dy = 1, rng:NextInteger(3, 9) do
					if w.get(x, f + dy, z) then
						break
					end
					w.set(x, f + dy, z, "basalt")
				end
			end
		end
	end
	-- светокамень под потолком
	for _ = 1, 30 do
		local x, z = rng:NextInteger(2, SX - 3), rng:NextInteger(2, SZ - 3)
		for y = H - 2, 20, -1 do
			if w.get(x, y, z) == nil and w.get(x, y + 1, z) == "netherrack" then
				for _ = 1, rng:NextInteger(4, 10) do
					if w.get(x, y, z) == nil then
						w.set(x, y, z, "glowstone")
					end
					x += rng:NextInteger(-1, 1)
					y -= rng:NextInteger(0, 1)
					z += rng:NextInteger(-1, 1)
				end
				break
			end
		end
	end
	veins(w, rng, "netherrack", "nether_gold_ore", 45, 4, 44, 5)
	veins(w, rng, "netherrack", "nether_quartz_ore", 60, 4, 44, 5)
	veins(w, rng, "netherrack", "blackstone", 15, 4, 30, 14)
	-- древние обломки: глубоко, по одному-два, обычно спрятаны в незераке
	for _ = 1, 12 do
		local x, y, z = rng:NextInteger(1, SX - 2), rng:NextInteger(8, 22), rng:NextInteger(1, SZ - 2)
		if w.get(x, y, z) == "netherrack" then
			w.set(x, y, z, "ancient_debris")
		end
	end
	w.spawn = Terrain.FindStand(w, SX // 2, SZ // 2, LAVA + 2) or Vector3.new(SX / 2, 30, SZ / 2)
	return w
end

-- ближайшее к (x, z) место, где можно стоять: твёрдый пол и две клетки воздуха над ним
function Terrain.FindStand(w, cx, cz, minY, solid)
	solid = solid or function(id)
		return id ~= nil and id ~= "lava" and id ~= "water"
	end
	for r = 0, 20 do
		for dx = -r, r do
			for dz = -r, r do
				if math.max(math.abs(dx), math.abs(dz)) == r then
					local x, z = cx + dx, cz + dz
					if x >= 1 and z >= 1 and x < SX - 1 and z < SZ - 1 then
						for y = minY or 1, w.H - 3 do
							if solid(w.get(x, y - 1, z)) and w.get(x, y, z) == nil and w.get(x, y + 1, z) == nil then
								return Vector3.new(x + 0.5, y + 0.01, z + 0.5)
							end
						end
					end
				end
			end
		end
	end
	return nil
end

return Terrain
