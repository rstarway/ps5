-- Трасса Neon Drive: замкнутый сплайн, дорога с неоновыми бортами и ночной город вокруг.
-- Вся математика на Vector3 и числах (без методов CFrame), чтобы работала и в имитации tools/mock.
local Track = {}
Track.__index = Track

Track.WIDTH = 44
local HALF = Track.WIDTH / 2
local SUB = 14 -- точек сплайна между опорными

-- Опорные точки (x, высота, z) относительно base. Длина круга около 4200 studs.
local CONTROL = {
	{ 0, 0, 0 }, { 450, 0, 0 }, { 760, 4, 70 }, { 880, 10, 300 }, { 780, 16, 520 }, { 540, 12, 580 },
	{ 380, 8, 740 }, { 430, 4, 960 }, { 260, 8, 1130 }, { -60, 16, 1090 }, { -230, 12, 880 }, { -140, 6, 660 },
	{ -330, 4, 500 }, { -470, 2, 270 }, { -380, 0, 70 }, { -200, 0, 0 },
}

local PINK = Color3.fromRGB(255, 61, 127)
local VIOLET = Color3.fromRGB(123, 44, 255)
local CYAN = Color3.fromRGB(0, 229, 255)
local AMBER = Color3.fromRGB(255, 176, 46)
Track.Colors = { pink = PINK, violet = VIOLET, cyan = CYAN, amber = AMBER }
local NEONS = { PINK, VIOLET, CYAN, AMBER, PINK, CYAN }

local function catmull(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	return (p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function part(parent, size, cf, color, material, transparency)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Parent = parent
	return p
end
Track.part = part

-- Брусок между двумя точками (длина по направлению a→b)
local function beam(parent, a, b, width, height, color, material, transparency)
	local d = b - a
	local len = d.Magnitude
	if len < 0.01 then
		return nil
	end
	local mid = (a + b) / 2
	return part(parent, Vector3.new(width, height, len), CFrame.lookAt(mid, b), color, material, transparency)
end

function Track.new(base)
	local self = setmetatable({}, Track)
	self.base = base
	local pts = {}
	for _, c in CONTROL do
		table.insert(pts, Vector3.new(c[1], c[2], c[3]))
	end
	local n = #pts
	local samples = {}
	for i = 1, n do
		local p0, p1 = pts[(i - 2) % n + 1], pts[i]
		local p2, p3 = pts[i % n + 1], pts[(i + 1) % n + 1]
		for k = 0, SUB - 1 do
			table.insert(samples, base + catmull(p0, p1, p2, p3, k / SUB))
		end
	end
	self.samples = samples
	self.N = #samples
	-- направления и правые векторы в каждой точке (по горизонтали)
	self.tangents, self.rights, self.lengths, self.cum = {}, {}, {}, {}
	local total = 0
	for i = 1, self.N do
		local prev, nxt = samples[(i - 2) % self.N + 1], samples[i % self.N + 1]
		local t = flat(nxt - prev).Unit
		self.tangents[i] = t
		self.rights[i] = Vector3.new(-t.Z, 0, t.X)
		self.cum[i] = total
		self.lengths[i] = flat(nxt - samples[i]).Magnitude
		total += self.lengths[i]
	end
	self.total = total
	return self
end

function Track:sample(i)
	return self.samples[(i - 1) % self.N + 1]
end

-- Проекция точки на осевую линию. hint — индекс прошлого сегмента (поиск вокруг него).
-- Возвращает индекс сегмента, долю t по нему, боковое смещение (+ вправо), точку на оси, касательную.
function Track:project(pos, hint, wide)
	local N = self.N
	local bestD, bestI, bestT = math.huge, 1, 0
	local from, to = 1, N
	if hint and not wide then
		from, to = hint - 8, hint + 8
	end
	local px, pz = pos.X, pos.Z
	for k = from, to do
		local i = (k - 1) % N + 1
		local a, b = self.samples[i], self.samples[i % N + 1]
		local dx, dz = b.X - a.X, b.Z - a.Z
		local len2 = dx * dx + dz * dz
		local t = math.clamp(((px - a.X) * dx + (pz - a.Z) * dz) / len2, 0, 1)
		local cx, cz = a.X + dx * t - px, a.Z + dz * t - pz
		local d = cx * cx + cz * cz
		if d < bestD then
			bestD, bestI, bestT = d, i, t
		end
	end
	local a, b = self.samples[bestI], self.samples[bestI % N + 1]
	local point = a + (b - a) * bestT
	local tangent = flat(b - a).Unit
	local right = Vector3.new(-tangent.Z, 0, tangent.X)
	local lateral = (pos.X - point.X) * right.X + (pos.Z - point.Z) * right.Z
	local slope = (b.Y - a.Y) / math.max(self.lengths[bestI], 0.01)
	return bestI, bestT, lateral, point, tangent, slope
end

-- Пройденная доля круга 0..1
function Track:progress(i, t)
	return (self.cum[i] + self.lengths[i] * t) / self.total
end

local function nearTrack(self, pos, clearance)
	local c2 = clearance * clearance
	for _, s in self.samples do
		local dx, dz = s.X - pos.X, s.Z - pos.Z
		if dx * dx + dz * dz < c2 then
			return true
		end
	end
	return false
end

-- Строит дорогу, ворота, ускорители и город. Возвращает { gates = {...}, pads = {...} }.
function Track:build(parent, checkpoints, padSpots)
	local rng = Random.new(7)
	local N, S, R = self.N, self.samples, self.rights
	local road = Instance.new("Model")
	road.Name = "Road"
	local asphalt = Color3.fromRGB(22, 18, 34)

	local minX, maxX, minZ, maxZ, minY = math.huge, -math.huge, math.huge, -math.huge, math.huge
	for _, s in S do
		minX, maxX = math.min(minX, s.X), math.max(maxX, s.X)
		minZ, maxZ = math.min(minZ, s.Z), math.max(maxZ, s.Z)
		minY = math.min(minY, s.Y)
	end
	local groundY = minY - 1.5

	for i = 1, N do
		local a, b = S[i], S[i % N + 1]
		-- полотно: брусок по сегменту + диск в точке, чтобы на поворотах не было щелей
		beam(road, a - Vector3.new(0, 0.5, 0), b - Vector3.new(0, 0.5, 0), Track.WIDTH, 1, asphalt, Enum.Material.Asphalt)
		local disc = part(road, Vector3.new(1, Track.WIDTH, Track.WIDTH), CFrame.new(a - Vector3.new(0, 0.55, 0)) * CFrame.Angles(0, 0, math.pi / 2), asphalt, Enum.Material.Asphalt)
		disc.Shape = Enum.PartType.Cylinder
		-- неоновые борта по краям, цвет меняется полосами
		local color = (math.floor(i / 3) % 2 == 0) and PINK or VIOLET
		local ra, rb = R[i], R[i % N + 1]
		for _, side in { -1, 1 } do
			local ea = a + ra * (side * (HALF + 0.6)) + Vector3.new(0, 1.1, 0)
			local eb = b + rb * (side * (HALF + 0.6)) + Vector3.new(0, 1.1, 0)
			beam(road, ea, eb, 0.7, 2.2, color, Enum.Material.Neon, 0.15)
		end
		-- разметка по центру
		if i % 2 == 0 then
			local m = (a + b) / 2 + Vector3.new(0, 0.03, 0)
			local dir = (b - a).Unit
			beam(road, m - dir * 4, m + dir * 4, 0.6, 0.06, Color3.fromRGB(200, 170, 255), Enum.Material.Neon, 0.35)
		end
		-- опоры под эстакадой
		if a.Y - groundY > 4 and i % 3 == 0 then
			for _, side in { -1, 1 } do
				local top = a + ra * (side * (HALF - 4)) - Vector3.new(0, 1, 0)
				local h = top.Y - groundY
				part(road, Vector3.new(3, h, 3), CFrame.new(top.X, groundY + h / 2, top.Z), Color3.fromRGB(30, 26, 46), Enum.Material.Concrete)
			end
		end
		-- фонари: столб, неоновая лампа и свет
		if i % 9 == 0 then
			local side = (i % 18 == 0) and 1 or -1
			local foot = a + ra * (side * (HALF + 3))
			part(road, Vector3.new(0.8, 16, 0.8), CFrame.new(foot + Vector3.new(0, 8, 0)), Color3.fromRGB(40, 36, 60), Enum.Material.Metal)
			local head = beam(road, foot + Vector3.new(0, 16, 0), foot - ra * (side * 6) + Vector3.new(0, 16, 0), 1.2, 0.5, i % 27 == 0 and CYAN or PINK, Enum.Material.Neon)
			if head then
				local light = Instance.new("PointLight")
				light.Color = head.Color
				light.Range = 45
				light.Brightness = 2.2
				light.Parent = head
			end
		end
	end

	-- старт/финиш: клетчатая линия и арка
	local gates = {}
	local function gate(index, color, isStart)
		local g = Instance.new("Model")
		g.Name = isStart and "StartGate" or ("Checkpoint" .. index)
		local a, r, t = S[index], R[index], self.tangents[index]
		local bars = {}
		for _, side in { -1, 1 } do
			local foot = a + r * (side * (HALF + 2))
			table.insert(bars, part(g, Vector3.new(2, 20, 2), CFrame.new(foot + Vector3.new(0, 10, 0)), color, Enum.Material.Neon))
		end
		table.insert(bars, beam(g, a - r * (HALF + 3) + Vector3.new(0, 20, 0), a + r * (HALF + 3) + Vector3.new(0, 20, 0), 2, isStart and 4 or 1.6, color, Enum.Material.Neon))
		if isStart then
			for row = 0, 1 do
				for col = 0, 10 do
					local pos = a + r * (-HALF + 2 + col * 4) + t * (row * 4 - 2) + Vector3.new(0, 0.04, 0)
					local white = (row + col) % 2 == 0
					part(g, Vector3.new(4, 0.08, 4), CFrame.lookAt(pos, pos + t), white and Color3.new(0.95, 0.95, 1) or Color3.fromRGB(10, 10, 16), white and Enum.Material.Neon or Enum.Material.SmoothPlastic)
				end
			end
			local sign = beam(g, a - r * 14 + Vector3.new(0, 25, 0), a + r * 14 + Vector3.new(0, 25, 0), 1, 6, Color3.fromRGB(16, 8, 30), Enum.Material.SmoothPlastic)
			if sign then
				for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
					local gui = Instance.new("SurfaceGui")
					gui.Face = face
					gui.LightInfluence = 0
					gui.PixelsPerStud = 20
					gui.Parent = sign
					local label = Instance.new("TextLabel")
					label.Size = UDim2.fromScale(1, 1)
					label.BackgroundTransparency = 1
					label.Text = "NEON DRIVE"
					label.TextScaled = true
					label.Font = Enum.Font.Arcade
					label.TextColor3 = PINK
					label.Parent = gui
				end
			end
		end
		g.Parent = parent
		gates[index] = bars
	end
	gate(1, Color3.new(1, 1, 1), true)
	for _, idx in checkpoints do
		if idx ~= 1 then
			gate(idx, CYAN, false)
		end
	end

	-- ускорители: светящаяся плита со стрелками
	local pads = {}
	for _, spot in padSpots do
		local a, r, t = S[spot.index], R[spot.index], self.tangents[spot.index]
		local center = a + r * spot.offset + Vector3.new(0, 0.05, 0)
		part(road, Vector3.new(12, 0.1, 16), CFrame.lookAt(center, center + t), Color3.fromRGB(0, 140, 180), Enum.Material.Neon, 0.3)
		for k = 0, 2 do
			local tip = center + t * (k * 5 - 3) + Vector3.new(0, 0.08, 0)
			for _, side in { -1, 1 } do
				beam(road, tip - t * 3 + r * (side * 4), tip, 1, 0.08, CYAN, Enum.Material.Neon)
			end
		end
		table.insert(pads, { index = spot.index, offset = spot.offset, center = center })
	end
	road.Parent = parent

	-- город
	local city = Instance.new("Model")
	city.Name = "City"
	local ground = part(city, Vector3.new(maxX - minX + 1400, 1, maxZ - minZ + 1400), CFrame.new((minX + maxX) / 2, groundY - 0.5, (minZ + maxZ) / 2), Color3.fromRGB(8, 6, 18), Enum.Material.SmoothPlastic)
	ground.Name = "Ground"
	-- неоновая сетка на земле
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local spanX, spanZ = maxX - minX + 1400, maxZ - minZ + 1400
	for x = -spanX / 2, spanX / 2, 120 do
		part(city, Vector3.new(0.4, 0.05, spanZ), CFrame.new(cx + x, groundY + 0.02, cz), VIOLET, Enum.Material.Neon, 0.75)
	end
	for z = -spanZ / 2, spanZ / 2, 120 do
		part(city, Vector3.new(spanX, 0.05, 0.4), CFrame.new(cx, groundY + 0.02, cz + z), VIOLET, Enum.Material.Neon, 0.75)
	end

	local function building(pos, t, w, d, h, detail)
		local body = Color3.fromRGB(rng:NextInteger(12, 26), rng:NextInteger(10, 20), rng:NextInteger(28, 48))
		local center = Vector3.new(pos.X, groundY + h / 2, pos.Z)
		local look = center + t
		part(city, Vector3.new(w, h, d), CFrame.lookAt(center, look), body, Enum.Material.SmoothPlastic)
		local r = Vector3.new(-t.Z, 0, t.X)
		local neon = NEONS[rng:NextInteger(1, #NEONS)]
		-- вертикальные неоновые рёбра по углам
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				if detail or sx == sz then
					local corner = center + r * (sx * (w / 2 + 0.1)) + t * (sz * (d / 2 + 0.1))
					part(city, Vector3.new(0.5, h, 0.5), CFrame.new(corner), neon, Enum.Material.Neon, 0.1)
				end
			end
		end
		if detail then
			-- полосы окон по периметру
			local bands = math.clamp(math.floor(h / 28), 1, 5)
			for k = 1, bands do
				local y = groundY + h * k / (bands + 1)
				local c = rng:NextNumber(0, 1) < 0.7 and neon or NEONS[rng:NextInteger(1, #NEONS)]
				local p = Vector3.new(center.X, y, center.Z)
				part(city, Vector3.new(w + 0.4, 1.2, d + 0.4), CFrame.lookAt(p, p + t), c, Enum.Material.Neon, rng:NextNumber(0, 1) * 0.5)
			end
		end
		-- огонёк на крыше
		local top = Vector3.new(center.X, groundY + h + 1, center.Z)
		part(city, Vector3.new(2, 2, 2), CFrame.new(top), Color3.fromRGB(255, 40, 60), Enum.Material.Neon)
	end

	for i = 1, N, 3 do
		local s, t, r = S[i], self.tangents[i], R[i]
		for _, side in { -1, 1 } do
			local w, d, h = rng:NextNumber(22, 46), rng:NextNumber(22, 46), rng:NextNumber(40, 200)
			local off = HALF + 16 + rng:NextNumber(0, 36) + math.max(w, d) / 2
			local pos = s + r * (side * off)
			if not nearTrack(self, pos, HALF + 6 + math.max(w, d) * 0.72) then
				building(pos, t, w, d, h, true)
			end
		end
	end
	-- дальние небоскрёбы на фоне
	for i = 1, N, 6 do
		local s, t, r = S[i], self.tangents[i], R[i]
		for _, side in { -1, 1 } do
			local w, d, h = rng:NextNumber(40, 80), rng:NextNumber(40, 80), rng:NextNumber(180, 420)
			local pos = s + r * (side * rng:NextNumber(180, 340))
			if not nearTrack(self, pos, HALF + 20 + math.max(w, d) * 0.72) then
				building(pos, t, w, d, h, false)
			end
		end
	end
	-- закатное неоновое солнце на горизонте
	local sunPos = Vector3.new(cx, groundY + 260, maxZ + 1800)
	local sun = part(city, Vector3.new(2, 900, 900), CFrame.lookAt(sunPos, Vector3.new(cx, groundY + 260, cz)) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(255, 90, 120), Enum.Material.Neon)
	sun.Shape = Enum.PartType.Cylinder
	city.Parent = parent

	return { gates = gates, pads = pads, groundY = groundY }
end

return Track
