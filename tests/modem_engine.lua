local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local peripheral=require('scripts.services.peripheral')
local lifecycle=require('scripts.lifecycle')
local modem=require('scripts.services.modem')
local radar=require('scripts.radar')
local defs=require('scripts.device-definitions')
local limits=require('scripts.runtime.limits')
local shell=require('scripts.runtime.shell')
local graph=require('scripts.network')
local sandbox=require('scripts.runtime.sandbox')
local M={}; local loaded=false
local function nop() end
local function f() return storage.modem_fixture end
local function report(name) f().groups=f().groups+1; log('TC_CONTRACT '..name) end
local function error_is(code,fn)
  local ok,e=pcall(fn); assert(not ok and type(e)=='table' and e.code==code,'expected '..code..': '..serpent.line(e))
end
local function build(kind,surface,x,y,force)
  local name=kind=='radar' and 'radar' or kind=='advanced' and 'tc-interplanetary-radar' or defs.devices[kind].entity_name
  local body=assert(surface.create_entity{name=name,position={x,y},force=force or 'player'})
  lifecycle.on_built{entity=body}; local rec=assert(registry.by_entity(body))
  lifecycle.power_entity(rec).energy=1000000; rec.powered=true; return rec
end
local function conn(rec,wire)
  if rec.native_carrier then return assert(rec.body.get_wire_connector(defines.wire_connector_id['circuit_'..wire],true)) end
  return assert(lifecycle.connector(rec,'network',wire))
end
local function connect(a,b,wire)
  if not conn(a,wire).is_connected_to(conn(b,wire)) then assert(conn(a,wire).connect_to(conn(b,wire),false)) end
end
local function guest(c,source,handler,event)
  local ctx=admission.context(admission.new(),c.id,game.tick)
  local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
  c.active={source=source,revision=0,api_version=1,compiler_version=limits.compiler_version,storage_version=1,handlers=plan.handlers}
  c.status='running'; c.run_id=c.run_id or c.id..'/fixture'
  local ok,problem=compiler.run(plan,handler or 'start',event or {name='start'},function(g) return runtime.services(c,game.tick,g) end,ctx)
  assert(ok,problem and (problem.code..': '..problem.message))
  return ctx
end
local function call(c,r,method,...)
  return modem.methods[method](c,r,'red',game.tick,nop,...)
end
local receiver_source=[[
function received(e)
  assert(e.name=='modem_message')
  local n=computer.getState('messages') or 0
  computer.setState('messages',n+1)
  computer.setState('last',e.message==nil and 'nil' or e.message)
end
]]
local function subscribe(c)
  guest(c,receiver_source,'received',{name='modem_message',message='setup'})
  c.state={}; c.state_sizes={}; c.state_bytes=16; c.state_entries=0; c.state_nodes=1; c.state_node_sizes={}
  runtime.subscribe(c,'modem_message','received',nil,nop)
end
local function clear(c) c.queue={}; c.queue_bytes=0 end
function M.run()
  storage.modem_fixture={groups=0,phase='armed'}
  local surface=game.surfaces[1]
  local c=build('computer',surface,0,0); local r=build('radar',surface,6,0)
  local d=build('computer',surface,1000,0); local s=build('radar',surface,1006,0)
  connect(c,r,'red'); connect(c,r,'green'); connect(d,s,'red'); connect(d,s,'green')
  f().sender=c.id; f().radar=r.id; f().receiver=d.id; f().remote=s.id
  c.status='running'; c.run_id=c.id..'/fixture'
  guest(c,[[function start(e)
    local m=peripheral.find('modem','red'); assert(m)
    local name=peripheral.getName(m); local green=peripheral.wrap(name,'green')
    local expected={'close','closeAll','getLimits','isOpen','isWireless','open','transmit'}
    local actual=peripheral.getMethods(name,'red'); assert(#actual==#expected)
    for i,v in ipairs(expected) do assert(actual[i]==v) end
    local info=peripheral.describe(name,'red'); assert(info.modem_tier=='surface' and info.footprint.width==3 and info.footprint.height==3)
    assert(m.isWireless() and m.getLimits().open_channels==128)
    assert(select('#',m.open(0))==0 and select('#',m.open(65535))==0)
    assert(green.isOpen(0) and green.isOpen(65535))
    assert(select('#',m.close(65535))==0 and not m.isOpen(65535))
    m.closeAll(); assert(not green.isOpen(0))
    for ch=0,127 do m.open(ch) end
    m.open(0); assert(green.isOpen(127))
    local ok,e=pcall(m.open,128); assert(not ok and e.code=='E_CAPACITY')
    m.close(0); m.open(128); assert(not m.isOpen(0) and m.isOpen(128))
    for _,v in ipairs({'x',false,{}}) do ok,e=pcall(m.open,v); assert(not ok and e.code=='E_ARGUMENT') end
    for _,v in ipairs({-1,65536,0.5}) do ok,e=pcall(m.open,v); assert(not ok and e.code=='E_RANGE') end
    for _,method in ipairs({'open','close','isOpen'}) do
      ok,e=pcall(m[method]); assert(not ok and e.code=='E_ARGUMENT')
      ok,e=pcall(m[method],m,1); assert(not ok and e.code=='E_ARGUMENT')
    end
    for _,method in ipairs({'closeAll','isWireless','getLimits'}) do ok,e=pcall(m[method],1); assert(not ok and e.code=='E_ARGUMENT') end
    ok,e=pcall(m.transmit,1,2); assert(not ok and e.code=='E_ARGUMENT')
    ok,e=pcall(computer.setState,'facade',m); assert(not ok and e.code=='E_ARGUMENT')
    m.closeAll()
  end]])
  report('compiled-seven-method-arity-channel-boundaries-capacity-sharing-and-metadata')
  r.body.energy=0; r.powered=false
  guest(c,[[function start(e)
    local m=peripheral.find('modem','red'); assert(m.getLimits().channel_min==0)
    assert(not peripheral.describe(peripheral.getName(m),'red').powered)
    for _,method in ipairs({'isWireless','closeAll'}) do local ok,e=pcall(m[method]); assert(not ok and e.code=='E_UNPOWERED') end
  end]])
  r.body.energy=1000000; r.powered=true
  report('compiled-unpowered-metadata-limits-and-live-method-refusal')
  subscribe(d); call(d,s,'open',42); call(c,r,'open',42)
  -- Include the real facade/service/G.call return boundary, not just the
  -- provider body. A refused current invocation cannot enqueue or spend a send.
  local root=registry.get(); local previous=root.modem_transport
  for _,kind in ipairs({'work','allocations'}) do
    local function setup()
      root.modem_transport=previous; clear(d)
      local ctx=admission.context(admission.new(),c.id,game.tick)
      local g=sandbox.new(ctx,{})
      local api=peripheral.services(c,game.tick,g).peripheral
      local fn=g.get(api.wrap(r.id,'red'),'transmit')
      return ctx,g,fn
    end
    local ctx,g,fn=setup(); local before=ctx.machine[kind]
    assert(pcall(g.call,fn,42,17,'boundary') and #d.queue==1)
    local cost=ctx.machine[kind]-before
    ctx,g,fn=setup()
    ctx.machine[kind]=limits[kind=='work' and 'callback_work' or 'callback_allocations']-cost
    assert(pcall(g.call,fn,42,17,'boundary') and #d.queue==1)
    ctx,g,fn=setup(); local sequence=root.next_sequence
    ctx.machine[kind]=limits[kind=='work' and 'callback_work' or 'callback_allocations']-cost+1
    local ok,e=pcall(g.call,fn,42,17,'boundary')
    assert(not ok and g.diagnostic(e).code=='E_BUDGET' and #d.queue==0 and root.next_sequence==sequence)
    assert(not root.modem_transport or root.modem_transport.total==0)
  end
  root.modem_transport=previous; clear(d)
  report('guarded-transmit-exact-work-allocation-and-one-short-no-publication')
  f().next=1
  log('TC_CONTRACT_TOTAL '..f().groups)
end
local function power()
  for _,id in ipairs(registry.get().order) do local rec=registry.record(id)
    if rec and rec.body.valid then lifecycle.power_entity(rec).energy=1000000; rec.powered=true end
  end
end
local function traffic(c,r,d,s)
  local payload={value=false,nested={text='original'}}
  call(c,r,'transmit',42,17,payload); payload.nested.text='mutated'
  assert(#d.queue==1 and #c.queue==0 and d.state.messages==nil)
  local e=d.queue[1].event
  assert(e.name=='modem_message' and e.peripheral==s.id and e.channel==42 and e.replyChannel==17)
  assert(e.wire=='red' and #e.wires==2 and e.wires[2]=='green' and e.distance==1000 and e.sent_tick==game.tick)
  assert(e.message.value==false and e.message.nested.text=='original')
  call(d,s,'closeAll'); assert(#d.queue==1)
  conn(d,'red').disconnect_from(conn(s,'red')); conn(d,'green').disconnect_from(conn(s,'green'))
  assert(#d.queue==1)
  connect(d,s,'red'); connect(d,s,'green'); call(d,s,'open',42)
  clear(d); call(c,r,'transmit',42,17,nil); assert(#d.queue==1 and d.queue[1].event.message==nil)
  error_is('E_LIMIT',function() call(c,r,'transmit',42,17,false) end)
  assert(#d.queue==1); clear(d)
  report('broadcast-defensive-copy-nil-distance-both-wire-dedup-detach-close-and-rate')
end
local function failures(c,r,d,s)
  local before=#d.queue
  local invalid={function() end,0/0,{[1]=1,a=2},{[2]=1}}
  local cycle={}; cycle.self=cycle; invalid[#invalid+1]=cycle
  for _,v in ipairs(invalid) do error_is('E_ARGUMENT',function() call(c,r,'transmit',42,17,v) end) end
  error_is('E_LIMIT',function() call(c,r,'transmit',42,17,string.rep('x',4097)) end)
  assert(#d.queue==before)
  -- A relevant unresolved physical frontier refuses the entire broadcast.
  local old=assert(d.body.surface.create_entity{name='radar',position={1012,0},force='player'})
  assert(conn(d,'red').connect_to(old.get_wire_connector(defines.wire_connector_id.circuit_red,true),false))
  error_is('E_NETWORK_PENDING',function() call(c,r,'transmit',42,17,'no-prefix') end)
  assert(#d.queue==before); old.destroy()
  call(c,r,'transmit',42,17,false); assert(#d.queue==before+1 and d.queue[#d.queue].event.message==false)
  clear(d)
  -- One overflowing receiver faults, without a retryable sender failure.
  local healthy=build('computer',d.body.surface,1000,-6); connect(healthy,s,'red'); subscribe(healthy)
  for _=1,limits.event_queue_entries do assert(runtime.enqueue(d,'received',{name='modem_message'},game.tick)) end
  call(c,r,'transmit',42,17,'overflow'); assert(d.status=='faulted' and d.diagnostic.code=='E_CAPACITY' and #d.queue==0)
  assert(healthy.status=='running' and #healthy.queue==1 and healthy.queue[1].event.message=='overflow')
  lifecycle.remove(healthy.id,'fixture-cleanup',true)
  subscribe(d)
  report('invalid-payload-no-prefix-incomplete-proof-false-and-recipient-overflow')
end
local function duplicates(c,r,d,s)
  runtime.subscribe(d,'modem_message','received',nil,nop)
  local second=build('radar',d.body.surface,1006,6); connect(d,second,'red'); call(d,second,'open',42)
  call(c,r,'transmit',42,17,{value=1}); assert(#d.queue==4)
  assert(d.queue[1].event.peripheral<=d.queue[3].event.peripheral)
  d.queue[1].event.message.value=99
  for i=2,4 do assert(d.queue[i].event.message.value==1) end
  clear(d); lifecycle.remove(second.id,'fixture',true)
  -- Fanout counts subscriptions, not computers. No prefix at nine handlers.
  for _=3,9 do runtime.subscribe(d,'modem_message','received',nil,nop) end
  error_is('E_LIMIT',function() call(c,r,'transmit',42,17,'fanout') end)
  assert(#d.queue==0)
  d.subscriptions={}; runtime.subscribe(d,'modem_message','received',nil,nop)
  report('multiple-radars-subscription-order-copy-isolation-and-fanout-refusal')
end
function M.on_load()
  loaded=true
  if f().phase=='frozen' then
    local d=registry.record(f().receiver); local s=registry.record(f().remote)
    assert(#d.queue==1 and s.modem.channels[42] and registry.get().modem_transport==f().credits)
    assert(d.queue[1].event.message=='cold-once'); log('TC_MODEM_LOAD_UNCHANGED')
  end
end
local function expansion_setup()
  if not script.active_mods['space-age'] then return end
  local planet=game.planets.vulcanus.create_surface()
  local pc=build('computer',planet,0,0); local pr=build('advanced',planet,6,0)
  connect(pc,pr,'red'); subscribe(pc); call(pc,pr,'open',77)
  local ac=build('computer',game.surfaces[1],20,0); local ar=build('advanced',game.surfaces[1],26,0)
  connect(ac,ar,'red'); subscribe(ac); call(ac,ar,'open',77)
  local platform=assert(game.forces.player.create_space_platform{name='Modem flight fixture',planet='nauvis',starter_pack='space-platform-starter-pack'})
  assert(platform.apply_starter_pack())
  local tiles={}; for x=-20,20 do for y=-20,20 do tiles[#tiles+1]={name='space-platform-foundation',position={x,y}} end end
  platform.surface.set_tiles(tiles)
  local fc=build('computer',platform.surface,10,10); local fr=build('advanced',platform.surface,16,10)
  connect(fc,fr,'red'); subscribe(fc); call(fc,fr,'open',77)
  platform.space_connection=prototypes.space_connection['nauvis-vulcanus']; platform.speed=100
  f().planet_computer=pc.id; f().planet_radar=pr.id; f().advanced_computer=ac.id; f().advanced_radar=ar.id
  f().flight_computer=fc.id; f().flight_radar=fr.id; f().platform=platform; f().flight_distance=platform.distance
end
local function expansion_traffic(c,r,d,s)
  if not script.active_mods['space-age'] then return end
  local pc,pr=registry.record(f().planet_computer),registry.record(f().planet_radar)
  local ac,ar=registry.record(f().advanced_computer),registry.record(f().advanced_radar)
  local fc,fr=registry.record(f().flight_computer),registry.record(f().flight_radar)
  local platform=f().platform
  assert(platform.surface.platform==platform and platform.space_connection and platform.speed>0 and platform.distance~=f().flight_distance)
  call(c,r,'transmit',77,78,'ordinary-no-cross'); assert(#pc.queue==0 and #fc.queue==0 and #ac.queue==1)
  clear(ac)
  call(ac,ar,'transmit',77,78,'advanced-cross')
  assert(#pc.queue==1 and #fc.queue==1 and pc.queue[1].event.distance==nil and fc.queue[1].event.distance==nil)
  assert(not peripheral.inventory(pc,'red',nop)[ar.id] and not peripheral.inventory(ac,'red',nop)[pr.id])
  clear(pc); clear(fc)
  -- Advanced -> ordinary crosses no surface, including a genuine platform.
  call(d,s,'open',77)
  call(ac,ar,'transmit',77,78,'mixed-same-surface'); assert(#d.queue==1 and #pc.queue==1 and #fc.queue==1)
  assert(d.queue[1].event.distance~=nil); clear(d); clear(pc); clear(fc)
  -- Reverse the interplanetary route from a real moving platform.
  call(fc,fr,'transmit',77,78,'flight-reply'); assert(#ac.queue==1 and #pc.queue==1 and #d.queue==0)
  clear(ac); clear(pc)
  for _,rec in ipairs({pc,pr,ac,ar}) do lifecycle.remove(rec.id,'fixture-cleanup',true) end
  f().deleted_platform={fc.id,fr.id}
  platform.destroy(0)
  report('advanced-planet-moving-platform-mixed-tier-scope-distance-and-no-remote-authority')
end
local function envelope(c,r,d,s)
  for _,id in ipairs(f().deleted_platform or {}) do
    assert(not registry.record(id),'native platform deletion did not retire identity; platform_valid='..tostring(f().platform.valid))
  end
  for _=2,8 do runtime.subscribe(d,'modem_message','received',nil,nop) end
  local ctx=guest(c,[[function start(e)
    peripheral.find('modem','red').transmit(42,17,string.rep('x',4088))
  end]])
  assert(#d.queue==8 and #d.queue[1].event.message==4088 and d.queue_bytes<limits.event_queue_bytes)
  f().maximum={work=ctx.machine.work,allocations=ctx.machine.allocations,queue_bytes=d.queue_bytes,
    deliveries=#d.queue,message_bytes=4096}
  log('TC_MODEM_ENVELOPE '..serpent.line(f().maximum))
  clear(d); d.subscriptions={}; runtime.subscribe(d,'modem_message','received',nil,nop)
  guest(c,[[function start(e)
    local nodes={}; for i=1,255 do nodes[i]=false end
    peripheral.find('modem','red').transmit(42,17,nodes)
  end]])
  assert(#d.queue==1 and #d.queue[1].event.message==255); clear(d)
  c.shell={version=1,id=c.id..'/shell-quota-fixture',pending={},pending_bytes=0}
  local ok,e=shell.evaluate(c,"peripheral.find('modem','green').transmit(42,17,nil)",game.tick,'quota')
  assert(not ok and e.code=='E_LIMIT' and #d.queue==0,serpent.line(e))
  c.shell=nil
  report('maximum-payload-envelope-eight-handler-compiled-work-nodes-and-console-shared-quota')
end
local function global_rate(c,r,d,s)
  local depth='value'; for _=1,8 do depth={child=depth} end
  call(c,r,'transmit',42,17,depth); clear(d)
  error_is('E_LIMIT',function() call(c,r,'transmit',42,17,{child=depth}) end)
  local nodes={}; for i=1,256 do nodes[i]=false end
  error_is('E_LIMIT',function() call(c,r,'transmit',42,17,nodes) end)
  call(c,r,'transmit',999,17,'no-recipient')
  local others={}
  for i=1,7 do
    local other=build('computer',c.body.surface,-10-i*3,0); connect(other,r,'red')
    guest(other,[[function start(e)
      local m=peripheral.find('modem','red'); m.transmit(999,17,nil); m.transmit(999,17,nil)
    end]])
    others[#others+1]=other
  end
  assert(registry.get().modem_transport.total==16)
  local other=build('computer',c.body.surface,-40,0); connect(other,r,'red'); others[#others+1]=other
  guest(other,[[function start(e)
    local ok,e=pcall(peripheral.find('modem','red').transmit,999,17,nil)
    assert(not ok and e.code=='E_LIMIT')
  end]])
  for _,rec in ipairs(others) do lifecycle.remove(rec.id,'fixture-cleanup',true) end
  report('depth-node-boundaries-sixteen-global-transmits-and-no-op-accounting')
end
local function lifecycle_cases(c,r,d,s)
  local peer=build('computer',c.body.surface,0,-6); connect(peer,r,'green')
  guest(peer,[[function start(e)
    local m=peripheral.find('modem','green'); assert(m.isOpen(42)); m.open(123)
  end]])
  guest(c,[[function start(e)
    local m=peripheral.find('modem','red'); assert(m.isOpen(123)); m.close(123)
  end]])
  runtime.stop(peer.id); assert(r.modem.channels[42]); lifecycle.remove(peer.id,'fixture-cleanup',true)
  local foreign=game.forces['modem-allied'] or game.create_force('modem-allied')
  game.forces.player.set_friend(foreign,true); foreign.set_friend(game.forces.player,true)
  local fc=build('computer',c.body.surface,1100,0,foreign); local fr=build('radar',c.body.surface,1106,0,foreign)
  connect(fc,fr,'red'); subscribe(fc); call(fc,fr,'open',42)
  call(c,r,'transmit',42,17,'force-isolation'); assert(#fc.queue==0 and #d.queue==1)
  runtime.set_power(d.id,false,game.tick,nop); assert(#d.queue==0 and s.modem.channels[42])
  call(c,r,'transmit',42,17,'computer-outage'); assert(#d.queue==0)
  runtime.set_power(d.id,true,game.tick,nop); assert(#d.queue==0)
  local previous=s.modem
  s.body.force=foreign
  assert(not peripheral.inventory(d,'red',nop)[s.id])
  radar.reconcile(s,nop); assert(s.modem~=previous and s.modem.count==0)
  s.body.force=game.forces.player; radar.reconcile(s,nop); call(d,s,'open',42)
  local other_surface=game.create_surface('modem-scope-change',{width=32,height=32})
  -- The pinned engine cannot teleport a radar between surfaces. Its actual
  -- cross-surface move operation is clone/replacement, with a fresh identity.
  local cloned=assert(s.body.clone{position={0,0},surface=other_surface,force=s.body.force})
  local clone=assert(registry.by_entity(cloned)); assert(clone.id~=s.id and clone.modem.count==0)
  lifecycle.remove(clone.id,'fixture-cleanup',true)
  -- Explicit retained-scope fault injection covers the defensive mismatch path;
  -- this is not claimed as an unsupported native surface teleport.
  s.surface_index=other_surface.index; assert(not lifecycle.connector(s,'network','red'))
  radar.reconcile(s,nop); assert(s.modem.count==0); call(d,s,'open',42)
  local retained=s.modem; s.modem={version=99,channels={secret='retained'},count=1}
  error_is('E_UNSUPPORTED',function() radar.state(s,nop) end); s.modem=retained
  r.body.active=false
  guest(c,[[function start(e)
    local m=peripheral.find('modem','red'); local ok,e=pcall(m.isOpen,42)
    assert(not ok and e.code=='E_UNPOWERED' and m.getLimits().open_channels==128)
  end]])
  r.body.active=true; assert(r.modem.channels[42])
  lifecycle.remove(fc.id,'fixture-cleanup',true); lifecycle.remove(fr.id,'fixture-cleanup',true)
  report('allied-force-exclusion-computer-outage-scope-clear-corrupt-state-and-native-disable')
end
local function additional_scope_cases(c,r,d,s)
  clear(d)
  local peer=build('computer',c.body.surface,0,-6); connect(peer,r,'red'); subscribe(peer)
  -- Both computers on the sending physical radar are excluded from self-echo.
  local database=build('kv',c.body.surface,-6,0); connect(c,database,'red')
  call(c,r,'transmit',42,17,{remote_database=database.id})
  assert(#peer.queue==0 and #d.queue==1 and d.queue[1].event.message.remote_database==database.id)
  guest(d,[[function received(e)
    local name=e.message.remote_database
    assert(not peripheral.isPresent(name,'red') and peripheral.wrap(name,'red')==nil)
    local ok,problem=pcall(peripheral.call,name,'red','get','secret')
    assert(not ok and problem.code=='E_UNREACHABLE')
  end]],'received',d.queue[1].event)
  clear(d); d.subscriptions={}; subscribe(d)
  lifecycle.remove(database.id,'fixture-cleanup',true)
  -- Actual radar outage retains channels, misses traffic, then resumes without
  -- replay. Use another authorized computer for the third send this tick.
  s.body.energy=0; s.powered=false
  call(c,r,'transmit',42,17,'radar-outage'); assert(#d.queue==0 and s.modem.channels[42])
  s.body.energy=1000000; s.powered=true
  local local_receiver=build('radar',c.body.surface,-6,-6)
  connect(peer,local_receiver,'red'); call(peer,local_receiver,'open',42)
  call(peer,r,'transmit',42,17,'radar-restored')
  assert(#d.queue==1 and d.queue[1].event.message=='radar-restored'); clear(d)
  assert(#peer.queue==1 and peer.queue[1].event.peripheral==local_receiver.id)
  lifecycle.remove(local_receiver.id,'fixture-cleanup',true)
  lifecycle.remove(peer.id,'fixture-cleanup',true)
  local surface=game.create_surface('ordinary-no-cross',{width=32,height=32})
  local oc=build('computer',surface,0,0); local ordinary=build('radar',surface,6,0)
  connect(oc,ordinary,'red'); subscribe(oc); call(oc,ordinary,'open',42)
  call(oc,ordinary,'transmit',42,17,'ordinary-cross-refused')
  assert(#d.queue==0 and #oc.queue==0)
  if script.active_mods['space-age'] then
    local ac=build('computer',c.body.surface,0,-12); local advanced=build('advanced',c.body.surface,6,-12)
    connect(ac,advanced,'red'); subscribe(ac); call(ac,advanced,'open',42)
    call(ac,advanced,'transmit',42,17,'advanced-to-ordinary-no-cross')
    assert(#oc.queue==0 and #d.queue==1); clear(d)
    call(oc,ordinary,'transmit',42,17,'ordinary-to-advanced-no-cross')
    assert(#ac.queue==0 and #d.queue==0)
    lifecycle.remove(ac.id,'fixture-cleanup',true); lifecycle.remove(advanced.id,'fixture-cleanup',true)
  end
  lifecycle.remove(oc.id,'fixture-cleanup',true); lifecycle.remove(ordinary.id,'fixture-cleanup',true)
  game.delete_surface(surface)
  local source=game.create_force('radar-merge-source'); local destination=game.create_force('radar-merge-destination')
  local merged=build('radar',c.body.surface,-6,-12,source)
  call(c,merged,'open',42); local body=merged.body
  game.merge_forces(source,destination)
  -- Native merge is completed after the current event, not inline in this call.
  f().merged=merged.id; f().merged_force=destination.index
  assert(body.valid)
  report('shared-radar-no-echo-native-power-cycle-and-all-ordinary-cross-surface-exclusions')
end
local function candidates_setup(c,r,d,s)
  local merged=assert(registry.record(f().merged))
  assert(merged.body.valid and merged.body.force.index==f().merged_force and not radar.available(merged))
  radar.reconcile(merged,nop)
  assert(merged.modem.count==0 and radar.available(merged))
  lifecycle.remove(merged.id,'fixture-cleanup',true)
  local ids={}
  for i=1,63 do
    local rec=build('radar',c.body.surface,2000+i*6,0); call(c,rec,'open',42); ids[#ids+1]=rec.id
  end
  call(c,r,'transmit',42,17,'maximum-candidates'); assert(#d.queue==1); clear(d)
  local extra=build('radar',c.body.surface,2400,0); call(c,extra,'open',42); ids[#ids+1]=extra.id
  error_is('E_LIMIT',function() call(c,r,'transmit',42,17,'candidate-overload') end)
  assert(#d.queue==0); f().crowded=ids
end
local function candidates_cleanup(c,r,d,s)
  local hidden=0
  for _,edge in ipairs(conn(r,'red').real_connections) do if edge.origin==defines.wire_origin.radars then hidden=hidden+1 end end
  assert(hidden>0,'crowded native radar graph has no actual native edges')
  log('TC_MODEM_NATIVE_EDGE_INVENTORY hidden='..hidden..' native_total='..conn(r,'red').real_connection_count)
  error_is('E_LIMIT',function() graph.real_edges(conn(r,'red'),nop,0) end)
  assert(peripheral.inventory(c,'red',nop)[r.id] and not peripheral.inventory(c,'red',nop)[s.id])
  for _,id in ipairs(f().crowded) do lifecycle.remove(id,'fixture-cleanup',true) end
  report('sixty-four-candidates-boundary-and-crowded-native-origin-inventory-isolation')
end
function M.on_tick(event)
  local fixture=f()
  local c,r,d,s=registry.record(fixture.sender),registry.record(fixture.radar),registry.record(fixture.receiver),registry.record(fixture.remote)
  if fixture.phase=='done' then return end
  if fixture.phase=='frozen' then
    if not loaded then return end
    loaded=false
    assert(#d.queue==1 and d.queue[1].event.sequence==fixture.sequence)
    assert(registry.get().modem_transport.total==fixture.spent)
    error_is('E_LIMIT',function() modem.methods.transmit(c,r,'green',fixture.credits.tick,nop,42,17,'no-same-tick-renewal') end)
    fixture.phase='resuming'; power()
  elseif fixture.phase=='armed' then
    loaded=false; power()
    if fixture.next==1 then traffic(c,r,d,s)
    elseif fixture.next==2 then failures(c,r,d,s)
    elseif fixture.next==3 then duplicates(c,r,d,s)
    elseif fixture.next==4 then expansion_setup()
    elseif fixture.next==5 then expansion_traffic(c,r,d,s)
    elseif fixture.next==6 then envelope(c,r,d,s)
    elseif fixture.next==7 then global_rate(c,r,d,s)
    elseif fixture.next==8 then lifecycle_cases(c,r,d,s)
    elseif fixture.next==9 then additional_scope_cases(c,r,d,s)
    elseif fixture.next==10 then candidates_setup(c,r,d,s)
    elseif fixture.next==11 then candidates_cleanup(c,r,d,s)
    elseif fixture.next==12 then
      local ctx=guest(c,[[function start(e)
        local m=peripheral.find('modem','red'); m.transmit(42,17,'cold-once')
      end]])
      assert(ctx.machine.work>0 and #d.queue==1)
      call(c,r,'transmit',999,17,'spend-second-credit')
      fixture.credits=registry.get().modem_transport; fixture.spent=fixture.credits.total
      fixture.sequence=d.queue[1].event.sequence; fixture.phase='frozen'
      game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
    end
    fixture.next=fixture.next+1
    return
  end
  if fixture.phase=='resuming' then
    scheduler.tick(event.tick)
    assert(d.status=='running',d.diagnostic and d.diagnostic.message)
    if d.state.messages==1 then
      assert(d.state.last=='cold-once' and #d.queue==0)
      fixture.phase='done'; log('TC_COLD_OK')
    end
  end
end
function M.on_configuration_changed() log('TC_UPGRADE_OK') end
return M
