-- Упрощённая имитация API Roblox для дымового теста песочницы.
local M = {}
local now = 0
M.warnings, M.errors = {}, {}

local function logError(msg) table.insert(M.errors, msg); print("ERROR: " .. tostring(msg)) end
local realWarn = function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end local s = table.concat(t, " "); table.insert(M.warnings, s); print("WARN: " .. s) end

-- Планировщик
local queue = {}
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then logError(debug.traceback(co, tostring(err))) end
end
local task = {}
function task.spawn(fn, ...)
	local co = type(fn) == "thread" and fn or coroutine.create(fn)
	resume(co, ...)
	return co
end
function task.defer(fn, ...)
	local co = coroutine.create(fn)
	table.insert(queue, { co = co, wake = now, args = table.pack(...) })
	return co
end
function task.delay(t, fn, ...)
	local co = coroutine.create(fn)
	table.insert(queue, { co = co, wake = now + (t or 0), args = table.pack(...) })
	return co
end
function task.wait(t)
	local co = coroutine.running()
	table.insert(queue, { co = co, wake = now + (t or 0.03), args = table.pack() })
	coroutine.yield()
	return t or 0.03
end
M.task = task

-- Сигналы
local Signal = {}
Signal.__index = Signal
local function newSignal() return setmetatable({ handlers = {} }, Signal) end
function Signal:Connect(fn)
	assert(type(fn) == "function", "Connect expects function")
	local h = { fn = fn, connected = true }
	table.insert(self.handlers, h)
	return { Connected = true, Disconnect = function() h.connected = false end }
end
function Signal:Once(fn)
	local c; c = self:Connect(function(...) c.Disconnect(); fn(...) end); return c
end
function Signal:Wait()
	local co = coroutine.running(); self:Once(function(...) task.spawn(co, ...) end); return coroutine.yield()
end
function Signal:Fire(...)
	for _, h in ipairs(table.clone(self.handlers)) do
		if h.connected then task.spawn(h.fn, ...) end
	end
end
M.newSignal = newSignal

-- Типы данных
local function mt(typ, extra) local m = extra or {}; m.__type = typ; m.__index = m.__index or m; return m end
local V3 = mt("Vector3")
V3.__add = function(a, b) return M.Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return M.Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__unm = function(a) return M.Vector3.new(-a.X, -a.Y, -a.Z) end
V3.__div = function(a, b) return M.Vector3.new(a.X / b, a.Y / b, a.Z / b) end
V3.Min = function(a, b) return M.Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end
V3.Max = function(a, b) return M.Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end
V3.Lerp = function(a, b, t) return a + (b - a) * t end
V3.Dot = function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
V3.__mul = function(a, b) if type(b) == "number" then return M.Vector3.new(a.X * b, a.Y * b, a.Z * b) end return M.Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
V3.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z); return M.Vector3.new(v.X / m, v.Y / m, v.Z / m) end
	return rawget(V3, k)
end
M.Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end }
M.Vector3.one = M.Vector3.new(1, 1, 1)
M.Vector3.zero = M.Vector3.new(0, 0, 0)
local V2 = mt("Vector2")
V2.__add = function(a, b) return M.Vector2.new(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return M.Vector2.new(a.X - b.X, a.Y - b.Y) end
V2.__unm = function(a) return M.Vector2.new(-a.X, -a.Y) end
V2.__div = function(a, b) if type(b) == "number" then return M.Vector2.new(a.X / b, a.Y / b) end return M.Vector2.new(a.X / b.X, a.Y / b.Y) end
V2.__mul = function(a, b) if type(b) == "number" then return M.Vector2.new(a.X * b, a.Y * b) end if type(a) == "number" then return M.Vector2.new(b.X * a, b.Y * a) end return M.Vector2.new(a.X * b.X, a.Y * b.Y) end
V2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
V2.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y); return M.Vector2.new(v.X / m, v.Y / m) end
	return rawget(V2, k)
end
M.Vector2 = { new = function(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end }
M.Vector2.zero = M.Vector2.new(0, 0)
local UD = mt("UDim")
M.UDim = { new = function(s, o) return setmetatable({ Scale = s or 0, Offset = o or 0 }, UD) end }
local UD2 = mt("UDim2")
M.UDim2 = {
	new = function(xs, xo, ys, yo) return setmetatable({ X = M.UDim.new(xs, xo), Y = M.UDim.new(ys, yo) }, UD2) end,
}
M.UDim2.fromScale = function(x, y) return M.UDim2.new(x, 0, y, 0) end
M.UDim2.fromOffset = function(x, y) return M.UDim2.new(0, x, 0, y) end
local C3 = mt("Color3")
C3.ToHSV = function(c) return 0.5, 0.5, math.max(c.R, c.G, c.B) end
C3.Lerp = function(a, b, t) return M.Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
M.Color3 = {
	new = function(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3) end,
}
M.Color3.fromRGB = function(r, g, b) return M.Color3.new(r / 255, g / 255, b / 255) end
M.Color3.fromHSV = function(h, s, v) assert(type(h) == "number"); return M.Color3.new(v, v, v) end
M.Color3.fromHex = function(hex) assert(type(hex) == "string" and hex:match("^#?%x%x%x%x%x%x$"), "bad hex " .. tostring(hex)); return M.Color3.new(0.5, 0.5, 0.5) end
local CS = mt("ColorSequence")
M.ColorSequence = { new = function(a, b) if type(a) == "table" and getmetatable(a) == nil then for _, k in ipairs(a) do assert(typeof(k) == "ColorSequenceKeypoint") end end return setmetatable({}, CS) end }
M.ColorSequenceKeypoint = { new = function(t, c) assert(t >= 0 and t <= 1 and typeof(c) == "Color3", "bad keypoint"); return setmetatable({ Time = t, Value = c }, mt("ColorSequenceKeypoint")) end }
M.NumberSequence = { new = function(a) return setmetatable({}, mt("NumberSequence")) end }
M.NumberSequenceKeypoint = { new = function(t, v) assert(t >= 0 and t <= 1); return setmetatable({}, mt("NumberSequenceKeypoint")) end }
local CF = mt("CFrame")
CF.__mul = function(a, b) return setmetatable({ Position = a.Position, LookVector = b.LookVector or a.LookVector }, CF) end
M.CFrame = {
	new = function(x, y, z) if type(x) == "table" then return setmetatable({ Position = x }, CF) end return setmetatable({ Position = M.Vector3.new(x, y, z) }, CF) end,
	lookAt = function(p, t) assert(typeof(p) == "Vector3" and typeof(t) == "Vector3"); return setmetatable({ Position = p }, CF) end,
	Angles = function(x, y, z) assert(type(x) == "number"); return setmetatable({ Position = M.Vector3.new() }, CF) end,
	fromOrientation = function(x, y, z)
		return setmetatable({ Position = M.Vector3.new(), LookVector = M.Vector3.new(-math.sin(y) * math.cos(x), math.sin(x), -math.cos(y) * math.cos(x)) }, CF)
	end,
}
M.TweenInfo = { new = function(t, s, d) return setmetatable({ Time = t or 1 }, mt("TweenInfo")) end }
M.NumberRange = { new = function(a, b) return setmetatable({}, mt("NumberRange")) end }

-- Enum
local enumCache = {}
M.Enum = setmetatable({}, { __index = function(_, typeName)
	enumCache[typeName] = enumCache[typeName] or setmetatable({}, { __index = function(t, itemName)
		local item = setmetatable({ Name = itemName, EnumType = typeName }, mt("EnumItem", { __tostring = function() return "Enum." .. typeName .. "." .. itemName end }))
		rawset(t, itemName, item)
		return item
	end })
	return enumCache[typeName]
end })

function M.typeof(v)
	if type(v) == "table" then
		local m = getmetatable(v)
		if m and m.__type then return m.__type end
	end
	return type(v)
end
typeof = M.typeof

-- Экземпляры
local data = setmetatable({}, { __mode = "k" })
local Inst = {}
local InstMT = { __type = "Instance" }
local SUPER = {
	Frame = { "GuiObject" }, TextLabel = { "GuiObject", "TextLabel" }, TextButton = { "GuiObject", "GuiButton" },
	ImageButton = { "GuiObject", "GuiButton" }, TextBox = { "GuiObject" }, ImageLabel = { "GuiObject" },
	ScrollingFrame = { "GuiObject" }, ScreenGui = { "LayerCollector" }, Part = { "BasePart", "PVInstance" },
	Model = { "PVInstance" }, ModuleScript = { "LuaSourceContainer" }, Script = { "LuaSourceContainer" }, LocalScript = { "LuaSourceContainer", "Script" },
}
local DEFAULTS = {
	Visible = true, Enabled = true, Text = "", BackgroundTransparency = 0, TextTransparency = 0, ImageTransparency = 0,
	Transparency = 0, Scale = 1, Value = 0, Looped = false, Volume = 0.5,
}
local function d(self) return data[self] end

local function newInstance(className, name)
	local self = setmetatable({}, InstMT)
	data[self] = { ClassName = className, Name = name or className, children = {}, props = {}, attrs = {}, signals = {}, propSignals = {} }
	return self
end
M.newInstance = newInstance

local function setParent(self, parent)
	local dd = d(self)
	if dd.destroyed and parent ~= nil then error("The Parent property of " .. dd.Name .. " is locked") end
	if dd.Parent then
		local list = d(dd.Parent).children
		for i, c in ipairs(list) do if c == self then table.remove(list, i) break end end
	end
	dd.Parent = parent
	if parent then table.insert(d(parent).children, self) end
end

function Inst:GetChildren() return table.clone(d(self).children) end
function Inst:GetDescendants()
	local out = {}
	local function walk(n) for _, c in ipairs(d(n).children) do table.insert(out, c); walk(c) end end
	walk(self); return out
end
function Inst:FindFirstChild(name, recursive)
	for _, c in ipairs(d(self).children) do if d(c).Name == name then return c end end
	if recursive then for _, c in ipairs(d(self).children) do local f = c:FindFirstChild(name, true) if f then return f end end end
	return nil
end
function Inst:WaitForChild(name, timeout)
	local c = self:FindFirstChild(name)
	if c then return c end
	if timeout then return nil end
	error("Infinite yield on WaitForChild(" .. name .. ") of " .. d(self).Name)
end
function Inst:IsA(cls)
	local dd = d(self)
	if cls == dd.ClassName or cls == "Instance" then return true end
	for _, s in ipairs(SUPER[dd.ClassName] or {}) do if s == cls then return true end end
	return false
end
function Inst:IsDescendantOf(other)
	local p = d(self).Parent
	while p do if p == other then return true end p = d(p).Parent end
	return false
end
function Inst:FindFirstAncestorWhichIsA(cls)
	local p = d(self).Parent
	while p do if p:IsA(cls) then return p end p = d(p).Parent end
end
function Inst:FindFirstChildWhichIsA(cls)
	for _, c in ipairs(d(self).children) do if c:IsA(cls) then return c end end
end
Inst.FindFirstChildOfClass = Inst.FindFirstChildWhichIsA
function Inst:ClearAllChildren() for _, c in ipairs(table.clone(d(self).children)) do c:Destroy() end end
function Inst:Destroy()
	local dd = d(self)
	if dd.destroyed then return end
	for _, c in ipairs(table.clone(dd.children)) do c:Destroy() end
	setParent(self, nil); dd.destroyed = true
end
function Inst:Clone()
	local c = newInstance(d(self).ClassName, d(self).Name)
	for k, v in pairs(d(self).props) do d(c).props[k] = v end
	for k, v in pairs(d(self).attrs) do d(c).attrs[k] = v end
	for _, ch in ipairs(d(self).children) do ch:Clone().Parent = c end
	return c
end
function Inst:SetAttribute(k, v)
	local dd = d(self)
	local old = dd.attrs[k]
	dd.attrs[k] = v
	local sig = dd.attrSignals and dd.attrSignals[k]
	if sig and old ~= v then sig:Fire() end
end
function Inst:GetAttributeChangedSignal(k)
	local dd = d(self)
	dd.attrSignals = dd.attrSignals or {}
	dd.attrSignals[k] = dd.attrSignals[k] or newSignal()
	return dd.attrSignals[k]
end
function Inst:Emit() end
function Inst:GetAttribute(k) return d(self).attrs[k] end
function Inst:GetPropertyChangedSignal(p) local ps = d(self).propSignals; ps[p] = ps[p] or newSignal(); return ps[p] end
function Inst:GetFullName() local n, p = d(self).Name, d(self).Parent while p do n = d(p).Name .. "." .. n p = d(p).Parent end return n end
function Inst:Play() d(self).props.IsPlaying = true end
function Inst:Resume() d(self).props.IsPlaying = true end
function Inst:Pause() d(self).props.IsPlaying = false end
function Inst:Stop() d(self).props.IsPlaying = false end
function Inst:CaptureFocus() end
function Inst:GetBoundingBox() return M.CFrame.new(), M.Vector3.new(4, 10, 8) end
function Inst:PivotTo(cf) end
function Inst:GetPivot() return M.CFrame.new() end
function Inst:ScaleTo(s) end
function Inst:GetService(name)
	local s = self:FindFirstChild(name)
	if not s then s = newInstance(name, name); setParent(s, self) end
	return s
end

local EVENTS = {
	Activated = true, MouseEnter = true, MouseLeave = true, Changed = true, FocusLost = true, Ended = true, Completed = true,
	InputBegan = true, InputEnded = true, InputChanged = true, Heartbeat = true, RenderStepped = true, Stepped = true,
	PlayerAdded = true, PlayerRemoving = true, OnServerEvent = true, OnClientEvent = true, ChildAdded = true, MouseButton1Click = true, MouseButton2Click = true, Triggered = true, PromptShown = true, PromptHidden = true, CharacterAdded = true, DescendantAdded = true, AncestryChanged = true,
}

InstMT.__index = function(self, k)
	if Inst[k] then return Inst[k] end
	local dd = data[self]
	if k == "ClassName" or k == "Name" or k == "Parent" then return dd[k] end
	local v = dd.props[k]
	if v ~= nil then return v end
	local child = self:FindFirstChild(k)
	if child then return child end
	if EVENTS[k] then dd.signals[k] = dd.signals[k] or newSignal(); return dd.signals[k] end
	if k == "AbsolutePosition" or k == "CanvasPosition" then return M.Vector2.new(0, 0) end
	if k == "AbsoluteSize" or k == "AbsoluteCanvasSize" or k == "AbsoluteWindowSize" then return dd.ClassName == "ScreenGui" and M.Vector2.new(1920, 1080) or M.Vector2.new(100, 100) end
	if k == "CFrame" then return M.CFrame.new() end
	if k == "Position" and dd.props.CFrame then return dd.props.CFrame.Position end
	if (k == "Position" or k == "Size") and (dd.ClassName == "Part" or dd.ClassName == "MeshPart" or dd.ClassName == "SpawnLocation") then return M.Vector3.new(1, 1, 1) end
	if k == "Position" or k == "Size" then return M.UDim2.new() end
	if DEFAULTS[k] ~= nil then return DEFAULTS[k] end
	return nil
end
InstMT.__newindex = function(self, k, v)
	local dd = data[self]
	if dd.destroyed and k ~= "Parent" then
		-- Roblox допускает запись в уничтоженный объект
	end
	if k == "Parent" then
		if v ~= nil then assert(typeof(v) == "Instance", "Parent must be Instance, got " .. typeof(v)) end
		setParent(self, v)
	elseif k == "Name" then dd.Name = v
	else
		if Inst[k] or EVENTS[k] then error("cannot assign to " .. k) end
		dd.props[k] = v
		if k == "Value" and dd.signals.Changed then dd.signals.Changed:Fire(v) end
		local ps = dd.propSignals[k]; if ps then ps:Fire() end
	end
end
InstMT.__tostring = function(self) return data[self].Name end

M.Instance = { new = function(cls, parent) local i = newInstance(cls); if parent then i.Parent = parent end; return i end }

-- Сервисы
local game = newInstance("DataModel", "game")
M.game = game
local function service(name) return game:GetService(name) end
local Players = service("Players")
local player = newInstance("Player", "Tester")
player.DisplayName = "Тестер"; player.UserId = 42
player.Parent = Players
local pg = newInstance("PlayerGui", "PlayerGui"); pg.Parent = player
Players.LocalPlayer = player
player.LoadCharacter = function() end
function Players:GetPlayers() return { player } end
function Players:GetPlayerByUserId(id) if id == player.UserId then return player end return nil end
function Players:GetPlayerFromCharacter() return nil end
local Workspace = service("Workspace")
local camera = newInstance("Camera", "Camera"); camera.Parent = Workspace
camera.CameraType = M.Enum.CameraType.Custom; camera.CFrame = M.CFrame.new(); camera.FieldOfView = 70
Workspace.CurrentCamera = camera
M.workspace = Workspace
local terrainInst = newInstance("Terrain", "Terrain"); terrainInst.Parent = Workspace
function terrainInst:FillBlock(cf, size, mat) assert(typeof(size) == "Vector3") end
function terrainInst:FillCylinder(cf, h, r, mat) assert(type(h) == "number" and type(r) == "number") end
function terrainInst:SetMaterialColor() end
function game:BindToClose(fn) end
local RS = service("RunService")
function RS:IsClient() return true end
function RS:IsServer() return true end
local UIS = service("UserInputService")
function UIS:GetFocusedTextBox() return nil end
function UIS:GetMouseDelta() return M.Vector2.new(3, 1) end
local CAS = service("ContextActionService")
function CAS:BindActionAtPriority() end
local HS = service("HapticService")
function HS:IsVibrationSupported() return true end
function HS:SetMotor() end
local SG = service("StarterGui")
function SG:SetCoreGuiEnabled() end
local TS = service("TweenService")
function TS:Create(inst, info, props)
	assert(typeof(inst) == "Instance", "tween target")
	assert(typeof(info) == "TweenInfo", "tween info")
	local tween = { Completed = newSignal() }
	function tween:Play()
		for k, v in pairs(props) do inst[k] = v end
		task.delay(info.Time, function() tween.Completed:Fire() end)
	end
	function tween:Cancel() end
	return tween
end
local DSS = service("DataStoreService")
M.stored = {}
function DSS:GetDataStore(name)
	return { GetAsync = function(_, k) return M.stored[k] end, SetAsync = function(_, k, v) M.stored[k] = v end }
end
local Http = service("HttpService")
local function encode(v)
	local t = type(v)
	if t == "table" then
		assert(getmetatable(v) == nil, "cannot JSON-encode " .. typeof(v))
		local parts = {}
		for k, x in pairs(v) do table.insert(parts, tostring(k) .. ":" .. encode(x)) end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif t == "string" then return '"' .. v .. '"'
	elseif t == "number" or t == "boolean" or t == "nil" then return tostring(v)
	end
	error("cannot JSON-encode " .. t)
end
function Http:JSONEncode(v) return encode(v) end
service("SoundService"); service("Lighting"); service("GuiService"); service("ServerScriptService")
local RepS = service("ReplicatedStorage")
local AS = service("AssetService")
M.editable = { images = 0, meshes = 0 }
function AS:CreateEditableImage(opts)
	assert(typeof(opts.Size) == "Vector2", "CreateEditableImage Size")
	M.editable.images += 1
	return { WritePixelsBuffer = function(_, pos, size, buf)
		assert(buffer.len(buf) == size.X * size.Y * 4, "pixel buffer size " .. buffer.len(buf))
	end }
end
function AS:CreateEditableMesh()
	local n, f = 0, 0
	local mesh = {}
	function mesh:AddVertex(p) assert(typeof(p) == "Vector3"); n += 1; return n end
	function mesh:AddNormal(p) assert(typeof(p) == "Vector3"); return n end
	function mesh:AddTriangle(a, b, c) assert(a and b and c, "triangle ids"); f += 1; return f end
	function mesh:SetFaceNormals(face, ids) assert(#ids == 3 and ids[1] and ids[2] and ids[3], "face normals") end
	local uvs = 0
	function mesh:AddUV(p) assert(typeof(p) == "Vector2"); uvs += 1; return uvs end
	function mesh:SetFaceUVs(face, ids) assert(#ids == 3 and ids[1] and ids[2] and ids[3] and ids[3] <= uvs, "face uvs") end
	return mesh
end
function AS:CreateMeshPartAsync(content, options) M.editable.meshes += 1; return newInstance("MeshPart", "MeshPart") end
_G.Content = { fromObject = function(o) return setmetatable({ object = o }, mt("Content")) end }
SUPER.MeshPart = { "BasePart", "PVInstance" }

-- RemoteFunction/RemoteEvent напрямую на «сервер» в том же процессе
Inst.InvokeServer = function(self, ...) local f = d(self).props.OnServerInvoke; return f(player, ...) end
Inst.FireServer = function(self, ...) self.OnServerEvent:Fire(player, ...) end

-- Модули по правилам Rojo
local moduleCache = {}
local sources = setmetatable({}, { __mode = "k" })
local function mount(path, parent, name)
	local entries = listdir(path)
	local hasInit = false
	for _, e in ipairs(entries) do if e.name == "init.luau" then hasInit = true end end
	local node
	if hasInit then node = newInstance("ModuleScript", name); sources[node] = path .. "/init.luau"
	else node = newInstance("Folder", name) end
	node.Parent = parent
	for _, e in ipairs(entries) do
		if e.dir then mount(path .. "/" .. e.name, node, e.name)
		elseif e.name ~= "init.luau" and e.name:match("%.luau$") then
			local base = e.name:gsub("%.luau$", "")
			local cls = "ModuleScript"
			if base:match("%.server$") then cls = "Script"; base = base:gsub("%.server$", "") end
			if base:match("%.client$") then cls = "LocalScript"; base = base:gsub("%.client$", "") end
			local inst = newInstance(cls, base); sources[inst] = path .. "/" .. e.name; inst.Parent = node
		end
	end
	return node
end
M.mount = mount

local env
local function run(inst)
	local src = readfile(sources[inst])
	local e = setmetatable({ script = inst }, { __index = env })
	local fn = compile(src, sources[inst], e)
	return fn()
end
M.run = run
local function require_(inst)
	assert(typeof(inst) == "Instance" and inst:IsA("ModuleScript"), "require expects ModuleScript, got " .. tostring(inst))
	if moduleCache[inst] == nil then
		moduleCache[inst] = "loading"
		local result = run(inst)
		assert(result ~= nil, "module returned nil: " .. inst:GetFullName())
		moduleCache[inst] = result
	end
	assert(moduleCache[inst] ~= "loading", "circular require " .. inst:GetFullName())
	return moduleCache[inst]
end

env = setmetatable({
	game = game, workspace = Workspace, require = require_, task = task, typeof = M.typeof, warn = realWarn,
	Instance = M.Instance, UDim = M.UDim, UDim2 = M.UDim2, Vector2 = M.Vector2, Vector3 = M.Vector3, Color3 = M.Color3,
	ColorSequence = M.ColorSequence, ColorSequenceKeypoint = M.ColorSequenceKeypoint, NumberSequence = M.NumberSequence,
	Random = { new = function(seed) return { NextNumber = function(_, a, b) return a + (b - a) * math.random() end, NextInteger = function(_, a, b) return math.random(a, b) end } end },
	NumberSequenceKeypoint = M.NumberSequenceKeypoint, CFrame = M.CFrame, TweenInfo = M.TweenInfo, Enum = M.Enum, NumberRange = M.NumberRange,
}, { __index = _G })

function M.step(dt)
	now += dt
	RS.Heartbeat:Fire(dt)
	RS.RenderStepped:Fire(dt)
	local guard = 0
	while true do
		local ready
		for i, q in ipairs(queue) do if q.wake <= now then ready = i break end end
		if not ready then break end
		local q = table.remove(queue, ready)
		resume(q.co, table.unpack(q.args, 1, q.args.n))
		guard += 1
		if guard > 10000 then logError("scheduler runaway") break end
	end
end
function M.advance(seconds, dt)
	dt = dt or 1 / 30
	local t = 0
	while t < seconds do M.step(dt); t += dt end
end
function M.key(name, down)
	local io = { KeyCode = M.Enum.KeyCode[name], UserInputType = M.Enum.UserInputType.Keyboard, Position = M.Vector3.new() }
	if down == false then UIS.InputEnded:Fire(io, false) else UIS.InputBegan:Fire(io, false) end
end
function M.tap(name) M.key(name, true); M.step(1 / 30); M.key(name, false); M.step(1 / 30) end
M.Content = _G.Content
M.player, M.services = player, { RS = RepS, UIS = UIS }
M.require = require_
return M
