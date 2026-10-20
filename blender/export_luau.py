"""Встраивает визуал из Blender прямо в код Roblox, чтобы ничего не загружать вручную.

    python3 blender/export_luau.py      (или blender -b -P blender/export_luau.py)

Модели → src/shared/PS5/Assets/ConsoleMesh.luau, ControllerMesh.luau (вершины, нормали, треугольники;
в игре собираются через EditableMesh). Картинки → src/shared/PS5/Assets/*.luau и
src/apps/StarPilot/cover.luau (уменьшенный RGB в base64; в игре — EditableImage).
Запускайте после изменения ps5_console.py, dualsense.py или ui_art.py.
"""
import base64
import importlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import common  # noqa: E402

ASSETS = os.path.join(common.ROOT, "src", "shared", "PS5", "Assets")
os.makedirs(ASSETS, exist_ok=True)


def kind_of(name):
    for kind in ("Light", "White", "Black"):
        if kind in name:
            return kind
    return "Black"


def export_mesh(module_name, out_name, title):
    common.reset()
    module = importlib.import_module(module_name)
    parts = module.build()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    groups = {}
    for obj in parts:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.transform(obj.matrix_world)
        mesh.calc_loop_triangles()
        normals = [tuple(n.vector) for n in mesh.corner_normals]
        g = groups.setdefault(kind_of(obj.name), {"v": [], "n": [], "t": [], "vi": {}, "ni": {}})
        for tri in mesh.loop_triangles:
            ids = []
            for loop in tri.loops:
                co = mesh.vertices[mesh.loops[loop].vertex_index].co
                # Blender (Z вверх) → Roblox (Y вверх): (x, y, z) → (x, z, -y)
                pos = (round(co.x, 3), round(co.z, 3), round(-co.y, 3))
                nx, ny, nz = normals[loop]
                nor = (round(nx, 2), round(nz, 2), round(-ny, 2))
                if pos not in g["vi"]:
                    g["vi"][pos] = len(g["v"]) + 1
                    g["v"].append(pos)
                if nor not in g["ni"]:
                    g["ni"][nor] = len(g["n"]) + 1
                    g["n"].append(nor)
                ids.append((g["vi"][pos], g["ni"][nor]))
            if len({v for v, _ in ids}) == 3:  # схлопнутые фаской треугольники пропускаем
                g["t"].extend(ids)
        evaluated.to_mesh_clear()

    def nums(values):
        return ",".join(("%g" % x) for v in values for x in v)

    lines = [f"-- Сгенерировано blender/export_luau.py из {module_name}.py. Не редактировать вручную.",
             f"-- {title}: вершины (x,y,z), нормали, треугольники (вершина, нормаль) × 3.", "return {"]
    total = 0
    for kind, g in groups.items():
        tris = len(g["t"]) // 3
        total += tris
        assert tris <= 20000 and len(g["v"]) <= 60000, f"{kind}: слишком большая сетка"
        flat_t = ",".join(f"{v},{n}" for v, n in g["t"])
        lines.append(f'\t{{ kind = "{kind}", v = {{{nums(g["v"])}}}, n = {{{nums(g["n"])}}}, t = {{{flat_t}}} }},')
        print(f"  {out_name}.{kind}: {len(g['v'])} вершин, {tris} треугольников")
    lines.append("}")
    path = os.path.join(ASSETS, out_name + ".luau")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"{path}: {total} треугольников, {os.path.getsize(path) // 1024} КБ")


def export_scene(module_name, out_name, title, max_tris=18000):
    """Scene with style keys (obj["rbx"]): one MeshPart per key, with color, material and box-projected UVs."""
    common.reset()
    module = importlib.import_module(module_name)
    objects = module.build()
    styles = module.STYLES
    depsgraph = bpy.context.evaluated_depsgraph_get()
    chunks = {}

    def chunk_for(key):
        lst = chunks.setdefault(key, [])
        if not lst or len(lst[-1]["t"]) // 3 >= max_tris:
            lst.append({"v": [], "n": [], "u": [], "t": [], "vi": {}, "ni": {}, "ui": {}})
        return lst[-1]

    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.transform(obj.matrix_world)
        mesh.calc_loop_triangles()
        normals = [tuple(n.vector) for n in mesh.corner_normals]
        g = chunk_for(obj["rbx"])
        for tri in mesh.loop_triangles:
            corners = []
            for loop in tri.loops:
                co = mesh.vertices[mesh.loops[loop].vertex_index].co
                corners.append(((round(co.x, 2), round(co.z, 2), round(-co.y, 2)), normals[loop]))
            if len({p for p, _ in corners}) < 3:
                continue
            fn = tri.normal
            ax, ay, az = abs(fn.x), abs(fn.z), abs(fn.y)  # Roblox axes
            ids = []
            for pos, (nx, ny, nz) in corners:
                nor = (round(nx, 2), round(nz, 2), round(-ny, 2))
                # box projection, one texture tile every 8 studs
                if ay >= ax and ay >= az:
                    uv = (pos[0], pos[2])
                elif ax >= az:
                    uv = (pos[2], pos[1])
                else:
                    uv = (pos[0], pos[1])
                uv = (round(uv[0] / 8, 2), round(uv[1] / 8, 2))
                for table, index, value in ((g["v"], g["vi"], pos), (g["n"], g["ni"], nor), (g["u"], g["ui"], uv)):
                    if value not in index:
                        index[value] = len(table) + 1
                        table.append(value)
                ids.append((g["vi"][pos], g["ni"][nor], g["ui"][uv]))
            g["t"].extend(ids)
        evaluated.to_mesh_clear()

    def nums(values):
        return ",".join(("%g" % x) for v in values for x in v)

    lines = [f"-- Generated by blender/export_luau.py from {module_name}.py. Do not edit by hand.",
             f"-- {title}: per style key: color, material, vertices, normals, uvs, triangles (v, n, uv) x 3.", "return {"]
    total = 0
    for key, lst in chunks.items():
        rgb, material, transparency = styles[key]
        for g in lst:
            tris = len(g["t"]) // 3
            total += tris
            assert tris <= 20000 and len(g["v"]) <= 60000, f"{key}: mesh too big"
            flat_t = ",".join(f"{v},{n},{u}" for v, n, u in g["t"])
            lines.append(f'\t{{ kind = "{key}", color = {{{rgb[0]},{rgb[1]},{rgb[2]}}}, material = "{material}", '
                         f'transparency = {transparency}, v = {{{nums(g["v"])}}}, n = {{{nums(g["n"])}}}, '
                         f'uv = {{{nums(g["u"])}}}, t = {{{flat_t}}} }},')
    lines.append("}")
    path = os.path.join(ASSETS, out_name + ".luau")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"{path}: {total} triangles, {len(lines) - 3} parts, {os.path.getsize(path) // 1024} KB")


def _luau_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return ("%.3f" % v).rstrip("0").rstrip(".")
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(v, (tuple, list)):
        return "{" + ",".join(_luau_value(x) for x in v) + "}"
    if isinstance(v, dict):
        return "{ " + ", ".join(f"{k} = {_luau_value(x)}" for k, x in v.items() if x is not None) + " }"
    raise TypeError(v)


def _luau_special(row, spec):
    return _luau_value(dict(row=row, **spec))


def _axis_box(obj, pos, rot, size):
    """World AABB of a Block whose rotation is a multiple of 90° (else None)."""
    import itertools
    ext = [0.0, 0.0, 0.0]
    for i in range(3):
        for j in range(3):
            v = abs(rot[i][j])
            if 1e-3 < v < 1 - 1e-3:
                return None
            ext[i] += v * size[j] / 2
    return [(pos[i] - ext[i], pos[i] + ext[i]) for i in range(3)]


def check_quality(module, objects, boxes):
    """Fails the export on z-fighting (two visible blocks sharing an overlapping face plane) and on asset spots
    that overlap each other or a solid part. boxes: list of (obj, aabb) for axis-aligned blocks."""
    problems = []
    visible = [(o, b) for o, b in boxes if module.STYLES[o["rbx"]][2] < 1 and not o.hide_render]
    eps = 1e-3
    for a in range(len(visible)):
        oa, ba = visible[a]
        for b in range(a + 1, len(visible)):
            ob, bb = visible[b]
            # quick reject: boxes must touch or overlap
            if any(ba[i][1] < bb[i][0] - eps or bb[i][1] < ba[i][0] - eps for i in range(3)):
                continue
            for axis in range(3):
                for side in (0, 1):
                    if abs(ba[axis][side] - bb[axis][side]) > eps:
                        continue
                    others = [i for i in range(3) if i != axis]
                    area = 1.0
                    for i in others:
                        area *= max(0.0, min(ba[i][1], bb[i][1]) - max(ba[i][0], bb[i][0]))
                    if area > 1e-3:
                        problems.append(f"z-fighting: {oa['rbx']} {oa.name} and {ob['rbx']} {ob.name} "
                                        f"share plane {'xyz'[axis]}={ba[axis][side]:.3f} ({area:.2f} sq studs)")
    spots = getattr(module, "ASSETS", [])
    rects = []
    for name, at, yaw, fit, size, fp, tier in spots:
        rects.append((name, at, (at[0] - fp[0] / 2, at[0] + fp[0] / 2), (at[2] - fp[1] / 2, at[2] + fp[1] / 2)))
    for i in range(len(rects)):
        for j in range(i + 1, len(rects)):
            ni, ai, xi, zi = rects[i]
            nj, aj, xj, zj = rects[j]
            if abs(ai[1] - aj[1]) > 6:
                continue
            if min(xi[1], xj[1]) - max(xi[0], xj[0]) > 0.05 and min(zi[1], zj[1]) - max(zi[0], zj[0]) > 0.05:
                problems.append(f"asset overlap: {ni} at {ai} and {nj} at {aj}")
    for name, at, xr, zr in rects:
        for o, bx in boxes:
            if not o.get("collide"):
                continue
            if min(xr[1], bx[0][1]) - max(xr[0], bx[0][0]) <= 0.05 or min(zr[1], bx[2][1]) - max(zr[0], bx[2][0]) <= 0.05:
                continue
            if bx[1][1] > at[1] + 0.05 and bx[1][0] < at[1] + 3:
                problems.append(f"asset {name} at {at} collides with {o['rbx']} {o.name}")
    for p in problems:
        print("QUALITY", p)
    if problems:
        raise SystemExit(f"{len(problems)} quality problems, export aborted")
    print(f"quality check: {len(visible)} blocks, {len(rects)} asset spots, no overlaps")


def export_parts(module_name, out_name, title):
    """Scene of primitives (obj["prim"], obj["size"], obj["rbx"]) -> list of Roblox parts with CFrames."""
    from mathutils import Matrix
    common.reset()
    module = importlib.import_module(module_name)
    objects = module.build()
    bpy.context.view_layer.update()
    m = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))  # Blender -> Roblox axes
    keys = sorted({o["rbx"] for o in objects})
    index = {k: i + 1 for i, k in enumerate(keys)}
    shapes = {"Block": 1, "Cylinder": 2, "Sphere": 3, "Wedge": 4}
    rows, specials, boxes = [], [], []
    for obj in objects:
        mw = obj.matrix_world
        pos = m @ mw.to_translation()
        rot = m @ mw.to_3x3().normalized() @ m.transposed()
        sx, sy, sz = obj["size"]
        if obj["prim"] == "Block":
            aabb = _axis_box(obj, pos, rot, (sx, sy, sz))
            if aabb:
                boxes.append((obj, aabb))
        vals = [index[obj["rbx"]], shapes[obj["prim"]], pos.x, pos.y, pos.z] + [rot[i][j] for i in range(3) for j in range(3)] + [sx, sy, sz]
        cells = [("%d" % v) if k < 2 else (("%.4f" if 5 <= k < 14 else "%.3f") % v).rstrip("0").rstrip(".") or "0" for k, v in enumerate(vals)]
        cells = [c if c != "-0" else "0" for c in cells]
        rows.append("{" + ",".join(cells + ["1" if obj.get("collide") else "0", str(int(obj.get("tier", 1)))]) + "}")
        spec = getattr(module, "SPECIALS", {}).get(obj.name)
        if spec:
            specials.append(_luau_special(len(rows), spec))
    check_quality(module, objects, boxes)
    styles = []
    for k in keys:
        rgb, material, transparency = module.STYLES[k]
        styles.append(f'\t\t{{ name = "{k}", color = {{{rgb[0]},{rgb[1]},{rgb[2]}}}, material = "{material}", transparency = {transparency} }},')
    with open(os.path.join(ASSETS, out_name + ".luau"), "w") as f:
        f.write(f"-- Generated by blender/export_luau.py from {module_name}.py. Do not edit by hand.\n")
        f.write(f"-- {title}: styles, parts {{style, shape (1 block, 2 cylinder, 3 sphere, 4 wedge), x, y, z, 3x3 rotation, size, solid, zone level}}\n")
        f.write("-- and specials: named parts (markers, lights, signs, fire) referring to a part row.\n")
        f.write("return {\n\tstyles = {\n" + "\n".join(styles) + "\n\t},\n\tparts = {\n")
        for i in range(0, len(rows), 6):
            f.write("\t\t" + ", ".join(rows[i:i + 6]) + ",\n")
        f.write("\t},\n\tspecials = {\n")
        for line in specials:
            f.write("\t\t" + line + ",\n")
        f.write("\t},\n}\n")
    print(f"{out_name}: {len(rows)} parts, {len(specials)} specials, {len(keys)} styles, {os.path.getsize(os.path.join(ASSETS, out_name + '.luau')) // 1024} KB")


def export_image(png, out_path, size, title):
    from PIL import Image  # pip install pillow
    src = os.path.join(common.RENDERS, png)
    image = Image.open(src).convert("RGB").resize(size, Image.LANCZOS)
    data = base64.b64encode(image.tobytes()).decode("ascii")
    with open(out_path, "w") as f:
        f.write(f"-- Сгенерировано blender/export_luau.py из assets/renders/{png}. Не редактировать вручную.\n")
        f.write(f"-- {title}: RGB {size[0]}×{size[1]} в base64, собирается в EditableImage.\n")
        f.write(f'return {{ width = {size[0]}, height = {size[1]}, rgb = "{data}" }}\n')
    print(f"{out_path}: {os.path.getsize(out_path) // 1024} КБ")


def export_game_art():
    """Key art of every game (blender/game_art.py): art.luau 320x180 for the home background, cover.luau 192x192 tile."""
    from PIL import Image
    import game_art
    for game_id, folder in game_art.GAMES.items():
        png = f"{game_id}_art.png"
        if not os.path.exists(os.path.join(common.RENDERS, png)):
            continue
        app = os.path.join(common.ROOT, "src", "apps", folder)
        export_image(png, os.path.join(app, "art.luau"), (320, 180), f"Key art {game_id}")
        if game_id == "star_pilot":
            continue  # has its own cover render
        image = Image.open(os.path.join(common.RENDERS, png)).convert("RGB")
        w, h = image.size
        crop = image.crop(((w - h) // 2, 0, (w + h) // 2, h))
        square = f"{game_id}_cover.png"
        crop.save(os.path.join(common.RENDERS, square))
        export_image(square, os.path.join(app, "cover.luau"), (192, 192), f"Cover {game_id}")


if __name__ == "__main__":
    # blender -b -P blender/export_luau.py -- chillzone  (аргументы после «--»)
    if "--" in sys.argv:
        sys.argv = [sys.argv[0]] + sys.argv[sys.argv.index("--") + 1:]
    if len(sys.argv) > 1 and sys.argv[1] == "art":
        export_game_art()
        sys.exit(0)
    if len(sys.argv) > 1 and sys.argv[1] == "chillzone":
        export_parts("chillzone", "ChillZoneParts", "Chill zone house and yard")
        sys.exit(0)
    export_parts("chillzone", "ChillZoneParts", "Chill zone house and yard")
    export_mesh("ps5_console", "ConsoleMesh", "Консоль PS5")
    export_mesh("dualsense", "ControllerMesh", "Геймпад DualSense")
    export_image("home_background.png", os.path.join(ASSETS, "HomeBackground.luau"), (400, 225), "Фон главного экрана")
    export_image("store_banner.png", os.path.join(ASSETS, "StoreBanner.luau"), (448, 140), "Баннер магазина")
    export_image("star_pilot_cover.png", os.path.join(common.ROOT, "src", "apps", "StarPilot", "cover.luau"), (192, 192), "Обложка Star Pilot")
