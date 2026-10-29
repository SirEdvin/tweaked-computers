# Design

## Context

See [proposal.md](proposal.md) for motivation and [the Lua contract](specs/production-statistics/lua-api.md) for exact signatures, shapes and errors. This design is required because a new physical peripheral crosses prototypes, lifecycle, sandbox services, inspection, documentation and native acceptance.

Observed baseline: `origin/main` at `136b3a6` has `info.json` version 0.1.16 targeting base/optional Space Age **2.1.23**. The current service uses non-yielding guarded callbacks; this is not the separate experimental durable-runtime work. The relevant existing integration points are:

| Area | Observed implementation | Planned use |
| --- | --- | --- |
| Device family | `scripts/device-definitions.lua`, `prototypes/devices.lua` | Register one additional single-role device; reuse shell/power/item/recipe generation |
| Lifecycle/progression | `scripts/lifecycle.lua`, especially the technology-owned recipe reconciliation | Reuse owned helpers, current identity rules and existing-force unlocks |
| Guest access | `scripts/services/peripheral.lua`, `scripts/services/recipe-searcher.lua`, `control.lua` | Add one closed service binding, loaded during control parsing |
| Authority | Peripheral facade checks identity/generation, force, surface, wire proof and power before dispatch | Keep unchanged rather than adding a second access path |
| Accounting | `scripts/runtime/limits.lua`, existing guard/service and Data transfer | Preserve common work/allocation/shape/byte protections |
| Inspector/UI | `scripts/ui/peripheral-inspector-model.lua`, `peripheral-inspector.lua`, `editor.lua`, `help.lua` | Extend closed family maps; use identity/status-only inspection |
| Artwork | `assets/service_rack.py`, `assets/sprites.lua`, manifests and provenance | Add one distinct industrial instrument without changing existing six device assets |
| Coverage/docs/package | `tests/api_inventory.lua`, `tests/integration_engine.lua`, `tools/player_docs.py`, `tools/planning_examples.py`, `tools/build.py`, `tools/smoke.py` | Extend exact inventories and the existing packaged fixture mechanisms |

The canonical lifecycle requirement still says 2.0.77, contrary to the already-migrated manifest and current native calls. The narrow lifecycle delta corrects that requirement to 2.1.23. This is an explicit documentation conflict, not an engine migration or permission to rewrite historical verification reports. Older capability files and AGENTS examples may still carry historical 2.0 references; they do not establish current acceptance.

## Goals / Non-Goals

**Goals:**
- Make one complete native query accessible through the current peripheral facade, with exact same-scope behavior and detached results.
- Reuse native history rather than adding saved state, event processing or idle work.
- Keep data acquisition separate from presentation: normal inspection identifies the device, while guest programs choose how to display data.
- Deliver one coherent feature with its actual guest/native/UI/lifecycle coverage and packaged documentation.

**Non-Goals:**
- No new scheduler, native-circuit result exemption, global capacity change, async bulk-query protocol or generic statistics framework.
- No public native handles, statistics writes/resets, machine scan, all-surface aggregation, force selector or electric-network discovery.
- No engine upgrade, runtime rewrite, native statistics GUI replacement, or mod release during planning.

## Decisions

### 1. One stateless physical device, using existing progression

Add internal kind and public type `production_statistics`, item `tc-production-statistics`, generated shell `tc-production-statistics-shell` and power helper `tc-production-statistics-power`. Use the existing single-role layout and normal composite lifecycle. The new implementation belongs in `scripts/services/production-statistics.lua`; it registers through the existing provider table and is required from `control.lua` at parse time.

The user-selected unlock is the existing Recipe Searcher technology, `tc-recipe-searcher`. Set the statistics device definition's `technology` explicitly to that identifier rather than inheriting the shared `tc-circuit-computers` default. Preserve the technology's prerequisites, science cost and existing Recipe Searcher recipe unlock; add only the statistics recipe unlock. Circuit Computers alone must not unlock the new recipe.

Proposed review defaults, not explicit user choices: 1×1, 30 kW, stack 50 and a 2-second recipe with 8 iron plates/5 electronic circuits/2 advanced circuits. These retain the KV-sized crafting/power balance independently of the confirmed research tier. The distinctive art should read as an industrial chart/measurement instrument, not a recolored Recipe Searcher or a seventh UI theme. Reuse the production generator, contacts and materials; preserve existing sprites byte-for-byte where unrelated.

Alternative: a built-in computer global or reuse of an existing peripheral. Rejected because the requested feature is a new peripheral and the existing device model already supplies reachability, power, identity and player discovery. A separate technology adds progression the user did not request.

### 2. Scope is resolved from the live bound device

After the shared facade authorizes the call, resolve the current device surface and force through its live entity/registry. Item and fluid queries use the force's `get_item_production_statistics(surface)` or `get_fluid_production_statistics(surface)`. Pollution uses `surface.pollution_statistics`; the official game-level getter is an equivalent source but not an additional public API.

```text
computer + explicit wire
          |
          v
existing facade: identity + physical authority + power
          |
          v
production_statistics provider
          |
          +--> force + own surface --> item / fluid statistics
          |
          +--> own surface --------> pollution statistics
          |
          v
detached plain snapshot --> existing service/Data admission
```

Do not use a current player's selected GUI surface, a remembered force, an arbitrary global default surface, circuit signals or a graph of machines. Pollution intentionally includes the native surface-wide sources/sinks, even when multiple forces occupy that surface. That is the approved data boundary, not a missing force filter.

### 3. Native map shape removes unnecessary projection work

The approved bulk-versus-single split is expressed with three statistical methods plus the ordinary `getLimits` method. The exact contract is in the companion; no overloads or optional selectors are needed.

- `getTotals(kind)`: capture each native direction map once. For items use `input_quality_counts` and `output_quality_counts`; for fluids/pollution use `input_counts` and `output_counts`.
- `getRates(kind, window)`: use those same direction-specific inventories and query each recorded key through `get_flow_count` without `sample_index`, explicitly setting `category` and `count=false`. Preserve keys with a zero current rate.
- `getHistory(kind, name, window, quality?)`: query the selected identity's input and output samples at every native index 1 through 300. Construct two dense numeric arrays with native newest-first order. Resolve item quality to normal when omitted; reject non-nil quality for other categories.

Return `{tick, input, output}`. Item maps are nested by quality then item name; other bulk maps are keyed by native name. Do not flatten, sort, merge the two direction inventories, synthesize absent opposite-side zeros or add redundant metadata vectors. History does not enumerate every recorded item. For ordinary item/fluid identities it can validate directly against the matching prototype registry; a non-prototype pollution key may require lookup in the native count maps.

Alternative: sorted arrays of `{name, quality, produced, consumed}` rows. Rejected because they require a union, sorting and additional table allocations while obscuring native key/direction distinctions. Separate production/consumption method families would unnecessarily multiply the public API. A single operation-mode method would contradict the user's explicit separate-method choice.

### 4. Native semantics, not reconstructed charts

Map the eight documented precision strings to the pinned `defines.flow_precision_index` symbols. Factorio 2.1 uses the `category` string argument; do not copy a legacy `input=true` call from older examples. For these non-electric categories, rates and historical samples are already per-minute; copy them without an extra unit conversion. Totals come from native counters, not integrated rates or a sum over chart samples.

`tick` records the query tick, not an invented bucket boundary. Keep the engine's update timing, partial-window behavior and reset semantics. Do not fold unmerged current-tick samples into a query. Native UI rounding, sample boundaries and verified pinned-engine graph smoothing are presentation-only comparison concerns: retain the burst fixture and compare every raw API sample directly with `get_flow_count`; never smooth API data.

Pollution is the native surface statistic, including the active pollutant behavior on Space Age surfaces. Do not hard-code Nauvis, assume every surface emits ordinary pollution, omit sinks whose native key lacks an entity prototype, or substitute `get_total_pollution()`/chunk scans. Pin native fixtures for these identities and the available pollutant modes before treating the mapping as verified.

### 5. Existing protections, with no new policy layer

The existing source has finite Data shape/byte limits and guarded callback/shared work. Keep them. A complete native inventory that fits returns in full; one that does not fit refuses explicitly. Bulk success is not an unbounded-size promise, and no statistics-specific cardinality limit is introduced.

Reuse the ordinary service result transfer and Data validation. Do not deep-copy a result solely to validate it and then immediately discard that copy. Meter actual native calls, input validation, key traversal and output construction through the existing accounting. Native getters can themselves materialize tables; retain that limitation in verification rather than claiming a Lua work counter precisely bounds C++ wall time or allocation.

The service is read-only, so a failed result admission has no world-side rollback obligation. It still must not publish partial data, leave a retained query job, renew credits or weaken authority. Do not introduce a continuation machine or exempt this service from common Data protections to make an oversized case pass. If representative native queries cannot fit the unchanged envelope, preserve the failing evidence and reopen that specific API/resource decision before expanding scope.

Alternative: persistent collector/cache, top-N truncation or pagination. Rejected because native history already exists, the user selected complete bulk totals/rates, and those alternatives add state or change the approved contract. Native snapshots are not automatically exempt from every guest transfer protection.

### 6. Reuse identity-only inspection and complete the inventories

Extend the closed family/type/icon maps in the service registry, inspector model/presenter, editor and contextual Reference. Give the new device the Recipe Searcher's identity/status-only inspection path: do not call statistics APIs while opening or refreshing that inspector. This avoids a second bulk-data UI and unnecessary polling under load.

Maintain a small self-contained Reference example and the equivalent packaged example. A separate monitor example uses the existing monitor methods to display rates and both historical directions; it receives historical samples directly rather than accumulating a second series. If a display draws oldest-to-newest left-to-right, change its indexing at presentation only, not the API's native-order arrays.

Extend `tests/api_inventory.lua` and the actual integration scenes together: an unconditional new expected family requires a real device in those scenes. Do not merely make the family optional to hide missing setup. Update the package's explicit canonical contract list and the documentation/Reference/example inventories; a file under an active change is not automatically shipped by `tools/build.py`.

## Risks / Trade-offs

- **Large modded inventories exceed existing envelopes** -> Complete-result refusal is explicit in the API; exercise both meaningful bulk success and real refusal with unchanged budgets. Do not silently truncate or add a replacement cap.
- **Native getters or repeated sample calls have nontrivial cost** -> Measure exact packaged workloads, distinguish native time from deterministic accounting, and compare repeated polling with an idle device. No new periodic service is required.
- **Pollution keys and Space Age pollutant behavior differ from ordinary prototypes** -> Exercise native sources, entity/tile absorption and relevant Space Age surfaces using direct native readback, not only host doubles. A mismatch blocks acceptance rather than justifying invented zero samples.
- **Quality or input/output normalization hides information** -> Keep the native nested maps, direction semantics and exact values. Test disjoint direction inventories and different qualities in actual guest reads.
- **Historical UI text is mistaken for current validation** -> Bind every receipt to the candidate archive and actual 2.1.23 engine. Older 2.0 graphical/client evidence is not inherited.
- **Prototype extension breaks fixed family inventories** -> Audit the source, generator, manifests, fixture builders, API inventory, inspector/Reference topics and package lists together. Preserve all existing fixture assertions.
- **An ordinary downgrade removes the new entity** -> Back up before upgrade; rollback means restore the pre-upgrade save and matching archive, not downgrade a save containing the new entity.

## Migration Plan

1. Implement additively on the current 2.1.23 baseline with no storage-schema or runtime-backend bump. Use the existing synchronized initialization/configuration-change recipe reconciliation; no load-time mutation or statistics cache recovery is introduced.
2. Exercise an upgrade from the immutable previous release on a copied save: already-researched Recipe Searcher unlocks the new item, forces with only Circuit Computers researched remain locked, and pre-existing devices/data/wires survive. Fresh completion of Recipe Searcher unlocks both its existing recipe and the new statistics recipe without changing research costs or prerequisites.
3. Synchronize the approved capability/API documents through the normal OpenSpec finalization workflow before an installable distribution relies on canonical package inventory entries. Do not teach the runtime packager to depend on active change directories. Preserve unrelated active changes and historical reports.
4. Build and verify the exact candidate against base and Space Age, with cold reload, actual client and connected-peer gates recorded separately. Record failed or unavailable gates honestly; no release is authorized by this plan.
5. Keep existing signatures and identities compatible. A release, version bump or Mod Portal upload is a separate authorized delivery action after implementation acceptance.

## Verification Strategy

- Provider/contract checks: arity/type/range errors, all windows, native name/quality mapping, complete direction-specific maps, empty/zero/fractional data, 300 samples per side, detached mutation and injected native failure. Label host doubles separately.
- Actual guest integration: query through `peripheral.find`/`wrap`/`call` under the real compiler, service transfer and guard, comparing each value/key to direct native observations at the same controlled tick. Assert method inventory and no write/reset method.
- Scope and lifecycle: two forces/two surfaces, pollution shared within one surface, power outage/restoration, wrong wire, detach/replacement, force/surface changes, clone/mine/blueprint and separate-process reload. Confirm no statistics collector/state is created.
- Resource checks: repeated reads consume shared budgets, complete results refuse atomically when an existing limit is reached, a successful representative history/whole-inventory query reaches the caller, and an idle installed device does not create a new per-tick statistics loop. Keep timing claims separate from work counters.
- Native client: compare the three categories against their real statistics displays, inspect all cardinal sprites/contacts and the identity-only inspector, execute Reference and monitor workflows, and preserve images outside the repository. Do not treat screenshot generation or headless startup as UI acceptance.
- Multiplayer: actual connected clients plus a late join/cold restart in base and Space Age, comparing synchronized observations and inspecting desync diagnostics. Do not substitute independent headless processes for connected peers.

Planning has only source/API-documentation evidence. None of these implementation gates has run for the proposed feature.
