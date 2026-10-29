# Proposal

## Why

Idle computers and devices currently participate in repeated scheduler, physical/power, subscription-discovery and ownership walks even when they have no work. Make recurring work proportional to actual demand while preserving tick-responsive signal subscriptions, deterministic bounded execution and fail-safe authority checks.

## What Changes

- Refactor the existing scheduler, not introduce a second framework: subsystems maintain runnable computers, due deadlines, watched inputs, owned outputs and pending maintenance/presentation membership as state changes.
- Only inputs with active signal subscriptions receive tick-level subscription observation. Share one observation per physical input/color, apply each subscriber's filter independently, and queue callbacks only for changes, requested initial observations or resynchronization. Unsubscribed computers do not participate in subscription sampling.
- Preserve fair non-reentrant program/Console dispatch, timer alignment/coalescing, shared budgets, output cleanup and deterministic cold-load behavior. Idle topology/inspection bookkeeping may remain delayed within existing published envelopes; active input observation may not be throttled into a slower polling interval.
- **BREAKING:** Remove electrical consumption and electrical availability requirements from all custom composite devices: computer, database, monitor, logic handler, configurator, Recipe Searcher, Factoriopedia Interface, Production Statistics and Dashboard Interface. Retire their power helpers and brownout/power-restoration behavior without deleting user data or physical signal/network roles.
- Keep both radar tiers and the native programmable speaker's existing electricity and native behavior unchanged. Check power during operations, metadata reads and transmission receiver eligibility; never proactively monitor their power.
- Convert every recurring hook to explicit pending work, deadline or active-observer membership, including topology, native adoption, clone/undo reconciliation, monitor grouping/notifications/presentation, KV reclamation, status art and open UI sessions. Retain narrowly targeted observation where Factorio provides no complete change event.
- Migrate existing saves once before ordinary ticking; preserve source/state, identity, timers, queue order, credits, database/display content and native-device state. Ordinary load must not run source or rebuild authoritative state in `on_load`.
- Include an editable Excalidraw drawing of the complete proposed tick cycle and an API compatibility contract. Keep the separate `function-only-programs` proposal independent: this change does not alter source syntax or callback execution semantics.

## Capabilities

### New Capabilities

None. Extend the existing runtime and device contracts rather than create a parallel scheduling capability.

### Modified Capabilities

- `computer-runtime`: demand-driven deterministic dispatch/deadlines and removal of computer brownout execution.
- `logic-handler`: subscription-owned tick observation, shared input reads and power-independent output services.
- `device-lifecycle`: power-free custom devices, targeted maintenance and safe legacy-helper migration.
- `peripheral-network`: demand-owned topology/authority work and operation-time native power checks.
- `monitor-display`: power-independent retained display and demand-only topology/notification/presentation work.
- `console-shell`: power-independent commands and runnable-only scheduling.
- `dashboard-interface`: power-independent service with viewer-owned refresh deadlines.
- `peripheral-inspection`: power-free custom-device status and open-session-only refresh.
- `kv-database`: power-independent service and deadline-owned retained-item cleanup.
- `recipe-searcher`: power-free physical/service contract.
- `factoriopedia-interface`: power-free physical/service contract.
- `production-statistics`: power-free physical/service contract.
- `device-visual-identity`: remove misleading custom-device electricity warnings while retaining native status behavior.
- `radar-modem`: native electricity checked only on interaction/receive eligibility; no computer-power outage semantics.
- `speaker-peripheral`: retain native electricity with no proactive availability polling.

## Impact

Implementation reaches `control.lua`, `scripts/scheduler.lua`, `scripts/registry.lua`, `scripts/runtime/computer.lua`, `scripts/runtime/shell.lua`, `scripts/lifecycle.lua`, `scripts/device-definitions.lua`, `prototypes/`, service/network/blueprint/undo modules, monitor rendering, status art and UI refresh consumers. Existing public signatures and resource ceilings remain; custom-device `E_UNPOWERED` and brownout behavior intentionally disappear. Identity, scope, wiring, generation and writer-ownership checks remain mandatory.

Tests must cover zero idle visits, subscribed-only per-tick observations, fairness and overload, one-tick pulses, last-writer revocation, all custom families without electricity, native outages at use time, migration/cold reload and connected peers. Documentation, API help, locale, artwork status selection and fixtures that previously supplied power must agree. No new dependency, user setting, execution model, public scheduling API or larger budget is proposed. Timing improvement is a hypothesis until matched baseline/candidate measurements are taken; structural no-visit assertions are independently required.
