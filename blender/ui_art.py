"""Картинки для интерфейса: фон главного экрана, баннер магазина, обложка Star Pilot.

Результат (assets/renders): home_background.png, store_banner.png, star_pilot_cover.png
После загрузки в Roblox (Asset Manager → Import) вставьте ID в Theme.Images и manifest.cover.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
from common import area_light, box, camera, cylinder, link, material, render, reset, setup_render, world  # noqa: E402


def waves(color_a, color_b, seed=1):
    """Глянцевая волнистая поверхность в стиле фона PS5 и светящиеся частицы."""
    import bmesh
    random.seed(seed)
    bm = bmesh.new()
    nx, ny, sx, sy = 300, 160, 140.0, 80.0
    phase = random.uniform(0, 6)
    rows = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            x = -sx / 2 + sx * i / nx
            y = -10 + sy * j / ny
            z = (1.1 * math.sin(0.22 * x + 0.12 * y + phase)
                 + 0.6 * math.sin(0.09 * x - 0.31 * y + 1.7)
                 + 0.25 * math.sin(0.5 * x + 0.05 * y))
            row.append(bm.verts.new((x, y, z)))
        rows.append(row)
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    mesh = bpy.data.meshes.new("Waves")
    bm.to_mesh(mesh)
    bm.free()
    plane = link(bpy.data.objects.new("Waves", mesh))
    for poly in plane.data.polygons:
        poly.use_smooth = True
    plane.data.materials.append(material("WaveMat", (0.01, 0.02, 0.06), roughness=0.22, metallic=0.85, coat=0.6))

    glow = material("Particle", (1, 1, 1), emission=color_b, strength=8)
    for _ in range(45):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=random.uniform(0.03, 0.09), segments=12, ring_count=6,
                                             location=(random.uniform(-16, 16), random.uniform(0, 30), random.uniform(1.5, 8)))
        bpy.context.active_object.data.materials.append(glow)

    world((color_a[0] * 0.02, color_a[1] * 0.02, color_a[2] * 0.03), 1.0)
    for name, loc, energy, color in (("Back", (0, 70, 12), 9000, color_a), ("Side", (-45, 30, 9), 5000, color_b)):
        light = area_light(name, loc, (0, 10, 0), energy, color, 70)
        light.data.shape = "RECTANGLE"
        light.data.size_y = 2.5


def home_background():
    reset()
    waves((0.1, 0.35, 1.0), (0.55, 0.3, 1.0))
    cam = camera((0, -12, 7), (0, 18, 0), lens=30)
    cam.data.dof.use_dof = True
    cam.data.dof.focus_distance = 22
    cam.data.dof.aperture_fstop = 2.0
    setup_render(1920, 1080, samples=96)
    render("home_background.png")


def store_banner():
    reset()
    waves((0.0, 0.45, 1.0), (1.0, 0.35, 0.6), seed=7)
    camera((6, -12, 6), (0, 18, 0), lens=40)
    setup_render(1600, 500, samples=96)
    render("store_banner.png")


def star_pilot_cover():
    reset()
    random.seed(3)
    world((0.002, 0.002, 0.01), 1.0)
    star = material("Star", (1, 1, 1), emission=(0.8, 0.9, 1.0), strength=20)
    for _ in range(160):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=random.uniform(0.01, 0.04), segments=8, ring_count=4,
                                             location=(random.uniform(-8, 8), random.uniform(6, 14), random.uniform(-8, 8)))
        bpy.context.active_object.data.materials.append(star)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=4.5, segments=64, ring_count=32, location=(3.5, 10, -4.5))
    planet = bpy.context.active_object
    planet.data.materials.append(material("Planet", (0.45, 0.12, 0.6), roughness=0.8))
    for poly in planet.data.polygons:
        poly.use_smooth = True

    hull = material("Hull", (1.0, 0.45, 0.2), roughness=0.25, metallic=0.3, coat=0.6)
    dark = material("Dark", (0.05, 0.05, 0.08), roughness=0.3)
    flame = material("Flame", (1, 1, 1), emission=(0.3, 0.8, 1.0), strength=30)
    ship = link(bpy.data.objects.new("Ship", None))
    parts = []
    bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=0.6, radius2=0.0, depth=1.6, location=(0, 0, 0.8))
    parts.append(bpy.context.active_object)
    parts[-1].data.materials.append(hull)
    parts.append(cylinder("Body", 0.6, 2.0, (0, 0, -1.0), hull, segments=48))
    for i in range(3):
        angle = i * 2 * math.pi / 3
        fin = box(f"Fin{i}", (0.08, 0.9, 1.1), (math.cos(angle) * 0.75, math.sin(angle) * 0.75, -1.7), dark)
        fin.rotation_euler = (0, 0, angle - math.pi / 2)
        parts.append(fin)
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.45, radius2=0.0, depth=1.8, location=(0, 0, -2.9), rotation=(math.pi, 0, 0))
    parts.append(bpy.context.active_object)
    parts[-1].data.materials.append(flame)
    for obj in parts:
        if obj.type == "MESH" and not obj.name.startswith("Fin"):
            for poly in obj.data.polygons:
                poly.use_smooth = True
        obj.parent = ship
    ship.rotation_euler = (math.radians(-15), math.radians(30), 0)

    area_light("Key", (-5, -6, 5), (0, 0, 0), 1500, (1, 0.9, 0.85), 4)
    area_light("Rim", (5, 4, 2), (0, 0, 0), 1500, (0.3, 0.5, 1.0), 4)
    camera((0, -10, 0.5), (0, 0, -0.6), lens=45)
    setup_render(1024, 1024, samples=96)
    render("star_pilot_cover.png")


if __name__ == "__main__":
    home_background()
    store_banner()
    star_pilot_cover()
