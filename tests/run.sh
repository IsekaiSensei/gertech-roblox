#!/usr/bin/env bash
# Builds engine-free copies of shared modules and runs tests/pure.spec.luau with the luau CLI.
set -euo pipefail
cd "$(dirname "$0")"
rm -rf build && mkdir -p build
cat > build/_shim.luau <<'S'
-- Minimal Roblox shims for offline tests
local Color3 = {}
function Color3.fromRGB(r, g, b) return { r = r, g = g, b = b } end
function Color3.fromHex(h) return { hex = h } end
function Color3.new(r, g, b) return { r = r, g = g, b = b } end
return Color3
S
for m in Config DecorGeometry ImageAssets ForgeRules ForgeFeed TetrominoGrid ForgeSession RecipeDefs ProgressionDefs ItemDefs; do
  { echo 'local Color3 = require("./_shim")'; sed -E 's#require\(script\.Parent\.([A-Za-z]+)\)#require("./\1")#' "../src/shared/$m.luau"; } > "build/$m.luau"
done
luau pure.spec.luau
# decode base64 images after a fresh clone (GitHub stores them as text)
if [ ! -d ../assets/refs ] && [ -f ../assets/encoded/MANIFEST.txt ]; then python3 ../tools/unpack_assets.py; fi
# every image slot must point at a file that exists in the repo
missing=0
for f in $(grep -oE 'assets/[A-Za-z0-9_/-]+\.(jpg|png)' ../src/shared/ImageAssets.luau | sort -u); do
  if [ ! -f "../$f" ]; then echo "FAIL: missing asset file $f"; missing=1; fi
done
[ "$missing" = 0 ] && echo "asset files: all $(grep -oE 'assets/[A-Za-z0-9_/-]+\.(jpg|png)' ../src/shared/ImageAssets.luau | sort -u | wc -l) present"
exit $missing
