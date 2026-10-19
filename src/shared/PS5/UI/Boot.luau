-- Экран включения: пролёт камеры вокруг консоли, символы PlayStation и «Нажмите ✕».
local PS5 = script.Parent.Parent
local Util = require(PS5.Util)
local Theme = require(PS5.Theme)
local Nav = require(PS5.Nav)
local Input = require(PS5.Input)
local Audio = require(PS5.Audio)
local Data = require(PS5.Data)
local World = require(PS5.World)

return function(Shell)
	local frame = Util.new("Frame", {
		Name = "Boot",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
	})
	local screen = { frame = frame }
	local layer, session = nil, 0
	local ready = false

	local function proceed()
		if not ready then
			return
		end
		ready = false
		session += 1
		Shell.state = "ui"
		Audio.Ui("confirm")
		Util.tween(frame, 0.4, { BackgroundTransparency = 0 })
		task.delay(0.4, function()
			Shell.SetBackdrop(true)
			Shell.Go("users")
		end)
	end

	local function symbols(parent)
		local row = Util.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(440, 110),
			BackgroundTransparency = 1,
			Parent = parent,
		}, { Util.list(Enum.FillDirection.Horizontal, 30, Enum.HorizontalAlignment.Center) })
		local items = {
			{ "△", Color3.fromRGB(64, 226, 176) },
			{ "○", Color3.fromRGB(255, 92, 110) },
			{ "✕", Color3.fromRGB(110, 168, 255) },
			{ "□", Color3.fromRGB(255, 128, 210) },
		}
		local labels = {}
		for i, item in items do
			local label = Util.text(item[1], {
				Size = UDim2.fromOffset(86, 110),
				TextSize = 90,
				Font = Theme.FontBold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = item[2],
				TextTransparency = 1,
				LayoutOrder = i,
				Parent = row,
			})
			table.insert(labels, label)
		end
		return labels
	end

	function screen.Enter()
		session += 1
		local my = session
		Shell.state = "boot"
		Shell.SetHints({})
		ready = false
		frame:ClearAllChildren()
		frame.BackgroundTransparency = 0
		Shell.SetBackdrop(false)
		local tap = Util.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = frame })
		tap.Activated:Connect(proceed)
		local labels = symbols(frame)
		local title = Util.text("PS5 SANDBOX", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromOffset(600, 50),
			TextSize = 40,
			Font = Theme.FontHeavy,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTransparency = 1,
			Parent = frame,
		})
		Util.new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 190, 255)),
			Parent = title,
		})
		local prompt = Util.text("", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.78),
			Size = UDim2.fromOffset(700, 30),
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.Colors.SubText,
			TextTransparency = 1,
			Parent = frame,
		})

		local animate = Data.Setting("bootAnimation")
		task.spawn(function()
			if animate then
				World.PlayBoot(6)
				Util.tween(frame, 1.2, { BackgroundTransparency = 0.6 })
				task.wait(2.6)
				if my ~= session then
					return
				end
				Util.tween(frame, 1, { BackgroundTransparency = 0.15 })
			else
				World.Build()
			end
			Audio.Ui("boot")
			for _, label in labels do
				Util.tween(label, 0.5, { TextTransparency = 0 })
				task.wait(animate and 0.18 or 0.05)
			end
			Util.tween(title, 0.8, { TextTransparency = 0 })
			task.wait(animate and 1 or 0.2)
			if my ~= session then
				return
			end
			ready = true
			prompt.Text = `Press {Input.Glyph("cross")} to continue`
			while my == session and frame.Visible do
				Util.tween(prompt, 0.9, { TextTransparency = 0 }, Enum.EasingStyle.Sine)
				task.wait(1.1)
				Util.tween(prompt, 0.9, { TextTransparency = 0.6 }, Enum.EasingStyle.Sine)
				task.wait(1.1)
			end
		end)

		layer = Nav.Push({
			root = frame,
			name = "boot",
			onButton = function(_, event)
				if event == "press" then
					proceed()
				end
				return true
			end,
		})
	end

	screen.OnPS = proceed

	function screen.Leave()
		session += 1
		Nav.Pop(layer)
	end

	return screen
end
