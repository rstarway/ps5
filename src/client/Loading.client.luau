-- Экран загрузки (ReplicatedFirst): закрывает чёрный экран, пока сервер строит чиллзону
-- и спавнит персонажа. Исчезает, когда персонаж стоит в своей зоне, — тогда начинается интро.
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "PS5Loading"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(4, 6, 14)
bg.BorderSizePixel = 0
bg.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Color = ColorSequence.new(Color3.fromRGB(10, 14, 40), Color3.fromRGB(2, 3, 8))
gradient.Parent = bg

local function label(text, size, y, color, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.new(0.5, 0, 0.5, y)
	l.Size = UDim2.fromOffset(900, size + 10)
	l.Font = font or Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = color
	l.Text = text
	l.Parent = bg
	return l
end

-- символы геймпада в цветах PS; «✕» в шрифтах Roblox нет, поэтому «×»
local symbols = {}
for i, data in { { "△", 46, 200, 150 }, { "○", 240, 90, 100 }, { "×", 90, 150, 255 }, { "□", 240, 110, 190 } } do
	local l = label(data[1], 34, -60, Color3.fromRGB(data[2], data[3], data[4]))
	l.Size = UDim2.fromOffset(50, 44)
	l.Position = UDim2.new(0.5, (i - 2.5) * 56, 0.5, -60)
	table.insert(symbols, l)
end
local title = label("PS5 SANDBOX", 40, 0, Color3.fromRGB(235, 240, 255))
local status = label("Building your Chill Zone", 18, 50, Color3.fromRGB(140, 150, 180), Enum.Font.Gotham)

-- три точки и пульсация символов, чтобы было видно, что игра не зависла
local alive = true
task.spawn(function()
	local dots = 0
	while alive do
		dots = (dots + 1) % 4
		status.Text = "Building your Chill Zone" .. string.rep(".", dots)
		task.wait(0.4)
	end
end)
for i, l in symbols do
	task.delay(i * 0.15, function()
		TweenService:Create(l, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { TextTransparency = 0.7 }):Play()
	end)
end

gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local function ready()
	local character = player.Character
	local zones = Workspace:FindFirstChild("ChillZones")
	return character ~= nil
		and character:FindFirstChild("HumanoidRootPart") ~= nil
		and zones ~= nil
		and zones:FindFirstChild("Zone_" .. player.UserId) ~= nil
end

-- без зоны (сервер упал или её нет) клиент сам включит интерфейс, поэтому ждём не дольше 30 с
local started = os.clock()
while not (game:IsLoaded() and ready()) and os.clock() - started < 30 do
	task.wait(0.1)
end

alive = false
local fade = TweenInfo.new(0.6, Enum.EasingStyle.Quad)
for _, l in { title, status, table.unpack(symbols) } do
	TweenService:Create(l, fade, { TextTransparency = 1 }):Play()
end
TweenService:Create(bg, fade, { BackgroundTransparency = 1 }):Play()
task.wait(0.7)
gui:Destroy()
