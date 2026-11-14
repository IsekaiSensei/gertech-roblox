# GERTECH — Roblox (Luau)

The Roblox build of Ryan's GERTECH multiplayer manufacturing game. You start in the **GERTECH Aqua Workshop hub**: gather raw feed at the intake docks, run it through the **TETRAFORGE** (the Tetris / Forge Foundry), and spend the output at the stock exchange and the WorldSeed lattice. Everyone on every server shares one **workshop inventory**. Your XP and unlocked recipes save between sessions.

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
| `src/client/UI/Widgets.luau` | `…› Client › UI` (Folder) | ModuleScript |

### Saving data (DataStores)
- **Published game:** saving works once the place is published.
- **Studio:** publish the place, then go to *Game Settings → Security* and turn on **Enable Studio Access to API Services**. If it's off, the server warns and switches to an **in-memory mock**: everything still plays, but nothing persists.
- Cross-server sync uses **MessagingService**, which only runs in live servers. In Studio, a single server works without it.

### Controls
- **E / hold E** on prompts: operate the TETRAFORGE, gather, trade, place or recover lattice modules, use the helix pads.
- **I**: toggle the shared stock panel. **Esc**: close panels.

## What's in the hub
| Station | What it does | Status |
|---|---|---|
| **TETRAFORGE** (operator console) | Pick a row composition and 1–8 rows. The server spends feed from the shared stock, runs a timer and returns the products. | Playable (timer adaptation of the Godot Tetris run) |
| Intake docks: **Dig Dog** ore seams, **Asteroids** salvage rocks, **Breakout** refined-parts bins | Hold to gather into the shared stock. Nodes deplete and regrow. | Playable (stand-in for minigames that aren't built yet) |
| **Stock Exchange** | 4 Packed Blocks + 1 Forged Blank → workshop Visor Chip capacity +1 | Playable (canon) |
| **WorldSeed lattice** (12 sockets, gold joints) | Place a Packed Block into a socket, or recover it 1:1. The core socket can't be recovered. | Playable (canon rules, placeholder size) |
| **DNA wormhole helix** + 5 destination pads | Teleports to the mining, forge, assembly, hangar and expeditions places once their PlaceIds are set. Until then it says the helix isn't stable yet. | Hook only |
| Coral growth vats, resin printer, 3D printer, arc welder, lathe, drill press, bench grinder, tool wall | Set dressing that shows parts being grown and assembled. *Inspect* prompts show lore text. | Scenery |
| **Quantum table** | Workbench with a tabletop virtual avatar and a micronized android. | Scenery (piloting planned) |
| Mouse Maze / Frogger / Space Invaders docks | Labeled offline, as in Godot. | Scenery |

Audio: `src/shared/AudioDefs.luau` has slots for workshop and electronics ambience plus a healing/ASMR tone layer. No sound assets ship with it. Paste `rbxassetid://` ids there.

## Architecture

```
ReplicatedStorage.Shared      (src/shared)   data + remotes, no game logic
  Config            tuning knobs
  ItemDefs          12 canon item keys + STARTER_STOCK (Godot world_seed.gd)
  RecipeDefs        TETRAFORGE row recipes + validator for the Godot row rules, score, scrap
  ProgressionDefs   PLACEHOLDER XP curve
  ResourceNodeDefs  intake-dock gatherables
  PlaceRegistry     universe places reached through the DNA wormhole helix
  AudioDefs         ambience slots
  Remotes           creates (server) / waits for (client) all RemoteEvents/Functions

ServerScriptService.Server    (src/server)
  Main.server       boot: validate recipes → build hub → start services → bind prompts → BindToClose
  HubBuilder        procedural map from Parts
  Services/
    StoreUtil                 DataStore retries + in-memory fallback
    DataService               per-player profile: session-locked UpdateAsync, autosave, release on leave
    WorkshopInventoryService  SHARED stock: one key per workshop, atomic spends, batched adds, MessagingService sync
    ForgeService              TETRAFORGE validation, timer, receipt, XP, abort → scrap
    GatherService             resource nodes
    ExchangeService           visor chip upgrade
    LatticeService            WorldSeed-lite sockets
    PortalService             helix → TeleportService
    AmbienceService           sounds from AudioDefs
    RateLimiter               per-player token buckets

StarterPlayerScripts.Client   (src/client)
  Main.client       ScreenGui: XP bar, shared stock, TETRAFORGE panel, exchange, toasts
  UI/Widgets        UI helpers
```

**Server authority.** The client only displays state and sends `StartCraft(recipeId, rows)`, `CancelCraft()` and `BuyUpgrade(id)`. The server checks: argument types, that rows is a whole number from 1 to 8, that the recipe exists and the player has unlocked it, distance to the station, one job per player, the console job cap, the alloy threshold, and stock. Spends happen atomically inside `UpdateAsync`, so two players, or two servers, can't spend the same ore. Every remote and prompt is rate-limited.

**Shared inventory concurrency.** Gathering and forge output pile up in a per-server `pending` delta, which is committed every 20 s or on the next transaction. Spends run the check and the subtraction inside `UpdateAsync`, against the freshest stored copy with the pending adds applied. After each commit the server publishes `{workshopId, revision}`, and other servers re-read. A periodic re-read covers dropped messages. If the store fails, pending adds are put back so nothing gathered is lost.

**Player saves.** `UpdateAsync` takes a session lock (`jobId`, `time`). A second server waits up to about 30 s, then takes over a lock that has gone stale. Saves never overwrite a lock another server owns. Autosave runs every 60 s. `PlayerRemoving` saves and releases the lock. `BindToClose` aborts running forge jobs (finished rows are kept, the rest becomes scrap), flushes the workshop and saves everyone in parallel.

## Checks
- `rojo build` succeeds.
- `selene src`: 0 errors, 0 warnings (Roblox std).
- `stylua --check src`
- `luau-compile` parses every file.
- `luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src` (Roblox API types, sourcemap from `rojo sourcemap`): 0 type errors.
- `./tests/run.sh`: offline tests for recipes, scoring, scrap, starter stock and the XP curve.

These are static checks plus engine-free tests. **This code hasn't been run in Roblox Studio yet.** The first Studio Play session is the next verification step.

## Roadmap
See [`docs/ROADMAP.md`](docs/ROADMAP.md) for the multi-place universe: mining, forge, assembly, hangar and expeditions, linked through TeleportService and the DNA wormhole helix.
