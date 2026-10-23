-- Native policy settings, effective values, and cold retained-credit identity.
local budgets=require('scripts.runtime.budget-settings')
local limits=require('scripts.runtime.limits')
local registry=require('scripts.registry')
local admission=require('scripts.runtime.admission')
local scheduler=require('scripts.scheduler')
local policy=require('scripts.runtime.resource-policy')
local speaker=require('scripts.services.speaker')
local M={}
local loaded=false
local expected={
  compile_work=1250000,callback_work=500000,callback_allocations=81920,
  host_work_per_tick=5000000,maintenance_work_per_tick=200000,
  runtime_memory_bytes=8388608,host_memory_bytes=134217728,state_bytes=65536,
  shell_value_bytes=16384,draft_storage_bytes=1048576,
  event_queue_entries=128,event_queue_bytes=65536,pending_work_bytes=1048576,
  host_stack_depth=32,console_entries=64,console_bytes=16384,
  compiler_cache_bytes=8388608,render_commit_work=160000,
  event_drop_warning_interval=600,speaker_sound_page_size=50,
  monitor_width_tiles=6,monitor_height_tiles=6,
  kv_keys=128,kv_bytes=16384,kv_key_bytes=256,kv_value_bytes=8192,
  kv_hash_fields=128,kv_hash_bytes=8192,kv_total_hash_fields=256,
  kv_command_arguments=128,kv_command_bytes=65536,kv_snapshot_bytes=65536
}
local function change(definition,value)
  settings.global[definition.name]={value=value}
  assert(settings.global[definition.name].value==value,'native setting rejected '..definition.name)
  local handler=assert(script.get_event_handler(defines.events.on_runtime_mod_setting_changed))
  handler{setting=definition.name,setting_type='runtime-global',tick=game.tick}
end
local function unchanged(f)
  local root=registry.get()
  local exposed=policy.limits()
  assert(exposed.policy_version==2)
  local speaker_policy=speaker.methods.getLimits()
  assert(speaker_policy.policy_version==2 and speaker_policy.callback_work==nil)
  assert(speaker_policy.tuning.speaker_sound_page_size.limit==f.values.speaker_sound_page_size)
  for _,key in ipairs({'callback_work','callback_allocations','host_work_per_tick','runtime_memory_bytes',
    'host_memory_bytes','pending_work_bytes','host_stack_depth'}) do
    local entry=assert(speaker_policy.resources[key])
    for field,value in pairs(exposed.resources[key]) do assert(entry[field]==value,'stale speaker policy: '..key) end
  end
  assert(speaker_policy.resources.kv_keys==nil and speaker_policy.resources.monitor_width_tiles==nil)
  assert(root.ledger==f.ledger and root.ledger.tick==f.tick and root.ledger.total==f.total,'policy refresh renewed retained work')
  assert(root.ledger.machines[f.id]==f.machine and f.machine.work==123)
  for _,definition in ipairs(budgets.definitions) do
    assert(settings.global[definition.name].value==f.values[definition.key])
    local value=f.values[definition.key]
    if definition.key=='maintenance_work_per_tick' then value=math.min(value,f.values.host_work_per_tick-1) end
    assert(limits[definition.key]==value,'effective setting lost: '..definition.key)
    local domain=definition.kind=='tuning' and exposed.tuning or exposed.resources
    local entry=assert(domain[definition.key],'missing policy introspection: '..definition.key)
    assert(entry.limit==value and entry.unit==definition.unit and entry.scope==definition.scope
      and entry.setting==definition.name and entry.behavior==definition.behavior)
  end
end
function M.run()
  registry.initialize()
  local found={}
  for _,definition in ipairs(budgets.definitions) do
    assert(expected[definition.key]~=nil and not found[definition.key],'unknown or duplicate policy definition')
    found[definition.key]=definition
    assert(definition.default_value==expected[definition.key] and limits[definition.key]==expected[definition.key])
    assert(type(definition.unit)=='string' and type(definition.scope)=='string')
    assert(definition.kind=='tuning' or definition.behavior=='defer' or definition.behavior=='reject'
      or definition.behavior=='drop_newest' or definition.behavior=='evict')
    assert(definition.minimum_value>0 and definition.minimum_value<=definition.default_value
      and definition.maximum_value>=definition.default_value)
  end
  for key in pairs(expected) do assert(found[key],'missing policy setting: '..key) end
  assert(found.monitor_width_tiles.maximum_value==6 and found.monitor_height_tiles.maximum_value==6)
  -- Legal spending above the old validator ceiling must survive scheduler entry.
  change(found.host_work_per_tick,4000000000)
  change(found.callback_work,3000000000)
  local high=registry.get()
  local high_ctx=admission.context(high.ledger,'large-spend',game.tick)
  assert(admission.reserve(high_ctx,'work',1000000000))
  assert(admission.reserve(high_ctx,'work',1000000000))
  scheduler.tick(game.tick)
  assert(high.scheduler.last_tick==game.tick and high.ledger.total==2000000000,
    'legal accumulated spending rejected by scheduler entry')
  scheduler.tick(game.tick+1)
  assert(high.scheduler.last_tick==game.tick+1,'legal spending prevented next-tick scheduler entry')
  high_ctx=admission.context(high.ledger,'large-spend',game.tick+1)
  assert(high.ledger.total==0 and high_ctx.machine.work==0)
  assert(admission.reserve(high_ctx,'work',1000000001),'legal individual reservation rejected')
  change(found.maintenance_work_per_tick,2000000000)
  local spend=scheduler.maintenance(high,game.tick+1,true)
  spend(1000000001)
  assert(high.scheduler.maintenance_spent>=1000000001)
  for _,invalid in ipairs({-1,0.5,math.huge,9007199254740992}) do
    assert(not pcall(admission.reserve,high_ctx,'work',invalid),'invalid guest reservation accepted')
    assert(not pcall(spend,invalid),'invalid maintenance reservation accepted')
  end
  change(found.host_work_per_tick,9007199254740991)
  change(found.callback_work,9007199254740991)
  change(found.maintenance_work_per_tick,1)
  local edge=admission.context(admission.new(),'safe-integer-edge',game.tick)
  assert(admission.reserve(edge,'work',9007199254740990))
  assert(not admission.reserve(edge,'work',1) and not admission.reserve(edge,'work',2))
  assert(edge.ledger.total==9007199254740990,'refused reservation changed exact spending')
  for _,key in ipairs({'host_work_per_tick','callback_work','maintenance_work_per_tick'}) do
    change(found[key],found[key].default_value)
  end
  storage.tweaked_computers=nil
  registry.initialize()
  local root=registry.get()
  local ctx=admission.context(root.ledger,'policy-settings',game.tick)
  assert(admission.reserve(ctx,'work',123))
  local f={phase='arm',ledger=root.ledger,machine=ctx.machine,id='policy-settings',tick=game.tick,
    total=root.ledger.total,values={}}
  for _,definition in ipairs(budgets.definitions) do
    local value=definition.default_value+1
    if value>definition.maximum_value then value=definition.default_value-1 end
    change(definition,value); f.values[definition.key]=value
    assert(root.ledger.total==f.total and ctx.machine.work==123)
  end
  unchanged(f)
  -- The engine must accept each declared endpoint, not merely its default.
  for _,definition in ipairs(budgets.definitions) do
    change(definition,definition.maximum_value)
    local effective=definition.maximum_value
    if definition.key=='maintenance_work_per_tick' then effective=math.min(effective,limits.host_work_per_tick-1) end
    assert(limits[definition.key]==effective and root.ledger.total==f.total and ctx.machine.work==123)
    change(definition,f.values[definition.key])
  end
  unchanged(f)
  -- Small legal allowances cannot renew credits; resource owners handle refusal.
  for _,key in ipairs({'state_bytes','event_queue_bytes','runtime_memory_bytes','host_memory_bytes','maintenance_work_per_tick'}) do
    local definition=found[key]; local value=f.values[key]
    change(definition,definition.minimum_value)
    assert(limits[key]==definition.minimum_value and root.ledger.total==f.total and ctx.machine.work==123)
    change(definition,value)
  end
  unchanged(f)
  storage.tc_policy_settings=f
  log('TC_CONTRACT complete-native-resource-settings-and-no-credit-renewal')
end
function M.on_load()
  local f=storage.tc_policy_settings
  if f and f.phase=='frozen' then unchanged(f); loaded=true; log('TC_POLICY_SETTINGS_ON_LOAD_UNCHANGED') end
end
function M.on_tick()
  local f=storage.tc_policy_settings
  if f.phase=='arm' then
    unchanged(f); f.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif f.phase=='frozen' and loaded then
    unchanged(f)
    for _,definition in ipairs(budgets.definitions) do change(definition,definition.default_value) end
    assert(registry.get().ledger.total==f.total and f.machine.work==123)
    f.phase='done'; log('TC_CONTRACT complete-resource-policy-settings-cold-preserved'); log('TC_COLD_OK')
  end
end
return M
