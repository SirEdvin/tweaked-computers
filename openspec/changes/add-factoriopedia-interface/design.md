# Design

## Context

See [proposal.md](proposal.md) for motivation and approved scope, [the capability](specs/factoriopedia-interface/spec.md) for behavior, and [the Lua API](specs/factoriopedia-interface/lua-api.md) for the exact returned schema.

This design is required because a new physical peripheral crosses prototype creation, authority, plain-data transfer, research reconciliation, art, inspection and packaging. It does not introduce a new architectural layer.

### Observed integration points

- `scripts/device-definitions.lua:3-25` owns the closed physical family, dimensions, power, ingredients and technology ownership. `prototypes/devices.lua:4-83,109-120` generates shells, helpers, items, recipes and per-technology effects. `scripts/lifecycle.lua:480-487` already performs additive unlock reconciliation using each definition's technology.
- `scripts/services/peripheral.lua:12-28,135-180` owns the closed public-type/provider inventory and the identity/path/power boundary. `getLimits` is the existing power exemption. `control.lua:14-19` imports the service modules during control parsing, and its production fixture allowlist begins at line 59.
- `scripts/services/recipe-searcher.lua` supplies the nearby stateless metadata-provider pattern, including native-error conversion, metered reads and detached field projection. Its recipe projector, fixed 50-result ceiling and force-recipe lookup are recipe-specific; copying them wholesale would add irrelevant behavior.
- `scripts/runtime/sandbox.lua:248-281,329-359` already admits/copies ordinary service arguments and results under current Data/work/allocation rules. `scripts/runtime/limits.lua:12-17` includes `table_entries=1024`, `data_nodes=4096` and `peripheral_call_bytes=65536`. The direct native circuit exception is explicitly limited to the Logic provider; it is not a general large-result path.
- `scripts/ui/peripheral-inspector-model.lua:11` has a closed supported-kind set. `scripts/ui/peripheral-inspector.lua:72-75,207-210` separately maps types and identity-only state. `scripts/ui/editor.lua:133`, `scripts/ui/help.lua` and `scripts/ui/tutorials.lua` supply further presentation/help integration.
- `assets/README.md:1-39` and `assets/generate.py:137` identify `assets/service_rack.py` as the active selected artwork source. Historical Recipe Searcher design text naming Foundry as the active family is no longer the right implementation guide. Shared contact/status helpers remain in `assets/industrial.py` and layout is exported from device definitions.
- `tests/api_inventory.lua:13-34` verifies methods through real compiled guest source. `tests/integration_engine.lua:16-18,61-63,198-205` explicitly builds devices and executes examples; merely appending a type name would fail that scene. `tests/recipe_searcher_engine.lua` is the nearby native fixture pattern.
- `tools/build.py:13-50,89-91` explicitly packages canonical capability/API documents and excludes change planning. `tools/test_build.py:254-257` checks exact contract inventory/count. `tools/player_docs.py` separately enumerates examples and generates player-facing material.

### Version and primary-source evidence

The actual checkout declares Factorio 2.1.23 in `info.json`, and `tools/smoke.py:103-105` rejects other engines. Existing durable lifecycle/recipe specs, historical evidence and supplied 2.0.77 host paths lag that declaration. This change targets 2.1.23, preserves existing behavior and records the drift; it does not silently edit unrelated global engine requirements or pretend the 2.0.77 installation validates new behavior.

The following versioned official sources were read during planning through direct HTTP retrieval; both JSON schemas reported `application_version: "2.1.23"`:

- `https://lua-api.factorio.com/2.1.23/runtime-api.json`: `LuaPrototypeBase`, `LuaItemPrototype`, `LuaFluidPrototype`, `LuaPrototypes`, `LuaCustomTable`, `UtilityConstants` and `Weight`.
- `https://lua-api.factorio.com/2.1.23/prototype-api.json`: native item weight/import/orbit properties.
- `https://lua-api.factorio.com/2.1.23/auxiliary/item-weight.html`: resolved weights are engine-derived; zero-weight cursor/spawnable entries exist.
- `https://lua-api.factorio.com/2.1.23/prototypes/FluidPrototype.html`: default temperature also means minimum; gas temperature controls visual presentation, not production feasibility.

Important observed details: 2.1 uses plural `fuel_categories`; `get_spoil_ticks` accepts an optional quality; `default_import_location` is a native reference rather than a universally hardcoded location; `default_rocket_lift_weight` is specifically used for the Rocket capacity item tooltip. `send_to_orbit_mode` describes standalone launch-to-orbit behavior and is not a filter for platform cargo. These observations establish available source fields, not runtime or tooltip acceptance.

## Goals / Non-Goals

Goals:

- Add one ordinary physical family and one focused stateless provider using established authority and transfer boundaries.
- Keep direct lookups proportional to their requested metadata rather than unrelated installed catalogue size.
- Make omissions, numeric units, baseline quality and resource refusal explicit enough to test through the real guest API.
- Extend the existing art/inspection/package paths without changing unrelated visuals, capacities or saved state.

Non-goals:

- No generic prototype serialization framework, extra runtime library, data-stage metadata mirror, localization subsystem or new mod-setting surface.
- No per-device cache, persisted query catalogue, asynchronous job, pagination, whole-VM rewrite or generalization of circuit-only native-array privileges.
- No special owner state or output cleanup hook for this read-only provider; no native Factoriopedia UI scraping or replacement.

## Decisions

### 1. Reuse the existing physical and research paths

Add internal kind/public type `factoriopedia_interface` with public item/recipe name `tc-factoriopedia-interface`; use the ordinary `-shell` and `-power` generated names. Its definition uses the confirmed Recipe Searcher dimensions, power and ingredient list, with `roles={'network'}` and `technology='tc-recipe-searcher'`.

The existing technology-effect builder automatically adds the new recipe to that technology's effects, and additive lifecycle reconciliation covers already-researched forces. Exercise those paths rather than introducing another technology, migration-specific unlock routine or special research event. Preserve existing research costs and the existing Recipe Searcher recipe.

Use the ordinary stackable item path; this device has no user payload to serialize. Reuse the generic placement, rotation, blueprint, clone, mining and helper ownership rules. Adding a new family must not trigger replacement or re-identification of existing devices.

Alternative rejected: extend Recipe Searcher's methods instead of building a new device. The user explicitly requested a new peripheral. Alternative rejected: a global library, which would bypass the physical requirement.

### 2. A small service with a fixed field schema

Introduce `scripts/services/factoriopedia-interface.lua` (new), add its closed kind to `scripts/services/peripheral.lua`, and import it in `control.lua`. Register the four feature methods and common `getLimits`; do not add a new callback-stability optimization or per-tick maintenance hook.

Direct lookups validate strict arity and exact nonempty names, then use the matching native item/fluid registry. Build only the whitelisted record in `lua-api.md`. Use a short shared projection of common fields and focused item/fluid projections; names are extracted from native references, never recursively serialized. Use small provider-local validation/metering helpers only where repeated reads actually need them.

Read `get_spoil_ticks('normal')` explicitly. Normalize absent `fuel_categories` to an empty array, while preserving the optional reference distinctions in the contract. Return the requested prototype's metadata even when `factoriopedia_alternative` exists. No quality selector is added to the approved one-name signature.

The existing guest service boundary supplies final defensive ownership. Do not add a second whole-result `data.copy`, expose native objects, or refactor the established Recipe Searcher projector merely to share a few primitive assignments. Native read failures map to `E_ENGINE`; guards and metered work remain outside any wrapper that could swallow fatal budget state.

Alternative rejected: dump every prototype field. Native subtype objects, localised strings, trigger trees and references would leak or create an uncontrolled schema far beyond the approved catalogue.

### 3. Reference rocket count is derived from resolved native values

Use native `weight` and `prototypes.utility_constants.default_rocket_lift_weight`. Compute the contract's whole-item quotient for positive weight and omit the count at zero weight. Keep stack size independent; expose the source quantities alongside the result. Validate representability and do not invent a configurable numeric quota.

Do not scan recipes to reconstruct weights, select a physical silo, clamp to inventory slots or use `send_to_orbit_mode` as a cargo filter. These would answer different questions. Fractional-weight flooring, overweight items, changed utility constants and zero-weight entries receive explicit fixtures.

The public contract defines a reference mass count, not a promise about every modded silo's feasible load. Native tooltip comparison is a blocking implementation acceptance gate. Preserve a discrepancy for review rather than introducing unproven epsilon arithmetic or claiming the documentation lookup already proved parity.

### 4. Name enumeration remains complete-or-error under current shared limits

Enumerate the selected native catalogue with `pairs`, building names only. `LuaCustomTable` is not a plain Lua array: do not use `ipairs`, return it to guests or save it. There is no retained iterator or authoritative cache.

Account admitted lookup/enumeration work, each actual name's bytes and actual sort comparisons. Track the existing result entry/node/byte bounds while building so an impossible list fails before unbounded staging; these are the existing common values, not another provider count setting. Sort the detached names in bytewise order and return exactly one complete array. A single lookup must not enumerate the catalogue or charge unrelated registry sizes.

Reuse the ordinary snapshot boundary and fatal work/allocation behavior. Do not silently truncate, automatically retry, reset credits, return a cursor, bypass the sandbox or raise production limits to make a large catalogue pass. Existing generic `table_entries=1024` means some modpack inventories will refuse; documentation must state that limitation. Large-catalogue support beyond shared Data capacity is not smuggled into this change.

Alternative rejected: return every detail record from `listItems`/`listFluids`, which would defeat the approved names-only API and amplify costs. Alternative rejected: a persisted reverse index or background job, which adds lifecycle obligations with no demonstrated need for the chosen complete-array contract.

### 5. Preserve identity-only inspection and existing artwork

Add the new kind to the existing inspector support/type maps and the same identity-only branch used by Recipe Searcher. Avoid leaving a powered identity-only device permanently labeled pending. Inspection reads status/identity only, not the metadata catalogue, and retains existing player/session authorization, selectable name, close/Escape and no-power behavior.

Add a distinct compact catalogue-terminal silhouette to `assets/service_rack.py`, with one ordinary Network contact pair and the existing status vocabulary. Reuse contact/status rendering helpers and existing export/provenance infrastructure. Add only the required device inventory mappings, icon, sprite sheets and locale text; no new technology icon is needed because research is shared. Regenerate layout/art metadata as required, while asserting all pre-existing PNG payloads remain byte-identical. New manifest source hashes are expected; unrelated pixel changes are not.

Alternative rejected: recolor Recipe Searcher's scanner or clone the computer body. The new block must be distinguishable without a label while keeping the selected visual family.

### 6. Publish one coherent contract and runnable example

Add the new type/icon and documentation through editor peripheral display, in-game Reference/help, localized names, player getting-started/API pages and example tooling. A new `examples/factoriopedia-program.lua` is proposed following the repository's source-document packaging convention. Execute its source in an actual wired factory scene, including the accepted method inventory; do not treat a compiler-only check as service acceptance.

During implementation, publish the new capability and companion Lua contract to their canonical `openspec/specs/factoriopedia-interface/` paths through the normal spec-sync process. Add those canonical files to `tools/build.py` and package tests. Do not point the production archive at `openspec/changes/` or ship proposal/design/tasks. Apply the inspector delta through the same workflow. This proposal phase writes only change artifacts.

## Risks / Trade-offs

- Existing shared Data limits can reject large catalogues → state complete-or-error behavior, test genuine overflowing registries and keep individual lookup independent. Do not present the API as unlimited or loosen unrelated limits.
- Native catalogue work and property materialization are not fully characterized by Lua charges → measure exact packaged base/Space Age and catalogue-heavy cases beside an active neighbor. Meter controlled work without claiming a C++ timing or allocator upper bound.
- Fixed-point native weight and floating-point quotient behavior can expose edge rounding → compare representative and deliberately fractional weights against the pinned client, retaining failures. Zero-weight semantics are explicit and do not use infinity.
- Some native references or quality-sensitive fields differ between content modes → exercise actual normal-quality spoilage, native import locations and absent references in base and Space Age, not a hardcoded Nauvis fallback or mocked metadata alone.
- Existing specs/instructions mention the older engine → verify the actual 2.1.23 executable/data before every acceptance lane, and keep legacy documentation drift visible rather than running the wrong engine.
- Shared closed family inventories and art hashes can miss the new kind → cover runtime discovery, actual factory placement, native inspectors, generated docs and exact archive contents together.
- Concurrent dashboard/other peripheral changes may touch the same closed maps → keep this change's files isolated and merge capability entries without replacing another family's methods or assuming a forever-fixed device count.

## Migration Plan

1. Ship additive prototypes/service/art/help and the new shared-technology recipe effect. No saved root/schema bump or catalogue migration is required for a stateless provider.
2. During permitted configuration change, use existing additive unlock reconciliation. An already-researched Recipe Searcher force receives the new recipe; a force without that research does not. Do not reset unrelated recipe/research state or existing device identities.
3. Prove ordinary cold load separately from a pre-feature configuration-change upgrade. Load must not query, mutate state, renew credits or replay guest startup. Saved plain-data snapshots remain ordinary application data.
4. Verify removal/mining/clone/blueprint paths and stale binding refusal with existing helper semantics. No service-owned query payload is transferred in items.
5. Back up saves before upgrading. Downgrade removes unknown new prototypes and is not a lossless rollback for placed new devices; restoring a pre-upgrade save/package is the lossless rollback path. No destructive automatic downgrade cleanup is introduced.

## Verification Strategy

- Native data/runtime fixtures lock the approved recipe/technology/power/geometry and compare the public schema with actual installed prototypes, including item subtypes, hidden/parameter/modded entries, namespace collisions, alternative display IDs, missing references, normal-quality spoilage and fluid boundaries.
- Runtime coverage uses compiled guest calls over actual red/green wires, with complete lists, exact ordering/arity/errors, defensive mutations, current limits, power loss/restoration, force/surface isolation, detach/replacement and passive relay. Include cold state retention and already-spent credits; maintain a neighboring runnable computer during repeated queries.
- Distinguish native metadata assertions from host-only injection of engine errors, zero credits and unrepresentable values. Run a real enlarged catalogue beyond the existing shared boundary and prove explicit refusal without a prefix or failure of otherwise affordable exact lookups.
- Build the candidate outside git and exercise `tools/smoke.py` in both modes with the new approved data/production fixture and a separate-process cold run. Extend the current harness only where required. Use a same-engine immutable pre-feature archive for upgrade; do not misapply the historical 2.0-to-2.1 Recipe Searcher upgrader as proof of this additive 2.1 feature.
- Full-client acceptance inspects every cardinal view, both wire contacts, icon/status, ordinary inspector opening/copy behavior and the native Factoriopedia rocket/temperature presentation. Keep generated contact sheets, headless results and actual client evidence separate.
- Connected-client acceptance compares query/list snapshots and identity behavior on real synchronized peers, including a joining client and ordinary reload. Absence of these runs remains an unmet gate, not inferred success.
- Final package checks include method/contract inventories, documentation freshness, example execution, unchanged pre-existing artwork and exclusion of game distributions and planning files. Preserve selected logs, hashes, screenshots and failed attempts outside git.

All feature implementation and execution acceptance remain pending. Only planning/schema/source inspection was performed to create this design.
