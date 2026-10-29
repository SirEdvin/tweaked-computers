# Proposal

## Why

Programs can draw on world monitors, but cannot give players a machine-style window containing their own status labels, buttons and charts. A Dashboard peripheral provides that interface without turning the monitor into a GUI toolkit or implementing another chart renderer.

## What Changes

- Add a powered, wired, one-tier Dashboard peripheral, opened through ordinary entity interaction. Its computer-configured window contains zero through six named mixed-content tabs: native labels/buttons and simple row/column layouts, with optional chart widgets.
- Keep a shared device-owned model; update widgets by stable IDs without rebuilding unaffected content. All authorized computers can configure the device in normal synchronized order. Each player independently selects and scrolls tabs.
- Deliver button events to every explicitly subscribed, currently authorized computer through the existing scheduled-event system. Configuration does not grant exclusive ownership or execute callbacks inside GUI handlers.
- Make `factorio-charts` an optional dependency. Expose chart methods only when it is enabled; use its supported line and duration-stacked-bar rendering unchanged. Do not fork, patch or replace the library, add generic numeric bars, or promise a pixel-identical native production graph.
- Store rolling line-chart samples on the peripheral, including while its window is closed. The program chooses a sample-count capacity; there is no multi-resolution aggregation. Non-history duration bars retain only their latest submitted dataset.
- Reuse the existing `state_bytes` allowance for each dashboard's combined layout/data and line-buffer reservation (currently 65,536 accounted bytes), together with existing Data, call, event and work protections. Do not introduce arbitrary widget/series-count knobs; respect actual upstream renderer constraints and the explicitly requested six-tab limit.
- Preserve accepted layout/data across ordinary save/load, program retirement and optional-library removal. Without the library, retained chart widgets show an unavailable placeholder while labels/buttons remain usable. Derive mining and configuration-copy behavior from existing device lifecycle rules.
- Add the companion [Dashboard Lua API contract](specs/dashboard-interface/lua-api.md), maintained player examples and native acceptance coverage. Align the stale lifecycle engine declaration with the already-shipped Factorio 2.1.23 manifest/harness; this is not another engine port.

## Capabilities

### New Capabilities

- `dashboard-interface`: Machine-style mixed-tab UI, shared configuration, scheduled button events, optional library-backed charts, rolling history, resource ownership and safe presentation.

### Modified Capabilities

- `device-lifecycle`: Add the dashboard's physical/data-bearing lifecycle and configuration-copy distinction; reconcile the lifecycle specification's old engine pin with the current manifest.
- `peripheral-network`: Include dashboards in integrated wiring targets and preserve the existing channel-qualified discovery and shared-access rules.
- `peripheral-inspection`: Route normal dashboard opening to its interactive window with device identity/status, without weakening the read-only behavior of existing inspectors.

## Impact

- Existing integration points: `scripts/device-definitions.lua`, `scripts/registry.lua`, `scripts/lifecycle.lua`, `scripts/lifecycle-data.lua`, `scripts/blueprints.lua`, `scripts/services/peripheral.lua`, `scripts/runtime/computer.lua`, `scripts/scheduler.lua`, `control.lua`, `scripts/ui/interaction.lua`, the editor/reference UI, device prototypes/art/locales, packaging and test harnesses.
- Proposed focused modules: dashboard service/model and dashboard UI/chart presentation. Reuse existing authorization, lifecycle adapters, admission and event dispatch rather than introducing another framework.
- Dependency candidate: `? factorio-charts >= 1.2.0`. Portal metadata declares that release for Factorio 2.1. Source inspection is not installed-release or engine acceptance; test exact release bytes with the packaged mod in both base and Space Age, with and without the dependency.
- Existing monitors, inspectors, programs, native machine windows, wire-color boundaries and unrelated saved data must remain compatible. The existing six-device artwork is not redesigned.
- Planning only: implementation, asset generation, engine tests, publication and release are not performed by this change proposal.
