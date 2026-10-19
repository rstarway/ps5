-- Центр управления (кнопка PS): карточки «Домой» / текущая игра и ряд быстрых функций.
local PS5 = script.Parent.Parent
local Util = require(PS5.Util)
local Theme = require(PS5.Theme)
local Nav = require(PS5.Nav)
local Input = require(PS5.Input)
local Data = require(PS5.Data)
local Runtime = require(PS5.Runtime)
local C = require(script.Parent.Components)
local Toasts = require(script.Parent.Toasts)

return function(Shell)
	local CC = {}
	local isOpen = false
	local layer, popSink
	local overApp = false

	local root = Util.new("Frame", {
		Name = "ControlCenter",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 40,
		Parent = Shell.overlayCanvas,
	})
	local dim = Util.new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(3, 3),
		Parent = root,
	})
	local panel = Util.new("Frame", {
		Name = "Panel",
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.05,
		Size = UDim2.new(1, 0, 0, 360),
		Position = UDim2.new(0, 0, 1, 0),
		Parent = root,
	}, {
		Util.gradient({ Color3.fromRGB(30, 36, 60), Color3.fromRGB(10, 12, 22) }, 90),
	})
	local cards = Util.new("Frame", {
		Name = "Cards",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -160, 0, 150),
		Position = UDim2.fromOffset(80, 30),
		Parent = panel,
	}, { Util.list(Enum.FillDirection.Horizontal, 20) })
	local icons = Util.new("Frame", {
		Name = "Icons",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -160, 0, 70),
		Position = UDim2.fromOffset(80, 214),
		Parent = panel,
	}, { Util.list(Enum.FillDirection.Horizontal, 22) })
	local clock = Util.text("", {
		Size = UDim2.fromOffset(200, 30),
		Position = UDim2.new(1, -280, 0, 214),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 26,
		Font = Theme.FontBold,
		Parent = panel,
	})
	local subPanel = Util.new("Frame", {
		Name = "SubPanel",
		BackgroundColor3 = Theme.Colors.Card,
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 80, 1, -380),
		AnchorPoint = Vector2.new(0, 1),
		Visible = false,
		Parent = root,
	}, { Util.corner(20), Util.padding(22), Util.list(Enum.FillDirection.Vertical, 12) })

	local function card(title, sub, colors, order, action)
		local button = Util.new("TextButton", {
			Text = "",
			Size = UDim2.fromOffset(300, 140),
			LayoutOrder = order,
			BackgroundColor3 = Color3.new(1, 1, 1),
			Parent = cards,
		}, { Util.corner(18), Util.gradient(colors, 135), Util.padding(18) })
		Util.text(title, { Size = UDim2.new(1, 0, 0, 30), TextSize = 24, Font = Theme.FontBold, Parent = button })
		Util.text(sub, {
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.fromOffset(0, 80),
			TextSize = 17,
			TextColor3 = Color3.fromRGB(220, 225, 240),
			Parent = button,
		})
		Nav.Register(button, { onActivate = action, scale = 1.05, ringThickness = 4 })
		return button
	end

	local function closeSub()
		subPanel.Visible = false
		subPanel:ClearAllChildren()
		Util.corner(20).Parent = subPanel
		Util.padding(22).Parent = subPanel
		Util.list(Enum.FillDirection.Vertical, 12).Parent = subPanel
	end

	-- Подпанель (звук, уведомления) открывается отдельным слоем навигации.
	local function openSub(title, build)
		closeSub()
		subPanel.Visible = true
		Util.text(title, { Size = UDim2.new(1, 0, 0, 30), TextSize = 24, Font = Theme.FontBold, LayoutOrder = 0, Parent = subPanel })
		build(subPanel)
		local subLayer
		subLayer = {
			root = subPanel,
			name = "cc-sub",
			onBack = function()
				Nav.Pop(subLayer)
				closeSub()
			end,
		}
		Nav.Push(subLayer)
	end

	local function volumeRow(parent)
		local row = Util.new("TextButton", {
			Text = "",
			BackgroundColor3 = Theme.Colors.CardLight,
			Size = UDim2.new(1, 0, 0, 60),
			LayoutOrder = 1,
			Parent = parent,
		}, { Util.corner(14), Util.padding(10, 16) })
		local label = Util.text("", { Size = UDim2.new(1, 0, 0, 20), TextSize = 17, Parent = row })
		local bar = C.Progress(0, { parent = row, position = UDim2.fromOffset(0, 30), size = UDim2.new(1, 0, 0, 8) })
		local function refresh()
			local v = Data.Setting("volume")
			label.Text = `Volume: {math.floor(v * 100 + 0.5)}%   (← →)`
			bar.Fill.Size = UDim2.fromScale(v, 1)
		end
		refresh()
		Nav.Register(row, {
			scale = 1.02,
			onButton = function(btn)
				if btn == "left" or btn == "right" then
					local v = Data.Setting("volume") + (btn == "right" and 0.1 or -0.1)
					Data.SetSetting("volume", math.clamp(math.floor(v * 10 + 0.5) / 10, 0, 1))
					refresh()
					return true
				end
				return false
			end,
		})
	end

	local function build()
		cards:ClearAllChildren()
		icons:ClearAllChildren()
		Util.list(Enum.FillDirection.Horizontal, 20).Parent = cards
		Util.list(Enum.FillDirection.Horizontal, 22).Parent = icons

		local running = Runtime.Current()
		local first
		first = card("Home", "Back to menu", { Color3.fromRGB(0, 90, 220), Color3.fromRGB(10, 30, 90) }, 1, function()
			CC.Close(true)
			Shell.GoHome()
		end)
		if running then
			local colors = Util.appColors(running)
			first = card(running.title, "Resume", { colors[1], colors[2] or colors[1] }, 2, function()
				CC.Close()
			end)
			card("Close Game", running.title, { Color3.fromRGB(120, 30, 40), Color3.fromRGB(40, 10, 16) }, 3, function()
				CC.Close(true)
				Runtime.Close()
			end)
		end

		local user = Data.CurrentUser()
		local entries = {
			{ "🔔", "Notifications", function()
				openSub("Notifications", function(parent)
					if #Toasts.History == 0 then
						Util.text("No new notifications", { TextColor3 = Theme.Colors.SubText, LayoutOrder = 1, Parent = parent })
					end
					for i, n in Toasts.History do
						if i > 6 then
							break
						end
						C.Card({
							title = `{n.title} · {Util.formatTime(n.time)}`,
							body = n.text,
							bodySize = 18,
							size = UDim2.new(1, 0, 0, 84),
							order = i,
							focusable = true,
							parent = parent,
						})
					end
				end)
			end },
			{ "🔊", "Sound", function()
				openSub("Sound", volumeRow)
			end },
			{ "🏆", "Trophies", function()
				CC.Close(true)
				Shell.GoHome()
				Shell.Go("trophies")
			end },
			{ "⚙", "Settings", function()
				CC.Close(true)
				Shell.GoHome()
				Shell.Go("settings")
			end },
			{ "👤", user and user.name or "User", function()
				CC.Close(true)
				Runtime.Close()
				Shell.systemGui.Enabled = true
				Shell.Go("users")
			end },
			{ "⏻", "Power", function()
				Shell.Modal.Menu("Power", {
					{ label = "Enter Rest Mode", action = function() Shell.Power("sleep") end },
					{ label = "Restart PS5", action = function() Shell.Power("restart") end },
					{ label = Shell.standalone and "Turn Off PS5" or "Turn Off PS5 and Get Up", variant = "danger", action = function() Shell.Power("off") end },
				})
			end },
		}
		for i, entry in entries do
			C.IconButton(entry[1], { caption = entry[2], order = i, size = 58, parent = icons, onActivate = entry[3] })
		end
		return first
	end

	function CC.Open()
		if isOpen or Shell.state ~= "ui" then
			return
		end
		isOpen = true
		local running, state = Runtime.Current()
		overApp = running ~= nil and state == "running"
		if overApp then
			Runtime.Pause()
			popSink = Input.PushSink(Nav.Handle, "ui")
		end
		local first = build()
		clock.Text = os.date("%H:%M")
		root.Visible = true
		Util.tween(dim, 0.25, { BackgroundTransparency = 0.5 })
		Util.tween(panel, 0.35, { Position = UDim2.new(0, 0, 1, -360) })
		layer = { root = root, name = "control-center", default = first, onBack = function()
			CC.Close()
		end }
		Nav.Push(layer)
	end

	-- keepPaused = true: не продолжать игру (переход на главный экран или закрытие)
	function CC.Close(keepPaused)
		if not isOpen then
			return
		end
		isOpen = false
		closeSub()
		while Nav.Top() and Nav.Top() ~= layer do
			Nav.Pop(Nav.Top())
		end
		Nav.Pop(layer)
		if popSink then
			popSink()
			popSink = nil
		end
		Util.tween(dim, 0.2, { BackgroundTransparency = 1 })
		Util.tween(panel, 0.25, { Position = UDim2.new(0, 0, 1, 0) })
		task.delay(0.25, function()
			if not isOpen then
				root.Visible = false
			end
		end)
		if overApp and not keepPaused then
			Runtime.Resume()
		end
		overApp = false
	end

	function CC.Toggle()
		if isOpen then
			CC.Close()
		else
			CC.Open()
		end
	end

	function CC.IsOpen()
		return isOpen
	end

	return CC
end
