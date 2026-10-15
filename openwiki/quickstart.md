---
type: quickstart
title: Developer quickstart and task routing
description: Start here to maintain Tweaked Computers internals, find owners and trust boundaries, and select a focused build or test without confusing player guides with developer architecture.
tags: [quickstart, architecture, development, routing]
verified:
  - by: openwiki/0.7.1
    at: 2026-10-15T06:41:57.498Z
sources:
  - id: openwiki-source-647cc954e0352bb51785a5d7
    resource: repo://control.lua
  - id: openwiki-source-0f322ac3f67e0772fa67765f
    resource: repo://data.lua
  - id: openwiki-source-4cee717286544161165260f8
    resource: repo://scripts/runtime/compiler.lua
  - id: openwiki-source-0ddacafef71462f8b63089cd
    resource: repo://scripts/runtime/computer.lua
  - id: openwiki-source-5d48cd00e5813afcd8f4727c
    resource: repo://scripts/runtime/data.lua
  - id: openwiki-source-ed1a70dfaf29a8bea3029be3
    resource: repo://tools/build.py
  - id: openwiki-source-76b87832ddf6312873ab8b07
    resource: repo://tools/smoke.py
generated: { by: "hermes", at: "2026-10-15T06:41:57.498Z" }
---

# Developer quickstart and task routing

Tweaked Computers is a Factorio 2.0.77 alpha implementation with optional Space Age. It composes native guarded named callbacks, a single-document editor, role-separated discovery and logic I/O, local string/hash KV, merging monitors, typed native configurators and material lifecycle policies. It is not an OS/filesystem/interpreter and is not client-verified stable software. Back up saves; limits and performance envelopes remain provisional.

This is the developer OpenWiki: it explains source ownership, data/control flow, invariants, failure paths and extension seams. The separate [player guide](../docs/player/index.md) is the player-site source; existing [alpha installation/checklist](../docs/alpha-candidate.md) and [factory example](../docs/factory-example.md) are useful behavioral context, not substitutes for internal architecture. Planned contracts under OpenSpec must be compared with actual source before claiming effective behavior.

## First source trace

1. `data.lua`/`prototypes/` define native devices, inputs and glyph registrations.
2. `control.lua` imports trusted modules during parsing and installs events. Normal initialization/configuration establishes state; normal `on_load` deliberately executes no source and changes no state.
3. `scripts/registry.lua` owns exact entity/role identities and retained roots; `scripts/lifecycle.lua` owns physical family/power/teardown.
4. `scripts/scheduler.lua` runs ordered host phases and fair queue dispatch; `scripts/runtime/computer.lua` owns saved/active revisions, explicit state and run IDs.
5. `compiler.lua` recompiles retained source into guarded native Lua for each dispatch; `sandbox.lua` closes guest authority and Data copies isolate state/effects.

## Route the actual maintenance task

| If you need to… | Read first | Source/check seam |
| --- | --- | --- |
| Understand save/load or why startup did not replay | [Runtime composition and state](architecture/runtime-and-state.md) | active source metadata, queue/timers, `computer_cold` |
| Change accepted language or guard a native operation | [Compiler and sandbox](runtime/compiler-and-sandbox.md) | compiler emission, sandbox services, `runtime_contract` |
| Debug starvation, budget refusal or overdue timers | [Scheduling and admission](runtime/scheduling-and-admission.md) | retained ledgers/cursors, `computer_contract` |
| Change ports, rotation, mining, cloning or blueprints | [Ownership and lifecycle](devices/ownership-and-lifecycle.md) | material versus settings import, `lifecycle_engine` |
| Explain unreachable devices or stale handles | [Discovery and current authority](network/discovery-and-authority.md) | mod-only BFS versus native target graph, `network_engine` |
| Change native configurator support | [Typed adapters](configuration/typed-adapters.md) | catalogue generator, validation/readback/recovery, configurator fixtures |
| Change screen grouping, byte cells, rendering or touch | [Monitor pipeline](services/monitor-pipeline.md) | partition/model/presentation/input, `monitor_engine` |
| Change KV expiry/capacity/material persistence | [KV staging and expiry](services/kv-staging-and-expiry.md) | single publish and audit/import, `kv_engine` |
| Debug input notifications or stuck signal outputs | [Signal ownership](services/signal-ownership.md) | sampling baseline, exact writer/path cleanup, `logic_engine` |
| Change Save/Run conflicts or draft recovery | [Editor revisions](authoring/editor-revisions.md) | native GUI envelope and plain model, editor fixtures |
| Package/test assets or publish documentation | [Build/test/assets operations](operations/build-test-and-assets.md) | external outputs, exact-engine harness, separate Pages workflow |

## Minimal local verification

Run from the repository root. Choose a fresh external output directory; the package builder/harness refuse in-checkout output. Replace the sample versioned ZIP name with the filename actually produced from `info.json`.

```sh
python3 tools/planning_examples.py --check
python3 tools/configuration_catalog.py --check
python3 tools/build.py --output /absolute/external/artifacts
python3 tools/smoke.py --factorio /path/to/factorio/bin/x64/factorio \
  --archive /absolute/external/artifacts/tweaked-computers_0.1.0.zip \
  --output /absolute/external/fresh-smoke --mode base \
  --fixture tests.runtime_contract
```

Use only the affected fixture after a narrow change. Cold save/load and production lifecycle checks use the existing harness flags described in [operations](operations/build-test-and-assets.md), not a second native event registry. Docs-only wiki maintenance needs managed generation/retrieval/link/evidence checks, not graphical Factorio or a full runtime matrix.

## Keep these boundaries intact

- Only plain copied Data, source text and named registrations survive guest callbacks; no saved guest closures, coroutine stacks or host objects cross APIs.
- A discovery notification/cache is not authority. Reprove current physical color/path/run before effects; output cleanup must work without compiling source.
- Stop/restart/removal/save/load do not renew same-tick admission. Reserve complete bounded work before native mutation and retain diagnostics rather than dropping malformed data.
- Material mining is not blueprint/settings/clone duplication. Preserve absolute KV expiry, stopped imported computers and explicit recovery text review.
- Preserve selected Greg Flavored MIT and independent glyph/parser provenance. Do not replace actual source evidence with speculative asset genealogy or client claims.

Historical implementation reports and source fixtures record focused headless evidence; this developer-wiki generation does not rerun application/game tests. Native GUI typing/focus/layout, graphical world rendering/touch/zoom, audible playback, multiplayer joins and simultaneous maximum-world performance remain deferred to user testing. A headless draw handle or mocked player event is not client verification.
