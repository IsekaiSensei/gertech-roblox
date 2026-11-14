# GERTECH — Roblox (Luau)

The Roblox build of Ryan's GERTECH multiplayer manufacturing game. You start in the **GERTECH Aqua Workshop hub**: gather raw feed at the intake docks, run it through the **TETRAFORGE** (the Tetris / Forge Foundry), and spend the output at the stock exchange and the WorldSeed lattice. Everyone on every server shares one **workshop inventory**. Your XP and level save between sessions.

> **Source of truth:** the Godot project `GERTECH_Aqua_Workshop` (owned by the *Godot Continuity* bot,
> mirrored at [`IsekaiSensei/to-world-open-crew/godot/GERTECH_Aqua_Workshop`](https://github.com/IsekaiSensei/to-world-open-crew/tree/main/godot/GERTECH_Aqua_Workshop)).
> Item keys, starter stock, forge row rules, scrap rule, visor-chip upgrade and lattice salvage
> rules are copied from it. Everything else is labeled **PLACEHOLDER** in code and in
> [`docs/DESIGN_MAPPING.md`](docs/DESIGN_MAPPING.md).

## Run it

### Option A: Rojo (recommended)
1. Install the toolchain: `aftman install` (pins Rojo 7.4.4, selene, StyLua). You can also install Rojo on its own.
2. Install the Rojo plugin in Roblox Studio (Plugins → Manage Plugins, or `rojo plugin install`).
3. In this folder run `rojo serve`.
4. In Studio, open a **Baseplate**, click **Rojo → Connect**. The scripts sync in.
5. Press **Play**. The hub builds itself, and the default Baseplate part is removed at runtime.

Or build a place file with `rojo build -o GERTECH.rbxlx` and open it.

### Option B: manual copy (no Rojo)
In Studio, create the matching instances and paste each file's source:

| Folder | Studio location | Instance type |
|---|---|---|
| `src/shared/*.luau` | `ReplicatedStorage › Shared` (Folder) | ModuleScript per file |
| `src/server/Main.server.luau` | `ServerScriptService › Server` (Folder) | **Script** named `Main` |
| `src/server/HubBuilder.luau` | `ServerScriptService › Server` | ModuleScript |
| `src/server/Services/*.luau` | `ServerScriptService › Server › Services` (Folder) | ModuleScript per file |
| `src/client/Main.client.luau` | `StarterPlayer › StarterPlayerScripts › Client` (Folder) | **LocalScript** named `Main` |
| `src/client/UI/Widgets.luau`, `src/client/UI/ForgeView.luau` | `…› Client › UI` (Folder) | ModuleScript per file |

### Saving data (DataStores)
- **Published game:** saving works once the place is published.
- **Studio:** publish the place, then go to *Game Settings → Security* and turn on **Enable Studio Access to API Services**. If it's off, the server warns and switches to an **in-memory mock**: everything still plays, but nothing persists.
- Cross-server sync uses **MessagingService**, which only runs in live servers. In Studio, a single server works without it.

### Controls
- **E / hold E** on prompts: operate or watch the TETRAFORGE, gather, trade, place or recover lattice modules, use the helix pads.
- **In the TETRAFORGE** (same keys as Godot): **A/D** or **←/→** move · **W/↑/X** rotate · **S/↓** soft drop · **Space** hard drop · **C** hold · **P** pause · **Backspace** ends the run. Roblox reserves Esc for its own menu, so Backspace replaces Godot's Esc. On touch screens, use the on-screen buttons.
- **I**: toggle the shared stock panel. **Esc**: close panels.

## What's in the hub
| Station | What it does | Status |
|---|---|---|
| **TETRAFORGE** (operator console + 10×20 chamber) | The real falling-block forge, ported from Godot. Pieces are made from ore, salvage and pure components drawn from the whole shared stock through a small atomically reserved feed hopper. Cleared rows crystallize into packed blocks, stabilized frames and forged blanks. A run ends at 8 rows. Leftover cells ÷ 5 become scrap. One operator at a time; anyone can watch, either in the panel or on the in-world chamber. | Playable (server-simulated) |
| Intake docks: **Dig Dog** ore seams, **Asteroids** salvage rocks, **Breakout** refined-parts bins | Hold to gather into the shared stock. Nodes deplete and regrow. | Playable (stand-in for minigames that aren't built yet) |
| **Stock Exchange** | 4 Packed Blocks + 1 Forged Blank → workshop Visor Chip capacity +1 | Playable (canon) |
| **WorldSeed lattice** (12 sockets, gold joints) | Place a Packed Block into a socket, or recover it 1:1. The core socket can't be recovered. | Playable (canon rules, placeholder size) |
| **DNA wormhole helix** + 5 destination pads | Teleports to the mining, forge, assembly, hangar and expeditions places once their PlaceIds are set. Until then it says the helix isn't stable yet. | Hook only |
| Coral growth vats, resin printer, 3D printer, arc welder, lathe, drill press, bench grinder, tool wall | Set dressing that shows parts being grown and assembled. *Inspect* prompts show lore text. | Scenery |
| **Quantum table** | Workbench with a tabletop virtual avatar and a micronized android. | Scenery (piloting planned) |
| Mouse Maze / Frogger / Space Invaders docks | Labeled offline, as in Godot. | Scenery |

Audio: `src/shared/AudioDefs.luau` has slots for workshop and electronics ambience plus a healing/ASMR tone layer. No sound assets ship with it. Paste `rbxassetid://` ids there.

## Provisional look pass (Ryan's references REF_01–REF_14)
Ryan shared 14 reference images (2026-11-14) as a common look for all the GERTECH bots. The hub is styled toward them. **This is provisional and not canon.** Godot is still the source of truth for logic, and no gameplay changed. The look is all procedural parts (`src/shared/DecorGeometry.luau`, which runs without the engine, plus `src/server/VisualStyle.luau`). To go back to the original aqua-workshop colors, set `Config.VISUAL_STYLE = "classic"`.

- **Shared look:**
  - Lighting: Future technology, dark ambient, Bloom and ColorCorrection, no Atmosphere.
  - Sky: night with the engine's star field, plus about 260 Neon star-dust specks above the darkened roof glass.
  - Materials: black chrome walls; polished gold (Metal/Foil) and chrome (Metal with reflectance); glowing cyan Neon edges, Highlights and Beams.
- **Performance:** about 1,450 decor parts. None of them collide, can be touched or can be queried, and none cast shadows. Spins run on the client at 30 Hz, only within 140 studs of the camera (`src/client/DecorFx.luau`). The tests cap decor at 1,700 parts. They also keep it inside the hub and away from the spawn, the forge console, the exchange, the lattice sockets, the helix pads, the quantum table and the docks.
- **Preview:** `docs/preview_iso.png` is an offline isometric layout check, not a Roblox render. To regenerate it: `bash tests/run.sh && (cd tests && luau dump_decor.luau > /tmp/decor.jsonl) && python3 tools/render_preview.py /tmp/decor.jsonl docs/preview_iso.png`.

| Reference | In the hub (procedural) | Image slot (used once uploaded) |
|---|---|---|
| REF_01 fractal vortex spheres | `FractalCascade`: gold/chrome/teal sphere clusters falling out of a small vortex ring (west wall) | gallery poster |
| REF_02 Platonic frames, crystal sphere, vortex | `MerkabaSphere`: gold star tetrahedron in a crystal + ForceField sphere, inner ring, cyan core | gallery poster |
| REF_03 gold cube, torus, sphere | `GoldCubeSphere` (gold glass sphere, cube frame, chrome + gold tori) and the helix's `WormholeTorus` | gallery poster |
| REF_04 polyhedra column, helix | `HelixProgression` frames up the helix axis, plus 3 curved cyan Beams | gallery poster |
| REF_05 gold rings, icosahedron | `GoldRingStack`: stacked gold/chrome rings around an icosahedron, cyan spine | gallery poster |
| REF_06 Voronoi gold/silver | `FoamLattice`: Voronoi-style (jittered hex) gold/silver floor tiles with cyan seams around the helix | gallery poster |
| REF_07 torus vortex, sphere tree | `SphereTree` under a ForceField torus (east corner) | gallery poster |
| REF_08 foam lattice, golden spiral | `FoamLattice` tiles colored along golden-spiral arms, plus `GoldenSpiralChain` | gallery poster |
| REF_09 gold polyhedra spiral chain | `GoldenSpiralChain`: faceted gold bodies on a golden spiral (r × φ every quarter turn) with cyan seams, hung over the lattice | gallery poster |
| REF_10 Modular Crystal Block | `ModularCrystalBlock` (crystal glass cube, gold edges, corner connectors with cyan eyes, inner energy helix, nebula particles). Same edge language on the TETRAFORGE chamber (`ChamberFrame`: cyan Neon edges, gold connectors, Highlight). | gallery poster |
| REF_11 five elemental crystals | 5 pedestals: tetra (fire), cube (frost), octa (storm), dodeca (solar), icosa (cosmic). Colors and particles come from the image only; no element lore is implied. | gallery poster |
| REF_12 crystal seed → winged android (30 frames) | `CrystalSeed` shard cluster on the quantum table | 6×5 flipbook on a holo screen above the quantum table |
| REF_13 helix → Platonic frames (30 frames) | `HoloHelixFrame` (dodecahedron with a cyan helix) on the quantum table, and `HelixProgression` | 6×5 flipbook on the quantum-table holo grid |
| REF_14 nebula triangle module | `NebulaTriangleModule`: upright triangle, nebula-purple face, cyan glowing edges, gold corners | Texture on the triangle faces (check the UV split in Studio) + gallery poster |

The DNA wormhole helix keeps its gameplay pads. Its look is now a torus of distortion (ForceField and crystal rings with a gold core ring) around the cyan helix, with gold base pairs and gold pads.

The aqua workshop's undersea glass roof is still there as a part. In this look it is tinted dark so the star field shows through. That changes the mood from undersea to space, and Ryan may want to choose between the two (or keep both as places).

### Reference images and asset ids
Roblox only displays images that were uploaded to Roblox. No Open Cloud key is set up here, so **nothing has been uploaded**, and every slot in `src/shared/ImageAssets.luau` is empty. While a slot is empty, the game uses the procedural pieces above and logs which slots are empty at startup.

Files: `assets/refs/` holds the 14 references, downscaled to 1,024 px JPEG. Ryan's original PNGs are at `/workspace/gertech_shared_refs/visual_2026-11-14/` on the shared box. `assets/sheets/` holds the REF_12 and REF_13 flipbook sheets (6×5 frames of 168 px, 1008×840). `assets/sky/` holds the six generated star-dust skybox faces (512 px PNG). To rebuild them from the originals: `python3 tools/make_assets.py <folder with the PNGs>`.

**On GitHub the images are stored as base64 text** in `assets/encoded/`, with checksums in `MANIFEST.txt`. The tooling that pushes this repo only carries text. After cloning, run `python3 tools/unpack_assets.py` to restore the binary files. `tests/run.sh` does this for you.

Upload, option 1, Studio Asset Manager:
1. Open the place and go to View → Asset Manager → Images → Bulk Import.
2. Pick the files.
3. Right-click each one → Copy ID to Clipboard.
4. Paste the digits into the matching `assetId = ""`.

Upload, option 2, Creator Dashboard: go to Creations → Development Items → Decals → Upload Asset. A decal page id is not the image id. Studio resolves the image id when you paste the decal into an ImageLabel, so use the `rbxassetid://` value it shows.

Upload, option 3, Open Cloud: create an API key with Assets read/write, then for each file:
```bash
curl -X POST https://apis.roblox.com/assets/v1/assets -H "x-api-key: $ROBLOX_API_KEY" \
  -F 'request={"assetType":"Decal","displayName":"GERTECH_REF_01","description":"GERTECH reference (provisional)","creationContext":{"creator":{"userId":"<RYAN_USER_ID>"}}};type=application/json' \
  -F 'fileContent=@assets/refs/GERTECH_REF_01_fractal_vortex_spheres.jpg;type=image/jpeg'
```
The call returns an operation path. Poll `GET https://apis.roblox.com/assets/v1/<operation path>` with the same key until it reports `done: true`, then read the asset id from the response. Fill the slots:
- `ImageAssets.REFS.REF_xx`: south-wall gallery posters, and REF_14 on the triangle.
- `ImageAssets.SHEETS.REF_12` and `REF_13`: the quantum-table flipbooks, animated by the client through `ImageRectOffset`.
- `ImageAssets.SKY` (all six faces): the space skybox.

Uploaded images go through Roblox moderation. REF_12 shows a humanoid android figure, so expect a review.

## Architecture

```
ReplicatedStorage.Shared      (src/shared)   data + remotes, no game logic
  Config            tuning knobs
  ItemDefs          12 canon item keys + STARTER_STOCK (Godot world_seed.gd)
  TetrominoGrid     port of Godot core/tetris/tetromino_grid.gd (10×20, 7 pieces, lock, line clears)
  ForgeRules        Godot forge constants/formulas: materials, alloy, score, row outputs, scrap, gravity
  ForgeSession      port of Godot theme_foundry/forge_foundry.gd game logic (engine-free, RNG injected)
  ForgeFeed         feed sources: Godot fixed budget / whole-stock rolling hopper
  DecorGeometry     PROVISIONAL look pass geometry (engine-free primitive specs, REF_01..14)
  ImageAssets       empty asset-id slots for the reference images, flipbook sheets, sky faces
  RecipeDefs        non-forge recipes (visor chip upgrade)
  ProgressionDefs   PLACEHOLDER XP curve
  ResourceNodeDefs  intake-dock gatherables
  PlaceRegistry     universe places reached through the DNA wormhole helix
  AudioDefs         ambience slots
  Remotes           creates (server) / waits for (client) all RemoteEvents/Functions

ServerScriptService.Server    (src/server)
  Main.server       boot: build hub → apply look pass → start services → bind prompts → BindToClose
  HubBuilder        procedural map from Parts
  VisualStyle       PROVISIONAL look pass: lighting/sky, hub recolor, decor parts, image slots
  Services/
    StoreUtil                 DataStore retries + in-memory fallback
    DataService               per-player profile: session-locked UpdateAsync, autosave, release on leave
    WorkshopInventoryService  SHARED stock: one key per workshop, atomic spends, batched adds, MessagingService sync
    ForgeService              TETRAFORGE: server sim per session, input intents, snapshots, watchers, chamber mirror, feed hopper reserve/top-up/settle
    GatherService             resource nodes
    ExchangeService           visor chip upgrade
    LatticeService            WorldSeed-lite sockets
    PortalService             helix → TeleportService
    AmbienceService           sounds from AudioDefs
    RateLimiter               per-player token buckets

StarterPlayerScripts.Client   (src/client)
  Main.client       ScreenGui: XP bar, shared stock, TETRAFORGE panel, exchange, toasts
  UI/ForgeView      TETRAFORGE board ScreenGui: 10×20 grid, interpolated piece, next/hold, controls
  UI/Widgets        UI helpers
  DecorFx           look pass motion: decor spins, sprite-sheet flipbooks (visual only)
```

**Server authority.** The server owns the TETRAFORGE board, the piece RNG and the gravity tick, running `ForgeSession` on Heartbeat. The client sends only `ForgeStart()`, input intents through `ForgeInput(intent)` (`left`, `right`, `rotate`, `soft_on`/`soft_off`, `hard`, `hold`, `pause`/`resume`, `end`), `ForgeWatch(bool)` and `BuyUpgrade(id)`. Intents are whitelisted and rate-limited (30 burst, 20/s). Only the operator's intents count. The server sends board snapshots (a 200-character board string plus the active piece) at most 20 times a second to the operator and watchers. The client interpolates the falling piece between snapshots. Other server rules: one session per player and one chamber per station. A pause auto-resumes after 30 s. The run ends if the operator walks more than 40 studs from the console.

**TETRAFORGE material safety (whole shared stock, like Godot).** A run can use the whole workshop stock. Only a small rolling **feed hopper** is held out of the shared stock at a time: up to 40 ore, 40 salvage and 12 pure.
- **Start.** One atomic `UpdateAsync` moves the first hopper fill out of the stock and records it as the session's reservation, in the same write.
- **Choosing pieces.** Pieces are picked with Godot's `_choose_materials`. It sees the whole stock: unspent hopper plus the unreserved shared stock.
- **Spending.** A piece spends its 4 cells on lock, as in Godot, and always from the hopper. It only spawns once its cells are in the hopper, so no two players can spend the same ore.
- **Top-ups.** When any kind drops below its low mark (20/20/6), the server tops the hopper up with another atomic write. That write adds to the reservation and subtracts from the stock together, at most every 2 s. A piece whose cells haven't arrived waits (status `FEED HOPPER REFILLING`). The 2 s spacing respects the DataStore limit of one write per key every 6 s.
- **Everyone else.** Gathering, other stations and other servers keep using everything outside the hopper. Material gathered mid-run feeds the run too.
- **End of run.** Whatever the reason (quota, chamber full, hoppers empty, overflow, Backspace, leaving, walking off, server shutdown), one atomic write refunds the unspent hopper (including the active piece), adds the products and deletes the reservation. Settlement waits for any top-up still in flight.
- **Crashes.** While a run is live, its server heartbeats the reservation. Any other server refunds a reservation that hasn't been heartbeated for 5 minutes, in full. A late settle or top-up finds the reservation gone: the settle grants nothing, and the run ends with `FEED LINE LOST`. Materials are never duplicated or lost.

**Shared inventory concurrency.** Gathering and forge output pile up in a per-server `pending` delta, which is committed every 20 s or on the next transaction. Spends run the check and the subtraction inside `UpdateAsync`, against the freshest stored copy with the pending adds applied. After each commit the server publishes `{workshopId, revision}`, and other servers re-read. A periodic re-read covers dropped messages. If the store fails, pending adds are put back so nothing gathered is lost.

**Player saves.** `UpdateAsync` takes a session lock (`jobId`, `time`). A second server waits up to about 30 s, then takes over a lock that has gone stale. Saves never overwrite a lock another server owns. Autosave runs every 60 s. `PlayerRemoving` saves and releases the lock. `BindToClose` aborts running forge jobs (finished rows are kept, the rest becomes scrap), flushes the workshop and saves everyone in parallel.

## Checks
- `rojo build` succeeds.
- `selene src`: 0 errors, 0 warnings (Roblox std).
- `stylua --check src`
- `luau-compile` parses every file.
- `luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src` (Roblox API types, sourcemap from `rojo sourcemap`): 0 type errors.
- `bash tests/run.sh`: offline tests (9,263 checks). They cover the board port (shapes, rotation, fits, locking, single and four-row clears, overflow), Godot formulas (score, row outputs, scrap, gravity, alloy material choice), session behavior (spawn, gravity, hold, pause, hoppers-empty end, refunds), a scripted 8-row quota run, and 200 seeded random runs. The random runs check conservation, refund + spent = budget, and that the score matches the Godot formula. Hopper-feed tests:
  - 60 seeded runs play identically to a Godot whole-stock budget: same pieces, board, score and outputs. Every step checks that shared + hopper + spent = initial stock.
  - A run of more than 3,000 cells drains a large stock without the hopper ever holding more than its target.
  - A slow top-up makes the next piece wait. A stock drained by someone else ends the run cleanly.
  - Look pass:
    - Platonic solids: vertex and edge counts, equal edges, unit circumradius.
    - Decor: stays within the part budget, inside the hub and out of the keep-clear spots, and every reference has a stand-in.
    - Image slots: empty by default, asset-id validation, and every slot's file is present.

These are static checks plus engine-free tests. **This code hasn't been run in Roblox Studio yet.** The first Studio Play session is the next verification step.

## Roadmap
See [`docs/ROADMAP.md`](docs/ROADMAP.md) for the multi-place universe: mining, forge, assembly, hangar and expeditions, linked through TeleportService and the DNA wormhole helix.
