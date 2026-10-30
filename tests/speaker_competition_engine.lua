-- Eight powered speakers at the published world note ceiling, plus the unchanged
-- four-wall chart and a normal controller, all on production tick/work ledgers.
local animation=require('tests.monitor_animation_engine')
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local speaker=require('scripts.speaker')
local defs=require('scripts.device-definitions')
local M={}
local source=[[function start(e) computer.after(120-computer.getTick()%60,'chord') end
function chord(e)
  local s=peripheral.find('speaker','red'); assert(s)
  local page=s.getSounds(); assert(#page.sounds==50)
  for i=0,7 do assert(s.playNote('piano',0,i)) end
  assert(not s.playNote('piano',0,0))
  computer.setState('accepted',(computer.getState('accepted') or 0)+8)
  computer.setState('sample_tick',computer.getTick())
  computer.after(60-computer.getTick()%60,'chord')
end]]
local logic_source=[[function start(e) computer.every(15,'sample') end
function sample(e)
  local io=peripheral.find('logic_handler','red')
  local value=io.readSignal('red',{type='item',name='iron-plate',quality='normal'})
  io.setOutput({{signal={type='virtual',name='signal-A',quality='normal'},count=value<100 and 1 or 0}})
  computer.setState('sample_tick',computer.getTick())
end]]
local function build(kind,x,y)
  local name=kind=='speaker' and 'programmable-speaker' or defs.devices[kind].entity_name
  local body=assert(game.surfaces[1].create_entity{name=name,position={x,y},force='player'})
  return assert(lifecycle.build(body))
end
local function connect(a,b,role)
  local from=a.body.get_wire_connector(defines.wire_connector_id.circuit_red,true)
  local to=role and lifecycle.connector(b,role,'red') or b.body.get_wire_connector(defines.wire_connector_id.circuit_red,true)
  assert(from.connect_to(to,false))
end
local function activate(c,program) assert(runtime.save(c.id,program,0)); assert(runtime.activate(c.id,game.tick)) end
function M.run()
  animation.run()
  storage.speaker_competition={computers={},speakers={},full_ticks=0}
  local x=storage.speaker_competition
  for i=1,8 do
    local c=build('computer',-30,-i*8); local s=build('speaker',-24,-i*8)
    connect(c,s); activate(c,source); x.computers[i]=c.id; x.speakers[i]=s.id
  end
  local c=build('computer',-42,-8); local io=build('logic',-38,-8); connect(c,io); activate(c,logic_source)
  x.logic=c.id; x.handler=io.id
  local constant=assert(c.body.surface.create_entity{name='constant-combinator',position={-38,-12},force='player'})
  local cb=constant.get_or_create_control_behavior(); for i=cb.sections_count,1,-1 do cb.remove_section(i) end
  cb.add_section().set_slot(1,{value={type='item',name='iron-plate',quality='normal'},min=99}); cb.enabled=true
  assert(constant.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(lifecycle.connector(io,'input','red'),false))
  x.constant=constant
end
function M.on_load() animation.on_load() end
function M.on_configuration_changed() animation.on_configuration_changed() end
function M.on_tick(event)
  local x=storage.speaker_competition
  -- Preserve the original native supply after native carriers left generic tick order.
  for _,id in ipairs(x.speakers) do local r=registry.record(id); r.body.energy=100000; assert(speaker.available(r)) end
  if storage.tc_animation.phase=='drawing' and event.tick%15==0 then
    x.constant.get_control_behavior().get_section(1).set_slot(1,{value={type='item',name='iron-plate',quality='normal'},min=event.tick%30==0 and 99 or 101})
  end
  animation.on_tick(event)
  for _,id in ipairs(x.computers) do local r=registry.record(id); assert(r.status=='running',id..' '..serpent.line(r.diagnostic)) end
  local ledger=registry.get().speaker_audio
  if ledger and ledger.tick==event.tick then
    assert(ledger.total==64,'all eight aligned chords must share the world limit: '..serpent.line(ledger))
    for _,id in ipairs(x.computers) do assert(ledger.computers[id]==8) end
    for _,id in ipairs(x.speakers) do assert(ledger.speakers[id].notes==8 and ledger.speakers[id].sounds==0) end
    x.full_ticks=x.full_ticks+1
  end
  if storage.tc_animation.phase=='done' and not x.finished then
    local c=registry.record(x.logic)
    assert(c.status=='running' and c.state.sample_tick and registry.record(x.handler).output_owner)
    assert(x.full_ticks>=10)
    local total=0
    for _,id in ipairs(x.computers) do local r=registry.record(id); assert(r.state.accepted>=80); total=total+r.state.accepted end
    x.finished=true; log('TC_SPEAKER_COMPETITION_OK full_ticks='..x.full_ticks..' accepted='..total..' logic_sample='..c.state.sample_tick)
  end
end
return M
