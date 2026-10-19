-- Пиксельные текстуры 16×16 в духе Minecraft, нарисованные кодом (свои, не файлы Mojang).
-- Для граней блоков картинка увеличивается до 64×64 «по пикселям», чтобы Decal не размывал её;
-- значки в интерфейсе — исходные 16×16 с ResampleMode = Pixelated.
local AssetService = game:GetService("AssetService")

local Textures = {}

local N = 16
local UP = 4 -- увеличение для граней мира

local function hash(s)
	local h = 7
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 2147483647
	end
	return h
end

-- холст: px[y*N+x+1] = { r, g, b, a } (0..255)
local function canvas()
	local px = table.create(N * N)
	for i = 1, N * N do
		px[i] = { 0, 0, 0, 0 }
	end
	return px
end
local function put(px, x, y, c, a)
	if x >= 0 and y >= 0 and x < N and y < N then
		px[y * N + x + 1] = { c[1], c[2], c[3], a or 255 }
	end
end
local function get(px, x, y)
	return px[y * N + x + 1]
end
local function shade(c, k)
	return { math.clamp(c[1] * k, 0, 255), math.clamp(c[2] * k, 0, 255), math.clamp(c[3] * k, 0, 255) }
end
local function mix(a, b, t)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

-- ---------------------------------------------------------------- узоры
local function noise(rng, c, v, steps)
	local px = canvas()
	steps = steps or 4
	for y = 0, N - 1 do
		for x = 0, N - 1 do
			local k = 1 + (math.floor(rng:NextNumber(0, 1) * steps) / (steps - 1) - 0.5) * v
			put(px, x, y, shade(c, k))
		end
	end
	return px
end

local function speckle(px, rng, c, count, size)
	for _ = 1, count do
		local x, y = rng:NextInteger(0, N - 1), rng:NextInteger(0, N - 1)
		put(px, x, y, c)
		if size and size > 1 then
			put(px, x + 1, y, shade(c, 0.85))
		end
	end
	return px
end

-- руда: каменный фон и 4–5 комков цвета руды с бликом
local function ore(rng, base, oreColor)
	local px = noise(rng, base, 0.22)
	for _ = 1, rng:NextInteger(4, 5) do
		local cx, cy = rng:NextInteger(1, 13), rng:NextInteger(1, 13)
		for _ = 1, rng:NextInteger(3, 5) do
			local x, y = cx + rng:NextInteger(0, 2), cy + rng:NextInteger(0, 2)
			put(px, x, y, shade(oreColor, rng:NextNumber(0.75, 1.1)))
		end
		put(px, cx, cy, shade(oreColor, 1.3))
	end
	return px
end

-- ячейки Вороного: булыжник, светокамень
local function cells(rng, c, count, edge, spread)
	local seeds = {}
	for i = 1, count do
		seeds[i] = { rng:NextNumber(0, N), rng:NextNumber(0, N), rng:NextNumber(1 - spread, 1 + spread) }
	end
	local px = canvas()
	for y = 0, N - 1 do
		for x = 0, N - 1 do
			local d1, d2, best = math.huge, math.huge, nil
			for _, s in seeds do
				-- плитка повторяется без шва
				local dx = math.min(math.abs(x + 0.5 - s[1]), N - math.abs(x + 0.5 - s[1]))
				local dy = math.min(math.abs(y + 0.5 - s[2]), N - math.abs(y + 0.5 - s[2]))
				local d = dx * dx + dy * dy
				if d < d1 then
					d2, d1, best = d1, d, s
				elseif d < d2 then
					d2 = d
				end
			end
			if math.sqrt(d2) - math.sqrt(d1) < 0.9 then
				put(px, x, y, shade(c, edge))
			else
				put(px, x, y, shade(c, best[3] * rng:NextNumber(0.94, 1.06)))
			end
		end
	end
	return px
end

local function bricks(rng, brick, mortar, h, w)
	local px = canvas()
	for y = 0, N - 1 do
		local row = y // h
		local off = (row % 2) * (w // 2)
		for x = 0, N - 1 do
			if y % h == h - 1 or (x + off) % w == 0 then
				put(px, x, y, shade(mortar, rng:NextNumber(0.9, 1.05)))
			else
				local k = 1 + ((row * 7 + (x + off) // w * 3) % 5 - 2) * 0.04
				put(px, x, y, shade(brick, k * rng:NextNumber(0.92, 1.06)))
			end
		end
	end
	return px
end

local function planks(rng, c)
	local px = canvas()
	for y = 0, N - 1 do
		local row = y // 4
		local seam = (row % 2 == 0) and 3 or 11
		for x = 0, N - 1 do
			if y % 4 == 3 then
				put(px, x, y, shade(c, 0.62))
			elseif x == seam then
				put(px, x, y, shade(c, 0.7))
			else
				local grain = ((x * 3 + row * 5) % 7 == 0) and 0.86 or 1
				put(px, x, y, shade(c, grain * rng:NextNumber(0.93, 1.05)))
			end
		end
	end
	return px
end

local function logSide(rng, c)
	local px = canvas()
	local cols = {}
	for x = 0, N - 1 do
		cols[x] = rng:NextNumber(0.78, 1.08)
	end
	for y = 0, N - 1 do
		for x = 0, N - 1 do
			local k = cols[x] * rng:NextNumber(0.93, 1.05)
			if rng:NextNumber(0, 1) < 0.06 then
				k *= 0.7
			end
			put(px, x, y, shade(c, k))
		end
	end
	return px
end

local function birchSide(rng)
	local px = noise(rng, { 224, 222, 210 }, 0.12)
	for _ = 1, 9 do
		local x, y = rng:NextInteger(0, 13), rng:NextInteger(0, 15)
		local len = rng:NextInteger(2, 4)
		for i = 0, len - 1 do
			put(px, x + i, y, { 40, 40, 36 })
		end
	end
	return px
end

local function logTop(rng, bark, inner)
	local px = canvas()
	for y = 0, N - 1 do
		for x = 0, N - 1 do
			local d = math.max(math.abs(x - 7.5), math.abs(y - 7.5))
			if d > 6.5 then
				put(px, x, y, shade(bark, rng:NextNumber(0.85, 1.05)))
			else
				local ring = (math.floor(d) % 2 == 0) and 0.86 or 1
				put(px, x, y, shade(inner, ring * rng:NextNumber(0.95, 1.04)))
			end
		end
	end
	return px
end

-- трава/нилий сбоку: верхние ряды цветные с неровным краем
local function topSide(rng, under, top)
	local px = under
	for x = 0, N - 1 do
		local depth = 3 + (rng:NextNumber(0, 1) < 0.45 and rng:NextInteger(1, 2) or 0)
		for y = 0, depth - 1 do
			put(px, x, y, shade(top, rng:NextNumber(0.85, 1.08)))
		end
	end
	return px
end

-- металлические блоки: рамка, скос и блик
local function plate(rng, c)
	local px = canvas()
	for y = 0, N - 1 do
		for x = 0, N - 1 do
			local k = 1
			if x == 0 or y == 0 then
				k = 1.25
			elseif x == N - 1 or y == N - 1 then
				k = 0.6
			elseif x == 1 or y == 1 then
				k = 1.12
			elseif x == N - 2 or y == N - 2 then
				k = 0.78
			elseif (x + y) % 9 == 0 then
				k = 1.15
			end
			put(px, x, y, shade(c, k * rng:NextNumber(0.97, 1.03)))
		end
	end
	return px
end

local function frame(px, c)
	for i = 0, N - 1 do
		put(px, i, 0, c)
		put(px, i, N - 1, c)
		put(px, 0, i, c)
		put(px, N - 1, i, c)
	end
	return px
end

local function rect(px, x0, y0, x1, y1, c)
	for y = y0, y1 do
		for x = x0, x1 do
			put(px, x, y, c)
		end
	end
	return px
end

-- ---------------------------------------------------------------- набор граней
local C = {
	grass = { 98, 158, 62 }, dirt = { 134, 96, 67 }, stone = { 126, 126, 126 }, oak = { 106, 82, 50 }, oakIn = { 176, 140, 86 },
	planks = { 170, 132, 82 }, netherrack = { 112, 42, 42 }, cobble = { 116, 116, 116 },
}

local GEN = {
	grass_top = function(r) return speckle(noise(r, C.grass, 0.28), r, { 78, 134, 48 }, 18) end,
	grass_side = function(r) return topSide(r, noise(r, C.dirt, 0.3), C.grass) end,
	dirt = function(r) return speckle(noise(r, C.dirt, 0.3), r, { 96, 66, 44 }, 14) end,
	stone = function(r) return speckle(noise(r, C.stone, 0.2), r, { 104, 104, 104 }, 16, 2) end,
	cobblestone = function(r) return cells(r, C.cobble, 9, 0.55, 0.15) end,
	bedrock = function(r) return speckle(noise(r, { 70, 70, 72 }, 0.9, 5), r, { 20, 20, 20 }, 30, 2) end,
	sand = function(r) return speckle(noise(r, { 220, 206, 152 }, 0.12), r, { 196, 180, 128 }, 16) end,
	gravel = function(r) return cells(r, { 132, 124, 120 }, 14, 0.7, 0.3) end,
	sandstone_side = function(r)
		local px = noise(r, { 214, 198, 140 }, 0.1)
		rect(px, 0, 0, 15, 2, { 226, 212, 158 })
		rect(px, 0, 12, 15, 12, { 186, 170, 116 })
		return px
	end,
	sandstone_top = function(r) return noise(r, { 220, 206, 150 }, 0.1) end,
	snow = function(r) return noise(r, { 240, 248, 255 }, 0.06) end,
	ice = function(r) return speckle(noise(r, { 150, 190, 250 }, 0.12), r, { 210, 230, 255 }, 10, 2) end,
	cactus_side = function(r)
		local px = noise(r, { 70, 132, 52 }, 0.15)
		for y = 0, N - 1 do
			for _, x in { 1, 5, 10, 14 } do
				put(px, x, y, { 50, 104, 36 })
			end
			if y % 4 == 1 then
				put(px, 3, y, { 230, 230, 200 })
				put(px, 12, y + 2, { 230, 230, 200 })
			end
		end
		return px
	end,
	cactus_top = function(r) return frame(noise(r, { 90, 150, 64 }, 0.15), { 50, 104, 36 }) end,
	oak_log = function(r) return logSide(r, C.oak) end,
	oak_log_top = function(r) return logTop(r, C.oak, C.oakIn) end,
	birch_log = function(r) return birchSide(r) end,
	birch_log_top = function(r) return logTop(r, { 220, 216, 200 }, { 200, 176, 120 }) end,
	oak_leaves = function(r) return speckle(noise(r, { 62, 120, 34 }, 0.38, 5), r, { 36, 80, 20 }, 22) end,
	birch_leaves = function(r) return speckle(noise(r, { 104, 150, 70 }, 0.45, 5), r, { 66, 104, 44 }, 24) end,
	oak_planks = function(r) return planks(r, C.planks) end,
	crimson_planks = function(r) return planks(r, { 112, 52, 80 }) end,
	warped_planks = function(r) return planks(r, { 46, 114, 108 }) end,
	table_top = function(r)
		local px = planks(r, C.planks)
		frame(px, { 100, 70, 40 })
		rect(px, 7, 1, 8, 14, { 110, 78, 44 })
		rect(px, 1, 7, 14, 8, { 110, 78, 44 })
		return px
	end,
	table_side = function(r)
		local px = planks(r, C.planks)
		rect(px, 0, 0, 15, 2, { 120, 84, 48 })
		-- пила и молоток на стене
		rect(px, 3, 5, 3, 12, { 90, 60, 34 })
		rect(px, 2, 5, 6, 6, { 170, 170, 176 })
		rect(px, 11, 6, 11, 12, { 90, 60, 34 })
		rect(px, 9, 5, 13, 7, { 120, 120, 126 })
		return px
	end,
	furnace_side = function(r) return frame(noise(r, { 110, 110, 112 }, 0.14), { 84, 84, 86 }) end,
	furnace_front = function(r)
		local px = frame(noise(r, { 110, 110, 112 }, 0.14), { 84, 84, 86 })
		rect(px, 3, 3, 12, 5, { 70, 70, 72 })
		rect(px, 4, 9, 11, 13, { 24, 22, 22 })
		rect(px, 4, 12, 11, 13, { 60, 40, 30 })
		return px
	end,
	furnace_top = function(r) return noise(r, { 118, 118, 120 }, 0.14) end,
	coal_ore = function(r) return ore(r, C.stone, { 40, 40, 42 }) end,
	iron_ore = function(r) return ore(r, C.stone, { 214, 170, 136 }) end,
	gold_ore = function(r) return ore(r, C.stone, { 250, 214, 70 }) end,
	redstone_ore = function(r) return ore(r, C.stone, { 210, 20, 20 }) end,
	lapis_ore = function(r) return ore(r, C.stone, { 30, 66, 190 }) end,
	diamond_ore = function(r) return ore(r, C.stone, { 96, 230, 226 }) end,
	nether_gold_ore = function(r) return ore(r, C.netherrack, { 250, 210, 70 }) end,
	nether_quartz_ore = function(r) return ore(r, C.netherrack, { 236, 228, 220 }) end,
	obsidian = function(r) return speckle(noise(r, { 24, 16, 38 }, 0.5, 5), r, { 70, 40, 110 }, 18, 2) end,
	glass = function(r)
		local px = canvas()
		frame(px, { 220, 240, 255 })
		for i = 3, 6 do
			put(px, i, 9 - i, { 240, 250, 255 }, 200)
			put(px, i + 6, 13 - i, { 240, 250, 255 }, 200)
		end
		return px
	end,
	stone_bricks = function(r) return bricks(r, { 124, 124, 124 }, { 88, 88, 88 }, 8, 16) end,
	bricks = function(r) return bricks(r, { 150, 74, 60 }, { 170, 160, 150 }, 4, 8) end,
	nether_bricks = function(r) return bricks(r, { 56, 26, 32 }, { 30, 14, 18 }, 4, 8) end,
	netherrack = function(r) return speckle(noise(r, C.netherrack, 0.4, 5), r, { 150, 70, 64 }, 20) end,
	ancient_debris = function(r) return logSide(r, { 100, 74, 64 }) end,
	ancient_debris_top = function(r) return logTop(r, { 90, 66, 58 }, { 120, 92, 80 }) end,
	soul_sand = function(r)
		local px = noise(r, { 88, 68, 54 }, 0.25)
		for _ = 1, 3 do
			local x, y = r:NextInteger(1, 11), r:NextInteger(1, 11)
			put(px, x, y, { 50, 36, 28 })
			put(px, x + 3, y, { 50, 36, 28 })
			rect(px, x + 1, y + 2, x + 2, y + 3, { 50, 36, 28 })
		end
		return px
	end,
	soul_soil = function(r) return speckle(noise(r, { 76, 58, 46 }, 0.25), r, { 56, 42, 32 }, 20) end,
	basalt = function(r)
		local px = logSide(r, { 76, 76, 82 })
		return px
	end,
	basalt_top = function(r) return frame(noise(r, { 84, 84, 90 }, 0.15), { 60, 60, 66 }) end,
	blackstone = function(r) return speckle(noise(r, { 42, 38, 46 }, 0.3), r, { 70, 64, 74 }, 14, 2) end,
	glowstone = function(r) return cells(r, { 240, 196, 110 }, 10, 0.6, 0.25) end,
	shroomlight = function(r) return cells(r, { 250, 160, 70 }, 7, 0.75, 0.15) end,
	magma_block = function(r)
		local px = cells(r, { 110, 40, 18 }, 8, 2.2, 0.15)
		return px
	end,
	crimson_top = function(r) return speckle(noise(r, { 150, 28, 40 }, 0.3), r, { 200, 60, 60 }, 12) end,
	crimson_side = function(r) return topSide(r, speckle(noise(r, C.netherrack, 0.4, 5), r, { 150, 70, 64 }, 20), { 150, 28, 40 }) end,
	warped_top = function(r) return speckle(noise(r, { 36, 128, 116 }, 0.3), r, { 60, 170, 150 }, 12) end,
	warped_side = function(r) return topSide(r, speckle(noise(r, C.netherrack, 0.4, 5), r, { 150, 70, 64 }, 20), { 36, 128, 116 }) end,
	crimson_stem = function(r) return logSide(r, { 120, 40, 64 }) end,
	crimson_stem_top = function(r) return logTop(r, { 120, 40, 64 }, { 150, 70, 90 }) end,
	warped_stem = function(r) return logSide(r, { 54, 100, 110 }) end,
	warped_stem_top = function(r) return logTop(r, { 54, 100, 110 }, { 60, 150, 140 }) end,
	nether_wart_block = function(r) return speckle(noise(r, { 136, 18, 20 }, 0.4, 5), r, { 90, 6, 8 }, 20) end,
	warped_wart_block = function(r) return speckle(noise(r, { 22, 128, 130 }, 0.4, 5), r, { 10, 86, 90 }, 20) end,
	netherite_block = function(r) return plate(r, { 66, 60, 64 }) end,
	diamond_block = function(r) return plate(r, { 104, 224, 220 }) end,
	gold_block = function(r) return plate(r, { 246, 208, 64 }) end,
	iron_block = function(r) return plate(r, { 220, 220, 224 }) end,
}

-- какие картинки на каких гранях: all | top/side/bottom/front
local FACES = {
	grass_block = { top = "grass_top", side = "grass_side", bottom = "dirt" },
	sandstone = { top = "sandstone_top", side = "sandstone_side", bottom = "sandstone_top" },
	snow_block = { all = "snow" },
	cactus = { top = "cactus_top", side = "cactus_side", bottom = "cactus_top" },
	oak_log = { top = "oak_log_top", side = "oak_log", bottom = "oak_log_top" },
	birch_log = { top = "birch_log_top", side = "birch_log", bottom = "birch_log_top" },
	crafting_table = { top = "table_top", side = "table_side", bottom = "oak_planks" },
	furnace = { top = "furnace_top", side = "furnace_side", bottom = "furnace_top", front = "furnace_front" },
	lapis_ore = { all = "lapis_ore" },
	ancient_debris = { top = "ancient_debris_top", side = "ancient_debris", bottom = "ancient_debris_top" },
	basalt = { top = "basalt_top", side = "basalt", bottom = "basalt_top" },
	crimson_nylium = { top = "crimson_top", side = "crimson_side", bottom = "netherrack" },
	warped_nylium = { top = "warped_top", side = "warped_side", bottom = "netherrack" },
	crimson_stem = { top = "crimson_stem_top", side = "crimson_stem", bottom = "crimson_stem_top" },
	warped_stem = { top = "warped_stem_top", side = "warped_stem", bottom = "warped_stem_top" },
}

-- ---------------------------------------------------------------- картинки
local pixels = {} -- имя -> px
local contents = {} -- имя .. размер -> Content | false
local enabled = true

local function draw(name)
	if pixels[name] == nil then
		local gen = GEN[name]
		pixels[name] = gen and gen(Random.new(hash(name))) or false
	end
	return pixels[name] or nil
end

local function toContent(px, scale, key)
	if contents[key] ~= nil then
		return contents[key] or nil
	end
	local ok, result = pcall(function()
		local size = N * scale
		local buf = buffer.create(size * size * 4)
		for y = 0, size - 1 do
			for x = 0, size - 1 do
				local p = px[(y // scale) * N + (x // scale) + 1]
				local o = (y * size + x) * 4
				buffer.writeu8(buf, o, math.floor(p[1]))
				buffer.writeu8(buf, o + 1, math.floor(p[2]))
				buffer.writeu8(buf, o + 2, math.floor(p[3]))
				buffer.writeu8(buf, o + 3, p[4])
			end
		end
		local image = AssetService:CreateEditableImage({ Size = Vector2.new(size, size) })
		image:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), buf)
		return Content.fromObject(image)
	end)
	if not ok then
		-- EditableImage недоступен (например, выключен в настройках опыта) — блоки остаются цветными
		enabled = false
		warn("[BlockCraft] textures off: " .. tostring(result))
	end
	contents[key] = ok and result or false
	return ok and result or nil
end

-- имя картинки для грани блока: face = top | bottom | side | front
function Textures.Name(id, face)
	local f = FACES[id]
	if f then
		return f.all or f[face] or (face == "front" and f.side) or f.side
	end
	return GEN[id] and id or nil
end

-- Content для грани мира (64×64) или nil
function Textures.Face(id, face)
	if not enabled then
		return nil
	end
	local name = Textures.Name(id, face)
	local px = name and draw(name)
	return px and toContent(px, UP, name .. "@" .. UP) or nil
end

-- Content 16×16 для значков (ImageLabel с ResampleMode.Pixelated)
function Textures.Icon(name)
	if not enabled then
		return nil
	end
	local px = draw(name)
	return px and toContent(px, 1, name .. "@1") or nil
end

-- произвольный рисунок по строкам-маске: палитра { символ = {r,g,b} }
function Textures.Sprite(name, rows, palette)
	if not enabled then
		return nil
	end
	if not pixels[name] then
		local px = canvas()
		for y, line in rows do
			for x = 1, #line do
				local c = palette[string.sub(line, x, x)]
				if typeof(c) == "Color3" then
					c = { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
				end
				if c then
					put(px, x - 1, y - 1, c)
				end
			end
		end
		pixels[name] = px
	end
	return toContent(pixels[name], 1, name .. "@1")
end


-- ---------------------------------------------------------------- значки предметов (рисуются кодом, с тёмным контуром)
local function c3(color)
	return { math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255) }
end
local STICK = { 120, 86, 44 }

local function pts(px, list, c, k)
	for _, q in list do
		put(px, q[1], q[2], k and shade(c, k) or c)
	end
end
local function line(x0, y0, n, dx, dy)
	local out = {}
	for i = 0, n - 1 do
		table.insert(out, { x0 + i * dx, y0 + i * dy })
	end
	return out
end
local function blob(cx, cy, r)
	local out = {}
	for y = 0, N - 1 do
		for x = 0, N - 1 do
			if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r then
				table.insert(out, { x, y })
			end
		end
	end
	return out
end
local function outline(px, k)
	local add = {}
	for y = 0, N - 1 do
		for x = 0, N - 1 do
			if get(px, x, y)[4] == 0 then
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local nx, ny = x + d[1], y + d[2]
					if nx >= 0 and ny >= 0 and nx < N and ny < N and get(px, nx, ny)[4] > 0 then
						table.insert(add, { x, y, get(px, nx, ny) })
						break
					end
				end
			end
		end
	end
	for _, a in add do
		put(px, a[1], a[2], shade(a[3], k or 0.35))
	end
	return px
end

local TOOL_HEADS = {
	pickaxe = { { 5, 2 }, { 6, 1 }, { 7, 1 }, { 8, 1 }, { 9, 1 }, { 10, 2 }, { 11, 2 }, { 12, 3 }, { 13, 4 }, { 13, 5 }, { 14, 6 }, { 14, 7 }, { 14, 8 }, { 14, 9 },
		{ 4, 3 }, { 6, 2 }, { 7, 2 }, { 8, 2 }, { 9, 2 }, { 10, 3 }, { 11, 3 }, { 12, 4 }, { 13, 6 }, { 13, 7 }, { 13, 8 } },
	axe = { { 7, 1 }, { 8, 1 }, { 9, 1 }, { 10, 1 }, { 6, 2 }, { 7, 2 }, { 8, 2 }, { 9, 2 }, { 10, 2 }, { 11, 2 }, { 6, 3 }, { 7, 3 }, { 8, 3 }, { 9, 3 }, { 10, 3 },
		{ 6, 4 }, { 7, 4 }, { 8, 4 }, { 9, 4 }, { 7, 5 }, { 8, 5 }, { 12, 3 } },
	shovel = { { 11, 1 }, { 12, 1 }, { 10, 2 }, { 11, 2 }, { 12, 2 }, { 13, 2 }, { 10, 3 }, { 11, 3 }, { 12, 3 }, { 13, 3 }, { 14, 3 }, { 11, 4 }, { 12, 4 }, { 13, 4 }, { 14, 4 }, { 12, 5 }, { 13, 5 } },
}

local function tool(kind, head)
	local px = canvas()
	if kind == "sword" then
		pts(px, line(5, 10, 9, 1, -1), head)
		pts(px, line(6, 10, 8, 1, -1), head, 1.25)
		pts(px, { { 3, 8 }, { 4, 9 }, { 6, 11 }, { 7, 12 } }, { 70, 50, 30 })
		pts(px, line(2, 13, 3, 1, -1), STICK)
		put(px, 1, 14, shade(head, 0.8))
		return outline(px)
	end
	local n = kind == "shovel" and 8 or 10
	pts(px, line(2, 14, n, 1, -1), STICK)
	pts(px, TOOL_HEADS[kind], head)
	put(px, TOOL_HEADS[kind][1][1], TOOL_HEADS[kind][1][2], shade(head, 1.3))
	return outline(px)
end

local ITEM_DRAW = {
	stick = function(c)
		local px = canvas()
		pts(px, line(3, 13, 10, 1, -1), STICK)
		return outline(px)
	end,
	ingot = function(c)
		local px = canvas()
		for y = 6, 10 do
			for x = 12 - (y - 6) - 7, 12 - (y - 6) + 1 do
				put(px, x, y, shade(c, y == 6 and 1.25 or (y == 10 and 0.75 or 1)))
			end
		end
		return outline(px)
	end,
	gem = function(c)
		local px = canvas()
		for y = 2, 13 do
			for x = 2, 13 do
				if math.abs(x - 7.5) + math.abs(y - 7.5) <= 6 then
					put(px, x, y, shade(c, (x + y < 14) and 1.2 or 0.85))
				end
			end
		end
		pts(px, { { 6, 5 }, { 7, 4 }, { 5, 6 } }, { 255, 255, 255 })
		return outline(px)
	end,
	nugget = function(c)
		local px = canvas()
		pts(px, blob(7.5, 8.5, 3), c)
		pts(px, { { 6, 7 }, { 7, 7 } }, c, 1.3)
		return outline(px)
	end,
	lump = function(c)
		local px = canvas()
		pts(px, blob(7.5, 8, 5), c)
		pts(px, { { 5, 5 }, { 6, 5 }, { 5, 6 }, { 9, 9 } }, c, 1.6)
		return outline(px)
	end,
	dust = function(c)
		local px = canvas()
		local r = Random.new(5)
		for _ = 1, 26 do
			local a, d = r:NextNumber(0, math.pi * 2), r:NextNumber(0, 5)
			put(px, math.floor(7.5 + math.cos(a) * d), math.floor(8 + math.sin(a) * d), shade(c, r:NextNumber(0.7, 1.2)))
		end
		return px
	end,
	flint = function(c)
		local px = canvas()
		for y = 3, 13 do
			for x = 8 - (y - 3) // 2, 8 + (y - 3) // 2 do
				put(px, x, y, shade(c, x < 8 and 1.3 or 1))
			end
		end
		return outline(px)
	end,
	string = function(c)
		local px = canvas()
		for x = 1, 14 do
			put(px, x, math.floor(8 + math.sin(x * 0.9) * 3), c)
		end
		return px
	end,
	apple = function(c)
		local px = canvas()
		pts(px, blob(7.5, 9, 5), c)
		pts(px, { { 5, 6 }, { 5, 7 }, { 6, 6 } }, { 255, 255, 255 })
		pts(px, { { 8, 2 }, { 8, 3 } }, { 90, 60, 30 })
		pts(px, { { 9, 2 }, { 10, 2 }, { 10, 3 } }, { 60, 150, 40 })
		return outline(px)
	end,
	meat = function(c)
		local px = canvas()
		for y = 4, 12 do
			for x = 2, 13 do
				if ((x - 7.5) / 6) ^ 2 + ((y - 8) / 4) ^ 2 <= 1 then
					put(px, x, y, c)
				end
			end
		end
		pts(px, line(4, 7, 8, 1, 0), { 250, 240, 230 })
		return outline(px)
	end,
	flint_and_steel = function()
		local px = canvas()
		for a = 0, 15 do
			local t = a / 16 * math.pi * 2
			put(px, math.floor(5.5 + math.cos(t) * 3.5), math.floor(9.5 + math.sin(t) * 3.5), { 170, 170, 176 })
		end
		for y = 2, 8 do
			for x = 10 - (y - 2) // 2, 10 + (y - 2) // 2 do
				put(px, x, y, { 60, 60, 64 })
			end
		end
		return outline(px)
	end,
	scrap = function(c)
		local px = canvas()
		pts(px, blob(7.5, 8, 5), c)
		pts(px, line(4, 6, 7, 1, 0), c, 0.7)
		pts(px, line(4, 10, 7, 1, 0), c, 0.7)
		return outline(px)
	end,
}
local ITEM_STYLE = {
	stick = "stick", coal = "lump", iron_ingot = "ingot", gold_ingot = "ingot", netherite_ingot = "ingot", gold_nugget = "nugget",
	diamond = "gem", lapis_lazuli = "gem", quartz = "gem", redstone = "dust", gunpowder = "dust", flint = "flint", string = "string",
	apple = "apple", golden_apple = "apple", porkchop = "meat", cooked_porkchop = "meat", rotten_flesh = "meat",
	flint_and_steel = "flint_and_steel", netherite_scrap = "scrap",
}

-- значок предмета (не блока): инструменты по виду, остальное по стилю
function Textures.Item(name, info)
	if not enabled or not info then
		return nil
	end
	local key = "item_" .. name
	if not pixels[key] then
		local color = c3(info.color)
		if info.tool then
			pixels[key] = tool(info.tool.kind, color)
		else
			local draw = ITEM_DRAW[ITEM_STYLE[name] or "lump"]
			pixels[key] = draw(color)
		end
	end
	return toContent(pixels[key], 1, key .. "@1")
end

-- значки здоровья и голода как в HUD Minecraft (свои рисунки)
local HEART = { ".oo.oo.", "orrorro", "orhrrro", "orrrrro", ".orrro.", "..oro..", "...o..." }
local FOOD = { ".....oo", "....obbo", "...obbbo", "..obbbo.", ".owoo...", "owo.....", ".o......" }
function Textures.Hud(kind, state)
	if not enabled then
		return nil
	end
	local key = "hud_" .. kind .. "_" .. state
	if not pixels[key] then
		local px = canvas()
		local rows = kind == "heart" and HEART or FOOD
		local fill = kind == "heart" and { 220, 20, 30 } or { 190, 120, 60 }
		local empty = { 40, 24, 24 }
		for y, line in rows do
			for x = 1, #line do
				local ch = string.sub(line, x, x)
				local px0, py0 = x - 1 + 4, y - 1 + 4
				local right = x > #line / 2 + 0.5
				local filled = state == "full" or (state == "half" and not right)
				if ch == "o" then
					put(px, px0, py0, { 20, 10, 10 })
				elseif ch == "h" then
					put(px, px0, py0, filled and { 255, 200, 200 } or empty)
				elseif ch == "w" then
					put(px, px0, py0, { 240, 230, 220 })
				elseif ch ~= "." then
					put(px, px0, py0, filled and fill or empty)
				end
			end
		end
		pixels[key] = px
	end
	return toContent(pixels[key], 1, key .. "@1")
end

-- лица мобов: 8×8 строк, растягиваются до 16×16
local FACE_ROWS = {
	pig = { "pppppppp", "pppppppp", "pwkppkwp", "pppppppp", "ppnssnpp", "ppsssspp", "pppppppp", "pppppppp" },
	zombie = { "gggggggg", "gggggggg", "gggggggg", "gkkggkkg", "gggddggg", "ggdggdgg", "gggggggg", "gggggggg" },
	creeper = { "cccccccc", "cccccccc", "ckkcckkc", "ckkcckkc", "ccckkccc", "cckkkkcc", "cckkkkcc", "cckcckcc" },
	piglin = { "pppppppp", "pppppppp", "pwkppkwp", "pppppppp", "ppnnnnpp", "pnkppknp", "ptppppTp", "pppppppp" },
	zombified_piglin = { "pppggppp", "ppgggppp", "pwkppkwp", "pppppppp", "ppnnnnpp", "pnkppknp", "ptppppTp", "ppppgggp" },
	hoglin = { "pppppppp", "pkpppkpp", "pppppppp", "pppppppp", "ppnnnnpp", "pnkppknp", "tppppppT", "tppppppT" },
}
function Textures.MobFace(kind, skin)
	local rows = FACE_ROWS[kind]
	if not enabled or not rows then
		return nil
	end
	local key = "face_" .. kind
	if not pixels[key] then
		local s = c3(skin)
		local pal = {
			p = s, g = { 90, 140, 80 }, c = s, k = { 18, 18, 18 }, w = { 240, 240, 240 }, d = shade(s, 0.7),
			n = shade(s, 0.8), s = shade(s, 1.1), t = { 240, 236, 220 }, T = { 240, 236, 220 },
		}
		local px = canvas()
		for y, line in rows do
			for x = 1, 8 do
				local c = pal[string.sub(line, x, x)] or s
				local k = 1 + (((x * 7 + y * 13) % 5) - 2) * 0.03
				for dy = 0, 1 do
					for dx = 0, 1 do
						put(px, (x - 1) * 2 + dx, (y - 1) * 2 + dy, shade(c, k))
					end
				end
			end
		end
		pixels[key] = px
	end
	return toContent(pixels[key], UP, key .. "@" .. UP)
end

function Textures.Enabled()
	return enabled
end

Textures.shade, Textures.mix, Textures.get = shade, mix, get
return Textures
