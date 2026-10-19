-- Дымовой тест всей системы без Roblox Studio: tools/README.md
local ROOT = ARGS[3] or "."
local M = compile(readfile(ROOT .. "/tools/mock/roblox.lua"), "roblox.lua", _G)()
local RepS = M.game:GetService("ReplicatedStorage")
M.mount(ROOT .. "/src/shared/PS5", RepS, "PS5")
M.mount(ROOT .. "/src/apps", RepS, "PS5Apps")
M.newInstance("Folder", "PS5Assets").Parent = RepS
local srv = M.mount(ROOT .. "/src/server", M.game:GetService("ServerScriptService"), "srv")
local cli = M.mount(ROOT .. "/src/client", M.game:GetService("ServerScriptService"), "cli")

local function check(cond, msg) if not cond then print("FAIL: " .. msg) table.insert(M.errors, msg) else print("ok: " .. msg) end end

local main = coroutine.create(function()
	M.run(srv.PS5Server)
	M.run(srv.ChillZone)
	local zones = M.workspace:FindFirstChild("ChillZones")
	local myZone = zones and zones:FindFirstChild("Zone_42")
	check(myZone ~= nil and myZone:GetAttribute("OwnerId") == 42, "player gets own chill zone")
	-- клиент собирает большую модель Blender с паузами между деталями
	M.task.spawn(M.run, cli.PS5Client)
	M.advance(3)
	local PS5 = RepS.PS5
	local Shell = M.require(PS5.UI)
	local Nav = M.require(PS5.Nav)
	local Runtime = M.require(PS5.Runtime)
	local Data = M.require(PS5.Data)
	local Registry = M.require(PS5.Registry)

	check(#Registry.List() == 1, "registry has 1 visible app (template hidden)")
	Registry.Uninstall("star_pilot")
	check(#Registry.List() == 0 and table.find(Registry.All(), Registry.Get("star_pilot")) ~= nil and not Registry.IsInstalled("star_pilot"), "deleted game leaves the library but stays in the store")
	Registry.Install("star_pilot")
	check(#Registry.List() == 1 and Registry.IsInstalled("star_pilot"), "download from store installs the game again")
	check(M.editable.meshes == 14, "console+controller and Creator Store sofa meshes built: " .. M.editable.meshes)
	check(myZone:FindFirstChild("Sofa") and not myZone:FindFirstChild("SofaFallback"), "store sofa replaced the Blender fallback")
	local scenery = myZone:FindFirstChild("Scenery")
	check(scenery ~= nil and #scenery:GetChildren() > 900, "Blender scenery built from parts: " .. (scenery and #scenery:GetChildren() or 0))
	local solid = 0
	for _, p in scenery:GetChildren() do
		if p.CanCollide then
			solid += 1
		end
	end
	check(solid > 150, "Blender parts marked solid collide: " .. solid)
	local zoneParts = myZone
	check(zoneParts:FindFirstChild("TVScreen") and zoneParts:FindFirstChild("GameSlot")
		and zoneParts:FindFirstChild("Spawn"), "Blender markers, signs and spawn placed")
	check(zoneParts.ConsoleSpot.Transparency == 1 and not zoneParts.ConsoleSpot.CanCollide, "markers hidden")
	check(M.editable.images >= 1, "embedded background image built: " .. M.editable.images)
	local zone = myZone
	check(Shell.state == "standby" and not Shell.systemGui.Enabled, "PS5 waits in standby while player walks")
	local promptObj = zone.ConsoleSpot:FindFirstChildOfClass("ProximityPrompt")
	check(promptObj ~= nil, "console has proximity prompt")
	local col = zone:FindFirstChild("MyCollection")
	check(col ~= nil, "collection folder built in house")
	-- уровни чиллзоны: детали выше уровня игрока спрятаны, повышение их показывает
	local function countTier(level)
		local n = 0
		for _, p in zone:GetDescendants() do
			if p:GetAttribute("Tier") == level then n += 1 end
		end
		return n
	end
	check(M.player:GetAttribute("PS5Tier") == 1 and countTier(3) == 0 and countTier(6) == 0, "upgrade parts hidden at level 1")
	M.player:SetAttribute("PS5Tier", 3); M.advance(0.2)
	check(countTier(2) > 0 and countTier(3) > 0 and countTier(4) == 0 and zone:GetAttribute("Tier") == 3, "level 3 reveals garden: " .. countTier(3))
	M.player:SetAttribute("PS5Tier", 1); M.advance(0.2)
	check(countTier(2) == 0, "level drop hides upgrades again")
	local PS5r = RepS.PS5Remotes
	local pub = PS5r.GetPublicProfile:InvokeServer(42)
	check(pub and pub.points == 40 and pub.gamesOwned == 1 and pub.tier == 1, "public profile: points from installed games: " .. tostring(pub and pub.points))
	local Profiles = M.require(RepS.PS5.Profiles)
	check(Profiles.Open(42) ~= nil, "profile window opens")
	Profiles.Close()
	PS5r.VisitZone:FireServer(42)
	check(M.player:GetAttribute("VisitingZone") == nil, "visiting own zone means home")
	-- чужая чиллзона: витрина строится из публичного профиля хозяина
	local guest = myZone:Clone()
	guest.Name = "Zone_99"
	guest.Parent = zones
	zones.ChildAdded:Fire(guest)
	M.advance(2)
	check(guest:FindFirstChild("Collection") ~= nil and #guest.Collection:GetChildren() > 0, "guest zone shows the owner's collection")
	guest:Destroy()
	promptObj.Triggered:Fire(M.player); M.advance(2)
	check(Shell.systemGui.Enabled, "prompt powers on PS5 UI")
	M.advance(10)
	check(Shell.Current() == "boot", "boot screen")
	M.tap("Return"); M.advance(1)
	check(Shell.Current() == "users", "users screen")
	M.tap("Return"); M.advance(1)
	check(Shell.Current() == "home", "home screen")
	local SoundService = M.game:GetService("SoundService")
	check(SoundService:FindFirstChild("MenuMusic") and SoundService.MenuMusic.IsPlaying, "menu music plays on home")
	check(zone:FindFirstChild("Ambience_campfire", true) and SoundService:FindFirstChild("Ambience_night"), "world ambience placed")
	local f = Nav.Focused()
	check(f and f.Name == "star_pilot", "home focuses Star Pilot: " .. tostring(f))
	M.tap("Return"); M.advance(1)
	local cur, state = Runtime.Current()
	check(cur and cur.id == "star_pilot" and state == "running", "game running")
	check(not Shell.systemGui.Enabled, "system gui hidden in game")
	M.advance(1)
	check(not SoundService.MenuMusic.IsPlaying, "menu music stops in game")
	M.key("Space", true); M.advance(3); M.key("Space", false); M.advance(0.2)
	M.tap("H"); M.advance(0.5)
	cur, state = Runtime.Current()
	check(state == "paused" and Shell.ControlCenter.IsOpen(), "PS opens control center & pauses")
	M.tap("Backspace"); M.advance(0.5)
	cur, state = Runtime.Current()
	check(state == "running" and not Shell.ControlCenter.IsOpen(), "circle resumes game")
	-- после системной паузы игра показывает своё меню паузы
	M.tap("Down"); M.tap("Down"); M.tap("Return"); M.advance(0.5)
	check(Runtime.Current() == nil and Shell.Current() == "home", "exit from game menu returns home")
	check(Shell.systemGui.Enabled, "system gui visible again")

	-- трофей и сохранение
	local man = Registry.Get("star_pilot")
	local Trophies = M.require(PS5.Trophies)
	Trophies.Unlock(man, "first_blood")
	check(Trophies.IsUnlocked(man, "first_blood"), "trophy unlock")
	M.advance(1)

	-- экраны
	for _, name in ipairs({ "library", "store", "trophies", "settings" }) do
		Shell.Go(name); M.advance(0.5)
		check(Shell.Current() == name and Nav.Focused() ~= nil, name .. " opens with focus")
		M.tap("Down"); M.tap("Right"); M.advance(0.3)
		M.tap("Backspace"); M.advance(0.5)
		check(Shell.Current() == "home", "back from " .. name)
	end
	-- настройки: строки
	Shell.Go("settings", { category = "sound" }); M.advance(0.3)
	M.tap("Return"); M.advance(0.2) -- в первую строку
	M.tap("Left"); M.advance(0.2)
	check(math.abs(Data.Setting("volume") - 0.6) < 0.001, "volume slider left: " .. tostring(Data.Setting("volume")))
	for _, cat in ipairs({ "users", "display", "storage", "system", "dev" }) do
		Shell.Go("settings", { category = cat }); M.advance(0.3)
	end
	Shell.Go("home"); M.advance(0.3)
	-- меню приложения
	local AppMenu = M.require(PS5.UI.AppMenu)
	AppMenu(Shell, man); M.advance(0.3)
	M.tap("Down"); M.tap("Return"); M.advance(0.5) -- Информация
	M.tap("Backspace"); M.advance(0.3)
	check(Nav.Depth() == 1, "modals closed")
	-- CC на главном экране и питание
	M.tap("H"); M.advance(0.5)
	check(Shell.ControlCenter.IsOpen(), "control center on home")
	M.tap("H"); M.advance(0.5)
	Shell.Power("sleep"); M.advance(1)
	M.tap("Return"); M.advance(1)
	check(Shell.state == "ui", "wake from sleep")
	Shell.Power("off"); M.advance(1)
	check(Shell.state == "standby" and not Shell.systemGui.Enabled, "power off returns player to world")
	local names = {} for _, c in ipairs(zone.MyCollection:GetChildren()) do table.insert(names, c.Name) end
	print("collection:", table.concat(names, ", "))
	check(zone.MyCollection:FindFirstChild("first_blood") and zone.MyCollection:FindFirstChild("star_pilot"), "house shows unlocked trophy and played game")
	promptObj.Triggered:Fire(M.player); M.advance(2)
	check(Shell.Current() == "boot", "power on again goes to boot")
	-- шаблон напрямую
	local tmplModule = RepS.PS5Apps._Template
	local tmpl = M.require(tmplModule.manifest)
	check(tmpl.hidden == true, "template hidden")
	tmpl.hidden = false
	Registry.Load()
	Registry.Install("my_game")
	M.tap("Return"); M.advance(1); M.tap("Return"); M.advance(1)
	Shell.Launch("my_game"); M.advance(1)
	M.tap("Return"); M.advance(0.5)
	check(Data.AppSaves("my_game").count == 1, "template counter saved")
	M.tap("Backspace"); M.advance(0.5)
	check(Runtime.Current() == nil, "template exits on circle")
	Shell.Launch("star_pilot"); M.advance(1)
	M.key("Space", true); M.advance(120); M.key("Space", false)
	M.tap("Return"); M.advance(5)
	cur = Runtime.Current()
	check(cur and cur.id == "star_pilot", "star pilot long run")
	print("saves:", Data.AppSaves("star_pilot").best, Data.AppSaves("star_pilot").games)
	Shell.Launch("my_game"); M.advance(0.5)
	check(Shell.Modal ~= nil and Nav.Depth() >= 1, "switching game asks confirmation")
	-- данные доехали до «сервера»
	M.advance(65)
	local saved = M.stored["player_42"]
	check(saved and saved.data and saved.data.u1 and saved.data.u1.trophies.star_pilot.first_blood, "autosave to DataStore")
	check(M.editable.images >= 4, "background, banner, covers and game art built: " .. M.editable.images)
	-- простые классические игры: запуск, немного ввода, выход без ошибок
	for _, id in { "snake", "pong", "game_2048", "sky_hop", "brick_break", "blockcraft" } do
		Runtime.Close(); M.advance(0.5)
		Registry.Install(id)
		local okLaunch = Runtime.Launch(id)
		M.advance(0.5)
		for _, k in { "Return", "Up", "Right", "Down", "Left", "Return" } do
			M.tap(k); M.advance(0.4)
		end
		M.key("Right", true); M.advance(2); M.key("Right", false)
		M.advance(4)
		local cur = Runtime.Current()
		check(okLaunch and cur and cur.id == id, "classic game runs: " .. id)
	end
	local BC = M.require(RepS.PS5Apps.BlockCraft)
	local BCContent = M.require(RepS.PS5Apps.BlockCraft.Content)
	local G = BC.debug
	-- главное меню как в Minecraft: Singleplayer -> Create New World
	if G and G.state ~= "play" then
		check(G.screens.current() ~= nil, "blockcraft shows a menu screen: " .. tostring(G.screens.current()))
		G.screens.open("title")
		check(G.screens.debug.activate("Singleplayer") and G.screens.current() == "worlds", "blockcraft title -> select world")
		check(G.screens.debug.activate("Create New World") and G.screens.current() == "create", "blockcraft select world -> create")
		G.screens.debug.activate("Create New World")
		M.advance(0.5)
	end
	check(G and G.state == "play", "blockcraft world started from title: " .. tostring(G and G.state))
	M.advance(3)
	local world = M.workspace:FindFirstChild("PS5App_blockcraft")
	check(world and #world:GetDescendants() > 500, "blockcraft chunks built: " .. (world and #world:GetDescendants() or 0))
	local decals = 0
	for _, d in world:GetDescendants() do
		if d.ClassName == "Decal" then decals += 1 end
	end
	check(decals > 1000, "blockcraft pixel textures on faces: " .. decals)
	if G and G.give then
		G.give("oak_log", 4)
		local recipe
		for _, r in BCContent.RECIPES do
			if r.inputs.oak_log and not r.station then recipe = r break end
		end
		check(recipe and G.craft(recipe), "blockcraft crafts planks")
		-- крафт по сетке 2×2: бревно в клетку, забрать доски из выхода
		local scr = G.screens
		scr.open("inventory")
		local logSlot, gridSlot, outSlot
		for i, w in scr.debug.slots() do
			local st = w.get()
			if not logSlot and st and st.n == "oak_log" and not w.grid then logSlot = i end
			if not gridSlot and w.grid then gridSlot = i end
			if w.kind == "output" then outSlot = i end
		end
		check(logSlot and gridSlot and outSlot, "blockcraft inventory has 2x2 grid")
		if logSlot and gridSlot and outSlot then
			scr.debug.click(logSlot, 2) -- правый клик: половина стопки
			scr.debug.click(gridSlot, 1)
			scr.debug.click(outSlot, 1)
			local c = scr.debug.cursor()
			check(c and c.n == "oak_planks" and c.c == 4, "blockcraft grid crafting gives planks: " .. tostring(c and c.n))
		end
		scr.close()
		local planks = 0
		for i = 1, 36 do if G.inv[i] and G.inv[i].n == "oak_planks" then planks += G.inv[i].c end end
		check(planks >= 8 and scr.debug.cursor() == nil, "blockcraft closing inventory returns items: " .. planks)
		-- верстак 3×3, печь и творческий режим открываются без ошибок
		scr.open("table"); M.advance(0.2); scr.close()
		local f = scr.furnaceState("0,0,0")
		f.input = { n = "iron_ore", c = 1 }; f.fuel = { n = "coal", c = 1 }
		scr.open("furnace", { key = "0,0,0" }); M.advance(0.2)
		scr.tickFurnaces(11)
		check(f.output and f.output.n == "iron_ingot", "blockcraft furnace smelts iron")
		scr.close()
		scr.open("creative"); M.advance(0.2); scr.close()
		for _, name in { "pause", "options", "statistics", "advancements" } do
			scr.open(name, { back = "pause" }); M.advance(0.1)
		end
		scr.close()
		G.damage(3)
		M.advance(0.5)
		G.travel(); M.advance(3)
		check(G.dim == "nether" and G.state == "play", "blockcraft enters the nether: " .. tostring(G.dim))
		G.travel(); M.advance(3)
		check(G.dim == "overworld", "blockcraft returns from the nether")
	end
	M.tap("F"); M.advance(0.2); M.key("MouseButton1", true); M.advance(2); M.key("MouseButton1", false)
	Runtime.Close(); M.advance(0.5)
	local bcSaves = Data.AppSaves("blockcraft")
	check(type(bcSaves.worlds) == "table" and #bcSaves.worlds >= 1 and type(bcSaves.world_1) == "table", "blockcraft saves world")
	print(("warnings=%d errors=%d"):format(#M.warnings, #M.errors))
end)
local ok, err = coroutine.resume(main)
if not ok then print("FATAL", debug.traceback(main, err)) end
