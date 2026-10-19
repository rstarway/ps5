-- Всплывающие уведомления в правом верхнем углу (трофеи, сообщения игр, система).
local PS5 = script.Parent.Parent
local Util = require(PS5.Util)
local Theme = require(PS5.Theme)
local Audio = require(PS5.Audio)

local Toasts = {}
Toasts.History = {} -- для центра уведомлений

local container = nil

function Toasts.Init(parent)
	container = Util.new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 420, 1, -40),
		Position = UDim2.new(1, -440, 0, 24),
		Parent = parent,
	}, { Util.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Right) })
end

-- opts: title, text, icon (символ), color, sound (false — без звука)
function Toasts.Show(opts)
	table.insert(Toasts.History, 1, { title = opts.title, text = opts.text, time = os.time(), icon = opts.icon })
	if #Toasts.History > 30 then
		table.remove(Toasts.History)
	end
	if opts.sound ~= false then
		Audio.Ui(opts.soundName or "notify")
	end
	local toast = Util.new("Frame", {
		Name = "Toast",
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.05,
		Size = UDim2.fromOffset(400, 84),
		LayoutOrder = -os.clock() * 1000,
		Parent = container,
	}, {
		Util.corner(16),
		Util.stroke(Color3.new(1, 1, 1), 1, 0.85),
	})
	local scale = Util.new("UIScale", { Scale = 0.8, Parent = toast })
	local iconFrame = Util.new("Frame", {
		BackgroundColor3 = opts.color or Theme.Colors.Accent,
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.fromOffset(14, 14),
		Parent = toast,
	}, { Util.corner(14) })
	Util.text(opts.icon or "i", {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 28,
		Font = Theme.FontBold,
		Parent = iconFrame,
	})
	Util.text(opts.title or "", {
		Size = UDim2.new(1, -96, 0, 26),
		Position = UDim2.fromOffset(84, 14),
		Font = Theme.FontBold,
		TextSize = 20,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = toast,
	})
	Util.text(opts.text or "", {
		Size = UDim2.new(1, -96, 0, 34),
		Position = UDim2.fromOffset(84, 40),
		TextSize = 16,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Theme.Colors.SubText,
		Parent = toast,
	})
	Util.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(opts.duration or 4.5, function()
		Util.tween(scale, 0.25, { Scale = 0 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.wait(0.3)
		toast:Destroy()
	end)
end

return Toasts
