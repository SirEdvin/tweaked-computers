# Design

## Context

See [proposal.md](proposal.md) for motivation and approved scope, and [the capability](specs/recipe-searcher/spec.md) / [Lua API contract](specs/recipe-searcher/lua-api.md) for observable behavior.

### Observed integration points

- `scripts/device-definitions.lua:3-21` owns the closed physical family, costs, dimensions, power and prototype-name lookup. `prototypes/devices.lua:4-84` generates the selectable Network shell, private power carrier, item and recipe from it. `scripts/lifecycle.lua:58-93,124-172` already supports single-Network bodies without an extra selectable socket.
- `prototypes/devices.lua:109-113` grants every definition through `tc-circuit-computers`; `scripts/lifecycle.lua:441-448` independently enables every device recipe when that technology is researched. Both must change together. Existing tests in `tests/device_engine.lua:173-184` encode the same all-devices assumption.
- `scripts/services/peripheral.lua:11-33,130-159` has a closed family map and fixed host-provider registration. Its invocation boundary handles identity, reachability, power and protected dot-call facades. `control.lua:13-18,39` imports providers while parsing control; `scripts/registry.lua:57-77` already stores ordinary peripheral identities generically.
- `scripts/runtime/sandbox.lua:212-270` validates and copies service inputs/results under current work/allocation limits. `scripts/runtime/data.lua` is a second host Data-copy helper with distinct capacity accounting; blindly composing both would duplicate copies and can produce the wrong error contract.
- The shipped `info.json` pins base and optional Space Age to 2.0.77. The installed headless binary reports 2.0.77 build 84539. The inspected version-matched source of API details is the local official schema at `gameitself/base-2.0.77/factorio/doc-html/runtime-api.json`, not the latest web documentation.
- That schema exposes `prototypes.recipe`, `prototypes.recipe_category`, `get_recipe_filtered` with `has-product-item`/`has-product-fluid`, `LuaRecipePrototype.has_category`, `category`/`additional_categories`, `Ingredient`, `ItemProduct`, `FluidProduct` and `SurfaceCondition`. `LuaRecipe.enabled` is force-specific while `LuaRecipePrototype.enabled` is the startup default. `LuaCustomTable` supports length and `pairs`, but not `ipairs` or save serialization.
- Artwork is generated from original Foundry sources (`assets/README.md:29-61`, `assets/foundry.py`, `assets/generate.py:135-231`). `assets/industrial.py` contains shared per-kind status/shadow positioning maps; adding only a body constructor is insufficient. `scripts/ui/editor.lua:122` and `scripts/ui/help.lua` separately enumerate peripheral presentation/types.
- `tools/build.py:14-18,57-62` explicitly packages capability contracts. `tests/api_inventory.lua` and `tests/integration_engine.lua` need the new provider plus an actual connected device, not just another expected method list.

There are no canonical specs under `openspec/specs/`. The original in-flight `add-native-circuit-computers` contracts provide lifecycle/network context. Their early Greg Flavored-only art language is superseded for the existing family by `redesign-device-experience/specs/device-lifecycle/spec.md`, which explicitly prefers original industrial artwork, and by the current shipped Foundry sources. This change extends that current family without editing historical changes. The unrelated untracked interactive-console proposal remains untouched.

## Goals / Non-Goals

Goals:

- Reuse the existing authority, power, plain-data boundary, physical lifecycle and shared accounting rather than invent a parallel peripheral mechanism.
- Keep query execution stateless, deterministic and read-only, with live force availability and complete-or-error results.
- Make independent technology ownership explicit in the shared definition path so another late-game peripheral cannot accidentally inherit the same unlock bug.
- Preserve existing device payloads and saved identities; make additive code/art/package changes with focused engine evidence.

Non-goals:

- No persistent recipe index, asynchronous query job, scheduler hook, pagination protocol, result cache or category-browser service.
- No generic provider/plugin framework, new runtime execution model, recipe mutation, production planner or research-cache invalidation system.
- No prototype-type migration for existing devices, automatic program restart, broad UI redesign or changes to unrelated shared limits.

## Decisions

### 1. One ordinary physical family and one focused service

Proposed internal kind: `recipe_searcher`; public item/recipe/technology identifier: `tc-recipe-searcher`; ordinary generated body/power names follow the current `-shell` / `-power` convention. Add the definition with the approved footprint, wattage, ingredients and `roles={'network'}`. Retain the ordinary stackable-item path because there is no user database or executable source to carry in an item.

Create `scripts/services/recipe-searcher.lua` and register only `findRecipes` and `getLimits` through the existing closed family. Add the import in `control.lua`. Use current generic physical ownership, blueprint and registry paths; add no cleanup hook because the service owns no outputs or query sessions. Do not opt into the monitor-specific callback proof-cache optimization as unrelated scope.

Alternative rejected: expose a global recipe library or overload configurator. Both bypass the requested new block or mix physical machine control with global catalogue observation.

### 2. Device definitions identify their unlock technology

Add an explicit technology owner to each device definition: retain `tc-circuit-computers` for existing devices, use `tc-recipe-searcher` only for the new one. Build technology effects and synchronized recipe-unlock reconciliation from that same ownership metadata. This replaces the two all-devices loops without creating a general technology framework.

The new technology has exactly the two approved direct prerequisites. Its science ingredients are red, green and utility only: do not add chemical or production packs merely because utility's own upstream progression requires other technologies. Keep old technology fields/effects unchanged except that the new recipe is not appended to them.

Reconciliation remains additive: enable a device recipe if its owning technology is researched; do not forcibly disable arbitrary script-enabled recipes or reset all force recipes. A new save/upgrade has the searcher recipe disabled by its prototype until its own technology unlocks it. Fresh-force behavior comes from native prototypes/effects, not an invented force-created event path.

Alternative rejected: a special exclusion only in data stage. The existing configuration-change loop would silently unlock the device on old saves.

### 3. Product-filtered native lookup, then authoritative category membership

Validate arguments, registry existence and lengths under the provider's `spend` callback. Reserve a conservative native lookup allowance based on recipe-catalogue size and query byte length before `prototypes.get_recipe_filtered`. Keep its result ephemeral; never expose or save a `LuaCustomTable`.

Use the exact product filter with a nested exact-name filter. Enumerate candidates with `pairs`; if a category is supplied, apply `prototype.has_category(category)` before admitting a match to the result set. This method has a version-pinned contract and includes additional categories without assuming that the engine's generic category filter treats them identically. Pre-charge candidate/membership work and stop at the fifty-first matching recipe, raising `E_LIMIT` before constructing its metadata or sorting an oversized list.

On success, there are at most 50 unique names. Sort with admitted byte-sensitive comparisons, then construct complete records in that order. Use product/category membership only to select recipes; no enabled, hidden, force, surface or name-suffix filter is introduced. A recipe with duplicate matching product records still yields one recipe record because the native catalogue is keyed by recipe name.

Alternative rejected: build a reverse index on initialization. It adds saved state, configuration migration, cache warming and deterministic invalidation for a read-only feature that can use native filtering. Alternative rejected: scan/materialize every full recipe on each call. Native filtering avoids constructing unrelated ingredient/product arrays.

### 4. A whitelisted full recipe snapshot, not a native-object export

Read static fields from the recipe prototype and only current enabled state from `game.forces[computer.force_index].recipes[name]`. Treat a missing force recipe for a candidate as an engine failure rather than inventing availability. No force-local enabled value is cached, so normal research and another mod's runtime changes are visible immediately on the next call.

Project only the fields in `lua-api.md`, preserving engine ingredient/product order, optional presence, probability/ranged amount distinctions and fluid modifiers. Additional category names are canonicalized as a sorted unique array. Convert absent native surface conditions to an empty array, and represent open infinite surface bounds with absent min/max so the public value remains finite Data without losing its meaning. Refuse other unrepresentable metadata explicitly.

Construct records through a small provider-local metered projector. Bound cumulative node/byte/container work as fields are staged; use the existing guest snapshot boundary for the final defensive copy. Align its result-limit diagnostics with `E_LIMIT` rather than accidentally surfacing host state-storage `E_CAPACITY` from an unnecessary whole-result `data.copy`. Preserve ordinary work charges and fatal budget controls; do not catch and translate `E_BUDGET` into a retryable result.

Alternative rejected: return raw native ingredients/products or `LuaRecipe` objects. This leaks opaque values and leaves the exposed schema/ownership to engine internals. Alternative rejected: compute a generic `researched`, `craftable` or `is_recycling` flag. Force-enabled state and actual category membership are precise; those inferred flags are not.

### 5. Fifty is a result ceiling, not a CPU guarantee

Expose `recipe_search_results=50` only through this provider's `getLimits`, alongside common limits. The fixed result ceiling is not configurable. Existing callback work, aggregate host work, snapshot bytes, node/depth and allocation limits remain unchanged and can independently refuse a query.

The native filter still traverses engine catalogue structures, and reading native ingredient/product properties can materialize arrays before Lua can inspect them. A count cap alone does not bound that C++ work or pathological mod metadata. Pre-charge conservative native-query work before calling it; validate and meter all Lua-side scans, sorts and projection. Measure ordinary queries, zero-match/catalogue-heavy queries, exactly-50 records, oversized metadata and repeated calls under the production scheduler beside a neighbor. Derive a conservative admission coefficient from that evidence without raising global budgets. Treat unacceptable native scan cost as a failed performance gate, not permission to silently truncate, add pagination or claim fixed-time lookup.

No cache-based fast path is planned, so warm/cold peers share the same logical work path and no ordinary-load reconstruction changes results or resets credits.

### 6. Additive visual and documentation integration

Add a scanner/archive constructor to `assets/foundry.py`, extend only necessary shared per-kind positioning maps in `assets/industrial.py` and the family contact-sheet inventory, then export socket metadata from actual Lua definitions and regenerate production art/manifest. Keep existing PNG payloads unchanged; changed source-dependency hashes in the manifest are expected, unrelated pixel changes are not. Produce a distinct silhouette rather than recoloring the KV icon.

Add English entity/item/recipe/technology names and descriptions; add the existing inspector icon and help topic without opening a new device GUI. Extend player discovery/getting-started/API docs and a maintained `examples/recipe-searcher-program.lua`. Integrate that example through the existing example/documentation tooling and real factory fixture.

Explicitly add the new spec and companion API paths to `tools/build.py`'s contract inventory. Update `tools/test_build.py`'s extension-set assertion: it currently assumes every extension belongs under the monitor change, so appending another path without adjusting that assertion produces a false regression. Do not package proposal/design/tasks or orchestration material.

## Risks / Trade-offs

- Native filter cost is opaque and catalogue-dependent → pre-charge before entry, meter all controllable work, run real-tick contention/latency checks and record native-versus-Lua scope. Fifty results is not a UPS guarantee.
- A category can itself have more than 50 matches → keep explicit `E_LIMIT`; no automatic pagination or changed user-approved contract.
- Small result counts can contain very large ingredient/product lists → bound projection and final snapshots independently; require real fixtures for metadata overflow and an exactly-50 small-record success.
- Modded names/categories and additional categories can expose vanilla-only assumptions → validate through installed registries and test synthetic third-party recipes in the actual engine, including duplicate products and additional categories.
- Force state can change after a prior snapshot → document snapshot-at-call semantics, read live enabled values and test script changes as well as research.
- Shared generator/fixture inventories assume five devices or one unlock technology → update explicit inventory expectations and technology assertions, retaining stronger checks for the unchanged family rather than weakening them.
- Artwork manifests include the definition file's hash → regenerate exported layout and provenance; verify old pixel hashes and exact packaged bytes, not only startup.
- The branch contains another untracked proposal → scope edits and any later staging to this change; do not include or rewrite that work.

## Verification Strategy

1. Add `tests/recipe_searcher_data.lua` and `tests/recipe_searcher_engine.lua` as proposed fixtures. Data-stage checks lock prototype geometry, recipe, technology/science prerequisites and unchanged prior effects. Test-only prototypes create item/fluid namespace overlap, hidden/locked/recycling/modded producers, additional categories, ranged quantities, temperatures, surface bounds and independent 50/51-match boundary products.
2. Exercise compiled guest source through real wired production providers, not only direct host calls. Assert exact method inventory, sorted complete records, nil/empty distinctions, invalid-domain/arity errors, mutation isolation, category-before-cap behavior, force freshness, unpowered limits and stale captured calls. Add the fixture to the fixed production-context allowlist in `control.lua`; do not let a companion mod double-own the physical registry.
3. Use actual engine research and separate-process configuration changes for independent unlocks. `tools/smoke.py` already has `--data-fixture`, `--production-context`, `--cold` and `--upgrade-fixture`; extend its existing fixture contract only as needed. Test installing into a pre-feature save separately from a configuration change after new-tech research. Retain an ordinary cold reload separately so configuration repair cannot hide on-load mutation.
4. Test zero/exhausted credits, repeated calls, maximum accepted small records, large rejected metadata and an active neighboring program on the real scheduler. Save spent same-tick credits and validate no renewal in a new process. Keep synthetic boundary checks distinct from actual-tick responsiveness.
5. Build a deterministic ZIP outside git and run relevant runtime, integration, lifecycle, new-feature and art/package regressions in both base and Space Age. Verify examples through the real compiler/services. Extend package/documentation assertions without changing prior contracts.
6. Inspect full-client screenshots of every cardinal view, icon, power states and red/green wiring beside existing devices/vanilla machines in both engine configurations. Reuse the documented isolated full-client workflow; no new graphical-input behavior is introduced. Check connected multiplayer query ordering/force state and reload behavior with a real joining peer before claiming that acceptance. Retain unavailable graphical/multiplayer evidence as explicitly unverified, not inferred from headless passes.

All implementation execution is deferred to the apply workflow. No engine feature or rendering acceptance is claimed by this planning change.

## Migration Plan

1. Ship additive prototypes/service and technology-owner metadata; do not bump or reset saved root representations solely for a stateless provider.
2. On permitted synchronized configuration change, run existing physical upgrade/reconciliation and the corrected per-device technology unlock logic. Do not mutate `storage` or execute guest code during `on_load`.
3. Confirm a pre-feature save retains existing IDs, wires, source/state and recipe unlocks without granting the new recipe. Confirm a later researched-searcher save keeps its independent unlock.
4. Back up saves before upgrading. Downgrading removes unknown new prototypes through normal Factorio mod compatibility behavior and is not a lossless rollback for placed searchers/items; restore a pre-upgrade backup for a lossless rollback. No automatic downgrade migration or destructive cleanup of unrelated devices is added.
