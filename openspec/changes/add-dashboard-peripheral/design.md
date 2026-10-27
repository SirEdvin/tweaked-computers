# Design

## Context

See [proposal.md](proposal.md) for motivation and the [Lua contract](specs/dashboard-interface/lua-api.md) for the complete proposed external interface. This artifact is planning only. Source baseline: `53f16a42c613938c1e57ae7a93b44ed99171134e` on the existing `new-specs` worktree; no implementation acceptance is inherited or claimed.

Relevant inspected integration points:

| Existing area | Evidence and consequence |
| --- | --- |
| Peripheral calls | `scripts/services/peripheral.lua:12-34,100-204` has a closed type/binding inventory, guarded method facades and explicit-wire authority. Install another provider, not a parallel discovery API. |
| Scheduled events | `scripts/runtime/computer.lua:100-135` supports trusted provider event registrations; `scripts/services/logic.lua:166-205` shows per-binding subscribe/cancel. `scripts/scheduler.lua` owns phased maintenance and callback dispatch. |
| Native windows | `scripts/ui/editor.lua:287-295` builds tabbed panes. `scripts/ui/peripheral-inspector.lua:26-39,56-82` and its model enforce actual-element session ownership, player force/surface/reach and permissions. Existing inspectors stay read-only. |
| Entity opening | `scripts/ui/interaction.lua:22-38` routes protected shells; `control.lua:24-39` already owns GUI events. Compose handlers instead of registering competing callbacks. |
| Device/data lifecycle | `scripts/device-definitions.lua`, `scripts/registry.lua`, `scripts/lifecycle.lua`, `scripts/lifecycle-data.lua` and `scripts/blueprints.lua` own physical identity, adapters and configuration copies. Prototype creation and art inventories are closed-family tables. |
| Budgets | `scripts/runtime/limits.lua` defines `state_bytes=65536`, Data/operation bounds and maintenance ceilings. A per-call bound alone would not constrain retained chart history. |
| Packaging/tests | `tools/build.py` has a canonical-contract allowlist; `tools/smoke.py` checks exactly 2.1.23 and constructs isolated mod lists. The wrapper currently has no extra-library archive input. |

`info.json` declares Factorio 2.1 with exact base/Space Age 2.1.23 dependencies, and CI/harness agree. The existing durable `device-lifecycle` engine paragraph still says 2.0.77; the narrow delta reconciles that paragraph, not another port or wholesale historical-spec cleanup. The locally documented 2.0.77 installations are not acceptance engines for this feature.

### Dependency evidence, not execution

The Mod Portal reports factorio-charts 1.2.0 for Factorio 2.1. Inspected upstream commit `ff7f6bd06a4532c8cd2bfbf0a4bd464916dbb62a` also declares 1.2.0. These observations do not establish equality to published ZIP bytes or compatibility in our engine. Relevant upstream files:

- `charts.lua`: public `surface`, `render`, `time_series` and optional interaction/event APIs.
- `charts/time-series.lua`: a single interval is already a rolling ring with sums/counts; cascading occurs only with further intervals/steps.
- `charts/line-graph.lua`: input is a ring plus sums/counts; supported `label_format` includes a function, time and percent. It draws at most `colors.get_max_series()` series and divides by `length - 1`.
- `charts/bar-chart.lua`: snapshot duration maps, phase order/colors, fixed time-axis formatting and viewport-dependent bar geometry. It does not expose a generic numeric bar-axis formatter.
- `core/rendering.lua`: private-surface creation, chunk allocation/free, camera fitting and render-state cleanup. Its convenience camera setup documents a zoom fallback caveat; use the provided fit calculation rather than assuming the default fits every UI scale.
- `core/format.lua`: duration values are seconds, not game ticks.
- `control.lua`: minimal; consumers import the library. Automatic interactive/event registration is unnecessary for static chart cameras and our own native buttons.

Primary source locations:

- Mod Portal metadata: https://mods.factorio.com/api/mods/factorio-charts/full
- Pinned source tree: https://github.com/nickelbob/factorio-charts/tree/ff7f6bd06a4532c8cd2bfbf0a4bd464916dbb62a
- Pinned native API: https://lua-api.factorio.com/2.1.23/runtime-api.json

The native API confirms `camera`, `tabbed-pane`, `flow`, `label` and `button` support and `script.active_mods`. No public production-graph widget is assumed.

## Goals / Non-Goals

**Goals:** A small declarative model mapped to existing native GUI primitives; one shared device state; explicit, validated scheduled button delivery; one optional chart adapter with paid work and owned resources. Reuse existing model validation, runtime authority, lifecycle adapters and library features.

**Non-Goals:** A generic UI framework, browser/CSS layout, editable forms, arbitrary styling, remote viewing, world-surface dashboards, custom chart drawing, library forks/patches, production-widget parity, numeric/category bars beyond upstream support, historical queries, automatic sampling, multi-resolution storage or a runtime/scheduler rewrite. Chart hover/click overlays, hatching and icons are not required merely because the library offers them.

## Decisions

### 1. Small dedicated provider and native window

Proposed new files are `scripts/services/dashboard.lua`, `scripts/dashboard-model.lua`, `scripts/ui/dashboard.lua` and `scripts/ui/dashboard-charts.lua`. Keep schema/state accounting in the model, guest entry points/subscriptions in the provider, native sessions/widgets in the UI and optional dependency/resource handling in the chart adapter. These are focused responsibilities, not a plugin registry or abstract widget framework.

Register type/kind `dashboard` through the existing closed family. Use one 1×1 powered Network-role shell and a data-bearing item. Reuse existing computer research; provisional balance reuses the monitor's inspected 15,000 W and base-material recipe rather than creating a progression tier. Record these balance defaults in implementation documentation. Add a modest identifiable control-panel body/icon through the existing asset pipeline; do not alias it indistinguishably to a monitor or redraw the six existing devices.

Add an explicit dashboard branch in normal opening before the read-only inspector path. Reuse proven title/drag/close, identity-copy, session-token and authority patterns without converting the inspector into an editable framework. Add only the required composite GUI handlers to `control.lua`; current editor, monitor, native-machine and inspector gestures remain intact.

Alternative rejected: putting configured controls inside the monitor inspector would conflate read-only inspection, terminal state and interactive UI, and would change monitor semantics.

### 2. Device model separate from viewer/render state

Store a versioned dashboard record on the existing device record: numbered tabs, their normalized definitions, layout generations and chart data/reservations. Save only plain application state in lifecycle snapshots. Keep viewer tokens, GUI references, render objects, chunk ownership and dirty presentation bookkeeping host-only, outside the application model and mined item.

Use stable widget IDs and per-tab layout identity. Text/enablement updates modify the named leaf and dirty only affected viewers. Structural replacement can rebuild the affected tab; unchanged tabs and valid selected slots/scroll remain. Compatible charts retain state by ID/data definition, while an intentional definition change resets just that chart. No whole-window rebuild for every incoming sample.

One player owns one current dashboard session. Device content is shared; selected tab, scroll and copying/focus are per viewer. Use native row/column flows and bounded scrolling instead of guest coordinates, automatic responsive breakpoints or a custom layout solver. Host viewport/window sizing follows existing resolution/scale handling.

### 3. Atomic calls and shared retained reservation

The user confirmed using the existing state-byte allowance per dashboard and a program-selected rolling capacity. Reserve the full line window at configuration time, including per-sample key/value records and sums/counts, plus the definition and private model metadata. Compute the fixed-shape reservation analytically using the same accounting convention; do not allocate an enormous empty candidate to find out it cannot fit. Also honor the existing Data depth/node/string/table/transport envelopes.

All writers and both colors share this allowance; sessions do not multiply it. Snapshot bars consume their actual retained dataset size. A `setTab` candidate accounts for retained compatible chart state, released removed state and new reservations as one transaction. Stage/refuse work before changing the model or consuming irreversible public effects; pre-admit boolean/ID results for `removeTab` and subscription methods too. Follow the existing provider/principal boundary rather than adding a second execution model.

For samples, validate the entire fixed-name numeric vector and resulting sums/ranges before the unmodified library ring mutates. A single non-cascading interval reuses `time_series.create` and `add_datapoint`; invoke the lower-level line renderer, not the high-level time-series renderer with its automatic TTL, metadata and viewer coupling. Admission includes genuine copies/validation; do not double-count nonexistent work or increase budgets to fit the feature.

Existing generic Data bounds can be stricter than bytes. The six tabs and upstream renderer-domain bounds are explicit; no new widget count, series setting or retention-time knob is invented. Finiteness includes sums, differences and bar scaling, not just each input scalar. Source inspection found that the library truncates excess line series, so refuse them before accepting the definition and expose the upstream bound.

Alternative rejected: a fixed arbitrary number of samples for every chart either wastes memory or fails to bound multiple series/tabs. Unbounded history and silently truncated successful layouts are also rejected.

### 4. Deliberately narrow optional chart adapter

Declare `? factorio-charts >= 1.2.0`, then conditionally import `__factorio-charts__/charts` during control parsing using `script.active_mods`. Do not import it inside an event or guest call. Install the chart methods only when the dependency is available. Keep renderer functions private; guest definitions are validated data, never Lua objects or executable callbacks.

Call the existing `render.line_graph` and `render.stacked_bars` APIs. Number labels for lines use the documented formatter-function option with trusted host `tostring`; this is an existing supported option, not a library change or guest formatting API. Duration bars keep the unmodified seconds axis. Render data uses the library's supplied ordering/palette; do not silently manufacture stable line colors or generic category labels.

Use one fixed design viewport for shared chart rendering (initially the library's 900×700 default) and fit it into native cameras. Derive the bar-count support boundary from that viewport and upstream spacing such that bar width stays positive; do not invent a higher count or change the spacing implementation. Host UI tuning can change camera/window size without changing accepted data or the design viewport.

First run an exact-release packaged compatibility gate with line and duration-bar data. If the selected release cannot support these calls safely on 2.1.23, stop and report the concrete blocker. No fork, shim renderer, replacement dependency or silently reduced contract is an authorized fallback.

### 5. Demand-driven, shared chart presentation

Keep one render state per visible dashboard chart, shared by cameras for all viewers of that chart; differing player UI sizes only affect camera fitting. Allocate the library surface/chunks lazily. Mark accepted updates dirty and render the newest complete model once under existing scheduler maintenance, not once per append or viewer. No render work is required while no selected tab displays that chart, but incoming data is still retained.

Pay for the complete indivisible library call and its bounded output envelope before entering it. If this tick lacks credits, preserve accepted data and show pending status while keeping a previous rendering identifiable as stale. A request that cannot fit even an otherwise fresh allowance must show an actionable refusal, not retry forever. Keep other UI and scheduler work moving without borrowing monitor synchronization or raising production ceilings.

Use explicit successful-call object ownership rather than relying on TTL for stationary charts. Pass the supported zero TTL only after verifying its native non-expiring semantics; own/destroy returned objects and library light/chunk state on final viewer close, definition removal, power/unavailability and device cleanup. If a third-party rendering failure prevents returning a complete object list, a rare recovery path can tear down only our private chart surface, invalidate its presentation records and rebuild visible charts later; histories and unrelated world/monitor rendering must survive. Do not monkeypatch native rendering or the library to collect handles.

The adapter must clean up without importing the library after dependency removal: host-retained LuaRenderObject references/private-surface ownership suffice. Deleting our surface is presentation cleanup, never a trigger to delete dashboard devices. Reuse freed fixed-size chunks and reject accidental adoption/deletion of an unrelated surface. Hide the owned surface from newly created forces too. Surface removal or invalid handles cause safe reinitialization during gameplay, not load.

### 6. Explicit broadcast subscriptions with live authority

The user selected all authorized explicit subscribers. Follow the existing provider subscription pattern, with each registration bound to dashboard identity/generation, wire, computer/run and declared handler. There is no last-writer ownership claim. Two subscriptions are intentionally distinct; redundant physical paths are not.

For a click, prove actual element ownership and player/session authority first. Freeze the tab layout identity and minimal event data. Charge fan-out using existing aggregate subscription/queue limits before guest-visible effects; enqueue through the current runtime, not a separate persistent click queue. Catch/classify each recipient's ordinary pressure/refusal path so a full or faulty recipient does not prevent other eligible deliveries.

Immediately before callback dispatch, revalidate the subscription, exact dashboard/layout/button, enabled state, recipient path/power and applicable player authority, using the established monitor-event revalidation pattern as the integration reference. Do not add `dashboard_click` to generic unrestricted `computer.on` if that would bypass the explicit per-device subscription contract. Retire affected queued entries on unsubscribe/run replacement/detachment. Existing transient-power and overflow behavior stays unchanged.

Alternative rejected: returning to only the writer is simpler superficially but contradicts shared access and the user's chosen subscriber behavior.

### 7. Durable state and configuration-only copies

Derive persistence from existing lifecycle rules rather than adding a distinct database subsystem:

- Ordinary cold saves retain accepted definitions, complete chart data, ring order and spent accounting; no source reruns on load.
- Item snapshots preserve layout and data in one versioned tagged item, with enough serialization metadata headroom beyond the accepted model. Removal is refused rather than silently dropping an unsupported/corrupt retained representation. Item placement creates a new identity.
- Blueprints, clones and settings copy serialize definitions only. New charts are empty; settings copy into an existing target uses the compatibility rules for that target's own history, not the source's history.
- Program retirement, window closure and optional-library removal do not clear model state. Dependency absence uses placeholders, not a different renderer. Full mod removal is not promised as a data-preserving operation.

Schema recovery and resource teardown occur during permitted synchronized events. `on_load` never draws, creates surfaces, revalidates the world or mutates storage.

## Risks / Trade-offs

- [Published release versus inspected source] -> Obtain and identify the exact 1.2.0 archive, inspect its manifest/API/license and record its hash; source-tree inspection is not an engine pass.
- [Opaque native/library allocation and rendering cost] -> Bound accepted inputs/reservations and prepay complete work; measure native behavior under unchanged allowances, including the full supported model and multiple viewers. Accounted bytes are not a native heap calibration.
- [Fixed renderer limitations] -> Report time-only bars, sample-order line X positions, line color ordering, palette/geometry limits and empty/single-sample behavior plainly. No promised production-graph parity.
- [Partial renderer failure] -> Validate before entry; protect private-surface ownership and retain application data during cleanup/rebuild. Exercise injected failure separately from genuine rendering acceptance.
- [Optional-library removal leaves native objects] -> Cleanup code remains host-owned and import-independent; test present -> absent -> present with open windows and populated/mined devices.
- [Two controllers react to one button] -> This is the selected broadcast semantics; document per-subscription delivery and require programs to coordinate intentional factory side effects.
- [UI polling damages focus or old clicks hit new controls] -> Use stable IDs, per-tab generations, actual element checks and targeted updates; verify with two native clients, not only GUI doubles.
- [Existing spec/engine drift] -> Reconcile the directly relevant lifecycle pin and use current 2.1.23 binaries/data for new acceptance. Do not claim old 2.0.77 graphical evidence carries forward.

## Migration Plan

1. Add the new kind, prototype/recipe/art/locales, provider and versioned model without rewriting existing device identities, art or data. Existing saves start with no dashboards; reconcile recipe unlocks for already-researched forces.
2. Add native sessions and optional charts under the existing dispatcher. Ordinary loading reconstructs functions only; initialization/configuration changes handle model-version checks and dependency presentation cleanup during synchronized work.
3. Extend isolated harness support to install an explicitly supplied chart ZIP alongside the built archive. Exercise base/Space Age with and without it, then separate-process save/reload and dependency removal/reinstallation. Use real 2.1.23 clients for input/appearance and connected-peer gates.
4. Synchronize the approved new/modified capability contracts and companion API into canonical documentation at the implementation delivery boundary, then update `tools/build.py` contract inclusion and regenerate player/reference docs. Do not make a runtime module depend on a planning-directory path or package missing canonical contracts. No sync/archive is performed during this proposal workflow.
5. Optional-library removal is supported as described. Downgrading the main mod to a release without dashboard prototypes is not a data-preserving rollback; preserve a backup save and the newer archive. Do not offer destructive downgrade as recovery for a failed feature gate.

## Open Questions

Only tuning/evidence details remain: the exact native window spacing and artwork composition within the declared footprint; a measured fair presentation cadence under unchanged maintenance limits; and the exact release/client evidence locations. None authorizes changing the API, adding limits, increasing budgets, modifying the chart library or removing an acceptance gate. A demonstrated conflict with those contracts requires a new user decision rather than being silently classified as tuning.
