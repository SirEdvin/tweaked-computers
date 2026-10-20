-- Same production ledgers/ticks as the unchanged four-wall/mixed chart gate.
local animation=require('tests.monitor_animation_engine')
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local defs=require('scripts.device-definitions')
-- Polling is a normal supported controller workload. The separate lossless
-- every-tick subscription envelope is not promised alongside four maximum
-- walls; its explicit E_BUSY fail-closed refusal is retained in stress evidence.
local logic_source=[[function start(e) computer.every(15,'sample') end
function sample(e)
  local io=peripheral.find('logic_handler','red')
  local count=io.readSignal('red',{type='item',name='iron-plate',quality='normal'})
  io.setOutput({{signal={type='virtual',name='signal-A',quality='normal'},count=count<100 and 1 or 0}})
  computer.setState('sample_tick',computer.getTick())
end]]
local M={}
local send_source=[[function start(e) computer.every(15,'send') end
function send(e)
  local m=peripheral.find('modem','red')
  m.transmit(42,17,string.rep('x',m.getLimits().message_bytes-8))
  computer.setState('sent',(computer.getState('sent') or 0)+1)
end]]
local receive_source=[[function start(e)
  peripheral.find('modem','red').open(42)
  for i=1,8 do computer.on('modem_message','received') end
end
function received(e)
  assert(#e.message==4088)
  computer.setState('received',(computer.getState('received') or 0)+1)
end]]
local function build(kind,x,y)
  local name=kind=='radar' and 'radar' or defs.devices[kind].entity_name
  local body=assert(game.surfaces[1].create_entity{name=name,position={x,y},force='player'})
  lifecycle.on_built{entity=body}; return assert(registry.by_entity(body))
end
local function connect(a,b,role)
  local from=a.body.get_wire_connector(defines.wire_connector_id.circuit_red,true)
  local target=role and lifecycle.connector(b,role,'red') or b.body.get_wire_connector(defines.wire_connector_id.circuit_red,true)
  assert(from.connect_to(target,false))
end
local function activate(c,source)
  runtime.save(c.id,source,0); assert(runtime.activate(c.id,game.tick))
end
function M.run()
  animation.run()
  local a=build('computer',-20,-20); local r=build('radar',-14,-20)
  local b=build('computer',-20,-30); local s=build('radar',-14,-30)
  connect(a,r); connect(b,s)
  activate(b,receive_source); activate(a,send_source)
  local c=build('computer',-30,-20); local io=build('logic',-26,-20); connect(c,io)
  local constant=assert(c.body.surface.create_entity{name='constant-combinator',position={-26,-24},force='player'})
  local behavior=constant.get_or_create_control_behavior()
  for i=behavior.sections_count,1,-1 do behavior.remove_section(i) end
  local section=behavior.add_section()
  section.set_slot(1,{value={type='item',name='iron-plate',quality='normal'},min=99})
  constant.get_control_behavior().enabled=true
  assert(constant.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(lifecycle.connector(io,'input','red'),false))
  activate(c,logic_source)
  storage.modem_competition={sender=a.id,receiver=b.id,logic=c.id,handler=io.id,constant=constant}
end
function M.on_load() animation.on_load() end
function M.on_configuration_changed() animation.on_configuration_changed() end
function M.on_tick(event)
  local state=storage.modem_competition
  if storage.tc_animation.phase=='drawing' and event.tick%15==0 then
    state.constant.get_control_behavior().get_section(1).set_slot(1,{value={type='item',name='iron-plate',quality='normal'},min=event.tick%30==0 and 99 or 101})
  end
  animation.on_tick(event)
  for _,id in ipairs({state.sender,state.receiver,state.logic}) do
    local rec=registry.record(id)
    assert(rec.status=='running',id..' '..serpent.line(rec.diagnostic))
  end
  if storage.tc_animation.phase=='done' and not state.finished then
    local a,b,c=registry.record(state.sender),registry.record(state.receiver),registry.record(state.logic)
    assert(a.status=='running' and b.status=='running' and c.status=='running')
    assert(a.state.sent>10 and b.state.received>50 and c.state.sample_tick)
    assert(registry.record(state.handler).output_owner)
    state.finished=true
    log('TC_MODEM_COMPETITION_OK sent='..a.state.sent..' received='..b.state.received..' logic_sample='..c.state.sample_tick)
  end
end
return M
