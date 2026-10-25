-- Defaults, not a release latency promise. Runtime-global settings replace the
-- work/compile/allocation and shared host ceilings without resetting ledgers.
return {
  api_version = 1, compiler_version = 2, storage_version = 1,
  identifier_bytes = 64, tuple_entries = 128,
  callback_work = 500000, callback_depth = 32, callback_allocations = 81920,
  compile_work = 1250000, host_work_per_tick = 5000000, compiler_cache_bytes = 8388608,
  active_computers = 64, active_logic_handlers = 128,
  aggregate_subscriptions = 1024, aggregate_owned_outputs = 128,
  state_bytes = 65536, state_entries = 256, data_depth = 16,
  string_bytes = 16384, table_entries = 1024,
  event_queue_bytes = 65536, timers = 64, subscriptions = 64,
  network_nodes = 256, network_edges = 512, topology_latency_ticks = 60,
  sync_group_refs = 8, sync_group_members = 4, sync_group_cells = 10584, sync_groups_per_run = 1,
  peripheral_call_bytes = 65536, peripheral_call_entries = 4096,
  console_bytes = 16384, fail_safe_latency_ticks = 1,
  shell_source_bytes = 4096, shell_bindings = 64, shell_value_bytes = 16384,
  shell_nodes = 1024, shell_pending_entries = 8, shell_pending_bytes = 16384, shell_sessions = 64,
  registry_entries = 4096, owned_children = 8,
  maintenance_work_per_tick = 200000, host_hooks = 16,
  runtime_memory_bytes = 8388608, host_memory_bytes = 134217728,
  draft_storage_bytes = 1048576, pending_work_bytes = 1048576,
  host_stack_depth = 32, render_commit_work = 160000,
  event_drop_warning_interval = 600, speaker_sound_page_size = 50,
  monitor_width_tiles = 6, monitor_height_tiles = 6,
  kv_keys = 128, kv_bytes = 16384, kv_key_bytes = 256, kv_value_bytes = 8192,
  kv_hash_fields = 128, kv_hash_bytes = 8192, kv_total_hash_fields = 256,
  kv_command_arguments = 128, kv_command_bytes = 65536, kv_snapshot_bytes = 65536
}
