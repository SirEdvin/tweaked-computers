-- Shared native channels through the real scheduler and retained-memory guard.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local radar=require('scripts.radar')
require('scripts.services.modem')
local M={}; local loaded=false
local source=[[
function policy(m)
  local p=m.getLimits(); local common=computer.getLimits()
  assert(p.policy_version==2,'Modem must expose resource policy v2')
  assert(select('#',m.getLimits())==1 and p.channel_min==0 and p.channel_max==9007199254740991 and next(p.tuning)==nil)
  for _,key in ipairs({'open_channels','message_bytes','message_nodes','message_depth','routing_candidates',
      'deliveries_per_transmit','transmits_per_computer_tick','transmits_per_tick','table_entries','callback_work'}) do assert(p[key]==nil) end
  local keys={'callback_work','callback_allocations','host_work_per_tick','maintenance_work_per_tick',
    'runtime_memory_bytes','host_memory_bytes','pending_work_bytes','host_stack_depth','event_queue_bytes'}
  local count=0; for _ in pairs(p.resources) do count=count+1 end; assert(count==#keys)
  for _,key in ipairs(keys) do
    for field,value in pairs(common.resources[key]) do assert(p.resources[key][field]==value) end
    for field,value in pairs(p.resources[key]) do assert(common.resources[key][field]==value) end
  end
  p.resources.host_memory_bytes.limit=1
  assert(m.getLimits().resources.host_memory_bytes.limit==common.resources.host_memory_bytes.limit)
  local ok,e=pcall(m.getLimits,nil); assert(not ok and e.code=='E_ARGUMENT')
  ok,e=pcall(m.getLimits,m); assert(not ok and e.code=='E_ARGUMENT')
end
function start()
  policy(assert(peripheral.find('modem','red')))
  computer.setState('starts',(computer.getState('starts') or 0)+1)
end
function open()
  local m=assert(peripheral.find('modem','red')); assert(m.isWireless())
  for ch=0,129 do assert(select('#',m.open(ch))==0) end
  assert(select('#',m.open(65536))==0 and select('#',m.open(9007199254740991))==0)
  computer.setState('opened',true)
end
function shared()
  local m=assert(peripheral.find('modem','green'))
  for ch=0,129 do assert(m.isOpen(ch)); assert(select('#',m.open(ch))==0) end
  assert(m.isOpen(65536) and m.isOpen(9007199254740991))
  assert(select('#',m.close(65536))==0 and not m.isOpen(65536))
  assert(select('#',m.close(65536))==0 and select('#',m.open(65536))==0)
  for _,method in ipairs({'open','isOpen','close'}) do
    for _,value in ipairs({'x',false,{}}) do
      local ok,e=pcall(m[method],value); assert(not ok and e.code=='E_ARGUMENT')
    end
    for _,value in ipairs({-1,0.5,9007199254740992,math.huge}) do
      local ok,e=pcall(m[method],value); assert(not ok and e.code=='E_RANGE')
    end
    local ok,e=pcall(m[method]); assert(not ok and e.code=='E_ARGUMENT')
    ok,e=pcall(m[method],m,0); assert(not ok and e.code=='E_ARGUMENT')
  end
  for _,value in ipairs({-1,0.5,9007199254740992}) do
    local ok,e=pcall(m.transmit,value,0,nil); assert(not ok and e.code=='E_RANGE')
    ok,e=pcall(m.transmit,0,value,nil); assert(not ok and e.code=='E_RANGE')
  end
  computer.setState('shared',true)
end
function cleanup()
  local m=assert(peripheral.find('modem','green'))
  assert(m.isOpen(129) and m.isOpen(65536) and m.isOpen(9007199254740991))
  assert(select('#',m.closeAll())==0 and select('#',m.closeAll())==0)
  assert(not m.isOpen(0) and not m.isOpen(129) and not m.isOpen(9007199254740991))
  computer.setState('cleaned',true)
end
function unpowered()
  local m=assert(peripheral.find('modem','red')); policy(m)
  for _,method in ipairs({'isWireless','closeAll'}) do
    local ok,e=pcall(m[method]); assert(not ok and e.code=='E_UNPOWERED')
  end
  local ok,e=pcall(m.isOpen,0); assert(not ok and e.code=='E_UNPOWERED')
  computer.setState('unpowered',true)
end]]
local function state() return storage.modem_policy_fixture end
local function record(id) return assert(registry.record(id)) end
local function power(rec,on)
  lifecycle.power_entity(rec).energy=on and 1000000 or 0; rec.powered=on
end
local function connect(c,r,color)
  assert(lifecycle.connector(c,'network',color).connect_to(r.body.get_wire_connector(defines.wire_connector_id['circuit_'..color],true),false))
end
function M.run()
  registry.initialize()
  local function computer(x)
    local body=assert(game.surfaces[1].create_entity{name=defs.devices.computer.entity_name,position={x,0},force='player'})
    local c=assert(lifecycle.build(body)); power(c,true); return c
  end
  local c,d=computer(0),computer(8)
  local body=assert(game.surfaces[1].create_entity{name='radar',position={4,0},force='player'})
  local r=assert(radar.build(body)); power(r,true)
  for _,color in ipairs({'red','green'}) do connect(c,r,color); connect(d,r,color) end
  storage.modem_policy_fixture={phase='starting',computer=c.id,peer=d.id,radar=r.id}
  for _,rec in ipairs({c,d}) do assert(runtime.save(rec.id,source,rec.saved_revision)); assert(runtime.activate(rec.id,game.tick)) end
end
function M.on_load() if state() and state().phase=='frozen' then loaded=true end end
function M.on_tick(event)
  local s=state(); if not s or s.phase=='done' then return end
  local c,d,r=record(s.computer),record(s.peer),record(s.radar)
  if s.phase=='frozen' then
    if not loaded then return end
    loaded=false
    assert(c.status=='stopped' and d.run_id==s.run_id and r.modem.count==132 and c.state.starts==1 and d.state.starts==1)
    assert(r.modem.channels[129] and r.modem.channels[65536] and r.modem.channels[9007199254740991])
    local root=registry.get()
    assert(root.host_memory.used==s.host_used and r.host_channels==r.modem.channels
      and root.host_memory_owner.values[r.modem.channels])
    s.phase='cleanup'; assert(runtime.enqueue(d,'cleanup',{name='cleanup'},event.tick))
    log('TC_CONTRACT cold-shared-132-channel-set-owner-and-no-startup-replay')
  end
  assert(event.tick<1600,'modem policy fixture timed out: '..serpent.line(c.diagnostic or d.diagnostic or d.resource_refusal))
  power(c,true); power(d,true); power(r,s.phase~='unpowered')
  scheduler.tick(event.tick)
  for _,rec in ipairs({c,d}) do assert(rec.status~='faulted' and not rec.diagnostic and not rec.resource_refusal,serpent.line(rec.diagnostic or rec.resource_refusal)) end
  if c.invocation or d.invocation or c.start_pending or d.start_pending then return end
  if s.phase=='starting' then
    assert(runtime.enqueue(c,'open',{name='open'},event.tick)); s.phase='opening'
  elseif s.phase=='opening' and c.state.opened then
    assert(r.modem.count==132 and r.host_channels==r.modem.channels)
    runtime.stop(c.id); assert(c.status=='stopped' and r.modem.count==132)
    assert(runtime.enqueue(d,'shared',{name='shared'},event.tick)); s.phase='sharing'
  elseif s.phase=='sharing' and d.state.shared then
    assert(r.modem.count==132 and #c.queue==0 and #d.queue==0)
    s.run_id=d.run_id; s.host_used=registry.get().host_memory.used; s.phase='frozen'
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif s.phase=='cleanup' and d.state.cleaned then
    assert(r.modem.count==0 and next(r.modem.channels)==nil and r.host_channels==nil)
    assert(registry.get().host_memory.used<s.host_used)
    s.phase='unpowered'; assert(runtime.enqueue(d,'unpowered',{name='unpowered'},event.tick))
  elseif s.phase=='unpowered' and d.state.unpowered then
    assert(c.state.starts==1 and d.state.starts==1)
    runtime.stop(d.id); s.phase='done'
    log('TC_CONTRACT native-safe-integer-shared-channels-policy-validation-stop-and-release')
    log('TC_COLD_OK')
  end
end
return M
