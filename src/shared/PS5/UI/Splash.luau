-- Заставка запуска приложения: цвета игры, значок и название.
local PS5 = script.Parent.Parent
local Util = require(PS5.Util)
local Theme = require(PS5.Theme)

local Splash = {}
local frame = nil

function Splash.Init(parent)
	frame = Util.new("Frame", {
		Name = "Splash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 100,
		Parent = parent,
	})
end

-- Показывает заставку, в середине вызывает onCovered (момент запуска игры).
function Splash.Play(manifest, onCovered)
	frame:ClearAllChildren()
	frame.Visible = true
	frame.BackgroundTransparency = 1
	local colors = Util.appColors(manifest)
	local bg = Util.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 101,
		Parent = frame,
	}, { Util.gradient({ colors[1], colors[2] or colors[1] }, 120) })
	local icon = Util.appIcon(manifest, UDim2.fromOffset(160, 160))
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.45)
	icon.ZIndex = 102
	icon.Parent = frame
	local title = Util.text(manifest.title, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.45, 100),
		Size = UDim2.new(1, 0, 0, 50),
		TextSize = 42,
		Font = Theme.FontBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		ZIndex = 102,
		Parent = frame,
	})
	if icon:IsA("TextLabel") then
		icon.TextTransparency = 1
		Util.tween(icon, 0.5, { TextTransparency = 0 })
	else
		icon.ImageTransparency = 1
		Util.tween(icon, 0.5, { ImageTransparency = 0 })
	end
	Util.tween(bg, 0.35, { BackgroundTransparency = 0 })
	Util.tween(title, 0.6, { TextTransparency = 0 })
	task.delay(0.45, function()
		frame.BackgroundTransparency = 0
		onCovered()
	end)
	task.delay(1.6, function()
		for _, d in frame:GetDescendants() do
			if d:IsA("TextLabel") then
				Util.tween(d, 0.4, { TextTransparency = 1 })
			elseif d:IsA("ImageLabel") then
				Util.tween(d, 0.4, { ImageTransparency = 1 })
			elseif d:IsA("Frame") then
				Util.tween(d, 0.4, { BackgroundTransparency = 1 })
			end
		end
		Util.tween(frame, 0.4, { BackgroundTransparency = 1 })
		task.wait(0.45)
		frame.Visible = false
	end)
end

return Splash
