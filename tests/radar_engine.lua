local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local peripheral=require('scripts.services.peripheral')
local radar=require('scripts.radar')
local graph=require('scripts.network')
local defs=require('scripts.device-definitions')
local limits=require('scripts.runtime.limits')
local blueprints=require('scripts.blueprints')
local modem=require('scripts.services.modem')
local radio_guard=require('tests.radio_test_guard')
local speaker=require('scripts.speaker')
local M={}; local loaded=false
local function nop() end
local function f() return storage.radar_fixture end
local function report(name) f().groups=f().groups+1; log('TC_CONTRACT '..name) end
local function error_is(code,fn)
  local ok,e=pcall(fn); assert(not ok and type(e)=='table' and e.code==code,'expected '..code..': '..serpent.line(e))
end
local function build(kind,x,y)
  local b=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})
  lifecycle.on_built{entity=b}; local rec=assert(registry.by_entity(b))
  lifecycle.power_entity(rec).energy=1000000; return rec
end
local function native(x,y,raised)
  local b=assert(game.surfaces[1].create_entity{name='radar',position={x,y},force='player'})
  if raised then lifecycle.on_built{entity=b} end
  return b
end
local function conn(b,color) return assert(b.get_wire_connector(defines.wire_connector_id['circuit_'..color],true)) end
function M.run()
  storage.radar_fixture={groups=0,phase='initial'}
  if script.active_mods['space-age'] then
    game.forces.player.technologies['tc-interplanetary-radar'].researched=true
    game.forces.player.recipes['tc-interplanetary-radar'].enabled=false
    game.create_force('radar-unresearched')
  end
  local tiles={}; for x=-16,120 do for y=-12,20 do tiles[#tiles+1]={name='landfill',position={x,y}} end end
  game.surfaces[1].set_tiles(tiles)
  local c=build('computer',0,0); local db=build('kv',12,0)
  local unsupported=assert(c.body.surface.create_entity{name='tc-fixture-unsupported-radar',position={0,-6},force='player'})
  lifecycle.on_built{entity=unsupported}
  assert(not radar.supports(unsupported) and not registry.by_entity(unsupported))
  assert(conn(c.body,'green').connect_to(conn(unsupported,'green'),false))
  assert(next((peripheral.inventory(c,'green',nop)))==nil and unsupported.valid)
  unsupported.destroy()
  local a=native(6,0,true); local b=native(100,0,true)
  local rec=assert(registry.by_entity(a)); local remote=assert(registry.by_entity(b))
  assert(rec.native_carrier=='radar' and next(rec.children)==nil and not rec.layout_version)
  assert(a.operable and a.minable and a.active and a.name=='radar')
  assert(lifecycle.build(a)==rec and registry.by_entity(a)==rec)
  conn(c.body,'red').connect_to(conn(a,'red'),false)
  conn(a,'red').connect_to(conn(db.body,'red'),false)
  local inv=peripheral.inventory(c,'red',nop); assert(inv[rec.id] and inv[db.id] and not inv[remote.id])
  assert(next((peripheral.inventory(c,'green',nop)))==nil)
  local _,path=peripheral.authority(c,db.id,'red',nop)
  assert(#path==3 and graph.validate_witness(c,'red',path,nop))
  report('native-identity-idempotent-no-helpers-and-physical-relay')
  a.energy=1000000; radio_guard.call(modem,c,rec,'open',7)
  local selection=game.create_inventory(1); selection[1].set_stack{name='blueprint',count=1}
  local bp=selection[1]
  local mapping=bp.create_blueprint{surface=a.surface,force='player',area={{-1,-1},{15,3}}}
  assert(blueprints.prepare(bp,mapping))
  local found=false
  for _,entry in ipairs(bp.get_blueprint_entities()) do
    if entry.name=='radar' then
      found=true; assert(not entry.tags or not entry.tags.tc_settings and not entry.tags.tc_body_token)
    end
  end
  assert(found and rec.modem.channels[7] and a.valid and a.operable)
  blueprints.on_pasted{source=a,destination=b}
  local energy=a.energy; lifecycle.normalize_power(rec); lifecycle.reset_network(rec)
  assert(a.energy==energy and a.active and a.operable and rec.modem.channels[7])
  selection.destroy()
  report('mixed-native-blueprint-settings-paste-and-power-guards-preserve-native-state')
  local clone=assert(a.clone{position={6,6},surface=a.surface,force=a.force,create_build_effect_smoke=false})
  lifecycle.on_cloned{source=a,destination=clone}
  local copied=assert(registry.by_entity(clone)); assert(copied.id~=rec.id and copied.modem.count==0 and clone.operable and rec.modem.channels[7])
  lifecycle.remove(copied.id,'fixture',false); assert(clone.valid); clone.destroy()
  local ghost=assert(a.surface.create_entity{name='entity-ghost',inner_name='radar',position={6,6},force='player'})
  local _,revived=ghost.revive{raise_revive=true}; assert(revived,'native ghost revival refused')
  -- Factorio suppresses raised entity events during on_init; exercise the
  -- composed handler here, then actual raised events during the tick phase.
  lifecycle.on_built{entity=revived}; assert(registry.by_entity(revived))
  local revived_id=registry.by_entity(revived).id
  local inventory=game.create_inventory(10); lifecycle.on_removed{entity=revived}
  assert(revived.mine{inventory=inventory,raise_destroyed=true})
  assert(inventory.get_item_count('radar')==1 and not registry.record(revived_id)); inventory.destroy()
  report('native-clone-revive-and-mining-material-identity')
  -- A genuine registration refusal must leave the native body untouched.
  local full=native(6,12,false); local order=registry.get().order
  local original=limits.registry_entries; limits.registry_entries=#order
  local added,e=radar.build(full); limits.registry_entries=original
  assert(not added and e.code=='E_CAPACITY' and full.valid and full.operable and full.minable)
  full.destroy()
  report('native-registration-capacity-preserves-material')
  for i,carrier in ipairs({radar,speaker}) do
    local name=i==1 and 'radar' or 'programmable-speaker'
    local body=assert(c.body.surface.create_entity{name=name,position={-12,i*8},force='player'})
    local lost=assert(carrier.build(body)); body.destroy() -- No raised removal event.
    local dummy={scheduler={last_tick=-1},ledger={tick=0,total=0}}
    local spend=scheduler.maintenance(dummy,0)
    spend(limits.maintenance_work_per_tick-dummy.scheduler.render_reserved_work-16)
    assert(not scheduler.try_maintenance(function() carrier.reconcile(lost,spend) end))
    assert(registry.record(lost.id)==lost,'refused cleanup must retain its identity')
    spend=scheduler.maintenance(dummy,1)
    assert(scheduler.try_maintenance(function() assert(carrier.reconcile(lost,spend)) end))
    assert(not registry.record(lost.id) and dummy.scheduler.maintenance_spent==16+limits.registry_entries*6)
  end
  report('missed-native-radar-and-speaker-removal-prepaid-before-registry-walk')
  local old=native(-6,0,false)
  conn(c.body,'green').connect_to(conn(old,'green'),false)
  error_is('E_NETWORK_PENDING',function() peripheral.inventory(c,'green',nop) end)
  registry.get().scheduler.radar_cursor=1
  for _=1,#registry.get().order+2 do radar.tick(game.tick,nop) end
  local adopted=assert(registry.by_entity(old)); assert(peripheral.inventory(c,'green',nop)[adopted.id])
  local next_id=registry.get().next_id
  for _=1,#registry.get().order+2 do radar.tick(game.tick,nop) end
  assert(registry.get().next_id==next_id and old.valid)
  report('bounded-connected-frontier-existing-radar-adoption')
  -- Remote local wires are deliberately out of physical reach, never discovery.
  conn(b,'red').connect_to(conn(build('kv',106,0).body,'red'),false)
  local power=assert(a.surface.create_entity{name='electric-energy-interface',position={0,8},force='player'})
  power.power_production=1000000000; power.electric_buffer_size=1000000000; power.energy=1000000000
  local remote_power=assert(a.surface.create_entity{name='electric-energy-interface',position={100,8},force='player'})
  remote_power.power_production=1000000000; remote_power.electric_buffer_size=1000000000; remote_power.energy=1000000000
  for _,x in ipairs({0,12,96,108}) do a.surface.create_entity{name='substation',position={x,8},force='player'} end
  a.energy=1000000; b.energy=1000000
  local constant=assert(a.surface.create_entity{name='constant-combinator',position={3,-4},force='player'})
  local behavior=constant.get_or_create_control_behavior(); local section=behavior.add_section()
  section.set_slot(1,{value={type='virtual',name='signal-A',quality='normal'},min=17}); behavior.enabled=true
  assert(conn(constant,'red').connect_to(conn(a,'red'),false))
  f().a=rec.id; f().b=remote.id; f().computer=c.id; f().db=db.id; f().old=adopted.id
  f().body=a; f().remote=b; f().native_count=#registry.get().order; f().scan=a.radar_scan_progress
  game.tick_paused=false
  log('TC_CONTRACT_TOTAL '..f().groups)
end
function M.on_load()
  loaded=true
  if f().phase=='snapshot' then
    assert(not registry.by_entity(f().pending) and registry.get().next_id==f().next_id)
    log('TC_RADAR_PENDING_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  local s=f()
  if s.phase=='initial' then loaded=false end
  if s.phase=='initial' and event.tick>=120 then
    -- Engine forms hidden links only after power/ticks; assert actual origins.
    local hidden=false
    for _,edge in ipairs(conn(s.body,'red').real_connections) do
      if edge.origin==defines.wire_origin.radars then hidden=true end
    end
    assert(hidden,'engine did not form native hidden radar links')
    local c=registry.record(s.computer)
    local inv=peripheral.inventory(c,'red',nop)
    assert(inv[s.a] and inv[s.db] and not inv[s.b])
    assert(not graph.validate_witness(c,'red',{s.computer,s.a,s.b},nop))
    assert(s.body.radar_scan_progress~=s.scan,'native radar scanning did not advance')
    assert(s.remote.get_signal({type='virtual',name='signal-A'},defines.wire_connector_id.circuit_red)==17)
    report('actual-powered-native-hidden-link-discovery-and-witness-isolation')
    local raised=s.body.surface.create_entity{name='radar',position={6,12},force='player',raise_built=true}
    assert(raised and registry.by_entity(raised),'actual script-raised native build missing')
    local id=registry.by_entity(raised).id
    raised.destroy{raise_destroy=true}; assert(not registry.record(id))
    s.pending=native(-12,0,false)
    assert(conn(registry.record(s.old).body,'green').connect_to(conn(s.pending,'green'),false))
    error_is('E_NETWORK_PENDING',function() peripheral.inventory(c,'green',nop) end)
    s.next_id=registry.get().next_id
    s.phase='snapshot'; s.tick=event.tick
    game.server_save('tc03-snapshot')
    log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif loaded and s.phase=='snapshot' then
    assert(registry.record(s.a).body==s.body and registry.record(s.b).body==s.remote)
    assert(registry.record(s.old) and #registry.get().order==s.native_count)
    assert(registry.get().next_id==s.next_id and not registry.by_entity(s.pending))
    s.phase='adopting'
  end
  if s.phase=='initial' or s.phase=='adopting' then scheduler.tick(event.tick) end
  if s.phase=='adopting' and registry.by_entity(s.pending) then
    assert(registry.get().next_id==s.next_id+1 and s.pending.valid)
    assert(peripheral.inventory(registry.record(s.computer),'green',nop)[registry.by_entity(s.pending).id])
    log('TC_COLD_OK'); s.phase='finished'
  end
end
function M.on_configuration_changed()
  if script.active_mods['space-age'] then
    assert(game.forces.player.technologies['tc-interplanetary-radar'].researched)
    assert(game.forces.player.recipes['tc-interplanetary-radar'].enabled)
    local other=game.forces['radar-unresearched']
    assert(not other.technologies['tc-interplanetary-radar'].researched and not other.recipes['tc-interplanetary-radar'].enabled)
    log('TC_RADAR_RESEARCH_RECONCILED')
  end
  log('TC_UPGRADE_OK')
end
return M
