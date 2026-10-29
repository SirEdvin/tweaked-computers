# Proposal

## Why

Computer programs can find recipes but cannot inspect the item and fluid properties needed to size storage, plan reference rocket loads or interpret fluid temperature bounds. A dedicated Factoriopedia Interface should expose that installed-game metadata without hardcoded vanilla values or access to native game objects.

## What Changes

- Add a distinct, read-only physical Factoriopedia Interface with public peripheral type `factoriopedia_interface` and item/recipe identifier `tc-factoriopedia-interface`.
- Provide the agreed `getItem(name)`, `getFluid(name)`, `listItems()` and `listFluids()` methods, plus the existing peripheral convention `getLimits()`. Lookup methods return detailed detached records; list methods return names only.
- Limit the catalogue to installed items and fluids, including modded entries. Keep entity/technology catalogues, recipe searches, production-chain analysis and obtainable-temperature discovery outside this change.
- Expose item stack size, native item weight and reference rocket capacity in individual items, plus a small explicit fuel/spoilage/placement/import metadata schema. Expose the fluid's native default/minimum and maximum temperatures, heat capacity and fuel properties. The companion Lua contract defines units, optional fields and baseline-quality semantics.
- Use the installed `default_rocket_lift_weight` and resolved item weight for a mass-limited reference count, not a hardcoded vanilla number, a stack count or free space in a particular silo. Zero-weight items have no finite mass-limited count. Native tooltip/rounding parity is an implementation acceptance gate, not a verified result of this proposal.
- Use complete, deterministic name arrays with explicit refusal under existing shared Data/work limits; add no feature-specific catalogue-count cap, pagination, cache or background index.
- Reuse the user-approved Recipe Searcher balance: 1×1 footprint, 30 kW, one Network endpoint supporting red and green wires, and a two-second recipe using 10 steel plates, 5 advanced circuits and 2 processing units. Unlock the new recipe through the existing `tc-recipe-searcher` technology; add no technology or science cost.
- Add identity/status-only native inspection, a distinct Service Rack visual identity, localized presentation, discoverable help, player API documentation and a runnable guest example. Preserve existing device behavior and native Factoriopedia UI.

## Capabilities

### New Capabilities

- `factoriopedia-interface`: Powered, network-authorized item/fluid catalogue discovery and metadata snapshots, including reference rocket capacity and intrinsic fluid temperature bounds. Includes the companion `specs/factoriopedia-interface/lua-api.md` contract.

### Modified Capabilities

- `peripheral-inspection`: Extend ordinary identity/status-only native inspection to the new peripheral without adding a catalogue-browser GUI.

## Impact

- Physical integration: `scripts/device-definitions.lua`, `prototypes/devices.lua` and existing registry/lifecycle/unlock paths. Configuration reconciliation must enable the new recipe on forces that already researched Recipe Searcher while preserving existing identities, data, wires and research.
- Runtime integration: a focused new service module, the closed family registration in `scripts/services/peripheral.lua`, and control-parsing imports in `control.lua`. Reuse the existing guarded service/result boundary; no general sandbox or scheduler rewrite.
- Presentation: current Service Rack source/generator and provenance inventories, locale, inspector model/view, computer peripheral icons, Reference/help and example/documentation tooling.
- Verification and delivery: actual guest method inventory and factory fixtures, metadata/data-stage fixtures, packaged base/Space Age checks, cold load and pre-feature upgrade, native-client appearance/tooltip comparison and connected-client determinism. Extend the explicit contract package inventory only when implementation publishes the authoritative capability documents; never package this change's planning files.
- Version baseline: current `info.json`, runtime sources and smoke harness target Factorio 2.1.23 in base-only and optional Space Age modes. Some durable lifecycle/recipe specs and host instructions still mention 2.0.77; record that drift rather than silently downgrading this feature or broadening this proposal into an engine migration.
- No new runtime dependency, persistent catalogue schema, modification to Recipe Searcher's methods, entity/technology API, localization service or world-mutating API. The unrelated `add-dashboard-peripheral` change remains untouched.
