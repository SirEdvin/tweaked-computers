# Common effective limits

All integer keys returned by computer.getLimits(). Version keys identify the
API/compiler/storage representation rather than capacities. Work/compile/allocation
units are implementation admission units, not milliseconds or measured host bytes.
Tick-keyed counters persist through same-tick load/replacement. Maintenance is
reserved inside host_work_per_tick, never added on top. These alpha limits are
provisional safety ceilings, not simultaneous maximum-world guarantees.

## Live mod settings

Open **Settings → Mod settings → Map** to change the runtime-global
budgets below while playing. They apply to every player and computer in the
save, without restarting the map. The table lists defaults; computer.getLimits()
returns the current effective values in a defensive copy.

| Setting | Limit key | Default | Allowed range |
| --- | --- | ---: | ---: |
| Compilation work per computer per tick (`tc-compile-work`) | `compile_work` | 1250000 | 1–100000000 |
| Execution work per computer per tick (`tc-callback-work`) | `callback_work` | 500000 | 1–100000000 |
| Guest allocations per computer per tick (`tc-callback-allocations`) | `callback_allocations` | 81920 | 1–100000000 |
| Shared host work per tick (`tc-host-work-per-tick`) | `host_work_per_tick` | 5000000 | 200001–1000000000 |
| Disposable compiler cache bytes (`tc-compiler-cache-bytes`) | `compiler_cache_bytes` | 8388608 | 1–1000000000 |
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

### Disposable compiler cache

`compiler_cache_bytes` bounds shared retained plans, generated continuation text
and deterministic charge traces, including metadata. These are accounting bytes,
not measured Lua heap bytes. There is no separate plan-count or trace-count cap.
Capacity pressure evicts the cache as a batch; an oversized proof is simply rebuilt.
The cache is private and disposable: cold, warm and evicted proofs charge the same
accepted work prefixes, so cache warmth cannot change progress or renew credits.
Reducing cache retention does not invalidate saved source or suspended invocations.

### Maintenance and shared headroom

The effective maintenance ceiling is `min(requested maintenance, host_work_per_tick - 1)`.
The requested setting is preserved, so raising host work can make more of it
effective. This never raises the shared host setting. At least one guest unit
remains, but one unit cannot run a useful callback: choose host headroom for
your actual programs, preferably the three per-computer budgets plus maintenance.
Maintenance covers discovery, power/signal sampling, timers, notifications and
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

## Default common limits

| Key | Default value |
| --- | ---: |
| `api_version` | 1 |
| `compiler_version` | 2 |
| `storage_version` | 1 |
| `source_bytes` | 16384 |
| `generated_source_bytes` | 131072 |
| `source_nodes` | 4096 |
| `source_tokens` | 4096 |
| `source_nesting` | 48 |
| `handler_names` | 64 |
| `identifier_bytes` | 64 |
| `tuple_entries` | 128 |
| `callback_work` | 500000 |
| `callback_depth` | 32 |
| `callback_allocations` | 81920 |
| `compile_work` | 1250000 |
| `host_work_per_tick` | 5000000 |
| `compiler_cache_bytes` | 8388608 |
| `active_computers` | 64 |
| `active_logic_handlers` | 128 |
| `aggregate_subscriptions` | 1024 |
| `aggregate_owned_outputs` | 128 |
| `state_bytes` | 65536 |
| `state_entries` | 256 |
| `data_nodes` | 4096 |
| `data_depth` | 16 |
| `string_bytes` | 16384 |
| `table_entries` | 1024 |
| `event_queue_entries` | 128 |
| `event_queue_bytes` | 65536 |
| `timers` | 64 |
| `subscriptions` | 64 |
| `network_nodes` | 256 |
| `network_edges` | 512 |
| `topology_latency_ticks` | 60 |
| `sync_group_refs` | 8 |
| `sync_group_members` | 4 |
| `sync_group_cells` | 10584 |
| `sync_groups_per_run` | 1 |
| `peripheral_call_bytes` | 65536 |
| `peripheral_call_entries` | 4096 |
| `console_entries` | 64 |
| `console_bytes` | 16384 |
| `fail_safe_latency_ticks` | 1 |
| `shell_source_bytes` | 4096 |
| `shell_bindings` | 64 |
| `shell_value_bytes` | 16384 |
| `shell_nodes` | 1024 |
| `shell_pending_entries` | 8 |
| `shell_pending_bytes` | 16384 |
| `shell_sessions` | 64 |
| `registry_entries` | 4096 |
| `owned_children` | 8 |
| `maintenance_work_per_tick` | 200000 |
| `host_hooks` | 16 |
| `runtime_memory_bytes` | 8388608 |
| `host_memory_bytes` | 134217728 |
| `draft_storage_bytes` | 1048576 |
| `pending_work_bytes` | 1048576 |
| `host_stack_depth` | 32 |
| `render_commit_work` | 160000 |
| `event_drop_warning_interval` | 600 |
| `speaker_sound_page_size` | 50 |
| `monitor_width_tiles` | 6 |
| `monitor_height_tiles` | 6 |
| `kv_keys` | 128 |
| `kv_bytes` | 16384 |
| `kv_key_bytes` | 256 |
| `kv_value_bytes` | 8192 |
| `kv_hash_fields` | 128 |
| `kv_hash_bytes` | 8192 |
| `kv_total_hash_fields` | 256 |
| `kv_command_arguments` | 128 |
| `kv_command_bytes` | 65536 |
| `kv_snapshot_bytes` | 65536 |

Device-specific limits: [monitor](monitor.md#bounds-example-and-troubleshooting),
[KV](kv.md#atomicity-errors-and-capacities), [logic](logic.md#bounds-and-use),
[configurator](configurator.md#bounds-programs-and-troubleshooting),
[Recipe Searcher](recipe-searcher.md#complete-results-not-a-prefix).
See [shared rules](common.md) for Data accounting and refusal behavior.
