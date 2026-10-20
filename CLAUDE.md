# CLAUDE.md — заметки для Claude Code

Этот файл читается в начале каждой сессии. Держи его актуальным: после каждой заметной
работы дописывай раздел «Журнал» и правь «Известные проблемы». Подробная документация
для людей — в `README.md` (API игр, манифест, управление, Blender-пайплайн).

## Что за игра

**PS5 Sandbox** — Roblox-плейс, где игрок гуляет по своей 3D-«чиллзоне» (двор с костром и
прудом, дом с гостиной), подходит к PS5 у телевизора, жмёт E (удержание 0.25 с) и попадает в
полноэкранный интерфейс «PlayStation 5»: загрузка → выбор пользователя → главный экран
«Игры / Медиа» → библиотека, магазин, трофеи, настройки, центр управления (H). Внутри — мини-игры
(`src/apps/*`: StarPilot, Chess, BlockCraft, NeonDrive, Pong, Snake, 2048 и т.д.).
Прогресс (трофеи, скачанные/сыгранные игры) поднимает уровень чиллзоны, и в доме появляются
новые украшения. Можно ходить в гости к чужим чиллзонам. Сохранения — DataStore.

Весь визуал (модели консоли/геймпада, фоны, обложки) сгенерирован Blender-скриптами из
`blender/` и вшит в код как данные (`src/shared/PS5/Assets/*.luau`, `src/apps/*/art.luau`),
собирается в рантайме через EditableMesh/EditableImage.

## Репозиторий

- Рабочий репо: `origin` → https://github.com/rstarway/ps5 (ветка `main`), коммитим и пушим сюда.
- Оригинал: `upstream` → https://github.com/bullkaesh/Playstation5-roblox-simulator (организация;
  текущий токен `gh` туда не пускает — организация запрещает fine-grained токены сроком > 366 дней).

## Как запускать и тестировать

- Быстрая синхронизация без плагина Rojo: `python -m http.server 34877 --bind 127.0.0.1` в корне
  репо, затем в `execute_luau` (Edit) временно `HttpService.HttpEnabled = true`, `GetAsync` файла →
  `.Source` скрипта, и вернуть `HttpEnabled` как было.
- Синхронизация: Rojo 7.6.1 (`rokit.toml`). `rojo serve` + плагин Rojo в Studio → Connect.
- Пересобрать файл места: `rojo build default.project.json -o PS5Sandbox.rbxlx`
  (после любых правок в `src/` — чтобы `PS5Sandbox.rbxlx` в репо был актуален).
- Тест через Roblox Studio MCP (`mcp__Roblox_Studio__*`): открыть `PS5Sandbox.rbxlx`
  (`RobloxStudioBeta.exe <путь>` открывает новое окно), `start_stop_play`, `screen_capture`,
  `execute_luau` в Client/Server, `user_keyboard_input`.
  - Подсказку PS5 жать как `keyDown E` → wait 600 мс → `keyUp E` (обычный keyPress не срабатывает).
  - Точка PS5 в зоне: `ConsoleSpot` ≈ (-5.5, 4, -16.3) относительно начала участка.
  - `execute_luau` сам откатывает изменения `CameraType` — править камеру из него нельзя.
  - В Studio исходники скриптов с CRLF; при точечной замене через `.Source` нормализуй `\r\n`.
- Без Studio: `tools/` (luau-runner на Rust + мок API Roblox), см. README «Проверка без Studio».

## Архитектура (кратко)

- `src/server/ChillZone.server.luau` — строит шаблон чиллзоны из `Assets/ChillZoneParts`
  + меши Creator Store (это занимает несколько секунд!), клонирует участок каждому игроку
  (`Workspace.ChillZones.Zone_<UserId>`, шаг 520 студов), **сам спавнит персонажей**
  (`CharacterAutoLoads = false`) и возрождает их после смерти, уровни декора, визиты.
- `src/server/PS5Server.server.luau` — DataStore-профили, `PS5Remotes`, атрибуты `PS5Points/PS5Tier/...`.
- `src/client/PS5Client.client.luau` — `UI.Init()`, `ChillZone.Start(UI)`, `Profiles.Start`.
- `src/shared/PS5/` — система: `ChillZone` (клиент: PS5/ТВ/полки/трофеи, вход в PS5),
  `WorldFX` (интро-пролёт камеры, эффекты), `World` (шоурум заставки на высоте 600),
  `UI/*` (экраны), `Runtime` (запуск игр, `ctx`), `Input`, `Data`, `Trophies`, `Progress`, `Registry`.
- `src/apps/<Игра>/` — `manifest.luau` + `init.luau` (`launch(ctx)`), шаблон в `_Template`.

## Стиль

Комментарии и тексты коммитов — по-русски. Отступы табами. Модули возвращают таблицу.
Комментарии короткие и объясняют «почему».

## Известные проблемы / TODO

- Бюджет EditableMesh/EditableImage на клиенте маленький: в Studio влезает ~3 модели из
  `Assets/*Mesh`. `Embedded.Model` поэтому строит каждую модель один раз и отдаёт клоны
  (клоны MeshPart ссылаются на тот же EditableMesh). Новые встроенные модели добавлять с оглядкой.
- Warning `rbxassetid://203785492` / `81504106` — не наши: ассеты аватара/Roblox (`81504106` —
  текстура шляпы аватара). Игнорировать.
- Warning `Player:Move called, but player currently has no humanoid` — от модуля управления до спавна, безвредно.
- На главном экране по умолчанию только Star Pilot; остальные игры ставятся через магазин.
- Идея: модели для чиллзоны/игр можно генерировать через Hunyuan3D-2
  (https://huggingface.co/spaces/tencent/Hunyuan3D-2) → GLB → Blender → `export_luau.py` или импорт в Studio.

## Журнал

- **2026-10-20** — Проект склонирован в `C:\dev\Playstation5-roblox-simulator`, протестирован в Studio.
  Баг «странный старт»: персонаж спавнился до готовности зоны в (0,103,0), падал ниже −500 и
  умирал; интро держало камеру Scriptable, и после него `CameraSubject` оставался на мёртвом
  гуманоиде → камера висела под картой (Y≈−508), видно только небо. Фикс: сервер выключает
  `CharacterAutoLoads` и вызывает `LoadCharacter()` после создания участка (+ ручной респавн),
  `WorldFX.Intro` по завершении привязывает камеру к текущему персонажу. Проверено: спавн
  один раз на участке, интро → камера за игроком, PS5 → загрузка → пользователь → главный
  экран → Star Pilot → центр управления — всё работает, ошибок скриптов нет.
  Добавлены `rokit.toml` (rojo 7.6.1) и этот файл.
- **2026-10-20 (2)** — Консоль/геймпад в заставке PS5 падали в запасной вариант: кончался бюджет
  EditableMesh (каждая PS5 в каждой зоне + заставка строили свои меши). `Embedded.Model` теперь
  кэширует модель и отдаёт клоны. Меши дивана из Creator Store грузятся параллельно (1.9 с → 0.4 с),
  добавлен экран загрузки `ReplicatedFirst.PS5Loading` (`src/client/Loading.client.luau`) вместо
  чёрного экрана до спавна. Проверено в Studio: геймпад и консоль в заставке — MeshPart, предупреждений нет.
