-- Содержимое BlockCraft по образцу Minecraft Java 1.16.5 (Nether Update): блоки, предметы, инструменты,
-- рецепты верстака и печи, бартер пиглинов. Цвета и значки свои, без текстур и звуков Mojang.
local M = Enum.Material
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Content = {}

-- Блоки. hardness как в Minecraft (сек ≈ hardness × 1.5 правильным инструментом без ускорения, −1 = нельзя сломать).
-- tool: pickaxe | axe | shovel; tier: какой кирке под силу (1 дерево, 2 камень, 3 железо, 4 алмаз);
-- see: сквозь блок видно соседей; solid = false: сквозь блок можно пройти; light: яркость свечения.
Content.BLOCKS = {
	grass_block = { label = "Grass Block", color = rgb(104, 168, 68), material = M.Grass, hardness = 0.6, tool = "shovel", drop = "dirt" },
	dirt = { label = "Dirt", color = rgb(134, 96, 67), material = M.Ground, hardness = 0.5, tool = "shovel" },
	stone = { label = "Stone", color = rgb(125, 125, 125), material = M.Slate, hardness = 1.5, tool = "pickaxe", tier = 1, drop = "cobblestone" },
	cobblestone = { label = "Cobblestone", color = rgb(112, 112, 112), material = M.Cobblestone, hardness = 2, tool = "pickaxe", tier = 1 },
	bedrock = { label = "Bedrock", color = rgb(45, 45, 48), material = M.Basalt, hardness = -1 },
	sand = { label = "Sand", color = rgb(222, 206, 150), material = M.Sand, hardness = 0.5, tool = "shovel", falls = true },
	gravel = { label = "Gravel", color = rgb(138, 130, 126), material = M.Pebble, hardness = 0.6, tool = "shovel", falls = true },
	sandstone = { label = "Sandstone", color = rgb(214, 198, 138), material = M.Sandstone, hardness = 0.8, tool = "pickaxe", tier = 1 },
	snow_block = { label = "Snow Block", color = rgb(240, 248, 255), material = M.Snow, hardness = 0.2, tool = "shovel" },
	ice = { label = "Ice", color = rgb(150, 190, 250), material = M.Ice, hardness = 0.5, tool = "pickaxe", see = true, transparency = 0.25, drop = false },
	cactus = { label = "Cactus", color = rgb(78, 138, 58), material = M.Grass, hardness = 0.4, inset = 0.0625, hurts = 1 },
	oak_log = { label = "Oak Log", color = rgb(108, 82, 50), material = M.Wood, hardness = 2, tool = "axe", fuel = true },
	birch_log = { label = "Birch Log", color = rgb(220, 216, 200), material = M.Wood, hardness = 2, tool = "axe", fuel = true },
	oak_leaves = { label = "Oak Leaves", color = rgb(60, 138, 56), material = M.LeafyGrass, hardness = 0.2, see = true, drop = "apple", dropChance = 0.05 },
	birch_leaves = { label = "Birch Leaves", color = rgb(110, 160, 80), material = M.LeafyGrass, hardness = 0.2, see = true, drop = "apple", dropChance = 0.03 },
	oak_planks = { label = "Oak Planks", color = rgb(184, 142, 92), material = M.WoodPlanks, hardness = 2, tool = "axe", fuel = true },
	crafting_table = { label = "Crafting Table", color = rgb(150, 104, 60), material = M.WoodPlanks, hardness = 2.5, tool = "axe", station = "table" },
	furnace = { label = "Furnace", color = rgb(96, 96, 98), material = M.Concrete, hardness = 3.5, tool = "pickaxe", tier = 1, station = "furnace" },
	coal_ore = { label = "Coal Ore", color = rgb(68, 68, 70), material = M.Slate, hardness = 3, tool = "pickaxe", tier = 1, drop = "coal" },
	iron_ore = { label = "Iron Ore", color = rgb(196, 158, 128), material = M.Slate, hardness = 3, tool = "pickaxe", tier = 2 },
	gold_ore = { label = "Gold Ore", color = rgb(232, 200, 88), material = M.Slate, hardness = 3, tool = "pickaxe", tier = 3 },
	redstone_ore = { label = "Redstone Ore", color = rgb(176, 40, 40), material = M.Slate, hardness = 3, tool = "pickaxe", tier = 3, drop = "redstone", dropCount = { 4, 5 } },
	lapis_ore = { label = "Lapis Lazuli Ore", color = rgb(40, 70, 176), material = M.Slate, hardness = 3, tool = "pickaxe", tier = 2, drop = "lapis_lazuli", dropCount = { 4, 8 } },
	diamond_ore = { label = "Diamond Ore", color = rgb(92, 220, 220), material = M.Slate, hardness = 3, tool = "pickaxe", tier = 3, drop = "diamond" },
	obsidian = { label = "Obsidian", color = rgb(30, 20, 46), material = M.Glass, hardness = 50, tool = "pickaxe", tier = 4 },
	glass = { label = "Glass", color = rgb(200, 232, 255), material = M.Glass, hardness = 0.3, see = true, transparency = 0.6, drop = false },
	stone_bricks = { label = "Stone Bricks", color = rgb(118, 118, 118), material = M.Brick, hardness = 1.5, tool = "pickaxe", tier = 1 },
	bricks = { label = "Bricks", color = rgb(150, 74, 60), material = M.Brick, hardness = 2, tool = "pickaxe", tier = 1 },
	torch = { label = "Torch", color = rgb(255, 196, 90), material = M.SmoothPlastic, hardness = 0, solid = false, see = true, shape = "torch", light = 1 },
	water = { label = "Water", color = rgb(48, 96, 214), material = M.Glass, hardness = -1, solid = false, see = true, liquid = true, transparency = 0.45, drop = false },
	lava = { label = "Lava", color = rgb(255, 110, 20), material = M.SmoothPlastic, hardness = -1, solid = false, see = true, liquid = true, light = 0.8, damage = 4, drop = false },
	nether_portal_x = { label = "Nether Portal", color = rgb(140, 60, 230), material = M.SmoothPlastic, hardness = -1, solid = false, see = true, transparency = 0.35, portal = "x", light = 0.6, drop = false },
	nether_portal_z = { label = "Nether Portal", color = rgb(140, 60, 230), material = M.SmoothPlastic, hardness = -1, solid = false, see = true, transparency = 0.35, portal = "z", light = 0.6, drop = false },
	-- Незер (обновление 1.16)
	netherrack = { label = "Netherrack", color = rgb(112, 40, 40), material = M.Cobblestone, hardness = 0.4, tool = "pickaxe", tier = 1 },
	nether_gold_ore = { label = "Nether Gold Ore", color = rgb(168, 92, 52), material = M.Cobblestone, hardness = 3, tool = "pickaxe", tier = 1, drop = "gold_nugget", dropCount = { 2, 6 } },
	nether_quartz_ore = { label = "Nether Quartz Ore", color = rgb(196, 168, 160), material = M.Cobblestone, hardness = 3, tool = "pickaxe", tier = 1, drop = "quartz" },
	ancient_debris = { label = "Ancient Debris", color = rgb(96, 70, 62), material = M.CorrodedMetal, hardness = 30, tool = "pickaxe", tier = 4 },
	soul_sand = { label = "Soul Sand", color = rgb(88, 68, 54), material = M.Sand, hardness = 0.5, tool = "shovel", slow = true },
	soul_soil = { label = "Soul Soil", color = rgb(76, 58, 46), material = M.Ground, hardness = 0.5, tool = "shovel" },
	basalt = { label = "Basalt", color = rgb(74, 74, 80), material = M.Basalt, hardness = 1.25, tool = "pickaxe", tier = 1 },
	blackstone = { label = "Blackstone", color = rgb(40, 36, 44), material = M.Slate, hardness = 1.5, tool = "pickaxe", tier = 1 },
	glowstone = { label = "Glowstone", color = rgb(255, 216, 128), material = M.SmoothPlastic, hardness = 0.3, light = 1 },
	shroomlight = { label = "Shroomlight", color = rgb(255, 168, 76), material = M.SmoothPlastic, hardness = 1, tool = "axe", light = 1 },
	magma_block = { label = "Magma Block", color = rgb(150, 54, 22), material = M.CrackedLava, hardness = 0.5, tool = "pickaxe", tier = 1, hurts = 1, light = 0.3 },
	crimson_nylium = { label = "Crimson Nylium", color = rgb(150, 28, 40), material = M.Grass, hardness = 0.4, tool = "pickaxe", tier = 1, drop = "netherrack" },
	warped_nylium = { label = "Warped Nylium", color = rgb(36, 128, 116), material = M.Grass, hardness = 0.4, tool = "pickaxe", tier = 1, drop = "netherrack" },
	crimson_stem = { label = "Crimson Stem", color = rgb(118, 40, 62), material = M.Wood, hardness = 2, tool = "axe" },
	warped_stem = { label = "Warped Stem", color = rgb(52, 98, 108), material = M.Wood, hardness = 2, tool = "axe" },
	crimson_planks = { label = "Crimson Planks", color = rgb(110, 50, 76), material = M.WoodPlanks, hardness = 2, tool = "axe" },
	warped_planks = { label = "Warped Planks", color = rgb(44, 112, 106), material = M.WoodPlanks, hardness = 2, tool = "axe" },
	nether_wart_block = { label = "Nether Wart Block", color = rgb(136, 18, 20), material = M.Fabric, hardness = 1 },
	warped_wart_block = { label = "Warped Wart Block", color = rgb(22, 128, 130), material = M.Fabric, hardness = 1 },
	nether_bricks = { label = "Nether Bricks", color = rgb(54, 26, 32), material = M.Brick, hardness = 2, tool = "pickaxe", tier = 1 },
	netherite_block = { label = "Block of Netherite", color = rgb(66, 60, 64), material = M.DiamondPlate, hardness = 50, tool = "pickaxe", tier = 4 },
	diamond_block = { label = "Block of Diamond", color = rgb(110, 230, 226), material = M.DiamondPlate, hardness = 5, tool = "pickaxe", tier = 3 },
	gold_block = { label = "Block of Gold", color = rgb(246, 210, 70), material = M.Foil, hardness = 3, tool = "pickaxe", tier = 3 },
	iron_block = { label = "Block of Iron", color = rgb(220, 220, 224), material = M.Metal, hardness = 5, tool = "pickaxe", tier = 2 },
}

-- Предметы (не блоки). icon — значок в слоте, food — сколько голода восстанавливает.
Content.ITEMS = {
	stick = { label = "Stick", icon = "╱", color = rgb(150, 110, 60), fuel = true },
	coal = { label = "Coal", icon = "●", color = rgb(40, 40, 44), fuel = true },
	iron_ingot = { label = "Iron Ingot", icon = "▬", color = rgb(226, 226, 230) },
	gold_ingot = { label = "Gold Ingot", icon = "▬", color = rgb(250, 210, 70) },
	gold_nugget = { label = "Gold Nugget", icon = "•", color = rgb(250, 210, 70) },
	diamond = { label = "Diamond", icon = "◆", color = rgb(100, 236, 230) },
	redstone = { label = "Redstone Dust", icon = "✦", color = rgb(220, 30, 30) },
	lapis_lazuli = { label = "Lapis Lazuli", icon = "◆", color = rgb(40, 80, 200) },
	quartz = { label = "Nether Quartz", icon = "◆", color = rgb(236, 226, 220) },
	flint = { label = "Flint", icon = "▲", color = rgb(60, 60, 64) },
	netherite_scrap = { label = "Netherite Scrap", icon = "▰", color = rgb(110, 86, 78) },
	netherite_ingot = { label = "Netherite Ingot", icon = "▬", color = rgb(70, 62, 66) },
	gunpowder = { label = "Gunpowder", icon = "∴", color = rgb(120, 120, 120) },
	rotten_flesh = { label = "Rotten Flesh", icon = "🥩", color = rgb(150, 90, 60), food = 4 },
	apple = { label = "Apple", icon = "🍎", color = rgb(220, 40, 40), food = 4 },
	golden_apple = { label = "Golden Apple", icon = "🍏", color = rgb(250, 210, 70), food = 4, heal = 8 },
	porkchop = { label = "Raw Porkchop", icon = "🥩", color = rgb(240, 150, 150), food = 3 },
	cooked_porkchop = { label = "Cooked Porkchop", icon = "🍖", color = rgb(200, 120, 70), food = 8 },
	string = { label = "String", icon = "〰", color = rgb(240, 240, 240) },
	flint_and_steel = { label = "Flint and Steel", icon = "🔥", color = rgb(160, 160, 160), stack = 1, durability = 64 },
}

-- Инструменты: материал × вид. tier — что можно добыть, speed — множитель скорости, damage — урон (меч).
local MATERIALS = {
	{ id = "wooden", label = "Wooden", tier = 1, speed = 2, durability = 59, color = rgb(184, 142, 92), mat = "planks" },
	{ id = "stone", label = "Stone", tier = 2, speed = 4, durability = 131, color = rgb(128, 128, 128), mat = "cobblestone" },
	{ id = "iron", label = "Iron", tier = 3, speed = 6, durability = 250, color = rgb(226, 226, 230), mat = "iron_ingot" },
	{ id = "golden", label = "Golden", tier = 1, speed = 12, durability = 32, color = rgb(250, 210, 70), mat = "gold_ingot" },
	{ id = "diamond", label = "Diamond", tier = 4, speed = 8, durability = 1561, color = rgb(100, 236, 230), mat = "diamond" },
	{ id = "netherite", label = "Netherite", tier = 4, speed = 9, durability = 2031, color = rgb(80, 70, 74) },
}
local KINDS = {
	{ id = "pickaxe", label = "Pickaxe", icon = "⛏", heads = 3, damage = 1 },
	{ id = "axe", label = "Axe", icon = "🪓", heads = 3, damage = 3 },
	{ id = "shovel", label = "Shovel", icon = "╿", heads = 1, damage = 0.5 },
	{ id = "sword", label = "Sword", icon = "🗡", heads = 2, damage = 3 },
}
local SWORD_DAMAGE = { wooden = 4, stone = 5, iron = 6, golden = 4, diamond = 7, netherite = 8 }

Content.RECIPES = {}
local function recipe(output, count, inputs, station)
	table.insert(Content.RECIPES, { output = output, count = count, inputs = inputs, station = station })
end

for i, m in MATERIALS do
	for _, k in KINDS do
		local id = m.id .. "_" .. k.id
		local damage = k.id == "sword" and SWORD_DAMAGE[m.id] or (k.damage + i * 0.5)
		Content.ITEMS[id] = {
			label = m.label .. " " .. k.label, icon = k.icon, color = m.color, stack = 1,
			tool = { kind = k.id, tier = m.tier, speed = m.speed, damage = damage }, durability = m.durability,
		}
		if m.mat then
			recipe(id, 1, { [m.mat] = k.heads, stick = k.id == "sword" and 1 or 2 }, "table")
		else
			-- незерит в 1.16 — улучшение алмазного инструмента слитком незерита
			recipe(id, 1, { ["diamond_" .. k.id] = 1, netherite_ingot = 1 }, "table")
		end
	end
end

-- Метки: любой из перечисленных предметов подходит в рецепт
Content.TAGS = {
	planks = { "oak_planks", "crimson_planks", "warped_planks" },
	fuel = { "coal", "oak_log", "birch_log", "oak_planks", "stick" },
}

recipe("oak_planks", 4, { oak_log = 1 })
recipe("oak_planks", 4, { birch_log = 1 })
recipe("crimson_planks", 4, { crimson_stem = 1 })
recipe("warped_planks", 4, { warped_stem = 1 })
recipe("stick", 4, { planks = 2 })
recipe("crafting_table", 1, { planks = 4 })
recipe("torch", 4, { coal = 1, stick = 1 })
recipe("furnace", 1, { cobblestone = 8 }, "table")
recipe("stone_bricks", 4, { stone = 4 })
recipe("sandstone", 1, { sand = 4 })
recipe("flint_and_steel", 1, { iron_ingot = 1, flint = 1 })
recipe("golden_apple", 1, { apple = 1, gold_ingot = 8 }, "table")
recipe("gold_ingot", 1, { gold_nugget = 9 }, "table")
recipe("netherite_ingot", 1, { netherite_scrap = 4, gold_ingot = 4 }, "table")
recipe("iron_block", 1, { iron_ingot = 9 }, "table")
recipe("gold_block", 1, { gold_ingot = 9 }, "table")
recipe("diamond_block", 1, { diamond = 9 }, "table")
recipe("netherite_block", 1, { netherite_ingot = 9 }, "table")
-- печь: сырьё + 1 топливо
recipe("iron_ingot", 1, { iron_ore = 1, fuel = 1 }, "furnace")
recipe("gold_ingot", 1, { gold_ore = 1, fuel = 1 }, "furnace")
recipe("glass", 1, { sand = 1, fuel = 1 }, "furnace")
recipe("stone", 1, { cobblestone = 1, fuel = 1 }, "furnace")
recipe("cooked_porkchop", 1, { porkchop = 1, fuel = 1 }, "furnace")
recipe("netherite_scrap", 1, { ancient_debris = 1, fuel = 1 }, "furnace")
recipe("nether_bricks", 1, { netherrack = 4, fuel = 1 }, "furnace")
recipe("bricks", 1, { gravel = 2, sand = 2 }, "table")

-- Бартер пиглинов (1.16): за слиток золота случайный предмет
Content.BARTER = {
	{ "obsidian", 1, 1 }, { "flint", 2, 4 }, { "gravel", 8, 12 }, { "quartz", 4, 8 },
	{ "soul_sand", 2, 6 }, { "string", 3, 8 }, { "blackstone", 8, 12 }, { "iron_ingot", 1, 2 },
}

-- Общие сведения о предмете: блок или обычный предмет
function Content.Info(name)
	local item = Content.ITEMS[name]
	if item then
		return item
	end
	local block = Content.BLOCKS[name]
	if block then
		return { label = block.label, color = block.color, block = true, fuel = block.fuel, stack = 64 }
	end
	return nil
end

function Content.StackSize(name)
	local info = Content.Info(name)
	return info and info.stack or 64
end

-- Блоки творческого режима
Content.CREATIVE = {
	"grass_block", "dirt", "stone", "cobblestone", "oak_log", "oak_planks", "birch_log", "oak_leaves", "glass", "sand", "sandstone",
	"gravel", "stone_bricks", "bricks", "snow_block", "ice", "torch", "crafting_table", "furnace", "obsidian", "coal_ore", "iron_ore",
	"gold_ore", "diamond_ore", "iron_block", "gold_block", "diamond_block", "netherrack", "nether_bricks", "crimson_planks",
	"warped_planks", "crimson_stem", "warped_stem", "nether_wart_block", "warped_wart_block", "glowstone", "shroomlight", "basalt",
	"blackstone", "soul_sand", "magma_block", "ancient_debris", "netherite_block", "flint_and_steel", "diamond_sword", "netherite_pickaxe",
}

return Content
