-- Главный экран в духе PS5: вкладки Games/Media, ряд маленьких плиток, выбранная плитка крупнее и с названием справа,
-- на весь экран — фон выбранной игры (art.luau из Blender) с плавной сменой, ниже название, Play и «•••», внизу карточки.
local PS5 = script.Parent.Parent
local Util = require(PS5.Util)
local Theme = require(PS5.Theme)
local Nav = require(PS5.Nav)
local Audio = require(PS5.Audio)
local Data = require(PS5.Data)
local Registry = require(PS5.Registry)
local Runtime = require(PS5.Runtime)
local Trophies = require(PS5.Trophies)
local Embedded = require(PS5.Embedded)
local C = require(script.Parent.Components)
local AppMenu = require(script.Parent.AppMenu)

local SMALL, BIG, GAP, ROW_X, ROW_Y = 118, 176, 18, 80, 112

local SYSTEM = {
	store = {
		id = "@store", title = "PlayStation Store", icon = "🛍", colors = { "#0070F0", "#00256B" },
		description = "Catalog of sandbox games and apps.", developer = "System", system = "store",
	},
	library = {
		id = "@library", title = "Game Library", icon = "▦", colors = { "#3A4466", "#151A2C" },
		description = "All installed games and apps.", developer = "System", system = "library",
	},
}

return function(Shell)
	local frame = Util.new("Frame", { Name = "Home", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local screen = { frame = frame, dirty = true }
	local layer
	local tab = "game"
	local selected = nil -- манифест выбранной плитки
	local selectedId = {}
	local tiles = {}

	-- Фон выбранной игры на весь экран: два слоя сменяют друг друга плавным наплывом
	local artRoot = Util.new("Frame", { Name = "Art", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0, Parent = frame })
	local artLayers = {}
	for i = 1, 2 do
		local layerFrame = Util.new("Frame", { Name = "Layer" .. i, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = artRoot })
		local grad = Util.new("UIGradient", { Name = "Gradient", Rotation = 30, Parent = layerFrame })
		local image = Util.new("ImageLabel", { Name = "Image", BackgroundTransparency = 1, ImageTransparency = 1, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), Parent = layerFrame })
		local zoom = Util.new("UIScale", { Scale = 1, Parent = image })
		artLayers[i] = { frame = layerFrame, gradient = grad, image = image, zoom = zoom }
	end
	-- затемнение слева и снизу, как на PS5: текст читается поверх любой картинки
	Util.new("Frame", { Name = "ShadeLeft", BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), Parent = artRoot }, {
		Util.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.55, 0.75), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	Util.new("Frame", { Name = "ShadeBottom", BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), Parent = artRoot }, {
		Util.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.6, 0.85), NumberSequenceKeypoint.new(1, 0.05) }) }),
	})
	local artFront, artKey = 1, nil

	local function showArt(manifest)
		local key = manifest and manifest.id or "none"
		if key == artKey then
			return
		end
		artKey = key
		local old = artLayers[artFront]
		artFront = 3 - artFront
		local cur = artLayers[artFront]
		local colors = Util.appColors(manifest or {})
		cur.gradient.Color = ColorSequence.new(colors[1], colors[2] or colors[1])
		local image = cur.image
		local ok = false
		if manifest then
			if manifest.system == "store" then
				ok = Embedded.ApplyImage(image, Theme.Images.StoreBanner ~= "" and Theme.Images.StoreBanner or "StoreBanner", PS5.Assets)
			elseif manifest.system == "library" then
				ok = Embedded.ApplyImage(image, Theme.Images.HomeBackground ~= "" and Theme.Images.HomeBackground or "HomeBackground", PS5.Assets)
			else
				ok = Embedded.ApplyImage(image, manifest.art, manifest.module) or Embedded.ApplyImage(image, manifest.cover, manifest.module)
			end
		end
		cur.frame.ZIndex = 2
		old.frame.ZIndex = 1
		cur.frame.BackgroundTransparency = 1
		image.ImageTransparency = 1
		local still = Data.Setting("reduceMotion")
		cur.zoom.Scale = still and 1 or 1.06
		Util.tween(cur.frame, 0.6, { BackgroundTransparency = ok and 0.6 or 0.25 })
		if ok then
			Util.tween(image, 0.6, { ImageTransparency = 0 })
			if not still then
				Util.tween(cur.zoom, 12, { Scale = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			end
		end
		Util.tween(old.frame, 0.6, { BackgroundTransparency = 1 })
		Util.tween(old.image, 0.6, { ImageTransparency = 1 })
	end

	-- Верхняя панель
	local top = Util.new("Frame", { Name = "Top", BackgroundTransparency = 1, Size = UDim2.new(1, -160, 0, 60), Position = UDim2.fromOffset(ROW_X, 30), Parent = frame })
	local tabsFrame = Util.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(400, 60), Parent = top }, { Util.list(Enum.FillDirection.Horizontal, 34) })
	local tabButtons = {}
	local right = Util.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(480, 60),
		Parent = top,
	}, { Util.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder }) })

	-- Ряд плиток: маленькие квадраты, выбранная крупнее, её название справа от неё
	local row = Util.new("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, BIG), Position = UDim2.fromOffset(0, ROW_Y), Parent = frame })
	local rowTitle = Util.text("", {
		Name = "RowTitle",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		TextSize = 30,
		Font = Theme.FontMedium,
		TextTransparency = 1,
		Parent = row,
	})

	-- Блок выбранной игры
	local hero = Util.new("Frame", { Name = "Hero", BackgroundTransparency = 1, Size = UDim2.new(1, -160, 0, 300), Position = UDim2.fromOffset(ROW_X, 470), Parent = frame })
	local heroTitle = Util.text("", { Size = UDim2.new(0.7, 0, 0, 96), TextSize = 88, Font = Theme.FontHeavy, TextTruncate = Enum.TextTruncate.AtEnd, TextStrokeTransparency = 0.75, Parent = hero })
	local heroSub = Util.text("", { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(4, 100), TextSize = 21, TextColor3 = Theme.Colors.SubText, Parent = hero })
	local actions = Util.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), Position = UDim2.fromOffset(0, 150), Parent = hero }, { Util.list(Enum.FillDirection.Horizontal, 16) })
	local playButton = C.Button("Play", {
		variant = "primary",
		size = UDim2.fromOffset(260, 62),
		order = 1,
		parent = actions,
		onActivate = function()
			screen.Open(selected)
		end,
	})
	C.Button("•••", {
		size = UDim2.fromOffset(62, 62),
		order = 2,
		parent = actions,
		onActivate = function()
			if selected and not selected.system then
				AppMenu(Shell, selected)
			end
		end,
	})
	local cards = Util.new("Frame", { Name = "Cards", BackgroundTransparency = 1, Size = UDim2.new(1, -160, 0, 190), Position = UDim2.new(0, ROW_X, 1, -250), Parent = frame }, { Util.list(Enum.FillDirection.Horizontal, 20) })

	local function tileIndex(el)
		return table.find(tiles, el)
	end

	local function updateHero(manifest)
		selected = manifest
		selectedId[tab] = manifest.id
		local running, state = Runtime.Current()
		heroTitle.Text = manifest.title
		heroTitle.TextTransparency = 1
		heroTitle.Position = UDim2.fromOffset(-24, 0)
		Util.tween(heroTitle, 0.35, { TextTransparency = 0, Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quart)
		if manifest.system then
			heroSub.Text = manifest.description
			playButton.Text = "Open"
		else
			local got, total = Trophies.Progress(manifest)
			local parts = { manifest.developer }
			if manifest.genre then
				table.insert(parts, manifest.genre)
			end
			if total > 0 then
				table.insert(parts, `🏆 {got}/{total}`)
			end
			heroSub.Text = table.concat(parts, "  ·  ")
			playButton.Text = (running and running.id == manifest.id and state == "paused") and "Resume"
				or (manifest.category == "game" and "Play" or "Open")
		end
		showArt(manifest)

		cards:ClearAllChildren()
		Util.list(Enum.FillDirection.Horizontal, 20).Parent = cards
		if manifest.system then
			C.Card({ title = "Tip", body = manifest.description, size = UDim2.fromOffset(420, 170), parent = cards })
			return
		end
		local got, total, pct = Trophies.Progress(manifest)
		local trophyCard = C.Card({
			title = "Trophies",
			body = total > 0 and `{got} of {total} · {pct}%` or "No trophies",
			size = UDim2.fromOffset(300, 170),
			order = 1,
			focusable = true,
			parent = cards,
			onActivate = function()
				Shell.Go("trophies", { app = manifest.id })
			end,
		})
		if total > 0 then
			C.Progress(got / total, { parent = trophyCard, position = UDim2.new(0, 0, 1, -10) })
		end
		C.Card({ title = "Last played", body = Util.formatTime(Data.LastPlayed(manifest.id)), size = UDim2.fromOffset(300, 170), order = 2, parent = cards })
		C.Card({ title = "About", body = manifest.description, bodySize = 18, size = UDim2.fromOffset(460, 170), order = 3, parent = cards })
	end

	-- Раскладка ряда: выбранная плитка крупнее, справа от неё название; ряд сдвигается,
	-- чтобы выбранная плитка стояла второй слева (первая видна, как на PS5)
	local function relayout(focusIndex, instant)
		local xs, x = {}, 0
		for i, tile in tiles do
			xs[i] = x
			x += (i == focusIndex and BIG or SMALL) + GAP
			if i == focusIndex then
				local tb = rowTitle.TextBounds
				local w = (tb and tb.X > 0) and tb.X or utf8.len(rowTitle.Text) * 16
				x += w + 40
			end
		end
		local slot = math.min(focusIndex - 1, 1)
		local shift = ROW_X + slot * (SMALL + GAP) - (xs[focusIndex] or 0)
		local t = instant and 0 or 0.28
		for i, tile in tiles do
			local size = i == focusIndex and BIG or SMALL
			local props = { Position = UDim2.fromOffset(xs[i] + shift, 0), Size = UDim2.fromOffset(size, size) }
			if t == 0 then
				tile.Position, tile.Size = props.Position, props.Size
			else
				Util.tween(tile, t, props, Enum.EasingStyle.Quart)
			end
		end
		if tiles[focusIndex] then
			rowTitle.Position = UDim2.fromOffset(xs[focusIndex] + shift + BIG + 26, BIG / 2 - 20)
		end
	end

	local function scrollTo(el, manifest)
		local i = tileIndex(el) or 1
		rowTitle.Text = manifest and manifest.title or ""
		rowTitle.TextTransparency = 1
		relayout(i)
		Util.tween(rowTitle, 0.3, { TextTransparency = 0 })
	end

	function screen.Open(manifest)
		if not manifest then
			return
		end
		if manifest.system == "store" then
			Shell.Go("store")
		elseif manifest.system == "library" then
			Shell.Go("library")
		else
			Shell.Launch(manifest.id)
		end
	end

	local function buildRow()
		for _, child in row:GetChildren() do
			if child ~= rowTitle then
				child:Destroy()
			end
		end
		table.clear(tiles)
		local list = {}
		if tab == "game" then
			table.insert(list, SYSTEM.store)
		end
		local apps = tab == "game" and Registry.List("game") or {}
		if tab == "media" then
			for _, a in Registry.List("media") do
				table.insert(apps, a)
			end
			for _, a in Registry.List("app") do
				table.insert(apps, a)
			end
		end
		apps = table.clone(apps)
		table.sort(apps, function(a, b)
			return (Data.LastPlayed(a.id) or 0) > (Data.LastPlayed(b.id) or 0)
		end)
		for _, a in apps do
			table.insert(list, a)
		end
		table.insert(list, SYSTEM.library)

		local running = Runtime.Current()
		local focusEl
		for i, manifest in list do
			local tile = C.Tile(manifest, {
				size = UDim2.fromOffset(SMALL, SMALL),
				position = UDim2.fromOffset(ROW_X + (i - 1) * (SMALL + GAP), 0),
				parent = row,
				scale = 1,
				onFocus = function(el)
					scrollTo(el, manifest)
					updateHero(manifest)
				end,
				onActivate = function()
					screen.Open(manifest)
				end,
				onButton = function(btn, event)
					if event == "press" and btn == "options" and not manifest.system then
						AppMenu(Shell, manifest)
						return true
					end
					return false
				end,
			})
			if running and running.id == manifest.id then
				Util.new("Frame", {
					Name = "Running",
					BackgroundColor3 = Theme.Colors.Success,
					Size = UDim2.fromOffset(14, 14),
					Position = UDim2.new(1, -24, 0, 10),
					Parent = tile,
				}, { Util.corner(UDim.new(0.5, 0)), Util.stroke(Color3.new(0, 0, 0), 2, 0.3) })
			end
			table.insert(tiles, tile)
			if manifest.id == selectedId[tab] then
				focusEl = tile
			end
		end
		if tab == "media" and #apps == 0 then
			Util.text("Media apps will show up here once they are built in their own threads.", {
				Size = UDim2.fromOffset(700, 30),
				Position = UDim2.fromOffset(ROW_X + SMALL + 40, SMALL / 2 - 15),
				TextColor3 = Theme.Colors.SubText,
				Parent = row,
			})
		end
		return focusEl or tiles[tab == "game" and math.min(2, #tiles) or 1]
	end

	local function setTab(newTab)
		if tab ~= newTab then
			Audio.Ui("tab")
		end
		tab = newTab
		for id, b in tabButtons do
			b.TextColor3 = id == tab and Theme.Colors.Text or Theme.Colors.Muted
			b.Underline.Visible = id == tab
		end
		local focusEl = buildRow()
		if layer then
			layer.focused = nil
			task.defer(function()
				Nav.Focus(focusEl, true)
			end)
		end
	end

	for i, t in { { "game", "Games" }, { "media", "Media" } } do
		local b = Util.new("TextButton", {
			Text = t[2],
			Font = Theme.FontBold,
			TextSize = 28,
			TextColor3 = Theme.Colors.Muted,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = i,
			Parent = tabsFrame,
		})
		Util.new("Frame", { Name = "Underline", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 1, -6), Visible = false, Parent = b })
		Nav.Register(b, { noRing = true, scale = 1.08, onActivate = function()
			setTab(t[1])
		end })
		tabButtons[t[1]] = b
	end

	C.IconButton("🔍", { caption = "Search", order = 1, size = 48, parent = right, onActivate = function()
		Shell.Go("library")
	end })
	C.IconButton("⚙", { caption = "Settings", order = 2, size = 48, parent = right, onActivate = function()
		Shell.Go("settings")
	end })
	local avatarButton = Util.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(48, 48), LayoutOrder = 3, Parent = right }, { Util.corner(UDim.new(0.5, 0)) })
	Nav.Register(avatarButton, { scale = 1.1, onActivate = function()
		local user = Data.CurrentUser()
		Shell.Modal.Menu(user and user.name or "Profile", {
			{ label = "Trophies", action = function() Shell.Go("trophies") end },
			{ label = "Switch User", action = function()
				Runtime.Close()
				Shell.Go("users")
			end },
			{ label = "User Settings", action = function() Shell.Go("settings", { category = "users" }) end },
		})
	end })
	local clock = Util.text("", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextSize = 24, Font = Theme.FontMedium, LayoutOrder = 4, Parent = right })

	task.spawn(function()
		while true do
			clock.Text = os.date(Data.Setting("clock24") and "%H:%M" or "%I:%M %p")
			task.wait(5)
		end
	end)

	function screen.Refresh()
		local focusEl = buildRow()
		if layer then
			layer.focused = nil
			task.defer(function()
				Nav.Focus(focusEl, true)
			end)
		end
	end

	function screen.Enter()
		Shell.SetHints({ { "cross", "Select" }, { "options", "Options" }, { "ps", "Control Center" } })
		avatarButton:ClearAllChildren()
		Util.corner(UDim.new(0.5, 0)).Parent = avatarButton
		local user = Data.CurrentUser()
		if user then
			C.Avatar(user, 48, avatarButton)
		end
		layer = { root = frame, name = "home" }
		layer.onBack = function()
			if tiles[1] then
				Nav.Focus(tiles[tab == "game" and math.min(2, #tiles) or 1])
			end
		end
		layer.onButton = function(btn, event)
			if event == "press" and (btn == "l1" or btn == "r1") then
				setTab(tab == "game" and "media" or "game")
				return true
			end
			return false
		end
		setTab(tab)
		layer.default = function()
			return tiles[table.find(tiles, row:FindFirstChild(selectedId[tab] or "")) or (tab == "game" and math.min(2, #tiles) or 1)]
		end
		Nav.Push(layer)
	end

	function screen.Leave()
		Nav.Pop(layer)
		layer = nil
		artKey = nil
	end

	return screen
end
