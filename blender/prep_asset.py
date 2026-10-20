"""Готовит модель из Hunyuan3D (GLB) к загрузке в Roblox.

    blender -b -P blender/prep_asset.py -- <in.glb> <out.glb> [--tris 18000] [--yaw 0] [--info]

Склеивает все сетки в одну, упрощает до лимита Roblox (20 000 треугольников на MeshPart),
ставит основание модели в начало координат (низ по центру), поворачивает на yaw градусов вокруг
вертикали (так, чтобы «перед» модели смотрел на +Z в Roblox) и сохраняет GLB с текстурами.
Размер не важен: сервер сам масштабирует модель под нужную высоту или длину.
"""
import argparse
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("src")
    p.add_argument("dst", nargs="?")
    p.add_argument("--tris", type=int, default=18000)
    p.add_argument("--yaw", type=float, default=0.0)
    p.add_argument("--info", action="store_true")
    return p.parse_args(argv)


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def main():
    a = args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a.src)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    before = sum(tri_count(o) for o in meshes)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    # убираем родителей (узлы glTF) и запекаем трансформации
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.context.scene.objects):
        if o is not obj:
            bpy.data.objects.remove(o)
    mats = [s.material.name for s in obj.material_slots if s.material]
    if a.info or not a.dst:
        lo = Vector([min(v.co[i] for v in obj.data.vertices) for i in range(3)])
        hi = Vector([max(v.co[i] for v in obj.data.vertices) for i in range(3)])
        print(f"INFO tris={before} materials={mats} size(blender x,y,z)={tuple(round(x, 3) for x in hi - lo)}")
        if not a.dst:
            return
    if before > a.tris:
        mod = obj.modifiers.new("Decimate", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = a.tris / before
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    # yaw вокруг вертикали (Blender Z = Roblox Y); Roblox +Z = Blender -Y
    obj.data.transform(Matrix.Rotation(math.radians(a.yaw), 4, "Z"))
    lo = Vector([min(v.co[i] for v in obj.data.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in obj.data.vertices) for i in range(3)])
    shift = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    obj.data.transform(Matrix.Translation(-shift))
    obj.location = (0, 0, 0)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(obj.data)
    bm.free()
    after = tri_count(obj)
    size = hi - lo
    # Roblox всё равно хранит текстуры не больше 1024×1024: уменьшаем заранее, чтобы файл был лёгким
    for img in bpy.data.images:
        w, h = img.size
        if max(w, h) > 1024:
            k = 1024 / max(w, h)
            img.scale(int(w * k), int(h * k))
    bpy.ops.export_scene.gltf(filepath=a.dst, export_format="GLB", use_selection=False, export_apply=True)
    print(f"DONE tris {before} -> {after}, size(blender x,y,z)={tuple(round(x, 3) for x in size)}, materials={mats}")


main()
