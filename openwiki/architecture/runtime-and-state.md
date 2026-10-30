---
type: architecture
title: Runtime composition, durable state and cold reconstruction
description: How the Factorio control entrypoint composes host services around plain retained records and reconstructs native guest callbacks after load.
tags: [architecture, persistence, lifecycle, runtime]
verified:
  - by: openwiki/0.7.1
    at: 2026-10-29T22:50:29.161Z
sources:
  - id: openwiki-source-647cc954e0352bb51785a5d7
    resource: repo://control.lua
  - id: openwiki-source-6017f73285ae6bbf6c3d040a
    resource: repo://scripts/registry.lua
  - id: openwiki-source-4cee717286544161165260f8
    resource: repo://scripts/runtime/compiler.lua
  - id: openwiki-source-0ddacafef71462f8b63089cd
    resource: repo://scripts/runtime/computer.lua
  - id: openwiki-source-0bf68f272e97a323da18a610
    resource: repo://scripts/scheduler.lua
generated: { by: "hermes", at: "2026-10-29T22:50:29.161Z" }
---

# Runtime composition, durable state and cold reconstruction

## Ownership and entrypoints

`data.lua` imports device, editor and monitor prototypes; `control.lua` imports trusted host modules while Factorio parses control code. Those imports register service providers, cleanup hooks and scheduler phases. The control entrypoint installs native entity, GUI, blueprint and custom-input handlers, and one normal `on_tick` calling `scheduler.tick`. Initialization/configuration changes initialize the registry and material adapters. Normal production deliberately registers no `on_load`: it neither runs guest source nor renews clocks during loading. The opt-in exact-name production test fixture at the bottom of `control.lua` is a separate harness path, not guest loading.

Configuration changes first call `lifecycle.upgrade_existing` to stage legacy physical families onto circuit-capable shells. GUI tab, selection and checkbox events are registered beside the existing open/text/click routes; they do not execute guest source. The dependency direction matters: registry owns identities and cleanup dispatch; runtime owns a computer generation and its services; scheduler dispatches it; physical lifecycle owns entities and power. Services register themselves with those lower-level owners during control parsing. Avoid importing a service into physical ownership merely to get its material serializer: lifecycle exposes item-adapter registration for that seam.

## What survives a save

`storage.tweaked_computers` holds schema version, monotonic IDs/sequences, entity bindings, computer/device records, player drafts, ordered identities, the admission ledger and scheduler cursors. Computer records retain source text, revisions, explicit Data state and accounting, bounded logs, queued event records, named timers and subscriptions. Native LuaEntity references remain host-owned Factorio references; they are not guest Data and never cross the API boundary.

The active snapshot contains source, source revision, compiler/API/storage versions and a handler-name map—not executable closures, generated source, coroutine stacks or guest environments. Host function tables (service providers, cleanup hooks, phase hooks) are ordinary module-local registrations recreated during control parsing, not serialized guest state.

Unknown root schemas remain inert rather than being reset. Registry writes reject unsupported schemas; scheduler returns without dispatching them. This is a data-preservation boundary, not a general automatic migration framework.

## Save, activation and dispatch

1. `runtime.save` checks the expected saved revision, bounds source bytes and increments the revision. It does not compile, stop or replace an active run.
2. `activate` checks retained headers/capacity and validates the saved declaration document before retiring the previous generation. Validation accepts exported function declarations and optional lexical local-function helpers, not top-level initialization or effects. A rejected candidate leaves the previous run intact.
3. Successful retirement runs all cleanup hooks, clears runtime queue/timers/subscriptions, assigns a new monotonic run identity and stores a plain active snapshot. A declared `start` handler is enqueued once here.
4. Each dispatch checks the active header, body, current power observation and admission. It takes one queued handler/event, then `compiler.run` recompiles the retained exact source, constructs a fresh guarded native environment and calls the named handler with a copied event.
5. Callback return does not preserve lexical variables. Cross-callback state must be explicitly copied through `computer.setState`; timers/subscriptions refer to handler names. Faults retire runtime work and invoke host cleanup, while retaining source and explicit state for recovery.

There is no startup callback replay on ordinary cold load: the queue and timers already describe pending work. Fresh reconstruction on dispatch makes compiler behavior independent of warm executable caches. Version mismatches fail closed with retained text/data instead of attempting to execute an old closure.

## Extension and tests

A new trusted service provider registers once through `runtime.register_services` and returns methods only in the `computer` or `peripheral` namespaces; namespace/name collisions are assertions. Peripheral type registration is a separate seam. Always reserve work and copy/validate Data before effects; do not smuggle host objects into a return value.

`tests/computer_contract.lua` and `tests/computer_cold.lua` cover runtime contracts and cold reconstruction; `tests/integration_engine.lua` exercises production editor activation, multiple services and retained behavior. Their presence is coverage evidence, not a claim they were rerun for this wiki-only change. See [operations](../operations/build-test-and-assets.md) for commands and the explicit client-verification boundary.

Related: [compiler and sandbox](../runtime/compiler-and-sandbox.md), [scheduling](../runtime/scheduling-and-admission.md), [physical lifecycle](../devices/ownership-and-lifecycle.md), [editor revisions](../authoring/editor-revisions.md).
