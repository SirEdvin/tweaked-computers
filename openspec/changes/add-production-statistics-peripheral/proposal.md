# Proposal

## Why

Computer programs cannot read the native production statistics that players use to understand their factory. A read-only peripheral should expose those same totals, time-window averages and chart samples without independently recording production or requiring programs to accumulate their own history.

## What Changes

- Add a physical **Production Statistics** peripheral, public type `production_statistics`, using the existing powered, single-Network-port device lifecycle and red/green discovery.
- Read exactly `item`, `fluid` and `pollution` statistics on the peripheral's own surface. Item/fluid data belongs to its force; pollution is surface-wide. Electricity, other surfaces, kills and construction statistics are out of scope.
- Add three distinct statistical methods: `getTotals(kind)` and `getRates(kind, window)` return all recorded entries; `getHistory(kind, name, window, quality?)` returns one entry's native history. Retain the ordinary `getLimits()` method.
- Preserve separate input/output values and item qualities. Use native counters, time windows and historical samples; do not add a collector, persistent history, subscriptions or a custom chart renderer.
- Provide the normal identity/status inspector, discoverable Reference, player documentation and runnable guest examples, including a monitor dashboard example.
- Supply the normative Lua API companion at `specs/production-statistics/lua-api.md` in this change. Successful bulk results are complete; existing shared execution/Data protections still apply without a new statistics-specific entry cap or setting.
- Align the stale lifecycle engine declaration with the already-shipped Factorio **2.1.23** manifest. This does not port the engine or promise 2.0 compatibility.

## Capabilities

### New Capabilities

- `production-statistics`: Physical read-only access to local native item/fluid/pollution totals, rates and history, including its public Lua contract and feature-specific acceptance.

### Modified Capabilities

- `peripheral-network`: Include the statistics device in the integrated, visible Network wiring targets without changing authority or relay rules.
- `peripheral-inspection`: Extend normal identity/status-only inspection to Production Statistics without adding a statistics browser.
- `device-lifecycle`: Correct the pinned engine requirement from the obsolete 2.0.77 baseline to the existing 2.1.23 target, retaining base/Space Age coverage.

## Impact

Implementation reaches shared device definitions/prototypes/artwork/localization; the service registry and `control.lua`; the existing inspector/editor/Reference type inventories; package and documentation inventories; guest/native/lifecycle/upgrade/client/multiplayer fixtures. It introduces no dependency, runtime backend, host API, storage schema or change to existing peripheral signatures.

The confirmed choices are category scope, own-surface scope, three distinct statistical operations, and bulk totals/rates with single-entry history. Exact field shapes, device name/artwork and reuse of the existing KV-sized balance/progression are proposed design defaults for review, not additional user-supplied decisions. Planning does not authorize implementation or publication of a mod release.
