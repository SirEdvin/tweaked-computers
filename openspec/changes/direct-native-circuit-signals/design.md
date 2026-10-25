# Design

## Context

See `proposal.md` for scope. Main is the implementation baseline; the resource-policy feature branch is not a dependency.

The relevant existing path is:

```text
native get_signals
  -> normalize / merge / sort / 64-entry checks (services/logic.lua:70)
  -> Data copy (logic.lua:212)
  -> sandbox snapshot (runtime/sandbox.lua:303)

subscription baseline -> Data copy (runtime/computer.lua:100)
sample -> Data copy -> event preparation -> queue
queued event -> sandbox snapshot (runtime/compiler.lua:407)
```

The shared copies impose entry, node, byte and string ceilings. Removing only the local 64 check leaves the original problem at another boundary. The earlier branch's `docs/inventory-resource-validation.md:84` records precisely that subscription failure.

Factorio is pinned by `info.json` to 2.0.77. Its official `runtime-api.json` confirms native single/all-signal getters, optional SignalID fields, additional signal categories and native logistic filter index domains. Read from `https://lua-api.factorio.com/2.0.77/runtime-api.json`; no engine execution was performed while planning.

## Goals / Non-Goals

**Goal:** delete avoidable circuit wrapping, retaining a small explicit trust boundary between engine values, private event state and mutable guest tables.

**Non-goals:** no continuation compiler, resumable sorter/validator, general memory ledger, new limit settings, discovery rewrite, new event-loss policy, general Data relaxation or port of the earlier branch. Compiler/scheduler edits are limited to the trusted event handoff, not execution semantics.

## Decisions

### 1. Native data is the answer, not input to another inventory pipeline

Use the existing input connector and native scalar/bulk getters on every call. Return the freshly detached native bulk array, substituting `{}` only for no result. Remove the value validator, aggregation map, signed-count recomputation and sort from that read path. Interpret optional fields only where comparing identities or presenting them. Native categories do not pass through the old four-type whitelist.

Read own output through the existing native constant-combinator section. A minimal filters-to-`{signal,count}` adapter is necessary because the native configuration shape differs; preserve the native identity record rather than normalizing it. Do not query output-network totals. The native section is the bank's source of truth; keep writer metadata and temporary rollback data, not an authoritative `output_bank` read cache.

Rejected: larger limits, configurable slot counts, native-data validation, canonical ordering and cached/deferred read jobs.

### 2. Narrow trusted transfer, not a global Data bypass

Reuse the sandbox's existing plain-table ownership mechanism with a host-only circuit transfer path. Adopt fresh detached result tables rather than copying them twice; enroll the nested signal records so normal indexing, length and iteration work. Enrollment is not prototype/count validation or proportional inventory admission. Preserve ordinary guest work charging after handoff.

Select this path only through the closed Logic Handler provider and trusted queued-event metadata, never user fields such as `name = "signal_changed"`. Route circuit arguments to their actual method validator without the generic pre-copy shape cap; caller data remains untrusted. Snapshot output/filter requests once only if needed to isolate retained state. Raw accesses, invalid inputs, metatables/functions/cycles, authority and side-effect atomicity remain protected.

Native scalar fields and arrays must be usable beyond former identifier/table limits, including non-growing replacement/deletion used to turn a returned array into a filter request. Do not run an old whole-table cardinality refusal merely to replace an existing slot. This does not exempt arbitrary additions, guest loops, large string operations, explicit application-state/KV writes or Console persistence from their normal rules. A mutated native result passed back to a service is caller input again.

Direct results need no extra defensive copy when exclusively owned by the caller. Retained subscription baselines must not alias delivered mutable events; copy only where two owners actually need isolation, using the known signal/event shape without generic Data ceilings. Do not replace plain tables with lazy proxies or add a universal trusted-value framework.

### 3. Keep subscriptions simple and preserve event semantics

Retain existing per-computer/global registration counts at `subscribe(...)` only. Remove the distinct sampled-handler and owned-output count gates, which constrain internal circuit service rather than user registrations. Remove filter/slot/name ceilings and their introspection entries, without touching unrelated registry/discovery quotas.

Take a fresh baseline during registration. Each sampling pass reads the engine anew; one local observation can feed subscribers in that pass, but it is not retained as a reusable read cache. Keep only each subscription's previous observation/connectivity and accepted events. Build identity comparison/filter maps only as needed; do not sort or persist processing cursors. Native defaults define equality without modifying records. Registration/filter validation occurs on caller input, not again on each native sample.

Preserve existing initial/resync/disappearance, queue-admission baseline advancement, FIFO dispatch and power/authority cleanup. Circuit payloads bypass generic Data and peripheral byte/node/entry guards in registration, preparation and dispatch. Meter the service invocation and normal dispatch, not a native inventory-sized refusal envelope.

Keep existing queue entry and envelope accounting/overflow behavior. Native signal graphs are excluded from generic guest-payload byte accounting so one large observation can be delivered; this counter consequently is not a total-memory bound for circuit snapshots. Preserve other producers' payload accounting and audit queue retirement, unsubscribe, power loss and cold load for consistent byte counters. No coalescing, dropping or new subscription policy is implied.

### 4. Preserve validation where data comes from the user

Validate wire/options, dense arrays, effective duplicate identities, native prototypes/qualities, supported native signal categories and exact native counts before output publication or registration. Native default fields are legal input. The old identifier length is not a prototype validity rule. An oversized output must fail at the actual native section domain, not a replacement mod constant.

Reuse the existing inactive-section staging, rollback and writer-ownership path. Native-operation failure handling/readback that prevents partial output is not permission to revalidate every native read. Keep original output and owner on rejected input and retain the existing recovery path if native restoration itself fails.

### 5. Update consumers, not another cache layer

`peripheral-inspector-model.lua` must acquire fresh native data independently of program subscriptions. In `peripheral-inspector.lua`, identity comparison, icons and tooltips interpret missing defaults locally; unsupported icon presentation must not hide an engine signal. Retain mounted UI/display state and existing scheduling/scrolling, not a service read cache. Presentation work may be scheduled separately from the complete native observation, with no inaccessible tail and no new guest pagination API.

Update `docs/logic-handler.md`, `docs/player/api/logic.md`, shared API wording where it would contradict the circuit exception, in-game Reference, affected examples/tests and the Logic API companion. Do not modify Configurator's independent SignalID validation just because its generator also mentions signals.

## Risks / Trade-offs

- Native cardinality now determines bridge work and snapshot memory. Fixed call/registration/backlog protection does not constitute a calibrated native heap or tick-time bound. Measure the actual large-circuit workload; report a demonstrated bottleneck rather than adding caps or another accounting architecture.
- Native optional fields/order break positional or fully normalized consumers. Update examples, inspector identity handling and regressions together; compare values by effective identity, including after reload.
- Trusted-transfer mistakes can expose mutable baselines or bypass user validation. Test nested mutation, cross-subscriber isolation, forged event data and modified read results before accepting the bridge.
- UI row creation or remaining event ingress copies can recreate the old ceiling. Verify complete tail access through actual compiled guests, queued callbacks and the native client, not provider-only tests.

## Migration Plan

Implement on a new feature branch from current main. The earlier proposal is withdrawn; do not apply or archive its deltas, or merge its implementation branch. During permitted synchronized lifecycle handling, retire obsolete circuit read caches and stop consulting the old output mirror; do not query or mutate during `on_load`. Preserve valid native banks, owners, registrations and queued observations. Legacy explicit-default/sorted snapshots remain valid comparison data; do not rebuild them merely for cosmetic shape changes. Preserve malformed-registration rejection.

Run packaged base and Space Age checks on the exact candidate, including a separate-process save/reload with a large pending event and an upgrade from 0.1.13. Check native inspector rendering separately. Keep failed evidence outside the repo. Rollback uses the prior package and a pre-upgrade backup; no downgrade serializer or speculative migration framework is part of this change.
