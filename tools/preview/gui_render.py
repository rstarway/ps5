# Рисует снятое из мок-движка дерево интерфейса BlockCraft (gui.txt) в PNG 1920x1080.
# Это превью раскладки кода, не снимок Roblox: шрифт — растровый PIL, 3D-вид упрощён.
import sys, json, re, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SRC, OUTDIR, BG = sys.argv[1], sys.argv[2], sys.argv[3]
W, H = 1920, 1080
snaps, imgs = {}, {}
for line in open(SRC):
    if line.startswith("SNAP\t"):
        _, name, data = line.rstrip("\n").split("\t", 2)
        snaps[name] = json.loads(data)
    elif line.startswith("IMG\t"):
        _, i, w, h, hx = line.split()
        w, h = int(w), int(h)
        a = np.frombuffer(bytes.fromhex(hx), np.uint8).reshape(h, w, 4)
        imgs[int(i)] = Image.fromarray(a.copy(), "RGBA")

FONT = ImageFont.load_default_imagefont()

def col(c, a=1.0):
    if c is None:
        c = [1, 1, 1]
    return (int(c[0] * 255 + .5), int(c[1] * 255 + .5), int(c[2] * 255 + .5), int(max(0, min(1, a)) * 255 + .5))

class Ctx:
    def __init__(self, img):
        self.img = img

def paste(canvas, im, x, y, clip):
    x, y = int(round(x)), int(round(y))
    cx0, cy0, cx1, cy1 = clip
    x0, y0 = max(x, cx0), max(y, cy0)
    x1, y1 = min(x + im.width, cx1), min(y + im.height, cy1)
    if x1 <= x0 or y1 <= y0:
        return
    part = im.crop((x0 - x, y0 - y, x1 - x, y1 - y))
    canvas.alpha_composite(part, (x0, y0))

def fill(canvas, rect, rgba, clip):
    x, y, w, h = rect
    if w < 1 or h < 1 or rgba[3] == 0:
        return
    paste(canvas, Image.new("RGBA", (int(round(w)), int(round(h))), rgba), x, y, clip)

def gradient_img(w, h, base, base_a, grad):
    w, h = max(1, int(round(w))), max(1, int(round(h)))
    vertical = abs((grad.get("rot") or 0) - 90) < 1
    n = h if vertical else w
    t = np.linspace(0, 1, n)
    kp = grad.get("kp") or [[0, [1, 1, 1]], [1, [1, 1, 1]]]
    ks = [k[0] for k in kp]
    cs = np.array([k[1] for k in kp])
    cc = np.stack([np.interp(t, ks, cs[:, i]) for i in range(3)], -1)
    tr = grad.get("tr") or [[0, 0], [1, 0]]
    ta = np.interp(t, [k[0] for k in tr], [k[1] for k in tr])
    rgb = cc * np.array(base[:3]) / 255.0
    alpha = (1 - ta) * base_a
    line = np.concatenate([rgb * 255, alpha[:, None] * 255], -1).clip(0, 255).astype(np.uint8)
    arr = np.repeat(line[:, None, :], w, 1) if vertical else np.repeat(line[None, :, :], h, 0)
    return Image.fromarray(arr, "RGBA")

def parse_rich(text, base):
    segs = []
    pos = 0
    stack = [base]
    for m in re.finditer(r'<font color="#([0-9A-Fa-f]{6})">|</font>|<[^>]+>', text):
        if m.start() > pos:
            segs.append((text[pos:m.start()], stack[-1]))
        if m.group(1):
            h = m.group(1)
            stack.append((int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), base[3]))
        elif m.group(0) == "</font>" and len(stack) > 1:
            stack.pop()
        pos = m.end()
    segs.append((text[pos:], stack[-1]))
    return segs

def text_img(text, rgba, k, rich):
    # строки текста растровым шрифтом, увеличенные без сглаживания
    lines = text.split("\n")
    segs_lines = [parse_rich(l, rgba) if rich else [(l, rgba)] for l in lines]
    widths = []
    for segs in segs_lines:
        widths.append(sum(FONT.getbbox(s)[2] if s else 0 for s, _ in segs))
    lw, lh = max(widths + [1]), 10
    im = Image.new("RGBA", (lw + 2, lh * len(lines) + 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for li, segs in enumerate(segs_lines):
        x = 0
        for s, c in segs:
            if s:
                d.text((x, li * lh), s, font=FONT, fill=c)
                x += FONT.getbbox(s)[2]
    if k != 1:
        im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.NEAREST)
    return im, widths, lh

def draw_text(canvas, n, rect, clip, grad):
    text = n.get("text") or ""
    if not text or not n.get("vis", True):
        return
    tt = n.get("tt") or 0
    if tt >= 1:
        return
    rgba = col(n.get("tc"), 1 - tt)
    ts = n.get("ts") or 14
    x, y, w, h = rect
    if n.get("tscaled"):
        ts = h * 0.9
    k = max(1, round(ts / 8 * 0.95)) if ts >= 12 else ts / 8
    rich = n.get("rich")
    im, widths, lh = text_img(text, rgba, k, rich)
    plain = re.sub(r"<[^>]+>", "", text) if rich else text
    if grad and grad.get("kp"):
        g = gradient_img(im.width, im.height, (255, 255, 255), 1, grad)
        arr = np.array(im).astype(float); garr = np.array(g).astype(float)
        arr[..., :3] *= garr[..., :3] / 255
        im = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")
    st = n.get("stroket")
    if st is not None and st < 1:
        sc = col(n.get("strokec") or [0, 0, 0], 1 - st)
        mask = im.split()[3]
        grow = mask.filter(ImageFilter.MaxFilter(3 if k < 3 else 5))
        base = Image.new("RGBA", im.size, sc)
        base.putalpha(grow.point(lambda v: int(v * sc[3] / 255)))
        base.alpha_composite(im)
        im = base
    tw = max(widths) * k
    th = lh * k * len(text.split("\n"))
    xa, ya = n.get("xa") or "Left", n.get("ya") or "Center"
    px = x if xa == "Left" else (x + w - tw if xa == "Right" else x + (w - tw) / 2)
    py = y if ya == "Top" else (y + h - th if ya == "Bottom" else y + (h - th) / 2 + k)
    paste(canvas, im, px, py, clip)

def draw_image(canvas, n, rect, clip):
    im = imgs.get(n.get("img"))
    if im is None:
        return
    x, y, w, h = rect
    if w < 1 or h < 1:
        return
    if n.get("rsize") and n["rsize"][0] > 0:
        ox, oy = n.get("rofs") or [0, 0]
        sw, sh = n["rsize"]
        im = im.crop((int(ox), int(oy), int(ox + sw), int(oy + sh)))
    ic = n.get("ic")
    if ic and ic != [1, 1, 1]:
        arr = np.array(im).astype(float)
        arr[..., :3] *= np.array(ic)
        im = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")
    it = n.get("it") or 0
    if n.get("scale") == "Tile" and n.get("tile"):
        tw, th = int(n["tile"][1]), int(n["tile"][3])
        tile = im.resize((tw, th), Image.NEAREST)
        big = Image.new("RGBA", (int(w), int(h)))
        for ty in range(0, int(h), th):
            for tx in range(0, int(w), tw):
                big.paste(tile, (tx, ty))
        im = big
    else:
        im = im.resize((max(1, int(round(w))), max(1, int(round(h)))), Image.NEAREST)
    if it > 0:
        a = im.split()[3].point(lambda v: int(v * (1 - it)))
        im.putalpha(a)
    paste(canvas, im, x, y, clip)

def cube_img(size, faces):
    size = max(4, int(size))
    def face(name, k):
        f = faces.get(name)
        if not f or f[0] not in imgs:
            return None
        a = np.array(imgs[f[0]].convert("RGBA").resize((64, 64), Image.NEAREST)).astype(float)
        a[..., :3] *= f[1]
        return a.clip(0, 255).astype(np.uint8)
    out = np.zeros((size, size, 4), np.uint8)
    s = size / 2 * 0.95
    cx, cy = size / 2, size / 2
    ys, xs = np.mgrid[0:size, 0:size].astype(float)
    def warp(src, p0, p1, p3):
        if src is None:
            return
        p0 = np.array(p0); e1 = np.array(p1) - p0; e2 = np.array(p3) - p0
        Mi = np.linalg.inv(np.array([e1, e2]).T)
        rel = np.stack([xs - p0[0], ys - p0[1]], -1) @ Mi.T
        ok = (rel[..., 0] >= 0) & (rel[..., 0] < 1) & (rel[..., 1] >= 0) & (rel[..., 1] < 1)
        u = (rel[..., 0] * 64).astype(int).clip(0, 63); v = (rel[..., 1] * 64).astype(int).clip(0, 63)
        px = src[v[ok], u[ok]]
        sel = px[:, 3] > 0
        idx = np.argwhere(ok)[sel]
        out[idx[:, 0], idx[:, 1]] = px[sel]
    r = s * 0.87
    warp(face("Top", 1), (cx - r, cy - s / 2), (cx, cy - s), (cx, cy))
    warp(face("Right", 1), (cx - r, cy - s / 2), (cx, cy), (cx - r, cy + s / 2))
    warp(face("Front", 1), (cx, cy), (cx + r, cy - s / 2), (cx, cy + s))
    return Image.fromarray(out, "RGBA")

def draw_viewport(canvas, n, rect, clip):
    parts = n.get("parts") or []
    x, y, w, h = rect
    if len(parts) == 1 and parts[0].get("faces"):
        paste(canvas, cube_img(min(w, h), parts[0]["faces"]), x + (w - min(w, h)) / 2, y + (h - min(w, h)) / 2, clip)
        return
    if not parts:
        return
    # фигурка: прямая проекция спереди, дальние детали раньше
    top = max(p["pos"][1] + p["size"][1] / 2 for p in parts)
    bot = min(p["pos"][1] - p["size"][1] / 2 for p in parts)
    k = h * 0.86 / (top - bot)
    cx, by = x + w / 2, y + h * 0.93
    for p in sorted(parts, key=lambda p: -p["pos"][2]):
        sx, sy = p["size"][0] * k, p["size"][1] * k
        px = cx - p["pos"][0] * k - sx / 2
        py = by - (p["pos"][1] - bot) * k - sy / 2
        c = col(p["color"])
        shade = 0.9 if p["pos"][2] > -1 else 1
        fill(canvas, (px, py, sx, sy), (int(c[0] * shade), int(c[1] * shade), int(c[2] * shade), 255), clip)

def stroke(canvas, rect, s, clip):
    tr = s.get("tr") or 0
    if tr >= 1:
        return
    c = col(s.get("color"), 1 - tr)
    t = max(1, int(round(s.get("th") or 1)))
    x, y, w, h = rect
    for r in [(x - t, y - t, w + 2 * t, t), (x - t, y + h, w + 2 * t, t), (x - t, y, t, h), (x + w, y, t, h)]:
        fill(canvas, r, c, clip)

def rect_of(n, parent):
    px, py, pw, ph = parent
    s = n.get("size") or [0, 0, 0, 0]
    p = n.get("pos") or [0, 0, 0, 0]
    a = n.get("anchor") or [0, 0]
    w = s[0] * pw + s[1]
    h = s[2] * ph + s[3]
    x = px + p[0] * pw + p[1] - a[0] * w
    y = py + p[2] * ph + p[3] - a[1] * h
    return [x, y, w, h]

def draw(canvas, n, rect, clip):
    if not n.get("vis", True):
        return
    if n.get("rot") and abs(n["rot"]) > 0.5:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        draw_inner(layer, n, rect, (0, 0, W, H))
        cx, cy = rect[0] + rect[2] / 2, rect[1] + rect[3] / 2
        # Roblox: положительный угол — по часовой стрелке, PIL — против
        layer = layer.rotate(-n["rot"], center=(cx, cy), resample=Image.NEAREST)
        paste(canvas, layer, 0, 0, clip)
        return
    draw_inner(canvas, n, rect, clip)

def draw_inner(canvas, n, rect, clip):
    kids = n.get("kids") or []
    grad = next((k for k in kids if k["c"] == "UIGradient"), None)
    strokes = [k for k in kids if k["c"] == "UIStroke"]
    x, y, w, h = rect
    cls = n["c"]
    bgt = n.get("bgt")
    if bgt is None:
        bgt = 0 if cls in ("Frame", "TextButton", "ScrollingFrame") else 1
    if bgt < 1 and cls != "TextLabel" or (cls == "TextLabel" and bgt < 1):
        base = col(n.get("bg"), 1 - bgt)
        if grad and cls not in ("TextLabel",):
            paste(canvas, gradient_img(w, h, base, 1 - bgt, grad), x, y, clip)
        else:
            fill(canvas, rect, base, clip)
    for s in strokes:
        if (s.get("mode") or "Border") == "Border" or cls not in ("TextLabel", "TextButton", "TextBox"):
            stroke(canvas, rect, s, clip)
    if cls in ("ImageLabel", "ImageButton"):
        draw_image(canvas, n, rect, clip)
    if cls == "ViewportFrame":
        draw_viewport(canvas, n, rect, clip)
        return
    if cls in ("TextLabel", "TextButton", "TextBox"):
        draw_text(canvas, n, rect, clip, grad if cls == "TextLabel" else None)
    # дети
    inner_clip = clip
    if n.get("clip"):
        inner_clip = (max(clip[0], int(x)), max(clip[1], int(y)), min(clip[2], int(x + w)), min(clip[3], int(y + h)))
    pad = next((k for k in kids if k["c"] == "UIPadding"), None)
    cx, cy = x, y
    if pad:
        cx += pad.get("pl") or 0
        cy += pad.get("pt") or 0
    lst = next((k for k in kids if k["c"] == "UIListLayout"), None)
    grid = next((k for k in kids if k["c"] == "UIGridLayout"), None)
    guis = [(i, k) for i, k in enumerate(kids) if "size" in k]
    if lst or grid:
        guis.sort(key=lambda t: (t[1].get("lo") or 0, t[0]))
        ox, oy = cx, cy
        col_i = 0
        for _, k in guis:
            if not k.get("vis", True):
                continue
            if grid:
                cw, ch = grid["cell"][1], grid["cell"][3]
                padx, pady = (grid.get("cpad") or [0, 0, 0, 0])[1], (grid.get("cpad") or [0, 0, 0, 0])[3]
                per = max(1, int((w + padx) // (cw + padx)))
                r = [cx + (col_i % per) * (cw + padx), cy + (col_i // per) * (ch + pady), cw, ch]
                col_i += 1
            else:
                r = rect_of(k, (cx, cy, w, h))
                r[0], r[1] = ox, oy
                if lst.get("dir") == "Horizontal":
                    ox += r[2] + (lst.get("pad") or 0)
                else:
                    oy += r[3] + (lst.get("pad") or 0)
            draw(canvas, k, r, inner_clip)
        return
    guis.sort(key=lambda t: (t[1].get("z") or 1, t[0]))
    for _, k in guis:
        draw(canvas, k, rect_of(k, (x, y, w, h)), inner_clip)

bg = Image.open(BG).convert("RGBA").resize((W, H))
for name, snap in snaps.items():
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    if name == "title":
        canvas.alpha_composite(bg.filter(ImageFilter.GaussianBlur(3)))
    elif name not in ("create", "worlds"):
        canvas.alpha_composite(bg)
    root = snap["root"]
    draw(canvas, root, rect_of(root, (0, 0, W, H)) if False else [0, 0, W, H], (0, 0, W, H))
    canvas.convert("RGB").save(f"{OUTDIR}/{name}.png")
    print("saved", name)
