# Common effective limits

All integer keys returned by computer.getLimits(). Version keys identify the
API/compiler/storage representation rather than capacities. Work/compile/allocation
units are implementation admission units, not milliseconds or measured host bytes.
Tick-keyed counters persist through same-tick load/replacement. Maintenance is
reserved inside host_work_per_tick, never added on top. These alpha limits are
provisional safety ceilings, not simultaneous maximum-world guarantees.

| Key | Value |
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
| `callback_work` | 100000 |
| `callback_depth` | 32 |
| `callback_allocations` | 16384 |
| `compile_work` | 250000 |
| `host_work_per_tick` | 1000000 |
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
| `peripheral_call_bytes` | 65536 |
| `peripheral_call_entries` | 4096 |
| `console_entries` | 64 |
| `console_bytes` | 16384 |
| `fail_safe_latency_ticks` | 1 |
| `registry_entries` | 4096 |
| `owned_children` | 8 |
| `maintenance_work_per_tick` | 200000 |
| `host_hooks` | 16 |

Device-specific limits: [monitor](monitor.md#bounds-example-and-troubleshooting),
[KV](kv.md#atomicity-errors-and-capacities), [logic](logic.md#bounds-and-use),
[configurator](configurator.md#bounds-programs-and-troubleshooting).
See [shared rules](common.md) for Data accounting and refusal behavior.
