-- Звук: общий SoundGroup с громкостью системы. Игры используют ctx.audio.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Audio = {}

local master = Instance.new("SoundGroup")
master.Name = "PS5Master"
master.Volume = 0.7
master.Parent = SoundService

local ui = Instance.new("SoundGroup")
ui.Name = "PS5Interface"
ui.Parent = master

local music = Instance.new("SoundGroup")
music.Name = "PS5Music"
music.Parent = master

-- Звуки мира (чиллзона) не зависят от громкости PS5, но приглушаются, пока она включена
local world = Instance.new("SoundGroup")
world.Name = "World"
world.Volume = 1
world.Parent = SoundService

Audio.Master = master
Audio.World = world
Audio.UiEnabled = true
Audio.MusicEnabled = true

local function resolve(nameOrId)
	if type(nameOrId) == "number" then
		return "rbxassetid://" .. nameOrId
	end
	return Theme.Sounds[nameOrId] or nameOrId
end

-- Audio.Play("shoot") или Audio.Play("rbxassetid://123", { volume = 0.5, pitch = 1.2, looped = true })
function Audio.Play(nameOrId, options, group)
	options = options or {}
	local sound = Instance.new("Sound")
	sound.SoundId = resolve(nameOrId)
	sound.Volume = options.volume or 0.5
	sound.PlaybackSpeed = options.pitch or 1
	sound.Looped = options.looped == true
	sound.SoundGroup = group or master
	sound.Parent = options.parent or SoundService
	sound:Play()
	if not sound.Looped then
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		task.delay(options.maxLength or 15, function()
			if sound.Parent then
				sound:Destroy()
			end
		end)
	end
	return sound
end

-- Звуки интерфейса (отключаются в настройках).
function Audio.Ui(name)
	if not Audio.UiEnabled then
		return
	end
	-- Стиль PS5: тихие, мягкие клики; при движении по плиткам тон слегка «гуляет», чтобы не надоедал
	local volume = ({ move = 0.22, tab = 0.3, confirm = 0.45, launch = 0.5, back = 0.35, open = 0.32, trophy = 0.6, boot = 0.7, powerOff = 0.4 })[name] or 0.45
	local pitch = ({ powerOff = 0.8, tab = 0.86, launch = 0.72 })[name] or 1
	if name == "move" then
		pitch = 0.97 + math.random() * 0.08
	end
	local sound = ({ tab = "move", launch = "confirm" })[name] or name
	Audio.Play(sound, { volume = volume, pitch = pitch }, ui)
	if name == "launch" then
		-- запуск игры: короткий клик и низкий «вдох» следом
		Audio.Play("open", { volume = 0.28, pitch = 0.6 }, ui)
	end
end

-- Музыка главного экрана: плавно включается и гаснет
local menuSound
function Audio.MenuMusic(on)
	on = on and Audio.MusicEnabled
	if on then
		if not menuSound then
			menuSound = Instance.new("Sound")
			menuSound.Name = "MenuMusic"
			menuSound.SoundId = Theme.Music.menu
			menuSound.Looped = true
			menuSound.Volume = 0
			menuSound.SoundGroup = music
			menuSound.Parent = SoundService
		end
		if not menuSound.IsPlaying then
			menuSound:Resume()
		end
		TweenService:Create(menuSound, TweenInfo.new(2), { Volume = 0.22 }):Play()
	elseif menuSound and menuSound.IsPlaying then
		local sound = menuSound
		local fade = TweenService:Create(sound, TweenInfo.new(0.8), { Volume = 0 })
		fade.Completed:Connect(function()
			if sound.Volume < 0.01 then
				sound:Pause()
			end
		end)
		fade:Play()
	end
end

-- Приглушить звуки мира, пока игрок сидит за PS5
function Audio.DuckWorld(on)
	TweenService:Create(world, TweenInfo.new(1.2), { Volume = on and 0.2 or 1 }):Play()
end

function Audio.SetVolume(value)
	master.Volume = math.clamp(value, 0, 1)
end

return Audio
