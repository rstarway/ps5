-- Оболочка системы: слои GUI, фон, переходы между экранами, кнопка PS, питание.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local PS5 = script.Parent
local Util = require(PS5.Util)
local Theme = require(PS5.Theme)
local Nav = require(PS5.Nav)
local Input = require(PS5.Input)
local Audio = require(PS5.Audio)
local Data = require(PS5.Data)
local Registry = require(PS5.Registry)
local Runtime = require(PS5.Runtime)
local Trophies = require(PS5.Trophies)
local Embedded = require(PS5.Embedded)

local Toasts = require(script.Toasts)
local Modal = require(script.Modal)
local Splash = require(script.Splash)

local Shell = {}
Shell.Toasts = Toasts
Shell.Modal = Modal
Shell.state = "standby" -- standby (PS5 выключена, игрок в мире) | boot | ui | off | sleep
Shell.standalone = false -- true: интерфейс без 3D-мира (Shell.Start)
Shell.Exited = require(PS5.Signal).new() -- игрок выключил PS5 и вернулся в мир

local screens = {}
local currentScreen = nil
local hintBar, backdrop, tint, blackout, fpsLabel, transition

local function makeGui(name, order)
	return Util.new("ScreenGui", {
		Name = name,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = order,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
end

-- Анимированный фон: градиент темы + плавающие световые пятна + оттенок выбранной игры.
local function buildBackdrop(parent)
	backdrop = Util.new("Frame", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	})
	Util.new("UIGradient", { Name = "Gradient", Rotation = 120, Parent = backdrop })
	-- Рендер из Blender: своя загруженная картинка (Theme.Images) или встроенная в код
	local image = Util.new("ImageLabel", {
		Name = "Image",
		BackgroundTransparency = 1,
		ImageTransparency = 0.2,
		ScaleType = Enum.ScaleType.Crop,
		Size = UDim2.fromScale(1, 1),
		Parent = backdrop,
	})
	if not Embedded.ApplyImage(image, Theme.Images.HomeBackground ~= "" and Theme.Images.HomeBackground or "HomeBackground", PS5.Assets) then
		image:Destroy()
	else
		-- медленный «наезд» камеры на фон (эффект Кена Бёрнса)
		local zoom = Util.new("UIScale", { Scale = 1.04, Parent = image })
		task.spawn(function()
			local inward = true
			while image.Parent do
				if not Data.Setting("reduceMotion") then
					Util.tween(zoom, 18, { Scale = inward and 1.14 or 1.04 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					Util.tween(image, 18, { Position = inward and UDim2.fromScale(-0.02, -0.015) or UDim2.fromScale(0.01, 0.01) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				end
				inward = not inward
				task.wait(18)
			end
		end)
	end
	for i = 1, 3 do
		local orb = Util.new("Frame", {
			Name = "Orb",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.7),
			Position = UDim2.fromScale(0.2 + i * 0.25, 0.3 + (i % 2) * 0.4),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.9,
			Parent = backdrop,
		}, {
			Util.corner(UDim.new(0.5, 0)),
			Util.new("UIAspectRatioConstraint", { AspectRatio = 1 }),
			Util.new("UIGradient", {
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
				Rotation = 90 * i,
			}),
		})
		task.spawn(function()
			while orb.Parent do
				if not Data.Setting("reduceMotion") then
					local target = UDim2.fromScale(0.1 + math.random() * 0.8, 0.1 + math.random() * 0.8)
					Util.tween(orb, 14, { Position = target }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				end
				task.wait(14)
			end
		end)
	end
	tint = Util.new("Frame", {
		Name = "AppTint",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Parent = backdrop,
	}, {
		Util.new("UIGradient", {
			Name = "Gradient",
			Rotation = 0,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		}),
	})
	Util.new("Frame", {
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		Parent = backdrop,
	}, {
		Util.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 0.2) }),
		}),
	})
end

function Shell.ApplyBackground()
	local id = Data.Setting("background")
	local bgTheme = Theme.Backgrounds[1]
	for _, b in Theme.Backgrounds do
		if b.id == id then
			bgTheme = b
		end
	end
	local c = bgTheme.colors
	backdrop.Gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c[1]),
		ColorSequenceKeypoint.new(0.55, c[2]),
		ColorSequenceKeypoint.new(1, c[3]),
	})
end

function Shell.SetBackdrop(visible)
	backdrop.Visible = visible
end

-- Окрашивает фон в цвета выбранной игры (nil — убрать).
function Shell.TintBackground(manifest)
	if not manifest then
		Util.tween(tint, 0.6, { BackgroundTransparency = 1 })
		return
	end
	local colors = Util.appColors(manifest)
	tint.Gradient.Color = ColorSequence.new(colors[1], colors[2] or colors[1])
	tint.BackgroundTransparency = 1
	Util.tween(tint, 0.6, { BackgroundTransparency = 0.15 })
end

-- Подсказки по кнопкам внизу справа: { {"cross", "Выбрать"}, {"circle", "Назад"} }
local currentHints = {}
function Shell.SetHints(hints)
	currentHints = hints or {}
	hintBar:ClearAllChildren()
	Util.list(Enum.FillDirection.Horizontal, 24, Enum.HorizontalAlignment.Right).Parent = hintBar
	for i, hint in currentHints do
		Util.text(`{Input.Glyph(hint[1])}  {hint[2]}`, {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			TextSize = 18,
			TextColor3 = Theme.Colors.SubText,
			LayoutOrder = i,
			Parent = hintBar,
		})
	end
end

function Shell.Go(name, args)
	if currentScreen then
		currentScreen.Leave()
		currentScreen.frame.Visible = false
	end
	currentScreen = screens[name]
	currentScreen.name = name
	currentScreen.frame.Visible = true
	currentScreen.Enter(args)
	-- переход: экран «приземляется» из лёгкого приближения, сквозь затемнение
	if not Data.Setting("reduceMotion") then
		local frame = currentScreen.frame
		local scale = frame:FindFirstChild("EnterScale") or Util.new("UIScale", { Name = "EnterScale", Parent = frame })
		scale.Scale = 1.035
		Util.tween(scale, 0.45, { Scale = 1 })
		if transition then
			transition.BackgroundTransparency = 0.35
			Util.tween(transition, 0.4, { BackgroundTransparency = 1 })
		end
	end
	Audio.MenuMusic(name ~= "boot" and Shell.state == "ui" and Runtime.Current() == nil)
end

function Shell.Current()
	return currentScreen and currentScreen.name
end

function Shell.Back()
	Shell.Go("home")
end

function Shell.Toast(title, text, opts)
	opts = opts or {}
	opts.title, opts.text = title, text
	Toasts.Show(opts)
end

-- Запуск приложения с заставкой (или продолжение уже запущенного).
function Shell.Launch(id)
	local manifest = Registry.Get(id)
	if not manifest then
		return
	end
	if not Registry.IsInstalled(id) then
		Shell.Toast("Not installed", `Download “{manifest.title}” in PlayStation Store`, { icon = "⬇" })
		Shell.Go("store")
		return
	end
	local running, state = Runtime.Current()
	if running and running.id == id and state == "paused" then
		Shell.systemGui.Enabled = false
		Runtime.Resume()
		return
	end
	local function start()
		Audio.Ui("launch")
		if Runtime.Launch(id) then
			Shell.systemGui.Enabled = false
		end
	end
	if running then
		Modal.Confirm("Close the game?", `“{running.title}” will close and unsaved progress will be lost.`, function()
			Runtime.Close()
			Splash.Play(manifest, start)
		end, "Close and Start")
		return
	end
	Splash.Play(manifest, start)
end

-- Вернуться на главный экран, оставив игру на паузе.
function Shell.GoHome()
	if Runtime.Current() then
		Runtime.Hide()
	end
	Shell.systemGui.Enabled = true
	Shell.Go("home")
end

-- Включение PS5 из мира. opts.launch = id: сразу запустить игру (с полки в доме).
function Shell.PowerOn(opts)
	opts = opts or {}
	if Shell.state ~= "standby" then
		return
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	Audio.DuckWorld(true)
	Shell.systemGui.Enabled = true
	if opts.launch and Registry.Get(opts.launch) then
		Shell.state = "ui"
		Shell.SetBackdrop(true)
		Shell.Go("home")
		Shell.Launch(opts.launch)
	else
		Shell.Go("boot")
	end
end

-- Выход из интерфейса обратно к персонажу.
function Shell.Exit()
	if Shell.state == "standby" then
		return
	end
	Shell.ControlCenter.Close(true)
	Runtime.Close()
	Nav.Clear()
	if currentScreen then
		currentScreen.Leave()
		currentScreen.frame.Visible = false
		currentScreen = nil
	end
	Nav.Clear()
	blackout.Visible = false
	Shell.systemGui.Enabled = false
	Shell.state = "standby"
	Audio.MenuMusic(false)
	Audio.Ui("powerOff")
	Audio.DuckWorld(false)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	end)
	Shell.Exited:Fire()
end

-- Питание
function Shell.Power(mode)
	if mode == "off" and not Shell.standalone then
		Shell.Exit()
		return
	end
	Shell.ControlCenter.Close(true)
	Runtime.Close()
	if mode == "restart" then
		Shell.systemGui.Enabled = true
		Shell.Go("boot")
		return
	end
	Shell.state = mode -- "off" | "sleep"
	Audio.MenuMusic(false)
	Audio.Ui("powerOff")
	blackout.Visible = true
	blackout.BackgroundTransparency = 1
	blackout.Label.Text = mode == "sleep" and "Rest Mode\nPress any button" or "Press the PS button to turn on"
	Util.tween(blackout, 0.8, { BackgroundTransparency = 0 })
end

local function wake()
	local mode = Shell.state
	Shell.state = "ui"
	Util.tween(blackout, 0.5, { BackgroundTransparency = 1 })
	task.delay(0.5, function()
		blackout.Visible = false
	end)
	Shell.systemGui.Enabled = true
	if mode == "off" then
		Shell.Go("boot")
	elseif currentScreen then
		Audio.MenuMusic(Runtime.Current() == nil and currentScreen.name ~= "boot")
	end
end

local function onSystemButton(event)
	if event ~= "press" or Shell.state == "standby" then
		return
	end
	if Shell.state == "off" or Shell.state == "sleep" then
		wake()
		return
	end
	if Shell.state == "boot" then
		if currentScreen and currentScreen.OnPS then
			currentScreen.OnPS()
		end
		return
	end
	if not Shell.ControlCenter.IsOpen() then
		Audio.Ui("open")
	end
	Shell.ControlCenter.Toggle()
end

-- Только интерфейс, без мира: сразу включает PS5.
function Shell.Start()
	Shell.standalone = true
	Shell.Init()
	Shell.PowerOn()
end

-- Создаёт интерфейс в выключенном состоянии; включается Shell.PowerOn().
function Shell.Init()
	Data.Load()
	Registry.Load()
	Audio.SetVolume(Data.Setting("volume"))
	Audio.UiEnabled = Data.Setting("uiSounds")
	Audio.MusicEnabled = Data.Setting("menuMusic") ~= false

	local appGui = makeGui("PS5Apps", 5)
	appGui.Enabled = false
	Runtime.Init(appGui)
	Shell.systemGui = makeGui("PS5System", 10)
	Shell.systemGui.Enabled = false
	Shell.overlayGui = makeGui("PS5Overlay", 50)

	buildBackdrop(Shell.systemGui)
	Shell.ApplyBackground()
	Shell.screensRoot = Util.canvas(Shell.systemGui)
	Shell.screensRoot.Name = "Screens"
	Shell.overlayCanvas = Util.canvas(Shell.overlayGui)
	Shell.overlayCanvas.Name = "Overlay"
	hintBar = Util.new("Frame", {
		Name = "Hints",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -160, 0, 30),
		Position = UDim2.new(0, 80, 1, -54),
		ZIndex = 5,
		Parent = Shell.screensRoot,
	})
	fpsLabel = Util.text("", {
		Name = "Fps",
		Size = UDim2.fromOffset(120, 20),
		Position = UDim2.fromOffset(12, 8),
		TextSize = 14,
		TextColor3 = Theme.Colors.Success,
		Visible = Data.Setting("showFps"),
		Parent = Shell.overlayGui,
	})
	local frames, acc = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		frames += 1
		acc += dt
		if acc >= 0.5 then
			fpsLabel.Text = `{math.floor(frames / acc)} FPS`
			frames, acc = 0, 0
		end
	end)

	Shell.ControlCenter = require(script.ControlCenter)(Shell)
	Modal.Init(Shell.overlayCanvas)
	Splash.Init(Shell.overlayGui)
	Toasts.Init(Shell.overlayCanvas)
	transition = Util.new("Frame", {
		Name = "Transition",
		BackgroundColor3 = Color3.fromRGB(2, 4, 14),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Active = false,
		ZIndex = 150,
		Parent = Shell.overlayGui,
	})
	blackout = Util.new("TextButton", {
		Name = "Blackout",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 200,
		Parent = Shell.overlayGui,
	})
	Util.text("", {
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Colors.Muted,
		TextSize = 22,
		ZIndex = 201,
		Parent = blackout,
	})
	blackout.Activated:Connect(wake)

	for _, name in { "Boot", "Users", "Home", "Library", "Store", "Trophies", "Settings" } do
		local screen = require(script[name])(Shell)
		screen.frame.Visible = false
		screen.frame.Parent = Shell.screensRoot
		screens[string.lower(name)] = screen
	end

	-- Ввод интерфейса — нижний приёмник; кнопка PS — системная.
	Input.PushSink(function(event, btn)
		if Shell.state == "sleep" and event == "press" then
			wake()
			return
		end
		if Shell.state == "off" or Shell.state == "standby" then
			return
		end
		Nav.Handle(event, btn)
	end, "ui")
	Input.SystemButton:Connect(onSystemButton)
	Input.DeviceChanged:Connect(function()
		Shell.SetHints(currentHints)
	end)

	Data.SettingChanged:Connect(function(key, value)
		if key == "volume" then
			Audio.SetVolume(value)
		elseif key == "uiSounds" then
			Audio.UiEnabled = value
		elseif key == "menuMusic" then
			Audio.MusicEnabled = value
			Audio.MenuMusic(value and Shell.state == "ui" and Runtime.Current() == nil)
		elseif key == "background" then
			Shell.ApplyBackground()
		elseif key == "showFps" then
			fpsLabel.Visible = value
		end
	end)
	Trophies.Unlocked:Connect(function(manifest, trophy)
		Toasts.Show({
			title = "Trophy earned",
			text = `{trophy.name} · {manifest.title}`,
			icon = "🏆",
			color = Theme.TrophyColors[trophy.grade or "bronze"],
			sound = false,
		})
	end)
	Runtime.Notify:Connect(function(title, text, manifest)
		Toasts.Show({ title = title, text = text, icon = manifest and manifest.icon or "i", color = manifest and Util.appColors(manifest)[1] })
	end)
	Runtime.Closed:Connect(function()
		Shell.systemGui.Enabled = true
		Audio.MenuMusic(Shell.state == "ui")
		if Shell.state == "ui" and Shell.Current() ~= "home" then
			Shell.Go("home")
		elseif Shell.Current() == "home" then
			screens.home.Refresh()
		end
	end)
	Runtime.Started:Connect(function()
		Audio.MenuMusic(false)
		if screens.home then
			screens.home.dirty = true
		end
	end)

end

return Shell
