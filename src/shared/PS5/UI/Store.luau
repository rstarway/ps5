-- PlayStation Store: бесплатные игры песочницы. Игру скачивают кнопкой Download (полоса загрузки),
-- после этого она появляется на главном экране и в библиотеке (Registry.Install).
-- Игры, которые ещё делаются в отдельных потоках проекта, показаны как «Coming soon»: когда в src/apps
-- появляется приложение с тем же id, карточка сама становится доступной для скачивания (план — в THREADS.md).
local PS5 = script.Parent.Parent
local Util = require(PS5.Util)
local Theme = require(PS5.Theme)
local Nav = require(PS5.Nav)
local Registry = require(PS5.Registry)
local Embedded = require(PS5.Embedded)
local Audio = require(PS5.Audio)
local C = require(script.Parent.Components)

-- Бесплатные игры, которые делаются в своих потоках (id совпадает с папкой игры в src/apps)
local FREE_GAMES = {
	{ id = "neon_drive", title = "Neon Drive", genre = "Racing", icon = "🏎", colors = { "#FF3D7F", "#3A0CA3" },
		description = "Night racing through a neon city: drift, boost and beat the clock." },
	{ id = "rocket_ball", title = "Rocket Ball", genre = "Sports", icon = "⚽", colors = { "#00B4D8", "#03045E" },
		description = "Car football: jump, boost and smash the giant ball into the goal." },
	{ id = "pixel_quest", title = "Pixel Quest", genre = "Platformer", icon = "🍄", colors = { "#43AA8B", "#0B3D2E" },
		description = "A cosy pixel platformer with coins, secrets and a boss at the end." },
	{ id = "orbit_strike", title = "Orbit Strike", genre = "Shooter", icon = "🛰", colors = { "#F8961E", "#5A1F00" },
		description = "Defend the space station from waves of drones in this twin-stick shooter." },
	{ id = "cube_logic", title = "Cube Logic", genre = "Puzzle", icon = "🧩", colors = { "#4CC9F0", "#14213D" },
		description = "Roll the cube onto the exit in short brain teasers." },
	{ id = "beat_rush", title = "Beat Rush", genre = "Rhythm", icon = "🎧", colors = { "#B5179E", "#240046" },
		description = "Hit the notes to the beat and chase the perfect combo." },
}
-- Будущие игры: ряд «Coming Soon». Когда игра появится в src/apps с тем же id, она переедет в «Free to Play».
local COMING_SOON = {
	{ id = "kart_rush", title = "Kart Rush", genre = "Racing", icon = "🏁", colors = { "#FFD60A", "#3A2E00" },
		description = "Party kart racing with items, shortcuts and drifting boosts." },
	{ id = "zombie_night", title = "Zombie Night", genre = "Survival", icon = "🧟", colors = { "#6A994E", "#1B2614" },
		description = "Board up the house and survive until sunrise." },
	{ id = "sky_royale", title = "Sky Royale", genre = "Battle Royale", icon = "🪂", colors = { "#4895EF", "#10002B" },
		description = "Drop from the sky, loot fast and be the last one standing." },
	{ id = "dungeon_delve", title = "Dungeon Delve", genre = "RPG", icon = "🗡", colors = { "#9D4EDD", "#240046" },
		description = "Explore random dungeons, collect loot and level up your hero." },
	{ id = "street_ball", title = "Street Ball", genre = "Sports", icon = "🏀", colors = { "#F77F00", "#3D1A00" },
		description = "Fast 3-on-3 basketball on city courts." },
	{ id = "ghost_hotel", title = "Ghost Hotel", genre = "Horror", icon = "👻", colors = { "#ADB5BD", "#0B0C10" },
		description = "Find a way out of a haunted hotel before the lights go out." },
	{ id = "ninja_run", title = "Ninja Run", genre = "Action", icon = "🥷", colors = { "#EF233C", "#2B0A0F" },
		description = "Wall-run, dash and slice through rooftops at full speed." },
	{ id = "farm_life", title = "Farm Life", genre = "Simulation", icon = "🌾", colors = { "#B5E48C", "#1E3A0F" },
		description = "Grow crops, raise animals and build the cosiest farm in town." },
}
local APPS = {
	{ id = "music", title = "Music", genre = "Media", icon = "🎵", colors = { "#1DB954", "#062B14" }, category = "media" },
	{ id = "video", title = "Video", genre = "Media", icon = "▶", colors = { "#E63946", "#3B0A0F" }, category = "media" },
}

local DOWNLOAD_TIME = 2.6

return function(Shell)
	local frame = Util.new("Frame", { Name = "Store", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local screen = { frame = frame }
	local layer
	local downloading = {} -- id -> 0..1
	local statusLabels = {} -- id -> TextLabel под плиткой
	local bannerLoop
	local scroll = Util.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -80),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = frame,
	})

	-- настоящее приложение песочницы или карточка будущей игры
	local function resolve(item)
		return Registry.Get(item.id) or item
	end

	local function status(manifest)
		if not manifest.module then
			return "Coming soon", Theme.Colors.SubText
		elseif downloading[manifest.id] then
			return `Downloading {math.floor(downloading[manifest.id] * 100)}%`, Theme.Colors.AccentLight
		elseif Registry.IsInstalled(manifest.id) then
			return "Installed", Theme.Colors.Success
		end
		return "Free", Theme.Colors.Text
	end

	local function refreshStatus(id)
		local label = statusLabels[id]
		local manifest = Registry.Get(id)
		if label and label.Parent and manifest then
			label.Text, label.TextColor3 = status(manifest)
		end
	end

	-- скачивание: полоса заполняется, затем игра устанавливается
	local function download(manifest, bar, onDone)
		if downloading[manifest.id] then
			return
		end
		downloading[manifest.id] = 0
		Audio.Ui("confirm")
		task.spawn(function()
			local t = 0
			while t < DOWNLOAD_TIME do
				t += task.wait(0.05)
				local k = math.min(1, t / DOWNLOAD_TIME)
				downloading[manifest.id] = k
				if bar and bar.Parent then
					bar.Fill.Size = UDim2.fromScale(k, 1)
				end
				refreshStatus(manifest.id)
			end
			downloading[manifest.id] = nil
			Registry.Install(manifest.id)
			refreshStatus(manifest.id)
			Shell.Toast("Download complete", manifest.title, { icon = "⬇" })
			if onDone then
				onDone()
			end
		end)
	end

	local function productPage(manifest)
		Shell.Modal.Open(function(panel, close)
			local cover = Util.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(220, 220), Parent = panel })
			C.Cover(manifest, cover)
			Util.text(manifest.title, { Size = UDim2.new(1, 0, 0, 40), TextSize = 34, Font = Theme.FontBold, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, Parent = panel })
			local trophies = manifest.trophies and #manifest.trophies or 0
			Util.text(`{manifest.genre or "Game"} · {manifest.developer or "PS5 Sandbox"}{trophies > 0 and ` · {trophies} trophies` or ""}`, {
				Size = UDim2.new(1, 0, 0, 24), TextSize = 19, TextColor3 = Theme.Colors.SubText, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Parent = panel,
			})
			Util.text((manifest.description or "") ~= "" and manifest.description or "Coming soon to the PS5 Sandbox.", {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = 19, LayoutOrder = 3, Parent = panel,
			})
			Util.text("Free", { Size = UDim2.new(1, 0, 0, 30), TextSize = 26, Font = Theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 4, Parent = panel })
			local actions = Util.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 5, Parent = panel })
			local bar = C.Progress(downloading[manifest.id] or 0, { size = UDim2.new(0.8, 0, 0, 8), parent = panel })
			bar.LayoutOrder = 6
			bar.Visible = downloading[manifest.id] ~= nil

			local function buttons()
				actions:ClearAllChildren()
				Util.list(Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center).Parent = actions
				if not manifest.module then
					C.Button("Add to Wishlist", { parent = actions, onActivate = function()
						close()
						Shell.Toast("Added to wishlist", manifest.title, { icon = "★" })
					end })
				elseif Registry.IsInstalled(manifest.id) then
					C.Button("Play", { variant = "primary", parent = actions, onActivate = function()
						close()
						Shell.Launch(manifest.id)
					end })
					C.Button("Delete", { parent = actions, onActivate = function()
						Registry.Uninstall(manifest.id)
						refreshStatus(manifest.id)
						Shell.Toast("Deleted", manifest.title)
						buttons()
					end })
				elseif downloading[manifest.id] then
					Util.text("Downloading…", { Size = UDim2.fromOffset(260, 56), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Parent = actions })
				else
					C.Button("Download", { variant = "primary", parent = actions, onActivate = function()
						bar.Visible = true
						download(manifest, bar, function()
							if panel.Parent then
								buttons()
							end
						end)
						buttons()
					end })
				end
			end
			buttons()
		end, { width = 640 })
	end

	local function section(title, order)
		-- плитки переносятся на следующую строку, когда игр больше, чем помещается в ширину экрана
		local holder = Util.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 340), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = scroll })
		Util.text(title, { Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(80, 0), TextSize = 28, Font = Theme.FontBold, Parent = holder })
		local rowFrame = Util.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -160, 0, 280), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromOffset(80, 50), Parent = holder }, {
			Util.new("UIGridLayout", { CellSize = UDim2.fromOffset(200, 270), CellPadding = UDim2.fromOffset(24, 24), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		return rowFrame
	end

	local function product(manifest, parent, order)
		local holder = Util.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(200, 270), LayoutOrder = order, Parent = parent })
		C.Tile(manifest, {
			size = UDim2.fromOffset(200, 200),
			parent = holder,
			onActivate = function()
				productPage(manifest)
			end,
		})
		Util.text(manifest.title, { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 212), TextSize = 19, TextTruncate = Enum.TextTruncate.AtEnd, Parent = holder })
		local label = Util.text("", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 238), TextSize = 16, Font = Theme.FontBold, Parent = holder })
		label.Text, label.TextColor3 = status(manifest)
		statusLabels[manifest.id] = label
	end

	-- большой баннер: по очереди показывает бесплатные игры
	local function banner(list)
		local holder = Util.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 380), LayoutOrder = 1, Parent = scroll })
		local button = Util.new("TextButton", {
			Text = "",
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.new(1, -160, 0, 380),
			Position = UDim2.fromOffset(80, 0),
			ClipsDescendants = true,
			Parent = holder,
		}, { Util.corner(26), Util.padding(48) })
		local gradient = Util.gradient({ Color3.new(0, 0, 0), Color3.new(0, 0, 0) }, 20)
		gradient.Parent = button
		local image = Util.new("ImageLabel", { BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, Size = UDim2.new(1, 96, 1, 96), Position = UDim2.fromOffset(-48, -48), ImageTransparency = 0.35, Parent = button }, { Util.corner(26) })
		if not Embedded.ApplyImage(image, Theme.Images.StoreBanner ~= "" and Theme.Images.StoreBanner or "StoreBanner", PS5.Assets) then
			image:Destroy()
		end
		Util.text("PlayStation Store · Free to Play", { Size = UDim2.new(1, 0, 0, 26), TextSize = 22, TextColor3 = Theme.Colors.SubText, Parent = button })
		local title = Util.text("", { Size = UDim2.new(0.6, 0, 0, 80), Position = UDim2.fromOffset(0, 40), TextSize = 72, Font = Theme.FontHeavy, Parent = button })
		local desc = Util.text("", { Size = UDim2.new(0.55, 0, 0, 80), Position = UDim2.fromOffset(0, 130), TextSize = 22, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = button })
		local tag = Util.text("", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -30), TextSize = 22, Font = Theme.FontBold, Parent = button })
		local coverHolder = Util.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(220, 220), Position = UDim2.new(1, -240, 0.5, -110), Parent = button })
		local current = 1
		local function show(i)
			current = i
			local manifest = list[i]
			local colors = Util.appColors(manifest)
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, colors[1]),
				ColorSequenceKeypoint.new(0.6, colors[2] or colors[1]),
				ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
			})
			title.Text = manifest.title
			desc.Text = manifest.description or ""
			tag.Text = `{manifest.genre or "Game"} · {(status(manifest))}`
			coverHolder:ClearAllChildren()
			C.Cover(manifest, coverHolder)
			title.TextTransparency = 1
			Util.tween(title, 0.4, { TextTransparency = 0 })
		end
		show(1)
		Nav.Register(button, { scale = 1.02, ringThickness = 4, onActivate = function()
			productPage(list[current])
		end })
		bannerLoop = task.spawn(function()
			while button.Parent do
				task.wait(6)
				if button.Parent then
					show(current % #list + 1)
				end
			end
		end)
	end

	local function build()
		scroll:ClearAllChildren()
		table.clear(statusLabels)
		Util.list(Enum.FillDirection.Vertical, 30).Parent = scroll
		Util.new("UIPadding", { PaddingTop = UDim.new(0, 40), PaddingBottom = UDim.new(0, 60), Parent = scroll })

		-- бесплатные игры: сначала готовые игры песочницы, затем те, что ещё в разработке
		local free, seen = {}, {}
		for _, manifest in Registry.All("game") do
			table.insert(free, manifest)
			seen[manifest.id] = true
		end
		for _, item in FREE_GAMES do
			if not seen[item.id] then
				table.insert(free, resolve(item))
				seen[item.id] = true
			end
		end
		banner(free)
		local row = section("Free to Play", 2)
		for i, manifest in free do
			product(manifest, row, i)
		end
		local soon = section("Coming Soon", 3)
		local n = 0
		for _, item in COMING_SOON do
			if not seen[item.id] then
				n += 1
				product(resolve(item), soon, n)
			end
		end
		local apps = section("Apps", 4)
		local i = 0
		for _, manifest in Registry.All("media") do
			i += 1
			product(manifest, apps, i)
			seen[manifest.id] = true
		end
		for _, item in APPS do
			if not seen[item.id] then
				i += 1
				product(resolve(item), apps, i)
			end
		end
	end

	function screen.Enter()
		Shell.SetHints({ { "cross", "Details" }, { "circle", "Back" } })
		build()
		layer = Nav.Push({ root = frame, name = "store", onBack = Shell.Back })
	end

	function screen.Leave()
		Nav.Pop(layer)
		if bannerLoop then
			pcall(task.cancel, bannerLoop)
			bannerLoop = nil
		end
	end

	return screen
end
