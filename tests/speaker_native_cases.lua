-- Native-carrier regression cases shared by the packaged speaker cold fixture.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local radar=require('scripts.radar')
local carrier=require('scripts.speaker')
local peripheral=require('scripts.services.peripheral')
local defs=require('scripts.device-definitions')
local shell=require('scripts.runtime.shell')
local runtime=require('scripts.runtime.computer')
local graph=require('scripts.network')
local M={}
local function nop() end
local function conn(body,color) return assert(body.get_wire_connector(defines.wire_connector_id['circuit_'..color],true)) end
local function wire(a,b,color) if not conn(a,color).is_connected_to(conn(b,color)) then assert(conn(a,color).connect_to(conn(b,color),false)) end end
local function build(kind,x,y)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})
  lifecycle.on_built{entity=body}; local rec=assert(registry.by_entity(body)); assert(not rec.children.power); return rec
end
local function native(x,y) return assert(game.surfaces[1].create_entity{name='programmable-speaker',position={x,y},force='player'}) end
local function adopt(c)
  for _,wire in ipairs({'red','green'}) do
    local ok,e=pcall(peripheral.inventory,c,wire,nop)
    assert(ok or type(e)=='table' and e.code=='E_NETWORK_PENDING',serpent.line(e))
  end
  for _=1,#registry.get().order*2+4 do graph.adopt_tick(game.tick,nop) end
end
local function error_is(code,fn) local ok,e=pcall(fn); assert(not ok and type(e)=='table' and e.code==code,serpent.line(e)) end
function M.run(c,r,conf,guest,report)
  local b=r.body; local s=b.surface
  local spent=registry.get().speaker_audio; assert(spent.total==2)
  c.shell={version=1,id=c.id..'/speaker-quota-fixture',pending={},pending_bytes=0}
  local expression="assert(not peripheral.wrap('"..r.id.."','green').playSound('utility/wire_connect_pole',0))"
  local ok,e=shell.evaluate(c,expression,game.tick,'shared-program-console'); assert(ok,serpent.line(e))
  assert(conn(c.body,'red').disconnect_from(conn(b,'red')))
  local detached="local ok,e=pcall(peripheral.call,'"..r.id.."','red','playSound','utility/wire_connect_pole',0); assert(not ok and e.code=='E_UNREACHABLE')"
  ok,e=shell.evaluate(c,detached,game.tick,'detached-console'); assert(ok,serpent.line(e))
  wire(c.body,b,'red')
  ok,e=shell.evaluate(c,expression,game.tick,'rewired-console'); assert(ok,serpent.line(e))
  assert(runtime.save(c.id,'function start(event) end',c.saved_revision)); assert(runtime.activate(c.id,game.tick))
  c.shell={version=1,id=c.id..'/speaker-quota-after-apply',pending={},pending_bytes=0}
  ok,e=shell.evaluate(c,expression,game.tick,'applied-console'); assert(ok,serpent.line(e))
  runtime.stop(c.id); c.shell=nil
  assert(registry.get().speaker_audio==spent and spent.total==2)
  report('compiled-console-program-apply-reconnect-and-recreated-wrapper-share-spent-credits')
  local unsupported=assert(s.create_entity{name='tc-fixture-unsupported-speaker',position={0,-6},force='player'})
  lifecycle.on_built{entity=unsupported}; wire(c.body,unsupported,'green'); adopt(c)
  assert(not carrier.supports(unsupported) and not registry.by_entity(unsupported) and unsupported.valid); unsupported.destroy()
  local middle=native(9,3); local db=build('kv',12,6); local green=build('kv',12,9)
  wire(b,middle,'red'); wire(middle,db.body,'red'); wire(middle,green.body,'green')
  error_is('E_NETWORK_PENDING',function() peripheral.inventory(c,'red',nop) end); adopt(c)
  local m=assert(registry.by_entity(middle)); middle.energy=0
  assert(peripheral.inventory(c,'red',nop)[m.id] and peripheral.inventory(c,'red',nop)[db.id])
  assert(not peripheral.inventory(c,'red',nop)[green.id] and not peripheral.inventory(c,'green',nop)[green.id])
  local pole=assert(s.create_entity{name='small-electric-pole',position={15,9},force='player'})
  local hidden=build('kv',18,9); wire(middle,pole,'red'); wire(pole,hidden.body,'red')
  assert(not peripheral.inventory(c,'red',nop)[hidden.id] and conn(middle,'red').is_connected_to(conn(pole,'red')))
  local target_only=native(0,12); wire(lifecycle.endpoint(conf,'targets'),target_only,'green'); adopt(c)
  assert(not registry.by_entity(target_only),'Targets-only native speaker must not be adopted as discovery frontier')
  report('native-speaker-chain-color-separation-unpowered-relay-unsupported-pole-and-target-role')
  wire(c.body,conf.body,'red')
  guest(c,[[local cfg=peripheral.find('configurator','red'); assert(cfg)
    local target
    for _,d in ipairs(cfg.getDevices('red')) do if d.prototype=='programmable-speaker' and d.position.x<8 then target=d.id; assert(d.configurable) end end
    assert(target)
    local old=cfg.getConfiguration(target,'red').values.circuit_parameters
    local change={instrument_id=old.instrument_id,note_id=old.note_id==0 and 1 or 0,signal_value_is_pitch=old.signal_value_is_pitch,stop_playing_sounds=old.stop_playing_sounds}
    local result=cfg.setConfiguration(target,{set={circuit_parameters=change}},'red')
    assert(result.values.circuit_parameters.note_id==change.note_id)
    result=cfg.setConfiguration(target,{set={circuit_parameters=old}},'red')
    assert(result.values.circuit_parameters.note_id==old.note_id)
  ]])
  report('compiled-configurator-read-write-and-restore-registered-native-speaker')
  local cloned=assert(b.clone{position={6,12},surface=s,force=b.force})
  lifecycle.on_cloned{source=b,destination=cloned}; assert(not registry.by_entity(cloned))
  wire(c.body,cloned,'green'); adopt(c); local clone=assert(registry.by_entity(cloned)); assert(clone.id~=r.id and next(clone.children)==nil)
  cloned.energy=100000
  c.shell={version=1,id=c.id..'/speaker-native-fixture',pending={},pending_bytes=0}
  local ok,e=shell.evaluate(c,"held=peripheral.wrap('"..clone.id.."','green')",game.tick,'hold'); assert(ok,serpent.line(e))
  local generation=clone.generation; local force=game.create_force('speaker-scope-fixture')
  cloned.force=force; assert(not peripheral.inventory(c,'green',nop)[clone.id]); carrier.reconcile(clone,nop)
  cloned.force=game.forces.player; carrier.reconcile(clone,nop); wire(c.body,cloned,'green')
  assert(clone.generation==generation+2)
  ok,e=shell.evaluate(c,'held.getLimits()',game.tick,'stale-generation'); assert(not ok and e.code=='E_UNREACHABLE',serpent.line(e))
  local old=clone.id
  lifecycle.on_removed{entity=cloned}
  local inventory=game.create_inventory(4); assert(cloned.mine{inventory=inventory,raise_destroyed=true})
  assert(inventory.get_item_count('programmable-speaker')==1 and not registry.record(old)); inventory.destroy()
  local replacement=native(6,12); wire(c.body,replacement,'green'); adopt(c)
  local next_rec=assert(registry.by_entity(replacement)); assert(next_rec.id~=old)
  ok,e=shell.evaluate(c,'held.getLimits()',game.tick,'stale-replacement'); assert(not ok and e.code=='E_UNREACHABLE',serpent.line(e)); c.shell=nil
  local at=replacement.position; local moved=replacement.teleport({at.x+1,at.y})
  if moved then
    carrier.reconcile(next_rec,nop)
    assert(lifecycle.connector(next_rec,'network','green')==conn(replacement,'green'))
    guest(c,"local i=peripheral.describe('"..next_rec.id.."','green'); assert(i and i.position.x=="..replacement.position.x..")")
  else log('TC_SPEAKER_NATIVE_TELEPORT_UNAVAILABLE no fabricated movement') end
  local other=game.create_surface('speaker-clone-scope',{width=32,height=32})
  local cross=assert(b.clone{position={0,0},surface=other,force=b.force}); lifecycle.on_cloned{source=b,destination=cross}
  local cross_rec=assert(carrier.build(cross)); assert(cross_rec.id~=r.id and cross_rec.surface_index==other.index)
  lifecycle.remove(cross_rec.id,'fixture',false); game.delete_surface(other)
  local removed_id=next_rec.id; replacement.destroy()
  assert(not peripheral.inventory(c,'green',nop)[removed_id]); carrier.reconcile(next_rec,nop); assert(not registry.record(removed_id))
  local ghost=assert(s.create_entity{name='entity-ghost',inner_name='programmable-speaker',position={6,12},force='player'})
  wire(c.body,ghost,'green'); wire(ghost,green.body,'green'); assert(not registry.by_entity(ghost))
  assert(not peripheral.inventory(c,'green',nop)[green.id],'ghost wires must not grant relay authority')
  local _,revived=ghost.revive{raise_revive=true}; assert(revived); lifecycle.on_built{entity=revived}; adopt(c)
  assert(registry.by_entity(revived) and registry.by_entity(revived).id~=removed_id)
  assert(peripheral.inventory(c,'green',nop)[green.id],'revived native relay must use real wires')
  report('native-clone-revive-mining-replacement-movement-scope-generation-and-stale-console')
  local cold_speaker
  if script.active_mods['space-age'] then
    local cold=game.planets.aquilo.create_surface()
    cold.request_to_generate_chunks({0,0},0); cold.force_generate_chunk_requests()
    cold.set_tiles{{name='concrete',position={0,0}}}
    local body=assert(cold.create_entity{name='programmable-speaker',position={0,0},force=b.force})
    cold_speaker=assert(carrier.build(body)).id
  end
  local local_body=assert(s.create_entity{name='radar',position={16,3},force='player'}); lifecycle.on_built{entity=local_body}
  local remote_body=assert(s.create_entity{name='radar',position={100,3},force='player'}); lifecycle.on_built{entity=remote_body}
  local remote_db=build('kv',106,3); wire(middle,local_body,'red'); wire(remote_body,remote_db.body,'red')
  adopt(c); assert(not registry.by_entity(remote_body))
  local remote=assert(radar.build(remote_body)) -- Retained legacy identity is still no physical bridge.
  for _,x in ipairs({16,100}) do
    local power=assert(s.create_entity{name='electric-energy-interface',position={x,-6},force='player'})
    power.power_production=1000000000; power.power_usage=0; power.electric_buffer_size=1000000000; power.energy=1000000000
    assert(s.create_entity{name='substation',position={x,-3},force='player'})
  end
  return {middle=m.id,local_radar=registry.by_entity(local_body).id,remote_radar=remote.id,remote_db=remote_db.id,cold_speaker=cold_speaker}
end
function M.hidden(c,r,x)
  local local_rec=registry.record(x.local_radar); local remote=registry.record(x.remote_radar)
  local hidden=false
  for _,edge in ipairs(conn(local_rec.body,'red').real_connections) do if edge.origin==defines.wire_origin.radars and edge.target.owner==remote.body then hidden=true end end
  assert(hidden,'powered native radar-origin link must actually exist')
  local inv=peripheral.inventory(c,'red',nop)
  assert(inv[local_rec.id] and inv[x.middle] and not inv[remote.id] and not inv[x.remote_db])
  assert(not graph.validate_witness(c,'red',{c.id,r.id,x.middle,local_rec.id,remote.id,x.remote_db},nop))
  if x.cold_speaker then
    if x.cold_removal_requested then
      if registry.record(x.cold_speaker) then
        assert(game.tick<x.cold_removal_requested+5,'queued surface removal must retire native record'); return false
      end
      assert(not x.cold_body.valid); x.cold_body=nil
    else
      local rec=assert(registry.record(x.cold_speaker)); local body=rec.body
      -- Pinned 2.0.77 has no native speaker asFreezable override.
      assert(body.prototype.heating_energy>0 and not body.is_freezable and not body.frozen)
      assert(carrier.available(rec)); x.cold_body=body
      assert(game.delete_surface(body.surface)); x.cold_removal_requested=game.tick
      return false -- Surface deletion and its lifecycle events are queued.
    end
    log('TC_SPEAKER_NATIVE_NONFREEZABLE_AND_SURFACE_REMOVAL_OK')
  end
  log('TC_SPEAKER_RADAR_HIDDEN_ISOLATION_OK')
  return true
end
return M
