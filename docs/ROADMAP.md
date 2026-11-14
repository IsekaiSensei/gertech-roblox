# Roadmap: GERTECH multi-place universe

One Roblox experience made of several places. Players travel between them through the **DNA wormhole helix** (never "the zipper") using `TeleportService:TeleportAsync`. Every place uses the **same workshop key** in `GERTECH_Workshops_v1`, so the manufacturing economy stays shared. The workshop id travels in `TeleportData`, and the destination calls `WorkshopInventoryService.setWorkshopId()` before `start()`.

| Place | Purpose | Inputs → outputs | Godot / design anchor |
|---|---|---|---|
| **Hub** (this place) | Workshop, TETRAFORGE, exchange, lattice, helix | ore/salvage/pure → packed_block, stabilized_frame, forged_blank, scrap | Aqua Workshop + Forge Foundry |
| **Mining** | Dig Dog excavation and Aster-Ores breakup | → ore, soil, salvage, rock | DIG DOG and ASTEROIDS docks; ASTER-ORES / BREAKDOWN candidate stations |
| **Forge** | A floor with several TETRAFORGE chambers (the hub has one), and later DOGIEPRESS (press / form / mount) | feed → crystallized rows; scrap from leftover cells | `forge_foundry.gd`, `tetromino_grid.gd`, `MinigameInterface`; DOGIEPRESS is PLANNED in design |
| **Assembly** | Grown-part sorting and assembly: coral/colony harvest → sort → assemble → test, plus the WorldSeed lattice at full scale | grown parts + packed blocks → assemblies | Chalk/biomineral manufacturing reconstruction (Nov 13); WorldSeed assemblies |
| **Hangar** | Building and docking vehicles and units from assemblies | assemblies → vehicles/units | Saturn Astra modular cockpit design; poundage/mount limits (brainstorm §8) |
| **Expeditions** | Missions that bring back salvage and rare stock. Gauntlet-style action is Ryan's stated reference for combat feel. | units → salvage, crystals | TO DoG handoff (Nov 14) |

## Milestones
1. **v0.1 (this commit).** Hub, timer-based TETRAFORGE, shared stock, gathering, exchange, lattice, helix hooks, saves.
2. **v0.2.** First Studio play-test and fixes. Fill in `AudioDefs`. Add real models for the stations.
3. **v0.3 (done early, Nov 14).** The live TETRAFORGE: a server-simulated port of the Godot falling-block forge with atomic feed reservation and settlement. This replaced the timer batch.
4. **v0.4.** Mining place, plus the helix teleport carrying `workshopId`. Private workshops: reserved servers keyed by `Workshop_<ownerUserId>`.
5. **v0.5.** Assembly place: WorldSeed lattice growth, and the sorting minigame once Ryan defines it.
6. **v0.6+.** Hangar and Expeditions. A cross-game backpack adapter, kept separate from the workshop save until the mapping is tested, per the Nov 14 handoff.

## Technical notes for the universe
- Use `TeleportService:ReserveServer` for private workshops and pass `{ workshopId }`. Public servers default to `Workshop_Global`.
- MessagingService topic `GERTECH_WorkshopSync_v1` already includes `workshopId`, so servers in every place can listen on it.
- Per-player progression (`GERTECH_Players_v1`) is shared across places by default. The session lock hands off cleanly on teleport, because the lock is released on `PlayerRemoving`.
- Keep DataStore budgets in mind. A workshop commit costs one `UpdateAsync`. At about 20 s flush intervals per server, roughly 30 servers fit comfortably inside the per-key write limit. Beyond that, shard the workshop into category keys or move to MemoryStore queues.
