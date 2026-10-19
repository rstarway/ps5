-- Единый ввод: клавиатура + геймпад (DualSense/Xbox) в кнопки PS5.
-- События идут в верхний «приёмник» стека (интерфейс системы или запущенное приложение).
-- Кнопка PS всегда уходит системе.
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local HapticService = game:GetService("HapticService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local Signal = require(script.Parent.Signal)

local Input = {}

Input.Buttons = {
	"cross", "circle", "square", "triangle",
	"l1", "r1", "l2", "r2", "l3", "r3",
	"up", "down", "left", "right",
	"options", "create", "touchpad", "ps",
}

local K = Enum.KeyCode
local MAP = {
	-- геймпад (в Roblox: A = ✕, B = ○, X = □, Y = △)
	[K.ButtonA] = "cross", [K.ButtonB] = "circle", [K.ButtonX] = "square", [K.ButtonY] = "triangle",
	[K.ButtonL1] = "l1", [K.ButtonR1] = "r1", [K.ButtonL2] = "l2", [K.ButtonR2] = "r2",
	[K.ButtonL3] = "l3", [K.ButtonR3] = "r3",
	[K.DPadUp] = "up", [K.DPadDown] = "down", [K.DPadLeft] = "left", [K.DPadRight] = "right",
	[K.ButtonStart] = "options", [K.ButtonSelect] = "ps",
	-- клавиатура (Esc занят меню Roblox, поэтому «назад» = Backspace)
	[K.Return] = "cross", [K.Space] = "cross", [K.KeypadEnter] = "cross",
	[K.Backspace] = "circle", [K.F] = "square", [K.R] = "triangle",
	[K.Q] = "l1", [K.E] = "r1", [K.One] = "l2", [K.Three] = "r2",
	[K.Up] = "up", [K.W] = "up", [K.Down] = "down", [K.S] = "down",
	[K.Left] = "left", [K.A] = "left", [K.Right] = "right", [K.D] = "right",
	[K.O] = "options", [K.C] = "create", [K.T] = "touchpad",
	[K.H] = "ps", [K.Home] = "ps", [K.Tab] = "ps",
}

local DIRECTIONS = { up = true, down = true, left = true, right = true }
local REPEAT_DELAY, REPEAT_RATE = 0.38, 0.09
local STICK_THRESHOLD = 0.55

local held = {} -- кнопка -> { [источник] = true }
local downSince = {}
local nextRepeat = {}
local axes = { lx = 0, ly = 0, rx = 0, ry = 0, l2 = 0, r2 = 0 }
local sinks = {}

Input.SystemButton = Signal.new() -- (event, btn) — кнопка PS
Input.Any = Signal.new() -- (event, btn) — все события, для отладки
Input.LastDevice = "keyboard" -- "keyboard" | "gamepad" | "touch"
Input.DeviceChanged = Signal.new()

local function isDown(btn)
	return held[btn] ~= nil and next(held[btn]) ~= nil
end

local function dispatch(event, btn)
	Input.Any:Fire(event, btn)
	if btn == "ps" then
		Input.SystemButton:Fire(event, btn)
		return
	end
	local sink = sinks[#sinks]
	if sink then
		local ok, err = pcall(sink.fn, event, btn)
		if not ok then
			warn("[PS5] Input handler error:", err)
		end
	end
end

local function setHeld(btn, source, value)
	local wasDown = isDown(btn)
	held[btn] = held[btn] or {}
	held[btn][source] = value or nil
	local nowDown = isDown(btn)
	if nowDown and not wasDown then
		downSince[btn] = os.clock()
		nextRepeat[btn] = os.clock() + REPEAT_DELAY
		dispatch("press", btn)
	elseif wasDown and not nowDown then
		dispatch("release", btn)
	end
end

local function setDevice(device)
	if Input.LastDevice ~= device then
		Input.LastDevice = device
		Input.DeviceChanged:Fire(device)
	end
end

local function isGamepad(inputType)
	return inputType.Name:sub(1, 7) == "Gamepad"
end

UserInputService.InputBegan:Connect(function(io, processed)
	if io.UserInputType == Enum.UserInputType.Touch then
		setDevice("touch")
	end
	if processed and UserInputService:GetFocusedTextBox() then
		return
	end
	local btn = MAP[io.KeyCode]
	if btn then
		setDevice(isGamepad(io.UserInputType) and "gamepad" or "keyboard")
		setHeld(btn, io.KeyCode.Name, true)
	end
end)

UserInputService.InputEnded:Connect(function(io)
	local btn = MAP[io.KeyCode]
	if btn then
		setHeld(btn, io.KeyCode.Name, false)
	end
end)

UserInputService.InputChanged:Connect(function(io)
	if io.KeyCode == K.Thumbstick1 then
		local x, y = io.Position.X, io.Position.Y
		axes.lx, axes.ly = x, y
		if math.abs(x) > 0.2 or math.abs(y) > 0.2 then
			setDevice("gamepad")
		end
		setHeld("right", "stick", x > STICK_THRESHOLD)
		setHeld("left", "stick", x < -STICK_THRESHOLD)
		setHeld("up", "stick", y > STICK_THRESHOLD)
		setHeld("down", "stick", y < -STICK_THRESHOLD)
	elseif io.KeyCode == K.Thumbstick2 then
		axes.rx, axes.ry = io.Position.X, io.Position.Y
	elseif io.KeyCode == K.ButtonL2 then
		axes.l2 = io.Position.Z
	elseif io.KeyCode == K.ButtonR2 then
		axes.r2 = io.Position.Z
	end
end)

-- Повтор направлений при удержании (для навигации по меню).
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for btn in DIRECTIONS do
		if isDown(btn) and nextRepeat[btn] and now >= nextRepeat[btn] then
			nextRepeat[btn] = now + REPEAT_RATE
			dispatch("repeat", btn)
		end
	end
end)

-- Не даём Roblox использовать эти клавиши (движение камеры, выделение GUI).
GuiService.AutoSelectGuiEnabled = false
pcall(function()
	ContextActionService:BindActionAtPriority("PS5Sink", function()
		return Enum.ContextActionResult.Pass
	end, false, 3000, K.ButtonSelect)
end)

function Input.IsDown(btn)
	return isDown(btn)
end

-- Оси: lx/rx вправо = +1, ly/ry вверх = +1, l2/r2 от 0 до 1.
-- Без геймпада левая ось собирается из стрелок/WASD.
function Input.GetAxes()
	local result = table.clone(axes)
	local kx = (isDown("right") and 1 or 0) - (isDown("left") and 1 or 0)
	local ky = (isDown("up") and 1 or 0) - (isDown("down") and 1 or 0)
	if math.abs(result.lx) < 0.15 then
		result.lx = kx
	end
	if math.abs(result.ly) < 0.15 then
		result.ly = ky
	end
	if isDown("l2") and result.l2 < 0.5 then
		result.l2 = 1
	end
	if isDown("r2") and result.r2 < 0.5 then
		result.r2 = 1
	end
	return result
end

-- Помещает приёмник наверх стека. Возвращает функцию снятия.
function Input.PushSink(fn, name)
	local sink = { fn = fn, name = name }
	table.insert(sinks, sink)
	return function()
		local i = table.find(sinks, sink)
		if i then
			table.remove(sinks, i)
		end
	end
end

function Input.TopSinkName()
	local sink = sinks[#sinks]
	return sink and sink.name
end

-- Вибрация геймпада: сила 0..1, длительность в секундах.
function Input.Rumble(strength, duration)
	local pad = Enum.UserInputType.Gamepad1
	if not HapticService:IsVibrationSupported(pad) then
		return
	end
	pcall(function()
		HapticService:SetMotor(pad, Enum.VibrationMotor.Large, strength or 0.5)
		HapticService:SetMotor(pad, Enum.VibrationMotor.Small, strength or 0.5)
	end)
	task.delay(duration or 0.15, function()
		pcall(function()
			HapticService:SetMotor(pad, Enum.VibrationMotor.Large, 0)
			HapticService:SetMotor(pad, Enum.VibrationMotor.Small, 0)
		end)
	end)
end

-- Подписи кнопок под текущее устройство (для подсказок).
local GLYPHS = {
	gamepad = { cross = "✕", circle = "○", square = "□", triangle = "△", options = "OPTIONS", ps = "PS", l1 = "L1", r1 = "R1", l2 = "L2", r2 = "R2" },
	keyboard = { cross = "Enter", circle = "Backspace", square = "F", triangle = "R", options = "O", ps = "H", l1 = "Q", r1 = "E", l2 = "1", r2 = "3" },
}

function Input.Glyph(btn)
	local set = GLYPHS[Input.LastDevice] or GLYPHS.gamepad
	return set[btn] or string.upper(btn)
end

return Input
