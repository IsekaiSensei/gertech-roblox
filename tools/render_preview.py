#!/usr/bin/env python3
"""Cheap isometric preview of the provisional hub look (no Roblox Studio needed).

    cd tests && luau dump_decor.luau > /tmp/decor.jsonl   (after bash tests/run.sh built tests/build)
    python3 tools/render_preview.py /tmp/decor.jsonl docs/preview_iso.png

Draws DecorGeometry prims plus rough hub landmarks (hand-copied from HubBuilder). Painter's
algorithm, flat shading: it is a layout check, not a render of Roblox materials.
"""
import json, math, sys
from PIL import Image, ImageDraw, ImageFilter

STYLE = {
    "gold": (212, 175, 55), "goldFoil": (230, 190, 70), "chrome": (205, 210, 220), "silver": (170, 175, 185),
    "teal": (40, 170, 180), "cyanNeon": (80, 230, 255), "goldNeon": (255, 200, 90), "crystal": (190, 225, 255),
    "crystalGold": (255, 215, 120), "forcefield": (120, 220, 255), "star": (255, 255, 255), "starGold": (255, 215, 140),
    "starTeal": (120, 230, 240), "fireNeon": (255, 110, 40), "fireGlass": (255, 120, 60), "frostNeon": (130, 230, 240),
    "frostGlass": (120, 220, 230), "stormNeon": (170, 90, 255), "stormGlass": (150, 90, 230), "solarNeon": (255, 190, 70),
    "solarGlass": (255, 200, 90), "cosmicNeon": (140, 110, 255), "cosmicGlass": (120, 100, 220),
    "nebulaPurple": (110, 60, 200), "nebulaGlass": (90, 70, 200),
}
GLOW = {"cyanNeon", "goldNeon", "fireNeon", "frostNeon", "stormNeon", "solarNeon", "cosmicNeon", "star", "starGold", "starTeal"}
ALPHA = {"crystal": 70, "crystalGold": 80, "forcefield": 50, "fireGlass": 90, "frostGlass": 90, "stormGlass": 90,
         "solarGlass": 90, "cosmicGlass": 90, "nebulaGlass": 110}

W, H, S = 1600, 1080, 5.4
OX, OY = W / 2, 600
C30, S30 = math.cos(math.radians(30)), math.sin(math.radians(30))

def proj(x, y, z):
    return (OX + (x - z) * C30 * S, OY + ((x + z) * S30 - y) * S)

def depth(x, y, z):
    return x + z + y * 0.01

def main(src, dst):
    prims = [json.loads(l) for l in open(src) if l.strip()]
    img = Image.new("RGBA", (W, H), (4, 5, 10, 255))
    d = ImageDraw.Draw(img, "RGBA")
    # star dust background (projected stars are far above: scatter them across the sky band)
    for p in prims:
        if p["g"] == "StarDust":
            x, y, z = p["p"]
            sx = (math.atan2(z, x) + math.pi) / (2 * math.pi) * W
            sy = (1 - (y - 45) / 260) * 300
            r = max(1, p["d"] * 1.4)
            d.ellipse([sx - r, sy - r, sx + r, sy + r], fill=STYLE[p["s"]] + (255,))
    # hub floor + walls (outline only on the near sides so the interior stays visible)
    fl = [proj(-85, 0, -65), proj(85, 0, -65), proj(85, 0, 65), proj(-85, 0, 65)]
    d.polygon(fl, fill=(16, 18, 24, 255), outline=(60, 70, 90, 255))
    for a, b in [((-85, -65), (85, -65)), ((-85, -65), (-85, 65))]:
        p0, p1 = proj(a[0], 0, a[1]), proj(b[0], 0, b[1])
        p2, p3 = proj(b[0], 26, b[1]), proj(a[0], 26, a[1])
        d.polygon([p0, p1, p2, p3], fill=(14, 16, 22, 255), outline=(50, 60, 80, 255))
    items = []
    def box(cx, cy, cz, sx, sy, sz, col, a=255):
        items.append((depth(cx, cy, cz), "box", (cx, cy, cz, sx, sy, sz, col, a)))
    # landmarks (HubBuilder)
    box(55, 0.5, 0, 26, 1, 18, (70, 72, 80))           # forge plinth
    box(62, 11, 0, 2, 20.5, 10.5, (40, 60, 90), 120)   # chamber glass
    box(46, 1.75, 0, 4, 3.5, 6, (60, 200, 255))        # console
    box(50, 2, 28, 6, 4, 4, (255, 210, 120))           # exchange
    for x in (-70, -61, -52):
        box(x, 6, -45, 7, 12, 7, (60, 160, 200), 140)  # coral vats
    box(-55, 3.5, 5, 14, 0.6, 8, (40, 60, 80))          # quantum table
    for i in range(41):
        t = i / 40; a = t * math.pi * 4; y = 2 + t * 20
        for off in (0, math.pi):
            items.append((depth(math.cos(a + off) * 5, y, -50 + math.sin(a + off) * 5), "ball",
                          (math.cos(a + off) * 5, y, -50 + math.sin(a + off) * 5, 1.2, (80, 220, 255), 255, True)))
    for i in range(12):
        a = i / 12 * math.pi * 2
        items.append((depth(math.cos(a) * 6, 4, 5 + math.sin(a) * 6), "ball", (math.cos(a) * 6, 4, 5 + math.sin(a) * 6, 1.6, (90, 110, 130), 255, False)))
    box(0, 0.25, 45, 10, 0.5, 10, (60, 200, 255))      # spawn
    for p in prims:
        if p["g"] == "StarDust":
            continue
        col = STYLE.get(p["s"], (200, 200, 200)); a = ALPHA.get(p["s"], 255); glow = p["s"] in GLOW
        if p["k"] == "rod":
            ax, ay, az = p["a"]; bx, by, bz = p["b"]
            items.append((depth((ax + bx) / 2, (ay + by) / 2, (az + bz) / 2), "rod", (p["a"], p["b"], p["w"], col, a, glow)))
        elif p["k"] == "ball":
            x, y, z = p["p"]
            items.append((depth(x, y, z), "ball", (x, y, z, p["d"], col, a, glow)))
        elif p["k"] in ("block", "wedge"):
            x, y, z = p["p"]; sx, sy, sz = p["size"]
            items.append((depth(x, y, z), "box", (x, y, z, sx, sy, sz, col, a)))
        elif p["k"] == "disc":
            x, y, z = p["p"]
            items.append((depth(x, y, z), "disc", (x, y, z, p["d"], p["h"], col, a)))
    items.sort(key=lambda it: it[0])
    glow_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0)); g = ImageDraw.Draw(glow_layer)
    for _, kind, v in items:
        if kind == "box":
            cx, cy, cz, sx, sy, sz, col, a = v
            hx, hy, hz = sx / 2, sy / 2, sz / 2
            top = [proj(cx - hx, cy + hy, cz - hz), proj(cx + hx, cy + hy, cz - hz), proj(cx + hx, cy + hy, cz + hz), proj(cx - hx, cy + hy, cz + hz)]
            right = [proj(cx + hx, cy + hy, cz - hz), proj(cx + hx, cy + hy, cz + hz), proj(cx + hx, cy - hy, cz + hz), proj(cx + hx, cy - hy, cz - hz)]
            left = [proj(cx - hx, cy + hy, cz + hz), proj(cx + hx, cy + hy, cz + hz), proj(cx + hx, cy - hy, cz + hz), proj(cx - hx, cy - hy, cz + hz)]
            shade = lambda k: tuple(int(c * k) for c in col) + (a,)
            d.polygon(right, fill=shade(0.6)); d.polygon(left, fill=shade(0.8)); d.polygon(top, fill=shade(1.0))
        elif kind == "ball":
            x, y, z, dia, col, a, glow = v
            sx, sy = proj(x, y, z); r = max(1.2, dia / 2 * S)
            d.ellipse([sx - r, sy - r, sx + r, sy + r], fill=col + (a,))
            if a == 255 and r > 2.5:
                d.ellipse([sx - r * 0.5, sy - r * 0.7, sx - r * 0.05, sy - r * 0.25], fill=(255, 255, 255, 90))
            if glow:
                g.ellipse([sx - r * 2.2, sy - r * 2.2, sx + r * 2.2, sy + r * 2.2], fill=col + (110,))
        elif kind == "rod":
            pa, pb, w, col, a, glow = v
            d.line([proj(*pa), proj(*pb)], fill=col + (a,), width=max(1, int(w * S)))
            if glow:
                g.line([proj(*pa), proj(*pb)], fill=col + (160,), width=max(3, int(w * S * 4)))
        elif kind == "disc":
            x, y, z, dia, h, col, a = v
            sx, sy = proj(x, y + h / 2, z); rx = dia / 2 * S * C30 * 1.15; ry = dia / 2 * S * S30 * 1.15
            d.ellipse([sx - rx, sy - ry, sx + rx, sy + ry], fill=col + (a,))
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(5))
    img = Image.alpha_composite(img, glow_layer)
    d = ImageDraw.Draw(img)
    d.text((16, H - 54), "GERTECH hub - provisional look pass toward GERTECH_REF_01..14 (layout preview, not a Roblox render)", fill=(200, 220, 240))
    d.text((16, H - 34), "Rendered offline from src/shared/DecorGeometry.luau + hand-copied hub landmarks.", fill=(140, 160, 180))
    img.convert("RGB").save(dst)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
