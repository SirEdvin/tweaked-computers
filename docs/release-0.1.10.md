# Tweaked Computers 0.1.10 — ALPHA

Target: exactly Factorio **2.0.77**, base alone or optional Space Age. Back up the
save and its mod configuration before upgrading. This remains a user-test alpha,
not a stable release, hardware-performance guarantee or universal mod-compatibility
certification. Historical releases are immutable.

## Included changes

- **Plain function programs:** exported `function name(...) ... end` declarations,
  optional private `local function` helpers, forward-visible exports and ordinary
  guarded direct/alias/protected calls. The maintained starter calls `sample()`
  immediately and also registers it by name for a later timer. Legacy returned
  descriptors remain supported; do not mix the two forms or add module-level
  effects/variables. Locals/functions are fresh for each callback, not durable
  state. Console bindings remain separate. See the [language guide](player/api/language.md).
- **Live world-maintenance setting:** change `tc-maintenance-work-per-tick` in Map
  settings. The default remains **200000**, within the unchanged shared-host
  default of **5000000**. Effective maintenance is the requested amount clamped
  to `host_work_per_tick - 1`; live decreases do not refund spent credits, and
  increases cannot reuse guest spending. Same-tick/cold accounting remains intact.
  The [measurement report](maintenance-budget-benchmark.md) is included, but its
  provisional **300000** recommendation is not adopted. Renderer reservation,
  whole-commit and structural ceilings are unchanged.
- **Diagnostic ownership:** a shared native sampling failure retains independent
  run/revision attribution per computer, without changing fail-closed output cleanup.
- **Interaction and monitor acceptance:** include guarded empty-cursor rotation,
  buffered publication/lifecycle/authority regressions and the consolidated
  representative-envelope receipt. Historical maximum-world failures are retained,
  not relabelled as passes. See [SC4 acceptance](sc4-final-acceptance.md).
- **Selected Service Rack artwork:** all six devices, matching item icons and
  two new research icons. Footprints, wire roles, monitor interiors, power, costs,
  research ownership and unlocks are unchanged. See the [player artwork guide](player/artwork.md).
- **Canonical contracts:** all completed source/API companions are packaged under
  `openspec/api/` and `openspec/specs/`, including `program-source`. The original
  planning/apply history is archived; no unperformed acceptance gate is silently checked.

## Install and compatibility

Use the existing [Factorio Mod Portal listing](https://mods.factorio.com/mod/tweaked-computers)
or the installable `tweaked-computers_0.1.10.zip` asset from
[alpha-0.1.10](https://github.com/SirEdvin/tweaked-computers/releases/tag/alpha-0.1.10).
Do not install GitHub's automatic source archives or the `tc-smoke` test companion.
Compare the downloaded ZIP with the release's `SHA256SUMS`/`SHA1SUMS` files.

API version 1, compiler representation 2 and storage schema 1 remain unchanged.
Existing supported descriptor programs are not rewritten or forcibly restarted;
ordinary reload executes no guest code and does not replay startup. Validate and
Save do not run a candidate; Run/Apply explicitly starts another generation.
Keep the pre-upgrade save and its matching 0.1.9 ZIP rather than downgrading a save
containing declaration-form source or newer presentation records. Existing 0.1.9
explicit-red/green selector rules and Recipe Searcher progression still apply.

## Verification boundary

The consolidated feature source was independently source/hash-bound and checked
with packaged base/Space Age runtime, cache, diagnostic, editor, monitor, lifecycle
and separate-process cold/upgrade suites. The release preparation changes only
metadata, documentation, canonical-contract paths and their package tests; it does
not change production Lua, selected artwork or engine fixtures.

Publication is gated on the exact deterministic 0.1.10 ZIP, full required CI,
populated published-0.1.9 upgrade, final native base/Space Age artwork/research UI
and editor smoke, merged-main rebuild identity, and public artifact/docs readbacks.
The immutable published ZIP checksums and external final receipt identify the
actual release artifact; earlier candidate hashes remain separate evidence.

A sustained animation harness now explicitly allows 240 wall seconds per cold
phase instead of relying on the short smoke default. Its 2200-tick deadline,
360-interval/two-tick cadence checks, power recovery and all paid production
limits remain unchanged. The earlier timed-out CI receipt is retained separately.
This correctness allowance is not a CPU-latency or FPS pass.

Finite llvmpipe captures are not hardware FPS or physical-display smoothness.
Representative acceptance is not simultaneous independent-cap saturation. Existing
connected-peer receipts retain their original source/scope; there is no new
exhaustive combined multiplayer campaign here. Audible playback, arbitrary third-party
mod combinations, every platform/IME and broad busy-factory smoothness are not certified.
