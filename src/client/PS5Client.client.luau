-- Запуск: интерфейс PS5 создаётся выключенным, игрок гуляет по чиллзоне
-- и включает приставку у телевизора.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PS5 = ReplicatedStorage:WaitForChild("PS5")
local UI = require(PS5:WaitForChild("UI"))
local ChillZone = require(PS5:WaitForChild("ChillZone"))

local Profiles = require(PS5:WaitForChild("Profiles"))

require(PS5:WaitForChild("NoGlow")).Start()

UI.Init()
task.spawn(ChillZone.Start, UI)
Profiles.Start(UI, ChillZone)
