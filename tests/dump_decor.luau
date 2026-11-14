-- Dumps DecorGeometry prims as JSON lines for tools/render_preview.py
local DG = require("./build/DecorGeometry")
local d = DG.build()
local function vec(t) if not t then return "null" end return string.format("[%.3f,%.3f,%.3f]", t.x, t.y, t.z) end
for _, p in d.prims do
	print(string.format('{"k":"%s","g":"%s","s":"%s","p":%s,"a":%s,"b":%s,"d":%s,"h":%s,"w":%s,"size":%s}',
		p.kind, p.group, p.style, vec(p.p), vec(p.a), vec(p.b), tostring(p.d or "null"), tostring(p.h or "null"), tostring(p.w or "null"), vec(p.size)))
end
