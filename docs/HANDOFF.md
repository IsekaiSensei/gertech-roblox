# GERTECH Roblox — Handoff (2026-11-14)

Repo: https://github.com/IsekaiSensei/gertech-roblox (public). This is a Rojo 7.4 project for the Roblox (Luau) version of GERTECH.
The Godot project in `IsekaiSensei/to-world-open-crew` (`godot/GERTECH_Aqua_Workshop`) is the **source of truth** for game logic. This repo ports that logic and adapts it to Roblox.

## What exists

- **Workshop hub** (`src/server/HubBuilder.luau`): spawn, resource docks, forge console, stock exchange, WorldSeed lattice sockets, quantum table, and the **DNA wormhole helix** portal. Never call the portal "the zipper".
  - Set dressing: coral growth vats, resin printer, 3D printer, arc welder, lathe and machine-shop tools.
  - Ambience: workshop and electronics sounds (`AudioDefs`, `AmbienceService`).
- **Shared workshop inventory** (`WorkshopInventoryService`): stored in the `Workshop_Global` DataStore. Writes use UpdateAsync with session locking, and MessagingService keeps servers in sync.
- **Player data** (`DataService`): uses session locks. XP and levels are **placeholders**.
- **TETRAFORGE**: the real falling-block game, ported faithfully from Godot.
  - Pure logic modules: `TetrominoGrid`, `ForgeRules`, `ForgeSession` and `ForgeFeed`.
  - The **server is authoritative** (`ForgeService`): it owns the board, the RNG and the gravity tick. The client (`UI/ForgeView`) only sends rate-limited input intents and renders a ScreenGui grid with interpolation.
  - A run can use the whole shared stock through an atomically reserved **rolling hopper**. Materials are spent on lock, as in Godot. Leftovers are refunded or converted when a player ends the run, leaves, or the server shuts down, so nothing is duplicated or lost.
  - Each player can have one active session, and other players can watch.
- **Provisional look pass toward REF_01..14** (not canon):
  - `DecorGeometry` (engine-free primitive specs), `VisualStyle` (server: lighting, materials, decor) and `DecorFx` (client: spins and flipbooks).
  - The look: black space with star dust, gold and chrome, cyan Neon edges, Platonic frames inside crystal spheres, a torus-plus-helix wormhole, fractal sphere clusters, and a golden-spiral polyhedra chain.
  - The decor is capped at 1700 parts by test.
- **Image slots** (`src/shared/ImageAssets.luau`): 22 slots (14 refs, 2 flipbook sheets, 6 sky faces). **All are empty.** The game falls back to procedural visuals until asset IDs are filled in.
  - Image files are stored base64-encoded in `assets/encoded/`. `tools/unpack_assets.py` decodes them, and `tests/run.sh` does this automatically.
- **Tests:** `tests/run.sh` (luau CLI) covers board logic, line clears, scoring parity with Godot, hopper conservation, decor budget and placement, and image slots. **9263 passed, 0 failed.**

## How to test in Studio

1. Install the tools with `aftman install` (rojo, selene, stylua).
2. **Either** run `rojo serve` and connect from the Rojo Studio plugin, **or** build with `rojo build -o GERTECH.rbxlx` and open the file. A prebuilt `GERTECH.rbxlx` is inside `gertech-roblox.zip`.
3. Publish the place, then turn on **Game Settings > Security > Enable Studio Access to API Services**. DataStores and MessagingService need this. Without it, data falls back to in-memory only.
4. Press Play. Gather at the docks, use the forge console and the stock exchange, start TETRAFORGE at the chamber, and walk into the DNA wormhole helix.
5. Images (optional):
   - Run `python3 tools/unpack_assets.py`.
   - Upload the files in `assets/refs`, `assets/sheets` and `assets/sky` with the Studio Asset Manager (Bulk Import) or the Creator Dashboard.
   - Paste each numeric **Image** id into the matching `assetId` in `ImageAssets.luau`. Empty slots keep the procedural visuals.
6. Checks: `selene src`, `stylua --check src tests`, luau-lsp analyze, and `bash tests/run.sh`.

## Commit history (summary)

| Milestone | Notes |
|---|---|
| v0.1 initial import (multi-part, 241d21d…) | Rojo structure, hub, shared inventory, DataStores, docs |
| TETRAFORGE port | Real falling-block game from Godot. The server-authoritative sim replaced the timed batch. |
| Whole shared stock | Removed the 120/56/16 per-run cap and added the rolling hopper with atomic top-ups |
| Look pass REF_01..14 (11 parts, ending 1f1309f) | Procedural decor, image slots, encoded assets, iso preview (`docs/preview_iso.png`) |
| This handoff | `docs/HANDOFF.md` |

Pushes go through the GitHub API in batches, so a milestone can span several commits.

## Canon vs placeholder

- **Ported from Godot (canon logic):**
  - TETRAFORGE: grid, piece set, materials drawn from shared stock, line clears producing rows, row output rules, leftover/5 → scrap, the 8-row cap and scoring.
  - Recipes and items as listed in `docs/DESIGN_MAPPING.md`.
- **Roblox adaptations:** the server-authoritative sim, the hopper reservation, DataStore session locks and cross-server sync.
- **Placeholder:**
  - XP and levels (`ProgressionDefs`).
  - All look-pass visuals (provisional refs, not canon).
  - Audio IDs.
  - The space backdrop.

## Not done (dropped cleanly, no code started)

The second look pass was **not implemented**. The tree is clean at the look-pass commit. That pass would have covered:
- batch2 REF_15–26
- Godot's REF_27–30 room and hall refs
- Drive picks such as `META_REVIEW__042…wormhole_icosahedron_logo.webp` and `GALACTIC_ETHER_RELAY_REF_04_MANA_FLOW_LATTICE.jpg`
- aligning colours to the Unity palette (`unity/Assets/Scripts/Look/GertechLook.cs`: Gold #BF8F43, GoldJoint #EF9E29, Chrome #BDC0BC, Cyan #35CAD8, Teal #3A8D9F, NebulaViolet #701AA9, InfinityBlue #3A7DFF provisional)
- the **Workshop Guide** NPC: a procedural R15-style rig with a gold lattice dress, blonde hair, blue infinity clip and sneakers, standing near spawn, with ProximityPrompt tips that describe only current features.

The Workshop Guide turnaround sheet is **not on the box or in Ryan's Drive library folder**. Searches for guide, turnaround, workshop, lattice and gold found only other characters (the Character Lattice Master sheets, the Porcelain Angel).

## Open questions for Ryan

1. **Roof/backdrop: space or undersea?** The look pass uses black space; the original Aqua Workshop is undersea. The roof has not been changed.
2. **XP/levels: keep or drop?** They are currently placeholders.
3. **One global workshop (shared stock across all servers, current) or private per player/party?**
4. **REF_14 texture check:** should the nebula triangle face use the REF_14 image as a texture, or stay procedural?
5. Please send the Workshop Guide turnaround sheet (to Drive or chat) so the NPC can be built against it.

## How ChatGPT or another agent can continue

- Clone the repo, run `bash tests/run.sh`, and read `README.md`, `docs/DESIGN_MAPPING.md` and `docs/ROADMAP.md`.
- Keep logic engine-free in `src/shared` and add tests in `tests/pure.spec.luau`. Server code goes in `src/server/Services`, and client UI in `src/client/UI`.
- Look work: add primitives in `DecorGeometry` (stay under `PART_BUDGET`) and styles in `VisualStyle.STYLES`. Add any new image as a slot in `ImageAssets`, put a downscaled copy in `assets/`, and add it to `tools/make_assets.py` and `assets/encoded`.
- Rules:
  - Godot is the source of truth for mechanics.
  - Label every placeholder.
  - Don't invent lore.
  - The portal is the **DNA wormhole helix**.
- Reference images on the shared box: `/workspace/gertech_shared_refs/` (visual_2026-11-14, visual_2026-11-14_batch2 with INDEX.md, drive_dl). Ryan's Drive library: https://drive.google.com/drive/folders/1wZLgBCGOoOL-r5bW4xJ95fyCS4F50ULT
