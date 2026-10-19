# План потоков

Каждый поток проекта отвечает за одну задачу и меняет только свои файлы. Так потоки не мешают друг другу и не тратят лимиты на чужой код.

## Кто за что отвечает

| Поток | Задача | Свои файлы |
|---|---|---|
| **Система PS5** (поток песочницы) | ядро, интерфейс, API `ctx`, сервер данных, чиллзона и дом | `src/shared/PS5/`, `src/server/`, `src/client/`, `default.project.json`, `tools/`, `README.md` |
| **Визуал / Blender** | модели (консоль, геймпад, комната), фоны, баннеры, обложки, иконки, звуки; после рендера запускает `blender/export_luau.py` | `blender/`, `assets/`, `src/shared/PS5/Assets/`, `cover.luau` в папках игр, значения в `Theme.Images` и `Theme.Sounds` |
| **Игра: Neon Drive** (гонки) | 3D-гонка | `src/apps/NeonDrive/`, `id = "neon_drive"` |
| **Игра: Pixel Quest** (платформер) | 2D-платформер | `src/apps/PixelQuest/`, `id = "pixel_quest"` |
| **Игра: Orbit Strike** (шутер) | космический шутер | `src/apps/OrbitStrike/`, `id = "orbit_strike"` |
| **Игра: Cube Logic** (головоломка) | головоломка | `src/apps/CubeLogic/`, `id = "cube_logic"` |
| **Игра: Rocket Ball** (спорт) | футбол на машинах | `src/apps/RocketBall/`, `id = "rocket_ball"` |
| **Игра: Beat Rush** (ритм) | ритм-игра | `src/apps/BeatRush/`, `id = "beat_rush"` |
| **Классика** (поток песочницы) | простые 2D-игры: Snake, Pong, 2048, Sky Hop, Brick Break | `src/apps/Snake/`, `Pong/`, `Game2048/`, `SkyHop/`, `BrickBreak/` |
| **Игра: BlockCraft** (кубический мир в стиле Minecraft) | в стиле 1.16.5: выживание и творчество, крафт, печь, инструменты до незерита, мобы, Незер и бартер; модули Content, Terrain, World, Mobs | `src/apps/BlockCraft/`, `id = "blockcraft"` |
| **Игра: Night Spider** (герой-паук) | 3D-экшен: полёт на паутине по неоновому городу, бег по стенам, бои с бандитами на вызовах, 20 жетонов на крышах | `src/apps/NightSpider/`, `id = "night_spider"` |
| **Приложение: Музыка** | плеер звуков Roblox | `src/apps/Music/`, `id = "music"`, `category = "media"` |
| **Приложение: Видео** | плеер VideoFrame | `src/apps/Video/`, `id = "video"`, `category = "media"` |

Все игры бесплатные. Будущие игры (Kart Rush, Zombie Night, Sky Royale, Dungeon Delve, Street Ball, Ghost Hotel, Ninja Run, Farm Life) стоят в ряду «Coming Soon» (список `COMING_SOON` в `Store.luau`); когда игру с тем же `id` добавят в `src/apps`, она сама переедет в «Free to Play». Первые шесть игр и уже стоят в PS Store (`src/shared/PS5/UI/Store.luau`, список `FREE_GAMES`) с пометкой «Coming soon». Когда в `src/apps` появляется игра с тем же `id`, в магазине у неё появляется кнопка Download: игрок скачивает игру, и она встаёт на главный экран и в библиотеку. Сразу установлена только игра с `preinstalled = true` в манифесте (Star Pilot). Новую игру вне списка можно добавить с любым свободным `id`.

## Правила для потока игры

1. Создай папку из `src/apps/_Template`, поставь свой `id`, убери `hidden = true`.
2. Меняй только свою папку. Если не хватает возможностей системы (новый метод `ctx`, новый звук), попроси поток «Система PS5», а не правь `src/shared/PS5` сам.
3. Для обложки и картинок попроси поток «Визуал»: он отрендерит их в Blender, а ты вставишь ID в `cover` манифеста.
4. Перед сдачей: проверка синтаксиса и дымовой тест из `tools/` без ошибок, затем `rojo build default.project.json -o PS5Sandbox.rbxlx` и проверка в Studio.
5. Всё, что игра создаёт, держи в `ctx.gui` и `ctx.world`, подписки делай через `ctx.input:On`, `ctx:Loop`, `ctx:Connect`: тогда система сама всё уберёт при выходе.

## Общие файлы

`PS5Sandbox.rbxlx` собирается из `src`, его пересобирает тот, кто последним менял код. Если два потока пересобирают одновременно, достаточно пересобрать ещё раз: файл целиком генерируется из `src`.
