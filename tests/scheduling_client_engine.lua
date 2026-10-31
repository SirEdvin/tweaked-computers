-- Native connected peers: freeze paid demand after client one, resume on synchronized late join.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local defs=require('scripts.device-definitions')
local logic=require('scripts.services.logic')
local monitor=require('scripts.services.monitor')
local kv=require('scripts.services.kv')
local sandbox=require('scripts.runtime.sandbox')
local admission=require('scripts.runtime.admission')
local M={}
local function f() return storage.tc_scheduling_peers end
local source=[[function start(e)
  computer.setState('boots',(computer.getState('boots') or 0)+1)
  computer.setState('order','')
  local io=peripheral.find('logic_handler','red')
  io.setOutput({{signal={type='virtual',name='signal-A',quality='normal'},count=17}})
  io.subscribe({input='red',initial=true},'changed')
  local m=peripheral.find('monitor','red'); m.write('POWER-FREE'); m.setCursorBlink(true)
  computer.every(5,'periodic')
end
function periodic(e) computer.setState('periods',(computer.getState('periods') or 0)+1) end
function changed(e) computer.setState('changes',(computer.getState('changes') or 0)+1) end
function effect(e) computer.setState('order',computer.getState('order')..e.tag) end
function once(e) computer.setState('once',(computer.getState('once') or 0)+1) end
function forbidden(e) error('canceled timer replayed') end]]
local function build(kind,x,y)
  local b=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})
  local r=assert(lifecycle.build(b)); assert(not r.children.power and lifecycle.available(r)); return r
end
local function summary()
  local x=f(); local root=registry.get(); local c=registry.record(x.computer); local peers={}
  for _,p in pairs(game.connected_players) do peers[#peers+1]=p.index end; table.sort(peers)
  local queue={}; for i,item in ipairs(c.queue) do queue[i]={sequence=item.event.sequence,name=item.event.name,tag=item.event.tag,handler=item.handler} end
  local deadlines={}; for i,d in ipairs(root.scheduler.deadlines) do deadlines[i]={id=d.id,tick=d.tick,generation=d.generation,run_id=d.run_id} end
  local watches={}; for i,w in ipairs(root.logic_observers.order) do watches[i]={computer=w.computer.id,subscription=w.sub.id,input=w.input.key} end
  local due={}; for kind,lane in pairs(root.scheduler.due_work) do if type(lane)=='table' then
    local entries={}; due[kind]=entries
    for i,d in ipairs(lane.deadlines) do entries[i]={id=d.id,tick=d.tick,generation=d.generation} end
  end end
  local g=assert(monitor.resolve(registry.record(x.monitor)))
  return {phase=x.phase,peers=peers,run=c.run_id,boots=c.state.boots,order=c.state.order,once=c.state.once or 0,
    periods=c.state.periods or 0,changes=c.state.changes or 0,queue=queue,queue_bytes=c.queue_bytes,
    ready_count=root.scheduler.ready_count,deadlines=deadlines,watches=watches,due=due,
    next_sequence=root.next_sequence,ledger=root.ledger.total,ledger_tick=root.ledger.tick,
    maintenance=root.scheduler.maintenance_spent,maintenance_tick=root.scheduler.maintenance_tick,
    front=g.render and g.render.presented_revision,model=g.model.revision,
    kv=registry.record(x.kv).database.entries.keep.value,output=logic.inspect_output(registry.record(x.logic),function() end),
    idle=registry.record(x.idle).status,late_join=x.late_join or false}
end
local function publish()
  local text=helpers.table_to_json(summary())
  helpers.write_file('scheduling-server.json',text,false,0)
  for _,p in pairs(game.connected_players) do helpers.write_file('scheduling-client.json',text,false,p.index) end
end
function M.run()
  if remote.interfaces.freeplay then remote.call('freeplay','set_skip_intro',true); remote.call('freeplay','set_disable_crashsite',true) end
  local s=game.surfaces[1]; s.always_day=true
  s.request_to_generate_chunks({0,0},2); s.force_generate_chunk_requests()
  for _,e in ipairs(s.find_entities_filtered{area={{-8,-8},{16,10}},type={'tree','simple-entity','cliff'}}) do e.destroy() end
  local c=build('computer',0,0); local io=build('logic',4,0); local m=build('monitor',0,4); local db=build('kv',4,4); local idle=build('computer',8,4)
  for _,r in ipairs({io,m,db}) do assert(lifecycle.connector(c,'network','red').connect_to(lifecycle.connector(r,'network','red'))) end
  local constant=assert(s.create_entity{name='constant-combinator',position={4,-4},force='player'})
  local cb=constant.get_or_create_control_behavior(); for i=cb.sections_count,1,-1 do cb.remove_section(i) end
  local section=cb.add_section(); section.set_slot(1,{value={type='virtual',name='signal-B',quality='normal'},min=1}); cb.enabled=true
  assert(constant.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(lifecycle.connector(io,'input','red')))
  kv.methods.set(nil,db,nil,game.tick,function() end,'keep','retained')
  storage.tc_scheduling_peers={phase='boot',computer=c.id,logic=io.id,monitor=m.id,kv=db.id,idle=idle.id,section=section,since=game.tick}
  assert(runtime.save(c.id,source,0)); assert(runtime.activate(c.id,game.tick))
end
function M.on_load()
  local x=f(); if x.phase=='finished' then
    local c=assert(registry.record(x.computer)); assert(c.state.boots==1 and c.state.order=='ab' and c.state.once==1)
    log('TC_SCHEDULING_PEER_COLD_NO_REPLAY')
  end
end
function M.on_configuration_changed() error('unexpected peer fixture configuration change') end
function M.on_player_joined(event)
  local p=game.get_player(event.player_index); p.set_controller{type=defines.controllers.god}; p.teleport({2,2}); p.zoom=1
  if f().phase=='frozen' and #game.connected_players==2 then
    local c=registry.record(f().computer)
    assert(c.queue==f().queue and c.timers==f().timers and c.subscriptions==f().subscriptions)
    assert(c.state.boots==1 and c.state.order=='' and not c.state.once and #c.queue>=3)
    assert(registry.get().scheduler.ready==f().ready and registry.get().logic_observers==f().observers)
    f().late_join=true; f().phase='resuming'; f().resume_tick=game.tick
    log('TC_SCHEDULING_PEER_LATE_JOIN_RETAINED')
  end
end
function M.on_tick(event)
  local x=f(); local c=registry.record(x.computer)
  if x.phase=='frozen' or x.phase=='finished' then
    assert(c.state.boots==1)
    if x.phase=='finished' then assert(c.state.order=='ab' and c.state.once==1 and c.state.changes==x.expected_changes) end
    if event.tick%30==0 then publish() end
    return
  end
  if x.phase=='freezing' then
    if event.tick<x.freeze_tick+2 then return end
    logic.sample(event.tick,scheduler.maintenance(registry.get(),event.tick))
    assert(#c.queue>=1 and c.queue[1].event.name=='signal_changed')
    assert(runtime.enqueue(c,'effect',{name='fixture',tag='a'},event.tick)); assert(runtime.enqueue(c,'effect',{name='fixture',tag='b'},event.tick))
    local guard=sandbox.new(admission.context(registry.get().ledger,c.id,event.tick),{})
    local api=runtime.services(c,event.tick,guard).computer
    api.after(8,'once'); local canceled=api.after(9,'forbidden'); assert(api.cancelTimer(canceled))
    x.queue=c.queue; x.timers=c.timers; x.subscriptions=c.subscriptions
    x.ready=registry.get().scheduler.ready; x.observers=registry.get().logic_observers
    x.expected_changes=(c.state.changes or 0)+1; x.phase='frozen'; publish()
    log('TC_SCHEDULING_PEER_FROZEN'); return
  end
  scheduler.tick(event.tick)
  assert(c.status=='running',serpent.line(c.diagnostic))
  assert(registry.record(x.idle).status=='stopped')
  if x.phase=='boot' then
    assert(event.tick-x.since<7200,'first peer/setup deadline')
    local g=monitor.resolve(registry.record(x.monitor))
    if #game.connected_players==1 and c.state.boots==1 and c.state.changes and g and g.render and g.render.presented_revision==g.model.revision then
      x.section.set_slot(1,{value={type='virtual',name='signal-B',quality='normal'},min=7})
      x.freeze_tick=event.tick; x.phase='freezing'
    end
  else
    assert(x.phase=='resuming' and event.tick-x.resume_tick<120,'late-join completion deadline')
    if c.state.order=='ab' and c.state.once==1 and c.state.changes==x.expected_changes and #c.queue==0 then
      assert(x.late_join and c.state.boots==1 and c.state.periods>=1)
      x.phase='finished'; publish(); game.server_save('tc-scheduling-peer-finished')
      log('TC_SCHEDULING_MULTIPLAYER_OK')
    end
  end
end
return M
