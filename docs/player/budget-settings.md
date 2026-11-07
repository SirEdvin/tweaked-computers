# Adjusting shared work budgets

Open **Settings → Mod settings → Map** to change the three runtime-global
budgets below during play. They apply to every player and computer in the
save. A map restart is not necessary. The table lists defaults. computer.getLimits()
returns the current effective values in a defensive copy.

| Setting | Limit key | Default | Allowed range |
| --- | --- | ---: | ---: |
| Compilation work per computer per tick (`tc-compile-work`) | `compile_work` | 1250000 | 1–100000000 |
| Shared host work per tick (`tc-host-work-per-tick`) | `host_work_per_tick` | 5000000 | 200001–1000000000 |
| World maintenance work per tick (`tc-maintenance-work-per-tick`) | `maintenance_work_per_tick` | 200000 | 200000–100000000 requested |

These settings limit host work, not ordinary Lua execution or temporary memory.
**Run only trusted code.** An infinite loop can stop the game.
Temporary Lua values can use all available memory. Stop cannot interrupt code that does not return control to the host.
The former execution-work and guest-allocation settings are removed.

Source validation, reconstruction, API calls, output, and Console graph encoding share host credits.
Source work also uses the compilation allowance. Maintenance retains its separate reservation.
Earlier spending can delay unstarted preparation until a later tick. The pending item keeps its order, and accepted preparation charges remain spent.
Preparation that cannot fit fresh allowances fails. After execution starts, host-work refusal causes `E_BUDGET`, without replay of earlier effects.

Changes never reset spending. A budget increase adds only the difference.
If the budget decreases below spent credits, the runtime refuses further charged operations
until a later tick or another increase. Existing faulted programs still require
Run to restart. Validate, Run validation and callback reconstruction share
compilation credits. Higher budgets can reduce UPS. These are not speed or
frame-rate controls. Source, persistent Data, Console graph, monitor, and other retained capacities remain unchanged.
Data depth, `string_bytes`, and `table_entries` apply at their documented boundaries, not to ordinary temporary Lua values.

### Maintenance and shared headroom

The effective maintenance ceiling is `min(requested maintenance, host_work_per_tick - 1)`.
The requested setting stays unchanged. An increase in host work can make more of it
effective. This never increases the shared host setting. At least one guest unit
remains. But one unit cannot run a useful callback. Choose host headroom for
your actual source preparation and API work, in addition to maintenance.
Maintenance covers discovery, physical validation, signal sampling, timers, notifications and
monitor preparation, publication and retirement. More maintenance can reduce guest
headroom. It does not automatically increase callback or monitor capacities.

This alpha does not support values below 200000. The renderer
keeps its 60000 baseline reservation, alternating adaptive reservations up to
160000 and its separate 160000 whole-commit ceiling. The existing floor
preserves baseline service opportunities for indivisible topology work outside rendering.
A lower floor needs separate feasibility measurements and reconciliation, not
only a smaller integer setting. Larger settings do not increase render commits.
The 100000000 upper bound is a provisional configurable-work safety ceiling,
not a measured CPU allowance or recommendation.

Live changes keep both ledgers, world and guest state, and the frozen render
reservation. Even a previously captured maintenance callback reads the live
ceiling. No credit is refunded. After a decrease, guests cannot reuse spent maintenance credits.
After an increase, maintenance cannot reuse guest credits.
If host work decreases below combined spending, that spending stays unchanged.
The runtime refuses further charged work until a later tick or sufficient increase.
The decrease cannot undo earlier effects. A saved spent count above the current ceiling is valid.
Admission stays refused on same-tick reload. Paid reconciliation and on_load mutation
are not necessary. Ordinary synchronized admission resets counters only on a new tick.
