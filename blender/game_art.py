"""Key art for every sandbox game: a 16:9 render per game (home screen background, store banner)
and a square crop for the tile cover.

    python3 blender/game_art.py [id ...]       # renders assets/renders/<id>_art.png
    python3 blender/export_luau.py art         # writes src/apps/<Folder>/art.luau and cover.luau

All art is original: simple stylised scenes in the spirit of each game.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
from common import area_light, box, camera, cylinder, link, material, render, reset, setup_render, world  # noqa: E402

GAMES = {
    # id: (app folder, scene function name)
    "star_pilot": "StarPilot",
    "neon_drive": "NeonDrive",
    "rocket_ball": "RocketBall",
    "pixel_quest": "PixelQuest",
    "orbit_strike": "OrbitStrike",
    "cube_logic": "CubeLogic",
    "beat_rush": "BeatRush",
}


def rgb(hexstr):
    h = hexstr.lstrip("#")
    return tuple((int(h[i:i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4))


def glow(name, color, strength=8):
    return material(name, color, emission=color, strength=strength)


def sphere(name, radius, location, mat, segments=32, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, segments=segments, ring_count=segments // 2, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    for poly in obj.data.polygons:
        poly.use_smooth = True
    obj.data.materials.append(mat)
    return obj


def stars(count=300, radius=60, seed=3):
    random.seed(seed)
    mat = glow("Star", (1, 1, 1), 6)
    for _ in range(count):
        a, b = random.uniform(0, math.tau), random.uniform(-0.2, 1.2)
        loc = (math.cos(a) * radius, math.sin(a) * radius + 30, b * radius * 0.5)
        sphere("Star", random.uniform(0.03, 0.12), loc, mat, segments=6)


def car(x, y, z, body, light_color, yaw=0.0, scale=1.0):
    parts = []
    parts.append(box("Body", (2.0 * scale, 4.2 * scale, 0.7 * scale), (x, y, z + 0.6 * scale), body, bevel=0.15 * scale))
    parts.append(box("Cabin", (1.6 * scale, 2.0 * scale, 0.6 * scale), (x, y - 0.3 * scale, z + 1.2 * scale),
                     material("Glass", (0.02, 0.03, 0.05), roughness=0.05, metallic=0.5), bevel=0.2 * scale))
    tire = material("Tire", (0.02, 0.02, 0.02), roughness=0.6)
    for dx in (-1.05, 1.05):
        for dy in (-1.4, 1.4):
            parts.append(cylinder("Wheel", 0.45 * scale, 0.4 * scale, (x + dx * scale, y + dy * scale, z + 0.45 * scale), tire,
                                  rotation=(0, math.pi / 2, 0)))
    tail = glow("Tail", light_color, 20)
    for dx in (-0.7, 0.7):
        parts.append(box("Tail", (0.5 * scale, 0.1 * scale, 0.15 * scale), (x + dx * scale, y - 2.12 * scale, z + 0.75 * scale), tail))
    if yaw:
        pivot = link(bpy.data.objects.new("CarPivot", None))
        pivot.location = (x, y, z)
        for p in parts:
            p.parent = pivot
            p.location = (p.location.x - x, p.location.y - y, p.location.z - z)
        pivot.rotation_euler = (0, 0, yaw)
        return pivot
    return parts


# ---------------------------------------------------------------- scenes
def star_pilot():
    world((0.004, 0.002, 0.012))
    stars()
    hull = material("Hull", (0.8, 0.82, 0.86), roughness=0.3, metallic=0.6)
    box("Ship", (1.2, 4.0, 0.6), (0, 0, 0), hull, bevel=0.25)
    box("Wing", (5.0, 1.4, 0.15), (0, -0.6, 0), hull, bevel=0.1)
    box("Cockpit", (0.7, 1.2, 0.5), (0, 0.8, 0.35), material("Canopy", (0.05, 0.3, 0.9), roughness=0.05), bevel=0.2)
    for dx in (-0.4, 0.4):
        cylinder("Flame", 0.16, 0.9, (dx, -2.4, 0), glow("Flame", rgb("#FF6B35"), 25), rotation=(math.pi / 2, 0, 0))
    rock = material("Rock", (0.25, 0.2, 0.18), roughness=0.9)
    random.seed(5)
    for _ in range(14):
        sphere("Asteroid", random.uniform(0.4, 2.2), (random.uniform(-14, 14), random.uniform(6, 30), random.uniform(-5, 6)), rock,
               segments=10, scale=(1, random.uniform(0.7, 1.2), random.uniform(0.6, 1)))
    sphere("Planet", 9, (14, 40, -6), material("Planet", rgb("#2B0F54"), roughness=0.7))
    area_light("Key", (-8, -6, 8), (0, 0, 0), 900, rgb("#FF9F6B"), 6)
    area_light("Rim", (8, 10, 4), (0, 0, 0), 700, rgb("#7A5CFF"), 6)
    camera((-3.5, -9, 2.8), (0.5, 2, 0), lens=32)


def neon_drive():
    world((0.02, 0.004, 0.04))
    ground = material("Asphalt", (0.01, 0.01, 0.015), roughness=0.25, metallic=0.3)
    box("Road", (60, 200, 0.1), (0, 60, -0.05), ground)
    pink, purple = glow("Pink", rgb("#FF3D7F"), 10), glow("Purple", rgb("#7B2CFF"), 8)
    for x in (-6, 6):
        box("Edge", (0.15, 200, 0.05), (x, 60, 0.02), pink)
    for i in range(30):
        box("Dash", (0.12, 2.5, 0.03), (0, i * 6, 0.02), glow("Dash", (1, 1, 1), 3))
    random.seed(9)
    tower = material("Tower", (0.02, 0.015, 0.04), roughness=0.4, metallic=0.4)
    for side in (-1, 1):
        for i in range(14):
            h = random.uniform(8, 30)
            x = side * random.uniform(11, 22)
            y = 10 + i * 9
            box("Tower", (random.uniform(4, 7), random.uniform(4, 7), h), (x, y, h / 2), tower)
            for k in range(int(h // 3)):
                box("Window", (0.1, 3.5, 0.2), (x - side * 2.6, y, 2 + k * 3), pink if (i + k) % 3 else purple)
    sphere("Sun", 14, (0, 170, 12), glow("Sun", rgb("#FF7AB6"), 4))
    car(0.0, 6, 0, material("Paint", rgb("#3A0CA3"), roughness=0.15, metallic=0.7, coat=1.0), rgb("#FF2050"))
    area_light("Key", (6, -4, 6), (0, 6, 0), 1500, rgb("#FF3D7F"), 6)
    area_light("Fill", (-6, 2, 5), (0, 6, 0), 800, rgb("#4CC9F0"), 6)
    camera((3.2, -4.5, 2.2), (0, 14, 1.2), lens=26)


def rocket_ball():
    world((0.005, 0.02, 0.06))
    box("Pitch", (60, 90, 0.1), (0, 20, -0.05), material("Turf", (0.02, 0.18, 0.06), roughness=0.8))
    line = glow("Line", (1, 1, 1), 2)
    box("Mid", (60, 0.3, 0.02), (0, 20, 0.01), line)
    cylinder("Circle", 8, 0.02, (0, 20, 0.01), glow("Ring", (1, 1, 1), 2), segments=64)
    cylinder("CircleIn", 7.7, 0.03, (0, 20, 0.012), material("Turf2", (0.02, 0.18, 0.06), roughness=0.8), segments=64)
    blue = glow("Goal", rgb("#00B4D8"), 10)
    for x in (-7, 7):
        box("Post", (0.4, 0.4, 6), (x, 60, 3), blue)
    box("Bar", (14.4, 0.4, 0.4), (0, 60, 6), blue)
    ball = sphere("Ball", 3.2, (2, 26, 5.5), material("Ball", (0.85, 0.87, 0.9), roughness=0.3, metallic=0.2))
    ball.rotation_euler = (0.3, 0.2, 0.5)
    for i in range(8):
        a = i / 8 * math.tau
        sphere("Panel", 0.9, (2 + math.cos(a) * 2.6, 26 + math.sin(a) * 2.0 - 1.4, 5.5 + math.sin(a * 2) * 1.6),
               glow("Panel", rgb("#00B4D8"), 6), segments=12, scale=(1, 0.4, 1))
    pivot = car(-3, 16, 2.2, material("Paint", rgb("#F8961E"), roughness=0.2, metallic=0.6, coat=1.0), rgb("#FF4020"), yaw=-0.5, scale=1.2)
    pivot.rotation_euler = (0.35, 0.1, -0.5)
    cylinder("Boost", 0.5, 3, (-1.4, 13.2, 1.4), glow("Boost", rgb("#FF8C1A"), 30), rotation=(1.2, 0, -0.5))
    for i, x in enumerate((-30, 30)):
        box("Stand", (4, 90, 14), (x, 20, 7), material("Stand", (0.03, 0.04, 0.08), roughness=0.6))
        for k in range(12):
            box("Lamp", (0.3, 2, 0.6), (x * 0.93, -10 + k * 7, 14.2), glow("Lamp", (1, 1, 1), 20))
    area_light("Sky", (0, 20, 30), (0, 20, 0), 6000, (0.8, 0.9, 1.0), 30)
    camera((-9, -6, 4.5), (2, 26, 4), lens=26)


def pixel_quest():
    world(rgb("#4CC9F0"), 0.9)
    random.seed(4)
    grass = material("Grass", rgb("#43AA8B"), roughness=0.8)
    dirt = material("Dirt", (0.25, 0.14, 0.07), roughness=0.9)
    heights = [0, 0, 1, 1, 1, 2, 2, 1, 1, 0, 0, 1, 3, 3, 2, 1, 1, 1, 2, 2]
    for i, h in enumerate(heights):
        x = -20 + i * 2
        for k in range(h + 3):
            box("Block", (2, 6, 2), (x, 10, -4 + k * 2), grass if k == h + 2 else dirt, bevel=0.05)
    sphere("Cap", 1.6, (-6, 10, 5.0), material("Cap", rgb("#E63946"), roughness=0.4), scale=(1, 1, 0.65))
    cylinder("Stem", 0.7, 1.6, (-6, 10, 4.0), material("Stem", (0.9, 0.85, 0.75), roughness=0.6))
    for dx, dz in ((-0.7, 5.6), (0.6, 5.4), (0.0, 6.0)):
        sphere("Dot", 0.3, (-6 + dx, 9.0, dz), material("Dot", (1, 1, 1), roughness=0.5), segments=10)
    gold = material("Coin", rgb("#FFD166"), roughness=0.25, metallic=1.0)
    for i in range(6):
        cylinder("Coin", 0.6, 0.15, (-2 + i * 2.2, 9, 7 + math.sin(i) * 0.8), gold, rotation=(math.pi / 2, 0, 0.4))
    cloud = material("Cloud", (1, 1, 1), roughness=0.9)
    for cx, cz in ((-12, 14), (6, 16), (16, 12)):
        for k in range(3):
            box("Cloud", (2, 2, 2), (cx + k * 2, 20, cz + (1 if k == 1 else 0)), cloud)
    box("Hero", (1.2, 1.2, 2.0), (2, 9, 5.0), material("Hero", rgb("#3A86FF"), roughness=0.4), bevel=0.1)
    box("HeroHead", (1.2, 1.2, 1.0), (2, 9, 6.5), material("Skin", (0.95, 0.75, 0.6), roughness=0.5), bevel=0.1)
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 4
    link(bpy.data.objects.new("Sun", sun)).rotation_euler = (0.8, 0.2, 0.4)
    camera((-3, -5, 6.5), (-3, 10, 5.2), lens=28)


def orbit_strike():
    world((0.003, 0.002, 0.01))
    stars(seed=8)
    sphere("Planet", 12, (14, 50, -10), material("Planet", rgb("#F8961E"), roughness=0.6))
    sphere("Atmos", 12.6, (14, 50, -10), material("Atmos", rgb("#F8961E"), roughness=1, emission=rgb("#F8961E"), strength=0.4))
    hull = material("Station", (0.7, 0.72, 0.78), roughness=0.35, metallic=0.7)
    bpy.ops.mesh.primitive_torus_add(major_radius=5, minor_radius=0.6, location=(3, 18, 2), rotation=(1.2, 0.2, 0))
    ring = bpy.context.active_object
    ring.data.materials.append(hull)
    cylinder("Core", 1.2, 5, (3, 18, 2), hull, rotation=(1.2, 0.2, 0))
    win = glow("Window", rgb("#FFD166"), 10)
    for i in range(12):
        a = i / 12 * math.tau
        sphere("Light", 0.18, (3 + math.cos(a) * 5, 18 + math.sin(a) * 1.8, 2 + math.sin(a) * 4.6), win, segments=8)
    red = glow("Drone", rgb("#FF3030"), 12)
    dark = material("DroneHull", (0.05, 0.05, 0.06), roughness=0.4, metallic=0.6)
    random.seed(12)
    for _ in range(7):
        loc = (random.uniform(-9, -2), random.uniform(6, 14), random.uniform(-2, 5))
        sphere("Drone", 0.6, loc, dark, segments=8, scale=(1.4, 1, 0.5))
        sphere("Eye", 0.2, (loc[0] + 0.4, loc[1] - 0.4, loc[2]), red, segments=8)
        box("Laser", (0.06, 6, 0.06), (loc[0] + 2.5, loc[1] + 2.5, loc[2] - 0.5), glow("Laser", rgb("#4CC9F0"), 25))
    area_light("Sun", (10, -10, 10), (3, 18, 2), 3000, (1, 0.9, 0.8), 8)
    camera((-6, -7, 2.5), (0, 14, 1.5), lens=28)


def cube_logic():
    world(rgb("#14213D"), 0.5)
    tile = material("Tile", (0.6, 0.7, 0.85), roughness=0.3, metallic=0.1)
    path = [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2), (3, 2), (4, 2), (4, 3), (4, 4), (5, 4), (6, 4), (6, 5)]
    for i, (gx, gy) in enumerate(path):
        box("Tile", (1.9, 1.9, 0.4), (gx * 2 - 6, gy * 2, -0.2 - (i % 3) * 0.05), tile, bevel=0.08)
    ex = path[-1]
    box("Exit", (1.7, 1.7, 0.1), (ex[0] * 2 - 6, ex[1] * 2, 0.05), glow("Exit", rgb("#4CC9F0"), 10))
    cube = box("Cube", (2, 2, 4), (path[3][0] * 2 - 6, path[3][1] * 2, 2.0), material("Cube", rgb("#F72585"), roughness=0.2, metallic=0.2, coat=1.0), bevel=0.15)
    cube.rotation_euler = (0.25, 0, 0)
    random.seed(2)
    deco = material("Deco", rgb("#4CC9F0"), roughness=0.3)
    for _ in range(18):
        b = box("Float", (0.6, 0.6, 0.6), (random.uniform(-14, 14), random.uniform(4, 26), random.uniform(-6, 8)), deco, bevel=0.05)
        b.rotation_euler = (random.uniform(0, 3), random.uniform(0, 3), random.uniform(0, 3))
    area_light("Key", (-6, -6, 10), (0, 4, 0), 2000, (1, 0.95, 0.9), 10)
    area_light("Rim", (8, 14, 6), (0, 4, 0), 1200, rgb("#4CC9F0"), 8)
    camera((-9, -9, 9), (1, 5, 0), lens=34)


def beat_rush():
    world((0.02, 0.003, 0.04))
    lanes = (rgb("#F72585"), rgb("#B5179E"), rgb("#7209B7"), rgb("#4CC9F0"))
    box("Highway", (10, 120, 0.1), (0, 50, -0.05), material("Highway", (0.01, 0.005, 0.02), roughness=0.2, metallic=0.4))
    for i in range(5):
        box("Divider", (0.06, 120, 0.03), (-5 + i * 2.5, 50, 0.02), glow("Divider", (0.8, 0.6, 1), 3))
    random.seed(6)
    for k in range(26):
        lane = random.randrange(4)
        box("Note", (2.1, 0.6, 0.35), (-3.75 + lane * 2.5, 6 + k * 4, 0.2), glow(f"Note{lane}", lanes[lane], 14), bevel=0.1)
    box("HitLine", (10, 0.25, 0.05), (0, 2, 0.03), glow("Hit", (1, 1, 1), 15))
    for i in range(24):
        h = 2 + abs(math.sin(i * 0.7)) * 14
        box("EQ", (1.6, 1.6, h), (-24 + i * 2.1, 90, h / 2), glow("EQ", lanes[i % 4], 5))
    for side in (-1, 1):
        box("Speaker", (3, 3, 6), (side * 9, 20, 3), material("Speaker", (0.03, 0.03, 0.04), roughness=0.5), bevel=0.2)
        cylinder("Cone", 1.1, 0.2, (side * 9, 18.4, 4), glow("Cone", lanes[0], 4), rotation=(math.pi / 2, 0, 0))
    camera((0, -6, 4), (0, 26, 0.5), lens=24)


def render_game(game_id):
    reset()
    setup_render(960, 540, samples=48)
    globals()[game_id]()
    return render(f"{game_id}_art.png")


if __name__ == "__main__":
    ids = [a for a in sys.argv[1:] if a in GAMES] or list(GAMES)
    for game_id in ids:
        render_game(game_id)
