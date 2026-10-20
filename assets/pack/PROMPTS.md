# Пак «Cozy Patio» — план и промпты

Стиль: минимализм, тёплый дуб, кремовая ткань, чёрный матовый металл, терракота, зелень.
Сайт Hunyuan (文生3D) принимает до 150 символов; китайский текст вмещает в разы больше деталей, поэтому
промпты китайские: описание предмета + якорь стиля. Параметры: 50k граней, текстура «通用».
Готовые строки лежат в `prompts_zh.json`.

## Якорь (в конец каждого промпта)

```
，极简现代风格，暖橡木，奶油亚麻布，哑光黑金属，单个物体，纯白背景，无地面
```

## Уже есть (Hunyuan → ready/*.glb, *.rbxm)

Lounger, OutdoorSofa, Umbrella, SideTable, Armchair, FloorLamp, PottedPlant, Boxwood, Grass, ShadeTree, HillPine.
Car в пак НЕ входит (из Creator Store).

## Нужно сгенерировать (13)

| # | Имя | Описание (перед якорем) | Высота, м |
|---|---|---|---|
| 1 | Daybed | outdoor daybed with canopy frame and thick cream cushion (англ., проба) | 2.1 |
| 2 | PotOlive | 圆形赤陶花盆里的小橄榄树，细树干，银绿色狭长叶片，树冠蓬松圆润 | 1.2 |
| 3 | LavenderPot | 低矮长方形水泥花盆，种满紫色薰衣草，花穗修长，灰绿色叶片 | 0.6 |
| 4 | CherryTree | 年轻樱花树，细长深褐色树干，树冠圆润，开满浅粉色花朵，底部带土壤 | 3.5 |
| 5 | HotTub | 圆形木桶浴缸，竖条橡木板外壳，黑色金属箍，奶油色保温盖半掀开，侧面有小台阶 | 0.9 |
| 6 | BBQIsland | 户外厨房岛台，嵌入式烤炉，橡木台面，黑色柜门，侧面有置物架 | 1.0 |
| 7 | Sculpture | 抽象极简石雕，光滑弧形曲面，米白色石灰岩，立在低矮黑色长方形基座上 | 1.4 |
| 8 | CoffeeTable | 低矮圆形户外茶几，橡木桌面，三根黑色金属细腿 | 0.4 |
| 9 | Pouf | 圆形编织坐墩，奶油色粗绳编织表面，橡木短圆柱底座 | 0.45 |
| 10 | BarCart | 户外酒水推车，两层橡木搁板，黑色金属框架，四个小轮，摆着酒瓶和玻璃杯 | 0.95 |
| 11 | GardenLantern | 悬挂式花园灯笼，黑色金属框架，四面玻璃，内有一支白蜡烛，顶部有吊环 | 0.45 |
| 12 | Firewood | 整齐码放的劈柴架，黑色金属框架，橡木柴堆，堆叠紧密 | 1.0 |
| 13 | FlowerBed | 长方形橡木抬高种植箱，种着粉色白色黄色小花，绿叶茂盛 | 0.6 |

## Порядок работы по каждой модели

1. Сайт Hunyuan (文生3D), 4 варианта, выбрать лучший (чистая форма, текстура без каши).
2. Скачать GLB → `assets/hunyuan/<name>.glb`.
3. `blender -b -P blender/prep_asset.py -- assets/hunyuan/<name>.glb assets/hunyuan/ready/<Name>.glb --tris 18000 --yaw N`
4. `blender -b -P blender/pack_export.py -- assets/hunyuan/ready/<Name>.glb <Name> <высота_м>`
   → `assets/pack/out/glb|fbx|previews`. Для Roblox: `python tools/roblox_upload.py ...` → .rbxm.

## Статус

Готово (GLB+FBX): Daybed.
Генерация идёт: PotOlive (2 задачи, 8 вариантов), LavenderPot.
