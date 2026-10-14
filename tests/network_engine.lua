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
  local body=assert(surface.create_entity{name=defs.devices[kind].name,position={x,y},force=force or 'player'})
  lifecycle.on_built{entity=body}
  local rec=assert(registry.by_entity(body)); body.energy=defs.devices[kind].watts/30
  rec.powered=true; return rec
end
local function inventory(c,wire) return peripheral.inventory(c,wire,nop) end
local function error_is(code,fn)
  local ok,e=pcall(fn); assert(not ok and type(e)=='table' and e.code==code,'expected '..code..', got '..(type(e)=='table' and tostring(e.code) or tostring(e)))
end
local function guest(c,body)
  local source='return {api_version=1,handlers={start=function(e) '..body..' end}}'
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
end
local cold_source=[[return {api_version=1,handlers={
start=function(e)
  computer.setState('boots',(computer.getState('boots') or 0)+1)
  computer.on('peripheral_attach','changed'); computer.on('peripheral_detach','changed')
  local db=peripheral.find('kv_database','red'); assert(db)
  computer.setState('db',peripheral.getName(db)); computer.setState('wire',peripheral.getWire(db))
  local info=peripheral.describe(peripheral.getName(db),'red'); computer.setState('position',info.position)
end,
changed=function(e)
  local events=computer.getState('events') or {}
  events[#events+1]={name=e.name,peripheral=e.peripheral,wire=e.wire,reason=e.reason or ''}
  computer.setState('events',events)
end,
check=function(e)
  local name=computer.getState('db'); assert(not peripheral.isPresent(name,'red'))
  assert(peripheral.wrap(name,'red')==nil)
  computer.setState('checked',true)
end
}}]]
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
    local info=peripheral.describe(peripheral.getName(db),'red'); assert(not info.powered)
    info.position.x=999; assert(peripheral.describe(peripheral.getName(db),'red').position.x~=999)
    assert(db.getLimits().fixture_entries==1)
    local ok,e=pcall(db.testGet); assert(not ok and e.code=='E_UNPOWERED')
    assert(select('#',peripheral.find('unknown','green'))==0)
    local methods=peripheral.getMethods(peripheral.getName(db),'red'); assert(#methods==5)
    methods[1]='bad'; assert(peripheral.getMethods(peripheral.getName(db),'red')[1]~='bad')
    ok,e=pcall(peripheral.getNames,'both'); assert(not ok and e.code=='E_ARGUMENT')
    ok,e=pcall(peripheral.getNames); assert(not ok and e.code=='E_ARGUMENT')
    ok,e=pcall(peripheral.call,peripheral.getName(db),'red','unknown'); assert(not ok and e.code=='E_ARGUMENT')
    ok,e=pcall(db.getLimits,db); assert(not ok and e.code=='E_ARGUMENT')]])
  db.powered=true
  report('compiled-discovery-metadata-copy-arity-unpowered-static-limits-and-zero-tuple')
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
  disconnect(c,db,'red'); peripheral.reconcile_one(c,'red',game.tick,nop)
  assert(not io.output_owner and io.children.output.get_control_behavior().sections_count==0)
  local failure_source="return {api_version=1,handlers={changed=function(e) error('detach handler failed') end}}"
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
  -- An old writer's revocation cannot clear the newer ownership generation.
  io.output_owner.run_id='newer-writer'; peripheral.revoke(c,io.id,'red','wire_removed')
  assert(io.output_owner and io.output_owner.run_id=='newer-writer')
  io.output_owner.run_id=c.run_id
  local root=registry.get(); root.scheduler.maintenance_tick=game.tick; root.scheduler.maintenance_spent=limits.maintenance_work_per_tick-(#root.order*4+256)
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
    maintenance=root.scheduler.maintenance_spent,sequence=root.next_sequence}
end
local function unchanged()
  local s=f().snapshot; local now=snapshot()
  for _,k in ipairs({'run_id','boots','source','db_unit','c_unit','io_unit','ledger_tick','total','work','compile','allocations','maintenance','sequence'}) do assert(now[k]==s[k],'cold load changed '..k) end
  assert(now.view==s.view and now.owner==s.owner and now.machine==s.machine,'cold aliases changed')
  assert(registry.record(f().io).output_owner.computer_id==f().c)
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
    disconnect(c,db,'red'); fixture.phase='resuming'; fixture.resume_tick=event.tick
    runtime.enqueue(c,'check',{name='fixture_check'},event.tick)
  elseif fixture.phase=='armed' then loaded=false end
  if fixture.phase=='done' then return end
  scheduler.tick(event.tick)
  assert(c.status=='running',c.diagnostic and c.diagnostic.message)
  if fixture.phase=='resuming' then
    assert(event.tick-fixture.resume_tick<120,'cold topology resumption deadline exceeded: '..serpent.line(c.state))
  end
  if fixture.phase=='armed' and c.state.boots==1 and c.network_views and c.network_views.red then
    assert(inventory(c,'red')[db.id] and inventory(c,'red')[io.id])
    output(io,c,'red'); fixture.phase='frozen'; fixture.snapshot=snapshot()
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  if fixture.phase=='resuming' and c.state.checked and c.state.events and #c.state.events==2 then
    assert(c.state.boots==1 and not io.output_owner and io.children.output.get_control_behavior().sections_count==0)
    assert(c.state.events[1].name=='peripheral_detach' and c.state.events[2].name=='peripheral_detach')
    assert(c.state.events[1].wire=='red' and c.state.events[1].peripheral<c.state.events[2].peripheral)
    assert(c.state.db==db.id and c.state.wire=='red' and c.state.position.x==db.body.position.x)
    fixture.phase='done'; log('TC_COLD_OK')
  end
end
return M
