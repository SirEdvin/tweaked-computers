-- Compact real-connector contracts plus two cold actual-tick phases. Fixture
-- bindings exercise the service boundary, not unfinished KV/logic functionality.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local defs=require('scripts.device-definitions')
local lifecycle=require('scripts.lifecycle')
local graph=require('scripts.network')
local peripheral=require('scripts.services.peripheral')
local inspection_source=require('examples.peripheral-program')
local M={}; local loaded=false
local function nop() end
local function f() return storage.tc05_fixture end
local function report(name) f().groups=f().groups+1; log('TC_CONTRACT '..name) end
local function connector(rec,wire,role) return assert(lifecycle.connector(rec,role or 'network',wire)) end
local function connect(a,b,wire,ar,br)
  assert(connector(a,wire,ar).connect_to(connector(b,wire,br)))
end
local function disconnect(a,b,wire)
  assert(connector(a,wire).disconnect_from(connector(b,wire)))
end
local function build(surface,kind,x,y,force)
  local body=assert(surface.create_entity{name=defs.devices[kind].entity_name,position={x,y},force=force or 'player'})
  lifecycle.on_built{entity=body}
  local rec=assert(registry.by_entity(body)); assert(not rec.children.power and lifecycle.available(rec))
  rec.powered=true; return rec
end
local function inventory(c,wire) return peripheral.inventory(c,wire,nop) end
local function error_is(code,fn)
  local ok,e=pcall(fn); assert(not ok and type(e)=='table' and e.code==code,'expected '..code..', got '..(type(e)=='table' and tostring(e.code) or tostring(e)))
end
local function guest(c,body)
  local source='function start(e) '..body..' end'
  local ctx=admission.context(admission.new(),c.id,0)
  local plan,err=compiler.compile(source,ctx); assert(plan,err and err.message)
  local ok,e=compiler.run(plan,'start',{name='start'},function(g) return runtime.services(c,game.tick,g) end,ctx)
  assert(ok,e and (e.code..': '..e.message))
end
peripheral.register_type('kv',{methods={
  getLimits=function() return {fixture_entries=1} end,
  testSet=function(c,rec,wire,tick,spend,...)
    assert(select('#',...)==1); local value=...; spend(16); rec.fixture_value=value
  end,
  testGet=function(c,rec,wire,tick,spend,...) assert(select('#',...)==0); spend(16); return rec.fixture_value end,
  testDisconnect=function(c,rec,wire,tick,spend,...)
    assert(select('#',...)==0); spend(16); disconnect(c,rec,wire)
  end,
  testObject=function(c,rec) return rec.body end
}})
-- This synthetic group resolver tests only the physical/no-hidden-bridge policy.
-- Actual rectangle/group lifecycle belongs to the pre-created monitor card.
peripheral.register_type('monitor',{methods={getLimits=function() return {fixture_members=2} end,
  testSplit=function(c,rec,wire,tick,spend,...) assert(select('#',...)==0); spend(16); registry.record(f().group_member).fixture_anchor=nil end},resolve=function(member)
  if member.fixture_anchor then return registry.record(member.fixture_anchor) end
  return member
end})
peripheral.register_revocation('fixture-observer',function(c,name,wire,reason)
  if f() then f().revocations[#f().revocations+1]={computer=c.id,name=name,wire=wire,reason=reason} end
end)
local function output(rec,c,wire)
  local cb=rec.children.output.get_or_create_control_behavior(); local s=cb.add_section()
  s.set_slot(1,{value={type='virtual',name='signal-A',quality='normal'},min=7}); cb.enabled=true
  rec.output_bank={{signal={type='virtual',name='signal-A',quality='normal'},count=7}}
  local target,path=peripheral.authority(c,rec.id,wire,nop); assert(target==rec)
  rec.output_owner={computer_id=c.id,run_id=c.run_id,wire=wire,path=path}
  registry.output_changed(rec) -- Host-only bank fixture uses the production publication index.
end
local cold_source=[[function start(e)
  computer.setState('boots',(computer.getState('boots') or 0)+1)
  computer.on('peripheral_attach','changed'); computer.on('peripheral_detach','changed')
  local db=peripheral.find('kv_database','red'); assert(db)
  computer.setState('db',peripheral.getName(db)); computer.setState('wire',peripheral.getWire(db))
  local info=peripheral.describe(peripheral.getName(db),'red'); computer.setState('position',info.position)
end

function changed(e)
  local events=computer.getState('events') or {}
  events[#events+1]={name=e.name,peripheral=e.peripheral,wire=e.wire,reason=e.reason or ''}
  computer.setState('events',events)
end

function check(e)
  local name=computer.getState('db'); assert(not peripheral.isPresent(name,'red'))
  assert(peripheral.wrap(name,'red')==nil)
  computer.setState('checked',true)
end]]
function M.run()
  registry.initialize(); storage.tc05_fixture={groups=0,revocations={},phase='armed'}
  local surface=game.surfaces[1]
  local c=build(surface,'computer',0,0); local db=build(surface,'kv',3,0)
  local mon=build(surface,'monitor',6,0); local io=build(surface,'logic',3,3)
  c.status='running'; c.run_id=c.id..'/fixture'
  connect(c,db,'red'); connect(db,mon,'red'); connect(db,io,'red')
  local inv=inventory(c,'red'); assert(inv[db.id] and inv[mon.id] and inv[io.id] and not inv[c.id])
  local _,path=peripheral.authority(c,io.id,'red',nop); assert(#path==3 and graph.validate_witness(c,'red',path,nop))
  report('real-same-colour-transitive-network-and-live-witness')
  disconnect(db,mon,'red'); connect(db,mon,'green')
  assert(not inventory(c,'red')[mon.id] and next((inventory(c,'green')))==nil)
  connect(c,db,'green'); assert(inventory(c,'green')[db.id] and inventory(c,'green')[mon.id])
  -- Duplicate paths still produce one identity per channel.
  report('mixed-colour-rejection-and-independent-both-colour-identities')
  -- Real vanilla continuity does not authorize discovery, and unsupported wires stay.
  local pole=assert(surface.create_entity{name='small-electric-pole',position={6,3},force='player'})
  local red=defines.wire_connector_id.circuit_red
  assert(connector(db,'red').connect_to(pole.get_wire_connector(red,true)))
  assert(pole.get_wire_connector(red,true).connect_to(connector(mon,'red')))
  assert(not inventory(c,'red')[mon.id] and connector(db,'red').real_connection_count>1)
  local role_only=build(surface,'configurator',6,6)
  connect(io,role_only,'red','input','network')
  assert(not inventory(c,'red')[role_only.id])
  local ghost=assert(surface.create_entity{name='entity-ghost',inner_name='constant-combinator',position={6,0},force='player'})
  local ghost_connector=ghost.get_wire_connector(red,true)
  assert(connector(db,'red').connect_to(ghost_connector))
  assert(not graph.discovery_vertex(ghost_connector,c,'red'))
  local foreign=build(surface,'kv',0,3,game.create_force('tc05-foreign'))
  assert(connector(c,'red').connect_to(connector(foreign,'red'),false))
  assert(not inventory(c,'red')[foreign.id])
  local other_surface=game.create_surface('tc05-other',{width=32,height=32})
  local remote=build(other_surface,'kv',0,0)
  assert(connector(c,'red').connect_to(connector(remote,'red'),false))
  assert(not inventory(c,'red')[remote.id])
  report('vanilla-ghost-foreign-surface-and-role-exclusion-with-wires-retained')
  db.powered=false
  guest(c,[[local n=peripheral.getNames('red'); assert(#n==2)
    local db=peripheral.find('kv_database','red'); assert(db)
    assert(peripheral.getType(peripheral.getName(db),'red')=='kv_database')
    local info=peripheral.describe(peripheral.getName(db),'red'); assert(info.powered)
    info.position.x=999; assert(peripheral.describe(peripheral.getName(db),'red').position.x~=999)
    assert(db.getLimits().fixture_entries==1)
    local ok,e=pcall(db.testGet); assert(ok and e==nil)
    assert(select('#',peripheral.find('unknown','green'))==0)
    local methods=peripheral.getMethods(peripheral.getName(db),'red'); assert(#methods==5)
    methods[1]='bad'; assert(peripheral.getMethods(peripheral.getName(db),'red')[1]~='bad')
    ok,e=pcall(peripheral.getNames,'both'); assert(not ok and e.code=='E_ARGUMENT')
    ok,e=pcall(peripheral.getNames); assert(not ok and e.code=='E_ARGUMENT')
    ok,e=pcall(peripheral.call,peripheral.getName(db),'red','unknown'); assert(not ok and e.code=='E_ARGUMENT')
    ok,e=pcall(db.getLimits,db); assert(not ok and e.code=='E_ARGUMENT')]])
  db.powered=true
  report('compiled-discovery-metadata-copy-arity-power-free-static-limits-and-zero-tuple')
  local direct_source='function start(e) return peripheral.call('..string.format('%q',db.id)..',"red","testGet") end'
  local direct_work={}
  for i,classify in ipairs({false,true}) do
    local ctx=admission.context(admission.new(),c.id,game.tick)
    local plan=assert(compiler.compile(direct_source,ctx)); local before=ctx.machine.work
    local ok,e=compiler.run(plan,'start',{},function(g)
      if not classify then g.circuit_call=nil end -- Reference non-circuit dispatch, with the same authority checks.
      return runtime.services(c,game.tick,g)
    end,ctx)
    assert(ok,e and e.message); direct_work[i]=ctx.machine.work-before
  end
  assert(direct_work[1]==direct_work[2],'native classification charged a duplicate authority lookup')
  report('direct-non-circuit-call-keeps-single-authority-charge')
  guest(c,[[local db=peripheral.find('kv_database','red'); local n=peripheral.getName(db)
    db.testSet({value=false}); local v=db.testGet(); assert(v.value==false); v.value=true
    assert(peripheral.call(n,'red','testGet').value==false)
    local ok,e=pcall(db.testObject); assert(not ok and e.code=='E_ARGUMENT')
    ok,e=pcall(computer.setState,'handle',db); assert(not ok and e.code=='E_ARGUMENT')
    ok,e=pcall(peripheral.getName,{}); assert(not ok and e.code=='E_ARGUMENT')
    ok,e=pcall(peripheral.getName,computer); assert(not ok and e.code=='E_ARGUMENT')
    ok,e=pcall(function() db.testSet=1 end); assert(not ok)
    local captured=db.testGet; db.testDisconnect()
    assert(peripheral.getName(db)==n and peripheral.getWire(db)=='red')
    ok,e=pcall(captured); assert(not ok and e.code=='E_UNREACHABLE')
    assert(peripheral.describe(n,'red')==nil and peripheral.wrap(n,'red')==nil)]])
  connect(c,db,'red')
  report('compiled-stale-captured-call-and-unforgeable-nondata-facades')
  local c2=build(surface,'computer',0,-3); c2.status='running'; c2.run_id=c2.id..'/fixture'
  connect(c2,db,'red'); guest(c2,[[local db=peripheral.find('kv_database','red'); db.testSet('second')]])
  guest(c,[[local db=peripheral.find('kv_database','red'); assert(db.testGet()=='second')]])
  local old_id=db.id; local old_position=db.body.position
  disconnect(c,db,'red'); assert(lifecycle.remove(db.id,'fixture-replace',true))
  db=build(surface,'kv',old_position.x,old_position.y); connect(c,db,'red'); connect(db,io,'red')
  assert(db.id~=old_id and not inventory(c,'red')[old_id] and inventory(c,'red')[db.id])
  report('shared-serialized-binding-writes-and-replacement-identity')
  -- No logical framebuffer edge: two physical disconnected monitor members can
  -- resolve to one name without reaching each other's attached database.
  local a=build(surface,'monitor',10,0); local b=build(surface,'monitor',13,0)
  b.fixture_anchor=a.id; local hidden=build(surface,'kv',16,0)
  local left=build(surface,'computer',10,-3); local right=build(surface,'computer',13,-3)
  connect(left,a,'red'); connect(right,b,'red'); connect(b,hidden,'red')
  assert(inventory(left,'red')[a.id] and not inventory(left,'red')[hidden.id])
  assert(inventory(right,'red')[a.id] and inventory(right,'red')[hidden.id] and not inventory(right,'red')[b.id])
  right.status='running'; right.run_id=right.id..'/fixture'; f().group_member=b.id
  guest(right,[[local m=peripheral.find('monitor','red'); local n=peripheral.getName(m)
    m.testSplit(); assert(peripheral.getName(m)==n and peripheral.getWire(m)=='red')
    local ok,e=pcall(m.getLimits); assert(not ok and e.code=='E_UNREACHABLE')
    assert(peripheral.getType(n,'red')==nil and peripheral.find('monitor','red')~=nil)]])
  report('synthetic-monitor-group-real-wire-no-implicit-member-bridge')
  -- Exact unchanged production node cap, real wire chain; no truncated success.
  local bounded=game.create_surface('tc05-bounded',{width=2048,height=32}); local chain={}
  for i=1,limits.network_nodes+1 do
    chain[i]=build(bounded,i>1 and i<=limits.tuple_entries+2 and 'kv' or 'computer',i*3,0)
    if i>1 then connect(chain[i-1],chain[i],'red') end
  end
  error_is('E_LIMIT',function() inventory(chain[1],'red') end)
  disconnect(chain[#chain-1],chain[#chain],'red')
  local complete=inventory(chain[1],'red'); local n=0; for _ in pairs(complete) do n=n+1 end
  assert(n==limits.tuple_entries+1)
  chain[1].status='running'; chain[1].run_id=chain[1].id..'/fixture'
  guest(chain[1],[[local ok,e=pcall(peripheral.find,'kv_database','red'); assert(not ok and e.code=='E_LIMIT')
    assert(#peripheral.getNames('red')==129)]])
  error_is('E_LIMIT',function() graph.real_edges(connector(c,'red'),nop,0) end)
  error_is('E_NETWORK_PENDING',function() peripheral.inventory(c,'red',function() error({code='E_NETWORK_PENDING',message='fixture work refusal'},0) end) end)
  for _,rec in ipairs(chain) do assert(lifecycle.remove(rec.id,'fixture-cleanup',true)) end
  report('real-maximum-node-complete-result-and-over-limit-refusal')
  -- Reconciliation baseline is silent; later transition detaches first, sorted.
  c.active={source='',api_version=1,compiler_version=limits.compiler_version,storage_version=1,handlers={changed=true}}
  runtime.subscribe(c,'peripheral_attach','changed'); runtime.subscribe(c,'peripheral_detach','changed')
  peripheral.reconcile_one(c,'red',game.tick,nop); assert(#c.queue==0)
  output(io,c,'red')
  local owner=io.output_owner; local view=c.network_views.red.inventory
  local native=assert(surface.create_entity{name='radar',position={9,6},force='player'})
  assert(connector(db,'red').connect_to(native.get_wire_connector(red,true)))
  for _=1,3 do
    peripheral.reconcile_one(c,'red',game.tick,nop)
    assert(c.network_views.red.diagnostic.code=='E_NETWORK_PENDING')
    assert(io.output_owner==owner and c.network_views.red.inventory==view and #c.queue==0,
      'pending unrelated adoption revoked a live output or published false transitions')
    assert(graph.validate_witness(c,'red',owner.path,nop))
    error_is('E_NETWORK_PENDING',function() inventory(c,'red') end)
    peripheral.check_outputs(game.tick,nop); assert(io.output_owner==owner)
  end
  graph.adopt_tick(game.tick,nop); local adopted=assert(registry.by_entity(native))
  peripheral.reconcile_one(c,'red',game.tick,nop)
  assert(io.output_owner==owner and #c.queue==1 and c.queue[1].event.name=='peripheral_attach'
    and c.queue[1].event.peripheral==adopted.id and not c.network_views.red.diagnostic)
  assert(lifecycle.remove(adopted.id,'fixture-adoption',true))
  peripheral.reconcile_one(c,'red',game.tick,nop)
  assert(#c.queue==2 and c.queue[2].event.name=='peripheral_detach' and c.queue[2].event.peripheral==adopted.id)
  c.queue={}; c.queue_bytes=0
  report('pending-adoption-preserves-live-output-and-observation-with-exact-native-transitions')
  local pending=assert(surface.create_entity{name='radar',position={9,6},force='player'})
  assert(connector(db,'red').connect_to(pending.get_wire_connector(red,true)))
  disconnect(db,io,'red')
  peripheral.reconcile_one(c,'red',game.tick,nop)
  error_is('E_NETWORK_PENDING',function() inventory(c,'red') end)
  peripheral.check_outputs(game.tick,nop)
  assert(not io.output_owner and io.children.output.get_control_behavior().sections_count==0,
    'pending adoption hid a real selected-path loss')
  pending.destroy(); graph.adopt_tick(game.tick,nop); connect(db,io,'red'); output(io,c,'red')
  report('pending-adoption-does-not-authorize-calls-or-hide-selected-wire-loss')
  for i,loss in ipairs({'scope','unavailable','destroyed','writer'}) do
    local writer=build(surface,'computer',24+i*8,0); writer.status='running'; writer.run_id=writer.id..'/fixture'
    local device=build(surface,'logic',24+i*8,3); connect(writer,device,'red'); output(device,writer,'red')
    peripheral.reconcile_one(writer,'red',game.tick,nop)
    local carrier=assert(surface.create_entity{name='radar',position={24+i*8,-4},force='player'})
    assert(connector(writer,'red').connect_to(carrier.get_wire_connector(red,true)))
    peripheral.reconcile_one(writer,'red',game.tick,nop); assert(device.output_owner)
    if loss=='scope' then device.body.force=game.forces['tc05-foreign']
    elseif loss=='unavailable' then device.availability_version=99
    elseif loss=='destroyed' then device.body.destroy()
    else writer.run_id=writer.id..'/next-generation' end
    peripheral.check_outputs(game.tick,nop)
    assert(not device.output_owner and device.children.output.get_control_behavior().sections_count==0,
      'pending adoption retained invalid '..loss..' authority')
    carrier.destroy(); graph.adopt_tick(game.tick,nop)
    assert(lifecycle.remove(device.id,'fixture-pending-loss',true))
    assert(lifecycle.remove(writer.id,'fixture-pending-loss',true))
  end
  report('pending-adoption-still-clears-scope-unavailable-destroyed-and-writer-generation-loss')
  disconnect(c,db,'red'); peripheral.reconcile_one(c,'red',game.tick,nop)
  assert(not io.output_owner and io.children.output.get_control_behavior().sections_count==0)
  local failure_source="function changed(e) error('detach handler failed') end"
  local failure_ctx=admission.context(admission.new(),c.id,0)
  local failure_plan=assert(compiler.compile(failure_source,failure_ctx))
  local ran,diagnostic=compiler.run(failure_plan,'changed',c.queue[1].event,function(g) return runtime.services(c,game.tick,g) end,failure_ctx)
  assert(not ran and diagnostic.code=='E_PROGRAM' and not io.output_owner)
  assert(#c.queue==2 and c.queue[1].event.name=='peripheral_detach' and c.queue[2].event.name=='peripheral_detach')
  assert(c.queue[1].event.peripheral<c.queue[2].event.peripheral and c.queue[1].event.wire=='red')
  connect(c,db,'red'); peripheral.reconcile_one(c,'red',game.tick,nop)
  assert(#c.queue==4 and c.queue[3].event.name=='peripheral_attach' and c.queue[4].event.name=='peripheral_attach')
  c.queue={}; c.queue_bytes=0
  report('silent-baseline-and-deterministic-detach-before-attach-events')
  output(io,c,'red'); disconnect(c,db,'red'); connect(c,io,'red')
  peripheral.check_outputs(game.tick,nop); assert(io.output_owner,'bounded alternate path was not recovered')
  disconnect(c,io,'red'); peripheral.check_outputs(game.tick,nop)
  assert(not io.output_owner and io.children.output.get_control_behavior().sections_count==0)
  connect(c,db,'red'); output(io,c,'red')
  local port=io.children.output; local at=port.position
  assert(port.teleport({at.x,at.y+1}))
  peripheral.check_outputs(game.tick,nop)
  assert(not io.output_owner and port.get_control_behavior().sections_count==0,'moved owned output retained its bank')
  assert(port.teleport(at)); output(io,c,'red')
  local unowned=assert(surface.create_entity{name='constant-combinator',position={6,12},force='player'})
  local native=unowned.get_or_create_control_behavior(); native.enabled=true
  for i=native.sections_count,1,-1 do native.remove_section(i) end
  local section=native.add_section(); section.set_slot(1,{value={type='virtual',name='signal-Z',quality='normal'},min=33})
  assert(native.enabled and native.sections_count==1 and section.get_slot(1).min==33)
  io.children.output=unowned; lifecycle.clear_output(io)
  assert(native.enabled and native.sections_count==1 and section.get_slot(1).min==33,'cleanup rewrote an unowned output')
  local body=io.body; io.body=unowned; lifecycle.reset_network(io); io.body=body
  assert(native.enabled and native.sections_count==1 and unowned.operable,'network reset rewrote an unowned body')
  io.children.output=port; lifecycle.clear_output(io); unowned.destroy(); output(io,c,'red')
  -- An old writer's revocation cannot clear the newer ownership generation.
  io.output_owner.run_id='newer-writer'; peripheral.revoke(c,io.id,'red','wire_removed')
  assert(io.output_owner and io.output_owner.run_id=='newer-writer')
  io.output_owner.run_id=c.run_id
  local root=registry.get(); root.scheduler.maintenance_tick=game.tick; root.scheduler.maintenance_spent=limits.maintenance_work_per_tick-#registry.owned_outputs().order*258
  peripheral.check_outputs(game.tick,scheduler.maintenance(root,game.tick))
  assert(not io.output_owner and io.authority_diagnostic.code=='E_NETWORK_PENDING')
  root.scheduler.maintenance_spent=0
  output(io,c,'red'); runtime.stop(c.id)
  assert(not io.output_owner and io.children.output.get_control_behavior().sections_count==0 and c.network_views==nil)
  c.status='running' -- Isolated boundary fixture; real activation/dispatch follows below.
  report('native-output-exact-writer-alternate-proof-and-zero-proof-credit-cleanup')
  local inspection_ctx=admission.context(admission.new(),c.id,0)
  local inspection_plan=assert(compiler.compile(inspection_source,inspection_ctx))
  c.subscriptions={}; c.active={source=inspection_source,api_version=1,compiler_version=limits.compiler_version,storage_version=1,handlers=inspection_plan.handlers}
  local inspected,diagnostic=compiler.run(inspection_plan,'start',{name='start'},function(g) return runtime.services(c,game.tick,g) end,inspection_ctx)
  assert(inspected,diagnostic and diagnostic.message)
  assert(#c.state.names_red==2 and #c.state.names_green==0)
  report('packaged-help-example-through-native-compiler-and-real-service-boundary')
  -- Keep only the cold participants: avoids measuring unrelated fixture worlds.
  for _,rec in ipairs({mon,c2,role_only,foreign,remote,a,b,hidden,left,right}) do lifecycle.remove(rec.id,'fixture-cleanup',true) end
  pole.destroy(); ghost.destroy()
  runtime.save(c.id,cold_source,c.saved_revision); assert(runtime.activate(c.id,game.tick))
  local substation=assert(surface.create_entity{name='substation',position={0,5},force='player'})
  local power=assert(surface.create_entity{name='electric-energy-interface',position={-3,5},force='player'})
  power.power_production=1000000; power.power_usage=0
  f().c=c.id; f().db=db.id; f().io=io.id; f().power=power; f().pole=substation
  f().lamp=assert(surface.create_entity{name='small-lamp',position={6,5},force='player'})
  assert(f().lamp.get_wire_connector(red,true).connect_to(connector(io,'red','output')))
  report('cold-fixture-armed-with-authentic-native-source-and-physical-identities')
  log('TC_CONTRACT_TOTAL '..f().groups)
end
local function snapshot()
  local root=registry.get(); local c=registry.computer(f().c); local db=registry.record(f().db); local io=registry.record(f().io)
  return {run_id=c.run_id,boots=c.state.boots,source=c.active.source,db_unit=db.body.unit_number,
    c_unit=c.body.unit_number,io_unit=io.body.unit_number,view=c.network_views.red.inventory,
    owner=io.output_owner,ledger_tick=root.ledger.tick,total=root.ledger.total,
    machine=root.ledger.machines[c.id],work=root.ledger.machines[c.id].work,
    compile=root.ledger.machines[c.id].compile,allocations=root.ledger.machines[c.id].allocations,
    maintenance=root.scheduler.maintenance_spent,sequence=root.next_sequence,
    outputs=root.output_owners,interests=root.topology_interests,adoption=root.native_adoption}
end
local function unchanged()
  local s=f().snapshot; local now=snapshot()
  for _,k in ipairs({'run_id','boots','source','db_unit','c_unit','io_unit','ledger_tick','total','work','compile','allocations','maintenance','sequence'}) do assert(now[k]==s[k],'cold load changed '..k) end
  assert(now.view==s.view and now.owner==s.owner and now.machine==s.machine,'cold aliases changed')
  assert(now.outputs==s.outputs and now.interests==s.interests and now.adoption==s.adoption,'cold membership aliases changed')
  assert(now.outputs.records[f().io].record==registry.record(f().io) and #now.interests.order==2)
  local pending=now.adoption.entries[f().stopped..'/red']
  assert(#now.adoption.order==3 and pending.computer==registry.record(f().stopped) and pending.wire=='red')
  local faulted=registry.computer(f().faulted_discovery)
  assert(faulted.status=='faulted' and faulted.state.boots==1 and not registry.by_entity(f().speaker))
  assert(now.adoption.entries[faulted.id..'/red'].computer==faulted)
  assert(pending.computer.status=='stopped' and pending.generation==pending.computer.generation and not registry.by_entity(f().native))
  assert(registry.record(f().io).output_owner.computer_id==f().c)
  assert(now.view[f().io] and registry.computer(f().c).network_views.red.diagnostic.code=='E_NETWORK_PENDING')
  assert(not registry.by_entity(f().live_native) and graph.validate_witness(registry.computer(f().c),'red',now.owner.path,nop))
end
function M.on_load()
  loaded=true
  if f().phase=='frozen' then unchanged(); log('TC_COLD_ON_LOAD_UNCHANGED') end
end
function M.on_tick(event)
  local fixture=f(); local c=registry.computer(fixture.c); local db=registry.record(fixture.db); local io=registry.record(fixture.io)
  if fixture.phase=='frozen' then
    if not loaded then return end
    unchanged(); loaded=false
    local ctx=admission.context(registry.get().ledger,c.id,fixture.snapshot.ledger_tick)
    assert(ctx.machine==fixture.snapshot.machine and ctx.ledger.total==fixture.snapshot.total)
    assert(not admission.reserve(ctx,'work',limits.callback_work+1-ctx.machine.work))
    error_is('E_NETWORK_PENDING',function() inventory(c,'red') end)
    fixture.phase='adopting'; fixture.resume_tick=event.tick
  elseif fixture.phase=='armed' then loaded=false end
  if fixture.phase=='done' then return end
  scheduler.tick(event.tick)
  assert(c.status=='running',c.diagnostic and c.diagnostic.message)
  if fixture.phase=='adopting' then
    assert(event.tick-fixture.resume_tick<120,'cold adoption deadline exceeded')
    assert(io.output_owner==fixture.snapshot.owner and c.state.boots==1)
    if not c.state.events or #c.state.events<1 or event.tick<fixture.resume_tick+4 then return end
    local adopted=assert(registry.by_entity(fixture.live_native))
    assert(#c.state.events==1 and c.state.events[1].name=='peripheral_attach' and c.state.events[1].peripheral==adopted.id)
    assert(fixture.lamp.energy>0 and fixture.lamp.get_signal({type='virtual',name='signal-A',quality='normal'},defines.wire_connector_id.circuit_red)==7)
    log('TC_CONTRACT cold-pending-adoption-preserves-native-output-owner-and-exactly-one-attach-without-startup-replay')
    disconnect(c,db,'red'); fixture.phase='resuming'; fixture.resume_tick=event.tick
    runtime.enqueue(c,'check',{name='fixture_check'},event.tick)
  end
  if fixture.phase=='resuming' then
    assert(event.tick-fixture.resume_tick<120,'cold topology resumption deadline exceeded: '..serpent.line(c.state))
  end
  if fixture.phase=='armed' and c.state.boots==1 and c.network_views and c.network_views.red then
    assert(inventory(c,'red')[db.id] and inventory(c,'red')[io.id])
    output(io,c,'red')
    local root=registry.get(); local queue,subscriptions,views=c.queue,c.subscriptions,c.network_views
    local sequence,maintenance=root.next_sequence,root.scheduler.maintenance_spent
    local owner=assert(io.output_owner)
    root.output_owners=nil; root.topology_interests=nil; root.native_adoption=nil
    registry.initialize()
    assert(c.queue==queue and c.subscriptions==subscriptions and c.network_views==views and io.output_owner==owner)
    assert(root.next_sequence==sequence and root.scheduler.maintenance_spent==maintenance)
    assert(root.output_owners.records[io.id].record==io and #root.topology_interests.order==2 and #root.native_adoption.order==0)
    local stopped=build(c.body.surface,'computer',40,30)
    local native=assert(c.body.surface.create_entity{name='radar',position={46,30},force='player'})
    assert(connector(stopped,'red').connect_to(native.get_wire_connector(defines.wire_connector_id.circuit_red,true)))
    error_is('E_NETWORK_PENDING',function() inventory(stopped,'red') end)
    assert(stopped.status=='stopped' and #root.native_adoption.order==1 and not registry.by_entity(native))
    fixture.stopped=stopped.id; fixture.native=native
    local first=build(c.body.surface,'computer',52,30)
    local native_speaker=assert(c.body.surface.create_entity{name='programmable-speaker',position={55,30},force='player'})
    assert(connector(first,'red').connect_to(native_speaker.get_wire_connector(defines.wire_connector_id.circuit_red,true)))
    runtime.save(first.id,[[function start()
      computer.setState('boots',(computer.getState('boots') or 0)+1)
      peripheral.find('speaker','red')
    end]],0)
    assert(runtime.activate(first.id,event.tick)); scheduler.dispatch(first,event.tick)
    -- The first activation advances the real admission clock; retain paid current-tick credits too.
    assert(admission.reserve(runtime.context(c,event.tick),'work',1))
    assert(first.status=='faulted' and first.diagnostic.code=='E_NETWORK_PENDING')
    assert(root.native_adoption.entries[first.id..'/red'],'first discovery fault canceled physical adoption')
    local removed=build(c.body.surface,'computer',60,30)
    assert(connector(removed,'red').connect_to(native_speaker.get_wire_connector(defines.wire_connector_id.circuit_red,true)))
    error_is('E_NETWORK_PENDING',function() inventory(removed,'red') end)
    assert(runtime.stop(removed.id) and root.native_adoption.entries[removed.id..'/red'])
    assert(lifecycle.remove(removed.id,'fixture-discovery-removal',true))
    assert(not root.native_adoption.entries[removed.id..'/red'],'removed root retained discovery demand')
    fixture.faulted_discovery=first.id; fixture.speaker=native_speaker
    fixture.live_native=assert(c.body.surface.create_entity{name='radar',position={9,0},force='player'})
    assert(connector(db,'red').connect_to(fixture.live_native.get_wire_connector(defines.wire_connector_id.circuit_red,true)))
    local owner=io.output_owner; local view=c.network_views.red.inventory
    peripheral.reconcile_one(c,'red',event.tick,nop)
    assert(io.output_owner==owner and c.network_views.red.inventory==view and #c.queue==0)
    log('TC_CONTRACT membership-migration-preserves-accepted-state-and-stopped-native-discovery-pending')
    fixture.phase='frozen'; fixture.snapshot=snapshot()
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  if fixture.phase=='resuming' and c.state.checked and c.state.events and #c.state.events==4 then
    assert(c.state.boots==1 and not io.output_owner and io.children.output.get_control_behavior().sections_count==0)
    local original={}; local native=assert(registry.by_entity(fixture.live_native))
    assert(c.state.events[1].name=='peripheral_attach' and c.state.events[1].peripheral==native.id)
    for i=2,4 do
      local e=c.state.events[i]
      assert(e.name=='peripheral_detach' and e.wire=='red')
      if i>2 then assert(c.state.events[i-1].peripheral<e.peripheral) end
      if e.peripheral~=native.id then original[#original+1]=e end
    end
    assert(#original==2 and original[1].peripheral<original[2].peripheral)
    assert((original[1].peripheral==db.id and original[2].peripheral==io.id)
      or (original[1].peripheral==io.id and original[2].peripheral==db.id))
    assert(c.state.db==db.id and c.state.wire=='red' and c.state.position.x==db.body.position.x)
    local native=assert(registry.by_entity(fixture.native)); local stopped=registry.computer(fixture.stopped)
    assert(native.kind=='radar' and #registry.get().native_adoption.order==0 and stopped.status=='stopped' and not stopped.active)
    assert(inventory(stopped,'red')[native.id] and not inventory(stopped,'green')[native.id])
    local first=registry.computer(fixture.faulted_discovery); local native_speaker=assert(registry.by_entity(fixture.speaker))
    assert(first.status=='faulted' and first.state.boots==1 and inventory(first,'red')[native_speaker.id])
    assert(runtime.activate(first.id,event.tick)); fixture.phase='retry-discovery'; return
  end
  if fixture.phase=='retry-discovery' and registry.computer(fixture.faulted_discovery).state.boots==2 then
    local first=registry.computer(fixture.faulted_discovery)
    assert(first.status=='running' and #first.queue==0 and #registry.get().native_adoption.order==0)
    assert(runtime.stop(first.id))
    log('TC_CONTRACT cold-first-discovery-fault-retains-adoption-no-replay-and-explicit-retry-succeeds')
    log('TC_CONTRACT cold-pending-native-discovery-adopted-once-from-stopped-root')
    local subscriptions={}; for id in pairs(c.subscriptions) do subscriptions[#subscriptions+1]=id end
    for _,id in ipairs(subscriptions) do assert(runtime.unsubscribe(c,id)) end
    local root=registry.get()
    assert(#root.topology_interests.order==0 and next(root.topology_interests.computers)==nil)
    assert(#root.output_owners.order==0 and next(root.output_owners.records)==nil and next(root.output_owners.computers)==nil)
    local work=0; peripheral.reconcile(event.tick,function(n) work=work+n end)
    assert(work==0,'last topology cancellation retained discovery work')
    log('TC_CONTRACT cold-owned-membership-retained-and-last-topology-interest-retired')
    fixture.phase='done'; log('TC_COLD_OK')
  end
end
return M
