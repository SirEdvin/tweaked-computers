-- Native read-only facade with real scheduler/continuation/memory ownership.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local sections=require('scripts.configuration.sections')
local adapters=require('scripts.configuration.adapters')
local targets=require('scripts.configuration.targets')
local validation=require('scripts.configuration.validation')
require('scripts.services.configurator')
local M={}; local loaded=false
local source=[[function policy(cfg)
  local p=cfg.getLimits()
  assert(p.policy_version==2,'Configurator must expose resource policy v2')
  assert(select('#',cfg.getLimits())==1 and next(p.tuning)==nil)
  assert(p.callback_work==nil and p.table_entries==nil and p.network_nodes==nil)
  local common=computer.getLimits()
  local keys={'callback_work','callback_allocations','host_work_per_tick','runtime_memory_bytes',
    'host_memory_bytes','pending_work_bytes','host_stack_depth'}
  local count=0; for _ in pairs(p.resources) do count=count+1 end
  assert(count==#keys)
  for _,key in ipairs(keys) do
    local descriptor=assert(p.resources[key]); local expected=common.resources[key]
    for field,value in pairs(expected) do assert(descriptor[field]==value) end
    for field,value in pairs(descriptor) do assert(expected[field]==value) end
  end
  p.resources.callback_work.limit=1; p.resources.host_memory_bytes.setting='changed'
  local other=peripheral.wrap(peripheral.getName(cfg),'green').getLimits()
  assert(other.resources.callback_work.limit==common.resources.callback_work.limit)
  assert(other.resources.host_memory_bytes.setting=='tc-host-memory-bytes')
  for _,call in ipairs({function() cfg.getLimits(nil) end,function() cfg.getLimits(cfg) end}) do
    local ok,e=pcall(call); assert(not ok and e.code=='E_ARGUMENT')
  end
end
function start()
  local cfg=peripheral.find('configurator','red'); assert(cfg)
  policy(cfg)
  local devices=cfg.getDevices('green'); assert(#devices==2)
  assert(#cfg.getDevices('red')==0)
  local constant,decider
  for _,device in ipairs(devices) do
    assert(cfg.getDevice(device.id,'green').id==device.id)
    assert(cfg.getCapabilities(device.id,'green').api_version==1)
    if device.type=='constant-combinator' then constant=device.id end
    if device.type=='decider-combinator' then decider=device.id end
  end
  assert(constant and decider)
  local values=cfg.getConfiguration(decider,'green').values.parameters
  assert(#values.conditions==129 and values.conditions[129].constant==129)
  local result=cfg.getSections(constant,'green')
  assert(#result==33 and #result[1].filters==129)
  for i,section in ipairs(result) do assert(section.index==i and section.is_manual) end
  for i,filter in ipairs(result[1].filters) do assert(filter.index==i and filter.min==i) end
  result[1].filters[129].min=-1
  assert(cfg.getSections(constant,'green')[1].filters[129].min==129)
  computer.setState('reads_done',true)
end
function unpowered()
  local cfg=peripheral.find('configurator','red'); assert(cfg)
  policy(cfg)
  local ok,e=pcall(cfg.getDevices,'green'); assert(not ok and e.code=='E_UNPOWERED')
  computer.setState('unpowered_done',true)
end]]
local function state() return storage.configurator_policy_fixture end
local function item(entity) return {id=targets.identity(entity),entity=entity} end
local function nop() end
function M.run()
  registry.initialize()
  local function build(kind,x)
    local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,0},force='player'})
    local rec,e=lifecycle.build(body); assert(rec,serpent.line(e))
    lifecycle.power_entity(rec).energy=1000000; rec.powered=true
    return rec
  end
  local computer=build('computer',0); local cfg=build('configurator',4)
  for _,wire in ipairs({'red','green'}) do
    assert(lifecycle.connector(computer,'network',wire).connect_to(lifecycle.connector(cfg,'network',wire),false))
  end
  local function target(name,x)
    local entity=assert(game.surfaces[1].create_entity{name=name,position={x,5},force='player'})
    local connector=entity.get_wire_connector(defines.wire_connector_id.circuit_green,true)
    assert(lifecycle.connector(cfg,'targets','green').connect_to(connector,false))
    return entity
  end
  local constant=target('constant-combinator',4)
  local cb=constant.get_or_create_control_behavior()
  while cb.sections_count<33 do assert(cb.add_section('')) end
  local names={}; for name in pairs(prototypes.item) do names[#names+1]=name end; table.sort(names)
  assert(#names>=129)
  for i=1,129 do
    cb.get_section(1).set_slot(i,{value={type='item',name=names[i],quality='normal',comparator='='},min=i})
  end
  local decider=target('decider-combinator',7)
  local parameters={conditions={},outputs={{signal={type='virtual',name='signal-B'},copy_count_from_input=false,constant=2}}}
  for i=1,129 do parameters.conditions[i]={first_signal={type='virtual',name='signal-A'},comparator='>',constant=i} end
  decider.get_or_create_control_behavior().parameters=parameters
  storage.configurator_policy_fixture={phase='reading',computer=computer.id,cfg=cfg.id,constant=constant,decider=decider,
    before_sections=sections.get(item(constant),nop),before_configuration=adapters.snapshot(item(decider),nop)}
  assert(runtime.save(computer.id,source,computer.saved_revision)); assert(runtime.activate(computer.id,game.tick))
end
function M.on_load() if state() and state().phase=='frozen' then loaded=true end end
function M.on_tick(event)
  local s=state(); if not s or s.phase=='done' then return end
  local computer=assert(registry.record(s.computer)); local cfg=assert(registry.record(s.cfg))
  if s.phase=='frozen' then
    if not loaded then return end
    loaded=false; s.phase='resumed'
    local pending=assert(computer.invocation.checkpoint.frame.pending)
    local job=assert(pending.jobs['result-data-2'])
    assert(not job.done and job.bytes==s.copy_bytes and #job.source==33)
    assert(computer.run_id==s.run_id and not computer.state.reads_done)
    log('TC_CONTRACT cold-native-section-result-resumes-paid-copy-frontier')
  end
  assert(event.tick<600,'native Configurator read fixture timed out: '..serpent.line(computer.diagnostic))
  lifecycle.power_entity(computer).energy=1000000; computer.powered=true
  local powered=s.phase~='unpowered'
  lifecycle.power_entity(cfg).energy=powered and 1000000 or 0; cfg.powered=powered
  scheduler.tick(event.tick)
  assert(computer.status~='faulted' and not computer.diagnostic,serpent.line(computer.diagnostic))
  if s.phase=='reading' then
    local pending=computer.invocation and computer.invocation.checkpoint.frame.pending
    local job=pending and pending.jobs and pending.jobs['result-data-2']
    if job and not job.done and job.bytes>0 and #job.source==33 and job.source[33].is_manual then
      s.phase='frozen'; s.copy_bytes=job.bytes; s.run_id=computer.run_id
      game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
    end
    assert(not computer.state.reads_done,'large native read did not expose the required cold copy boundary')
  end
  if s.phase=='resumed' and computer.state.reads_done and not computer.invocation then
    assert(runtime.enqueue(computer,'unpowered',{name='unpowered'},event.tick)); s.phase='unpowered'
  elseif s.phase=='unpowered' and computer.state.unpowered_done and not computer.invocation then
    assert(validation.equal(sections.get(item(s.constant),nop),s.before_sections))
    assert(validation.equal(adapters.snapshot(item(s.decider),nop).values,s.before_configuration.values))
    assert(not cfg.configuration_recovery)
    log('TC_CONTRACT native-policy-both-colors-unpowered-arity-defensive-read-and-unchanged-targets')
    runtime.stop(computer.id); s.phase='done'; log('TC_COLD_OK')
  end
end
return M
