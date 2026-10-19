# PS5 Sandbox для Roblox

Песочница с интерфейсом PS5 внутри Roblox. Игрок появляется в 3D-чиллзоне (двор с костром, прудом и гирляндами, дом с гостиной). В гостиной стоит PS5 у телевизора: подходишь, жмёшь E, и запускается весь интерфейс консоли. В доме есть стенд трофеев и полка игр игрока, они обновляются сами после игры. Интерфейс: включение с 3D-пролётом вокруг консоли, выбор пользователя, главный экран «Игры / Медиа», центр управления по кнопке PS, библиотека, магазин, трофеи, настройки, сохранения в DataStore. Игры и приложения подключаются как отдельные модули, каждый в своей папке, поэтому их можно делать в отдельных потоках проекта, не трогая систему.

Визуал (модель консоли, геймпад, фон главного экрана, баннер магазина, обложки) генерируется скриптами Blender из папки `blender/` и уже встроен в код: модели собираются в игре через EditableMesh, картинки через EditableImage. Ничего загружать в Roblox вручную не нужно.

## Быстрый старт

**Вариант 1, без установки инструментов.** Откройте `PS5Sandbox.rbxlx` в Roblox Studio и нажмите Play.
Чтобы работали сохранения: Game Settings → Security → *Enable Studio Access to API Services* (место нужно сначала опубликовать). Без этого всё работает, но данные живут до выхода.

**Вариант 2, с живой синхронизацией кода (Rojo).**
1. Установите Rojo 7 (`cargo install rojo` или aftman/rokit) и плагин Rojo в Studio.
2. В папке проекта: `rojo serve`.
3. В Studio откройте пустое место → плагин Rojo → Connect. Код из `src/` сразу попадает в игру.
4. Пересобрать файл места: `rojo build default.project.json -o PS5Sandbox.rbxlx`.

## Чиллзона и дом

| Где | Что |
|---|---|
| Гостиная, PS5 у телевизора | E (или кнопка на геймпаде/тач): «Играть на PS5», камера наезжает на экран, включается интерфейс |
| Центр управления → «Выключить PS5 и встать» | интерфейс гаснет, игрок снова ходит по миру |
| Зал славы (правая часть дома) | стеклянный шкаф с трофеями: открытые светятся цветом грейда, закрытые тёмные; рядом табло с уровнем и счётом |
| Полка игр (задняя стена) | коробки игр, в которые играл; E на коробке сразу запускает игру на PS5 |

Мир целиком описан в `blender/chillzone.py`: дом, двор, столкновения (`solid`), свет, таблички и метки (`ConsoleSpot`, `TrophySlot`, `GameSlot`, `SpawnPoint`). После правок запустите `python3 blender/export_luau.py chillzone`, он пишет `Assets/ChillZoneParts.luau`. Планировка: от точки появления прямая дорожка ко входу; в доме по центру телевизор, PS5 и диван, слева MY GAMES, справа MY TROPHIES; во дворе костёр слева, пруд справа. `src/server/ChillZone.server.luau` только кладёт землю, строит детали и ставит модели из Creator Store по списку `Assets/CreatorStore.luau` (сейчас диван; если меш не загрузился, остаётся диван из Blender). PS5, телевизор, подсказки и коллекцию игрока ставит клиент `src/shared/PS5/ChillZone.luau`. Если модели `ChillZone` в Workspace нет, интерфейс включается сразу, как раньше.

### Свои чиллзоны, уровни и профили

- У каждого игрока своя чиллзона: `Workspace.ChillZones.Zone_<UserId>`, участки идут через 520 студов (0, +1, −1, +2…). Сервер строит шаблон из Blender один раз и копирует его на участок, на табличке над входом имя хозяина.
- Очки прогресса (`src/shared/PS5/Progress.luau`): трофеи (бронза 15, серебро 30, золото 90, платина 300), 40 за каждую скачанную игру и 20 за каждую игру, в которую играли. Уровни чиллзоны: 1 Cabin (0), 2 Cozy (60), 3 Garden (200), 4 Neon Nights (500), 5 Luxury (1000), 6 Legend (1800).
- Украшения уровней описаны в `blender/chillzone.py` внутри `with tier(n):` (функция `upgrades()`); в выгрузке это 19-я колонка. Детали выше уровня хозяина лежат в `ServerStorage.ChillZoneTiers` и плавно появляются при повышении. Если очки упали (удалил игру), они снова прячутся.
- `PS5Server` считает публичный профиль и ставит игроку атрибуты `PS5Points`, `PS5Tier`, `PS5Trophies`, `PS5Games`, `PS5ProfileVersion`. Полный профиль отдаёт `PS5Remotes.GetPublicProfile(userId)`.
- `src/shared/PS5/Profiles.luau`: при наведении мыши на игрока появляются подсветка и карточка, клик или тап открывает профиль с трофеями и наградами по играм и кнопкой «Visit Chill Zone» (`PS5Remotes.VisitZone`). В гостях сверху плашка «Go home». В чужой чиллзоне на полках коллекция хозяина.
- Чтобы участков не было слишком много, поставьте в настройках игры небольшое число игроков на сервер (например 8).

## Управление

| PS5 | Геймпад в Roblox | Клавиатура |
|---|---|---|
| ✕ | A / ✕ | Enter, Пробел |
| ○ (назад) | B / ○ | Backspace |
| □ | X / □ | F |
| △ | Y / △ | R |
| L1 / R1 | L1 / R1 | Q / E |
| L2 / R2 | L2 / R2 (аналог) | 1 / 3 |
| OPTIONS | Start / Options | O |
| Кнопка PS | Select / Create | H, Home, Tab |
| Стик, крестовина | левый стик, D-pad | стрелки, WASD |

Мышь и тач тоже работают: наведение выделяет, клик нажимает. Настоящая кнопка PS и Esc заняты самим Roblox, поэтому роль кнопки PS выполняет Select/Create (на клавиатуре H).

## Структура

```
default.project.json        дерево Rojo
PS5Sandbox.rbxlx            готовый файл места (собран из src)
src/shared/PS5/             система (ReplicatedStorage.PS5)
  ChillZone                 PS5 у телевизора, трофеи и игры в доме (клиент)
  Input, Audio, Data, Registry, Runtime, Trophies, Nav, World, Theme, Util, Signal
  UI/                       экраны: Boot, Users, Home, Library, Store, Trophies, Settings,
                            ControlCenter, Modal, Toasts, Splash, Components, AppMenu
src/apps/                   игры и приложения (ReplicatedStorage.PS5Apps)
  StarPilot/                пример игры
  _Template/                шаблон для новой игры (скрыт в системе)
src/server/PS5Server        DataStore: профили, сохранения, трофеи
src/server/ChillZone        3D-мир из Blender + модели Creator Store
src/client/PS5Client        запуск оболочки и чиллзоны
blender/                    скрипты моделей и картинок
assets/models, assets/renders   результаты Blender (FBX/GLB/PNG)
tools/                      проверка Luau и дымовой тест без Studio
THREADS.md                  какой поток за что отвечает
```

## Как добавить игру

1. Скопируйте `src/apps/_Template` в `src/apps/<ИмяИгры>`.
2. В `manifest.luau` задайте свой `id` (латиница, цифры, `_`, `-`), название, цвета, трофеи и **удалите `hidden = true`**.
3. Пишите игру в `init.luau`: модуль возвращает таблицу с функцией `launch(ctx)`.
4. Перезапустите Play. Игра сама появится на главном экране, в библиотеке, магазине и трофеях.

Больше ничего регистрировать не нужно: система читает каждую папку в `PS5Apps`, где есть `manifest`.

### Манифест

```lua
return {
	id = "neon_drive",             -- обязательно, уникально
	title = "Neon Drive",          -- обязательно
	category = "game",             -- game | media | app (media и app идут во вкладку «Медиа»)
	genre = "Гонки",
	developer = "Студия",
	version = "1.0",
	order = 10,                    -- порядок в списках (меньше = раньше)
	description = "Текст для главного экрана и магазина",
	icon = "🏎",                   -- символ/эмодзи или "rbxassetid://..."
	cover = "rbxassetid://...",    -- обложка плитки (необязательно)
	colors = { "#FF3D7F", "#3A0CA3" }, -- градиент плитки и фона
	transparentGui = false,        -- true: ctx.gui прозрачный (видно 3D-мир)
	controls = { { "✕", "Газ" }, { "□", "Тормоз" } },
	trophies = {
		{ id = "first_win", name = "Первая победа", description = "...", grade = "bronze" }, -- bronze|silver|gold|platinum
		{ id = "secret", name = "...", description = "...", grade = "gold", hidden = true },
		{ id = "platinum", name = "...", description = "Все трофеи", grade = "platinum" }, -- выдаётся автоматически
	},
}
```

Манифест читают и клиент, и сервер, поэтому в нём только данные, без кода.

## API игры: объект `ctx`

```lua
local Game = {}
function Game.launch(ctx)
	local canvas = ctx.ui.canvas(ctx.gui)      -- холст 1920×1080, вписанный в экран
	ctx:Loop(function(dt) ... end)             -- кадр игры, на паузе не вызывается
end
return Game
```

| Поле / метод | Что делает |
|---|---|
| `ctx.manifest` | манифест игры |
| `ctx.user` | `{ id, name, color }` текущего пользователя PS5 |
| `ctx.gui` | Frame на весь экран для 2D (по умолчанию чёрный фон) |
| `ctx.world` | Folder в Workspace для 3D-объектов |
| `ctx.camera` | камера; после выхода система восстанавливает её |
| `ctx.ui` | помощники GUI: `new`, `text`, `corner`, `padding`, `list`, `stroke`, `gradient`, `tween`, `canvas`, `hex` |
| `ctx.theme` | цвета и шрифты системы |
| `ctx.paused` | true, пока игра на паузе (открыт центр управления) |
| **Ввод** | |
| `ctx.input:On("press" \| "release" \| "repeat", fn(btn))` | события кнопок: `cross circle square triangle l1 r1 l2 r2 l3 r3 up down left right options create touchpad` |
| `ctx.input:IsDown(btn)` | кнопка зажата |
| `ctx.input:WasPressed(btn)` | нажата с прошлого вызова (для игрового цикла) |
| `ctx.input:GetAxes()` | `{ lx, ly, rx, ry, l2, r2 }`: стики −1..1 (вверх = +), курки 0..1; без геймпада lx/ly из стрелок/WASD |
| `ctx.input:Rumble(сила, секунды)` | вибрация (учитывает настройку) |
| `ctx.input:Glyph(btn)` | подпись кнопки под текущее устройство («✕» или «Enter») |
| `ctx.input:Device()` | `keyboard`, `gamepad` или `touch` |
| **Сохранения** | хранятся отдельно для каждого пользователя PS5, в DataStore |
| `ctx.save:Get(key, default)` / `:Set(key, value)` / `:Remove(key)` / `:All()` | значения: числа, строки, булевы, таблицы без Instance и Color3 |
| **Трофеи** | |
| `ctx.trophies:Unlock(id)` | выдаёт трофей с уведомлением; повторный вызов ничего не делает |
| `ctx.trophies:IsUnlocked(id)` / `:List()` | состояние |
| **Звук** | |
| `ctx.audio:Play(имя или id, { volume, pitch, looped })` | системные имена: `move confirm back notify trophy error shoot explosion hit`, или `"rbxassetid://..."`, или число |
| `ctx.audio:PlayMusic(id, volume)` / `:StopAll()` | музыка в цикле, остановка всего |
| **Жизненный цикл** | |
| `ctx:Loop(fn(dt))` | вызывается каждый кадр, кроме паузы |
| `ctx:On("pause" \| "resume" \| "exit", fn)` | события системы |
| `ctx:Connect(signal, fn)` | подписка, которая сама отключится при выходе |
| `ctx:Notify(заголовок, текст)` | уведомление PS5 в углу экрана |
| `ctx:Exit()` | выйти на главный экран |

Кнопку PS игра не получает: она открывает центр управления и ставит игру на паузу. При выходе система сама удаляет `ctx.gui`, `ctx.world`, подписки и звуки.

**2D-игры** рисуют в `ctx.ui.canvas(ctx.gui)` в координатах 1920×1080 (см. Star Pilot). **3D-игры** кладут модели в `ctx.world`, ставят `ctx.camera.CameraType = Scriptable` и управляют камерой (см. `_Template`). Персонаж игрока стоит в чиллзоне, его управление на время работы PS5 отключено; если игре нужен свой герой, создавайте модель в `ctx.world` и двигайте её сами.

## Визуал из Blender

Скрипты работают в Blender 4.2+ (`blender -b -P blender/ps5_console.py`) или как модуль Python (`pip install bpy`, затем `python3 blender/ps5_console.py`). `PS5_PREVIEW=1` даёт быстрый черновой рендер.

| Скрипт | Результат |
|---|---|
| `ps5_console.py` | `assets/models/PS5Console.fbx/.glb`, `assets/renders/console_hero.png` |
| `dualsense.py` | `assets/models/DualSense.fbx/.glb`, `assets/renders/controller_hero.png` |
| `ui_art.py` | `home_background.png`, `store_banner.png`, `star_pilot_cover.png` |
| `export_luau.py` | встраивает всё это в код: `src/shared/PS5/Assets/*.luau`, `src/apps/StarPilot/cover.luau` |

После изменения моделей или картинок запустите `python3 blender/export_luau.py` и пересоберите `PS5Sandbox.rbxlx`.

Фоны и обложки игр для главного экрана рисует `blender/game_art.py` (по сцене на игру). `python3 blender/export_luau.py art` пишет `src/apps/<Игра>/art.luau` (фон 320x180) и `cover.luau`. В манифесте игры поля `art = "art"` и `cover = "cover"`; главный экран плавно меняет фон на `art` выбранной игры.

Как это работает в игре: `PS5/Embedded.luau` собирает сетки в MeshPart (детали красятся по типу: белый пластик, чёрный глянец, синий неон) и картинки в EditableImage. Если движок не разрешит Editable-объекты, система тихо перейдёт на запасной вариант: консоль из деталей и градиентный фон.

Если захотите обычные загруженные ассеты (лучше качество картинок, меньше работы при запуске):
1. Консоль: Import 3D → `assets/models/PS5Console.fbx`, модель назовите `Console` и положите в `ReplicatedStorage.PS5Assets`. Она заменит встроенную.
2. Картинки: Asset Manager → Import → PNG, вставьте ID в `Theme.Images` или в `cover` манифеста.

Обложка игры в манифесте: `cover = "cover"` берёт модуль-картинку `cover.luau` из папки игры, `cover = "rbxassetid://..."` берёт загруженную картинку.

## Проверка без Studio

`tools/` содержит проверку синтаксиса Luau и дымовой тест: имитация API Roblox, которая строит чиллзону, включает PS5 через подсказку у консоли, проходит загрузку, выбор пользователя, запуск Star Pilot, центр управления, все экраны, трофеи, питание и автосохранение.

```
cd tools/luau-runner && cargo build --release && cd ../..
tools/luau-runner/target/release/luau-runner $(find src -name '*.luau')   # синтаксис
tools/luau-runner/target/release/luaurun tools/mock/smoke_test.lua .        # дымовой тест
```

Имитация не заменяет Studio: раскладку, шрифты и физику проверяйте в Play.

## Известные ограничения

- Встроенные картинки уменьшены (фон 400×225), чтобы не раздувать код; для чёткой картинки загрузите PNG как ассет.
- Звуки системы взяты из встроенных файлов клиента Roblox (`rbxasset://sounds/...`); для «настоящих» звуков загрузите свои и пропишите ID в `Theme.Sounds`.
- Эмодзи на значках зависят от шрифтов устройства; для точного вида используйте картинки (`icon = "rbxassetid://..."`).
- Сервер проверяет только путь и размер данных; трофеи не защищены от подделки клиентом. Для песочницы этого достаточно.
