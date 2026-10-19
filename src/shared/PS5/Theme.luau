-- Визуальная тема системы. Сюда вставляются ID ассетов после загрузки рендеров из Blender.
local rgb = Color3.fromRGB

local Theme = {}

Theme.Font = Enum.Font.BuilderSans
Theme.FontMedium = Enum.Font.BuilderSansMedium
Theme.FontBold = Enum.Font.BuilderSansBold
Theme.FontHeavy = Enum.Font.BuilderSansExtraBold

Theme.Colors = {
	Text = rgb(255, 255, 255),
	SubText = rgb(178, 188, 210),
	Muted = rgb(120, 130, 155),
	Accent = rgb(0, 112, 240), -- фирменный синий
	AccentLight = rgb(72, 160, 255),
	Card = rgb(26, 32, 52),
	CardLight = rgb(44, 52, 80),
	Panel = rgb(16, 20, 36),
	Danger = rgb(230, 70, 80),
	Success = rgb(60, 200, 120),
	Focus = rgb(255, 255, 255),
	Bronze = rgb(205, 127, 50),
	Silver = rgb(192, 200, 212),
	Gold = rgb(240, 196, 70),
	Platinum = rgb(170, 220, 255),
}

-- Фоновые темы главного экрана (настройка «Экран и тема»).
Theme.Backgrounds = {
	{ id = "aurora", name = "Aurora", colors = { rgb(6, 14, 48), rgb(18, 60, 140), rgb(4, 8, 24) } },
	{ id = "ocean", name = "Ocean", colors = { rgb(2, 24, 40), rgb(0, 110, 150), rgb(2, 10, 20) } },
	{ id = "sunset", name = "Sunset", colors = { rgb(40, 8, 40), rgb(160, 60, 90), rgb(20, 6, 20) } },
	{ id = "mono", name = "Graphite", colors = { rgb(14, 14, 18), rgb(46, 48, 58), rgb(6, 6, 8) } },
}

-- Изображения. Пустая строка = встроенный рендер из PS5/Assets (blender/export_luau.py).
-- Можно вставить свой "rbxassetid://<id>" после загрузки картинки в Roblox.
Theme.Images = {
	HomeBackground = "",
	BootLogo = "",
	StoreBanner = "",
}

-- Звуки. Встроенные файлы клиента Roblox; замените на свои rbxassetid при желании.
-- Звуки из Creator Store (бесплатные, проверены в Studio: грузятся). Свои: "rbxassetid://..."
Theme.Sounds = {
	move = "rbxassetid://113085021060403", -- мягкий hover
	confirm = "rbxassetid://122966251252708", -- короткий тап
	back = "rbxassetid://131218019674138", -- закрытие
	open = "rbxassetid://17582213219", -- центр управления, меню
	notify = "rbxassetid://131453611310784",
	trophy = "rbxassetid://93360393539898",
	error = "rbxasset://sounds/collide.wav",
	boot = "rbxassetid://1841209502", -- атмосферное включение (APM)
	powerOff = "rbxassetid://131218019674138",
	shoot = "rbxasset://sounds/swordslash.wav",
	explosion = "rbxasset://sounds/collide.wav",
	hit = "rbxasset://sounds/collide.wav",
}

-- Музыка главного экрана PS5 (тихо, в цикле; выключается в настройках)
Theme.Music = {
	menu = "rbxassetid://140722099430139",
}

-- Звуки мира чиллзоны: id, громкость, радиус слышимости (0 = везде)
Theme.Ambience = {
	night = { id = "rbxassetid://9112764573", volume = 0.35, radius = 0 }, -- сверчки
	campfire = { id = "rbxassetid://121113514638190", volume = 0.9, radius = 45 },
	pond = { id = "rbxassetid://9116203162", volume = 0.7, radius = 35 },
	radio = { id = "rbxassetid://9046863253", volume = 0.35, radius = 30 }, -- музыка в гостиной (APM)
}

Theme.TrophyColors = {
	bronze = Theme.Colors.Bronze,
	silver = Theme.Colors.Silver,
	gold = Theme.Colors.Gold,
	platinum = Theme.Colors.Platinum,
}

Theme.TrophyNames = {
	bronze = "Bronze",
	silver = "Silver",
	gold = "Gold",
	platinum = "Platinum",
}

return Theme
