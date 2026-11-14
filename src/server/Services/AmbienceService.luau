--!strict
-- Workshop / electronics ambience (+ healing / ASMR tone layer). Plays only the sounds whose
-- ids are filled in AudioDefs; ships silent so no unlicensed audio is referenced.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local AudioDefs = require(ReplicatedStorage.Shared.AudioDefs)

local AmbienceService = {}

function AmbienceService.start(stationParts: { [string]: BasePart })
	SoundService.AmbientReverb = Enum.ReverbType.Hangar
	for _, a in AudioDefs.Ambience do
		if a.soundId ~= "" then
			local s = Instance.new("Sound")
			s.Name = a.key
			s.SoundId = a.soundId
			s.Volume = a.volume
			s.Looped = true
			s.Parent = SoundService
			s:Play()
		end
	end
	for key, def in AudioDefs.Stations do
		local p = stationParts[key]
		if p and def.soundId ~= "" then
			local s = Instance.new("Sound")
			s.Name = key .. "_loop"
			s.SoundId = def.soundId
			s.Volume = def.volume
			s.Looped = true
			s.RollOffMaxDistance = 60
			s.Parent = p
			s:Play()
		end
	end
end

return AmbienceService
