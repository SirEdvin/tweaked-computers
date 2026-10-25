-- Native inventories through the real scheduler and guest result/memory guard.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
require('scripts.services.logic')
local M={}; local loaded=false
local sizes={64,65,150,1100}
local source=[[function policy(io)
  local p=io.getLimits(); local common=computer.getLimits()
  assert(p.policy_version==2,'Logic must expose resource policy v2')
  assert(select('#',io.getLimits())==1 and next(p.tuning)==nil and p.sample_interval_ticks==1)
  assert(p.signal_slots==nil and p.filter_signals==nil and p.table_entries==nil and p.callback_work==nil)
  local keys={'callback_work','callback_allocations','host_work_per_tick','maintenance_work_per_tick',
    'runtime_memory_bytes','host_memory_bytes','pending_work_bytes','host_stack_depth','event_queue_bytes'}
  local count=0; for _ in pairs(p.resources) do count=count+1 end; assert(count==#keys)
  for _,key in ipairs(keys) do
    for field,value in pairs(common.resources[key]) do assert(p.resources[key][field]==value) end
    for field,value in pairs(p.resources[key]) do assert(common.resources[key][field]==value) end
  end
  p.resources.callback_work.limit=1
  assert(io.getLimits().resources.callback_work.limit==common.resources.callback_work.limit)
  local ok,e=pcall(io.getLimits,nil); assert(not ok and e.code=='E_ARGUMENT')
  ok,e=pcall(io.getLimits,io); assert(not ok and e.code=='E_ARGUMENT')
end
function start() policy(assert(peripheral.find('logic_handler','red'))) end
function check(io,color,n,sign)
  local values=io.readSignals(color); assert(#values==n,'native signal inventory '..color..': '..#values..' expected '..n)
  for i,value in ipairs(values) do
    assert(value.signal.type=='virtual' and value.signal.name==string.format('tc-inventory-%04d',i))
    assert(value.signal.quality=='normal' and value.count==sign*i)
    assert(io.readSignal(color,value.signal)==sign*i)
  end
  values[1].count=999; values[1].signal.name='changed'
  assert(io.readSignal(color,{type='virtual',name='tc-inventory-0001'})==sign)
end
function read(event)
  local io=assert(peripheral.find('logic_handler','red'))
  local other=assert(peripheral.wrap(peripheral.getName(io),'green'))
  check(io,'red',event.count,1); check(other,'green',event.count,-1)
  if event.count==150 then
    local bank=io.readSignals('green'); assert(select('#',io.setOutput(bank))==0)
    assert(#io.getOutput()==150)
    bank[150].count=2147483648
    local ok,e=pcall(io.setOutput,bank); assert(not ok and e.code=='E_RANGE')
    assert(io.getOutput()[150].count==-150)
  end
  computer.setState('count',event.count)
end
function identities(event)
  local io=assert(peripheral.find('logic_handler','green'))
  local values=io.readSignals('red'); assert(#values==(event.quality and 5 or 4))
  local seen={}
  for _,value in ipairs(values) do
    assert(io.readSignal('red',value.signal)==value.count)
    seen[value.signal.type..'/'..value.signal.quality]=value.count
  end
  assert(seen['recipe/normal']==-9 and seen['item/normal']==7 and seen['fluid/normal']==11 and seen['virtual/normal']==-13)
  if event.quality then assert(seen['item/uncommon']==-3) end
  local ok,e=pcall(io.readSignal,'red',{type='item',name='tc-missing-item'}); assert(not ok and e.code=='E_RANGE')
  ok,e=pcall(io.readSignal,'red',{type='item',name='iron-plate',quality='tc-missing-quality'}); assert(not ok and e.code=='E_RANGE')
  ok,e=pcall(io.readSignals,'both'); assert(not ok and e.code=='E_ARGUMENT')
  computer.setState('identities',true)
end
function filtered()
  local io=assert(peripheral.find('logic_handler','red')); local filters={}
  for i=1,1100 do filters[i]={type='virtual',name=string.format('tc-inventory-%04d',i)} end
  local id=io.subscribe({input='green',signals=filters,initial=false},'unused')
  computer.setState('subscription',id)
end
function unused() error('unchanged filtered baseline must not dispatch') end
function cleanup()
  local io=assert(peripheral.find('logic_handler','red'))
  local id=computer.getState('subscription')
  if id then assert(io.unsubscribe(id)); assert(not io.unsubscribe(id)) end
  assert(select('#',io.clearOutput())==0 and #io.getOutput()==0)
  computer.setState('cleaned',true)
end
function unpowered()
  local io=assert(peripheral.find('logic_handler','red')); policy(io)
  local ok,e=pcall(io.readSignals,'red'); assert(not ok and e.code=='E_UNPOWERED')
  computer.setState('unpowered',true)
end]]
local function state() return storage.logic_policy_fixture end
local function set(entity,n,negative)
  local cb=entity.get_or_create_control_behavior()
  for i=cb.sections_count,1,-1 do cb.remove_section(i) end
  local section=assert(cb.add_section('')); local filters={}
  for i=1,n do filters[i]={index=i,value={type='virtual',name=string.format('tc-inventory-%04d',i),quality='normal'},min=negative and -i or i} end
  section.filters=filters; assert(#section.filters==n); cb.enabled=true
end
function M.run(skip_large_filter)
  registry.initialize()
  local function build(kind,x)
    local entity=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,0},force='player'})
    local r=assert(lifecycle.build(entity)); lifecycle.power_entity(r).energy=1000000; r.powered=true; return r
  end
  local c=build('computer',0); local io=build('logic',4)
  local s={phase='ready',index=1,due=5,computer=c.id,logic=io.id,skip_large_filter=skip_large_filter==true}; storage.logic_policy_fixture=s
  for _,color in ipairs({'red','green'}) do
    assert(lifecycle.connector(c,'network',color).connect_to(lifecycle.connector(io,'network',color),false))
    local e=assert(game.surfaces[1].create_entity{name='constant-combinator',position={color=='red' and 2 or 6,-4},force='player'})
    assert(e.get_wire_connector(defines.wire_connector_id['circuit_'..color],true).connect_to(lifecycle.connector(io,'input',color),false))
    set(e,64,color=='green'); s[color]=e
  end
  assert(runtime.save(c.id,source,c.saved_revision)); assert(runtime.activate(c.id,game.tick))
end
function M.on_load() if state() and state().phase=='frozen' then loaded=true end end
function M.on_tick(event)
  local s=state(); if not s or s.phase=='done' then return end
  local c=assert(registry.record(s.computer)); local io=assert(registry.record(s.logic))
  if s.phase=='frozen' then
    if not loaded then return end
    loaded=false
    local job=assert(c.invocation.checkpoint.frame.pending.jobs['result-data-2'])
    assert(not job.done and job.bytes==s.copy_bytes and #job.source==1100 and c.run_id==s.run_id)
    s.phase='reading'; s.reloaded=true; log('TC_CONTRACT cold-native-1100-signal-result-paid-frontier')
  end
  assert(event.tick<1800,'native logic fixture timed out: '..serpent.line(c.diagnostic or c.resource_refusal))
  lifecycle.power_entity(c).energy=1000000; c.powered=true
  io.powered=s.phase~='unpowered'; lifecycle.power_entity(io).energy=io.powered and 1000000 or 0
  scheduler.tick(event.tick)
  assert(c.status~='faulted' and not c.diagnostic and not c.resource_refusal,serpent.line(c.diagnostic or c.resource_refusal))
  if s.phase=='reading' and sizes[s.index]==1100 and not s.reloaded then
    local pending=c.invocation and c.invocation.checkpoint.frame.pending
    local job=pending and pending.jobs and pending.jobs['result-data-2']
    if job and not job.done and job.bytes>0 and #job.source==1100 then
      s.phase='frozen'; s.copy_bytes=job.bytes; s.run_id=c.run_id
      game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
    end
  end
  if c.invocation then return end
  local function enqueue(name,fields)
    fields=fields or {}; fields.name=name; assert(runtime.enqueue(c,name,fields,event.tick))
  end
  if s.phase=='ready' and event.tick>=s.due then
    log('TC_LOGIC_NATIVE '..sizes[s.index]..' red='..#(io.children.input.get_signals(defines.wire_connector_id.circuit_red) or {})..' green='..#(io.children.input.get_signals(defines.wire_connector_id.circuit_green) or {}))
    enqueue('read',{count=sizes[s.index]}); s.phase='reading'
  elseif s.phase=='reading' and c.state.count==sizes[s.index] then
    if sizes[s.index]==150 then
      assert(#io.output_bank==150 and #io.children.output.get_control_behavior().get_section(1).filters==150)
    end
    s.index=s.index+1
    if sizes[s.index] then
      for _,color in ipairs({'red','green'}) do set(s[color],sizes[s.index],color=='green') end
      s.phase='ready'; s.due=event.tick+3
    else
      assert(s.reloaded,'large result never reached a cold boundary')
      s.red.get_control_behavior().get_section(1).filters={
        {index=1,value={type='recipe',name='iron-plate',quality='normal'},min=-9},
        {index=2,value={type='item',name='iron-plate',quality='normal'},min=7},
        {index=3,value={type='fluid',name='water',quality='normal'},min=11},
        {index=4,value={type='virtual',name='tc-inventory-'..string.rep('long-name-',12),quality='normal'},min=-13},
      }
      if script.active_mods.quality then s.red.get_control_behavior().get_section(1).set_slot(5,{value={type='item',name='iron-plate',quality='uncommon'},min=-3}) end
      s.phase='settling'; s.due=event.tick+3
    end
  elseif s.phase=='settling' and event.tick>=s.due then
    enqueue('identities',{quality=script.active_mods.quality~=nil}); s.phase='identities'
  elseif s.phase=='identities' and c.state.identities then
    if s.skip_large_filter then enqueue('cleanup'); s.phase='cleanup'
    else enqueue('filtered'); s.phase='filtered' end
  elseif s.phase=='filtered' and c.state.subscription then
    local sub=assert(c.subscriptions[c.state.subscription])
    assert(#sub.details.signals==1100 and #sub.details.previous==1100)
    enqueue('cleanup'); s.phase='cleanup'
  elseif s.phase=='cleanup' and c.state.cleaned then
    assert(next(c.subscriptions)==nil and #io.output_bank==0)
    enqueue('unpowered'); s.phase='unpowered'
  elseif s.phase=='unpowered' and c.state.unpowered then
    runtime.stop(c.id); s.phase='done'
    log('TC_CONTRACT native-64-65-150-1100-both-colors-scalar-bulk-output-identity-and-policy')
    if not s.skip_large_filter then log('TC_CONTRACT native-1100-filter-admission-and-unsubscribe') end
    log('TC_COLD_OK')
  end
end
return M
