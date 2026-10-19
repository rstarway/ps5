-- Снимает дерево интерфейса BlockCraft из мок-движка: каждый экран -> JSON для отрисовки в Python
local ROOT = ARGS[3] or "."
local OUT = ARGS[4] or "gui"
local M = compile(readfile(ROOT .. "/tools/mock/roblox.lua"), "roblox.lua", _G)()
local RepS = M.game:GetService("ReplicatedStorage")
M.mount(ROOT .. "/src/shared/PS5", RepS, "PS5")
M.mount(ROOT .. "/src/apps", RepS, "PS5Apps")

-- запоминаем ключи градиентов (мок их теряет)
local csNew = M.ColorSequence.new
M.ColorSequence.new = function(a, b)
	local r = csNew(a, b)
	rawset(r, "_kp", type(a) == "table" and getmetatable(a) == nil and a or { { Time = 0, Value = a }, { Time = 1, Value = b or a } })
	return r
end
local nsNew = M.NumberSequence.new
M.NumberSequence.new = function(a, b)
	local r = nsNew(a)
	rawset(r, "_v", a); rawset(r, "_v2", b)
	return r
end
local nkNew = M.NumberSequenceKeypoint.new
M.NumberSequenceKeypoint.new = function(t, v)
	local r = nkNew(t, v)
	rawset(r, "Time", t); rawset(r, "Value", v)
	return r
end

local images, imageList = {}, {}
local AS = M.game:GetService("AssetService")
function AS:CreateEditableImage(opts)
	local img = { size = opts.Size }
	function img:WritePixelsBuffer(_, size, buf) self.buf = buf; self.w = size.X; self.h = size.Y end
	return img
end
local function imageId(content)
	if not content or not content.object then return nil end
	local o = content.object
	if not images[o] then
		table.insert(imageList, o)
		images[o] = #imageList
	end
	return images[o]
end

-- JSON
local function enc(v)
	local t = type(v)
	if t == "nil" then return "null" end
	if t == "boolean" then return v and "true" or "false" end
	if t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "0" end
		return string.format("%.4f", v):gsub("%.?0+$", "")
	end
	if t == "string" then
		return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", string.byte(c)) end) .. '"'
	end
	if #v > 0 or next(v) == nil then
		local p = {}
		for i = 1, #v do p[i] = enc(v[i]) end
		return "[" .. table.concat(p, ",") .. "]"
	end
	local p = {}
	for k, x in pairs(v) do table.insert(p, enc(tostring(k)) .. ":" .. enc(x)) end
	return "{" .. table.concat(p, ",") .. "}"
end
local function c3(c) return c and { c.R, c.G, c.B } or nil end
local function ud2(u) return u and { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset } or nil end
local function v2(v) return v and { v.X, v.Y } or nil end
local function en(e) return e and e.Name or nil end

local function node(inst)
	local cls = inst.ClassName
	local n = { c = cls, name = inst.Name }
	if cls == "UIStroke" then
		n.color, n.th, n.tr, n.mode = c3(inst.Color), inst.Thickness, inst.Transparency, en(inst.ApplyStrokeMode)
		return n
	elseif cls == "UIGradient" then
		local kp = {}
		local cs = inst.Color
		for _, k in ipairs(cs and rawget(cs, "_kp") or {}) do table.insert(kp, { k.Time, c3(k.Value) }) end
		n.kp, n.rot = kp, inst.Rotation
		local ns = inst.Transparency
		if ns then
			local v = rawget(ns, "_v")
			if type(v) == "number" then n.tr = { { 0, v }, { 1, rawget(ns, "_v2") or v } }
			elseif type(v) == "table" then n.tr = {}; for _, k in ipairs(v) do table.insert(n.tr, { rawget(k, "Time"), rawget(k, "Value") }) end end
		end
		return n
	elseif cls == "UIListLayout" then
		n.dir, n.pad, n.halign = en(inst.FillDirection), inst.Padding and inst.Padding.Offset or 0, en(inst.HorizontalAlignment)
		return n
	elseif cls == "UIGridLayout" then
		n.cell, n.cpad = ud2(inst.CellSize), ud2(inst.CellPadding)
		return n
	elseif cls == "UIPadding" then
		n.pl = inst.PaddingLeft and inst.PaddingLeft.Offset or 0
		n.pt = inst.PaddingTop and inst.PaddingTop.Offset or 0
		return n
	elseif cls == "UIScale" or cls == "UICorner" then
		return n
	end
	if not inst:IsA("GuiObject") and cls ~= "ViewportFrame" then return nil end
	n.size, n.pos, n.anchor = ud2(inst.Size), ud2(inst.Position), v2(inst.AnchorPoint)
	n.vis = inst.Visible ~= false
	n.bg, n.bgt = c3(inst.BackgroundColor3), inst.BackgroundTransparency
	n.z, n.lo, n.rot, n.clip = inst.ZIndex or 1, inst.LayoutOrder or 0, inst.Rotation or 0, inst.ClipsDescendants
	if cls == "TextLabel" or cls == "TextButton" or cls == "TextBox" then
		n.text = inst.Text
		if cls == "TextBox" and (n.text == nil or n.text == "") then n.text = inst.PlaceholderText; n.ph = true; n.tc = c3(inst.PlaceholderColor3) end
		n.tc = n.tc or c3(inst.TextColor3)
		n.ts, n.tt, n.xa, n.ya, n.rich = inst.TextSize, inst.TextTransparency, en(inst.TextXAlignment), en(inst.TextYAlignment), inst.RichText
		n.tscaled, n.stroket, n.strokec = inst.TextScaled, inst.TextStrokeTransparency, c3(inst.TextStrokeColor3)
	end
	if cls == "ImageLabel" or cls == "ImageButton" then
		n.img = imageId(inst.ImageContent)
		n.ic, n.it, n.scale, n.tile = c3(inst.ImageColor3), inst.ImageTransparency, en(inst.ScaleType), ud2(inst.TileSize)
		n.rofs, n.rsize = v2(inst.ImageRectOffset), v2(inst.ImageRectSize)
	end
	if cls == "ScrollingFrame" then n.clip = true end
	if cls == "ViewportFrame" then
		n.parts = {}
		for _, p in inst:GetChildren() do
			if p.ClassName == "Part" then
				local faces = {}
				for _, d in p:GetChildren() do
					if d.ClassName == "Decal" then faces[en(d.Face)] = { imageId(d.TextureContent), (d.Color3 or M.Color3.new(1, 1, 1)).R } end
				end
				local pos = p.CFrame and p.CFrame.Position or M.Vector3.new()
				table.insert(n.parts, { size = { p.Size.X, p.Size.Y, p.Size.Z }, pos = { pos.X, pos.Y, pos.Z }, color = c3(p.Color), tr = p.Transparency or 0, faces = faces })
			end
		end
		return n
	end
	local kids = {}
	for _, ch in inst:GetChildren() do
		local k = node(ch)
		if k then table.insert(kids, k) end
	end
	n.kids = kids
	return n
end

-- контекст приложения
local Util = M.require(RepS.PS5.Util)
local gui = M.Instance.new("ScreenGui")
gui.Parent = M.player:FindFirstChild("PlayerGui") or M.game:GetService("StarterGui")
local folder = M.Instance.new("Folder"); folder.Parent = M.workspace
local store = {}
local loops = {}
local manifest = M.require(RepS.PS5Apps.BlockCraft.manifest)
local unlocked = { stone_age = true, getting_upgrade = true, acquire_hardware = true }
local ctx = {
	ui = Util, gui = gui, world = folder, camera = M.workspace.CurrentCamera, paused = false,
	input = {
		On = function() end, Device = function() return "keyboard" end, IsDown = function() return false end,
		GetAxes = function() return { lx = 0, ly = 0, rx = 0, ry = 0 } end, Rumble = function() end,
	},
	save = {
		Get = function(_, k, d) local v = store[k]; if v == nil then return d end return v end,
		Set = function(_, k, v) store[k] = v end, Remove = function(_, k) store[k] = nil end,
	},
	trophies = {
		Unlock = function() end, IsUnlocked = function(_, id) return unlocked[id] end,
		List = function()
			local out = {}
			for _, t in manifest.trophies or {} do
				table.insert(out, { id = t.id, name = t.name, description = t.description, unlocked = unlocked[t.id] or false })
			end
			return out
		end,
	},
	audio = { Play = function() end, Loop = function() end },
}
function ctx:Loop(fn) table.insert(loops, fn) end
function ctx:Connect(sig, fn) return sig:Connect(fn) end
function ctx:On() end
function ctx:Exit() end

local BC = M.require(RepS.PS5Apps.BlockCraft)
BC.launch(ctx)
local G = BC.debug
local canvas = gui:FindFirstChild("Canvas")

local function snap(name)
	-- подсказка у курсора в превью не нужна
	for _, d in canvas:GetDescendants() do
		if d.Name == "Tooltip" then d.Visible = false end
	end
	local f = io and io.open and io.open(OUT .. "/" .. name .. ".json", "w")
	local data = enc({ state = G.state, root = node(canvas) })
	print("SNAP", name, data)
end

snap("title")
G.screens.open("create"); snap("create")
G.createWorld("New World", "survival", 12345, "Normal")
for _ = 1, 3 do for _, fn in loops do fn(1 / 30) end end
G.give("oak_log", 12); G.give("cobblestone", 30); G.give("iron_ore", 5); G.give("coal", 8); G.give("stone_pickaxe", 1); G.give("iron_sword", 1); G.give("torch", 16); G.give("apple", 3); G.give("crafting_table", 1)
G.screens.open("worlds"); snap("worlds")
G.screens.open("inventory"); snap("inventory")
G.screens.close()
G.screens.open("table")
-- разложить доски в сетку: половина брёвен -> верстак
G.screens.close()
local f = G.screens.furnaceState("1,1,1")
f.input = { n = "iron_ore", c = 4 }; f.fuel = { n = "coal", c = 3 }; f.output = { n = "iron_ingot", c = 2 }; f.burn, f.burnMax, f.cook = 50, 80, 6
G.screens.open("furnace", { key = "1,1,1" }); G.screens.tickFurnaces(0); snap("furnace")
G.screens.close()
G.screens.open("table"); snap("table")
G.screens.close()
G.mode = "creative"
G.screens.open("creative", { tab = 1 }); snap("creative")
G.screens.close()
G.mode = "survival"
G.state = "paused"
G.screens.open("pause"); snap("pause")
G.screens.open("options", { back = "pause" }); snap("options")
G.screens.open("advancements", { back = "pause" }); snap("advancements")
G.state = "play"
G.screens.close()
G.damage(30, nil, "lava"); snap("death")
-- изображения
for i, o in ipairs(imageList) do
	if o.buf then
		local t = {}
		for j = 0, buffer.len(o.buf) - 1 do t[#t + 1] = string.format("%02x", buffer.readu8(o.buf, j)) end
		print("IMG", i, o.w, o.h, table.concat(t))
	end
end
