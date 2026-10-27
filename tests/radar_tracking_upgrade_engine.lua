-- One fixture in immutable 0.1.15 and the candidate; production payloads stay unchanged.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local peripheral=require('scripts.services.peripheral')
local defs=require('scripts.device-definitions')
local M={}; local loaded=false
local function f() return storage.radar_tracking_upgrade end
local function nop() end
local source=[[function start(e) computer.setState('boots',(computer.getState('boots') or 0)+1) end
function received(e) computer.setState('messages',(computer.getState('messages') or 0)+1); computer.setState('payload',e.message) end]]
local function build_computer()
  return assert(lifecycle.build(assert(game.surfaces[1].create_entity{name=defs.devices.computer.entity_name,position={0,-8},force='player'})))
end
local function connect(c,r)
  assert(c.body.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(r.body.get_wire_connector(defines.wire_connector_id.circuit_red,true),false))
end
function M.run()
  assert(script.active_mods['tweaked-computers']=='0.1.15','baseline fixture must run original 0.1.15')
  storage.radar_tracking_upgrade={phase='boot',records={},channels={},bodies={},dormant={}}
  local s=f()
  for i=1,100 do
    local b=assert(game.surfaces[1].create_entity{name='radar',position={i*4,0},force='player'})
    lifecycle.on_built{entity=b}
    local r=assert(registry.by_entity(b)); r.modem={version=1,channels={[42]=true},count=1}
    s.records[i]=r.id; s.channels[r.id]=r.modem; s.bodies[r.id]=b; s.dormant[r.id]=true
  end
  if not settings.startup['tc-radar-tracking-upgrade-idle'].value then
    local c=build_computer(); s.computer=c.id; s.connected=s.records[1]; s.dormant[s.connected]=nil
    connect(c,registry.record(s.connected))
    runtime.save(c.id,source,0); assert(runtime.activate(c.id,game.tick))
  end
end
local function retained()
  local s=f(); local root=registry.get()
  for _,id in ipairs(s.records) do
    local r=assert(registry.record(id))
    assert(r.body==s.bodies[id] and r.body.valid and r.body.operable and r.body.minable and r.body.active)
    assert(r.modem==s.channels[id] and r.modem.channels[42] and r.modem.count==1)
  end
  assert(root.next_id==s.next_id and root.ledger==s.ledger)
  if s.computer then
    local c=registry.record(s.computer)
    assert(c.run_id==s.run_id and c.state==s.state and c.state.boots==1 and c.active.source==source)
  end
end
local function separated()
  local s=f(); local root=registry.get()
  assert(root.tracking_version==1 and root.retained_count==#s.records+(s.computer and 1 or 0))
  for _,id in ipairs(root.order) do assert(registry.record(id).kind~='radar') end
  assert(#root.order==(s.computer and 1 or 0))
  assert(root.scheduler.radar_cursor==nil)
end
local function credits()
  local root=registry.get()
  return {tick=root.ledger.tick,total=root.ledger.total,last_tick=root.scheduler.last_tick,
    maintenance_tick=root.scheduler.maintenance_tick,maintenance_spent=root.scheduler.maintenance_spent}
end
local function check_credits(expected)
  local actual=credits(); for k,v in pairs(expected) do assert(actual[k]==v,'renewed saved credit '..k) end
end
function M.on_load()
  loaded=true
  if f().phase=='installed' then retained(); separated(); check_credits(f().cold_credits) end
end
function M.on_configuration_changed()
  local s=f(); assert(s.phase=='legacy-frozen')
  retained(); separated(); check_credits(s.credits)
  if s.computer then
    local c=registry.record(s.computer)
    assert(#c.queue==1 and c.queue[1]==s.queued and c.queue[1].event.message=='upgrade-once' and not c.state.messages)
  end
  s.phase='installing'
  log('TC_TRACKING_BEFORE_FIRST_TICK '..helpers.table_to_json{radars=#s.records,ticking=#registry.get().order,credits=credits()})
end
local function tick_without_dormant(tick)
  local s=f(); local original=registry.record; local visits=0
  registry.record=function(id)
    assert(not s.dormant[id],'first gameplay tick visited dormant radar '..id)
    visits=visits+1; return original(id)
  end
  local ok,e=pcall(scheduler.tick,tick)
  registry.record=original
  assert(ok,serpent.line(e))
  log('TC_TRACKING_FIRST_TICK '..helpers.table_to_json{phase=s.phase,tick=tick,dormant_visits=0,identity_visits=visits})
end
function M.on_tick(event)
  local s=f()
  if s.phase=='legacy-frozen' then return end
  if s.phase=='boot' then
    loaded=false
    if s.computer then lifecycle.power_entity(registry.record(s.computer)).energy=1000000 end
    scheduler.tick(event.tick)
    local c=s.computer and registry.record(s.computer)
    if c and c.state.boots~=1 then return end
    if c then
      assert(runtime.enqueue(c,'received',{name='modem_message',message='upgrade-once'},event.tick,nop))
      s.queued=c.queue[1]; s.run_id=c.run_id; s.state=c.state
    end
    local root=registry.get(); s.next_id=root.next_id; s.ledger=root.ledger; s.credits=credits()
    assert(#root.order==#s.records+(c and 1 or 0))
    s.phase='legacy-frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif s.phase=='installing' then
    retained(); separated(); check_credits(s.credits)
    if s.computer then lifecycle.power_entity(registry.record(s.computer)).energy=1000000 end
    tick_without_dormant(event.tick)
    if s.computer then
      local c=registry.record(s.computer)
      assert(c.state.messages==1 and c.state.payload=='upgrade-once' and #c.queue==0)
      assert(peripheral.inventory(c,'red',nop)[s.connected])
    end
    s.phase='installed'; s.cold_credits=credits(); loaded=false; log('TC_UPGRADE_OK')
  elseif s.phase=='installed' and loaded then
    loaded=false; retained(); separated(); check_credits(s.cold_credits)
    if s.computer then lifecycle.power_entity(registry.record(s.computer)).energy=1000000 end
    tick_without_dormant(event.tick)
    if s.computer then assert(registry.record(s.computer).state.messages==1 and #registry.record(s.computer).queue==0) end
    local c=s.computer and registry.record(s.computer) or build_computer()
    local r=registry.record(s.records[#s.records]); connect(c,r)
    -- Existing identity is usable immediately; no dormant sweep or re-enrollment.
    assert(peripheral.inventory(c,'red',nop)[r.id] and r.modem==s.channels[r.id] and r.modem.channels[42])
    s.phase='done'; log('TC_UPGRADE_ORDINARY_OK')
  end
end
return M
