-- Development ceilings, not a release latency promise. Keep shared costs versioned.
return {
  api_version = 1, compiler_version = 1, storage_version = 1,
  source_bytes = 16384, generated_source_bytes = 131072,
  source_nodes = 4096, source_tokens = 4096, source_nesting = 48,
  handler_names = 64, identifier_bytes = 64, tuple_entries = 128,
  callback_work = 100000, callback_depth = 32, callback_allocations = 16384,
  compile_work = 250000, host_work_per_tick = 1000000,
  active_computers = 64, active_logic_handlers = 128,
  aggregate_subscriptions = 1024, aggregate_owned_outputs = 128,
  state_bytes = 65536, state_entries = 256, data_nodes = 4096, data_depth = 16,
  string_bytes = 16384, table_entries = 1024,
  event_queue_entries = 128, event_queue_bytes = 65536, timers = 64, subscriptions = 64,
  network_nodes = 256, network_edges = 512, topology_latency_ticks = 60,
  peripheral_call_bytes = 65536, peripheral_call_entries = 4096,
  console_entries = 64, console_bytes = 16384, fail_safe_latency_ticks = 1
}
