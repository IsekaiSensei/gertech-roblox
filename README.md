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
| **TETRAFORGE** (operator console + 10×20 chamber) | The real falling-block forge, ported from Godot. Pieces are made from ore, salvage and pure components reserved from the shared stock. Cleared rows crystallize into packed blocks, stabilized frames and forged blanks. A run ends at 8 rows. Leftover cells ÷ 5 become scrap. One operator at a time; anyone can watch, either in the panel or on the in-world chamber. | Playable (server-simulated) |
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
  TetrominoGrid     port of Godot core/tetris/tetromino_grid.gd (10×20, 7 pieces, lock, line clears)
  ForgeRules        Godot forge constants/formulas: materials, alloy, score, row outputs, scrap, gravity
  ForgeSession      port of Godot theme_foundry/forge_foundry.gd game logic (engine-free, RNG injected)
  RecipeDefs        non-forge recipes (visor chip upgrade)
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
    ForgeService              TETRAFORGE: server sim per session, input intents, snapshots, watchers, chamber mirror, reserve/settle
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
```

**Server authority.** The server owns the TETRAFORGE board, the piece RNG and the gravity tick, running `ForgeSession` on Heartbeat. The client sends only `ForgeStart()`, input intents through `ForgeInput(intent)` (`left`, `right`, `rotate`, `soft_on`/`soft_off`, `hard`, `hold`, `pause`/`resume`, `end`), `ForgeWatch(bool)` and `BuyUpgrade(id)`. Intents are whitelisted and rate-limited (30 burst, 20/s). Only the operator's intents count. The server sends board snapshots (a 200-character board string plus the active piece) at most 20 times a second to the operator and watchers. The client interpolates the falling piece between snapshots. Other server rules: one session per player and one chamber per station. A pause auto-resumes after 30 s. The run ends if the operator walks more than 40 studs from the console.

**TETRAFORGE material safety.** Starting a run reserves feed in one atomic `UpdateAsync`: min(stock, cap) of ore, salvage and pure. The caps are 120/56/16, the Godot starter stock. The same write records the reservation inside the workshop. When the run ends, for any reason (quota, chamber full, hoppers empty, overflow, Backspace, leaving, walking off, server shutdown), one atomic write does three things: refunds the unspent feed (including the active piece, which isn't locked yet), adds the products and deletes the reservation. While a run is live, its server heartbeats the reservation every 20 s. If a server crashes, any other server refunds a reservation that hasn't been heartbeated for 5 minutes, in full. A late settle finds the reservation gone and grants nothing. Materials are never duplicated, and they're only lost if they were locked into a run that never settled. In that case the full refund returns them too.

**Shared inventory concurrency.** Gathering and forge output pile up in a per-server `pending` delta, which is committed every 20 s or on the next transaction. Spends run the check and the subtraction inside `UpdateAsync`, against the freshest stored copy with the pending adds applied. After each commit the server publishes `{workshopId, revision}`, and other servers re-read. A periodic re-read covers dropped messages. If the store fails, pending adds are put back so nothing gathered is lost.

**Player saves.** `UpdateAsync` takes a session lock (`jobId`, `time`). A second server waits up to about 30 s, then takes over a lock that has gone stale. Saves never overwrite a lock another server owns. Autosave runs every 60 s. `PlayerRemoving` saves and releases the lock. `BindToClose` aborts running forge jobs (finished rows are kept, the rest becomes scrap), flushes the workshop and saves everyone in parallel.

## Checks
- `rojo build` succeeds.
- `selene src`: 0 errors, 0 warnings (Roblox std).
- `stylua --check src`
- `luau-compile` parses every file.
- `luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src` (Roblox API types, sourcemap from `rojo sourcemap`): 0 type errors.
- `bash tests/run.sh`: offline tests (2,938 checks). They cover the board port (shapes, rotation, fits, locking, single and four-row clears, overflow), Godot formulas (score, row outputs, scrap, gravity, alloy material choice), session behavior (spawn, gravity, hold, pause, hoppers-empty end, refunds), a scripted 8-row quota run, and 200 seeded random runs. The random runs check conservation, refund + spent = budget, and that the score matches the Godot formula.

These are static checks plus engine-free tests. **This code hasn't been run in Roblox Studio yet.** The first Studio Play session is the next verification step.

## Roadmap
See [`docs/ROADMAP.md`](docs/ROADMAP.md) for the multi-place universe: mining, forge, assembly, hangar and expeditions, linked through TeleportService and the DNA wormhole helix.
