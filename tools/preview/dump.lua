local ROOT = ARGS[3] or "."
local M = compile(readfile(ROOT .. "/tools/mock/roblox.lua"), "roblox.lua", _G)()
local RepS = M.game:GetService("ReplicatedStorage")
M.mount(ROOT .. "/src/apps", RepS, "PS5Apps")
local AS = M.game:GetService("AssetService")
function AS:CreateEditableImage(opts)
	local img = {}
	function img:WritePixelsBuffer(_, size, buf) self.buf = buf; self.w = size.X end
	return img
end
local BC = RepS.PS5Apps.BlockCraft
local Textures = M.require(BC.Textures)
local Content = M.require(BC.Content)
local Terrain = M.require(BC.Terrain)
local function hex(content)
	local o = content.object
	local t = {}
	for i = 0, buffer.len(o.buf) - 1 do t[#t + 1] = string.format("%02x", buffer.readu8(o.buf, i)) end
	return table.concat(t)
end
for id in Content.BLOCKS do
	for _, f in { "top", "side", "bottom", "front" } do
		local name = Textures.Name(id, f)
		if name then
			local c = Textures.Icon(name)
			if c then print("TEX", id, f, hex(c)) end
		end
	end
end
for _, k in { "heart", "food" } do
	for _, st in { "full", "half", "empty" } do print("HUD", k, st, hex(Textures.Hud(k, st))) end
end
for _, n in { "diamond_pickaxe", "iron_sword", "stone_axe", "wooden_shovel", "apple", "cooked_porkchop", "diamond", "iron_ingot", "coal", "stick" } do
	print("ITEM", n, "x", hex(Textures.Item(n, Content.ITEMS[n])))
end
local w = Terrain.Overworld(12345)
print("WORLD", w.H, Terrain.SX, Terrain.SZ, w.spawn.X, w.spawn.Y, w.spawn.Z)
for k, id in w.blocks do print("B", k, id) end
