--!strict
-- Sound direction (Ryan, 2026-11-14): workshop + electronics ambience / background noise,
-- with healing and ASMR frequencies layered in.
-- No audio assets are shipped. Paste rbxassetid:// ids from the Creator Store here;
-- empty ids are skipped silently.

export type SoundDef = { soundId: string, volume: number }

local AudioDefs = {}

AudioDefs.Ambience = {
	{ key = "workshop_bed", soundId = "", volume = 0.35 }, -- machine-shop room tone
	{ key = "electronics_hum", soundId = "", volume = 0.2 }, -- transformer / server hum
	{ key = "healing_tone", soundId = "", volume = 0.12 }, -- soft healing / ASMR frequency pad
}

AudioDefs.Stations = {
	tetraforge = { soundId = "", volume = 0.5 },
	arc_welder = { soundId = "", volume = 0.4 },
	lathe = { soundId = "", volume = 0.35 },
	coral_vat = { soundId = "", volume = 0.3 },
	printer = { soundId = "", volume = 0.3 },
	helix = { soundId = "", volume = 0.4 },
} :: { [string]: SoundDef }

return AudioDefs
