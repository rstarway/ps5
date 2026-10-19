"""Chess (src/apps/Chess): Staunton pieces as sprites with transparency, key art and cover.

    python3 blender/chess_art.py            # renders + writes src/apps/Chess/{pieces,art,cover}.luau
    PS5_PREVIEW=1 python3 blender/chess_art.py

All art is original: lathe-turned pieces, the knight is an extruded silhouette.
"""
import base64
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import bmesh  # noqa: E402
import common  # noqa: E402
from common import add_bevel, area_light, box, camera, extrude_outline, material, mesh_object, render, reset, setup_render, world  # noqa: E402

APP = os.path.join(common.ROOT, "src", "apps", "Chess")
KINDS = ["pawn", "knight", "bishop", "rook", "queen", "king"]
SPRITE = 80  # px, size of one piece in pieces.luau

BASE = [(0.0, 0.0), (0.46, 0.0), (0.47, 0.04), (0.46, 0.08), (0.40, 0.10), (0.40, 0.14), (0.32, 0.18)]


def arc(cx, cz, r, a0, a1, steps=10):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / steps)), cz + r * math.sin(math.radians(a0 + (a1 - a0) * i / steps))) for i in range(steps + 1)]


def lathe(name, profile, mat, loc):
    """Profile (radius, height) turned around Z."""
    bm = bmesh.new()
    verts = [bm.verts.new((max(r, 0.0), 0, z)) for r, z in profile]
    edges = [bm.edges.new((verts[i], verts[i + 1])) for i in range(len(verts) - 1)]
    bmesh.ops.spin(bm, geom=verts + edges, cent=(0, 0, 0), axis=(0, 0, 1), angle=math.tau, steps=40, use_duplicate=False)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mesh_object(name, bm, mat)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    obj.location = loc
    return obj


def ball(name, r, loc, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=24, ring_count=12, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    for poly in obj.data.polygons:
        poly.use_smooth = True
    obj.data.materials.append(mat)
    return obj


def piece(kind, mat, x=0.0, y=0.0, scale=1.0, yaw=0.0, eye=None):
    """Builds one piece at (x, y); returns its objects."""
    parts = []
    if kind == "pawn":
        prof = BASE + [(0.22, 0.24), (0.14, 0.50), (0.23, 0.54), (0.23, 0.57), (0.12, 0.60)] + arc(0, 0.77, 0.19, -62, 90)
        parts.append(lathe("Pawn", prof, mat, (0, 0, 0)))
    elif kind == "rook":
        prof = BASE + [(0.29, 0.25), (0.24, 0.70), (0.33, 0.75), (0.33, 0.90), (0.0, 0.90)]
        parts.append(lathe("Rook", prof, mat, (0, 0, 0)))
        for i in range(6):
            a = i / 6 * math.tau
            b = box("Merlon", (0.17, 0.1, 0.13), (math.cos(a) * 0.26, math.sin(a) * 0.26, 0.96), mat, bevel=0.015)
            b.rotation_euler = (0, 0, a + math.pi / 2)
            parts.append(b)
    elif kind == "bishop":
        prof = BASE + [(0.25, 0.25), (0.14, 0.62), (0.25, 0.66), (0.25, 0.70), (0.13, 0.73)]
        prof += [(0.19, 0.80), (0.21, 0.88), (0.18, 0.98), (0.10, 1.06), (0.04, 1.10), (0.0, 1.11)]
        parts.append(lathe("Bishop", prof, mat, (0, 0, 0)))
        parts.append(ball("Top", 0.06, (0, 0, 1.15), mat))
    elif kind == "queen":
        prof = BASE + [(0.29, 0.25), (0.15, 0.80), (0.27, 0.85), (0.27, 0.89), (0.18, 0.92), (0.30, 1.10), (0.18, 1.12), (0.08, 1.17), (0.0, 1.18)]
        parts.append(lathe("Queen", prof, mat, (0, 0, 0)))
        for i in range(9):
            a = i / 9 * math.tau
            parts.append(ball("Crown", 0.05, (math.cos(a) * 0.29, math.sin(a) * 0.29, 1.13), mat))
        parts.append(ball("Top", 0.075, (0, 0, 1.24), mat))
    elif kind == "king":
        prof = BASE + [(0.30, 0.25), (0.16, 0.86), (0.28, 0.91), (0.28, 0.95), (0.18, 0.97), (0.27, 1.16), (0.12, 1.21), (0.0, 1.22)]
        parts.append(lathe("King", prof, mat, (0, 0, 0)))
        parts.append(box("CrossV", (0.08, 0.08, 0.30), (0, 0, 1.35), mat, bevel=0.015))
        parts.append(box("CrossH", (0.24, 0.08, 0.08), (0, 0, 1.39), mat, bevel=0.015))
    elif kind == "knight":
        prof = BASE + [(0.31, 0.24), (0.0, 0.24)]
        parts.append(lathe("KnightBase", prof, mat, (0, 0, 0)))
        outline = [(-0.27, 0.22), (0.30, 0.22), (0.31, 0.42), (0.27, 0.62), (0.22, 0.80), (0.15, 0.95), (0.08, 1.04), (0.04, 1.13),
                   (-0.03, 1.05), (-0.13, 1.00), (-0.28, 0.89), (-0.40, 0.75), (-0.41, 0.67), (-0.36, 0.61), (-0.25, 0.59),
                   (-0.20, 0.52), (-0.26, 0.36)]
        head = extrude_outline("KnightHead", outline, 0.28, axis="Y", mat=mat)
        add_bevel(head, 0.03, 2)
        parts.append(head)
        if eye:
            for side in (-1, 1):
                parts.append(ball("Eye", 0.035, (-0.14, side * 0.15, 0.88), eye))
    root = bpy.data.objects.new("Piece_" + kind, None)
    common.link(root)
    for p in parts:
        p.parent = root
    root.location = (x, y, 0)
    root.scale = (scale, scale, scale)
    root.rotation_euler = (0, 0, yaw)
    return root


def materials():
    ivory = material("Ivory", (0.86, 0.80, 0.68), roughness=0.28, coat=0.6)
    ebony = material("Ebony", (0.035, 0.035, 0.045), roughness=0.22, coat=1.0)
    return ivory, ebony


def render_sprites():
    """12 sprites (white/black × 6) with transparent background -> list of RGBA PIL images."""
    from PIL import Image
    images = {}
    for color in ("w", "b"):
        for kind in KINDS:
            reset()
            scene = setup_render(SPRITE * 2, SPRITE * 2, samples=48)
            scene.render.resolution_x = scene.render.resolution_y = SPRITE * 2
            scene.render.film_transparent = True
            world((0.08, 0.09, 0.12), 0.6)
            ivory, ebony = materials()
            dark = material("Eye", (0.02, 0.02, 0.02), roughness=0.3)
            piece(kind, ivory if color == "w" else ebony, yaw=0, eye=dark if color == "w" else ivory)
            area_light("Key", (-3, -4, 5), (0, 0, 0.6), 900, (1, 0.96, 0.9), 3)
            area_light("Fill", (4, -3, 2), (0, 0, 0.6), 300, (0.8, 0.85, 1), 3)
            area_light("Rim", (1, 5, 3), (0, 0, 0.8), 1400 if color == "b" else 600, (0.45, 0.7, 1), 2)
            cam = camera((0, -8, 2.6), (0, 0, 0.64), lens=50)
            cam.data.type = "ORTHO"
            cam.data.ortho_scale = 1.62
            path = render(f"chess_{color}{kind}.png")
            images[color + kind] = Image.open(path).convert("RGBA").resize((SPRITE, SPRITE), Image.LANCZOS)
    return images


def render_key_art():
    reset()
    setup_render(960, 540, samples=64)
    world((0.01, 0.015, 0.04), 0.4)
    light_sq = material("SqLight", (0.55, 0.62, 0.78), roughness=0.15, coat=1.0)
    dark_sq = material("SqDark", (0.05, 0.08, 0.18), roughness=0.15, coat=1.0)
    frame = material("Frame", (0.01, 0.01, 0.015), roughness=0.3, metallic=0.5)
    box("Frame", (8.8, 8.8, 0.3), (0, 0, -0.16), frame, bevel=0.05)
    box("Glow", (8.9, 8.9, 0.04), (0, 0, -0.3), material("Neon", (0, 0.3, 1), emission=(0.0, 0.35, 1.0), strength=12))
    for f in range(8):
        for r in range(8):
            box("Sq", (1, 1, 0.04), (f - 3.5, r - 3.5, 0.0), light_sq if (f + r) % 2 else dark_sq)
    ivory, ebony = materials()
    eye = material("Eye", (0.02, 0.02, 0.02))
    # позиция из середины партии
    setup = [
        ("king", "w", 6, 0), ("rook", "w", 5, 0), ("pawn", "w", 5, 1), ("pawn", "w", 6, 1), ("pawn", "w", 7, 2),
        ("queen", "w", 3, 2), ("bishop", "w", 2, 3), ("knight", "w", 4, 4), ("pawn", "w", 4, 3), ("pawn", "w", 0, 1),
        ("king", "b", 6, 7), ("rook", "b", 3, 7), ("pawn", "b", 5, 6), ("pawn", "b", 6, 5), ("pawn", "b", 7, 6),
        ("queen", "b", 1, 5), ("bishop", "b", 4, 6), ("knight", "b", 2, 5), ("pawn", "b", 3, 5), ("pawn", "b", 0, 6),
    ]
    for kind, color, f, r in setup:
        piece(kind, ivory if color == "w" else ebony, f - 3.5, r - 3.5, 0.9, math.pi if kind == "knight" and color == "b" else 0, eye if color == "w" else ivory)
    # большой конь на переднем плане
    piece("knight", ebony, -3.0, -5.2, 2.2, -0.35, ivory)
    piece("king", ivory, 2.9, -5.0, 2.3, 0, eye)
    area_light("Key", (-6, -8, 9), (0, 0, 0), 4000, (1, 0.95, 0.88), 6)
    area_light("Rim", (4, 9, 4), (0, 0, 1), 5000, (0.25, 0.5, 1.0), 6)
    area_light("Under", (0, -10, 1), (0, -5, 1.5), 900, (0.3, 0.55, 1), 4)
    camera((0.6, -12.5, 5.6), (0.2, -1.2, 0.9), lens=38)
    return render("chess_art.png")


def export(images):
    from PIL import Image
    import export_luau
    # спрайты: RGBA в base64, по строке на фигуру
    lines = [
        "-- Сгенерировано blender/chess_art.py. Не редактировать вручную.",
        f"-- Фигуры: RGBA {SPRITE}×{SPRITE} в base64 (w/b + pawn knight bishop rook queen king), собираются в EditableImage.",
        f"return {{ size = {SPRITE}, sprites = {{",
    ]
    for key, image in images.items():
        lines.append(f'\t{key} = "{base64.b64encode(image.tobytes()).decode("ascii")}",')
    lines.append("} }")
    with open(os.path.join(APP, "pieces.luau"), "w") as f:
        f.write("\n".join(lines) + "\n")
    sheet = Image.new("RGBA", (SPRITE * 6, SPRITE * 2), (40, 48, 70, 255))
    for i, kind in enumerate(KINDS):
        for j, color in enumerate("wb"):
            sheet.alpha_composite(images[color + kind], (i * SPRITE, j * SPRITE))
    sheet.save(os.path.join(common.RENDERS, "chess_pieces.png"))
    export_luau.export_image("chess_art.png", os.path.join(APP, "art.luau"), (320, 180), "Key art chess")
    art = Image.open(os.path.join(common.RENDERS, "chess_art.png")).convert("RGB")
    w, h = art.size
    art.crop(((w - h) // 2 - int(w * 0.08), 0, (w + h) // 2 - int(w * 0.08), h)).save(os.path.join(common.RENDERS, "chess_cover.png"))
    export_luau.export_image("chess_cover.png", os.path.join(APP, "cover.luau"), (192, 192), "Cover chess")


if __name__ == "__main__":
    sprites = render_sprites()
    render_key_art()
    export(sprites)
