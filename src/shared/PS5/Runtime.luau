-- Жизненный цикл приложений и объект ctx, который получает игра.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Signal = require(script.Parent.Signal)
local Util = require(script.Parent.Util)
local Theme = require(script.Parent.Theme)
local Input = require(script.Parent.Input)
local Audio = require(script.Parent.Audio)
local Data = require(script.Parent.Data)
local Trophies = require(script.Parent.Trophies)
local Registry = require(script.Parent.Registry)

local Runtime = {}
Runtime.Started = Signal.new() -- (manifest)
Runtime.Paused = Signal.new() -- (manifest)
Runtime.Resumed = Signal.new() -- (manifest)
Runtime.Closed = Signal.new() -- (manifest)
Runtime.Notify = Signal.new() -- (title, text, manifest)

local appLayer = nil
local current = nil -- { manifest, ctx, state = "running" | "paused" }

function Runtime.Init(gui)
	appLayer = gui
end

function Runtime.Current()
	return current and current.manifest, current and current.state
end

local function createContext(manifest)
	local events = { pause = Signal.new(), resume = Signal.new(), exit = Signal.new() }
	local inputEvents = { press = Signal.new(), release = Signal.new(), ["repeat"] = Signal.new() }
	local connections = {}
	local pressedSince = {}
	local camera = Workspace.CurrentCamera
	local cameraState = { type = camera.CameraType, cframe = camera.CFrame, fov = camera.FieldOfView }

	local gui = Util.new("Frame", {
		Name = manifest.id,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = manifest.transparentGui and 1 or 0,
		ClipsDescendants = true,
		Parent = appLayer,
	})
	local world = Instance.new("Folder")
	world.Name = "PS5App_" .. manifest.id
	world.Parent = Workspace

	local ctx = {
		manifest = manifest,
		user = table.clone(Data.CurrentUser() or { id = "u1", name = "Player" }),
		gui = gui, -- Frame на весь экран: сюда рисуется 2D-интерфейс игры
		world = world, -- Folder в Workspace: сюда кладутся 3D-объекты игры
		camera = camera, -- текущая камера; после выхода состояние восстанавливается
		ui = Util, -- помощники построения GUI
		theme = Theme,
		paused = false,
		_closed = false,
	}

	-- Ввод
	ctx.input = {}
	function ctx.input:On(event, fn)
		local conn = inputEvents[event]:Connect(fn)
		table.insert(connections, conn)
		return conn
	end
	function ctx.input:IsDown(btn)
		return Input.IsDown(btn)
	end
	function ctx.input:WasPressed(btn)
		-- true, если кнопку нажали с прошлого вызова (удобно в игровом цикле)
		local v = pressedSince[btn] == true
		pressedSince[btn] = nil
		return v
	end
	function ctx.input:GetAxes()
		return Input.GetAxes()
	end
	function ctx.input:Rumble(strength, duration)
		if Data.Setting("vibration") then
			Input.Rumble(strength, duration)
		end
	end
	function ctx.input:Glyph(btn)
		return Input.Glyph(btn)
	end
	function ctx.input:Device()
		return Input.LastDevice
	end

	-- Сохранения (по пользователю и приложению, хранятся в DataStore)
	ctx.save = {}
	function ctx.save:Get(key, default)
		local value = Data.AppSaves(manifest.id)[key]
		if value == nil then
			return default
		end
		return value
	end
	function ctx.save:Set(key, value)
		assert(type(key) == "string", "save key must be a string")
		Data.Set(Data.UserPath("saves", manifest.id, key), value)
	end
	function ctx.save:Remove(key)
		Data.Set(Data.UserPath("saves", manifest.id, key), nil)
	end
	function ctx.save:All()
		return table.clone(Data.AppSaves(manifest.id))
	end

	-- Трофеи
	ctx.trophies = {}
	function ctx.trophies:Unlock(id)
		return Trophies.Unlock(manifest, id)
	end
	function ctx.trophies:IsUnlocked(id)
		return Trophies.IsUnlocked(manifest, id)
	end
	function ctx.trophies:List()
		return Trophies.List(manifest)
	end

	-- Звук
	local sounds = {}
	ctx.audio = {}
	function ctx.audio:Play(nameOrId, options)
		local s = Audio.Play(nameOrId, options)
		table.insert(sounds, s)
		return s
	end
	function ctx.audio:PlayMusic(nameOrId, volume)
		return ctx.audio:Play(nameOrId, { looped = true, volume = volume or 0.35 })
	end
	function ctx.audio:StopAll()
		for _, s in sounds do
			if s.Parent then
				s:Destroy()
			end
		end
		table.clear(sounds)
	end

	-- Жизненный цикл
	function ctx:On(event, fn)
		local conn = events[event]:Connect(fn)
		table.insert(connections, conn)
		return conn
	end
	function ctx:Connect(signal, fn)
		local conn = signal:Connect(fn)
		table.insert(connections, conn)
		return conn
	end
	-- Игровой цикл: fn(dt) каждый кадр, на паузе не вызывается
	function ctx:Loop(fn)
		local conn = RunService.RenderStepped:Connect(function(dt)
			if not ctx.paused and not ctx._closed then
				local ok, err = pcall(fn, math.min(dt, 0.1))
				if not ok then
					warn(`[{manifest.id}] Error in game loop: {err}`)
				end
			end
		end)
		table.insert(connections, conn)
		return conn
	end
	function ctx:Notify(title, text)
		Runtime.Notify:Fire(title, text, manifest)
	end
	function ctx:Exit()
		Runtime.Close()
	end

	ctx._events = events
	ctx._input = function(event, btn)
		if event == "press" then
			pressedSince[btn] = true
		end
		inputEvents[event]:Fire(btn)
	end
	ctx._destroy = function()
		ctx._closed = true
		events.exit:Fire()
		for _, conn in connections do
			pcall(conn.Disconnect, conn)
		end
		ctx.audio:StopAll()
		gui:Destroy()
		world:Destroy()
		camera.CameraType = cameraState.type
		camera.CFrame = cameraState.cframe
		camera.FieldOfView = cameraState.fov
	end
	return ctx
end

-- Запуск: если та же игра на паузе — продолжает, другая — закрывается.
function Runtime.Launch(id)
	local manifest = Registry.Get(id)
	if not manifest then
		warn("[PS5] No app " .. tostring(id))
		return false
	end
	if current then
		if current.manifest.id == id then
			Runtime.Resume()
			return true
		end
		Runtime.Close()
	end
	local ok, app = pcall(require, manifest.module)
	if not ok or type(app) ~= "table" or type(app.launch) ~= "function" then
		warn(`[PS5] {id}: module must return a table with a launch(ctx) function. {app}`)
		return false
	end
	local ctx = createContext(manifest)
	local popSink = Input.PushSink(function(event, btn)
		if current and current.ctx == ctx and not ctx.paused then
			ctx._input(event, btn)
		end
	end, "app:" .. id)
	current = { manifest = manifest, ctx = ctx, popSink = popSink, state = "running" }
	appLayer.Enabled = true
	Data.MarkPlayed(id)
	Runtime.Started:Fire(manifest)
	task.spawn(function()
		local success, err = pcall(app.launch, ctx)
		if not success then
			warn(`[PS5] {id}: launch error: {err}`)
			Runtime.Notify:Fire("App error", tostring(err), manifest)
			Runtime.Close()
		end
	end)
	return true
end

function Runtime.Pause()
	if not current or current.state == "paused" then
		return
	end
	current.state = "paused"
	current.ctx.paused = true
	current.ctx._events.pause:Fire()
	Runtime.Paused:Fire(current.manifest)
end

function Runtime.Resume()
	if not current or current.state ~= "paused" then
		return
	end
	current.state = "running"
	current.ctx.paused = false
	appLayer.Enabled = true
	current.ctx._events.resume:Fire()
	Runtime.Resumed:Fire(current.manifest)
end

-- Скрыть игру (уход на главный экран), не закрывая её.
function Runtime.Hide()
	Runtime.Pause()
	appLayer.Enabled = false
end

function Runtime.Close()
	if not current then
		return
	end
	local closing = current
	current = nil
	closing.popSink()
	pcall(closing.ctx._destroy)
	appLayer.Enabled = false
	Runtime.Closed:Fire(closing.manifest)
end

return Runtime
