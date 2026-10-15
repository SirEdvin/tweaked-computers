---
type: architecture
title: Discovery, target traversal and current authority
description: Why mod-only peripheral discovery, native configurator target traversal, delayed notifications and current service authority are separate mechanisms.
tags: [network, discovery, authorization, peripherals]
verified:
  - by: openwiki/0.7.1
    at: 2026-10-15T06:41:57.498Z
sources:
  - id: openwiki-source-cb60da2bf5fe82e8150a4867
    resource: repo://scripts/configuration/targets.lua
  - id: openwiki-source-cf29203f009f2866aa4dd8f4
    resource: repo://scripts/network.lua
  - id: openwiki-source-84bfcd6a80f737a0b75f8c1c
    resource: repo://scripts/services/peripheral.lua
generated: { by: "hermes", at: "2026-10-15T06:41:57.498Z" }
---

# Discovery, target traversal and current authority

## Discovery is not the native circuit-network ID

`network.discover` performs a complete bounded BFS from the computer's explicit red or green `network` connector. A discovery vertex must be a live same-force/surface owned `network` role, and must equal the connector returned by lifecycle ownership checks. It follows real physical edges of that color; an ordinary pole/combinator is not a traversable bridge, nor are input/output/target roles. Computers can be intermediate vertices, but are not returned as peripherals.

Edge counts are checked before fetching native connection arrays, including ignored external edges. Node/edge or work refusal is a failure, not a truncated successful inventory. Parents record a physical witness path. Group identities are not graph vertices: neighboring monitor tiles may resolve to a single logical anchor after traversal, but geometric grouping never creates a hidden network wire.

`peripheral.inventory` maps discovered members through the fixed per-type resolver, validates scope and deduplicates logical identities. The four public families are KV database, monitor, logic handler and configurator. The monitor resolver can map a reachable tile to its group anchor without making every other tile a wire bridge.

## Handles are callback-local capabilities, not persisted authority

`peripheral.wrap` builds a guarded namespace with methods from the host's fixed family binding. It captures name, generation and chosen wire; the weak handle map belongs to that callback's service environment. `getName`/`getWire` accept only genuine handles from that environment. A handle is not Data, cannot serve as a saveable LuaEntity proxy and does not authorize arbitrary methods or guest plugin registration.

Every method invocation—including captured functions and `getLimits`—checks current computer run identity/power and rebuilds live discovery. A missing/regrouped identity revokes the old binding and raises `E_UNREACHABLE`. Ordinary methods also demand actual peripheral energy/availability; reachable `getLimits` is allowed while unpowered. Metadata discovery and notifications therefore do not substitute for effect-time authority.

To add methods within an existing family, register a bounded host binding once, include `getLimits`, use copied Data and reserve service-native work before effects. Adding a completely new family also requires changing the closed type/physical registries intentionally; there is no guest extension hook.

## Configurator target traversal is a different graph

`configuration/targets.lua` starts at the configurator's `targets` port. Here native entities/connectors are traversable, with same force/surface and explicit color checks. Vertices use native object-destruction registration identity plus connector ID; results aggregate entity identity and connector names. Mod-owned components are described through their body and marked protected. IDs are not positions and cannot retarget replacement entities.

Every target lookup builds the whole bounded inventory again. The configurator is first authorized through mod discovery, then the native target is authorized through this separate target graph. Sharing the bounded `real_edges` primitive does not merge the policies. Preserve this distinction when extending adapters: changing native target reachability must not allow ordinary poles to bridge peripheral discovery.

## Notifications lag; safety does not

Topology maintenance is a notifications-phase fair sweep of at most three computer/color inventories per tick. A new run takes a baseline without synthetic attach snapshots. Later differences stage deterministic detach/attach changes in a retained job and reserve delivery/cleanup before publication. Cursor advancement prevents replay after deferral; `E_NETWORK_PENDING` is diagnostic, never permission to use stale inventory.

Logic output safety runs earlier in lifecycle. It validates the current run and either proves a retained physical witness or recomputes authority. Missing authority, invalid data or proof deferral clears the bank immediately through a prepaid cleanup path. It does not wait for the slower attach/detach sweep. Cleanup on Stop/fault/activation/removal is keyed to the exact computer/run owner, not a blanket clear of unrelated devices.

## Focused verification

`tests/network_engine.lua` covers mod-only topology, color/role separation, captured handle revalidation and notifications; `tests/monitor_engine.lua` covers logical monitor resolution; `tests/configurator_engine.lua` covers the native target policy. `tests/logic_engine.lua` covers writer/path cleanup. These are source coverage references, not new execution results from this documentation run.

Related: [physical bindings](../devices/ownership-and-lifecycle.md), [typed target adapters](../configuration/typed-adapters.md), [signal ownership](../services/signal-ownership.md), [monitor grouping](../services/monitor-pipeline.md).
