-- Точка входа SDK. Игры получают всё нужное через ctx (см. README), этот модуль —
-- для системного кода и инструментов.
local PS5 = {
	Version = require(script.Version),
	Signal = require(script.Signal),
	Theme = require(script.Theme),
	Util = require(script.Util),
	Input = require(script.Input),
	Audio = require(script.Audio),
	Registry = require(script.Registry),
}

-- Данные и запуск доступны только на клиенте.
if game:GetService("RunService"):IsClient() then
	PS5.Data = require(script.Data)
	PS5.Trophies = require(script.Trophies)
	PS5.Runtime = require(script.Runtime)
	PS5.Nav = require(script.Nav)
	PS5.World = require(script.World)
end

return PS5
