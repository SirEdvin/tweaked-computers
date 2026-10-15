---
type: lifecycle
title: Physical ownership, material data and lifecycle
description: Entity families, exact role bindings, power and teardown, data-bearing mining, blueprint wire revival and stopped clone/replacement semantics.
tags: [devices, lifecycle, persistence, blueprints, ownership]
verified:
  - by: openwiki/0.7.1
    at: 2026-10-15T06:41:57.498Z
sources:
  - id: openwiki-source-d804efd8219272266fe9cedb
    resource: repo://scripts/blueprints.lua
  - id: openwiki-source-199ebbbf763b15ba60eb9147
    resource: repo://scripts/device-definitions.lua
  - id: openwiki-source-efb72cb67b97c27491e72b6a
    resource: repo://scripts/lifecycle-data.lua
  - id: openwiki-source-765149bc0fcb867d9e5de6c4
    resource: repo://scripts/lifecycle.lua
  - id: openwiki-source-6017f73285ae6bbf6c3d040a
    resource: repo://scripts/registry.lua
  - id: openwiki-source-0ddacafef71462f8b63089cd
    resource: repo://scripts/runtime/computer.lua
generated: { by: "hermes", at: "2026-10-15T06:41:57.498Z" }
---

# Physical ownership, material data and lifecycle

## A device is an owned family

`device-definitions.lua` is shared host tuning for recipes, widths, power and cardinal port offsets. Computers, KV stores and monitor tiles have a `network` child; logic has separate `input`, `network`, `output`; configurators have `network`, `targets`. The body is the electric interface; role children are protected circuit entities, not player inventory items. Passive ports have no output sections and stay disabled. Only the logic output role deliberately publishes a bank.

`lifecycle.build` allocates physical parts before publishing an identity, binds each exact child and records body position/direction/scope. Duplicate raised builds return the existing identity rather than replaying material import. Rollback removes staged parts unless cleanup failure requires an inert recoverable record. Registry lookup checks the exact retained object against the role binding: reused native numbers or a replacement at the same position cannot retarget the old ID.

`lifecycle.connector` is the single role accessor. It rejects missing/error records, moved/rotated bodies, wrong port offsets/directions, wrong registry ownership or changed force/surface. Do not bypass it by searching a nearby combinator. Rotation moves existing children with their wires and attempts restoration on failure; failed restoration makes the device inert rather than silently adopting another entity.

## Power, teardown and synchronized repair

A critical early lifecycle pass detects power loss and physical invalidity before ordinary callbacks/output checks. Ordinary physical reconciliation walks records fairly, samples current power and repairs scope/position relationships through owned objects; missing ports are retained as physical errors. Scheduler dispatch also demands a current-tick positive power observation for physical computers, so deferred maintenance cannot keep stale authority alive.

Computer power loss invokes cleanup and retains only queued start/timer events, not ordinary input notifications. Restoration marks input resynchronization and may enqueue `power_restored`. A peripheral outage clears its output bank. Registry cleanup runs every registered hook in sorted order even if one fails and retains diagnostics; failed removal leaves a faulted record instead of discarding recoverable state. Removal destroys exact retained children, never arbitrary entities at a position. Surface deletion and force merge have explicit teardown paths; subsequent reconciliation also catches invalid bodies or changed scope.

## Persistence policies are intentionally different

| Operation | Computer | KV | Monitor |
| --- | --- | --- | --- |
| Ordinary save/load | Active source metadata, explicit state and pending records remain; dispatch reconstructs callbacks | Physical-local database and absolute expiry remain | Group/model/render jobs remain |
| Mining into material item | Saved and formerly active source, explicit state, label; no runtime execution | Audited data snapshot, with expiry semantics retained | Scale, palette, foreground/background, blink; no old group buffer/cursor |
| Place material item | New identity, stopped, no queue/timers/subscriptions; recovery text is not auto-run | Import data only from actually consumed material item | New grouping from tile settings |
| Blueprint/settings copy | Saved source/label, not active execution or application state | No database duplication | Settings only |
| Clone | Settings into a new stopped identity; no application state/run/output | Empty fresh store | Settings, fresh grouping |
| Destruction | Explicit loss, teardown and outputs cleared | Explicit data loss | Membership regrouping/teardown |

Material snapshots are host formats with strict version/shape/size validation; import never compiles source. Computer snapshot validation recomputes aggregate state accounting. Unsupported retained computer data becomes unmineable/faulted for recovery rather than being serialized destructively. Settings-copy increments the destination source revision monotonically and preserves its existing explicit state while stopping its old run.

The mining event serializes into the actual matching native result stack before unregistering ownership. Placement reads adapter tags only from the consumed item; blueprint/script tags cannot counterfeit a carried database. Successful material restoration takes precedence over blueprint settings. On material restore failure placement is refused/refunded unless cleanup itself requires retention.

## Blueprints and cloned helper events

Blueprint preparation stages saved-source/settings plus all selected role helper entities and selected native wire edges before updating the blueprint. It appends an explicit disclosure that saved source/labels may contain literals, while state/KV/active runs/timers/outputs are excluded. Treat exported source as intentionally disclosed text, not a secrets vault.

A blueprint body token links role ghosts to the exact family. Adoption checks token, family, role, force/surface and exact rotated offset. Native ghost revival transfers actual wires; replacing a matching ghost with `create_entity` would delete them. Helper adoption clears inherited sections/output ownership and binds a single protected child. Unexpected external helper placements are destroyed rather than left usable and unowned.

Area clone events can arrive for helpers separately from bodies. A bounded retained pending list reconciles each clone helper to a destination with matching source ID/role/scope/offset; it replaces the freshly created helper or destroys an orphan. This preserves native wire reconstruction without cloning writer ownership or KV contents.

## Maintenance seams and tests

Material adapters register `initialize`, `snapshot`, `restore` and a fixed tag during control parsing. Ownership stays independent from service data formats. Keep state-bearing import separate from settings-only import and preserve explicit review/copy-to-draft for formerly active text.

`tests/device_engine.lua` covers physical contracts; `tests/lifecycle_engine.lua` covers exact owned teardown, native blueprints/clones and material data. Use the production-context harness for lifecycle/integration fixtures so a second event registry does not fabricate duplicate helpers. No graphical rotations, mining UX or multiplayer join were run for this wiki. See [operations](../operations/build-test-and-assets.md).

Related: [runtime reconstruction](../architecture/runtime-and-state.md), [network authority](../network/discovery-and-authority.md), [KV data audit](../services/kv-staging-and-expiry.md), [editor recovery](../authoring/editor-revisions.md).
