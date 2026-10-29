-- Same witness runs against genuine pre-change code and the exact candidate.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local logic=require('scripts.services.logic')
local defs=require('scripts.device-definitions')
local M={}; local loaded=false
local function f() return storage.tc_circuit_upgrade end
local program=[[function start(e)
  computer.setState('boots',(computer.getState('boots') or 0)+1)
  local p=peripheral.find('logic_handler','red')
  p.setOutput({{signal={type='virtual',name='signal-A'},count=13}})
  p.subscribe({input='red',initial=true},'changed')
end

function changed(e)
  assert(#e.current==1 and e.current[1].signal.name=='iron-plate')
  if e.initial then computer.setState('first',e.current[1].count) end
  computer.setState('last',e.current[1].count)
  computer.setState('events',(computer.getState('events') or 0)+1)
end]]
local function put(n)
  f().source.get_control_behavior().get_section(1).set_slot(1,{value={type='item',name='iron-plate',quality='normal'},min=n})
end
function M.run()
  local s=game.surfaces[1]
  local function build(kind,x)
    return assert(lifecycle.build(assert(s.create_entity{name=defs.devices[kind].entity_name,position={x,0},force='player'})))
  end
  local c=build('computer',0); local io=build('logic',4)
  assert(lifecycle.connector(c,'network','red').connect_to(lifecycle.connector(io,'network','red')))
  local source=assert(s.create_entity{name='constant-combinator',position={4,-3},force='player'})
  source.get_or_create_control_behavior().add_section()
  assert(source.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(lifecycle.connector(io,'input','red')))
  assert(s.create_entity{name='substation',position={3,5},force='player'})
  local supply=assert(s.create_entity{name='electric-energy-interface',position={7,5},force='player'})
  supply.power_production=100000000; supply.power_usage=0
  storage.tc_circuit_upgrade={computer=c.id,logic=io.id,source=source,phase='boot',since=game.tick}
  put(21)
end
local function retained()
  local x=f(); local c=registry.computer(x.computer); local io=registry.record(x.logic)
  assert(c.queue==x.queue and c.queue_bytes==x.bytes and c.subscriptions==x.subscriptions)
  assert(c.run_id==x.run and c.state.boots==1 and not c.state.events and io.output_owner==x.owner)
  assert(c.queue[1].event.current==x.pending and (x.pending[1].signal.type or 'item')=='item' and (x.pending[1].signal.quality or 'normal')=='normal')
  assert(x.pending[1].count==21)
end
function M.on_load() loaded=true; if f().phase=='frozen' then retained(); log('TC_COLD_ON_LOAD_UNCHANGED') end end
function M.on_configuration_changed() retained(); f().upgraded=true end
function M.on_tick(event)
  local x=f(); local c=registry.computer(x.computer); local io=registry.record(x.logic)
  if x.phase=='done' then return end
  if x.phase=='frozen' then
    if not loaded then return end
    retained(); loaded=false; put(33); x.phase='resume'; x.since=event.tick
    return
  elseif x.phase=='resume' then
    if event.tick-x.since<4 then return end
    retained()
    assert(logic.inspect_input(io,'red',event.tick,function() end).values[1].count==33,'first post-load read reused old data')
    assert(logic.inspect_output(io,function() end)[1].count==13)
    x.phase='delivery'; x.since=event.tick
  elseif x.phase=='running' and c.state.boots==1 then
    logic.sample(event.tick,scheduler.maintenance(registry.get(),event.tick))
    assert(#c.queue==1 and not c.state.events)
    x.queue=c.queue; x.bytes=c.queue_bytes; x.subscriptions=c.subscriptions; x.run=c.run_id; x.owner=io.output_owner
    x.pending=c.queue[1].event.current
    retained(); x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  scheduler.tick(event.tick)
  assert(event.tick-x.since<90,'native upgrade deadline '..x.phase)
  if x.phase=='boot' and event.tick-x.since>=5 then
    runtime.save(c.id,program,0); assert(runtime.activate(c.id,event.tick)); x.phase='running'
  elseif x.phase=='delivery' and c.state.events==2 then
    assert(c.state.boots==1 and c.state.first==21 and c.state.last==33 and c.run_id==x.run)
    assert(io.output_owner==x.owner and #c.queue==0 and c.queue_bytes==0)
    assert(logic.inspect_output(io,function() end)[1].count==13)
    if x.upgraded then assert(not io.output_bank and not io.logic_sample) end
    x.phase='done'; log(x.upgraded and 'TC_UPGRADE_OK native-circuits-owner-registration-pending-event-no-replay' or 'TC_COLD_OK native-circuit-baseline')
  end
end
return M
