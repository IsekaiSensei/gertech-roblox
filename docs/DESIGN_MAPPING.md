# Godot → Roblox design mapping

**Source of truth:** Godot 4 project `GERTECH_Aqua_Workshop`, the Nov 10/11 2026 baseline. It's owned by the *Godot Continuity* bot. The Roblox port follows it. When this file and the Godot code disagree, the Godot code is right.

Sources read for this port:
- Godot code: [`to-world-open-crew/godot/GERTECH_Aqua_Workshop`](https://github.com/IsekaiSensei/to-world-open-crew/tree/main/godot/GERTECH_Aqua_Workshop), plus the box copy of the Nov 10 baseline, `current_build.zip`, at `/workspace/godot-current-review/extract/GERTECH_Aqua_Workshop` (63 files, sha256 `91ad30f4…`).
  - `workshop/inventory.gd`, `worldseed/world_seed.gd`, `theme_foundry/forge_foundry.gd`, `core/tetris/tetromino_grid.gd`, `core/game_loop/minigame_interface.gd`, `scripts/workshop.gd`, `README.md`
- Progression chart page: "TO WORLD / GERTECH — Progression Chart + Implemented vs Planned" (Nov 14 2026)
- Drive: *TO DoG reopens — Grokbot Ambassador / ChatGPT game handoff — 2026-11-14*. This is where the name **TETRAFORGE** and the candidate path ASTER-ORES → BREAKDOWN → BUBBLE SORT → TETRAFORGE → DOGIEPRESS → DIG DOG come from.
- Drive: *GERTECH Workshop Concepts — Placement and Gap Report — 2026-11-13*. It records that Tetris's purpose is "officially unsettled", quoting Ryan: "we never really established what it really does."
- GitHub: `chat.work.open.ai/brainstorm/GERTECH_SHARED_BRAINSTORM_2026-11-10.md`, sections on one shared backpack and the candidate minigame roles.
- Owner lore from Ryan, passed on by the parent bot: growth vats, printers, arc welder, lathe, quantum table, DNA wormhole helix (never "the zipper"), and the sound direction.

Labels: **CANON** means copied exactly from the Godot code. **ADAPTED** means the same rule implemented a different way for Roblox. **PLACEHOLDER** means invented for this port and safe to swap.

| Godot system | Godot file(s) | Roblox equivalent | Status |
|---|---|---|---|
| Single inventory authority (`WorldSeed.inventory`; "Single authority") | `worldseed/world_seed.gd`, `workshop/inventory.gd` | `WorkshopInventoryService`: one DataStore key per workshop id (`Workshop_Global`), shared by all players and servers | ADAPTED (local file → DataStore + MessagingService) |
| 12 inventory keys + `STARTER_STOCK` (ore 120, salvage 56, pure 16, others 0) | `world_seed.gd` | `ItemDefs.STARTER_STOCK` | CANON |
| `equipment.visor_chip_capacity` = 1 | `world_seed.gd`, `inventory.gd` | `ItemDefs.STARTER_EQUIPMENT`, stored on the workshop | CANON |
| `can_consume` / `apply_material_receipt` (reject if short, never negative, log the receipt) | `world_seed.gd` | `WorkshopInventoryService.consume/transact`: atomic in `UpdateAsync`, negative-stock guard, 50-entry event log | CANON rule, ADAPTED storage |
| Save to `user://gertech_worldseed_v1.json` | `world_seed.gd` | DataStore `GERTECH_Workshops_v1`, plus per-player `GERTECH_Players_v1` | ADAPTED |
| Tetris Forge Foundry run (live falling-block play) | `forge_foundry.gd`, `tetromino_grid.gd` | **TETRAFORGE**: the same game, simulated on the server (`ForgeSession`) and rendered in a client ScreenGui plus the in-world 10×20 chamber | PORTED (Ryan, 2026-11-14: "real falling-block game like Godot") |
| Grid 10×20; shapes I O T L J S Z with Godot's exact offsets; rotation (x,y)→(−y,x), O never rotates | `tetromino_grid.gd` | `TetrominoGrid.luau` (same 0-based coordinates; y=0 is the top) | CANON |
| `fits` (walls/floor block, above-top allowed), `lock` (overflow if any cell is above the top; clear solid rows bottom-up with a per-row material tally; shift down) | `tetromino_grid.gd` | `TetrominoGrid.fits/lock` | CANON |
| Spawn at (4,1), rotation 0; next-piece preview; uniform random piece | `forge_foundry.gd _spawn_piece/_random_shape` | `ForgeSession` with a server `Random` | CANON |
| Rotation kicks 0, −1, +1, −2, +2 | `_rotate_piece` | `ForgeRules.ROTATION_KICKS` | CANON |
| Hold (C): once per piece; first hold takes the next piece; the active piece keeps its materials | `_hold_piece` | `ForgeSession.hold` | CANON |
| Soft drop ×0.11 interval; hard drop = fall then lock; pause (P) | `_process`, `_unhandled_input` | Same rules, driven by input intents. A pause auto-resumes after 30 s because the station is shared. | CANON + ADAPTED pause limit |
| Gravity `max(0.09, 0.62·(1 − min(heat,1)·0.34))`; heat starts 0.19, +0.018 per lock, +0.07 per cleared row | `_process`, `_lock_piece` | `ForgeRules.gravityInterval`, server Heartbeat tick | CANON |
| Pieces drawn from ore or salvage (whichever has ≥4 left of the whole stock); alloy piece [base, pure, base, pure] when alloy is enabled, ≥2 pure and ≥2 base remain, and a roll < 0.32 | `_choose_materials` | `ForgeRules.chooseMaterials`, given remaining = unspent hopper + unreserved shared stock (`ForgeFeed.hopper:remaining`) | CANON |
| Alloy enabled when pure_component ≥ 4 | `inventory.gd get_foundry_config` | `enableAlloy` = whole-stock pure ≥ 4 at run start | CANON |
| Feed budget = the whole workshop stock | `inventory.gd get_foundry_config` | The run draws on the whole shared stock (Ryan, 2026-11-14). Only a rolling feed hopper (target 40/40/12, refill below 20/20/6) is held out of the shared stock. It is reserved atomically at start and topped up atomically (`topUpFeed`) as pieces lock. Everything else stays spendable by other players and stations, and mid-run gathering feeds the run. | CANON budget; ADAPTED delivery (DataStore allows 1 write per key every 6 s, so a write per lock is impossible) |
| Materials spent only when a piece locks (4 cells per piece) | `_lock_piece` | Same: each lock spends 4 cells from the hopper. A piece spawns only when its cells are already in the hopper. Otherwise it waits with the status `FEED HOPPER REFILLING`, without drawing RNG again, so the piece sequence matches Godot. The unlocked active piece is refunded. | CANON + ADAPTED wait |
| Each cleared row → 1 packed_block; ≥4 salvage cells → +stabilized_frame; ≥2 pure cells → +forged_blank (from the actual row contents) | `_lock_piece` | `ForgeRules.rowOutputs(tally)` | CANON |
| Score += rows² × 100 per lock, +400 for a 4-row clear | `_lock_piece` | `ForgeRules.scoreForClear`, applied per real lock | CANON |
| Run ends at the 8-row quota (`target_lines = 8`), chamber full, hoppers empty, material overflow, or Esc ("RETURN TO THE LOFT") | `_lock_piece`, `_spawn_piece`, `_end_run` | Same reasons. Backspace replaces Esc (Roblox reserves Esc). Extra host reasons: OPERATOR LEFT, OPERATOR LEFT THE CONSOLE, SERVER SHUTDOWN, FEED LINE LOST (reservation refunded as abandoned). | CANON + ADAPTED keys/reasons |
| Leftover locked cells ÷ 5 → scrap at run end | `_end_run` | Same | CANON |
| Result dictionary (win, score, materials_consumed, materials_produced, forge_heat, stats, station, reason) | `_end_run` | `ForgeSession.result` (same fields, camelCase) | CANON |
| Receipt applied to the inventory (`apply_material_receipt`) | `world_seed.gd`, `inventory.gd deposit_from_minigame` | `WorkshopInventoryService.settleReservation`: refund the unspent hopper + add products + delete the reservation, in one atomic write, after any in-flight top-up has landed. Abandoned reservations get a full refund after 5 min without a heartbeat. | ADAPTED (multiplayer-safe) |
| One local player | — | One session per player, one chamber per station; watchers get the same snapshots; the in-world chamber mirrors the board | ADAPTED |
| `MinigameInterface` (`start` / `minigame_finished(result)`) | `core/game_loop/minigame_interface.gd` | `ForgeSession.start` / `finished` + `result`. Engine-free, doesn't know about the inventory (same independence rule). | CANON contract |
| `foundry_runs` counter | `world_seed.gd` | `foundryRuns` on the workshop record | CANON |
| Stock exchange: 4 packed_block + 1 forged_blank → visor_chip_capacity +1 (K) | `inventory.gd make_mouse_visor_chip_upgrade` | `ExchangeService` | CANON |
| `occupy_vertex` (spend 1 module) / `free_vertex` (recover 1:1; the `core` vertex can't be freed) | `world_seed.gd` | `LatticeService` sockets | CANON rules |
| WorldSeed lattice growth (36 vertices, Delaunay, silhouette → tetra) | `worldseed/*` | Fixed 12-socket ring with gold joints | PLACEHOLDER (geometry not ported) |
| Intake docks: DIG DOG = ORE + SOIL, ASTEROIDS = SALVAGE + ROCK, BREAKOUT = REFINED PARTS | `scripts/workshop.gd` | Gatherable nodes: Dig Dog seam → ore + soil, Asteroid rock → salvage, Breakout bin → pure_component | CANON sources. ADAPTED: "refined parts" mapped to pure_component. PLACEHOLDER yields |
| Mouse Maze / Frogger / Space Invaders docks (scenery) | `scripts/workshop.gd` | Labeled offline docks | CANON (scenery in Godot too) |
| DNA double-helix Galactic Ether Relay (scenery) | `scripts/workshop.gd` | DNA wormhole helix with 5 destination pads and a TeleportService hook | ADAPTED (Godot has no transfer logic) |
| Biomineral / shell foundry, vacuum-crystal gallery, living-metal loom, six-vat printing room | `scripts/workshop.gd` | Coral growth vats, resin printer, 3D printer, arc welder, lathe, machine-shop tools (Ryan's set-dressing list) | Scenery |
| Quantum table | Owner lore (not in the Godot scene) | Table with a holo grid, virtual avatar and micronized android | Scenery; piloting PLANNED |
| Gold superconductor lines | `module_types.gd`, gold_rail GLB | Neon gold floor lines and lattice joints | Scenery (no circuit logic, same as Godot) |
| Unused keys `soil`, `food`, `labor_token`, `alloy`, `defense_tech` | `world_seed.gd` | Kept with the same names. Only soil has a source (Dig Dog), matching its dock label. | CANON |
| No XP / levels in Godot | — | Per-player XP: forge score × 0.1, +2 per gather, +5 per socket. Level gates were removed with the row recipes, so a level unlocks nothing yet. | **PLACEHOLDER** (pending Ryan) |
| Audio: none in the build | — | `AudioDefs` slots: workshop + electronics bed, healing/ASMR tone layer (Ryan, 2026-11-14) | PLACEHOLDER ids |

## Explicitly not decided by canon (do not treat the Roblox choices as lore)
- **What Tetris/TETRAFORGE "really does"** in the manufacturing chain is officially unsettled. That's Ryan's own note in the Nov 13 reconstruction. This port only reproduces what the Godot code already does: the falling-block forge turning feed into packed blocks, frames and blanks.
- The station order ASTER-ORES → BREAKDOWN → BUBBLE SORT → TETRAFORGE → DOGIEPRESS → DIG DOG is a **candidate** path from the Nov 14 handoff, not an implemented chain.
- Durability-from-score (Tetris/Bejeweled) isn't in the Godot receipt, so it isn't here either.
