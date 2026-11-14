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

-- TETRAFORGE session (Roblox adaptation knobs; game rules live in ForgeRules)
Config.FORGE_MAX_SESSIONS_PER_STATION = 1 -- one chamber, like Godot; others watch
Config.FORGE_PAUSE_MAX_SECONDS = 30 -- PLACEHOLDER: shared station, so pauses auto-resume
Config.FORGE_SNAPSHOT_MIN_INTERVAL = 0.05 -- max 20 board snapshots / s per session
Config.FORGE_WATCH_DISTANCE = 60 -- studs; watchers farther away are dropped
Config.FORGE_INPUT_BURST = 30 -- input intents rate limit (token bucket)
Config.FORGE_INPUT_PER_SECOND = 20
Config.FORGE_OPERATOR_MAX_DISTANCE = 40 -- operator walking off ends the run

Config.FORGE_TOPUP_MIN_INTERVAL = 2 -- seconds between routine hopper top-ups (DataStore budget)
Config.FORGE_TOPUP_RETRY_SECONDS = 0.5 -- while a piece waits for feed

-- Reservations older than this (no heartbeat from the owning server) are refunded in full.
Config.RESERVATION_STALE_SECONDS = 300

-- PROVISIONAL look pass toward Ryan's shared reference images (not canon, no gameplay):
-- "refs_2026_11_14" = space / gold / chrome / cyan decor (VisualStyle); "classic" = the
-- original aqua-workshop colors only.
Config.VISUAL_STYLE = "refs_2026_11_14"

return Config
