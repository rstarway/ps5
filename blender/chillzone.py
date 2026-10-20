"""Chill zone, entirely authored in Blender: house, yard, colliders, lights, signs and gameplay markers.

    blender -b -P blender/export_luau.py -- chillzone   # writes src/shared/PS5/Assets/ChillZoneParts.luau
    blender -b -P blender/chillzone.py                  # build + renders (assets/renders/chillzone_*.png)

Style: modern minimalism, warm evening light, no neon. A white house volume under a thin dark flat roof that
cantilevers over a concrete terrace; vertical wood slats on the sides; steel columns, recessed downlights.
Plot (house front faces +Z, the street is behind the spawn):
    spawn (0, 104) by the gate -> wide concrete paver walk with low bollards -> terrace -> open entrance
    left: driveway and carport with the car; behind it the fire lounge (square fire pit, four sofas)
    right: rectangular pool (terrain water) with a teak deck, stone coping, loungers and an umbrella
    boundary: clipped hedge; outside it the server raises soft wooded hills (ChillZone.server.luau)
Inside (unchanged): TV, PS5 and sofa in the middle, MY GAMES on the left wall, MY TROPHIES on the right wall.

Everything is authored in Roblox coordinates through R(x, y, z) (Y up, studs). Every object is a Roblox-friendly
primitive (obj["prim"] = Block | Cylinder | Sphere | Wedge, obj["size"] in Roblox axes) with a style key obj["rbx"].
obj["collide"] = 1 makes it solid in Roblox. special(obj, name, ...) turns an object into a named part placed directly
in the ChillZone model, optionally with a light, a sign (SurfaceGui text), fire, an Index attribute or hidden (markers).
asset(name, at, ...) leaves an AssetSpot marker: the server puts the 3D model ServerStorage.ChillZoneAssets[name]
(generated with Hunyuan3D, assets/roblox/*.rbxm) there, scaled to the given size.
Parts never overlap with coplanar faces (z-fighting): export_luau.py checks it and fails the export.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import bmesh  # noqa: E402
import common  # noqa: E402
from mathutils import Vector  # noqa: E402

# key: (rgb 0-255, Roblox material, transparency). No Neon anywhere: lamps are glass with a real light.
STYLES = {
    # house shell and interior
    "Plaster": ((236, 232, 224), "Plaster", 0),
    "Cladding": ((70, 50, 40), "WoodPlanks", 0),
    "WoodFloor": ((170, 122, 82), "WoodPlanks", 0),
    "WoodDark": ((58, 42, 34), "Wood", 0),
    "WoodLight": ((196, 156, 110), "WoodPlanks", 0),
    "Ceiling": ((214, 182, 140), "WoodPlanks", 0),
    "Glass": ((170, 205, 255), "Glass", 0.65),
    "Metal": ((34, 34, 38), "Metal", 0),
    "Sofa": ((70, 80, 108), "Fabric", 0),
    "Cushion": ((88, 100, 132), "Fabric", 0),
    "Rug": ((168, 160, 148), "Carpet", 0),
    "PillowPink": ((255, 122, 162), "Fabric", 0),
    "PillowBlue": ((120, 200, 255), "Fabric", 0),
    "LampShade": ((255, 226, 184), "Fabric", 0),
    "Ceramic": ((186, 112, 82), "Concrete", 0),
    "Leaves": ((70, 132, 74), "LeafyGrass", 0),
    "LeavesDark": ((46, 100, 62), "LeafyGrass", 0),
    "Curtain": ((222, 196, 166), "Fabric", 0),
    "Blanket": ((238, 226, 204), "Fabric", 0),
    "Leather": ((150, 92, 62), "Leather", 0),
    "BookRed": ((168, 62, 60), "SmoothPlastic", 0),
    "BookGreen": ((62, 118, 92), "SmoothPlastic", 0),
    "BookCream": ((230, 214, 182), "SmoothPlastic", 0),
    "BookNavy": ((52, 64, 110), "SmoothPlastic", 0),
    "Candle": ((250, 242, 228), "SmoothPlastic", 0),
    "CandleFlame": ((255, 196, 120), "Glass", 0.15),
    "Mug": ((244, 244, 248), "SmoothPlastic", 0),
    "Screen": ((4, 6, 12), "Glass", 0),
    "Sign": ((28, 29, 32), "Metal", 0),
    "Marker": ((255, 255, 255), "SmoothPlastic", 1),
    "ShelfGlass": ((200, 220, 255), "Glass", 0.3),
    "LampGlass": ((255, 236, 205), "Glass", 0.15),
    "BulbGlass": ((255, 226, 180), "Glass", 0.1),
    # exterior
    "Plinth": ((88, 88, 90), "Concrete", 0),
    "Concrete": ((196, 194, 188), "Concrete", 0),
    "Paver": ((184, 182, 176), "Concrete", 0),
    "RoofSlab": ((44, 45, 49), "Concrete", 0),
    "RoofGravel": ((112, 110, 106), "Pebble", 0),
    "Slats": ((112, 78, 52), "Wood", 0),
    "SlatBack": ((30, 26, 24), "SmoothPlastic", 0),
    "Deck": ((146, 102, 70), "WoodPlanks", 0),
    "Coping": ((226, 222, 212), "Limestone", 0),
    "PoolTile": ((92, 168, 196), "CeramicTiles", 0),
    "Hedge": ((54, 88, 50), "LeafyGrass", 0),
    "Gravel": ((146, 142, 134), "Pebble", 0),
    "LavaRock": ((44, 40, 38), "Basalt", 0),
    "Corten": ((122, 66, 40), "CorrodedMetal", 0),
    "RailGlass": ((200, 225, 235), "Glass", 0.7),
    "WaterStill": ((52, 86, 96), "Glass", 0.25),
    "Gold": ((222, 180, 82), "Metal", 0),
}
assert all(kind != "Neon" for _, kind, _ in STYLES.values()), "no neon in the chill zone"

random.seed(7)
OBJECTS = []
TIER = [1]  # zone level an object belongs to; objects above the owner's level stay hidden in Roblox


class tier:
    """with tier(3): ... -> everything created inside appears when the owner's chill zone reaches level 3."""

    def __init__(self, n):
        self.n = n

    def __enter__(self):
        TIER[0] = self.n

    def __exit__(self, *exc):
        TIER[0] = 1
_materials = {}


def R(x, y, z):
    """Roblox (x, y up, z) -> Blender (x, -z, y)."""
    return (x, -z, y)


def _mat(key):
    if key not in _materials:
        rgb, kind, transparency = STYLES[key]
        color = tuple((c / 255) ** 2.2 for c in rgb)
        emission = color if kind == "Neon" else None
        rough = {"Glass": 0.05, "Metal": 0.35, "SmoothPlastic": 0.35}.get(kind, 0.8)
        mat = common.material(key, color, roughness=rough, metallic=0.8 if kind == "Metal" else 0.0,
                              emission=emission, strength=6.0 if emission else 0.0)
        if transparency:
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            bsdf.inputs["Transmission Weight"].default_value = 0.9
        _materials[key] = mat
    return _materials[key]


def _finish(obj, key, rot=(0, 0, 0), prim="Block", size=(1, 1, 1)):
    obj["rbx"] = key
    obj["prim"] = prim
    obj["size"] = [float(v) for v in size]
    if key not in STYLES:
        raise KeyError(key)
    obj.data.materials.append(_mat(key))
    obj.rotation_mode = "XYZ"
    # rot is (rx, ry, rz) in Roblox axes, degrees -> Blender axes (x, -z, y)
    obj.rotation_euler = (math.radians(rot[0]), -math.radians(rot[2]), math.radians(rot[1]))
    if TIER[0] > 1:
        obj["tier"] = TIER[0]
    OBJECTS.append(obj)
    return obj


def box(key, size, at, rot=(0, 0, 0), bevel=0.0):
    """size and at in Roblox axes (x, y, z)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[2]
        v.co.z *= size[1]
    obj = common.mesh_object(key, bm)
    obj.location = R(*at)
    if bevel:
        common.add_bevel(obj, bevel, 1)
    return _finish(obj, key, rot, "Block", size)


def wedge(key, size, at, rot=(0, 0, 0)):
    """Roblox WedgePart: full bottom, high edge at local +Z, slope facing -Z."""
    w, h, d = size
    bm = bmesh.new()
    pts = [(-w / 2, -h / 2, -d / 2), (w / 2, -h / 2, -d / 2), (w / 2, -h / 2, d / 2), (-w / 2, -h / 2, d / 2),
           (-w / 2, h / 2, d / 2), (w / 2, h / 2, d / 2)]
    v = [bm.verts.new((x, -z, y)) for x, y, z in pts]
    for face in ((0, 1, 2, 3), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2), (0, 4, 5, 1)):
        bm.faces.new([v[i] for i in face])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = common.mesh_object(key, bm)
    obj.location = R(*at)
    return _finish(obj, key, rot, "Wedge", size)


def cyl(key, radius, height, at, rot=(0, 0, 0), segments=16, radius2=None, bevel=0.0):
    """Vertical (Roblox Y) cylinder/cone centred at `at`."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius,
                          radius2=radius if radius2 is None else radius2, depth=height)
    obj = common.mesh_object(key, bm)
    obj.location = R(*at)
    if bevel:
        common.add_bevel(obj, bevel, 1)
    r = radius if radius2 is None else (radius + radius2) / 2
    return _finish(obj, key, rot, "Cylinder", (2 * r, height, 2 * r))


def blob(key, radius, at, scale=(1, 1, 1), noise=0.18, subdiv=1, rot=(0, 0, 0)):
    """Low-poly lumpy sphere (rocks, crowns, bushes). scale in Roblox axes."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    for v in bm.verts:
        k = 1 + random.uniform(-noise, noise)
        v.co.x *= k * scale[0]
        v.co.y *= k * scale[2]
        v.co.z *= k * scale[1]
    obj = common.mesh_object(key, bm)
    obj.location = R(*at)
    return _finish(obj, key, rot, "Sphere", (2 * radius * scale[0], 2 * radius * scale[1], 2 * radius * scale[2]))


def rock(key, radius, at, scale=(1, 0.7, 1)):
    """Rock: a randomly turned block (reads as a chiselled stone in Roblox)."""
    size = (2 * radius * scale[0], 2 * radius * scale[1], 2 * radius * scale[2])
    return box(key, size, at, rot=(random.uniform(-12, 12), random.uniform(0, 90), random.uniform(-12, 12)))


def beam(key, a, b, thickness):
    """Thin box from point a to point b (Roblox coords)."""
    ax, ay, az = a
    bx, by, bz = b
    dx, dy, dz = bx - ax, by - ay, bz - az
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= length
        v.co.y *= thickness
        v.co.z *= thickness
    obj = common.mesh_object(key, bm)
    obj["rbx"] = key
    obj["prim"] = "Block"
    obj["size"] = [length, thickness, thickness]
    obj.data.materials.append(_mat(key))
    obj.location = R((ax + bx) / 2, (ay + by) / 2, (az + bz) / 2)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((dx, -dz, dy)).to_track_quat("X", "Z")
    if TIER[0] > 1:
        obj["tier"] = TIER[0]
    OBJECTS.append(obj)
    return obj



# ---------------------------------------------------------------- roblox metadata
SPECIALS = {}  # Blender object name -> {name, light, sign, fire, index, attrs, hidden}


def solid(obj):
    """Solid in Roblox (CanCollide + CanQuery)."""
    obj["collide"] = 1
    return obj


def special(obj, name, **kw):
    SPECIALS[obj.name] = dict(name=name, **{k: v for k, v in kw.items() if v is not None})
    return obj


def light(color, rng, brightness, shadows=False, flicker=False, surface=None, angle=90):
    return dict(color=color, range=rng, brightness=brightness, shadows=shadows, flicker=flicker, surface=surface, angle=angle)


def marker(name, at, index=None, rot=(0, 0, 0), **kw):
    obj = box("Marker", (1, 1, 1), at, rot=rot)
    obj.hide_render = True
    return special(obj, name, index=index, hidden=True, **kw)


def signboard(name, size, at, face, text, color, rot=(0, 0, 0), glow=False):
    obj = box("Sign", size, at, rot=rot)
    return special(obj, name, sign=dict(face=face, text=text, color=color),
                   light=light(color, 14, 0.8) if glow else None)


ASSETS = []  # (name, (x, y, z), yaw, fit, size, footprint) for the overlap check and the renders


def asset(name, at, yaw=0, size=None, fit="height", footprint=(2, 2)):
    """Spot for a generated 3D model: its bottom centre lands on `at`, turned by `yaw` degrees,
    scaled so that its height (fit="height") or its longest side (fit="length") equals `size`.
    footprint (x, z) is the planned size on the ground: export_luau.py checks spots and parts do not overlap."""
    ASSETS.append((name, at, yaw, fit, size, footprint, TIER[0]))
    attrs = {"Asset": name, "Yaw": yaw, "Fit": fit}
    if size:
        attrs["Size"] = size
    return marker("AssetSpot", at, attrs=attrs)


# ---------------------------------------------------------------- house shell (x ±30, z ±20, floor top y 1)
WARM = (255, 204, 150)  # warm white of every exterior lamp


def house():
    solid(box("Plinth", (61, 1.0, 41), (0, 0.5, 0)))
    box("WoodFloor", (58.6, 0.1, 38.6), (0, 1.03, 0))
    # back wall with two windows at x ±20 (behind the games and trophy corners)
    solid(box("Plaster", (60, 4, 1), (0, 3, -19.5)))
    solid(box("Plaster", (60, 4, 1), (0, 15, -19.5)))
    solid(box("Plaster", (30, 8, 1), (0, 9, -19.5)))
    for side in (-1, 1):
        solid(box("Plaster", (5, 8, 1), (side * 27.5, 9, -19.5)))
        window_z(side * 20, -19.5, 10)
    # side walls stop at the front and back walls so the corners do not overlap
    solid(box("Plaster", (1, 16, 38), (29.5, 9, 0)))
    solid(box("Plaster", (1, 16, 38), (-29.5, 9, 0)))
    # front wall: a wide open entrance x -7..7 (y 1..12) and two big windows, so the room is visible from the yard
    for side in (-1, 1):
        solid(box("Plaster", (23, 4, 1), (side * 18.5, 3, 19.5)))
        solid(box("Plaster", (23, 4, 1), (side * 18.5, 15, 19.5)))
        solid(box("Plaster", (3, 8, 1), (side * 8.5, 9, 19.5)))
        solid(box("Plaster", (6, 8, 1), (side * 27, 9, 19.5)))
        window_z(side * 17, 19.5, 14)
    solid(box("Plaster", (14, 5, 1), (0, 14.5, 19.5)))
    # steel portal around the entrance: jambs just inside the opening, header on top
    for side in (-1, 1):
        box("Metal", (0.5, 10.5, 1.6), (side * 6.75, 6.25, 19.5))
    box("Metal", (14, 0.5, 1.6), (0, 11.75, 19.5))
    facade()
    roof()


def window_z(cx, z, width):
    """Window in a wall facing ±Z: thin steel frame, mullion and transom, glass (solid)."""
    out = 1 if z > 0 else -1
    solid(box("Glass", (width, 8, 0.2), (cx, 9, z)))
    for dx in (-width / 2, width / 2):
        box("Metal", (0.35, 8.4, 1.3), (cx + dx, 9, z))
    for dy in (-4, 4):
        box("Metal", (width - 0.35, 0.35, 1.3), (cx, 9 + dy, z))
    box("Metal", (0.2, 7.65, 0.4), (cx, 9, z))
    for dx in (-1, 1):
        box("Metal", (width / 2 - 0.275, 0.2, 0.4), (cx + dx * (width / 4 - 0.0375), 10.5, z))
    box("Metal", (width + 0.4, 0.12, 0.7), (cx, 4.76, z + out * 0.85))  # flashing under the window


def slat_panel(axis, fixed, a0, a1, y0=1.0, y1=17.0):
    """Vertical wood slats on a dark backing, on the outside of a wall.
    axis "z": wall facing +Z at z = fixed, slats run along x from a0 to a1; axis "x": wall facing ±X at x = fixed."""
    h, yc = y1 - y0, (y0 + y1) / 2
    sign_ = 1 if fixed > 0 else -1
    length = a1 - a0
    n = int(length / 0.6)
    pad = (length - n * 0.6) / 2
    if axis == "z":
        box("SlatBack", (length, h, 0.1), ((a0 + a1) / 2, yc, fixed + sign_ * 0.05))
        for i in range(n):
            box("Slats", (0.35, h, 0.25), (a0 + pad + 0.3 + i * 0.6, yc, fixed + sign_ * 0.225))
    else:
        box("SlatBack", (0.1, h, length), (fixed + sign_ * 0.05, yc, (a0 + a1) / 2))
        for i in range(n):
            box("Slats", (0.25, h, 0.35), (fixed + sign_ * 0.225, yc, a0 + pad + 0.3 + i * 0.6))


def facade():
    # wood slats on both end piers of the front and along both side walls; steel corner trims
    for side in (-1, 1):
        slat_panel("z", 20, *sorted((side * 24.4, side * 29.95)))
        slat_panel("x", side * 30, -19.95, 19.95)
        for z in (-20.2, 20.2):
            box("Metal", (0.4, 16, 0.4), (side * 30.2, 9, z))
    # house name plaque above the entrance (the server writes the owner's name on it)
    signboard("ChillSign", (12, 1.4, 0.15), (0, 14.5, 20.075), "Back", "CHILL ZONE", (236, 232, 222))
    # wall lights on the white piers either side of the entrance
    for side in (-1, 1):
        box("Metal", (0.5, 1.6, 0.35), (side * 8.5, 8.6, 20.175))
        special(box("LampGlass", (0.4, 0.12, 0.25), (side * 8.5, 7.74, 20.175)), "WallLight",
                light=light(WARM, 10, 0.9, surface="Bottom", angle=120))


def roof():
    """Thin dark flat roof cantilevering over the terrace, on two slim steel columns."""
    solid(box("RoofSlab", (64.4, 1.2, 51), (0, 17.6, 3.3)))
    box("RoofGravel", (62.4, 0.05, 49), (0, 18.225, 3.3))
    for side in (-1, 1):
        solid(box("Metal", (0.6, 16, 0.6), (side * 14.5, 9, 28)))
    # recessed downlights in the soffit over the terrace
    for x in (-10, 0, 10):
        special(cyl("LampGlass", 0.45, 0.1, (x, 16.95, 24.5), segments=16), "Downlight",
                light=light(WARM, 18, 1.2, shadows=True, surface="Bottom", angle=80))
    # inside: ceiling, beams, pendant lamps (one over each zone)
    solid(box("Ceiling", (58, 0.2, 38), (0, 16.9, 0)))
    for x in range(-24, 25, 8):
        box("WoodDark", (0.8, 0.8, 38), (x, 16.4, 0))
    for x, z in ((-20, 0), (0, -3), (20, 0)):
        cyl("Metal", 0.06, 3.4, (x, 15.1, z), segments=6)
        cyl("Metal", 1.6, 1.4, (x, 12.7, z), segments=20, radius2=0.35)
        special(cyl("LampGlass", 1.25, 0.15, (x, 11.925, z), segments=20), "CeilingLamp",
                light=light((255, 205, 160), 30, 1.2, shadows=True))


def terrace():
    """Concrete terrace in front of the entrance, two wide steps down to the walk."""
    solid(box("Concrete", (30, 1.0, 8), (0, 0.5, 24.5)))
    solid(box("Concrete", (30, 0.66, 1.2), (0, 0.33, 29.1)))
    solid(box("Concrete", (30, 0.33, 1.2), (0, 0.165, 30.3)))


# ---------------------------------------------------------------- PLAY zone (centre): TV, PS5, sofa
CONSOLE = (-5.5, 4, -16.3)
FLOOR = 1.08  # top of the wooden floor


def play_zone():
    special(box("Rug", (24, 0.1, 18), (0, 1.1, -5), bevel=0.8), "Rug")
    # slatted accent wall
    box("WoodDark", (24, 15.6, 0.15), (0, 8.9, -18.95))
    x = -11.6
    while x <= 11.7:
        box("Cladding", (0.45, 15.4, 0.3), (x, 8.9, -18.75))
        x += 0.85
    # big TV
    solid(box("Metal", (16.4, 9.4, 0.6), (0, 10, -18.25), bevel=0.1))
    special(box("Screen", (15.6, 8.6, 0.1), (0, 10, -17.92)), "TVScreen", light=light((80, 140, 255), 14, 0.8))
    # floating TV stand with the PS5 spot
    solid(box("WoodDark", (16, 2.6, 3.8), (0, 2.7, -16.5), bevel=0.12))
    box("WoodLight", (16.1, 0.25, 3.9), (0, 3.88, -16.5), bevel=0.05)
    marker("ConsoleSpot", CONSOLE)
    # sofa facing the TV: the server puts a Creator Store sofa here (Assets/CreatorStore.luau);
    # these Blender parts are its fallback and are removed when the store model loads
    def sofa(obj):
        return special(obj, "SofaFallback")
    sofa(solid(box("Sofa", (12.4, 1.8, 5.4), (0, 2.2, 6.3), bevel=0.3)))
    for ax in (-5.7, 5.7):
        sofa(solid(box("Sofa", (1.2, 3.42, 5.6), (ax, 2.79, 6.3), bevel=0.4)))
    for cx in (-2.6, 2.6):
        sofa(box("Cushion", (5.0, 1.1, 4.6), (cx, 3.55, 6.0), bevel=0.35))
        sofa(box("Cushion", (5.0, 3.6, 1.4), (cx, 5.3, 8.4), rot=(-10, 0, 0), bevel=0.5))
    sofa(solid(box("Sofa", (10.2, 4.2, 1.0), (0, 4.2, 9.2), bevel=0.3)))
    sofa(box("Blanket", (1.6, 3.4, 4.4), (-5.6, 3.5, 6.1), rot=(0, 0, -6)))
    # coffee table with the controller, candles and mugs
    solid(box("WoodLight", (8, 0.5, 4), (0, 3.0, -3), bevel=0.2))
    for dx in (-3.4, 3.4):
        for dz in (-1.4, 1.4):
            beam("Metal", (dx, 1.05, -3 + dz), (dx * 0.9, 2.78, -3 + dz * 0.9), 0.18)
    marker("ControllerSpot", (0, 3.3, -3))
    box("WoodDark", (2.6, 0.15, 1.8), (-2.6, 3.33, -3.3))
    for dx, h in ((-0.7, 1.0), (0, 0.7), (0.7, 0.5)):
        cyl("Candle", 0.28, h, (-2.6 + dx, 3.4 + h / 2, -3.3), segments=10)
        flame = blob("CandleFlame", 0.12, (-2.6 + dx, 3.4 + h + 0.18, -3.3), scale=(1, 1.6, 1), noise=0)
        if dx == 0:
            special(flame, "CandleLight", light=light((255, 170, 90), 10, 1.2, shadows=True, flicker=True))
    for dx in (-0.5, 0.5):
        cyl("Mug", 0.36, 0.7, (2.8 + dx, 3.6, -3.0 + dx * 0.4), segments=10)
    # floor lamp and a plant either side of the TV stand (Hunyuan models; the lamp's light is a hidden marker)
    floor_lamp(-11.5, -16)
    asset("PottedPlant", (11.5, FLOOR, -16.3), size=7, footprint=(3, 3))


def floor_lamp(x, z):
    asset("FloorLamp", (x, FLOOR, z), size=10, footprint=(2.6, 2.6))
    marker("LampLight", (x, 9.5, z), light=light((255, 196, 140), 22, 1.4, shadows=True))


# ---------------------------------------------------------------- MY GAMES (left wall)
def games_zone():
    for y in (9.5, 5.5):
        solid(box("WoodDark", (2.6, 0.4, 22), (-28.2, y, -2), bevel=0.08))
        for z in (-12, -2, 8):
            box("Metal", (2.2, 1.2, 0.3), (-28.3, y - 0.7, z))
    slot = 0
    for y in (9.5, 5.5):
        for i in range(10):
            slot += 1
            marker("GameSlot", (-28.2, y + 0.2, -11.5 + i * 2.1), index=slot, rot=(0, 90, 0))
    signboard("GameSign", (0.3, 2.2, 13), (-28.85, 14.2, -2), "Right", "MY GAMES", (236, 232, 222), glow=False)
    asset("PottedPlant", (-25.5, FLOOR, -16.3), yaw=60, size=7, footprint=(3, 3))
    # reading corner by the entrance: bookshelf, an armchair facing the room, a floor lamp
    bookshelf(-28.2, 14, 7)
    asset("Armchair", (-21.5, FLOOR, 12.5), yaw=135, size=4.6, fit="length", footprint=(4.8, 4.8))
    floor_lamp(-25, 17.2)


# ---------------------------------------------------------------- MY TROPHIES (right wall)
def trophy_zone():
    # cabinet: plinth (y 1..2), back and sides between plinth and top (2..14.55), top (14.55..15.25)
    solid(box("WoodDark", (1, 12.55, 22.4), (28.5, 8.275, 0)))
    for z in (-11.2, 11.2):
        solid(box("WoodDark", (2.7, 12.55, 0.6), (26.65, 8.275, z), bevel=0.06))
    box("WoodDark", (3.8, 0.7, 23.2), (27, 14.9, 0), bevel=0.1)
    solid(box("WoodDark", (3.8, 1.0, 23.2), (27, 1.5, 0), bevel=0.1))
    slot = 0
    for y in (12, 8, 4):
        solid(box("ShelfGlass", (3, 0.3, 21.4), (27, y, 0)))
        box("LampGlass", (0.15, 0.1, 21), (28, y + 3.6, 0))
        for i in range(8):
            slot += 1
            marker("TrophySlot", (27, y + 0.15, -8.75 + i * 2.5), index=slot)
    signboard("TrophySign", (0.3, 2.2, 14), (28.4, 16.0, 0), "Left", "MY TROPHIES", (236, 232, 222), glow=False)
    special(box("Screen", (0.3, 6, 7), (28.7, 8, 15.2)), "StatsBoard", attrs={"Face": "Left"},
            light=light((120, 160, 255), 10, 0.6))
    asset("PottedPlant", (22.5, FLOOR, -16.3), yaw=200, size=6.5, footprint=(3, 3))


# ---------------------------------------------------------------- cozy touches
def curtains_z(cx, width, z):
    box("Metal", (width + 3.4, 0.18, 0.18), (cx, 14.5, z))
    for side in (-1, 1):
        x = cx + side * (width / 2 + 0.6)
        for k in range(3):
            # folds overlap a little: the middle one is shorter so their tops and bottoms never share a plane
            box("Curtain", (0.9, 10.0 if k % 2 else 10.2, 0.45), (x + side * (k - 1) * 0.75, 9.3, z + (0.12 if k % 2 else 0)))


def bookshelf(x, cz, length):
    # sides, a back panel and shelves fitted between them (no shared faces)
    solid(box("WoodDark", (1.4, 11, 0.4), (x, 6.5, cz - length / 2)))
    solid(box("WoodDark", (1.4, 11, 0.4), (x, 6.5, cz + length / 2)))
    solid(box("WoodDark", (0.2, 11, length - 0.4), (x - 0.6, 6.5, cz)))
    keys = ("BookRed", "BookGreen", "BookCream", "BookNavy")
    for y in (1.3, 4.0, 6.7, 9.4, 12.0):
        box("WoodDark", (1.2, 0.25, length - 0.4), (x + 0.1, y, cz))
        if y > 11:
            break
        z = cz - length / 2 + 0.4
        while z < cz + length / 2 - 0.6:
            w = random.uniform(0.25, 0.5)
            h = random.uniform(1.5, 2.3)
            if random.random() < 0.12:
                blob("Leaves", 0.45, (x, y + 0.6, z + 0.3), noise=0.2)
                z += 1.0
                continue
            tilt = random.choice((0, 0, 0, 8))
            box(random.choice(keys), (1.0, h, w), (x + 0.1, y + 0.12 + h / 2, z + w / 2), rot=(tilt, 0, 0))
            z += w + 0.04


def cozy():
    for side in (-1, 1):
        curtains_z(side * 17, 14, 18.6)


# ---------------------------------------------------------------- yard
# Plot: lawn x -78.8..78.8, z -43.8..113.8 inside the hedge. Ground (terrain) is flat at y = 0.
SPAWN = (0, 0.5, 104)
FIRE = (-50, 0, -6)
POOL = (36, 68, 36, 60)  # inner water rectangle x0, x1, z0, z1 (aligned to the 4-stud terrain grid)
DECK = (15, 70, 24, 35)  # one teak deck from the house terrace to the pool coping
CARPORT = (-62, -38, 30, 58)
PLOT = (-78.8, 78.8, -43.8, 113.8)


def walk():
    """Wide concrete pavers from the gate to the terrace steps, low bollards on both sides."""
    marker("SpawnPoint", SPAWN)
    z = 33.9
    while z + 2.4 <= 112.6:
        box("Paver", (8, 0.3, 2.4), (0, 0.15, z - 1.2))
        z += 3.6
    for z in (38, 52, 66, 80, 94, 108):
        for x in (-6, 6):
            bollard(x, z)
    # boxwood balls where the walk meets the steps
    for x in (-7, 7):
        asset("Boxwood", (x, 0, 33.5), size=2.4, footprint=(2.6, 2.6))


def bollard(x, z):
    solid(cyl("Metal", 0.35, 2.2, (x, 1.1, z), segments=16))
    special(cyl("LampGlass", 0.35, 0.45, (x, 2.425, z), segments=16), "Bollard", light=light(WARM, 12, 0.9))
    cyl("Metal", 0.38, 0.15, (x, 2.725, z), segments=16)


def hedges():
    """Clipped hedge around the plot: openings for the walk (x ±7.6) and the driveway (x -58..-42)."""
    solid(box("Hedge", (162.4, 4, 2.4), (0, 2, -45)))
    for side in (-1, 1):
        solid(box("Hedge", (2.4, 4, 160), (side * 80, 2, 36.2)))
    for x0, x1 in ((-78.8, -58), (-42, -7.6), (7.6, 78.8)):
        solid(box("Hedge", (x1 - x0, 4, 2.4), ((x0 + x1) / 2, 2, 115)))
    # gate pillars at the walk, a mailbox on the inside of the right one
    for side in (-1, 1):
        solid(box("Concrete", (1.6, 4.4, 2.4), (side * 6.8, 2.2, 115)))
    box("Metal", (1.2, 1.4, 0.6), (6.8, 2.9, 113.5))
    box("Metal", (0.12, 2.2, 0.12), (6.8, 1.1, 113.5))


def driveway():
    """Concrete slabs from the street to the carport; a flat roof on four slim columns; the car underneath."""
    x0, x1, z0, z1 = CARPORT
    z = 30
    while z < 113.8:
        depth = min(9.4, 113.8 - z)
        box("Concrete", (16, 0.3, depth), (-50, 0.15, z + depth / 2))
        z += 10
    solid(box("RoofSlab", (x1 - x0, 0.8, z1 - z0), ((x0 + x1) / 2, 11.6, (z0 + z1) / 2)))
    for x in (x0 + 0.5, x1 - 0.5):
        for zz in (z0 + 0.5, z1 - 0.5):
            solid(box("Metal", (0.5, 11.2, 0.5), (x, 5.6, zz)))
    special(cyl("LampGlass", 0.45, 0.1, ((x0 + x1) / 2, 11.15, (z0 + z1) / 2), segments=16), "Downlight",
            light=light(WARM, 20, 1.1, shadows=True, surface="Bottom", angle=90))
    asset("Car", (-50, 0.3, 44), yaw=0, size=15, fit="length", footprint=(6.5, 15.5))


def side_paths():
    """Stepping pavers from the terrace to the fire lounge (left). On the right the pool deck meets the terrace."""
    for x in (-18.6, -22.8, -27, -31.2, -35.4, -39.6):
        box("Paver", (3, 0.3, 3), (x, 0.15, 24.5))
    for z in (20.3, 16.1, 11.9, 7.7):
        box("Paver", (3, 0.3, 3), (-43.8, 0.15, z))


def fire_lounge():
    """Stone patio with a square concrete fire pit and four outdoor sofas around it."""
    fx, _, fz = FIRE
    box("Paver", (24, 0.3, 24), (fx, 0.15, fz))
    solid(box("Concrete", (5.2, 1.1, 5.2), (fx, 0.85, fz)))
    box("LavaRock", (3.8, 0.12, 3.8), (fx, 1.46, fz))
    special(box("Marker", (1, 1, 1), (fx, 2.0, fz)), "FireCore", hidden=True, fire=True,
            light=light((255, 150, 70), 34, 3, shadows=True))
    OBJECTS[-1].hide_render = True
    # models face +Z at yaw 0; footprints are in world axes
    for dx, dz, yaw in ((0, -8.5, 0), (0, 8.5, 180), (-8.5, 0, 90), (8.5, 0, 270)):
        fp = (9.2, 3.6) if dx == 0 else (3.6, 9.2)
        asset("OutdoorSofa", (fx + dx, 0.3, fz + dz), yaw=yaw, size=9, fit="length", footprint=fp)


def pool():
    """Pool: tiled basin (water is terrain, filled by the server). A slim stone coping all round, flush with
    the lawn on three sides; one wide teak deck on the house side with three loungers facing the water."""
    x0, x1, z0, z1 = POOL
    special(box("Marker", (1, 1, 1), ((x0 + x1) / 2, -2, (z0 + z1) / 2)), "Pool", hidden=True,
            attrs={"X0": x0, "X1": x1, "Z0": z0, "Z1": z1, "Bottom": -4.2, "Surface": -0.4})
    OBJECTS[-1].hide_render = True
    w, d, cx, cz = x1 - x0, z1 - z0, (x0 + x1) / 2, (z0 + z1) / 2
    box("PoolTile", (w, 0.4, d), (cx, -4.4, cz))
    for z in (z0 - 0.5, z1 + 0.5):
        box("PoolTile", (w + 2, 4.6, 1), (cx, -2.3, z))
    for x in (x0 - 0.5, x1 + 0.5):
        box("PoolTile", (1, 4.6, d), (x, -2.3, cz))
    special(box("PoolTile", (0.1, 0.6, 3), (x0 + 0.05, -2.2, cz)), "PoolLight",
            light=light((220, 236, 255), 16, 0.8, surface="Right", angle=120))
    # coping and deck share one level (top 0.35), so there are no steps around the water
    top = 0.35
    for z in (z0 - 0.5, z1 + 0.5):
        solid(box("Coping", (w + 2, top, 1), (cx, top / 2, z)))
    for x in (x0 - 0.5, x1 + 0.5):
        solid(box("Coping", (1, top, d), (x, top / 2, cz)))
    dx0, dx1, dz0, dz1 = DECK
    solid(box("Deck", (dx1 - dx0, top, dz1 - dz0), ((dx0 + dx1) / 2, top / 2, (dz0 + dz1) / 2)))
    # three loungers in a row, feet towards the water (+Z), umbrellas between them
    for x in (cx - 8, cx, cx + 8):
        asset("Lounger", (x, top, dz0 + 4.4), yaw=0, size=7, fit="length", footprint=(2.8, 7.1))
    for x in (cx - 4, cx + 4):
        asset("Umbrella", (x, top, dz0 + 3), size=9, footprint=(2, 2))


def garden():
    """A few specimen trees, ornamental grasses along the house front, shade trees behind the house."""
    for side in (-1, 1):
        box("Gravel", (13, 0.15, 2), (side * 22.5, 0.075, 21.5))
        for x in (17.5, 22.5, 27.5):
            asset("Grass", (side * x, 0.15, 21.5), size=2.6, footprint=(1.8, 1.8))
    asset("ShadeTree", (-24, 0, 70), size=18, footprint=(10, 10))
    asset("ShadeTree", (22, 0, 80), yaw=120, size=15, footprint=(9, 9))
    asset("ShadeTree", (56, 0, 88), yaw=240, size=17, footprint=(10, 10))
    asset("ShadeTree", (-10, 0, -33), size=22, footprint=(14, 14))
    asset("ShadeTree", (44, 0, -31), yaw=70, size=20, footprint=(14, 14))
    asset("ShadeTree", (-70, 0, 16), yaw=200, size=14, footprint=(9, 9))


# ---------------------------------------------------------------- zone upgrades: the chill zone grows with the owner's progress
# Level points come from trophies, installed and played games (src/shared/PS5/Progress.luau). Each level adds its own set.
def upgrades():
    with tier(2):  # Cozy: corten planters on the terrace, an outdoor rug, potted olives at the gate
        for side in (-1, 1):
            solid(box("Corten", (3.2, 1.4, 1.6), (side * 11, 1.7, 26)))
            asset("Grass", (side * 11, 2.4, 26), size=2.2, footprint=(1.6, 1.6))
            asset("PottedOlive", (side * 10.5, 0, 110.5), size=6, footprint=(2.6, 2.6))
        box("Rug", (10, 0.05, 4.4), (0, 1.025, 24.6))
    with tier(3):  # Garden: a long still-water basin beside the walk, lavender, cherry trees
        solid(box("Coping", (4, 0.6, 50), (-12, 0.3, 70)))
        box("WaterStill", (3, 0.05, 49), (-12, 0.625, 70))
        for z in (48, 62, 76, 90):
            asset("Lavender", (12, 0, z), size=2.2, footprint=(2.6, 2.6))
        asset("CherryTree", (-30, 0, 100), size=14, footprint=(10, 10))
        asset("CherryTree", (40, 0, 104), yaw=120, size=13, footprint=(10, 10))
    with tier(4):  # Lounge: hot tub next to the pool deck, an outdoor kitchen by the boardwalk
        asset("HotTub", (71, 0, 17), size=8, fit="length", footprint=(8.2, 8.2))
        special(box("Marker", (1, 1, 1), (71, 3, 17)), "HotTub", hidden=True)
        OBJECTS[-1].hide_render = True
        asset("BBQIsland", (44, 0, 18), size=10, fit="length", footprint=(10.2, 3.8))
    with tier(5):  # Luxury: a sports car on the driveway, a daybed on the pool deck, a bronze sculpture
        asset("SportsCar", (-50, 0.3, 74), yaw=180, size=15, fit="length", footprint=(6.5, 15.5))
        asset("Daybed", (73, 0, 67), yaw=270, size=7, fit="length", footprint=(6.4, 7.2))
        asset("Sculpture", (-20, 0, 50), size=7, footprint=(3, 3))
    with tier(6):  # Legend: rooftop terrace with a glass railing and loungers, a golden trophy statue on the lawn
        y = 18.25  # top of the roof gravel; the railing stands on the slab edge (18.2)
        for z in (-21.6, 28.2):
            box("RailGlass", (63.2, 3.2, 0.2), (0, 19.8, z))
        for x in (-31.6, 31.6):
            box("RailGlass", (0.2, 3.2, 49.6), (x, 19.8, 3.3))
        for x in (-6, 6):
            asset("Lounger", (x, y, 12), yaw=0, size=7, fit="length", footprint=(2.8, 7.1))
        asset("Umbrella", (0, y, 8), size=9, footprint=(2, 2))
        asset("TrophyStatue", (24, 0, 62), size=8, footprint=(3.4, 3.4))


def build():
    common.reset()
    OBJECTS.clear()
    SPECIALS.clear()
    ASSETS.clear()
    _materials.clear()
    random.seed(7)
    house()
    play_zone()
    games_zone()
    trophy_zone()
    cozy()
    terrace()
    walk()
    hedges()
    driveway()
    side_paths()
    fire_lounge()
    pool()
    garden()
    upgrades()
    return OBJECTS


def _scene_lights():
    """Blender point lights for every special that carries a Roblox light, so the renders match the game."""
    for obj in OBJECTS:
        spec = SPECIALS.get(obj.name)
        if not spec or "light" not in spec:
            continue
        info = spec["light"]
        data = bpy.data.lights.new(spec["name"], "POINT")
        data.color = tuple(c / 255 for c in info["color"])
        data.energy = info["brightness"] * info["range"] * 25
        data.shadow_soft_size = 0.5
        common.link(bpy.data.objects.new(spec["name"], data)).location = obj.location


def _render_setup():
    scene = common.setup_render(1600, 900, samples=48)
    common.world((0.09, 0.08, 0.12), 0.7)
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=260)
    ground = common.mesh_object("Ground", bm, common.material("Ground", (0.05, 0.09, 0.04), roughness=0.95))
    ground.location = (0, -35, -0.02)
    x0, x1, z0, z1 = POOL
    common.box("Water", (x1 - x0, z1 - z0, 0.1), R((x0 + x1) / 2, -0.45, (z0 + z1) / 2),
               common.material("Water", (0.05, 0.25, 0.32), roughness=0.05))
    sun = bpy.data.lights.new("Dusk", "SUN")
    sun.energy = 1.2
    sun.color = (1.0, 0.72, 0.5)
    dusk = common.link(bpy.data.objects.new("Dusk", sun))
    dusk.rotation_euler = (math.radians(75), 0, math.radians(-40))
    _scene_lights()
    data = bpy.data.lights.new("Fire", "POINT")
    data.energy = 3000
    data.color = (1, 0.6, 0.3)
    common.link(bpy.data.objects.new("Fire", data)).location = R(FIRE[0], 2, FIRE[2])
    return scene


def hero():
    _render_setup()
    common.camera(R(60, 45, 150), R(0, 4, 30), lens=30)
    common.render("chillzone_hero.png")
    common.camera(R(0, 10, 25), R(0, 6, -10), lens=20)
    return common.render("chillzone_inside.png")


if __name__ == "__main__":
    objs = build()
    tris = sum(common.triangles(o) for o in objs)
    print(f"chillzone: {len(objs)} objects, {sum(1 for o in objs if o.get('collide'))} solid, "
          f"{len(SPECIALS)} special, {len(ASSETS)} asset spots, {tris} triangles")
    hero()
