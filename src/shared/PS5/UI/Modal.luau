-- Модальные окна: меню действий, подтверждение, ввод текста.
local PS5 = script.Parent.Parent
local Util = require(PS5.Util)
local Theme = require(PS5.Theme)
local Nav = require(PS5.Nav)
local Input = require(PS5.Input)
local C = require(script.Parent.Components)

local Modal = {}
local root = nil

function Modal.Init(parent)
	root = parent
end

local function open(build, opts)
	opts = opts or {}
	local dim = Util.new("TextButton", {
		Name = "Modal",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(3, 3),
		ZIndex = 50,
		Parent = root,
	})
	local panel = Util.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(opts.width or 560, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		Parent = dim,
	}, {
		Util.corner(22),
		Util.padding(28),
		Util.stroke(Color3.new(1, 1, 1), 1, 0.85),
		Util.list(Enum.FillDirection.Vertical, 14, Enum.HorizontalAlignment.Center),
	})
	local scale = Util.new("UIScale", { Scale = 0.9, Parent = panel })
	Util.tween(dim, 0.2, { BackgroundTransparency = 0.45 })
	Util.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)

	local popSink = Input.TopSinkName() ~= "ui" and Input.PushSink(Nav.Handle, "ui") or nil
	local layer
	local function close()
		if not dim.Parent then
			return
		end
		Nav.Pop(layer)
		if popSink then
			popSink()
		end
		dim:Destroy()
		if opts.onClose then
			opts.onClose()
		end
	end
	layer = { root = panel, name = "modal", onBack = close }
	build(panel, close)
	Nav.Push(layer)
	return close
end
Modal.Open = open

local function title(panel, value, order)
	if value then
		Util.text(value, {
			Size = UDim2.new(1, 0, 0, 34),
			Font = Theme.FontBold,
			TextSize = 28,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = order or 0,
			Parent = panel,
		})
	end
end

-- items = { { label, action = fn, variant = "danger" } }
function Modal.Menu(heading, items, opts)
	return open(function(panel, close)
		title(panel, heading)
		for i, item in items do
			C.Button(item.label, {
				order = i,
				size = UDim2.new(1, 0, 0, 54),
				variant = item.variant,
				parent = panel,
				onActivate = function()
					close()
					if item.action then
						item.action()
					end
				end,
			})
		end
	end, opts)
end

function Modal.Confirm(heading, body, onYes, yesLabel)
	return open(function(panel, close)
		title(panel, heading)
		Util.text(body, {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 20,
			TextColor3 = Theme.Colors.SubText,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 1,
			Parent = panel,
		})
		local row = Util.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 60),
			LayoutOrder = 2,
			Parent = panel,
		}, { Util.list(Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center) })
		C.Button("Cancel", { order = 1, parent = row, onActivate = close })
		C.Button(yesLabel or "OK", {
			order = 2,
			variant = "primary",
			parent = row,
			onActivate = function()
				close()
				onYes()
			end,
		})
	end)
end

-- Ввод текста (клавиатура или экранная клавиатура консоли).
function Modal.Prompt(heading, default, onDone)
	return open(function(panel, close)
		title(panel, heading)
		local box = Util.new("TextBox", {
			Text = default or "",
			PlaceholderText = "Enter text",
			ClearTextOnFocus = false,
			Font = Theme.FontMedium,
			TextSize = 24,
			TextColor3 = Theme.Colors.Text,
			BackgroundColor3 = Theme.Colors.Card,
			Size = UDim2.new(1, 0, 0, 56),
			LayoutOrder = 1,
			Parent = panel,
		}, { Util.corner(12), Util.padding(8, 16) })
		local function submit()
			local value = string.gsub(box.Text, "^%s*(.-)%s*$", "%1")
			close()
			if value ~= "" then
				onDone(value)
			end
		end
		box.FocusLost:Connect(function(enter)
			if enter then
				submit()
			end
		end)
		C.Button("Done", { order = 2, variant = "primary", parent = panel, onActivate = submit })
		task.defer(function()
			box:CaptureFocus()
		end)
	end)
end

return Modal
