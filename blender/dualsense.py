"""Геймпад в стиле DualSense: корпус, тачпад, стики, кнопки, световая полоса + рендер.

Результат: assets/models/DualSense.fbx|.glb, assets/renders/controller_hero.png
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
from common import (add_bevel, add_subsurf, area_light, box, camera, cylinder, export, extrude_outline,  # noqa: E402
                    material, render, report, reset, setup_render, smooth, world)

HALF = [(0, 1.3), (2.2, 1.35), (2.8, 1.1), (3.05, 0.5), (3.0, -0.6), (2.8, -1.8), (2.5, -2.55),
        (2.0, -2.75), (1.6, -2.45), (1.3, -1.4), (0.9, -0.95), (0, -0.85)]


def catmull_rom(points, steps=6):
    """Сглаживает замкнутый контур сплайном Катмулла-Рома."""
    out = []
    n = len(points)
    for i in range(n):
        p0, p1, p2, p3 = points[i - 1], points[i], points[(i + 1) % n], points[(i + 2) % n]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(
                0.5 * (2 * p1[k] + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                       + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3)
                for k in range(2)))
    return out


def mirrored(half):
    left = [(-x, y) for x, y in reversed(half) if x != 0]
    return list(half) + left


def build():
    white = material("White", (0.92, 0.92, 0.94), roughness=0.45)
    black = material("Black", (0.02, 0.02, 0.025), roughness=0.35, coat=0.3)
    glow = material("LightBlue", (0.1, 0.45, 1.0), emission=(0.1, 0.45, 1.0), strength=25.0)
    parts = []

    outline = catmull_rom(mirrored(HALF))
    body = extrude_outline("Body_White", outline, 0.9, axis="Z", mat=white)
    add_bevel(body, 0.36, 6)
    smooth(body, 60)
    parts.append(body)

    center = extrude_outline("Center_Black", [(-1.5, 1.05), (1.5, 1.05), (1.35, -0.75), (0.9, -1.0), (-0.9, -1.0), (-1.35, -0.75)], 0.12, axis="Z", mat=black)
    center.location.z = 0.42
    add_bevel(center, 0.08, 3)
    parts.append(center)

    pad = box("Touchpad_Black", (2.2, 1.0, 0.1), (0, 0.65, 0.52), black, bevel=0.08)
    parts.append(pad)
    for side in (-1, 1):
        parts.append(box(f"Light_Blue_{'L' if side < 0 else 'R'}", (0.06, 0.9, 0.05), (side * 1.16, 0.65, 0.52), glow))

    for side in (-1, 1):
        stick = cylinder(f"Stick_Black_{'L' if side < 0 else 'R'}", 0.32, 0.35, (side * 0.78, -0.45, 0.62), black, segments=32, bevel=0.06)
        smooth(stick)
        parts.append(stick)

    # Кнопки действий справа и крестовина слева
    for i, (dx, dy) in enumerate([(0, 0.38), (0.38, 0), (0, -0.38), (-0.38, 0)]):
        btn = cylinder(f"Button_Black_{i}", 0.15, 0.1, (2.1 + dx, 0.35 + dy, 0.5), black, segments=24, bevel=0.03)
        smooth(btn)
        parts.append(btn)
        parts.append(box(f"Dpad_Black_{i}", (0.24 if dx == 0 else 0.3, 0.3 if dx == 0 else 0.24, 0.08), (-2.1 + dx * 0.9, 0.35 + dy * 0.9, 0.5), black, bevel=0.03))

    parts.append(cylinder("PSButton_Black", 0.12, 0.06, (0, -0.55, 0.5), black, segments=24))
    for side in (-1, 1):
        trigger = box(f"Trigger_Black_{'L' if side < 0 else 'R'}", (0.9, 0.5, 0.35), (side * 2.1, 1.35, 0.1), black, bevel=0.12)
        parts.append(trigger)
    return parts


if __name__ == "__main__":
    reset()
    parts = build()
    print("Геймпад:")
    report(parts)
    export(parts, "DualSense")
    box("Floor", (60, 60, 0.1), (0, 0, -0.5), material("Floor", (0.01, 0.012, 0.02), roughness=0.2))
    world((0.004, 0.006, 0.015))
    area_light("Key", (-4, -6, 8), (0, 0, 0), 900, (1, 1, 1), 4)
    area_light("RimBlue", (5, 5, 4), (0, 0, 0), 900, (0.2, 0.45, 1.0), 3)
    area_light("RimPink", (-6, 4, 3), (0, 0, 0), 500, (0.8, 0.3, 1.0), 3)
    camera((0, -9, 7.5), (0, -0.3, 0), lens=50)
    setup_render(1600, 1000, samples=128)
    render("controller_hero.png")
