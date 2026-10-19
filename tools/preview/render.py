import sys, numpy as np
from PIL import Image, ImageDraw, ImageFont
S_DIR = sys.argv[1]; OUT = sys.argv[2]
tex = {}; hud = {}; items = {}; blocks = {}
H = SX = SZ = 0; spawn = None
def img16(h):
    a = np.frombuffer(bytes.fromhex(h), dtype=np.uint8).reshape(16, 16, 4)
    return a
for line in open(S_DIR + "/dump.txt"):
    p = line.rstrip("\n").split("\t")
    if p[0] == "TEX": tex[(p[1], p[2])] = img16(p[3])
    elif p[0] == "HUD": hud[(p[1], p[2])] = img16(p[3])
    elif p[0] == "ITEM": items[p[1]] = img16(p[3])
    elif p[0] == "WORLD": H, SX, SZ = int(p[1]), int(p[2]), int(p[3]); spawn = (float(p[4]), float(p[5]), float(p[6]))
    elif p[0] == "B": blocks[int(p[1])] = p[2]
ids = sorted(set(blocks.values())); idx = {n: i + 1 for i, n in enumerate(ids)}
grid = np.zeros((SX, H, SZ), dtype=np.int16)
for k, n in blocks.items():
    x = k % SX; z = (k // SX) % SZ; y = k // (SX * SZ)
    grid[x, y, z] = idx[n]
SEE = {"water", "lava", "glass", "ice", "oak_leaves", "birch_leaves", "torch", "nether_portal_x", "nether_portal_z"}
LIQ = {"water", "lava"}
LIGHT = {"lava": 0.8, "glowstone": 1, "torch": 1, "shroomlight": 1, "magma_block": 0.3}
see = np.zeros(len(ids) + 1, bool); liq = np.zeros(len(ids) + 1, bool)
for n in ids:
    see[idx[n]] = n in SEE; liq[idx[n]] = n in LIQ
heights = np.full((SX, SZ), -1)
for x in range(SX):
    for z in range(SZ):
        col = grid[x, :, z]
        ys = [y for y in range(H) if col[y] and not see[col[y]]]
        heights[x, z] = max(ys) if ys else -1
lights = [((k % SX), k // (SX * SZ), (k // SX) % SZ, LIGHT[n]) for k, n in blocks.items() if n in LIGHT]
W, Hh = 1920, 1080
# camera
eye = np.array([spawn[0] - 6, spawn[1] + 3.2, spawn[2] - 10])
yaw, pitch = np.radians(35), np.radians(-14)
fwd = np.array([np.sin(yaw) * np.cos(pitch), np.sin(pitch), np.cos(yaw) * np.cos(pitch)])
right = np.cross(fwd, [0, 1, 0]); right /= np.linalg.norm(right); up = np.cross(right, fwd)
fov = np.radians(70); th = np.tan(fov / 2); aspect = W / Hh
u = (np.arange(W) + 0.5) / W * 2 - 1; v = 1 - (np.arange(Hh) + 0.5) / Hh * 2
U, V = np.meshgrid(u * th * aspect, v * th)
D = fwd[None, None, :] + U[..., None] * (-right)[None, None, :] + V[..., None] * up[None, None, :]
D /= np.linalg.norm(D, axis=2, keepdims=True)
D = D.reshape(-1, 3); N = D.shape[0]
pos = np.floor(eye).astype(int)[None, :].repeat(N, 0)
step = np.where(D > 0, 1, -1)
with np.errstate(divide="ignore"):
    tdelta = np.where(D != 0, np.abs(1 / D), 1e30)
    tmax = np.where(D > 0, (pos + 1 - eye) / D, np.where(D < 0, (pos - eye) / D, 1e30))
hit = np.zeros(N, int); face = np.full(N, -1); tval = np.zeros(N); alive = np.ones(N, bool)
water_t = np.full(N, np.inf)
for it in range(160):
    a = np.where(alive)[0]
    if len(a) == 0: break
    tm = tmax[a]; ax = np.argmin(tm, axis=1)
    rows = np.arange(len(a))
    t = tm[rows, ax]
    pos[a, ax] += step[a, ax]; tmax[a, ax] += tdelta[a, ax]
    x, y, z = pos[a, 0], pos[a, 1], pos[a, 2]
    out = (x < 0) | (x >= SX) | (z < 0) | (z >= SZ) | (y < 0) | (y >= H) | (t > 90)
    inside = ~out
    cell = np.zeros(len(a), int)
    cell[inside] = grid[x[inside], y[inside], z[inside]]
    isw = inside & (cell > 0) & liq[cell]
    wi = a[isw]; water_t[wi] = np.minimum(water_t[wi], t[isw])
    solid = inside & (cell > 0) & ~liq[cell]
    h = a[solid]
    hit[h] = cell[solid]; face[h] = ax[solid] * 2 + (step[h, ax[solid]] < 0); tval[h] = t[solid]
    alive[a[out | solid]] = False
# colour
names = {i + 1: n for i, n in enumerate(ids)}
img = np.zeros((N, 3))
sky_top, sky_bot = np.array([120, 167, 255]), np.array([192, 216, 255])
sv = np.clip(D[:, 1] * 2 + 0.3, 0, 1)[:, None]
img[:] = sky_bot * (1 - sv) + sky_top * sv
hitp = eye + D * tval[:, None]
for c in np.unique(hit[hit > 0]):
    n = names[c]
    sel = np.where(hit == c)[0]
    for fi in range(6):
        s2 = sel[face[sel] == fi]
        if len(s2) == 0: continue
        axis = fi // 2; neg = fi % 2 == 1  # step<0 means ray going negative => we hit +side face
        normal = np.zeros(3); normal[axis] = 1 if neg else -1
        fname = "top" if (axis == 1 and normal[1] > 0) else "bottom" if axis == 1 else ("side" if axis == 0 or normal[2] > 0 else "front")
        t16 = tex.get((n, fname)) if (n, fname) in tex else tex.get((n, "side"))
        shade = 1.0 if fname == "top" else 0.5 if fname == "bottom" else (0.6 if axis == 0 else 0.8)
        p = hitp[s2]
        # texture coords
        if axis == 0: uu, vv = p[:, 2], p[:, 1]
        elif axis == 1: uu, vv = p[:, 0], p[:, 2]
        else: uu, vv = p[:, 0], p[:, 1]
        ui = np.clip(((uu % 1) * 16).astype(int), 0, 15); vi = np.clip(((1 - (vv % 1)) * 16).astype(int), 0, 15) if axis != 1 else np.clip(((vv % 1) * 16).astype(int), 0, 15)
        col = t16[vi, ui, :3].astype(float) if t16 is not None else np.full((len(s2), 3), 128.0)
        # light at neighbour cell
        cellp = np.floor(p - normal * 0.5 + normal * 0.0).astype(int)
        nb = np.floor(p + normal * 0.5).astype(int)
        nx, ny, nz = np.clip(nb[:, 0], 0, SX - 1), nb[:, 1], np.clip(nb[:, 2], 0, SZ - 1)
        hh = heights[nx, nz]
        L = np.where(ny > hh, 1.0, np.maximum(0.2, 1 - (hh - ny) * 0.16))
        if n in LIGHT: L[:] = 1
        for lx, ly, lz, st in lights:
            d = np.abs(lx - nb[:, 0]) + np.abs(ly - nb[:, 1]) + np.abs(lz - nb[:, 2])
            L = np.maximum(L, st * (1 - d / 13))
        img[s2] = col * (shade * np.minimum(L, 1))[:, None]
# water tint
wmask = np.isfinite(water_t) & ((hit == 0) | (water_t < tval))
img[wmask] = img[wmask] * 0.45 + np.array([48, 96, 214]) * 0.55
# fog
dist = np.where(hit > 0, tval, 90)
fog = np.clip((dist - 40) / 50, 0, 1)[:, None]
img = img * (1 - fog) + (sky_bot) * fog
im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8).reshape(Hh, W, 3)).convert("RGBA")
import os
if os.environ.get("WORLD_ONLY"):
    im.convert("RGB").save(OUT); sys.exit(0)
# ---------------- HUD at scale 3 (canvas 1920x1080 = image)
S = 3
def paste_px(arr, x, y, scale, crop=None):
    a = arr if crop is None else arr[crop[1]:crop[1] + crop[3], crop[0]:crop[0] + crop[2]]
    t = Image.fromarray(a, "RGBA").resize((a.shape[1] * scale, a.shape[0] * scale), Image.NEAREST)
    im.alpha_composite(t, (int(x), int(y)))
ov = Image.new("RGBA", im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
HW = 182 * S; top = 1080 - 22 * S - 2; left = 960 - HW // 2
d.rectangle([left, top, left + HW, top + 22 * S], fill=(0, 0, 0, 115), outline=(20, 20, 20, 200), width=S)
for i in range(9):
    x0 = left + S + i * 20 * S
    d.rectangle([x0, top + S, x0 + 20 * S, top + 21 * S], fill=(60, 60, 60, 140), outline=(140, 140, 140, 165), width=2)
sel = 1
sx = left + S + sel * 20 * S - 2 * S
d.rectangle([sx, top - S, sx + 24 * S, top + 23 * S], outline=(235, 235, 235, 255), width=S)
xpTop = top - 8 * S
d.rectangle([left, xpTop, left + HW, xpTop + 5 * S], fill=(16, 16, 16, 205))
d.rectangle([left, xpTop, left + int(HW * 0.45), xpTop + 5 * S], fill=(128, 255, 32, 255))
# crosshair
d.rectangle([960 - 5 * S, 540 - 1, 960 + 5 * S, 540 + 1], fill=(230, 230, 230, 220))
d.rectangle([960 - 1, 540 - 5 * S, 960 + 1, 540 + 5 * S], fill=(230, 230, 230, 220))
im.alpha_composite(ov)
barsTop = xpTop - S - 9 * S
for i in range(10):
    st = "full" if i < 9 else "half"
    paste_px(hud[("heart", st)], left + i * 8 * S, barsTop, S, (3, 3, 9, 9))
    paste_px(hud[("food", "full" if i < 8 else "empty")], left + HW - 9 * S - i * 8 * S, barsTop, S, (3, 3, 9, 9))
# hotbar items: block cubes (iso) and item sprites
def cube_icon(n, size):
    c = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    top_t = tex.get((n, "top")); side_t = tex.get((n, "side")); front_t = tex.get((n, "front"), side_t)
    def face_img(t, k):
        a = t.astype(float); a[..., :3] *= k
        return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA").resize((64, 64), Image.NEAREST)
    s = size / 2 * 0.95; cx, cy = size / 2, size / 2
    pts_top = [(cx, cy - s), (cx + s * 0.87, cy - s / 2), (cx, cy), (cx - s * 0.87, cy - s / 2)]
    def warp(src, quad):
        # map unit square corners (0,0),(1,0),(1,1),(0,1) -> quad via QUAD transform (inverse)
        w = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        q = quad
        data = (q[0][0], q[0][1], q[3][0], q[3][1], q[2][0], q[2][1], q[1][0], q[1][1])
        # PIL QUAD maps output->input; we need input->output: do it by sampling output
        out = np.zeros((size, size, 4), np.uint8); srcA = np.array(src)
        ys, xs = np.mgrid[0:size, 0:size]
        p0 = np.array(q[0]); e1 = np.array(q[1]) - p0; e2 = np.array(q[3]) - p0
        M = np.linalg.inv(np.array([e1, e2]).T)
        rel = np.stack([xs - p0[0], ys - p0[1]], -1) @ M.T
        ok = (rel[..., 0] >= 0) & (rel[..., 0] < 1) & (rel[..., 1] >= 0) & (rel[..., 1] < 1)
        ui = (rel[..., 0] * 64).astype(int).clip(0, 63); vi = (rel[..., 1] * 64).astype(int).clip(0, 63)
        out[ok] = srcA[vi[ok], ui[ok]]
        return Image.fromarray(out, "RGBA")
    c.alpha_composite(warp(face_img(top_t, 1), [pts_top[3], pts_top[0], pts_top[1], pts_top[2]]))
    c.alpha_composite(warp(face_img(side_t, 0.8), [(cx - s * 0.87, cy - s / 2), (cx, cy), (cx, cy + s), (cx - s * 0.87, cy + s / 2)]))
    c.alpha_composite(warp(face_img(front_t, 0.6), [(cx, cy), (cx + s * 0.87, cy - s / 2), (cx + s * 0.87, cy + s / 2), (cx, cy + s)]))
    return c
hot = ["diamond_pickaxe", "grass_block", "cobblestone", "oak_log", "oak_planks", "crafting_table", "iron_sword", "cooked_porkchop", "torch"]
counts = {"grass_block": 64, "cobblestone": 37, "oak_log": 12, "oak_planks": 23, "cooked_porkchop": 9}
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 22)
except Exception:
    font = ImageFont.load_default()
d2 = ImageDraw.Draw(im)
for i, n in enumerate(hot):
    x0 = left + S + i * 20 * S + 6; y0 = top + S + 6
    if n in items:
        paste_px(items[n], x0 + 0, y0, 3)
    elif (n, "top") in tex:
        im.alpha_composite(cube_icon(n, 48), (x0, y0))
    if n in counts:
        t = str(counts[n]); tw = d2.textlength(t, font=font)
        d2.text((x0 + 50 - tw + 3, y0 + 30 + 3), t, font=font, fill=(63, 63, 63))
        d2.text((x0 + 50 - tw, y0 + 30), t, font=font, fill=(255, 255, 255))
# held item (diamond pickaxe), big, bottom right
held = Image.fromarray(items["diamond_pickaxe"], "RGBA").resize((380, 380), Image.NEAREST).rotate(-18, expand=True, resample=Image.NEAREST)
im.alpha_composite(held, (1500, 720))
im = im.crop((0, 0, 1920, 1080)).convert("RGB")
im.save(OUT, quality=92)
print("saved", OUT)
