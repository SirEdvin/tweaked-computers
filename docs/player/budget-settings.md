# Adjusting shared work budgets

Open **Settings → Mod settings → Map** to change the five runtime-global
budgets below while playing. They apply to every player and computer in the
save, without restarting the map. The table lists defaults; computer.getLimits()
returns the current effective values in a defensive copy.

| Setting | Limit key | Default | Allowed range |
| --- | --- | ---: | ---: |
| Compilation work per computer per tick (`tc-compile-work`) | `compile_work` | 1250000 | 1–100000000 |
| Execution work per computer per tick (`tc-callback-work`) | `callback_work` | 500000 | 1–100000000 |
| Guest allocations per computer per tick (`tc-callback-allocations`) | `callback_allocations` | 81920 | 1–100000000 |
| Shared host work per tick (`tc-host-work-per-tick`) | `host_work_per_tick` | 5000000 | 200001–1000000000 |
| World maintenance work per tick (`tc-maintenance-work-per-tick`) | `maintenance_work_per_tick` | 200000 | 200000–100000000 requested |

Compilation, execution and allocation defaults are five times the original
allowances. The shared host default is also five times larger so it can admit
them. The maintenance default remains 200000 admission units.
Prefer a shared ceiling at least as large as all three per-computer budgets
combined plus maintenance. A smaller shared budget can defer callbacks or
cause E_BUDGET when actual work exceeds its remaining allowance.

Changes never reset spending: raising a budget adds only the difference;
lowering it below already-spent credits refuses further charged operations
until a later tick or another increase. Existing faulted programs still require
Run to restart. Validate, Run validation and callback reconstruction share
compilation credits. Higher budgets may reduce UPS; these are not speed or
frame-rate controls. Source, state, depth, monitor and other structural caps
remain unchanged.

### Maintenance and shared headroom

The effective maintenance ceiling is `min(requested maintenance, host_work_per_tick - 1)`.
The requested setting is preserved, so raising host work can make more of it
effective. This never raises the shared host setting. At least one guest unit
remains, but one unit cannot run a useful callback: choose host headroom for
your actual programs, preferably the three per-computer budgets plus maintenance.
Maintenance covers discovery, physical validation, signal sampling, timers, notifications and
monitor preparation/publication/retirement. More maintenance can reduce guest
headroom; it does not automatically increase callback or monitor capacities.

Values below 200000 are deliberately unsupported in this alpha. The renderer
keeps its 60000 baseline reservation, alternating adaptive reservations up to
160000 and its separate 160000 whole-commit ceiling. Keeping the existing floor
preserves baseline non-render service opportunities for indivisible topology
work; lowering it needs separate feasibility measurements/reconciliation, not
just a smaller integer setting. Larger settings do not widen render commits.
The 100000000 upper bound is a provisional configurable-work safety ceiling,
not a measured CPU allowance or recommendation.

Live changes retain both ledgers, world/guest state and the frozen render
reservation. Even a previously captured maintenance callback reads the live
ceiling. No credit is refunded: guests cannot reuse maintenance already spent
after a decrease, and maintenance cannot reuse guest credits after an increase.
Reducing host work below combined spending preserves that spending and refuses
further charged work until a later tick or sufficient increase; it cannot undo
earlier effects. A saved spent count above the current ceiling is valid and
stays refused on same-tick reload. No paid reconciliation or on_load mutation
is needed; ordinary synchronized admission resets counters only on a new tick.
