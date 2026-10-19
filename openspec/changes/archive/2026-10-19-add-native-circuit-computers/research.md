# Investigation, evidence and compatibility

Research date: 2026-10-14. Scope: source/documentation investigation and planning, not a working mod or engine benchmark. Exact repository revisions, selected file hashes and immutable Redis document URLs are in [research/source-manifest.json](research/source-manifest.json).

## Evidence inventory

| ID | Primary source | Pinned reference / inspected material |
| --- | --- | --- |
| R1 | `https://github.com/Relik77/factorio_computer_core` | `92e4ab616d385dfb0247ce2fc195c0e189b01efd`; metadata, control registration, computer runtime, API modules, commands and shipped examples |
| R2 | `https://lua-api.factorio.com/2.0.77/runtime-api.json` | application version 2.0.77, schema API version 6; full class/inheritance/concept/enum/event inventory |
| R3 | `https://lua-api.factorio.com/2.0.77/prototype-api.json` | application version 2.0.77, schema API version 6; circuit-capable entity, power, rendering/input and prototype candidates |
| R4 | `https://lua-api.factorio.com/2.0.77/auxiliary/libraries.html` and `.../storage.html` | Modified Lua environment, native loading and persistent storage restrictions |
| R5 | `https://github.com/cc-tweaked/CC-Tweaked` | `c8b3f6af270cd74c7494e2bf45a9f377b90c9b29`; monitor merging/resize implementation, palette, licenses and asset metadata; public monitor/peripheral docs also inspected |
| R6 | `https://github.com/redis/docs` | `46f775c33aefa6159a0027ab60f55dc76ed75a0f`; every selected command refetched at the immutable revision, not left as a moving main reference |
| R7 | `https://github.com/redis/redis` | `86b20b1b9e5f03d86db72c3d59bec432e471fbc9`, `src/expire.c`; exact TTL rounding reference |
| R8 | `https://github.com/BirbIrl/ComputerCraft-Greg-Flavored` | `ac6cafc3993c902e2ca95d85b501d3c7e172570c`; models, textures, rendered preview, README credits, license and casing variants |
| R9 | `https://github.com/JanSharp/phobos` | `2566dd85807b4f2bdff8e40ba4d79bcf8e96de3f`; parser/tokenizer/AST inventory, MIT license and Factorio support documentation |

Official public behavior references: `https://tweaked.cc/peripheral/monitor.html`, `https://tweaked.cc/module/peripheral.html`. These live pages are supporting references; pinned source is used where exact historical behavior matters. The selected Factorio version was explicitly confirmed rather than automatically choosing the experimental release.

## Computer Core: what is actually being remade

R1 is Computer Core 1.3.12 for Factorio 0.16, not a Factorio 2.x runtime. Its computer executes native Lua with callbacks. Deferred callbacks are dumped and later loaded; its terminal is text input/output, not a CC character-grid monitor. Its circuit I/O belongs to the computer entity, unlike the separate logic peripheral requested here.

| Legacy area observed in R1 | New design disposition |
| --- | --- |
| `os` identity/label, state-like tuples, deferred callbacks, time and library loading | Redesigned `computer` identity/state/named timers and simulation ticks; no legacy signatures or host clock/library loading |
| `term` text input/output and listener registration | Native editor/output pane for authoring/diagnostics; world terminal display is a monitor peripheral, not the old terminal API |
| `disk` file read/write/append/remove/existence | Explicitly excluded: one program document, no gameplay filesystem |
| `lan` left/right signal I/O and aliases | Moved to a separately authorized 3×1 logic handler with input/network/output roles |
| `wlan` listener/message/broadcast and built-computer notifications | Excluded; intercomputer communication uses native circuit signals via logic handlers |
| `speaker` chat/alerts/notes/instruments | Excluded from this first scope |
| Shell/file navigation, remote mounts, personal/portable computer behavior | Excluded; not required to introduce reactive code |
| `addComputerAPI` extension registration and lifecycle hooks | Excluded; no third-party guest-extension surface in v1 |
| Saved dumped callback functions | Replaced with source snapshots plus named registrations and explicit Data |

There is no promise that old scripts, saves, names, tuples or extension modules run unchanged. This is the user-confirmed API-inspired redesign, not a compatibility port. The new Lua contracts document the replacement surface rather than pretending CC:Tweaked or Computer Core is embedded.

## Factorio findings that constrain the architecture

### Native Lua and persistence (R4)

Factorio's Lua is based on a modified 5.2.1 environment. Native coroutine/io/os and loadfile/dofile facilities are unavailable; text load exists but binary chunks are refused. The exposed debug facilities do not provide a guest instruction-hook escape hatch. Therefore raw load/pcall alone does not establish safe execution of arbitrary loops, and the legacy callback-bytecode design cannot be transplanted unchanged.

Storage can retain plain data and supported engine objects but not functions. Its allowed load stage is not an opportunity to run player programs or mutate persistent state. Named handlers plus exact source snapshots address persistence only when reconstruction is side-effect-free and synchronized; they do not automatically establish sandbox safety or multiplayer correctness.

Phobos documents Factorio integration and text-load constraints (R9). That is evidence for investigating a reusable parser front end, not proof that its compiler is a safe native runtime. The plan uses AST validation/instrumentation and native text execution only; no Phobos bytecode/interpreter machinery or saved execution stack is authorized.

### Wiring and sampling (R2/R3)

`LuaWireConnector.real_connections` describes real wires between nonghost entities, and connector records identify their owner and connector role. This permits physical role/color-aware traversal. A passive endpoint and a per-link signal-isolating router are different things; the user selected passivity with normal native wire continuity.

A shared `network_id` is insufficient to authorize the mod-only discovery graph because native networks can include vanilla relays that discovery must ignore. Conversely, configurator targets intentionally include ordinary same-color native relays. These are separate traversal policies, not one graph with a flag added after lookup.

No suitable dedicated wire-change or circuit-signal-change event was identified in the pinned event inventory. Generic events help invalidate known lifecycle/UI paths but do not prove detection of every wire mutation by other mods. The plan therefore requires current path proof for calls and bounded periodic reconciliation for notifications and fail-safe cleanup.

`LuaCircuitNetwork.signals` documents previous-tick signals and nullable empty results. Signal values are signed 32-bit; signal identity includes quality as well as type/name. Modern constant-combinator output is section/filter based. These facts shape canonical snapshots, summed input semantics and observable subscription latency.

The fixed native connector roles do not prove that one prototype can supply three independent input/network/output sections. An owned composite is the selected candidate, with a dedicated engine/client gate. `ElectricEnergyInterfacePrototype` exposes an electric source, usage and directional pictures/animations, but inspection alone does not prove the proposed power carrier's final placement/GUI/lifecycle behavior.

### Configurator coverage (R2)

The generated catalogue includes 36 control-behavior classes, 164 effective writable field entries including inherited repetitions, 29 referenced concepts and 10 enum groups. These are mechanically derived inventory counts, not a claim of 36 craftable device types or completed adapters. Abstract/base classes are intentionally included for inheritance auditing.

The surface includes much more than enable/disable: circuit-controlled filters, conditions, hand/contents modes, arithmetic/decider/selector parameters, train limits/priorities, recipe/status controls, lamps, display messages, constant sections and expansion behaviors. Native entity modes still govern applicability.

`LuaLogisticSection` returns objects and supports shared groups. Exposing those objects or blindly editing a shared group's filters would defeat target-network confinement. The planned facade instead returns plain schemas/data, protects nonmanual sections, distinguishes assignment from shared-content mutation, and refuses writes outside proven target scope.

## CC-style monitors: retained behavior and deliberate differences (R5)

Retained behavior: rectangular tile groups; clipped rather than wrapped cell writes; cursor/blink; clearing and scrolling; text/background colors; blit; palettes; Color/Colour aliases; text scaling in half steps; resize and touch concepts. The pinned server monitor clears when character dimensions change, consistent with the confirmed resize policy.

Deliberate differences:

- Flat Factorio ground arrays, not Minecraft vertical block walls.
- New physical/logical identity and deterministic partition rules, not a port of the Java expander.
- Explicit red/green peripheral binding and named callbacks, not side names/modems or os.pullEvent.
- One color/touch tier; no CraftOS, terminal redirection or Unicode-terminal compatibility.
- Documented Factorio character geometry and an independently sourced ASCII/mosaic/replacement atlas, not the original font bitmaps.
- Limits selected from measured Factorio workloads rather than copying CC's physical defaults.

The initial palette values were checked against the pinned Colour enum. API data/behavior is a compatibility target; no original Java implementation is included in this planning package.

## Redis subset: exact behavior and differences (R6/R7)

Selected commands are get/set/del/exists/type; hget/hset/hdel/hexists/hgetall/hlen; expire/ttl/persist. Values and hash fields/values are strings; each physical peripheral owns a separate shared database. No numeric increments, conditional SET options, transactions, lists, field expiry or external Redis process is included.

SET replaces other types and removes expiry; HSET preserves expiry; deleting the last hash field removes the key. Missing GET/HGET returns nil; missing HGETALL returns an empty Lua map; wrong-type operations fail. DEL counts actual removals, whereas EXISTS counts supplied existing arguments, including repeated arguments. TTL uses -2 for missing and -1 for persistent.

R7 rounds a live millisecond TTL to the nearest second. The contract translates that behavior to simulation ticks, while explicitly changing the clock source: `expire` accepts integer simulation seconds and the stored deadline is absolute tick time. Pause/closed saves do not consume time; unpowered/mined devices do not stop an advancing simulation clock. Expiry is logically checked at every read, independent of bounded physical cleanup.

## Artwork investigation and distribution gate (R8/R5)

The requested pack's actual asset root is `resourcepack/refreshed/Computer Craft Greg Refreshed 1.20.1/`. Computer variants use case, case-pattern, face-overlay and glow textures; monitor models provide edge/corner arrangements. The inspected preview depicts a grey casing, recessed dark screen and cyan-lit face, but that promotional render is not a Factorio sprite sheet. Directional projection, shadows, port selection/wire alignment, tile seams and status sprites still require an actual art pipeline and client checks.

R8 has a root MIT license and explicitly credits original/modified textures/models from GregTech Refreshed, GregTech Modern, GregTech Programmer Art and CC:Tweaked. Those facts do not identify provenance for every selected layer. Upstream repository-level license checks are useful leads, not a per-file clearance manifest.

The inspected CCPL text in R5 expressly restricts use of its covered code/assets in mods for other games. Do not transplant a CCPL-covered font or model into this Factorio mod on the strength of the resource pack's root license. Identify the actual origin and permission for selected derivatives; unresolved material blocks distribution. This is a practical provenance gate, not a blanket assertion that every file in the requested pack is unusable. No converted textures or fonts are shipped by this planning change.

## Confirmed product decisions versus engineering proposals

Confirmed with the user: target/expansion matrix; redesigned rather than backward-compatible callback API; bounded native named handlers and explicit state; one in-game source document; passive same-color mod-only discovery; flat rectangular color/touch monitors; string/hash KV and simulation-time expiry; separate whole-network configurator targets with full pinned control coverage; mirrored combinator output; shared last-successful-write access; output fail-safe; one-tier footprints/electricity/base progression; mining and clone policy; resize clearing; no extra messaging.

Engineering proposals now documented for review: concrete API names/data shapes, graph witness strategy, composite component choice, monitor partition/anchor algorithm, character geometry/glyph mapping, strict source grammar and method-level error/admission rules. They are specifications for the new implementation, not observations of working code. Numeric balance/capacity/latency values remain measured/reviewed release outputs, not guessed performance promises.

## Verification boundary and mandatory gates

Completed research establishes source/API facts and a reviewable contract. It does not establish an executable sandbox, physical composite, renderer, native editor or configurator adapter. The task list carries explicit gates for:

1. Native compiled-source guard correctness and measured maximum useful workloads.
2. Real role-isolated physical entities and lifecycle in every rotation.
3. Real editor/save/run-to-factory behavior, not merely a bundled fixture.
4. Complete configurator setting coverage with actual applicable engine devices.
5. Cold save/load, configuration changes and multiplayer determinism without replay.
6. Native client display/input and supported-envelope latency.
7. Exact packaged artifact/license/provenance checks.

The planning validation report records only the checks actually executed for these documents. Lua 5.2 reference syntax checks do not certify Factorio's modified runtime or the planned restricted compiler.
