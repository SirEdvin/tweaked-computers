-- Shared settings-stage definitions and control-stage refresh. Effective limits
-- remain a plain table so computer.getLimits() can return a defensive Data copy.
local limits=require('scripts.runtime.limits')
local MAX=9007199254740991
local maintenance_max=MAX
local M={maintenance_max=maintenance_max,definitions={
  {key='compile_work',name='tc-compile-work',unit='work_units',scope='computer/tick',behavior='defer'},
  {key='callback_work',name='tc-callback-work',unit='work_units',scope='computer/tick',behavior='defer'},
  {key='callback_allocations',name='tc-callback-allocations',unit='allocation_units',scope='computer/tick',behavior='defer'},
  {key='host_work_per_tick',name='tc-host-work-per-tick',minimum_value=2,unit='work_units',scope='world/tick',behavior='defer'},
  {key='compiler_cache_bytes',name='tc-compiler-cache-bytes',unit='bytes',scope='world',behavior='evict'},
  {key='maintenance_work_per_tick',name='tc-maintenance-work-per-tick',unit='work_units',scope='world/tick',behavior='defer'},
  {key='runtime_memory_bytes',name='tc-runtime-memory-bytes',unit='bytes',scope='computer',behavior='reject'},
  {key='host_memory_bytes',name='tc-host-memory-bytes',unit='bytes',scope='world',behavior='reject'},
  {key='state_bytes',name='tc-state-bytes',unit='bytes',scope='computer',behavior='reject'},
  {key='shell_value_bytes',name='tc-shell-value-bytes',unit='bytes',scope='computer',behavior='reject'},
  {key='draft_storage_bytes',name='tc-draft-storage-bytes',unit='bytes',scope='player',behavior='reject'},
  {key='event_queue_entries',name='tc-event-queue-entries',unit='entries',scope='computer',behavior='drop_newest'},
  {key='event_queue_bytes',name='tc-event-queue-bytes',unit='bytes',scope='computer',behavior='drop_newest'},
  {key='pending_work_bytes',name='tc-pending-work-bytes',unit='bytes',scope='computer',behavior='reject'},
  {key='host_stack_depth',name='tc-host-stack-depth',unit='depth',scope='host_call',behavior='reject'},
  {key='console_entries',name='tc-console-entries',unit='entries',scope='computer',behavior='evict'},
  {key='console_bytes',name='tc-console-bytes',unit='bytes',scope='computer',behavior='evict'},
  {key='render_commit_work',name='tc-render-commit-work',unit='work_units',scope='world/tick',behavior='reject'},
  {key='event_drop_warning_interval',name='tc-event-drop-warning-interval',unit='ticks',scope='computer',kind='tuning'},
  {key='speaker_sound_page_size',name='tc-speaker-sound-page-size',unit='records',scope='page',kind='tuning'},
  {key='monitor_width_tiles',name='tc-monitor-width-tiles',maximum_value=6,unit='tiles',scope='display',behavior='reject'},
  {key='monitor_height_tiles',name='tc-monitor-height-tiles',maximum_value=6,unit='tiles',scope='display',behavior='reject'},
  {key='kv_keys',name='tc-kv-keys',unit='entries',scope='database',behavior='reject'},
  {key='kv_bytes',name='tc-kv-bytes',unit='bytes',scope='database',behavior='reject'},
  {key='kv_key_bytes',name='tc-kv-key-bytes',unit='bytes',scope='key_or_field',behavior='reject'},
  {key='kv_value_bytes',name='tc-kv-value-bytes',unit='bytes',scope='value_or_field',behavior='reject'},
  {key='kv_hash_fields',name='tc-kv-hash-fields',unit='entries',scope='hash',behavior='reject'},
  {key='kv_hash_bytes',name='tc-kv-hash-bytes',unit='bytes',scope='hash',behavior='reject'},
  {key='kv_total_hash_fields',name='tc-kv-total-hash-fields',unit='entries',scope='database',behavior='reject'},
  {key='kv_command_arguments',name='tc-kv-command-arguments',unit='arguments',scope='command',behavior='reject'},
  {key='kv_command_bytes',name='tc-kv-command-bytes',unit='bytes',scope='command',behavior='reject'},
  {key='kv_snapshot_bytes',name='tc-kv-snapshot-bytes',unit='bytes',scope='snapshot',behavior='reject'},
}}
for _,definition in ipairs(M.definitions) do
  definition.default_value=assert(limits[definition.key],'missing resource default')
  definition.minimum_value=definition.minimum_value or 1
  definition.maximum_value=definition.maximum_value or MAX
  definition.kind=definition.kind or 'resource'
end
function M.refresh()
  for _,definition in ipairs(M.definitions) do
    limits[definition.key]=settings.global[definition.name].value
  end
  -- Do not raise the shared ceiling to honor a larger maintenance request.
  -- Keep at least one guest unit even at the smallest supported host setting.
  limits.maintenance_work_per_tick=math.min(limits.maintenance_work_per_tick,limits.host_work_per_tick-1)
end
return M
