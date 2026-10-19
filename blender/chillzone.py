"""Chill zone, entirely authored in Blender: house, yard, colliders, lights, signs and gameplay markers.

    python3 blender/chillzone.py                     # build + renders (assets/renders/chillzone_hero.png, chillzone_inside.png)
    python3 blender/export_luau.py chillzone         # writes src/shared/PS5/Assets/ChillZoneParts.luau

Layout is made to be read at a glance from the spawn point:
    spawn (0, 74) -> signpost -> straight lantern path -> wide open entrance
    inside: TV, PS5 and sofa in the middle, MY GAMES on the left wall, MY TROPHIES on the right wall
    yard: campfire on the left, pond on the right.

Everything is authored in Roblox coordinates through R(x, y, z) (Y up, studs). Every object is a Roblox-friendly
primitive (obj["prim"] = Block | Cylinder | Sphere | Wedge, obj["size"] in Roblox axes) with a style key obj["rbx"].
obj["collide"] = 1 makes it solid in Roblox. special(obj, name, ...) turns an object into a named part placed directly
in the ChillZone model, optionally with a light, a sign (SurfaceGui text), fire, an Index attribute or hidden (markers).
The server (src/server/ChillZone.server.luau) only adds terrain, builds these parts and sets the lighting.
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

# key: (rgb 0-255, Roblox material, transparency)
STYLES = {
    "Plaster": ((236, 231, 220), "Plaster", 0),
    "Cladding": ((70, 50, 40), "WoodPlanks", 0),
    "WoodFloor": ((170, 122, 82), "WoodPlanks", 0),
    "WoodDark": ((58, 42, 34), "Wood", 0),
    "WoodLight": ((196, 156, 110), "WoodPlanks", 0),
    "Ceiling": ((214, 182, 140), "WoodPlanks", 0),
    "Stone": ((132, 128, 124), "Cobblestone", 0),
    "Slate": ((104, 104, 112), "Slate", 0),
    "Roof": ((50, 52, 62), "RoofShingles", 0),
    "Glass": ((170, 205, 255), "Glass", 0.65),
    "Metal": ((34, 34, 38), "Metal", 0),
    "Sofa": ((70, 80, 108), "Fabric", 0),
    "Cushion": ((88, 100, 132), "Fabric", 0),
    "Rug": ((56, 62, 112), "Carpet", 0),
    "RugPurple": ((96, 64, 140), "Carpet", 0),
    "PillowPink": ((255, 122, 162), "Fabric", 0),
    "PillowBlue": ((120, 200, 255), "Fabric", 0),
    "BeanOrange": ((255, 120, 88), "Fabric", 0),
    "BeanPurple": ((122, 110, 255), "Fabric", 0),
    "LampShade": ((255, 226, 184), "Fabric", 0),
    "Ceramic": ((186, 112, 82), "Concrete", 0),
    "Leaves": ((70, 132, 74), "LeafyGrass", 0),
    "LeavesDark": ((46, 100, 62), "LeafyGrass", 0),
    "Pine": ((38, 88, 66), "LeafyGrass", 0),
    "Autumn": ((214, 128, 58), "LeafyGrass", 0),
    "Bark": ((96, 70, 50), "Wood", 0),
    "Rock": ((122, 124, 130), "Rock", 0),
    "Hills": ((72, 110, 66), "Grass", 0),
    "Reeds": ((118, 146, 72), "Grass", 0),
    "Lily": ((62, 134, 68), "SmoothPlastic", 0),
    "FlowerPink": ((255, 130, 190), "SmoothPlastic", 0),
    "FlowerYellow": ((255, 214, 90), "SmoothPlastic", 0),
    "FlowerWhite": ((245, 245, 255), "SmoothPlastic", 0),
    "ArtA": ((255, 140, 90), "SmoothPlastic", 0),
    "ArtB": ((90, 170, 255), "SmoothPlastic", 0),
    "NeonBlue": ((0, 140, 255), "Neon", 0),
    "NeonPurple": ((160, 80, 255), "Neon", 0),
    "NeonWarm": ((255, 196, 130), "Neon", 0),
    "Ember": ((255, 110, 40), "Neon", 0),
    "Curtain": ((222, 196, 166), "Fabric", 0),
    "Blanket": ((238, 226, 204), "Fabric", 0),
    "Knit": ((196, 120, 96), "Fabric", 0),
    "Leather": ((150, 92, 62), "Leather", 0),
    "BookRed": ((168, 62, 60), "SmoothPlastic", 0),
    "BookGreen": ((62, 118, 92), "SmoothPlastic", 0),
    "BookCream": ((230, 214, 182), "SmoothPlastic", 0),
    "BookNavy": ((52, 64, 110), "SmoothPlastic", 0),
    "Candle": ((250, 242, 228), "SmoothPlastic", 0),
    "Mug": ((244, 244, 248), "SmoothPlastic", 0),
    "Screen": ((4, 6, 12), "Glass", 0),
    "Sign": ((20, 20, 30), "SmoothPlastic", 0),
    "Marker": ((255, 255, 255), "SmoothPlastic", 1),
    "BulbWarm": ((255, 200, 120), "Neon", 0),
    "BulbPink": ((255, 120, 180), "Neon", 0),
    "BulbBlue": ((120, 200, 255), "Neon", 0),
    "BulbGreen": ((180, 255, 150), "Neon", 0),
    "ShelfGlass": ((200, 220, 255), "Glass", 0.3),
    # zone upgrades (tiers 2-6)
    "FountainWater": ((90, 180, 235), "Glass", 0.35),
    "Blossom": ((255, 176, 206), "Grass", 0),
    "Gold": ((236, 192, 84), "Metal", 0),
    "Marble": ((236, 234, 240), "Marble", 0),
    "Velvet": ((168, 26, 44), "Carpet", 0),
    "Crystal": ((140, 230, 255), "Neon", 0.25),
    "PlatinumGlow": ((180, 225, 255), "Neon", 0),
    "SkyBeam": ((150, 120, 255), "Neon", 0.82),
    "AuroraGreen": ((90, 255, 170), "Neon", 0.8),
    "AuroraPurple": ((170, 110, 255), "Neon", 0.82),
}

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


def signboard(name, size, at, face, text, color, rot=(0, 0, 0), glow=True):
    obj = box("Sign", size, at, rot=rot)
    return special(obj, name, sign=dict(face=face, text=text, color=color),
                   light=light(color, 14, 0.8) if glow else None)


# ---------------------------------------------------------------- house shell (x ±30, z ±20, floor top y 1)
def house():
    solid(box("Stone", (61, 1.0, 41), (0, 0.5, 0)))
    box("WoodFloor", (58.6, 0.1, 38.6), (0, 1.03, 0))
    # back wall with two windows at x ±20 (behind the games and trophy corners)
    solid(box("Plaster", (60, 4, 1), (0, 3, -19.5)))
    solid(box("Plaster", (60, 4, 1), (0, 15, -19.5)))
    solid(box("Plaster", (30, 8, 1), (0, 9, -19.5)))
    for side in (-1, 1):
        solid(box("Plaster", (5, 8, 1), (side * 27.5, 9, -19.5)))
        window_z(side * 20, -19.5, 10)
    solid(box("Plaster", (1, 16, 40), (29.5, 9, 0)))
    solid(box("Plaster", (1, 16, 40), (-29.5, 9, 0)))
    # front wall: a wide open entrance x -7..7 (y 1..12) and two big windows, so the room is visible from the yard
    for side in (-1, 1):
        solid(box("Plaster", (23, 4, 1), (side * 18.5, 3, 19.5)))
        solid(box("Plaster", (23, 4, 1), (side * 18.5, 15, 19.5)))
        solid(box("Plaster", (3, 8, 1), (side * 8.5, 9, 19.5)))
        solid(box("Plaster", (6, 8, 1), (side * 27, 9, 19.5)))
        window_z(side * 17, 19.5, 14)
        box("Cladding", (2.2, 16, 0.35), (side * 8.6, 9, 20.15))
        box("Metal", (0.8, 1.4, 0.8), (side * 8.6, 9.2, 20.7), bevel=0.08)
        special(box("NeonWarm", (0.5, 0.9, 0.5), (side * 8.6, 9.2, 20.75)), "PorchLamp", light=light((255, 190, 130), 16, 1.2))
        box("WoodDark", (0.5, 11, 1.4), (side * 7.25, 6.5, 19.5))
    solid(box("Plaster", (14, 5, 1), (0, 14.5, 19.5)))
    box("WoodDark", (15, 0.6, 1.4), (0, 12.2, 19.5))
    box("NeonWarm", (14, 0.12, 0.12), (0, 11.85, 20.15))
    for x in (-29.8, 29.8):
        for z in (-19.8, 19.8):
            box("Cladding", (0.8, 16.2, 0.8), (x, 9, z))
    roof()
    box("Stone", (3.4, 11, 3.4), (22, 22.5, -8))
    box("Slate", (4, 0.5, 4), (22, 28.2, -8))
    marker("ChimneyTop", (22, 29, -8))


def window_z(cx, z, width):
    """Window in a wall facing ±Z: frame, mullions, glass (solid)."""
    solid(box("Glass", (width, 8, 0.2), (cx, 9, z)))
    for dx in (-width / 2, width / 2):
        box("Metal", (0.35, 8.4, 1.3), (cx + dx, 9, z))
    for dy in (-4, 4):
        box("Metal", (width + 0.4, 0.35, 1.3), (cx, 9 + dy, z))
    box("Metal", (0.2, 8, 0.4), (cx, 9, z))
    box("Metal", (width, 0.2, 0.4), (cx, 10.5, z))
    box("WoodDark", (width + 1, 0.3, 1.0), (cx, 4.9, z + (0.6 if z > 0 else -0.6)))  # sill outside


def roof():
    rise, run = 7.0, 23.0
    angle = math.degrees(math.atan2(rise, run))
    slope = math.hypot(rise, run)
    for side in (-1, 1):
        solid(box("Roof", (67, 0.8, slope + 0.6), (0, 17 + rise / 2 + 0.4, side * run / 2), rot=(side * angle, 0, 0)))
        box("WoodDark", (67, 0.7, 0.4), (0, 16.95, side * (run + 0.2)))
        box("NeonPurple", (66.4, 0.25, 0.25), (0, 16.55, side * (run + 0.25)))
    box("WoodDark", (67.4, 0.6, 0.9), (0, 17 + rise + 0.75, 0))
    for x in (-30, 30):
        box("Plaster", (1, 0.9, 40), (x, 17.45, 0))
        wedge("Plaster", (1, 6.1, 20), (x, 20.95, 10), rot=(0, 180, 0))
        wedge("Plaster", (1, 6.1, 20), (x, 20.95, -10))
        cyl("Metal", 1.9, 1.3, (x, 20.4, 0), rot=(0, 0, 90), segments=20)
        cyl("NeonBlue", 1.5, 1.4, (x, 20.4, 0), rot=(0, 0, 90), segments=20)
        for side in (-1, 1):
            a = (x + (0.6 if x > 0 else -0.6), 16.7, side * 23.3)
            b = (x + (0.6 if x > 0 else -0.6), 24.3, 0)
            beam("NeonBlue", a, b, 0.25)
    solid(box("Ceiling", (58.6, 0.2, 38.6), (0, 16.9, 0)))
    for x in range(-24, 25, 8):
        box("WoodDark", (0.8, 0.8, 38.4), (x, 16.4, 0))
    # pendant lamps: one over each zone
    for x, z in ((-20, 0), (0, -3), (20, 0)):
        cyl("Metal", 0.06, 2.6, (x, 15.5, z), segments=6)
        cyl("Metal", 1.6, 1.4, (x, 13.6, z), segments=20, radius2=0.35)
        special(cyl("NeonWarm", 1.25, 0.15, (x, 12.9, z), segments=20), "CeilingLamp",
                light=light((255, 205, 160), 30, 1.2, shadows=True))


# ---------------------------------------------------------------- PLAY zone (centre): TV, PS5, sofa, glowing pad
CONSOLE = (-5.5, 4, -16.3)


def play_zone():
    special(box("Rug", (24, 0.1, 18), (0, 1.1, -5), bevel=0.8), "Rug")
    box("Blanket", (12, 0.08, 7), (0, 1.16, -3.5), bevel=0.4)
    # slatted accent wall
    box("WoodDark", (24, 15.6, 0.15), (0, 9, -18.95))
    x = -11.6
    while x <= 11.7:
        box("Cladding", (0.45, 15.6, 0.3), (x, 9, -18.75))
        x += 0.85
    box("NeonBlue", (23, 0.15, 0.15), (0, 16.2, -18.5))
    # big TV
    solid(box("Metal", (16.4, 9.4, 0.6), (0, 10, -18.25), bevel=0.1))
    special(box("Screen", (15.6, 8.6, 0.1), (0, 10, -17.92)), "TVScreen", light=light((80, 140, 255), 14, 0.8))
    box("NeonBlue", (16, 0.15, 0.15), (0, 5.2, -18.45))
    # floating TV stand with the PS5 spot
    solid(box("WoodDark", (16, 2.6, 3.8), (0, 2.7, -16.5), bevel=0.12))
    box("WoodLight", (16.1, 0.25, 3.9), (0, 3.88, -16.5), bevel=0.05)
    box("NeonBlue", (15, 0.12, 0.12), (0, 1.35, -14.7))
    marker("ConsoleSpot", CONSOLE)
    # sofa facing the TV: the server puts a Creator Store sofa here (Assets/CreatorStore.luau);
    # these Blender parts are its fallback and are removed when the store model loads
    def sofa(obj):
        return special(obj, "SofaFallback")
    sofa(solid(box("Sofa", (12.4, 1.8, 5.4), (0, 2.2, 6.3), bevel=0.3)))
    for ax in (-5.7, 5.7):
        sofa(solid(box("Sofa", (1.2, 3.2, 5.6), (ax, 2.9, 6.3), bevel=0.4)))
    for cx in (-2.6, 2.6):
        sofa(box("Cushion", (5.0, 1.1, 4.6), (cx, 3.55, 5.9), bevel=0.35))
        sofa(box("Cushion", (5.0, 3.6, 1.4), (cx, 5.3, 8.4), rot=(-10, 0, 0), bevel=0.5))
    sofa(solid(box("Sofa", (12.4, 4.2, 1.0), (0, 4.2, 9.2), bevel=0.3)))
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
        flame = blob("NeonWarm", 0.12, (-2.6 + dx, 3.4 + h + 0.18, -3.3), scale=(1, 1.6, 1), noise=0)
        if dx == 0:
            special(flame, "CandleLight", light=light((255, 170, 90), 10, 1.2, shadows=True, flicker=True))
    for dx in (-0.5, 0.5):
        cyl("Mug", 0.36, 0.7, (2.8 + dx, 3.6, -3.0 + dx * 0.4), segments=10)
    # arc floor lamp and a plant either side of the TV stand
    cyl("Metal", 1.2, 0.3, (-11, 1.2, -16), segments=20)
    cyl("Metal", 0.15, 8.6, (-11, 5.6, -16), segments=8)
    special(cyl("LampShade", 1.4, 2.0, (-11, 10.5, -16), segments=20, radius2=0.9), "LampShade",
            light=light((255, 190, 130), 22, 1.5, shadows=True))
    potted_plant(11, -16.5, 1.2)


def potted_plant(x, z, r=1.0):
    solid(cyl("Ceramic", r, 2.2 * r, (x, 1.0 + 1.1 * r, z), segments=16, radius2=r * 0.82, bevel=0.1))
    for i in range(6):
        a = i / 6 * math.tau
        blob("Leaves" if i % 2 else "LeavesDark", 1.1 * r, (x + math.cos(a) * 0.8 * r, 1 + 2.6 * r + (i % 3) * 0.7, z + math.sin(a) * 0.8 * r),
             scale=(0.75, 1.6, 0.75), rot=(math.cos(a) * 25, 0, math.sin(a) * 25), noise=0.15)


# ---------------------------------------------------------------- MY GAMES (left wall)
def games_zone():
    for y in (9.5, 5.5):
        solid(box("WoodDark", (2.6, 0.4, 22), (-28.2, y, -2), bevel=0.08))
        for z in (-12, -2, 8):
            box("Metal", (2.2, 1.2, 0.3), (-28.3, y - 0.7, z))
    box("NeonBlue", (0.12, 0.12, 22), (-26.95, 4.95, -2))
    slot = 0
    for y in (9.5, 5.5):
        for i in range(10):
            slot += 1
            marker("GameSlot", (-28.2, y + 0.2, -11.5 + i * 2.1), index=slot, rot=(0, 90, 0))
    signboard("GameSign", (0.3, 2.2, 13), (-28.85, 14.2, -2), "Right", "🎮 MY GAMES", (120, 200, 255))
    # beanbags to sit and browse
    solid(blob("BeanOrange", 2.1, (-20, 2.5, -7), scale=(1.15, 0.8, 1.15), noise=0.06, subdiv=2))
    solid(blob("BeanPurple", 2.1, (-20, 2.5, 1.5), scale=(1.15, 0.8, 1.15), noise=0.06, subdiv=2))
    potted_plant(-26, -16.5, 1.1)
    # reading corner by the entrance: bookshelf, armchair, tall lamp
    bookshelf(-28.2, 14, 7)
    armchair(-21, 14.5, 150)
    cyl("Metal", 0.15, 9, (-25, 5.5, 17.5), segments=8)
    cyl("Metal", 1.0, 0.2, (-25, 1.1, 17.5), segments=16)
    special(cyl("NeonWarm", 0.6, 3.0, (-25, 10.5, 17.5), segments=12), "ReadingLamp",
            light=light((255, 190, 120), 18, 1.1, shadows=True))


# ---------------------------------------------------------------- MY TROPHIES (right wall)
def trophy_zone():
    solid(box("WoodDark", (1, 13.6, 22.4), (28.5, 7.8, 0)))
    for z in (-11.2, 11.2):
        solid(box("WoodDark", (3.4, 13.6, 0.6), (27, 7.8, z), bevel=0.06))
    box("WoodDark", (3.8, 0.7, 23.2), (27, 14.9, 0), bevel=0.1)
    solid(box("WoodDark", (3.8, 1.0, 23.2), (27, 1.5, 0), bevel=0.1))
    box("NeonPurple", (0.2, 0.2, 22), (25.3, 14.4, 0))
    slot = 0
    for y in (12, 8, 4):
        solid(box("ShelfGlass", (3, 0.3, 21.4), (27, y, 0)))
        box("BulbBlue", (0.15, 0.1, 21), (28, y + 3.6, 0))
        for i in range(8):
            slot += 1
            marker("TrophySlot", (27, y + 0.15, -8.75 + i * 2.5), index=slot)
    signboard("TrophySign", (0.3, 2.2, 14), (28.4, 16.0, 0), "Left", "🏆 MY TROPHIES", (255, 215, 110))
    special(box("Screen", (0.3, 6, 7), (28.7, 8, 15.2)), "StatsBoard", attrs={"Face": "Left"},
            light=light((120, 160, 255), 10, 0.6))
    cyl("RugPurple", 6.0, 0.1, (16, 1.1, 6), segments=32)
    solid(blob("BeanPurple", 2.1, (18, 2.5, 3), scale=(1.15, 0.8, 1.15), noise=0.06, subdiv=2))
    solid(cyl("Knit", 1.3, 1.4, (14, 1.75, 9), segments=14))
    potted_plant(25.5, -16.5, 1.0)


# ---------------------------------------------------------------- cozy touches
def fairy_lights(z, y=16.0):
    for x0 in range(-28, 28, 8):
        x1 = min(x0 + 8, 28)
        for k in range(1, 6):
            t = k / 6
            blob("NeonWarm", 0.16, (x0 + (x1 - x0) * t, y - math.sin(t * math.pi) * 1.1, z), noise=0, subdiv=1)


def curtains_z(cx, width, z):
    box("Metal", (width + 3.4, 0.18, 0.18), (cx, 14.5, z))
    for side in (-1, 1):
        x = cx + side * (width / 2 + 0.6)
        for k in range(3):
            box("Curtain", (0.9, 10.2, 0.45), (x + side * (k - 1) * 0.75, 9.3, z + (0.12 if k % 2 else 0)))


def bookshelf(x, cz, length):
    solid(box("WoodDark", (1.4, 11, 0.4), (x, 6.5, cz - length / 2)))
    solid(box("WoodDark", (1.4, 11, 0.4), (x, 6.5, cz + length / 2)))
    solid(box("WoodDark", (0.2, 11, length), (x - 0.6, 6.5, cz)))
    keys = ("BookRed", "BookGreen", "BookCream", "BookNavy")
    for y in (1.3, 4.0, 6.7, 9.4, 12.0):
        box("WoodDark", (1.4, 0.25, length), (x, y, cz))
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


def armchair(x, z, yaw):
    c, s_ = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))

    def at(dx, dy, dz):
        return (x + dx * c + dz * s_, dy, z - dx * s_ + dz * c)
    solid(box("Leather", (4.2, 1.4, 4.0), at(0, 2.3, 0), rot=(0, yaw, 0), bevel=0.25))
    solid(box("Leather", (4.2, 4.0, 1.0), at(0, 4.2, 1.6), rot=(-8, yaw, 0), bevel=0.3))
    for dx in (-2.0, 2.0):
        box("Leather", (0.8, 2.4, 4.0), at(dx, 3.0, 0), rot=(0, yaw, 0), bevel=0.25)
    for dx in (-1.7, 1.7):
        for dz in (-1.6, 1.6):
            cyl("WoodDark", 0.15, 1.6, at(dx, 1.4, dz), segments=6)
    box("Knit", (3.2, 0.3, 2.6), at(0.2, 3.15, -0.2), rot=(0, yaw + 6, 0))
    box("PillowPink", (2.2, 1.8, 0.7), at(0, 4.1, 0.9), rot=(-12, yaw, 0), bevel=0.25)


def cozy():
    fairy_lights(-18.4)
    fairy_lights(18.4)
    for side in (-1, 1):
        curtains_z(side * 17, 14, 18.6)
    for z in (-17.5, 17.5):
        special(box("NeonWarm", (0.2, 0.2, 0.2), (0, 15, z)), "FairyGlow",
                light=light((255, 190, 130), 16, 0.6, surface="Back" if z < 0 else "Front", angle=150))
    for x in (-13, 13):
        cyl("Metal", 0.04, 3.2, (x, 14.4, 15.5), segments=4)
        cyl("Ceramic", 0.8, 1.0, (x, 12.4, 15.5), segments=12, radius2=0.6)
        for k in range(6):
            a = k / 6 * math.tau
            for j in range(3):
                blob("Leaves" if (k + j) % 2 else "LeavesDark", 0.35, (x + math.cos(a) * 0.8, 12.6 - j * 0.7, 15.5 + math.sin(a) * 0.8),
                     noise=0.15)


# ---------------------------------------------------------------- porch
def porch():
    z = 20.3
    while z < 28:
        solid(box("WoodLight", (24, 0.9, 0.62), (0, 0.55, z + 0.31)))
        z += 0.7
    for x in (-11.6, 11.6):
        for zz in (21, 27.6):
            solid(cyl("WoodDark", 0.35, 4.2, (x, 2.1, zz), segments=8))
        solid(box("WoodDark", (0.35, 0.3, 7.2), (x, 4.1, 24.3)))
        box("WoodDark", (0.25, 0.25, 7.2), (x, 2.4, 24.3))
        solid(box("WoodDark", (0.3, 3.0, 7.2), (x, 2.5, 24.3)))
    for side in (-1, 1):
        solid(box("WoodDark", (7.6, 0.3, 0.35), (side * 7.9, 4.1, 27.6)))
        box("WoodDark", (7.6, 0.25, 0.25), (side * 7.9, 2.4, 27.6))
        solid(box("WoodDark", (7.6, 3.0, 0.3), (side * 7.9, 2.5, 27.6)))
        solid(box("WoodDark", (3, 1.6, 2), (side * 9.6, 1.8, 22), bevel=0.1))
        for i in range(6):
            key = ("FlowerPink", "FlowerYellow", "FlowerWhite")[i % 3]
            blob(key, 0.45, (side * 9.6 + random.uniform(-1.1, 1.1), 2.9, 22 + random.uniform(-0.6, 0.6)), noise=0.2)
        blob("Leaves", 0.9, (side * 9.6, 2.7, 22), scale=(1.6, 0.6, 1.0))
    solid(box("WoodLight", (8, 0.3, 1.2), (0, 0.51, 28.6)))
    solid(box("WoodLight", (8, 0.3, 1.2), (0, 0.18, 29.8)))
    # wide canopy over the entrance with the CHILL ZONE sign on top
    solid(box("WoodDark", (18, 0.5, 5.2), (0, 12.9, 22.4), bevel=0.08))
    box("NeonWarm", (17, 0.12, 0.12), (0, 12.6, 24.9))
    for x in (-8.5, 8.5):
        solid(cyl("WoodDark", 0.3, 11.9, (x, 6.95, 24.6), segments=8))
    signboard("ChillSign", (14, 2.6, 0.3), (0, 14.5, 20.4), "Back", "CHILL ZONE", (120, 200, 255))
    box("Rug", (8, 0.1, 3), (0, 1.07, 22), bevel=0.3)


# ---------------------------------------------------------------- yard
SPAWN = (0, 0.5, 74)
FIRE = (-30, 0, 56)
POND = (42, 0, 52)


def yard():
    marker("SpawnPoint", SPAWN)
    # straight stepping-stone path from the spawn to the porch steps, lanterns on both sides
    for i in range(17):
        z = 31.4 + i * 2.4
        cyl("Slate", 1.4, 0.2, (math.sin(i * 0.9) * 0.3, 0.08, z), segments=9, rot=(0, random.uniform(0, 90), 0))
    for z in (36, 46, 56, 66):
        for x in (-4.5, 4.5):
            solid(cyl("Metal", 0.18, 4.2, (x, 2.1, z), segments=8))
            box("Metal", (0.9, 0.15, 0.9), (x, 4.3, z))
            special(box("NeonWarm", (0.6, 0.8, 0.6), (x, 4.8, z)), "PathLamp", light=light((255, 190, 130), 14, 1))
            box("Metal", (1.0, 0.3, 1.0), (x, 5.35, z), rot=(0, 45, 0))
    # signpost right of the path, facing the spawn
    solid(cyl("WoodDark", 0.3, 6.4, (7.5, 3.2, 64), segments=8))
    for y, text, color in ((5.6, "▲ HOUSE · PS5", (120, 200, 255)), (4.3, "◀ CAMPFIRE", (255, 170, 90)), (3.0, "POND ▶", (120, 230, 200))):
        signboard("Signpost", (5.4, 1.05, 0.25), (7.5, y, 64.3), "Back", text, color, glow=False)
    # campfire on the left
    special(box("Marker", (1, 1, 1), (FIRE[0], 1, FIRE[2])), "FireCore", hidden=True, fire=True,
            light=light((255, 150, 70), 34, 3, shadows=True))
    OBJECTS[-1].hide_render = True
    cyl("Slate", 12.5, 0.2, (FIRE[0], 0.05, FIRE[2]), segments=40)
    cyl("Stone", 12.9, 0.16, (FIRE[0], 0.02, FIRE[2]), segments=40)
    for i in range(10):
        a = i / 10 * math.tau
        solid(rock("Rock", 0.75, (FIRE[0] + math.cos(a) * 3.2, 0.45, FIRE[2] + math.sin(a) * 3.2), scale=(1.1, 0.8, 1.0)))
    for a in (30, 120, 75):
        cyl("Bark", 0.4, 4.2, (FIRE[0], 0.55, FIRE[2]), rot=(0, a, 90), segments=8)
    for i in range(7):
        blob("Ember", 0.35, (FIRE[0] + random.uniform(-1, 1), 0.35, FIRE[2] + random.uniform(-1, 1)), noise=0.3)
    for i in range(4):
        a = i / 4 * math.tau + math.pi / 4
        cx, cz = FIRE[0] + math.cos(a) * 9, FIRE[2] + math.sin(a) * 9
        yaw = math.degrees(-a + math.pi / 2)
        solid(cyl("Bark", 0.85, 7, (cx, 0.85, cz), rot=(0, yaw, 90), segments=10))
        for end in (-3.52, 3.52):
            ex = cx + math.cos(math.radians(yaw)) * end
            ez = cz - math.sin(math.radians(yaw)) * end
            cyl("WoodLight", 0.7, 0.06, (ex, 0.85, ez), rot=(0, yaw, 90), segments=10)
    # string lights around the fire
    poles = [(FIRE[0] - 16, FIRE[2] - 16), (FIRE[0] + 16, FIRE[2] - 16), (FIRE[0] + 16, FIRE[2] + 16), (FIRE[0] - 16, FIRE[2] + 16)]
    bulbs = ("BulbPink", "BulbBlue", "BulbGreen", "BulbWarm")
    for i, (px, pz) in enumerate(poles):
        solid(cyl("WoodDark", 0.3, 12.4, (px, 6.2, pz), segments=8))
        cyl("Metal", 0.5, 0.3, (px, 12.3, pz), segments=8)
        nx, nz = poles[(i + 1) % 4]
        prev = (px, 11.5, pz)
        for k in range(1, 13):
            t = k / 12
            sag = math.sin(t * math.pi) * 2.2
            cur = (px + (nx - px) * t, 11.5 - sag + 0.32, pz + (nz - pz) * t)
            beam("Metal", prev, cur, 0.07)
            prev = cur
            if k < 12:
                b = blob(bulbs[k % 4], 0.3, (cur[0], cur[1] - 0.45, cur[2]), noise=0, subdiv=1)
                special(b, "Bulb", light=light(STYLES[bulbs[k % 4]][0], 14, 0.9) if k % 4 == 0 else None)


def pond():
    special(box("Marker", (1, 1, 1), (POND[0], 1, POND[2])), "Pond", hidden=True)
    OBJECTS[-1].hide_render = True
    for i in range(14):
        a = i / 14 * math.tau
        size = 0.9 + (i % 3) * 0.3
        solid(rock("Rock", size, (POND[0] + math.cos(a) * 13.2, 0.25, POND[2] + math.sin(a) * 13.2), scale=(1.2, 0.7, 1.0)))
    for i in range(9):
        a = random.uniform(0, math.tau)
        r = random.uniform(4, 10)
        cyl("Lily", random.uniform(0.6, 1.0), 0.06, (POND[0] + math.cos(a) * r, 0.04, POND[2] + math.sin(a) * r), segments=9)
        if i % 3 == 0:
            blob("FlowerPink", 0.25, (POND[0] + math.cos(a) * r, 0.2, POND[2] + math.sin(a) * r), noise=0.2)
    for a0 in (0.6, 2.5, 4.4):
        for k in range(7):
            a = a0 + random.uniform(-0.25, 0.25)
            r = random.uniform(11.5, 12.8)
            h = random.uniform(2.2, 3.6)
            cyl("Reeds", 0.09, h, (POND[0] + math.cos(a) * r, h / 2 - 0.2, POND[2] + math.sin(a) * r),
                rot=(random.uniform(-8, 8), 0, random.uniform(-8, 8)), segments=4)
    # bench looking at the pond
    solid(box("WoodLight", (6, 0.4, 1.8), (POND[0], 1.8, POND[2] - 16.5), bevel=0.06))
    box("WoodLight", (6, 1.4, 0.3), (POND[0], 3.0, POND[2] - 17.4), rot=(-10, 0, 0))
    for dx in (-2.6, 2.6):
        box("WoodDark", (0.4, 1.6, 1.6), (POND[0] + dx, 0.8, POND[2] - 16.5))


def deciduous(x, z, height=12, crown=4.5, key="Leaves", collide=False):
    trunk = cyl("Bark", 0.9, height, (x, height / 2, z), segments=7, radius2=0.55)
    if collide:
        solid(trunk)
    for bx, by, bz, s in ((0, 0, 0, 1.0), (2.3, 1.6, 1.2, 0.72), (-2.0, 1.0, -1.4, 0.75), (0.4, 3.0, -0.6, 0.6)):
        k = key if (bx + bz) >= 0 else ("LeavesDark" if key == "Leaves" else key)
        blob(k, crown * s, (x + bx, height + 1 + by, z + bz), scale=(1, 0.85, 1), noise=0.15)


def pine(x, z, height=16):
    cyl("Bark", 0.6, height * 0.4, (x, height * 0.2, z), segments=6)
    for i in range(4):
        r = 4.0 - i * 0.85
        blob("Pine", r, (x, height * 0.3 + i * 2.8 + 2, z), scale=(1, 0.8, 1), noise=0.1)


def nature():
    for x, z in ((-56, 30), (-56, 84), (-30, 94), (60, 85), (58, 30), (-60, 5), (55, -10), (24, 94)):
        deciduous(x, z, key="Autumn" if (x, z) == (-56, 84) else "Leaves", collide=True)
    for i in range(26):
        a = i / 26 * math.tau + random.uniform(-0.08, 0.08)
        r = random.uniform(85, 125)
        x, z = math.cos(a) * r, 40 + math.sin(a) * r
        if random.random() < 0.5:
            pine(x, z, height=random.uniform(14, 22))
        else:
            deciduous(x, z, height=random.uniform(10, 15), crown=random.uniform(4, 6),
                      key=random.choice(("Leaves", "Leaves", "Autumn")))
    for x in (-27, -20, -13, 13, 20, 27):
        blob("LeavesDark" if x % 2 else "Leaves", 1.8, (x, 1.2, 22.5), scale=(1.3, 0.9, 1.0), noise=0.2)
    for x, z in ((-50, 56), (36, 72), (-14, 96), (48, 32), (-48, 20), (20, 30)):
        for k in range(3):
            blob("Leaves" if k % 2 else "LeavesDark", random.uniform(1.3, 2.1),
                 (x + random.uniform(-2, 2), 0.9, z + random.uniform(-2, 2)), scale=(1.3, 0.8, 1.2))

    def fence(a, b):
        length = math.dist(a, b)
        n = max(1, int(length // 6))
        for k in range(n + 1):
            t = k / n
            x, z = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            solid(box("WoodDark", (0.5, 3.2, 0.5), (x, 1.6, z), bevel=0.05))
        for y in (1.2, 2.5):
            solid(beam("WoodLight", (a[0], y, a[1]), (b[0], y, b[1]), 0.3))
    fence((-34, 24), (-66, 24))
    fence((-66, 24), (-66, 104))
    fence((-66, 104), (-8, 104))
    fence((8, 104), (66, 104))
    fence((66, 104), (66, 24))
    fence((66, 24), (34, 24))
    for cx, cz in ((-9, 34), (9, 40), (-10, 70), (14, 72), (26, 44), (-20, 84)):
        for _ in range(12):
            key = random.choice(("FlowerPink", "FlowerYellow", "FlowerWhite"))
            blob(key, 0.35, (cx + random.uniform(-2.5, 2.5), 0.35, cz + random.uniform(-2.5, 2.5)), noise=0.2, subdiv=0)
    for i in range(16):
        a = i / 16 * math.tau
        r = random.uniform(175, 205)
        blob("Hills", 1.0, (math.cos(a) * r, -4, 40 + math.sin(a) * r),
             scale=(random.uniform(45, 70), random.uniform(18, 34), random.uniform(35, 50)), noise=0.08, subdiv=2,
             rot=(0, math.degrees(-a), 0))


# ---------------------------------------------------------------- zone upgrades: the chill zone grows with the owner's progress
# Level points come from trophies, installed and played games (src/shared/PS5/Progress.luau). Each level adds its own set.
def upgrades():
    with tier(2):  # Cozy: flowers along the path, window boxes, potted plants, a mailbox by the spawn
        for i in range(24):
            z = 33 + i * 1.6
            for x in (-2.7, 2.7):
                key = ("FlowerPink", "FlowerYellow", "FlowerWhite")[(i + (x > 0)) % 3]
                blob(key, 0.32, (x + random.uniform(-0.25, 0.25), 0.3, z + random.uniform(-0.3, 0.3)), noise=0.2, subdiv=0)
                if i % 2 == 0:
                    blob("LeavesDark", 0.45, (x * 1.12, 0.3, z + 0.8), scale=(1.2, 0.7, 1.2), noise=0.2, subdiv=0)
        for side in (-1, 1):
            box("WoodDark", (13, 0.9, 1.1), (side * 17, 5.1, 21.0), bevel=0.05)
            for k in range(10):
                key = ("FlowerPink", "FlowerWhite", "FlowerYellow", "Leaves")[k % 4]
                blob(key, 0.42, (side * 17 - 6 + k * 1.33, 5.8, 21.0), noise=0.2, subdiv=0)
            solid(cyl("Ceramic", 0.9, 1.6, (side * 5.6, 1.3, 29.4), segments=12, radius2=0.7))
            for k in range(3):
                blob("Leaves" if k % 2 else "LeavesDark", 0.8 - k * 0.15, (side * 5.6, 2.6 + k * 0.7, 29.4), noise=0.2)
        solid(cyl("WoodDark", 0.15, 3.4, (-4, 1.7, 75), segments=6))
        box("Slate", (1.0, 0.9, 1.6), (-4, 3.6, 75), bevel=0.15)
        box("Velvet", (0.08, 0.7, 0.18), (-3.45, 4.1, 75.5))
    with tier(3):  # Garden: fountain, flower arch over the path, blossom trees
        fx, fz = 18, 56
        solid(cyl("Stone", 4.6, 1.2, (fx, 0.6, fz), segments=24))
        cyl("FountainWater", 4.0, 0.1, (fx, 1.22, fz), segments=24)
        solid(cyl("Marble", 0.6, 3.2, (fx, 2.6, fz), segments=12))
        cyl("Marble", 1.7, 0.4, (fx, 4.2, fz), segments=18, radius2=1.2)
        cyl("FountainWater", 1.5, 0.08, (fx, 4.42, fz), segments=18)
        special(blob("FountainWater", 0.35, (fx, 4.8, fz), noise=0, subdiv=1), "FountainSpout",
                light=light((120, 200, 255), 16, 1.2))
        for x in (-3.3, 3.3):
            solid(cyl("WoodLight", 0.25, 7, (x, 3.5, 51), segments=8))
        prev = None
        for k in range(13):
            a = k / 12 * math.pi
            cur = (-3.3 * math.cos(a), 7 + math.sin(a) * 1.6, 51)
            if prev:
                beam("WoodLight", prev, cur, 0.22)
            prev = cur
            blob(("FlowerPink", "Leaves", "FlowerWhite", "LeavesDark")[k % 4], 0.55, (cur[0], cur[1] + 0.2, 51 + random.uniform(-0.3, 0.3)), noise=0.25, subdiv=0)
        for x in (-3.3, 3.3):
            for y in (2, 3.5, 5):
                blob("Leaves", 0.45, (x, y, 51), noise=0.25, subdiv=0)
        for x, z in ((-12, 84), (13, 87)):
            cyl("Bark", 0.6, 9, (x, 4.5, z), segments=7, radius2=0.4)
            for bx, by, bz, r in ((0, 0, 0, 3.6), (1.8, 1.2, 1, 2.6), (-1.7, 0.8, -1, 2.7), (0.3, 2.3, -0.4, 2.2)):
                blob("Blossom", r, (x + bx, 10 + by, z + bz), scale=(1, 0.8, 1), noise=0.15)
    with tier(4):  # Neon Nights: neon outline on the house, ground lights, hot tub, sky beams
        for x in (-30.4, 30.4):
            box("NeonBlue", (0.25, 16, 0.25), (x, 9, 20.4))
        box("NeonPurple", (60.8, 0.25, 0.25), (0, 17.1, 20.4))
        for i in range(10):
            z = 33 + i * 4
            for x in (-2.0, 2.0):
                cyl("NeonWarm", 0.22, 0.1, (x, 0.12, z), segments=8)
        tx, tz = 24, 36
        solid(cyl("WoodDark", 3.6, 2.2, (tx, 1.1, tz), segments=20))
        cyl("Metal", 3.75, 0.25, (tx, 2.3, tz), segments=20)
        special(cyl("FountainWater", 3.1, 0.1, (tx, 2.0, tz), segments=20), "HotTub",
                light=light((90, 220, 255), 14, 1.6, surface="Top", angle=150))
        for x in (-62, 62):
            special(cyl("SkyBeam", 0.9, 90, (x, 45, 100), rot=(-18, 0, -14 if x < 0 else 14), segments=10), "SkyBeam")
            solid(cyl("Metal", 1.6, 1.4, (x, 0.7, 100), segments=12))
    with tier(5):  # Luxury: red carpet with golden posts, golden controller statue
        box("Velvet", (2.6, 0.1, 40), (0, 0.24, 51))
        for z in range(32, 72, 6):
            for x in (-1.9, 1.9):
                cyl("Gold", 0.12, 1.6, (x, 1.0, z), segments=8)
                blob("Gold", 0.2, (x, 1.85, z), noise=0, subdiv=1)
            for x in (-1.9, 1.9):
                if z + 6 < 72:
                    beam("Velvet", (x, 1.6, z), (x, 1.6, z + 6), 0.12)
        sx, sz = -21, 31
        solid(box("Marble", (4.2, 3, 4.2), (sx, 1.5, sz), bevel=0.15))
        box("Gold", (4.6, 0.3, 4.6), (sx, 3.1, sz), bevel=0.1)
        base = (sx, 5.4, sz)
        box("Gold", (4.2, 1.5, 1.9), base, rot=(0, 20, 12), bevel=0.4)
        for gx in (-1.7, 1.7):
            ox = math.cos(math.radians(20)) * gx
            oz = -math.sin(math.radians(20)) * gx
            cyl("Gold", 0.75, 2.2, (sx + ox, 4.6 + gx * 0.2, sz + oz), rot=(0, 20, 12 + (12 if gx < 0 else -12)), segments=12)
        special(blob("Gold", 0.5, (sx, 7.4, sz), noise=0), "Statue", light=light((255, 210, 120), 18, 2, shadows=True))
    with tier(6):  # Legend: floating platinum trophy over the roof, crystals at the gate, aurora, fireworks
        tx, ty, tz = 0, 34, 0
        for name, obj in (
            ("SkyTrophy", cyl("Marble", 2.2, 1.0, (tx, ty, tz), segments=20)),
            ("SkyTrophy", cyl("PlatinumGlow", 0.5, 3.0, (tx, ty + 2, tz), segments=12)),
            ("SkyTrophy", cyl("PlatinumGlow", 3.0, 3.6, (tx, ty + 5.2, tz), segments=20, radius2=1.4)),
            ("SkyTrophy", cyl("PlatinumGlow", 3.3, 0.4, (tx, ty + 7.1, tz), segments=20)),
        ):
            special(obj, name)
        special(blob("PlatinumGlow", 0.6, (tx, ty + 8, tz), noise=0), "SkyTrophyCore", light=light((180, 225, 255), 60, 2.5))
        for x in (-10.5, 10.5):
            for k, (dx, dz, h, lean) in enumerate(((0, 0, 7, 0), (1.1, 0.6, 4.5, 14), (-1.0, -0.5, 5, -12))):
                solid(cyl("Crystal", 0.7, h, (x + dx, h / 2, 104 + dz), rot=(0, 0, lean), segments=6, radius2=0.1))
        for i, key in enumerate(("AuroraGreen", "AuroraPurple", "AuroraGreen")):
            box(key, (260, 18 - i * 4, 0.3), (0, 120 + i * 14, -170 - i * 10), rot=(8, 0, -4 + i * 4))
        for at in ((-40, 2, 90), (40, 2, 90), (0, 2, -40)):
            marker("Fireworks", at)


def build():
    common.reset()
    OBJECTS.clear()
    SPECIALS.clear()
    _materials.clear()
    random.seed(7)
    house()
    play_zone()
    games_zone()
    trophy_zone()
    cozy()
    porch()
    yard()
    pond()
    nature()
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
    common.world((0.05, 0.05, 0.12), 0.6)
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=220)
    ground = common.mesh_object("Ground", bm, common.material("Ground", (0.09, 0.07, 0.05), roughness=0.95))
    ground.location = (0, -40, -0.02)
    common.cylinder("Water", 13, 0.05, R(42, 0.0, 52), common.material("Water", (0.02, 0.08, 0.12), roughness=0.05))
    sun = bpy.data.lights.new("Moon", "SUN")
    sun.energy = 0.6
    sun.color = (0.6, 0.65, 1.0)
    moon = common.link(bpy.data.objects.new("Moon", sun))
    moon.rotation_euler = (math.radians(55), 0, math.radians(35))
    _scene_lights()
    for name, at, energy in (("Fire", R(FIRE[0], 2, FIRE[2]), 3000), ("Room", R(0, 12, 4), 2500)):
        data = bpy.data.lights.new(name, "POINT")
        data.energy = energy
        data.color = (1, 0.6, 0.3) if name == "Fire" else (1, 0.82, 0.65)
        common.link(bpy.data.objects.new(name, data)).location = at
    return scene


def hero():
    _render_setup()
    common.camera(R(30, 30, 112), R(-2, 4, 34), lens=30)
    common.render("chillzone_hero.png")
    # inside, from the entrance: PLAY ahead, MY GAMES left, MY TROPHIES right
    common.camera(R(0, 10, 25), R(0, 6, -10), lens=20)
    return common.render("chillzone_inside.png")


if __name__ == "__main__":
    objs = build()
    tris = sum(common.triangles(o) for o in objs)
    print(f"chillzone: {len(objs)} objects, {sum(1 for o in objs if o.get('collide'))} solid, "
          f"{len(SPECIALS)} special, {tris} triangles")
    hero()
