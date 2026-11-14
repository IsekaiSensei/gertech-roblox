--!strict
-- Global tuning knobs. Values marked PLACEHOLDER are not from the Godot source of truth.

local Config = {}

-- Which shared workshop this server belongs to. One DataStore key per workshop id.
-- Godot equivalent: the single WorldSeed save (user://gertech_worldseed_v1.json).
Config.DEFAULT_WORKSHOP_ID = "Workshop_Global"

Config.DATASTORE_PLAYERS = "GERTECH_Players_v1"
Config.DATASTORE_WORKSHOPS = "GERTECH_Workshops_v1"
Config.MESSAGING_TOPIC = "GERTECH_WorkshopSync_v1"

Config.AUTOSAVE_SECONDS = 60 -- PLACEHOLDER
Config.WORKSHOP_FLUSH_SECONDS = 20 -- PLACEHOLDER: how often gathered deltas are committed
Config.SESSION_LOCK_STALE_SECONDS = 600 -- a lock older than this is considered abandoned
Config.DATASTORE_RETRIES = 5

-- Station interaction
Config.STATION_MAX_DISTANCE = 16 -- studs; server rejects requests from farther away
Config.GATHER_MAX_DISTANCE = 14

-- Godot forge_foundry.gd: target_lines = 8 (output quota per run)
Config.FORGE_MAX_ROWS_PER_RUN = 8
-- Godot tetromino_grid: 10-wide chamber -> one row = 10 material cells
Config.FORGE_ROW_WIDTH = 10
-- PLACEHOLDER: seconds per row in the timer-based adaptation (Godot is a live Tetris run)
Config.FORGE_SECONDS_PER_ROW = 3
Config.FORGE_MAX_CONCURRENT_JOBS = 4 -- PLACEHOLDER: operators at one console

return Config
