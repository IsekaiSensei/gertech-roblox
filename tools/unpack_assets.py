#!/usr/bin/env python3
"""Decode the look-pass images from assets/encoded/*.b64 back into binary files.

The GitHub copy of this repo stores images as base64 text (the push tooling only carries
text), so after cloning run:

    python3 tools/unpack_assets.py          # writes assets/refs, assets/sheets, assets/sky, docs/preview_iso.png
    python3 tools/unpack_assets.py --encode # maintainers: re-encode after tools/make_assets.py

Each file is checked against assets/encoded/MANIFEST.txt (sha256, bytes).
"""
import base64, hashlib, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENC = os.path.join(ROOT, "assets", "encoded")
SOURCES = ["assets/refs", "assets/sheets", "assets/sky", "docs/preview_iso.png"]

def files():
    for s in SOURCES:
        p = os.path.join(ROOT, s)
        if os.path.isdir(p):
            for f in sorted(os.listdir(p)):
                if f.lower().endswith((".png", ".jpg")):
                    yield os.path.join(s, f)
        elif os.path.isfile(p):
            yield s

def encode():
    lines = []
    for rel in files():
        data = open(os.path.join(ROOT, rel), "rb").read()
        out = os.path.join(ENC, rel + ".b64")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        open(out, "wb").write(base64.encodebytes(data))
        lines.append(f"{hashlib.sha256(data).hexdigest()}  {len(data)}  {rel}")
    open(os.path.join(ENC, "MANIFEST.txt"), "w").write("\n".join(lines) + "\n")
    print(f"encoded {len(lines)} files")

def decode():
    ok = 0
    for line in open(os.path.join(ENC, "MANIFEST.txt")):
        if not line.strip():
            continue
        sha, size, rel = line.split(None, 2)
        rel = rel.strip()
        data = base64.decodebytes(open(os.path.join(ENC, rel + ".b64"), "rb").read())
        if hashlib.sha256(data).hexdigest() != sha or len(data) != int(size):
            sys.exit(f"checksum mismatch: {rel}")
        dst = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        open(dst, "wb").write(data)
        ok += 1
    print(f"decoded {ok} files")

if __name__ == "__main__":
    encode() if "--encode" in sys.argv else decode()
