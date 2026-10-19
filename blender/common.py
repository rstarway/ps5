"""Общие помощники для скриптов Blender песочницы PS5.

Запуск любого скрипта:
    blender -b -P blender/<скрипт>.py          (установленный Blender 4.2+)
    python3 blender/<скрипт>.py                (модуль bpy: pip install bpy)
Результаты: assets/models/*.fbx|*.glb и assets/renders/*.png рядом с папкой blender.
"""
import math
import os
import sys

import bpy
import bmesh

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(ROOT, "assets", "models")
RENDERS = os.path.join(ROOT, "assets", "renders")
os.makedirs(MODELS, exist_ok=True)
os.makedirs(RENDERS, exist_ok=True)

# Быстрый режим для проверки: PS5_PREVIEW=1 рендерит маленькие картинки с малым числом сэмплов.
PREVIEW = os.environ.get("PS5_PREVIEW") == "1"


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    return scene


def material(name, color, roughness=0.4, metallic=0.0, emission=None, strength=0.0, coat=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if coat and "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = coat
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    mat.diffuse_color = (*color, 1.0)  # цвет во вьюпорте и в glTF без нод
    return mat


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def mesh_object(name, bm, mat=None):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = link(bpy.data.objects.new(name, mesh))
    if mat:
        obj.data.materials.append(mat)
    return obj


def extrude_outline(name, points, thickness, axis="X", mat=None):
    """Плоский контур (список (u, v)) выдавливается на thickness вдоль оси."""
    bm = bmesh.new()
    verts = []
    for u, v in points:
        if axis == "X":
            co = (-thickness / 2, u, v)
        elif axis == "Z":
            co = (u, v, -thickness / 2)
        else:
            co = (u, -thickness / 2, v)
        verts.append(bm.verts.new(co))
    face = bm.faces.new(verts)
    # вогнутый контур: режем на треугольники, иначе сглаживание даёт артефакты
    faces = bmesh.ops.triangulate(bm, faces=[face], quad_method="BEAUTY", ngon_method="EAR_CLIP")["faces"]
    offset = {"X": (thickness, 0, 0), "Z": (0, 0, thickness), "Y": (0, thickness, 0)}[axis]
    ext = bmesh.ops.extrude_face_region(bm, geom=faces)
    moved = [g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=offset, verts=moved)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm, mat)


def box(name, size, location=(0, 0, 0), mat=None, bevel=0.0, segments=3):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    obj = mesh_object(name, bm, mat)
    obj.location = location
    if bevel > 0:
        add_bevel(obj, bevel, segments)
    return obj


def cylinder(name, radius, depth, location=(0, 0, 0), mat=None, segments=32, rotation=(0, 0, 0), bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=depth)
    obj = mesh_object(name, bm, mat)
    obj.location = location
    obj.rotation_euler = rotation
    if bevel > 0:
        add_bevel(obj, bevel, 2)
    return obj


def add_bevel(obj, width, segments=3):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.harden_normals = False
    return mod


def add_subsurf(obj, levels=1):
    mod = obj.modifiers.new("Subsurf", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    return mod


def smooth(obj, angle=35):
    for poly in obj.data.polygons:
        poly.use_smooth = True
    if hasattr(obj.data, "set_sharp_from_angle"):
        obj.data.set_sharp_from_angle(angle=math.radians(angle))


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def triangles(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = obj.evaluated_get(depsgraph).to_mesh()
    count = sum(len(p.vertices) - 2 for p in mesh.polygons)
    obj.evaluated_get(depsgraph).to_mesh_clear()
    return count


def report(objects):
    total = 0
    for obj in objects:
        tris = triangles(obj)
        total += tris
        flag = "  <-- больше лимита Roblox 20k" if tris > 20000 else ""
        print(f"  {obj.name}: {tris} треугольников{flag}")
    print(f"  всего: {total}")


def export(objects, basename):
    """FBX и GLB для импорта в Roblox Studio (3D Importer)."""
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    fbx = os.path.join(MODELS, basename + ".fbx")
    glb = os.path.join(MODELS, basename + ".glb")
    bpy.ops.export_scene.fbx(
        filepath=fbx, use_selection=True, apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z", axis_up="Y", use_mesh_modifiers=True, mesh_smooth_type="FACE",
    )
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_apply=True)
    print("Экспорт:", fbx, glb)


def setup_render(width, height, samples=96):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scale = 0.35 if PREVIEW else 1.0
    scene.render.resolution_x = int(width * scale)
    scene.render.resolution_y = int(height * scale)
    scene.render.resolution_percentage = 100
    scene.cycles.samples = 16 if PREVIEW else samples
    scene.cycles.use_denoising = True
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Punchy"
    except TypeError:
        pass
    scene.render.film_transparent = False
    return scene


def world(color, strength=1.0):
    w = bpy.data.worlds.new("World")
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (*color, 1.0)
    bg.inputs["Strength"].default_value = strength
    bpy.context.scene.world = w


def camera(location, target, lens=50):
    cam_data = bpy.data.cameras.new("Camera")
    cam_data.lens = lens
    cam = link(bpy.data.objects.new("Camera", cam_data))
    cam.location = location
    empty = link(bpy.data.objects.new("Target", None))
    empty.location = target
    constraint = cam.constraints.new("TRACK_TO")
    constraint.target = empty
    constraint.track_axis = "TRACK_NEGATIVE_Z"
    constraint.up_axis = "UP_Y"
    bpy.context.scene.camera = cam
    return cam


def area_light(name, location, target, energy, color=(1, 1, 1), size=3.0):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.color = color
    data.size = size
    light = link(bpy.data.objects.new(name, data))
    light.location = location
    constraint = light.constraints.new("TRACK_TO")
    empty = link(bpy.data.objects.new(name + "_T", None))
    empty.location = target
    constraint.target = empty
    constraint.track_axis = "TRACK_NEGATIVE_Z"
    constraint.up_axis = "UP_Y"
    return light


def render(filename):
    path = os.path.join(RENDERS, filename)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("Рендер:", path)
    return path
