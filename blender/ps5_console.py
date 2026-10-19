"""Модель консоли в стиле PS5 (вертикальная) + рендер-«герой».

Результат:
    assets/models/PS5Console.fbx и .glb — части названы по цвету (Fin_White, Core_Black, Light_Blue...),
        World.luau сам раскрашивает их при импорте в ReplicatedStorage.PS5Assets.Console
    assets/renders/console_hero.png — картинка для заставки/магазина
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402  (bpy раньше bmesh)
import bmesh  # noqa: E402
from common import (add_bevel, add_subsurf, area_light, box, camera, cylinder, export, link, material,
                    mesh_object, render, report, reset, setup_render, smooth, world)

HEIGHT = 10.6


def fin(side, mat):
    """Изогнутая боковая панель: сетка по высоте и глубине + толщина (Solidify)."""
    rows, cols = 28, 14
    bm = bmesh.new()
    grid = []
    for i in range(rows + 1):
        z = 0.3 + (HEIGHT - 0.3) * i / rows
        t = z / HEIGHT
        front = -3.55 - 0.95 * t ** 2
        back = 3.45 + 0.45 * t ** 1.5
        row = []
        for j in range(cols + 1):
            u = j / cols
            y = front + (back - front) * u
            x = 1.22 + 0.6 * t ** 2 + 0.14 * math.sin(math.pi * u)
            row.append(bm.verts.new((side * x, y, z)))
        grid.append(row)
    for i in range(rows):
        for j in range(cols):
            quad = [grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]]
            if side < 0:
                quad.reverse()
            bm.faces.new(quad)
    obj = mesh_object(f"Fin_White_{'L' if side < 0 else 'R'}", bm, mat)
    solid = obj.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = 0.28
    solid.offset = 1.0
    add_bevel(obj, 0.06, 2)
    smooth(obj, 50)
    return obj


def build():
    white = material("White", (0.93, 0.93, 0.95), roughness=0.35, coat=0.3)
    black = material("Black", (0.015, 0.015, 0.02), roughness=0.22, coat=0.6)
    blue = material("LightBlue", (0.1, 0.45, 1.0), emission=(0.1, 0.45, 1.0), strength=30.0)

    parts = []
    core = box("Core_Black", (2.2, 7.4, 9.6), (0, 0, 0.35 + 4.8), black, bevel=0.1)
    smooth(core)
    parts.append(core)
    for side in (-1, 1):
        parts.append(fin(side, white))
        light = box(f"Light_Blue_{'L' if side < 0 else 'R'}", (0.05, 7.0, 9.2), (side * 1.14, 0, 0.35 + 4.8), blue)
        parts.append(light)

    # Порты и кнопки на передней грани
    bm = bmesh.new()
    def port(w, h, x, z):
        geom = bmesh.ops.create_cube(bm, size=1.0)
        for v in geom["verts"]:
            v.co.x = v.co.x * w + x
            v.co.y = v.co.y * 0.08 - 3.72
            v.co.z = v.co.z * h + z
    port(0.55, 0.2, 0.0, 1.6)   # USB-A
    port(0.3, 0.12, 0.0, 2.1)   # USB-C
    port(0.9, 0.04, 0.0, 8.7)   # кнопка питания
    port(0.9, 0.04, 0.0, 8.4)   # кнопка извлечения
    ports = mesh_object("Ports_Black", bm, black)
    parts.append(ports)

    stand = cylinder("Stand_Black", 2.6, 0.32, (0, 0, 0.16), black, segments=48, bevel=0.05)
    smooth(stand)
    parts.append(stand)
    return parts


def stage():
    floor_mat = material("Floor", (0.01, 0.012, 0.02), roughness=0.15)
    floor = box("Floor", (80, 80, 0.1), (0, 0, -0.05), floor_mat)
    world((0.004, 0.006, 0.015), 1.0)
    area_light("Key", (-8, -10, 12), (0, 0, 5), 2500, (1, 1, 1), 6)
    area_light("RimBlue", (8, 8, 9), (0, 0, 5), 3000, (0.2, 0.45, 1.0), 5)
    area_light("RimPink", (-9, 7, 6), (0, 0, 4), 1500, (0.8, 0.3, 1.0), 4)
    camera((14, -24, 8.5), (0, 0, 5.2), lens=45)
    return floor


if __name__ == "__main__":
    reset()
    parts = build()
    print("Консоль:")
    report(parts)
    export(parts, "PS5Console")
    stage()
    setup_render(1600, 1000, samples=128)
    render("console_hero.png")
