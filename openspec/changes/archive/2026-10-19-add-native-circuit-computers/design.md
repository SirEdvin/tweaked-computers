# Design

## Context

See [proposal.md](proposal.md) for motivation and capability scope. This is a greenfield repository: there is no production runtime or compatibility burden to preserve. The target is Factorio 2.0.77 with base-only and optional Space Age installations. The investigation used pinned source, runtime/prototype schemas and auxiliary lifecycle documentation; [research.md](research.md) records evidence and its limits.

The defining constraints are native callbacks with explicit durable state, one editor document, same-color mod-only peripheral discovery, separate native factory circuits, and no extra computer-messaging layer. Confirmed detailed choices include shared peripherals, a single mirrored output bank, signal fail-safe cleanup, Redis-style strings/hashes, color/touch monitors, full pinned circuit-control configuration, and the mining/clone policies in the capability contracts.

## Goals / Non-Goals

Goals:

- Make every factory effect traceable to an authorized device, run and synchronous API operation.
- Keep source, plain durable application data and ephemeral executable functions separate.
- Reuse native Factorio wiring, signal propagation, GUI and save machinery without exposing host objects to guest programs.
- Deliver useful end-to-end milestones before broadening into every configuration adapter or polish task.
- Establish real engine/client acceptance for bounds, lifecycle, visuals and multiplayer before release.

Non-goals:

- No suspended guest stack, bytecode interpreter, continuation machine, OS, filesystem or legacy-script loader.
- No arbitrary Factorio property forwarding, remote interfaces, new messaging protocol or third-party guest extension registry.
- No claim that work-unit caps prove real-time latency, that headless tests prove client usability, or that a repository license clears every credited texture.

## Decisions

### 1. A small set of owned modules, not a framework

Proposed implementation homes, to be created during apply rather than this planning change:

```text
info.json, data.lua, control.lua, settings.lua
prototypes/       devices, items, recipes, technology, custom-input
scripts/
  registry.lua    public identities, owner/child associations, schema version
  lifecycle.lua   placement, rotation, mining, clones, power, recovery
  network.lua     permitted discovery graph and separate target traversal
  scheduler.lua   clocks, queues, timers, round-robin, shared budgets
  runtime/        parser integration, subset validator, emitter, guards
  services/       computer, peripheral, monitor, kv, logic, configurator
  configuration/  normalized schemas and behavior-specific native adapters
  ui/             editor, help, diagnostics and player recovery drafts
  rendering.lua   dirty monitor presentation and interaction transform
vendor/           only reviewed pinned parser dependencies and notices
assets/           source provenance, derived sprites and independent glyphs
locale/en/
tests/            pure contracts, packaged-engine scenarios, client checklist
```

Share validation/copying, identity lookup and authority admission rather than duplicating them in each service. Keep native setting differences in small behavior adapters. Avoid a generic plugin bus or persistence framework before a second concrete need exists.

### 2. Compile a bounded subset into native Lua

Use a pinned, reviewed parser front end (Phobos is the investigated MIT candidate) for syntax/AST understanding, not its bytecode compiler or an emulated execution backend. Default-deny unsupported syntax, validate lexical bindings and the named-function inventory, instrument accepted AST nodes, and emit Lua text with original-source locations. Native `load` executes only this validated output under a closed environment. Import trusted implementation modules during control-stage parsing, not inside a guest callback.

The complete accepted language and mandatory guards live in [api/native-language.md](api/native-language.md). Preserve direct Lua evaluation, ordinary calls/returns and lexical locals; instrumentation checks work/allocation/depth and wraps input-dependent operations. It must not transform the program into durable stack frames or a resumable instruction dispatcher. A callback finishes or faults.

Each dispatch obtains fresh functions/environment. Only explicit state, named registrations and scalar/data event records cross callback boundaries. A cached compiled factory may be reused ephemerally, but neither its presence nor reconstruction may change admission costs or authoritative state. Store the exact active source/compiler/API version separately from the saved editor revision.

A private fatal guard signal poisons the run. Protected guest pcall rethrows it; effect boundaries recheck the poison even if an ordinary Lua error path behaves unexpectedly. Protected namespaces, wrappers, string operations and table helpers cannot reveal host metatables, objects, unmetered native methods or table addresses. Maximum useful accepted source and maximum helper amplification must fit measured cold and warm envelopes.

Alternatives rejected: raw load/pcall cannot preempt arbitrary loops; saved functions are not persistable; replaying initializers repeats effects; a VM would contradict the selected execution boundary. If instrumentation cannot satisfy the safety/latency gate, stop and revisit the design with the user—do not quietly substitute a VM or remove player programs.

### 3. Plain authoritative state; executable caches are disposable

A versioned storage root owns records for entities, computers, databases, logical displays, output ownership, registrations, timers, queues, scheduler cursors/budgets and player drafts. Host entity references may be retained only in implementation registries; guest data never includes them. Computer application state uses the deliberately narrower acyclic Data contract.

`on_load` only reconnects allowed host references/event wiring. It does not run user code, change queues/counters or initialize a computer. On the next synchronized dispatch, validate the retained header, admit reconstruction and rebuild the native callable cache from the retained active source. Ordinary load never enqueues start or power-restored merely because the executable cache is empty.

Store accepted service effects before returning from each API operation. There is no callback-wide transaction: a later fault retains earlier KV/configuration/display changes, while independent host cleanup clears still-owned logic output. Durable byte/node ledgers must account for serialization metadata as well as content. Unsupported schema/compiler versions retain source and data for recovery and halt only affected computers.

### 4. One scheduler and explicit maintenance capacity

Use the ordering in [api/common.md](api/common.md): lifecycle/revocation, once-per-tick input sampling, timer/notification advancement, fair FIFO callback dispatch, bounded rendering/maintenance. Persist the round-robin cursor, sequence numbers and spent credits keyed by the real simulation tick. Removing/re-adding a run or reloading the same tick cannot renew credits.

Reserve safety maintenance within one total supported host-work envelope; it is independent of a malicious guest's remaining credits, not an unbounded extra budget. Admission limits cover active computers, sampled logic handlers, total subscriptions and owned outputs, as well as per-device data. If a world exceeds the active envelope, preserve placed devices/data but refuse new activation/services explicitly rather than silently lowering sampling frequency.

Once-per-tick subscriptions compare canonical full-identity snapshots. Normal operation queues every observed change; bounded overflow faults the affected run and clears its owned output instead of fabricating a complete history. Brownouts suspend callbacks, discard obsolete transient events, retain registrations/timers and resynchronize current input on restoration. Recurring overdue timers coalesce according to their API contract, never into an unbounded burst.

Alternative rejected: an on_tick callback per computer without shared admission makes aggregate cost unbounded and can starve unrelated work. An instruction counter alone also omits source compilation, copying, native queries and rendering.

### 5. Physical ports are owned components

Implement each device as one logical body with explicit role ownership. The prototype candidate is an electrically powered body and owned circuit-capable endpoint helpers: passive empty endpoints for network/input/target roles and a controlled constant-combinator endpoint for output. An electric-energy-interface body is a candidate power carrier, not a claim of proven prototype behavior. All owned components participate in one placement/removal/rotation transaction and produce one logical item.

```text
logic handler, horizontal view:
+---------+---------+---------+
| INPUT   | NETWORK | OUTPUT  |
| red/grn | red/grn | red/grn |
+---------+---------+---------+

configurator, horizontal view:
+---------+---------+
| NETWORK | TARGETS |
| red/grn | red/grn |
+---------+---------+
```

Native prototype connector roles do not by themselves provide the required three independent interfaces. A composite is preferred over connecting role endpoints internally or overloading wire color as a port selector. The physical prototype gate must prove wire selection, power demand, collision/selection boxes, native wire endpoints, cardinal rotations, robots, blueprints and cleanup before the approach is considered accepted.

The middle network role neither reads nor emits signal data. Native wires sharing that connector may retain ordinary native continuity, as confirmed by the user. Do not delete unsupported player wires. Hide/protect implementation helpers from configurator mutation; target-side inspection may describe a public body as protected.

### 6. Two graph policies, never one global network ID

Represent vertices as actual connector identities with entity generation, role, force, surface and color. Walk only real physical wire edges.

- Peripheral discovery allows only this mod's computer-network-role vertices. Red and green are independent graphs. A merged monitor contributes an endpoint for each physically wired member but no implicit edge between members.
- Configurator target traversal permits ordinary factory relay entities on the selected color, following actual connector connectivity. It does not jump between isolated input/output connectors, surfaces, forces or wireless signal-transport facilities.

A native circuit network ID is useful observation metadata, not authorization: native continuity may include disallowed discovery relays. Initial full enumeration must finish within bounded capacity to publish a complete inventory. An incomplete traversal returns a pending/limit error, never an apparently complete prefix.

Cache topology for scheduling/events, but revalidate a current witness path before every device call. Check each live edge, connector role, owner, force and surface; a stale graph epoch alone is insufficient because other mods can alter wires without a dedicated wire-change event. A broken witness can trigger a bounded alternate-path search; if proof cannot be completed, refuse. Periodic bounded reconciliation supplies attachment/detachment events and output cleanup latency. Owners whose current authority cannot be proven are handled fail-closed.

Alternative rejected: merging red and green graphs through each device directly violates the user's correction. Strict per-link electrical isolation is unnecessary and was not selected.

### 7. Monitor grouping, identity and model are separate

On geometry/force/orientation changes, collect the bounded affected compatible tile component. A complete within-limit rectangular component becomes one group. Otherwise partition deterministically: repeatedly take the unassigned tile smallest by world `(y,x,stable_tile_id)`, choose the largest complete unassigned rectangle anchored there that satisfies tile/cell limits, break equal-area ties by width then height, assign it and repeat. Enumeration is bounded by the accepted component size; no unbounded search is hidden behind rendering.

Retain an old identity only in the resulting rectangle containing its anchor. If several old anchors merge into one rectangle, the smallest stable anchor ID wins; absorbed identities detach. Split rectangles without a surviving anchor get new identities and inherit their predecessor's display settings. A removed anchor never retargets an unrelated display. Group origin and anchor identity are different concepts.

The plain terminal model stores cells, palette, cursor, scale and revisions independently from world draw objects. Resize clearing and geometry are fixed in the monitor API. Render only changed cells/runs/palette entries and track the exact model revision at the beginning of a sweep; never call a mixed-revision sweep current. Group power requires all member tiles powered; outages blank presentation without changing grouping or erasing the buffer.

Use tinted independently licensed/generated glyph sprites plus bounded background runs. Do not interpret guest strings as Factorio rich text or import the original restricted CC font. The glyph manifest records the supported byte slots and independent provenance. World touch uses the same transform as rendering, actual cursor world coordinates and a rebindable activation action, with authority/GUI-hover checks. Client tests, not table-backed input mocks, decide whether native activation is usable.

Alternative rejected: treating all contiguous tiles as one screen produces holes/L-shaped coordinates and hidden cable bridges. Rendering every cell every tick wastes the shared envelope. A GUI-only substitute would not meet the requested in-world display.

### 8. KV is a local deterministic service, not embedded Redis

Use a key table with explicit string/hash tags, optional absolute expiry tick, bounded content accounting and a deterministic expiry index. Reuse one immutable value/snapshot where safe internally; guest readback remains copied. Check logical expiration on every command regardless of sweep position. Stage command changes and final capacity before publishing; a variadic command is the atomic boundary.

Maintenance reclaims expired values within its reserved capacity. If live-capacity accounting cannot be established without finishing deferred reclamation, return E_BUSY rather than falsely claiming expired content is live or granting an unsafe write. Snapshot metadata has reserved space so a maximum accepted database can always be saved/mined.

The expiry rounding and minimal command set are explicit in the API. Do not import a server library, wall-clock TTL mechanism, numerical increment or broader Redis protocol merely for familiar names.

### 9. Logic ownership is one complete output bank

Canonical input/output records use full signal type/name/quality and signed-32-bit counts. One bank supplies the same contribution on both output connectors through modern constant-combinator sections. Other native contributors are not included in getOutput.

A successful whole-bank replacement records computer ID, active run generation and discovery color. Retiring a run clears only banks still owned by that exact writer generation; an older writer cannot clear a newer writer's bank. Cleanup must function even if the run's source/state is malformed or compilation fails. All factory effects use actual engine propagation timing; subscriptions are observations of native snapshots, not instantaneous combinational callbacks.

### 10. Configurator coverage is generated; adapters remain deliberate

The pinned [configuration catalogue](specs/device-configurator/configuration-catalog.md) is the coverage oracle, not a dynamic property-forwarding implementation. Generate/freeze normalized schema data from the pinned field/concept/enum inventory, then implement small native behavior adapters with explicit setter ordering and mode invariants. Enumerate unsupported devices as metadata rather than hiding them.

Separate values, unset fields and read-only observations. Convert allowed prototype-object unions to names; never expose actual objects. Validate every patch field, target identity/path, capacity and inter-field dependency before native mutation. Snapshot affected target fields, perform deterministic setters, then read back the exact target. If an unexpected native failure occurs, attempt target-local restoration and retain an explicit recovery record if restoration fails. Native notifications or other mods may observe/interfere with setters; there is no claim of a global transaction or rollback of third-party effects.

Constant-combinator sections need collection operations, not a fake writable sections property. Native indexes can shift. Shared group content changes can affect entities outside the target network, so default to refusal unless membership closure is proven; offer explicit local detachment preserving effective values. Assignment to a group is distinct from editing its shared contents.

Alternative rejected: a universal `entity[property]=value` bridge would expose noncircuit controls, objects, incompatible fields and uncontrolled shared effects. Supporting only enable/disable would contradict the user's explicit full-surface choice.

### 11. Authoring and data movement use explicit boundaries

Use Factorio native multiline text entry with visible Save, Validate, Run/Apply, Stop, Reset State and help. A source revision check prevents silent overwrites by another player. Save never activates. Run validates first and only then replaces the active generation. Recovery drafts are per-player, bounded and separate from the device's committed source. Essential actions remain buttons even if native text focus suppresses custom shortcuts.

Mining serializes committed source/state or database content/deadlines into a bounded data-bearing item, not executable callbacks. Blueprints/clones copy source/settings only and start stopped; source inclusion is visible to the player. Wire/role mapping must survive a real blueprint/revival path, not only a synthetic registry clone. The lifecycle API matrix is authoritative for each transition.

### 12. Artwork is a provenance-gated pipeline

Start from the requested Greg Flavored computer/monitor models and their case/pattern/overlay/glow texture inputs. Prefer one visually coherent casing family; derivative variants for KV/logic/configurator keep recognizable device and port cues. Create Factorio-oriented directions, shadows, powered states and item icons through a reproducible transformation workflow.

Retain per-file upstream revision/path, original bytes/hash, applicable notice/permission evidence, transformation and output hashes. Credits to other packs mean the root MIT label alone is not sufficient asset evidence. CCPL-covered original CC material is not a permitted shortcut for a Factorio release. Hold affected distribution until provenance/permission is resolved; do not silently substitute an unrelated art direction. The glyph atlas is independent of these block textures and also requires documented provenance.

## Risks / Trade-offs

- [Native guards or synchronous compilation miss an unbounded path] -> Gate the actual accepted subset with adversarial compiled-source tests and maximum useful workloads in the pinned engine; no fallback interpreter.
- [Composite endpoint/body behavior differs from schema expectations] -> Prove the smallest real three-role and two-role devices in all rotations before peripheral implementation expands.
- [Polling and per-call path proofs become expensive] -> Bound admitted graph sizes and active devices, retain verified witnesses, reserve revocation capacity and measure real-tick worst cases.
- [World monitor rendering is too expensive or text is illegible] -> Use dirty rendering, measured group/cell caps, independent atlas and real-client zoom/interaction tests; do not replace the world display with a hidden GUI.
- [Full configurator surface is larger than examples suggest] -> Mechanically compare every inherited setting and nested concept against the catalogue; table-driven fixtures plus actual applicable engine entities are required.
- [Shared native groups or third-party native notifications escape local update assumptions] -> Enforce shared-scope refusal and explicit target-local recovery; never promise external rollback.
- [Power/recipe/limit numbers are falsely precise] -> Treat them as tuning outputs, freeze and publish them only after supported workloads pass; preserve already accepted user data during later limit changes.
- [Asset provenance cannot be demonstrated] -> Distribution gate and explicit maintainer permission/provenance work, not an assumed blanket relicensing.

## Migration Plan

This first release does not import Computer Core programs or saves. Use a versioned new mod/storage namespace and independent entity identities. During development, test configuration-change migration separately from ordinary save/load. Future incompatible formats preserve source/data inertly and expose a recoverable stopped state; they never reset silently.

Build one deterministic mod archive and run the base/expansion, cold-load, client and multiplayer matrices against those exact bytes. Keep development fixtures/logs/screenshots outside the repository. Publish only after all release gates and asset notices pass. Rollback of a schema-changing release requires the pre-upgrade save and matching previous archive; do not claim downgrading arbitrary newer state is safe.

## Open Questions

Only tuning/production details remain deferrable without changing the selected architecture: concrete recipes/research costs/power demand, measured capacity and latency numbers, exact directional sprite presentation, independent font styling and a mod display name. These require recorded review before release. Failed feasibility gates are not permission to change native execution, topology, requested art provenance or peripheral scope; such a failure requires returning to the user with evidence.
