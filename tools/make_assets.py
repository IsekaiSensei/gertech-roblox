#!/usr/bin/env python3
"""Regenerate the look-pass image files from Ryan's reference PNGs (needs Pillow + numpy).

    python3 tools/make_assets.py /workspace/gertech_shared_refs/visual_2026-11-14

Writes:
  assets/refs/GERTECH_REF_XX_*.jpg   downscaled copies (max 1024 px, Roblox's upload limit)
  assets/sheets/REF_12_growth_sheet_6x5.jpg, REF_13_helix_sheet_6x5.jpg
                                      30-frame flipbooks, 6 x 5 frames of 168 px (1008 x 840)
  assets/sky/space_{bk,dn,ft,lf,rt,up}.png   generated black-space star-dust skybox faces
"""
import glob, os, sys
import numpy as np
from PIL import Image

F = 168

def refs(src):
    for f in sorted(glob.glob(os.path.join(src, "GERTECH_REF_*.png"))):
        im = Image.open(f).convert("RGB")
        im.thumbnail((1024, 1024), Image.LANCZOS)
        im.save("assets/refs/" + os.path.basename(f)[:-4] + ".jpg", quality=88, optimize=True, progressive=True)

def sheet12(src):
    # REF_12 cells: gold borders + frame-number strips under each image; rows measured by hand
    im = Image.open(os.path.join(src, "GERTECH_REF_12_crystal_to_android_growth_30.png")).convert("RGB")
    rows = [(6, 196), (229, 410), (444, 625), (658, 840), (873, 1103)]
    cw = im.width / 6
    out = Image.new("RGB", (6 * F, 5 * F))
    for r, (t, b) in enumerate(rows):
        s = min(b - t, 212)
        for c in range(6):
            cx = c * cw + cw / 2
            out.paste(im.crop((int(cx - s / 2), int(b - s), int(cx + s / 2), int(b))).resize((F, F), Image.LANCZOS), (c * F, r * F))
    out.save("assets/sheets/REF_12_growth_sheet_6x5.jpg", quality=88, optimize=True)

def sheet13(src):
    im = Image.open(os.path.join(src, "GERTECH_REF_13_helix_platonic_progression_30.png")).convert("RGB")
    cw, ch = im.width / 6, im.height / 5
    out = Image.new("RGB", (6 * F, 5 * F))
    for r in range(5):
        for c in range(6):
            x0, y0 = c * cw, r * ch
            out.paste(im.crop((int(x0 + 12), int(y0 + 8), int(x0 + 217), int(y0 + 213))).resize((F, F), Image.LANCZOS), (c * F, r * F))
    out.save("assets/sheets/REF_13_helix_sheet_6x5.jpg", quality=88, optimize=True)

def sky():
    rng = np.random.default_rng(1114)
    n = 512
    for face in ["bk", "dn", "ft", "lf", "rt", "up"]:
        a = np.zeros((n, n, 3), float)
        noise = rng.random((n // 32, n // 32))
        cloud = np.array(Image.fromarray((noise * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)).astype(float) / 255
        tint = np.array([0.9, 0.75, 0.4]) if face in ("up", "ft") else np.array([0.3, 0.7, 0.8])
        a += (cloud[:, :, None] ** 3) * tint * 18
        for _ in range({"dn": 300}.get(face, 900)):
            x, y = rng.integers(0, n, 2)
            b = rng.random() ** 3
            col = [np.array([1, 1, 1]), np.array([1, 0.85, 0.55]), np.array([0.55, 0.9, 0.95])][rng.integers(0, 3)]
            a[y, x] += col * (80 + 175 * b)
            if b > 0.6:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    a[(y + dy) % n, (x + dx) % n] += col * 60 * b
        Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(f"assets/sky/space_{face}.png", optimize=True)

if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else "/workspace/gertech_shared_refs/visual_2026-11-14"
    for d in ("assets/refs", "assets/sheets", "assets/sky"):
        os.makedirs(d, exist_ok=True)
    refs(src); sheet12(src); sheet13(src); sky()
    print("assets regenerated")
