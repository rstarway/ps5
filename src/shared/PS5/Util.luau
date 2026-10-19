-- Помощники для построения интерфейса. Доступны играм как ctx.ui.
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Util = {}

-- Util.new("Frame", { Size = ..., Parent = ... }, { дочерние элементы })
function Util.new(className, props, children)
	local inst = Instance.new(className)
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Util.corner(radius)
	if typeof(radius) == "UDim" then
		return Util.new("UICorner", { CornerRadius = radius })
	end
	return Util.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Util.padding(all, horizontal)
	local v = UDim.new(0, all)
	local h = UDim.new(0, horizontal or all)
	return Util.new("UIPadding", { PaddingTop = v, PaddingBottom = v, PaddingLeft = h, PaddingRight = h })
end

function Util.list(direction, gap, align)
	return Util.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

function Util.stroke(color, thickness, transparency)
	return Util.new("UIStroke", {
		Color = color or Color3.new(1, 1, 1),
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Util.gradient(colors, rotation, transparency)
	local keypoints = {}
	for i, c in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / math.max(#colors - 1, 1), c))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, colors[1]))
	end
	return Util.new("UIGradient", {
		Color = ColorSequence.new(keypoints),
		Rotation = rotation or 0,
		Transparency = transparency or NumberSequence.new(0),
	})
end

-- Текстовая метка с настройками системы по умолчанию.
function Util.text(text, props)
	local label = Util.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text or "",
		Font = Theme.FontMedium,
		TextColor3 = Theme.Colors.Text,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
	})
	for key, value in props or {} do
		if key ~= "Parent" then
			label[key] = value
		end
	end
	if props and props.Parent then
		label.Parent = props.Parent
	end
	return label
end

-- Холст фиксированного размера (по умолчанию 1920×1080), вписанный в родителя.
-- Вся система свёрстана в этих координатах; игры могут делать так же: ctx.ui.canvas(ctx.gui).
function Util.canvas(parent, width, height)
	width, height = width or 1920, height or 1080
	local frame = Util.new("Frame", {
		Name = "Canvas",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		Parent = parent,
	})
	local scale = Util.new("UIScale", { Parent = frame })
	local function update()
		local size = parent.AbsoluteSize
		if size.X > 0 and size.Y > 0 then
			scale.Scale = math.min(size.X / width, size.Y / height)
		end
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	update()
	return frame
end

function Util.tween(inst, duration, props, style, direction)
	local tween = TweenService:Create(
		inst,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

function Util.hex(value)
	if typeof(value) == "Color3" then
		return value
	end
	local ok, color = pcall(Color3.fromHex, value)
	return ok and color or Color3.new(0.3, 0.3, 0.3)
end

-- Цвета приложения из манифеста (colors = {"#hex", "#hex"}).
function Util.appColors(manifest)
	local list = {}
	for _, c in manifest and manifest.colors or { "#1b2a5a", "#0a1024" } do
		table.insert(list, Util.hex(c))
	end
	if #list == 0 then
		list = { Color3.fromRGB(27, 42, 90), Color3.fromRGB(10, 16, 36) }
	end
	return list
end

-- Значок приложения: картинка (rbxassetid) или текст/эмодзи.
function Util.appIcon(manifest, size)
	local icon = manifest.icon or string.sub(manifest.title or "?", 1, 1)
	if string.find(icon, "rbxasset") then
		return Util.new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = icon,
			Size = size or UDim2.fromScale(1, 1),
			ScaleType = Enum.ScaleType.Crop,
		})
	end
	return Util.text(icon, {
		Size = size or UDim2.fromScale(1, 1),
		TextScaled = true,
		Font = Theme.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
end

function Util.formatTime(timestamp)
	if not timestamp then
		return "never"
	end
	local diff = os.time() - timestamp
	if diff < 60 then
		return "just now"
	elseif diff < 3600 then
		return `{math.floor(diff / 60)} min ago`
	elseif diff < 86400 then
		return `{math.floor(diff / 3600)} h ago`
	end
	return `{math.floor(diff / 86400)} d ago`
end

return Util
