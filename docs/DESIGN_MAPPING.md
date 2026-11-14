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
| Tetris Forge Foundry run (10×20, 4 cells per piece, live play) | `forge_foundry.gd`, `tetromino_grid.gd` | **TETRAFORGE** station: pick a row composition and 1–8 rows, server timer at 3 s per row | ADAPTED (the live falling-block run isn't ported yet) |
| Feed stock = ore / salvage / pure_component | `forge_foundry.gd`, `inventory.gd get_foundry_config` | Recipe inputs use only these three | CANON |
| Alloy enabled only when pure_component ≥ 4 | `inventory.gd get_foundry_config` | `RecipeDefs.ALLOY_ENABLE_THRESHOLD`, checked by the server | CANON |
| Alloy piece = 2 base + 2 pure | `forge_foundry.gd _choose_materials` | Alloy rows hold exactly 2 pure per row | CANON-derived |
| Row cleared → 1 packed_block; ≥4 salvage → +stabilized_frame; ≥2 pure → +forged_blank | `forge_foundry.gd _lock_piece` | 4 row compositions in `RecipeDefs`, each checked at boot by `validateRowRules` | CANON rules; the compositions are ADAPTED |
| Output quota `target_lines = 8` | `forge_foundry.gd` | `Config.FORGE_MAX_ROWS_PER_RUN = 8` | CANON |
| Score = rows² × 100 per clear, +400 for 4 rows | `forge_foundry.gd` | `RecipeDefs.scoreForRows`, assuming the best-case 4-row clears | CANON formula, ADAPTED grouping |
| Leftover chamber cells ÷ 5 → scrap | `forge_foundry.gd _end_run` | An aborted run (cancel, leaving, server shutdown) keeps its finished rows. Unfinished rows' cells ÷ 5 become scrap. | CANON rule, ADAPTED trigger |
| Heat (0.19 start, rises per lock/clear, speeds gravity) | `forge_foundry.gd` | Console glow only | Not ported (no gameplay effect without the live run) |
| `foundry_runs` counter | `world_seed.gd` | `foundryRuns` on the workshop record | CANON |
| `MinigameInterface` (`start` / `minigame_finished(result)`) | `core/game_loop/minigame_interface.gd` | Planned for the live TETRAFORGE minigame. Results will go through `WorkshopInventoryService.transact` the way Godot uses `apply_material_receipt`. | PLANNED |
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
| No XP / levels in Godot | — | Per-player XP: forge score × 0.1, +2 per gather, +5 per socket. Level gates: Ore/Salvage rows L1, Alloy L2, Salvage Alloy L3. | **PLACEHOLDER** |
| Audio: none in the build | — | `AudioDefs` slots: workshop + electronics bed, healing/ASMR tone layer (Ryan, 2026-11-14) | PLACEHOLDER ids |

## Explicitly not decided by canon (do not treat the Roblox choices as lore)
- **What Tetris/TETRAFORGE "really does"** in the manufacturing chain is officially unsettled. That's Ryan's own note in the Nov 13 reconstruction. This port only reproduces what the Godot code already does.
- The station order ASTER-ORES → BREAKDOWN → BUBBLE SORT → TETRAFORGE → DOGIEPRESS → DIG DOG is a **candidate** path from the Nov 14 handoff, not an implemented chain.
- Durability-from-score (Tetris/Bejeweled) isn't in the Godot receipt, so it isn't here either.
