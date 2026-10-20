# Design

## Context

See `proposal.md` for motivation and confirmed gameplay choices. This is a planning-only design; no runtime, prototype or native-client behavior described as new below has been implemented or exercised.

Source inspection establishes the following integration constraints:

- `info.json` pins `base = 2.0.77` and optional `space-age = 2.0.77`. The installed engine's prototype/runtime JSON identifies the same version.
- `scripts/device-definitions.lua` and `prototypes/devices.lua` describe six authored composite devices. The prototype loop creates constant-combinator shells and private electricity carriers. Appending vanilla radar to that loop would create the wrong entity type, power behavior and assets.
- `scripts/lifecycle.lua` currently calls combinator-only control behavior, normalizes private power buffers, upgrades non-layout-2 bodies and can destroy/refund a failed placement. `scripts/device-art.lua` assumes authored `tc-status-*` sprites. None of those paths is safe for a vanilla radar without an explicit native-carrier branch.
- `scripts/registry.lua` already provides opaque non-reused identities and exact entity ownership. `scripts/network.lua` proves same-force/surface physical connectivity, but `real_edges` presently admits all real wire origins. `validate_witness` uses the same primitive. `scripts/services/peripheral.lua` has a closed type registry, per-call authorization, shared device state, sorted attachment events and provider metadata hooks, but its base metadata construction assumes a thin composite footprint.
- `scripts/runtime/computer.lua` has an allowlist of general events, named subscriptions and durable bounded queues. `emit` is synchronous enqueueing, not recursive execution. `scripts/scheduler.lua` dispatches FIFO events fairly and persists admission ledgers; `runtime.set_power` already discards transient queued events on computer outage.
- The installed vanilla radar prototype uses its own native connectors, a 3×3 selection footprint, 300 kW electric usage and a rotating sprite. The pinned `RadarPrototype.connects_to_other_radars` documentation explicitly describes hidden wires with `defines.wire_origin.radars`; real wire enumeration is not sufficient to distinguish them from local attachment.
- `tests/network_engine.lua` covers actual connectors, same-color graphs, ghosts, other forces, stale wrappers and cold phases. `tests/api_inventory.lua` asserts exact public method inventories. `tools/smoke.py` and `control.lua` have explicit production-context fixture allowlists. `tools/player_docs.py` generates/checks player documentation and executable examples.
- The separate unimplemented `add-peripheral-inspectors` proposal is present. Preserve it and its changes. Radar native opening remains outside its current family list; neither change must require the other to implement first.

Primary references consulted: CC:Tweaked's public modem and modem-message documentation, plus the installed version-pinned Factorio documentation and prototype source. The CC API informs names/channel semantics, not a promise of full runtime compatibility:

- `https://tweaked.cc/peripheral/modem.html`
- `https://tweaked.cc/event/modem_message.html`
- `gameitself/base-2.0.77/factorio/doc-html/runtime-api.json`: `LuaWireConnector`, `LuaEntity`.
- `gameitself/base-2.0.77/factorio/doc-html/prototype-api.json`: `RadarPrototype`.
- `gameitself/base-2.0.77/factorio/data/base/prototypes/entity/entities.lua`: native radar definition.
- `gameitself/space-age-2.0.77/factorio/data/base/prototypes/technology.lua`: exact production, utility and space-science technology identifiers.

No game distribution or copied game asset belongs in the mod archive or git.

## Goals / Non-Goals

Goals:

- Add a narrow native-radar lifecycle adapter and one modem provider, reusing existing identities, authority, data validation, subscriptions and queues.
- Keep native circuit signal transport, local peripheral discovery and guest modem messages as three separate mechanisms.
- Use bounded synchronous prepare/publish routing, so payload errors or incomplete proof cannot publish a prefix and no new durable packet scheduler is needed.
- Make save/load, existing-radar adoption, force changes and queue overflow explicit rather than accidental consequences of generic device code.

Non-goals:

- No remote peripheral bridge, wired-modem API, rednet, routing daemon, packet ACK/retry layer, encryption, CraftOS, suspended handlers or new program execution model.
- No wholesale lifecycle/plugin framework, third-party radar compatibility registry, new dependency, fleet-wide every-tick entity scan or change to six-device artwork.
- No dedicated radar inspector or blanket replacement of native radar controls. No release or publication in the planning workflow.

## Decisions

### 1. Separate native carriers from generated composite devices

Introduce a focused host-only radar lifecycle module, proposed as `scripts/radar.lua`, and a modem provider, proposed as `scripts/services/modem.lua`. These are new files, not existing APIs. Track supported native entity names separately from `defs.order`; use one internal radar kind plus a tier field, with public type `modem`.

Keep ordinary radar data-stage definitions untouched. The new adapter registers the existing body in the current registry with an explicit native-radar carrier marker, without pretending it is a legacy composite or layout-2 shell. It owns no children and does not invoke combinator disabling, private power normalization, shell migration, refund/destroy-on-failure or Service Rack status rendering.

Compose native lifecycle dispatch into the existing event owner in `control.lua`/`lifecycle.lua`; do not register a second handler for the same Factorio event and accidentally replace the first. Add a narrow native branch to common connector/power/metadata access where required. The native connector remains the radar body's own red/green connector. Current identity, exact entity, force/surface and connector checks remain mandatory; radar animation orientation is not a reason to require composite-shell rotation machinery.

A native radar is operational for modem calls when its exact live entity is active and has positive buffered electrical energy. Read native state; never write its consumption, active flag or buffer. Document that the same `E_UNPOWERED` availability error also covers native inactivity, such as freezing or script disablement. Low supply can cause availability to vary by tick. Discovery does not depend on this operational state.

Generic presentation, blueprint, lifecycle and removal loops must explicitly skip unsupported composite operations for the new carrier. Metadata construction must support native footprint and tier before attempting `defs.devices[rec.kind]`; the provider's post-processing hook alone cannot fix an earlier nil dereference.

Alternative rejected: clone/replace the player's ordinary radar with a hidden modem shell. That changes native behavior, jeopardizes saved wires and item identity, and violates the requested vanilla-radar integration.

### 2. Adopt existing radars from bounded physical graph frontiers

Use lifecycle events for new radars and a fair synchronized reconciliation pass over registered local network connectors for radars that predate installation or were created without a raised build event. Encountering a supported unregistered radar over a real non-radar-origin wire schedules/adopts that exact entity under the existing bounded registry policy. Newly adopted radar connectors become further local frontier vertices; hidden native radio links never seed adoption.

This connected-frontier approach makes all physically usable existing radars available without scanning every generated chunk or registering every unrelated radar in a large world. An unwired existing radar needs no modem state until it becomes physically attached. Until adoption completes, discovery that encounters it returns `E_NETWORK_PENDING`, not a successful inventory omitting it. Exhausted identity capacity is an explicit capacity diagnostic; it cannot destroy or refund the radar. Persist bounded cursors/work items as plain host state and exact native references, not saved iterator functions. Charge native edge counts before array materialization and bound retained work.

Adoption is idempotent by exact registry ownership. Initialize new root fields in synchronized initialization/configuration stages and resume work on ticks. No `on_load` mutations or world rebuild. Reconcile normal removals, native invalidation without events, scope changes and same-position replacements through the same identity checks.

Alternative rejected: enumerate all radars on every surface on each tick or first transmission. Even if a result array is sliced afterward, the native lookup/allocation was already unbounded.

### 3. Physical paths explicitly reject hidden radar links

Extend discovery vertex policy only for supported, registered native radar connectors. Permit a radar to relay real local same-color physical wires; red and green stay independent. Exclude `defines.wire_origin.radars` edges in both fresh discovery and witness revalidation, while preserving supported player/script-origin real wires and all existing force/surface/role/ghost rules.

Keep counting/admitting native connection inventory before materializing it. Hidden edges still cost work to inspect and can trigger the declared native-edge inventory limit; do not materialize an unlimited array and then claim a small filtered graph was cheap. The pinned connector API has no bulk origin-filtered enumeration. A crowded native radar graph therefore has a documented capacity boundary, not silently unlimited support.

The shared `real_edges` primitive also serves configurator target traversal. Keep the discovery-origin policy at the correct boundary instead of silently changing unrelated configurator/native-wire snapshot behavior. Native circuit signals and hidden links themselves are retained. Tests must include powered actual-engine radars after the engine has formed its hidden connections, not only a hand-injected mock edge.

Alternative rejected: authorize by native circuit-network ID or radar shared signal network. Those connect remote radar endpoints and would expose databases/configurators without the user's local wire path.

### 4. Shared physical channels and callback-based compatibility

Implement the exact methods/events in `specs/radar-modem/lua-api.md`. Numeric channels are distinct from discovery wires. Store a versioned channel set/count with the radar record, using validated numeric host keys or a bounded deterministic representation. Allow 128 channels in the 0–65535 domain.

The channel set is shared across authorized computers, wire colors and Console calls, consistent with the existing shared-peripheral contract. There are no per-run channel leases. A stopped program loses its subscriptions/queue but does not close channels for another computer. Clone/blueprint/mine replacement starts empty; native force/surface reassignment clears channels and revokes old bindings. A same-scope outage retains channels.

Add `modem_message` to the existing general-event allowlist; saved programs register with `computer.on`. Both-color receive deduplication follows the monitor event convention (`wires`, canonical `wire`), but events are distinct per receiving radar. Console can configure/transmit synchronously; it gains no receive loop or background subscription. Add tier metadata to `peripheral.describe`; do not invent an additional non-CC modem method solely to identify the upgrade.

Alternative rejected: copy `os.pullEvent` or maintain independent per-wrapper listening sets. The first conflicts with the callback runtime; the second makes shared radar state unexpectedly depend on a wrapper or color and complicates teardown without a product requirement.

### 5. Bounded two-phase broadcast into existing queues

Use synchronous routing within the admitted call, with all possible fallible payload/proof/copy work before publication. Do not create a durable outbox or a per-radar tick handler.

Preparation:

1. Prove the sending wrapper's current local identity, power and authority through the existing peripheral service boundary. Validate exact argument count, channels and payload; explicit nil is handled outside ordinary nonnil Data.
2. Enumerate bounded registered receiving radar candidates with open channel, live native availability, exact force and appropriate surface/tier. Exclude the transmitting physical radar. This is a bounded registry walk, not a surface entity search.
3. Examine bounded running, powered computers of the eligible force/surfaces with `modem_message` subscriptions. Prove complete red/green local inventories using existing discovery, intersect with candidates and deduplicate receiver identity across colors. A potentially eligible subscribed computer with an incomplete relevant graph refuses the entire send before publication; caches cannot silently omit it. No subscribed destinations/no open candidates is a successful no-op.
4. Build the bounded delivery list sorted by computer ID, receiver ID and subscription sequence. Calculate receive-time wires and same-surface distance. Validate complete event-envelope capacity, and precharge all copies, queue work and overflow-cleanup worst cases. Count actual handler deliveries rather than just computers. Enforce finite per-computer and aggregate per-tick transmission limits shared by saved programs and Console.
5. Retain only defensive prepared event values and current identities needed for immediate publication. No guest callback can run or mutate topology between this preparation and publication.

Publication:

- Commit accepted-transmission accounting once and enqueue in the prepared order through existing queue semantics. Refactor a small trusted prepare/enqueue helper only if necessary to avoid double-copy undercharging; do not redesign the scheduler or broaden its guest API.
- Queue overflow visibly faults that recipient through the existing runtime path. Do not enqueue later plan entries to the now-retired run; continue other recipients. Do not raise a retryable sender failure after publishing to others.
- Receipt is queue admission. Later channel close or radar detach does not retract accepted data. Current receiver computer stop/fault/power/scope policies can discard its transient queue normally. A packet confers no future device authority.

Existing event sequence numbers and saved queues provide reload durability; only the per-tick transport counters need new durable admission fields. Preserve spent counters when re-entering the same tick or alternating Console and program access. Keep the native-origin filtering and candidate ordering deterministic on all peers.

Alternative rejected: immediately emit to each discovered recipient while still validating later recipients. A caught error could otherwise leave an undisclosed prefix and a retry would duplicate it. A retained asynchronous outbox is also unnecessary for this first bounded datagram transport.

### 6. Optional advanced prototype and practical geometry

Add a dedicated data module, proposed as `prototypes/radar.lua`, loaded from `data.lua`. Guard advanced entity, item, recipe and technology creation with `mods["space-age"]`. Use the existing optional dependency; base-only loads must have no dangling advanced references.

Deep-copy the installed vanilla radar prototype for `tc-interplanetary-radar` without mutating the source. Keep its radar scanning and native same-surface circuit behavior; modem interplanetary messages remain independent of those native signals. Reuse native asset references and scale all applicable body/shadow/integration/reflection shifts and scales consistently. A 3-tile vanilla width at 1.5× is 4.5 tiles; choose a 5×5 whole-tile footprint with aligned selection/collision and appropriately scaled connector positions. Do not accidentally retain a 3×3 collision box or scale only the body while leaving a floating connector.

Use a dedicated item/recipe/technology identifier `tc-interplanetary-radar`, a distinguishable composed native-asset icon and locale text. The disabled-by-default recipe unlocks only through that technology. Prerequisites include `tc-circuit-computers`, `production-science-pack`, `utility-science-pack` and `space-science-pack`; the packaged data-stage test verifies the complete dependency chain and ingredient reachability under Space Age's updates.

Confirmed research ingredients are exactly the six names in the spec. Proposed balance defaults for initial implementation are 500 units at 30 seconds with one of each pack, a recipe of one radar, 20 steel plates, 20 processing units and 10 low-density structures taking 10 seconds, and 1 MW power consumption. These are explicit initial tuning choices, not measured balance claims; they use no planet-specific materials. Native scan radii remain the vanilla values, and quality does not change modem channel capacity or scope. Preserve native safety/placement constraints but impose no planet-only condition; verify platform construction and in-flight operation in the real expansion engine.

Alternative rejected: make the large radar exist in base with disabled cross-surface routing. The user explicitly selected Space Age-only availability for the advanced tier.

### 7. Validation is layered and archive-based

Add focused contract/data/native fixtures rather than relying on a large manual scene alone. Reuse `tests/network_engine.lua` patterns for real connectors and `tools/smoke.py` production-context/cold processes for persistence. Both explicit fixture allowlists must be updated for new native fixtures; never let the companion test mod create duplicate physical owners.

Acceptance has distinct gates:

- Contract/API: argument types and arity, channels, shared state, nil/data validation, exact method inventory, copied events, deterministic ordering, no prefix on refusal and overflow policy.
- Native base: existing/new ordinary radar, local physical relay, actual hidden links, preserved native scanning/signals/opening, power, same-surface unlimited distance, other-force exclusion and remote-peripheral refusal.
- Native Space Age: optional prototype matrix, research/recipe unlocking, all tier-pair direction combinations, advanced routes across planets and a genuine travelling platform surface, correct distance presence/absence and platform deletion.
- Persistence: queued-event cold save/reload, saved channel sets and same-tick credits, no startup/transmit replay, existing-save adoption, clone/blueprint/replacement and force/surface reassignment.
- Capacity: existing global budgets unchanged, complete fan-out accounting, candidate/edge/queue bounds, progress under competing controller/monitor workload and measured supported transport envelope. Only the 128 open-channel compatibility limit is fixed in advance; publish measured finite payload/rate/fan-out ceilings before release.
- Native client: ordinary radar unchanged, advanced radar scale/5×5 selection/wires/ghost/animation/shadows, icons/research and placement on a platform. Capture actual windows and sampled animation frames using the complete licensed client; llvmpipe screenshots do not establish representative GPU FPS.
- Multiplayer: connect real peers, exercise ordered traffic/shared channels, join/reload and compare authoritative state. Headless cold processes do not substitute for this gate.

## Risks / Trade-offs

- Native hidden edges are real connections → Filter by origin in every discovery proof, pre-admit their inspection cost and preserve native signal links. A large native radar network can hit the existing edge limit even with few local cables; report it rather than removing links or raising limits to hide the cost.
- Composite assumptions are scattered → Use an explicit native-carrier path and regression-test art, metadata, upgrade, clone, refund, removal and UI entry paths before adding communication.
- Whole-send proof can be refused by an eligible receiver's unresolved graph → Keep the policy explicit, return before publication and expose diagnostics. Measure the supported envelope; do not silently fall back to partial delivery. More scalable indexed/asynchronous routing is deferred until a measured workload requires it.
- Shared channel configuration can surprise users → Document that `closeAll` affects all attached computers and provide separate-radar guidance; do not introduce hidden per-program ownership.
- Radar state increases registry pressure → Connected-frontier adoption avoids eagerly claiming unrelated old radars, and capacity failure leaves every native entity/wire intact.
- Broadcast amplification can starve normal controllers → Account every candidate, handler copy and queue cleanup; enforce per-computer and aggregate limits and verify alongside existing monitor/logic workloads under unchanged global budgets.
- Native radar buffers fluctuate under low supply → Define operational availability from live native activity/energy and test outages; do not reuse composite buffer-write logic.
- Optional expansion and future inspector work touch common files → Keep prototype guards and native opening explicit, preserve base-only loading, and reconcile integration without importing an unimplemented inspector dependency.

## Migration Plan

1. Add versioned radar state and transport accounting through synchronized initialization/configuration paths, retaining existing registry IDs, program state, queues, spent credits and device schemas. Keep unsupported/corrupt native integration state inert with diagnostics, not reset-and-continue behavior.
2. Register new native radars via the single event owner and adopt physically connected pre-existing radars through bounded reconciliation. Do not convert native bodies, normalize their power or clear their circuit wires/settings.
3. Reconcile advanced recipe unlocks for already researched forces only when Space Age and the prototype exist. Ordinary radar progression remains native.
4. Exercise released-save upgrade and ordinary cold reload separately. Preserve a backup outside git and verify exact entity/wire/data continuity.
5. For rollback, restore the pre-upgrade save with the prior mod set. Downgrading a live save can remove the new advanced entity/technology and is not a lossless rollback promise. Disabling Space Age is a Factorio configuration transition, not a promised transparent downgrade; absent advanced prototypes must not crash base-only startup.

## Open Questions

No unresolved gameplay decision blocks implementation. Numerical payload/fan-out/rate ceilings and final balance tuning remain empirical release tasks: measure them against the fixed contracts and unchanged existing budgets, then document the accepted values. If the 128-channel API or native-origin isolation cannot be met, return for design review rather than silently reducing compatibility or weakening authority.
