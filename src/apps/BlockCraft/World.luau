-- Отрисовка мира кусками 8×8 вокруг игрока: строятся только блоки с открытой гранью, дальние куски убираются.
-- Здесь же столкновения AABB (игрок и мобы) и луч по сетке для прицела.
local Content = require(script.Parent.Content)
local Terrain = require(script.Parent.Terrain)
local Textures = require(script.Parent.Textures)

local BLOCKS = Content.BLOCKS
local SX, SZ = Terrain.SX, Terrain.SZ
local key = Terrain.key
local CHUNK = 8
local NEIGHBORS = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }
-- грани: сдвиг к соседу, сторона детали, какая картинка (вперёд = −Z = Front)
local FACES = {
	{ 1, 0, 0, Enum.NormalId.Right, "side" }, { -1, 0, 0, Enum.NormalId.Left, "side" },
	{ 0, 1, 0, Enum.NormalId.Top, "top" }, { 0, -1, 0, Enum.NormalId.Bottom, "bottom" },
	{ 0, 0, 1, Enum.NormalId.Back, "side" }, { 0, 0, -1, Enum.NormalId.Front, "front" },
}

local World = {}
World.__index = World
World.CHUNK = CHUNK

function World.new(gen, parent, origin, B)
	local self = setmetatable({}, World)
	self.gen = gen
	self.blocks = gen.blocks
	self.H = gen.H
	self.parent = parent
	self.origin = origin
	self.B = B
	self.chunks = {} -- индекс куска -> { [key] = Part }
	self.queue = {}
	self.sky = gen.sky ~= false -- в Незере неба нет
	-- карта высот для небесного света и источники света по кускам (как свет блоков в Minecraft)
	self.heights = table.create(SX * SZ, -1)
	self.lights = {} -- индекс куска -> { [key] = сила }
	for x = 0, SX - 1 do
		for z = 0, SZ - 1 do
			self:scanColumn(x, z)
		end
	end
	for k, id in self.blocks do
		local info = BLOCKS[id]
		if info.light then
			local x, z = k % SX, (k // SX) % SZ
			local ci = (x // CHUNK) + (z // CHUNK) * (SX // CHUNK)
			self.lights[ci] = self.lights[ci] or {}
			self.lights[ci][k] = info.light
		end
	end
	return self
end

-- самый верхний непрозрачный блок столбца
function World:scanColumn(x, z)
	local h = -1
	for y = self.H - 1, 0, -1 do
		local id = self.blocks[key(x, y, z)]
		if id and not BLOCKS[id].see then
			h = y
			break
		end
	end
	self.heights[x + z * SX + 1] = h
	return h
end

-- освещённость клетки 0..1: небо (затухает под навесом и в пещерах) или ближайший источник света
local SKY_FALLOFF = 0.16
local DARK = 0.2
function World:lightAt(x, y, z)
	local light = DARK
	if self.sky then
		local h = self.heights[math.clamp(x, 0, SX - 1) + math.clamp(z, 0, SZ - 1) * SX + 1]
		light = y > h and 1 or math.max(DARK, 1 - (h - y) * SKY_FALLOFF)
	else
		light = 0.55
	end
	if light >= 1 then
		return 1
	end
	local cx, cz = x // CHUNK, z // CHUNK
	local per = SX // CHUNK
	for dx = -1, 1 do
		for dz = -1, 1 do
			local bx, bz = cx + dx, cz + dz
			local bucket = bx >= 0 and bz >= 0 and bx < per and bz < per and self.lights[bx + bz * per]
			if bucket then
				for k, strength in bucket do
					local lx, lz, ly = k % SX, (k // SX) % SZ, k // (SX * SZ)
					local d = math.abs(lx - x) + math.abs(ly - y) + math.abs(lz - z)
					local v = strength * (1 - d / 13)
					if v > light then
						light = v
					end
				end
			end
		end
	end
	return math.min(light, 1)
end

function World:get(x, y, z)
	if x < 0 or z < 0 or y < 0 or x >= SX or z >= SZ or y >= self.H then
		return nil
	end
	return self.blocks[key(x, y, z)]
end

function World:inside(x, y, z)
	return x >= 0 and z >= 0 and y >= 0 and x < SX and z < SZ and y < self.H
end

-- твёрдая клетка: за краем мира и под дном — невидимая стена
function World:solid(x, y, z)
	if x < 0 or z < 0 or y < 0 or x >= SX or z >= SZ then
		return true
	end
	if y >= self.H then
		return false
	end
	local id = self.blocks[key(x, y, z)]
	return id ~= nil and BLOCKS[id].solid ~= false
end

function World:toWorld(v)
	return self.origin + v * self.B
end

local function chunkIndex(x, z)
	return (x // CHUNK) + (z // CHUNK) * (SX // CHUNK)
end

function World:exposed(x, y, z, id)
	for _, d in NEIGHBORS do
		local nx, ny, nz = x + d[1], y + d[2], z + d[3]
		if ny >= self.H then
			return true
		end
		if ny >= 0 and nx >= 0 and nz >= 0 and nx < SX and nz < SZ then
			local n = self.blocks[key(nx, ny, nz)]
			if n == nil or (BLOCKS[n].see and n ~= id) or BLOCKS[n].shape then
				return true
			end
		end
	end
	return false
end

-- видна ли грань: сосед пустой, прозрачный или фигурный (за краем мира грань не рисуется)
function World:faceOpen(x, y, z, id, f)
	local nx, ny, nz = x + f[1], y + f[2], z + f[3]
	if ny >= self.H then
		return true
	end
	if ny < 0 or nx < 0 or nz < 0 or nx >= SX or nz >= SZ then
		return false
	end
	local n = self.blocks[key(nx, ny, nz)]
	return n == nil or (BLOCKS[n].see and n ~= id) or BLOCKS[n].shape ~= nil
end

-- затенение граней как в Minecraft: верх ярче всех, бока по осям темнее, низ темнее всего
local FACE_SHADE = { top = 1, bottom = 0.5, side = 0.8, front = 0.8 }
local function faceShade(f)
	return f[1] ~= 0 and 0.6 or FACE_SHADE[f[5]]
end

-- пиксельные текстуры только на открытых гранях; при изменении соседей грани добавляются и убираются
function World:decorate(p, id, x, y, z)
	local info = BLOCKS[id]
	if info.shape or info.portal or info.liquid or not Textures.Enabled() then
		return
	end
	for _, f in FACES do
		local name = f[4].Name
		local decal = p:FindFirstChild(name)
		local open = self:faceOpen(x, y, z, id, f)
		if open and not decal then
			local tex = Textures.Face(id, f[5])
			if tex then
				decal = Instance.new("Decal")
				decal.Name = name
				decal.Face = f[4]
				decal.TextureContent = tex
				decal.Parent = p
				p.Material = Enum.Material.SmoothPlastic
				if id == "glass" then
					p.Transparency = 0.9
				end
			end
		elseif decal and not open then
			decal:Destroy()
			decal = nil
		end
		if decal then
			local k = faceShade(f) * (BLOCKS[id].light and 1 or self:lightAt(x + f[1], y + f[2], z + f[3]))
			decal.Color3 = Color3.new(k, k, k)
		end
	end
end

-- пересчитать свет граней в коробке клеток (после факела, копания шахты и т.п.)
function World:relight(x0, x1, y0, y1, z0, z1)
	for x = math.max(0, x0), math.min(SX - 1, x1) do
		for z = math.max(0, z0), math.min(SZ - 1, z1) do
			local chunk = self.chunks[chunkIndex(x, z)]
			if chunk then
				for y = math.max(0, y0), math.min(self.H - 1, y1) do
					local k = key(x, y, z)
					local part = chunk[k]
					if part then
						self:decorate(part, self.blocks[k], x, y, z)
					end
				end
			end
		end
	end
end

function World:makePart(id, x, y, z)
	local info = BLOCKS[id]
	local B = self.B
	local p = Instance.new("Part")
	p.Name = id
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Color = info.color
	p.Material = info.material
	p.Transparency = info.transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = info.solid ~= false and not info.see
	local center = self.origin + Vector3.new(x + 0.5, y + 0.5, z + 0.5) * B
	if info.shape == "torch" then
		p.Size = Vector3.new(0.15, 0.6, 0.15) * B
		center -= Vector3.new(0, 0.2 * B, 0)
	elseif info.portal == "x" then
		p.Size = Vector3.new(B, B, 0.25 * B)
	elseif info.portal == "z" then
		p.Size = Vector3.new(0.25 * B, B, B)
	elseif info.liquid and self:get(x, y + 1, z) ~= id then
		p.Size = Vector3.new(B, 0.875 * B, B)
		center -= Vector3.new(0, 0.0625 * B, 0)
	elseif info.inset then
		p.Size = Vector3.new(B * (1 - 2 * info.inset), B, B * (1 - 2 * info.inset))
	else
		p.Size = Vector3.one * B
	end
	p.Position = center
	self:decorate(p, id, x, y, z)
	p.Parent = self.parent
	return p
end

function World:refresh(x, y, z)
	if not self:inside(x, y, z) then
		return
	end
	local chunk = self.chunks[chunkIndex(x, z)]
	if not chunk then
		return
	end
	local k = key(x, y, z)
	local id = self.blocks[k]
	local p = chunk[k]
	local show = id ~= nil and self:exposed(x, y, z, id)
	if p and (not show or p.Name ~= id) then
		p:Destroy()
		chunk[k] = nil
		p = nil
	end
	if show and not p then
		chunk[k] = self:makePart(id, x, y, z)
	elseif p then
		self:decorate(p, id, x, y, z)
	end
end

function World:set(x, y, z, id)
	if not self:inside(x, y, z) then
		return
	end
	local k = key(x, y, z)
	local old = self.blocks[k]
	self.blocks[k] = id
	self:refresh(x, y, z)
	for _, d in NEIGHBORS do
		self:refresh(x + d[1], y + d[2], z + d[3])
	end
	-- жидкость под изменённой клеткой меняет высоту поверхности
	self:refresh(x, y - 1, z)
	-- свет: новая высота столбца или источник света
	local before = self.heights[x + z * SX + 1]
	local after = self:scanColumn(x, z)
	local oldLight, newLight = old and BLOCKS[old].light, id and BLOCKS[id].light
	if oldLight or newLight then
		local ci = chunkIndex(x, z)
		self.lights[ci] = self.lights[ci] or {}
		self.lights[ci][k] = newLight or nil
		self:relight(x - 12, x + 12, y - 12, y + 12, z - 12, z + 12)
	elseif before ~= after then
		self:relight(x - 1, x + 1, math.min(before, after) - 8, math.max(before, after) + 1, z - 1, z + 1)
	end
end

function World:buildChunk(ci)
	if self.chunks[ci] then
		return
	end
	local chunk = {}
	self.chunks[ci] = chunk
	local cx, cz = (ci % (SX // CHUNK)) * CHUNK, (ci // (SX // CHUNK)) * CHUNK
	for x = cx, cx + CHUNK - 1 do
		for z = cz, cz + CHUNK - 1 do
			for y = 0, self.H - 1 do
				local k = key(x, y, z)
				local id = self.blocks[k]
				if id and self:exposed(x, y, z, id) then
					chunk[k] = self:makePart(id, x, y, z)
				end
			end
		end
	end
end

function World:unloadChunk(ci)
	local chunk = self.chunks[ci]
	if chunk then
		for _, p in chunk do
			p:Destroy()
		end
		self.chunks[ci] = nil
	end
end

-- какие куски нужны вокруг точки (в блоках); ближние строятся первыми
function World:focus(pos, radius)
	local pcx, pcz = math.floor(pos.X / CHUNK), math.floor(pos.Z / CHUNK)
	local wanted = {}
	table.clear(self.queue)
	for dx = -radius, radius do
		for dz = -radius, radius do
			local cx, cz = pcx + dx, pcz + dz
			if cx >= 0 and cz >= 0 and cx < SX // CHUNK and cz < SZ // CHUNK then
				local ci = cx + cz * (SX // CHUNK)
				wanted[ci] = true
				if not self.chunks[ci] then
					table.insert(self.queue, { ci = ci, d = dx * dx + dz * dz })
				end
			end
		end
	end
	table.sort(self.queue, function(a, b)
		return a.d < b.d
	end)
	for ci in self.chunks do
		if not wanted[ci] then
			self:unloadChunk(ci)
		end
	end
end

function World:step(count)
	for _ = 1, count do
		local item = table.remove(self.queue, 1)
		if not item then
			return false
		end
		self:buildChunk(item.ci)
	end
	return #self.queue > 0
end

function World:destroy()
	for ci in self.chunks do
		self:unloadChunk(ci)
	end
end

-- ---------------------------------------------------------------- физика коробки (координаты в блоках)
function World:collides(pos, half, tall)
	for x = math.floor(pos.X - half), math.floor(pos.X + half - 1e-4) do
		for y = math.floor(pos.Y), math.floor(pos.Y + tall - 1e-4) do
			for z = math.floor(pos.Z - half), math.floor(pos.Z + half - 1e-4) do
				if self:solid(x, y, z) then
					return true
				end
			end
		end
	end
	return false
end

-- двигает коробку по осям с мелкими шагами. Возвращает новую позицию, стоит ли на земле, упёрлась ли вбок и в потолок.
function World:moveBox(pos, delta, half, tall)
	local steps = math.max(1, math.ceil(delta.Magnitude / 0.3))
	local d = delta / steps
	local onGround, blocked, ceiling = false, false, false
	for _ = 1, steps do
		local nx = pos + Vector3.new(d.X, 0, 0)
		if self:collides(nx, half, tall) then
			blocked = true
		else
			pos = nx
		end
		local nz = pos + Vector3.new(0, 0, d.Z)
		if self:collides(nz, half, tall) then
			blocked = true
		else
			pos = nz
		end
		local ny = pos + Vector3.new(0, d.Y, 0)
		if self:collides(ny, half, tall) then
			if d.Y < 0 then
				onGround = true
			else
				ceiling = true
			end
		else
			pos = ny
		end
	end
	return pos, onGround, blocked, ceiling
end

-- что за блок в клетке точки (для воды, лавы, портала)
function World:at(pos)
	return self:get(math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z))
end

-- луч по сетке (Amanatides–Woo): блок под прицелом (не жидкость), пустая клетка перед ним и расстояние
function World:raycast(origin, dir, reach)
	local x, y, z = math.floor(origin.X), math.floor(origin.Y), math.floor(origin.Z)
	local stepX, stepY, stepZ = dir.X > 0 and 1 or -1, dir.Y > 0 and 1 or -1, dir.Z > 0 and 1 or -1
	local function boundary(o, d, cell)
		if d == 0 then
			return math.huge
		end
		return ((d > 0 and cell + 1 or cell) - o) / d
	end
	local tMaxX, tMaxY, tMaxZ = boundary(origin.X, dir.X, x), boundary(origin.Y, dir.Y, y), boundary(origin.Z, dir.Z, z)
	local tDX = dir.X ~= 0 and math.abs(1 / dir.X) or math.huge
	local tDY = dir.Y ~= 0 and math.abs(1 / dir.Y) or math.huge
	local tDZ = dir.Z ~= 0 and math.abs(1 / dir.Z) or math.huge
	local px, py, pz = x, y, z
	local t = 0
	while t <= reach do
		local id = self:get(x, y, z)
		if id and not BLOCKS[id].liquid then
			return Vector3.new(x, y, z), Vector3.new(px, py, pz), t, id
		end
		px, py, pz = x, y, z
		if tMaxX < tMaxY and tMaxX < tMaxZ then
			x += stepX
			t = tMaxX
			tMaxX += tDX
		elseif tMaxY < tMaxZ then
			y += stepY
			t = tMaxY
			tMaxY += tDY
		else
			z += stepZ
			t = tMaxZ
			tMaxZ += tDZ
		end
	end
	return nil
end

return World
