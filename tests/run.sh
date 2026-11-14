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
for m in Config RecipeDefs ProgressionDefs ItemDefs; do
  { echo 'local Color3 = require("./_shim")'; sed -E 's#require\(script\.Parent\.([A-Za-z]+)\)#require("./\1")#' "../src/shared/$m.luau"; } > "build/$m.luau"
done
luau pure.spec.luau
