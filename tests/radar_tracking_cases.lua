-- Real native graph/lifecycle cases, composed into the production-context radar fixture.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local graph=require('scripts.network')
local peripheral=require('scripts.services.peripheral')
local radar=require('scripts.radar')
local shell=require('scripts.runtime.shell')
local limits=require('scripts.runtime.limits')
local defs=require('scripts.device-definitions')
local M={}
local function nop() end
local function conn(b,color) return assert(b.get_wire_connector(defines.wire_connector_id['circuit_'..color],true)) end
local function wire(a,b,color) assert(conn(a,color).connect_to(conn(b,color),false)) end
local function cut(a,b,color) assert(conn(a,color).disconnect_from(conn(b,color))) end
local function error_is(code,fn)
  local ok,e=pcall(fn); assert(not ok and type(e)=='table' and e.code==code,serpent.line(e))
end
local function console(c,source)
  c.shell=c.shell or {version=1,id=c.id..'/radar-tracking',pending={},pending_bytes=0}
  local ok,e=shell.evaluate(c,source,game.tick,'radar-tracking'); assert(ok,serpent.line(e))
end
function M.run(report)
  local s=game.create_surface('radar-tracking',{width=256,height=256})
  local function body(name,x,y,force)
    return assert(s.create_entity{name=name,position={x,y},force=force or 'player'})
  end
  local function device(kind,x,y)
    return assert(lifecycle.build(body(defs.devices[kind].entity_name,x,y)))
  end
  local c=device('computer',0,0); local db=device('kv',6,0)
  local sp=body('programmable-speaker',12,0); local a=body('radar',18,0); local b=body('radar',24,0)
  wire(c.body,db.body,'red'); wire(db.body,sp,'red'); wire(sp,a,'red'); wire(a,b,'red')
  local bad={}
  local mixed=body('radar',6,6); wire(db.body,mixed,'green'); bad[#bad+1]=mixed
  local alone=device('kv',40,0); local x=body('radar',46,0); local y=body('radar',52,0)
  wire(alone.body,x,'red'); wire(x,y,'red'); wire(y,alone.body,'red'); bad[#bad+1]=x; bad[#bad+1]=y
  local pole=body('small-electric-pole',0,8); local behind=body('radar',0,14)
  wire(c.body,pole,'green'); wire(pole,behind,'green'); bad[#bad+1]=behind
  local io=device('logic',12,8); wire(c.body,io.body,'green')
  for i,role in ipairs({'input','output'}) do
    local r=body('radar',18+i*6,8); wire(lifecycle.endpoint(io,role),r,'green'); bad[#bad+1]=r
  end
  local cfg=device('configurator',12,16); local targeted=body('radar',18,16)
  wire(c.body,cfg.body,'green'); wire(lifecycle.endpoint(cfg,'targets'),targeted,'green'); bad[#bad+1]=targeted
  local m1=device('monitor',0,-6); local m2=device('monitor',1,-6); local adjacent=body('radar',6,-6)
  wire(c.body,m1.body,'green'); wire(m2.body,adjacent,'green'); bad[#bad+1]=adjacent
  local ghost=assert(s.create_entity{name='entity-ghost',inner_name='radar',position={0,20},force='player'})
  local ghosted=body('radar',6,20); wire(c.body,ghost,'green'); wire(ghost,ghosted,'green'); bad[#bad+1]=ghosted
  local foreign=game.create_force('radar-tracking-foreign'); local other=body('radar',-6,6,foreign)
  wire(c.body,other,'red'); bad[#bad+1]=other
  for _,r in ipairs(bad) do lifecycle.on_built{entity=r}; assert(not registry.by_entity(r)) end
  local before=registry.get().next_id
  local nodes=limits.network_nodes; limits.network_nodes=2
  error_is('E_LIMIT',function() graph.adopt(c,'red',nop) end); limits.network_nodes=nodes
  assert(registry.get().next_id==before and not registry.by_entity(sp) and not registry.by_entity(b))
  local cap=limits.registry_entries; limits.registry_entries=registry.get().retained_count+2
  error_is('E_CAPACITY',function() graph.adopt(c,'red',nop) end); limits.registry_entries=cap
  local refused={}
  local ok,e=pcall(graph.adopt,c,'red',function(n) if n==3*32 then error(refused,0) end end)
  assert(not ok and e==refused and registry.get().next_id==before and not registry.by_entity(a))
  for _,status in ipairs({'stopped','faulted'}) do
    c.status=status; c.powered=false
    graph.adopt(c,'red',nop); graph.adopt(c,'green',nop)
  end
  c.status='stopped'
  local ar,br=assert(registry.by_entity(a)),assert(registry.by_entity(b))
  assert(registry.by_entity(sp) and peripheral.inventory(c,'red',nop)[br.id])
  for _,r in ipairs(bad) do assert(not registry.by_entity(r),'non-computer path enrolled a radar') end
  report('rooted-native-chain-stopped-faulted-unpowered-and-atomic-admission')
  report('no-mixed-color-standalone-cycle-pole-factory-ghost-force-or-monitor-bridge')
  br.modem={version=1,channels={[71]=true},count=1}
  c.powered=true; b.energy=1000000; br.powered=false
  console(c,"held=peripheral.wrap('"..br.id.."','red'); assert(held.isOpen(71)); assert(peripheral.describe('"..br.id.."','red').powered)")
  b.energy=0; br.powered=true
  console(c,"assert(not peripheral.describe('"..br.id.."','red').powered); assert(held.getLimits().open_channels==128); local ok,e=pcall(held.isOpen,71); assert(not ok and e.code=='E_UNPOWERED')")
  b.energy=1000000
  wire(c.body,b,'green'); cut(c.body,db.body,'red')
  console(c,"local ok,e=pcall(held.getLimits); assert(not ok and e.code=='E_UNREACHABLE'); assert(peripheral.wrap('"..br.id.."','green').isOpen(71))")
  cut(c.body,b,'green'); wire(c.body,db.body,'red')
  console(c,'assert(held.isOpen(71))')
  local generation=br.generation; local saved=br.modem
  b.force=foreign
  assert(not peripheral.inventory(c,'red',nop)[br.id])
  local fc=assert(lifecycle.build(body(defs.devices.computer.entity_name,30,6,foreign)))
  wire(fc.body,b,'red')
  error_is('E_NETWORK_PENDING',function() peripheral.inventory(fc,'red',nop) end)
  assert(br.modem==saved and br.generation==generation)
  graph.adopt(fc,'red',nop); assert(br.generation==generation+1 and br.modem.count==0)
  b.force=game.forces.player; graph.adopt(c,'red',nop)
  assert(br.generation==generation+2 and br.modem.count==0)
  console(c,'local ok,e=pcall(held.getLimits); assert(not ok and e.code=="E_UNREACHABLE")')
  -- Native radars cannot teleport surfaces; inject only the retained-scope mismatch.
  br.surface_index=game.surfaces[1].index; br.modem={version=1,channels={[71]=true},count=1}
  error_is('E_NETWORK_PENDING',function() peripheral.inventory(c,'red',nop) end)
  graph.adopt(c,'red',nop); assert(br.surface_index==s.index and br.modem.count==0)
  lifecycle.remove(fc.id,'fixture',true)
  report('console-live-power-limits-reconnect-and-adopter-only-scope-revocation')
  br.modem={version=1,channels={[71]=true},count=1}
  local peer=device('computer',30,0); wire(peer.body,b,'red')
  lifecycle.remove(c.id,'fixture',true)
  assert(peripheral.inventory(peer,'red',nop)[br.id] and br.modem.channels[71])
  lifecycle.remove(peer.id,'fixture',true)
  local original=registry.record
  registry.record=function(id) assert(id~=ar.id and id~=br.id,'disconnected component seeded adoption'); return original(id) end
  for _=1,8 do graph.adopt_tick(game.tick,nop) end
  registry.record=original
  assert(registry.record(br.id)==br and br.modem.channels[71])
  report('surviving-computer-path-and-last-root-removal-do-not-poll-dormant-component')
  local doomed=assert(radar.build(body('radar',64,0)))
  local registration=doomed.destruction_registration
  lifecycle.on_object_destroyed{registration_number=registration}
  assert(registry.record(doomed.id)==doomed,'live body must not be retired by a stale event')
  doomed.body.destroy() -- No raised removal: the real engine must dispatch cleanup.
  local replacement=body('radar',64,0); lifecycle.on_built{entity=replacement}
  assert(not registry.by_entity(replacement))
  local unrelated=body('constant-combinator',64,6)
  local unrelated_registration=script.register_on_object_destroyed(unrelated); unrelated.destroy()
  local removed_surface=game.create_surface('radar-tracking-deletion',{width=32,height=32})
  local removed=assert(radar.build(assert(removed_surface.create_entity{name='radar',position={0,0},force='player'})))
  assert(game.delete_surface(removed_surface))
  local cold=device('computer',0,32); local cold_body=body('radar',6,32)
  wire(cold.body,cold_body,'red'); wire(cold.body,cold_body,'green'); graph.adopt(cold,'red',nop)
  local cold_rec=assert(registry.by_entity(cold_body)); cold_rec.modem={version=1,channels={[99]=true},count=1}
  return {doomed=doomed.id,registration=registration,replacement=replacement,unrelated=unrelated_registration,
    removed=removed.id,computer=cold.id,radar=cold_rec.id,generation=cold_rec.generation}
end
function M.check_cleanup(x)
  assert(not registry.record(x.doomed) and not registry.record(x.removed),'targeted native cleanup did not retire dormant identity')
  lifecycle.on_object_destroyed{registration_number=x.registration}
  lifecycle.on_object_destroyed{registration_number=x.unrelated}
  assert(x.replacement.valid and not registry.by_entity(x.replacement))
end
function M.detach(x)
  local c,r=registry.record(x.computer),registry.record(x.radar)
  c.powered=true; r.body.energy=1000000
  console(c,"held=peripheral.wrap('"..r.id.."','red'); assert(held.isOpen(99))")
  peripheral.reconcile_one(c,'red',game.tick,nop)
  cut(c.body,r.body,'red'); cut(c.body,r.body,'green')
  x.channels=r.modem
end
function M.check_dormant(x)
  local r=registry.record(x.radar)
  assert(r.modem==x.channels and r.modem.channels[99] and r.generation==x.generation)
  for _,id in ipairs(registry.get().order) do assert(id~=r.id) end
end
function M.reconnect(x)
  M.check_dormant(x)
  local c,r=registry.record(x.computer),registry.record(x.radar)
  c.powered=true; r.body.energy=1000000
  console(c,'local ok,e=pcall(held.getLimits); assert(not ok and e.code=="E_UNREACHABLE")')
  wire(c.body,r.body,'red'); wire(c.body,r.body,'green'); graph.adopt(c,'red',nop)
  console(c,'assert(held.isOpen(99))')
  assert(registry.by_entity(r.body)==r and r.modem==x.channels)
end
return M
