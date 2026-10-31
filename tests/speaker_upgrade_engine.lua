-- Shared released-0.1.10/candidate fixture: imports only released modules.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local peripheral=require('scripts.services.peripheral')
local monitor=require('scripts.services.monitor')
local defs=require('scripts.device-definitions')
local M={}; local loaded=false
local source=[[function start(e)
  computer.setState('boots',(computer.getState('boots') or 0)+1)
  peripheral.find('kv_database','red').set('retained','released-save')
  peripheral.find('monitor','red').write('KEEP')
end]]
local function f() return storage.speaker_upgrade end
local function build(kind,x,y)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})
  lifecycle.on_built{entity=body}; return assert(registry.by_entity(body))
end
local function connect(a,b)
  assert(a.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(b.get_wire_connector(defines.wire_connector_id.circuit_red,true),false))
end
local function settings(b)
  local cb=b.get_or_create_control_behavior()
  return serpent.line{parameters=b.parameters,alert=b.alert_parameters,circuit=cb.circuit_parameters}
end
function M.run()
  storage.speaker_upgrade={phase='boot'}
  local c=build('computer',0,0); local db=build('kv',3,0); local m=build('monitor',3,3)
  local b=assert(c.body.surface.create_entity{name='programmable-speaker',position={7,0},force='player'})
  local p=b.parameters; p.playback_mode='global'; p.playback_volume=.4; p.allow_polyphony=true; b.parameters=p
  connect(c.body,db.body); connect(db.body,m.body); connect(c.body,b)
  f().c=c.id; f().db=db.id; f().monitor=m.id; f().speaker=b; f().settings=settings(b)
  f().c_body=c.body; f().db_body=db.body; f().m_body=m.body
  f().wire=b.get_wire_connector(defines.wire_connector_id.circuit_red,false)
  runtime.save(c.id,source,0); assert(runtime.activate(c.id,game.tick))
end
local function retained(loading)
  local s=f(); local c,db,m=registry.record(s.c),registry.record(s.db),registry.record(s.monitor)
  assert(c.body==s.c_body and db.body==s.db_body and m.body==s.m_body and c.state.boots==1)
  assert(c.active.source==source and c.run_id==s.run_id and c.state==s.state and db.database==s.database)
  assert(s.speaker.valid and s.speaker.name=='programmable-speaker' and s.speaker.operable and s.speaker.minable)
  assert(settings(s.speaker)==s.settings)
  assert(s.speaker.get_wire_connector(defines.wire_connector_id.circuit_red,false)==s.wire)
  assert(s.wire.is_connected_to(c.body.get_wire_connector(defines.wire_connector_id.circuit_red,false)))
  local monitors=registry.get().monitors
  local group=loading and monitors.groups[monitors.membership[m.id]] or monitor.resolve(m)
  assert(group.model==s.model)
end
function M.on_load()
  loaded=true
  if f().phase~='boot' then retained(true); log('TC_SPEAKER_UPGRADE_LOAD_UNCHANGED') end
end
function M.on_configuration_changed()
  retained()
  if f().phase=='legacy-frozen' then
    assert(not registry.by_entity(f().speaker) and registry.get().speaker_audio==nil)
    local ok,e=pcall(peripheral.inventory,registry.record(f().c),'red',function() end)
    assert(not ok and e.code=='E_NETWORK_PENDING')
    f().phase='installing'
  end
end
function M.on_tick(event)
  local s=f()
  if s.phase=='legacy-frozen' then return end
  if s.phase=='installed' then
    if loaded then retained(); assert(registry.get().speaker_audio==nil); log('TC_UPGRADE_ORDINARY_OK'); loaded=false end
    return
  end
  loaded=false
  for _,id in ipairs({s.c,s.db,s.monitor}) do local rec=registry.record(id)
    if lifecycle.power_entity then lifecycle.power_entity(rec).energy=1000000; rec.powered=true
    else assert(not rec.children.power and lifecycle.available(rec)) end
  end
  s.speaker.energy=1000000
  scheduler.tick(event.tick)
  if s.phase=='boot' and registry.record(s.c).state.boots==1 then
    local c,db,m=registry.record(s.c),registry.record(s.db),registry.record(s.monitor)
    s.state=c.state; s.run_id=c.run_id; s.database=db.database; s.model=monitor.resolve(m).model
    s.next_id=registry.get().next_id; s.phase='legacy-frozen'
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif s.phase=='installing' and registry.by_entity(s.speaker) then
    retained()
    local rec=registry.by_entity(s.speaker)
    assert(rec.native_carrier=='speaker' and next(rec.children)==nil and registry.get().next_id==s.next_id+1)
    assert(peripheral.inventory(registry.record(s.c),'red',function() end)[rec.id])
    assert(registry.get().speaker_audio==nil,'installation must not dispatch startup audio')
    s.phase='installed'; log('TC_UPGRADE_OK')
  end
end
return M
