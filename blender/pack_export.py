"""Готовая модель (assets/hunyuan/ready/<Name>.glb) -> файлы для продажи пака.

    blender -b -P blender/pack_export.py -- <ready.glb> <Name> <height_m> [--out assets/pack/out]

Масштабирует модель до реальной высоты (метры), низ по центру в начало координат, «перед» на +Y в Blender
(= +Z в glTF), пишет <out>/glb/<Name>.glb, <out>/fbx/<Name>.fbx и превью <out>/previews/<Name>.png
на одном и том же фоне и свете, чтобы пак выглядел единым.
"""
import math
import os
import sys

import bpy
from mathutils import Vector


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    src, name, height = argv[0], argv[1], float(argv[2])
    out = os.path.abspath(argv[argv.index("--out") + 1] if "--out" in argv else "assets/pack/out")
    src = os.path.abspath(src)
    for sub in ("glb", "fbx", "previews"):
        os.makedirs(os.path.join(out, sub), exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    root = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(root)
    for o in meshes:
        o.parent = root
    bpy.context.view_layer.update()

    def bounds():
        vs = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
        return (Vector((min(v[i] for v in vs) for i in range(3))), Vector((max(v[i] for v in vs) for i in range(3))))

    lo, hi = bounds()
    k = height / (hi.z - lo.z)
    root.scale = (k, k, k)
    bpy.context.view_layer.update()
    lo, hi = bounds()
    root.location = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    bpy.context.view_layer.update()
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    root.select_set(True)

    bpy.ops.export_scene.gltf(filepath=os.path.join(out, "glb", name + ".glb"), export_format="GLB", use_selection=True)
    bpy.ops.export_scene.fbx(filepath=os.path.join(out, "fbx", name + ".fbx"), use_selection=True, path_mode="COPY",
                             embed_textures=True, apply_unit_scale=True)

    # превью: единый фон и свет
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_EEVEE"
    scn.render.resolution_x = scn.render.resolution_y = 1024
    scn.render.film_transparent = False
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.93, 0.91, 0.88, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scn.world = world
    # AgX по умолчанию выцветает: чёрный металл становится серым, фон — грязным
    scn.view_settings.view_transform = "Standard"
    scn.view_settings.look = "None"
    lo, hi = bounds()
    c = (lo + hi) / 2
    size = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    d = size * 2.4
    cam.location = c + Vector((d * 0.75, -d * 0.85, d * 0.55))
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.camera = cam
    for loc, energy in (((3, -3, 5), 90), ((-4, -2, 3), 35)):
        light = bpy.data.objects.new("L", bpy.data.lights.new("L", "AREA"))
        light.data.energy = energy * max(size, 1) ** 2
        light.data.size = 4
        light.location = loc
        light.rotation_euler = (math.radians(50), 0, math.radians(35))
        scn.collection.objects.link(light)
    scn.render.filepath = os.path.join(out, "previews", name + ".png")
    bpy.ops.render.render(write_still=True)
    print("PACK", name, "h=%.2f m" % height)


main()
