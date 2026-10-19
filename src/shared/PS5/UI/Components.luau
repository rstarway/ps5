-- Общие элементы интерфейса системы.
local PS5 = script.Parent.Parent
local Util = require(PS5.Util)
local Theme = require(PS5.Theme)
local Nav = require(PS5.Nav)
local Embedded = require(PS5.Embedded)

local C = {}
local new, text = Util.new, Util.text

-- Кнопка-«пилюля». variant: "primary" (белая), "secondary", "danger"
function C.Button(label, opts)
	opts = opts or {}
	local primary = opts.variant == "primary"
	local button = new("TextButton", {
		Name = opts.name or label,
		Text = label,
		Font = Theme.FontBold,
		TextSize = opts.textSize or 22,
		TextColor3 = primary and Color3.new(0, 0, 0) or Theme.Colors.Text,
		BackgroundColor3 = primary and Color3.new(1, 1, 1)
			or (opts.variant == "danger" and Theme.Colors.Danger or Theme.Colors.CardLight),
		BackgroundTransparency = primary and 0 or 0.15,
		Size = opts.size or UDim2.fromOffset(220, 56),
		LayoutOrder = opts.order or 0,
		Position = opts.position,
		Parent = opts.parent,
	}, { Util.corner(UDim.new(0.5, 0)) })
	Nav.Register(button, {
		onActivate = opts.onActivate,
		onFocus = opts.onFocus,
		onButton = opts.onButton,
		scale = opts.scale or 1.06,
	})
	return button
end

-- Круглая кнопка со значком (верхняя панель, центр управления).
function C.IconButton(glyph, opts)
	opts = opts or {}
	local size = opts.size or 52
	local button = new("TextButton", {
		Name = opts.name or glyph,
		Text = glyph,
		Font = Theme.FontBold,
		TextSize = opts.textSize or math.floor(size * 0.45),
		TextColor3 = Theme.Colors.Text,
		BackgroundColor3 = opts.color or Theme.Colors.CardLight,
		BackgroundTransparency = opts.transparency or 0.35,
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = opts.order or 0,
		Parent = opts.parent,
	}, { Util.corner(UDim.new(0.5, 0)) })
	if opts.caption then
		text(opts.caption, {
			Name = "Caption",
			Size = UDim2.new(0, 160, 0, 22),
			Position = UDim2.new(0.5, -80, 1, 8),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 16,
			TextColor3 = Theme.Colors.SubText,
			Visible = opts.alwaysCaption == true,
			Parent = button,
		})
	end
	Nav.Register(button, {
		onActivate = opts.onActivate,
		scale = 1.1,
		onFocus = function(el)
			local cap = el:FindFirstChild("Caption")
			if cap then
				cap.Visible = true
			end
			if opts.onFocus then
				opts.onFocus(el)
			end
		end,
		onBlur = function(el)
			local cap = el:FindFirstChild("Caption")
			if cap and not opts.alwaysCaption then
				cap.Visible = false
			end
		end,
	})
	return button
end

-- Обложка приложения: градиент из manifest.colors + значок или картинка cover.
function C.Cover(manifest, parent)
	local colors = Util.appColors(manifest)
	local frame = new("Frame", {
		Name = "Cover",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	}, {
		Util.corner(UDim.new(0.14, 0)),
		Util.gradient({ colors[1], colors[2] or colors[1] }, 135),
	})
	local cover = new("ImageLabel", {
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Crop,
		Size = UDim2.fromScale(1, 1),
		Parent = frame,
	}, { Util.corner(UDim.new(0.14, 0)) })
	-- cover: "rbxassetid://..." или имя модуля-картинки в папке игры (например "cover")
	if not Embedded.ApplyImage(cover, manifest.cover, manifest.module) then
		cover:Destroy()
		local icon = Util.appIcon(manifest, UDim2.fromScale(0.5, 0.5))
		icon.Position = UDim2.fromScale(0.25, 0.2)
		icon.Parent = frame
	end
	return frame
end

-- Плитка приложения для рядов и сеток.
function C.Tile(manifest, opts)
	opts = opts or {}
	local tile = new("TextButton", {
		Name = manifest.id,
		Text = "",
		BackgroundTransparency = 1,
		Size = opts.size or UDim2.fromOffset(140, 140),
		LayoutOrder = opts.order or 0,
		Position = opts.position,
		Parent = opts.parent,
	}, { Util.corner(UDim.new(0.14, 0)) })
	C.Cover(manifest, tile)
	if opts.caption then
		text(manifest.title, {
			Name = "Caption",
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.new(0, 0, 1, 8),
			TextSize = 17,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = Theme.Colors.SubText,
			Parent = tile,
		})
	end
	Nav.Register(tile, {
		onActivate = opts.onActivate,
		onFocus = opts.onFocus,
		onBlur = opts.onBlur,
		onButton = opts.onButton,
		scale = opts.scale or 1.08,
		ringThickness = 4,
	})
	return tile
end

-- Системная плитка (Магазин, Библиотека) с крупным символом.
function C.SystemTile(label, glyph, colors, opts)
	return C.Tile({ id = opts.id or label, title = label, icon = glyph, colors = colors }, opts)
end

-- Заголовок экрана.
function C.Header(title, parent)
	return text(title, {
		Name = "Header",
		Size = UDim2.new(1, -160, 0, 56),
		Position = UDim2.fromOffset(80, 44),
		TextSize = 40,
		Font = Theme.FontBold,
		Parent = parent,
	})
end

-- Карточка с текстом (главный экран, магазин).
function C.Card(opts)
	local card = new(opts.focusable and "TextButton" or "Frame", {
		Name = opts.name or "Card",
		BackgroundColor3 = Theme.Colors.Card,
		BackgroundTransparency = 0.25,
		Size = opts.size or UDim2.fromOffset(320, 180),
		Position = opts.position,
		LayoutOrder = opts.order or 0,
		Parent = opts.parent,
	}, { Util.corner(18), Util.padding(18) })
	if card:IsA("TextButton") then
		card.Text = ""
	end
	if opts.title then
		text(opts.title, { Name = "Title", Size = UDim2.new(1, 0, 0, 22), TextSize = 16, TextColor3 = Theme.Colors.SubText, Parent = card })
	end
	if opts.body then
		text(opts.body, {
			Name = "Body",
			Size = UDim2.new(1, 0, 1, -30),
			Position = UDim2.fromOffset(0, 30),
			TextSize = opts.bodySize or 22,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Font = Theme.FontMedium,
			Parent = card,
		})
	end
	if opts.focusable then
		Nav.Register(card, { onActivate = opts.onActivate, scale = 1.03 })
	end
	return card
end

-- Полоса прогресса.
function C.Progress(value, opts)
	opts = opts or {}
	local bar = new("Frame", {
		Name = "Progress",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.8,
		Size = opts.size or UDim2.new(1, 0, 0, 6),
		Position = opts.position,
		Parent = opts.parent,
	}, { Util.corner(UDim.new(0.5, 0)) })
	new("Frame", {
		Name = "Fill",
		BackgroundColor3 = opts.color or Theme.Colors.AccentLight,
		Size = UDim2.fromScale(math.clamp(value, 0, 1), 1),
		Parent = bar,
	}, { Util.corner(UDim.new(0.5, 0)) })
	return bar
end

-- Аватар пользователя.
function C.Avatar(user, size, parent)
	local frame = new("Frame", {
		Name = "Avatar",
		BackgroundColor3 = Util.hex(user.color or "#2D7CF6"),
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	}, {
		Util.corner(UDim.new(0.5, 0)),
		Util.gradient({ Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 170) }, 45),
	})
	local name = (user.name and user.name ~= "") and user.name or "?"
	text(utf8.char(utf8.codepoint(name, 1)), {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.FontBold,
		TextSize = math.floor(size * 0.45),
		Parent = frame,
	})
	return frame
end

return C
