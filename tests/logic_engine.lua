-- Real circuit/section/transfer contracts; editor player delivery is table-backed.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local lifecycle=require('scripts.lifecycle')
local peripheral=require('scripts.services.peripheral')
local logic=require('scripts.services.logic')
local limits=require('scripts.runtime.limits')
local defs=require('scripts.device-definitions')
local editor=require('scripts.ui.editor')
local players=require('tests.editor_contract')
local source=require('examples.logic-controller')
local inspect=require('scripts.ui.network-inspector')
editor.register_inspector(inspect)
local M={}; local loaded=false
local function f() return storage.tc07 end
local function nop() end
local function report(s) f().groups=f().groups+1; log('TC_CONTRACT '..s) end
local function build(kind,x,y)
  local b=assert(game.surfaces[1].create_entity{name=defs.devices[kind].name,position={x,y},force='player'})
  local r=assert(lifecycle.build(b)); b.energy=100000; r.powered=true; return r
end
local function connector(r,wire,role) return assert(lifecycle.connector(r,role or 'network',wire)) end
local function connect(a,b,wire,role,other) assert(connector(a,wire,role).connect_to(connector(b,wire,other))) end
local function wire(entity,rec,color,role)
  assert(entity.get_wire_connector(defines.wire_connector_id['circuit_'..color],true).connect_to(connector(rec,color,role)))
end
local function signal(n,quality) return {type='item',name=n or 'iron-plate',quality=quality or 'normal'} end
local function put(entity,entries)
  local cb=entity.get_or_create_control_behavior()
  for i=cb.sections_count,1,-1 do cb.remove_section(i) end
  local s=cb.add_section(); local filters={}
  for i,e in ipairs(entries) do filters[i]={index=i,value=e.signal,min=e.count} end
  s.filters=filters; cb.enabled=true
end
local function guest(c,text,handler)
  local src='return {api_version=1,handlers={start=function(e) '..text..' end,changed=function(e) end}}'
  local ctx=admission.context(admission.new(),c.id,0)
  local plan,e=compiler.compile(src,ctx); assert(plan,e and e.message)
  c.active={source=src,revision=1,api_version=1,compiler_version=limits.compiler_version,storage_version=1,handlers=plan.handlers}
  local ok,err=compiler.run(plan,handler or 'start',{name='start'},function(g) return runtime.services(c,game.tick,g) end,ctx)
  assert(ok,err and (err.code..': '..err.message))
end
local function setup(c,io)
  c.status='running'; c.run_id=c.id..'/fixture'
  connect(c,io,'red')
end
local function verify_faults()
  local a=registry.computer(f().fault_ids[1]); local b=registry.computer(f().fault_ids[2])
  assert(a.diagnostic~=b.diagnostic and a.active.revision~=b.active.revision and a.run_id~=b.run_id)
  for _,c in ipairs({a,b}) do
    assert(c.status=='faulted' and c.diagnostic.code=='E_BUSY')
    assert(c.diagnostic.message=='injected native sampling refusal')
    assert(c.diagnostic.source_revision==c.active.revision and c.diagnostic.run_id==c.run_id)
    assert(#c.queue==0 and next(c.timers)==nil and next(c.subscriptions)==nil)
  end
  local io=registry.record(f().fault_io)
  assert(not io.output_owner and io.output_bank==nil and io.children.output.get_control_behavior().sections_count==0)
end
local function shared_sampler_failure()
  local a=build('computer',-12,0); local b=build('computer',-12,3); local io=build('logic',-9,0)
  -- Refusal must exercise an actual connected-input query. A disconnected
  -- endpoint is known empty and needs no native list call.
  local source=assert(game.surfaces[1].create_entity{name='constant-combinator',position={-9,-3},force='player'})
  wire(source,io,'red','input')
  f().fault_ids={a.id,b.id}; f().fault_io=io.id
  for i,c in ipairs({a,b}) do
    setup(c,io)
    guest(c,[[local io=peripheral.find('logic_handler','red')
      io.setOutput({{signal={type='virtual',name='signal-A'},count=1}})
      io.subscribe({input='red',initial=true},'changed')
      computer.after(10,'changed')]])
    c.active.revision=i+2
    assert(runtime.enqueue(c,'changed',{name='pending'},game.tick))
  end
  assert(io.output_owner.computer_id==b.id)
  -- Refuse only native-call admission, not gathering/ordering/notification.
  -- One shared sample must fan out the very same failure to both subscribers.
  local charge=32
  local failure={code='E_BUSY',message='injected native sampling refusal'}; local refusals=0
  logic.sample(game.tick,function(n)
    if n==charge then refusals=refusals+1; error(failure,0) end
  end)
  assert(refusals==1 and failure.run_id==nil and failure.source_revision==nil)
  verify_faults()
  source.destroy()
  report('shared-native-sampler-failure-distinct-diagnostics-and-fail-closed-cleanup')
end
function M.run()
  registry.initialize(); storage.tc07={groups=0,phase='inputs',started=game.tick}
  local s=game.surfaces[1]; local c=build('computer',0,0); local relay=build('kv',3,0); local io=build('logic',6,0)
  setup(c,io); connect(c,relay,'red'); connect(relay,io,'red')
  local b=build('computer',6,3); setup(b,io)
  f().c=c.id; f().b=b.id; f().io=io.id; f().relay=relay.id
  local inventory=assert(inspect(c,'red',game.tick)); assert(#inventory==2)
  assert(#assert(inspect(c,'green',game.tick))==0)
  inventory[1].name='mutated'; assert(assert(inspect(c,'red',game.tick))[1].name~='mutated')
  local ctx=runtime.context(c,game.tick); assert(admission.reserve(ctx,'work',limits.callback_work-ctx.machine.work))
  local absent,diagnostic=inspect(c,'red',game.tick); assert(not absent and diagnostic.code=='E_BUSY')
  -- This is an isolated host adapter admission contract, not new tick credits.
  assert(ctx.machine.work==limits.callback_work)
  report('production-editor-inspector-complete-copy-colour-and-work-refusal')
  guest(c,[[local io=peripheral.find('logic_handler','red'); assert(#peripheral.getMethods(peripheral.getName(io),'red')==9)
    assert(select('#',io.setOutput({{signal={type='virtual',name='signal-A'},count=-2147483648}}))==0)
    local old=io.getOutput(); assert(old[1].count==-2147483648 and old[1].signal.quality=='normal')
    old[1].count=9; assert(io.getOutput()[1].count==-2147483648)
    local ok,e=pcall(io.setOutput,{{signal={type='virtual',name='signal-A'},count=2},{signal={type='virtual',name='signal-A',quality='normal'},count=3}})
    assert(not ok and e.code=='E_ARGUMENT' and io.getOutput()[1].count==-2147483648)
    ok,e=pcall(io.setOutput,{{signal={type='virtual',name='signal-each'},count=1}}); assert(not ok and e.code=='E_RANGE')
    ok,e=pcall(io.setOutput,{{signal={type='item',name='iron-plate',quality=false},count=1}}); assert(not ok and e.code=='E_ARGUMENT')
    ok,e=pcall(io.setOutput,{{signal={type='item',name='iron-plate'},count=2147483648}}); assert(not ok and e.code=='E_RANGE')
    ok,e=pcall(io.readSignals,'blue'); assert(not ok and e.code=='E_ARGUMENT')
    ok,e=pcall(io.clearOutput,io); assert(not ok and e.code=='E_ARGUMENT')
    assert(io.getLimits().sample_interval_ticks==1 and io.getLimits().signal_slots==64)]])
  report('native-sections-canonical-copy-duplicate-domain-and-arity-refusals')
  guest(b,[[peripheral.find('logic_handler','red').setOutput({{signal={type='virtual',name='signal-A'},count=7}})]])
  local newer=io.output_owner; runtime.stop(c.id); assert(io.output_owner==newer and io.output_bank[1].count==7)
  runtime.stop(b.id); assert(not io.output_owner and io.children.output.get_control_behavior().sections_count==0)
  report('real-multiple-writers-exact-run-stop-cleanup')
  c.status='running'; c.run_id=c.id..'/fixture2'
  local red=assert(s.create_entity{name='constant-combinator',position={3,-3},force='player'})
  local green=assert(s.create_entity{name='constant-combinator',position={6,-3},force='player'})
  put(red,{{signal=signal(),count=2147483647}})
  local green_entries={{signal=signal(),count=1}}
  if script.active_mods.quality then green_entries[2]={signal=signal('iron-plate','uncommon'),count=3}; f().has_quality=true end
  put(green,green_entries)
  wire(red,io,'red','input'); wire(green,io,'green','input'); f().red=red; f().green=green
  local probe=assert(s.create_entity{name='constant-combinator',position={9,0},force='player'})
  put(probe,{}); wire(probe,io,'green','output'); wire(probe,io,'red','output'); f().probe=probe
  guest(c,[[peripheral.find('logic_handler','red').setOutput({{signal={type='virtual',name='signal-A'},count=7}})]])
  local power=assert(s.create_entity{name='electric-energy-interface',position={0,5},force='player'})
  power.power_production=1000000; power.power_usage=0
  f().power=power; f().pole=assert(s.create_entity{name='substation',position={5,5},force='player'})
  report('native-real-wire-input-output-fixture-armed')
  shared_sampler_failure()
end
local function snapshot()
  local c=registry.computer(f().c); local io=registry.record(f().io); local root=registry.get()
  return {state=c.state,run=c.run_id,source=c.active.source,subscriptions=c.subscriptions,queue=c.queue,bank=io.output_bank,owner=io.output_owner,
    ledger=root.ledger.total,tick=root.ledger.tick,maintenance=root.scheduler.maintenance_spent,starts=c.state.starts,unit=io.body.unit_number,
    machine=root.ledger.machines[c.id],work=root.ledger.machines[c.id].work,compile=root.ledger.machines[c.id].compile,allocations=root.ledger.machines[c.id].allocations}
end
local function unchanged()
  verify_faults()
  local a,b=f().snapshot,snapshot()
  for _,k in ipairs({'state','run','source','subscriptions','queue','bank','owner','ledger','tick','maintenance','starts','unit','machine','work','compile','allocations'}) do assert(a[k]==b[k],'cold changed '..k) end
end
function M.on_load() loaded=true; if f().phase=='frozen' then unchanged(); log('TC_COLD_ON_LOAD_UNCHANGED') end end
function M.on_tick(event)
  local c=registry.computer(f().c); local io=registry.record(f().io); local s=game.surfaces[1]
  if f().phase=='frozen' then
    if not loaded then return end
    unchanged(); loaded=false; f().phase='cold-resume'; f().resume=event.tick
    put(f().red,{{signal=signal(),count=120}})
    -- Keep stock fixture machinery frozen until the cold controller reacts.
    f().inserter.active=false
  elseif f().phase=='inputs' then loaded=false end
  if f().phase=='done' then return end
  scheduler.tick(event.tick)
  if f().phase=='inputs' and event.tick-f().started>=5 then
    guest(c,[[local io=peripheral.find('logic_handler','red')
      assert(io.readSignal('red',{type='item',name='iron-plate'})==2147483647)
      assert(io.readSignal('green',{type='item',name='iron-plate'})==1)
      assert(io.readSignal('green',{type='fluid',name='water'})==0)
      assert(io.readSignals('red')[1].count==2147483647)
      assert(io.readSignals('green')[1].count==1)
      for _,bad in ipairs({'both','blue',false}) do
        local ok,e=pcall(io.readSignals,bad); assert(not ok and e.code=='E_ARGUMENT')
        ok,e=pcall(io.readSignal,bad,{type='item',name='iron-plate'}); assert(not ok and e.code=='E_ARGUMENT')
        ok,e=pcall(io.subscribe,{input=bad},'changed'); assert(not ok and e.code=='E_ARGUMENT')
      end
      local ok,e=pcall(io.readSignals); assert(not ok and e.code=='E_ARGUMENT')
      ok,e=pcall(io.readSignal,nil,{type='item',name='iron-plate'}); assert(not ok and e.code=='E_ARGUMENT')
      ok,e=pcall(io.subscribe,{},'changed'); assert(not ok and e.code=='E_ARGUMENT')
      local s=io.getInputStatus(); assert(s.red_connected and s.green_connected)]])
    assert(f().probe.get_signal({type='virtual',name='signal-A',quality='normal'},defines.wire_connector_id.circuit_green)==7)
    assert(io.children.output.get_signal({type='virtual',name='signal-A',quality='normal'},defines.wire_connector_id.circuit_red)==7)
    if f().has_quality then
      guest(c,[[local io=peripheral.find('logic_handler','red')
        assert(io.readSignal('green',{type='item',name='iron-plate',quality='uncommon'})==3)
        assert(#io.readSignals('green')==2)
        io.setOutput({{signal={type='item',name='iron-plate',quality='normal'},count=2},{signal={type='item',name='iron-plate',quality='uncommon'},count=3}})
        assert(#io.getOutput()==2 and io.getOutput()[2].signal.quality=='uncommon')]])
      report('expansion-quality-identities-remain-distinct-in-native-reads-and-output')
    end
    report('native-red-green-isolation-signed32-boundaries-selector-refusals-and-mirrored-propagation')
    put(f().red,{{signal=signal(),count=5}}); put(f().green,{})
    f().phase='subscribe'; f().since=event.tick
  elseif f().phase=='subscribe' and event.tick-f().since>=3 then
    guest(c,[[local io=peripheral.find('logic_handler','red')
      local id=io.subscribe({input='red',signals={{type='item',name='iron-plate'}},initial=true},'changed')
      computer.setState('sub',id)
      local ok,e=pcall(io.subscribe,{input='red',signals={}},'changed'); assert(not ok and e.code=='E_ARGUMENT')
      ok,e=pcall(io.subscribe,{input='red',initial=1},'changed'); assert(not ok and e.code=='E_ARGUMENT')]])
    logic.sample(event.tick+1,nop)
    local sub=c.subscriptions[c.state.sub]; local queued=c.queue[#c.queue]
    assert(queued.event.initial and queued.event.previous[1]==nil and queued.event.current[1].count==5)
    assert(sub.details.previous[1].count==5,'baseline did not advance on admission')
    local n=#c.queue; logic.sample(event.tick+2,nop); assert(#c.queue==n,'unchanged input emitted')
    guest(c,[[local io=peripheral.find('logic_handler','red'); assert(io.unsubscribe(computer.getState('sub'))); assert(not io.unsubscribe(computer.getState('sub')))]])
    assert(#c.queue==0)
    report('initial-filter-queue-admission-baseline-unchanged-and-unsubscribe')
    -- Actual production authoring actions, with an explicitly mocked player.
    runtime.stop(c.id); assert(connector(c,'red').disconnect_from(connector(io,'red')))
    local p=players.player(7001,c.body); local real_game=game
    local ok,err=pcall(function()
      game={tick=event.tick,get_player=function(index) if index==p.index then return p end end,connected_players={p}}
      assert(editor.open(p,c.id)); local frame=p.gui.screen[editor.frame_name]
      frame.content.editor.source.text=source
      editor.on_text{player_index=p.index,element=frame.content.editor.source,tick=event.tick}
      editor.on_click{player_index=p.index,element=frame.content.editor.actions.save,tick=event.tick}
      assert(c.saved_source==source and c.status=='stopped')
      editor.on_click{player_index=p.index,element=frame.content.editor.actions.activate,tick=event.tick}
      assert(c.status=='running' and c.active.source==source)
    end)
    game=real_game; if not ok then error(err,0) end
    f().phase='controller'; f().since=event.tick
    -- Powered inserter between two real chests, enable controlled by OUTPUT.
    local x=15
    f().stock=assert(s.create_entity{name='steel-chest',position={x,0},force='player'})
    f().dest=assert(s.create_entity{name='steel-chest',position={x,2},force='player'})
    f().stock.insert{name='iron-plate',count=100}
    f().inserter=assert(s.create_entity{name='inserter',position={x,1},direction=defines.direction.north,force='player'})
    f().machine_pole=assert(s.create_entity{name='substation',position={12,5},force='player'})
    local cb=f().inserter.get_or_create_control_behavior(); cb.circuit_enable_disable=true
    cb.circuit_condition={first_signal={type='virtual',name='signal-A',quality='normal'},comparator='>',constant=0}
    wire(f().inserter,io,'red','output')
    report('saved-source-through-production-editor-handlers-and-native-inserter-armed')
  elseif f().phase=='controller' then
    assert(c.status=='running',c.diagnostic and c.diagnostic.message)
    assert(event.tick-f().since<300,'controller transfer deadline: '..serpent.line({state=c.state,bank=io.output_bank,owner=io.output_owner,energy=f().inserter.energy,status=f().inserter.status,pickup=f().inserter.pickup_position,drop=f().inserter.drop_position,stock=f().stock.position,dest=f().dest.position}))
    if f().dest.get_item_count('iron-plate')>=2 then
      assert(c.state.starts==1 and c.state.stock==5 and io.output_owner.computer_id==c.id)
      report('actual-powered-inserter-transfer-from-saved-controller')
      -- Save retained controller/output/subscription identities with pending input.
      f().inserter.active=false; f().phase='frozen'; f().snapshot=snapshot()
      log('TC_CONTRACT_TOTAL '..f().groups)
      game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
    end
  elseif f().phase=='cold-resume' then
    assert(c.status=='running',c.diagnostic and c.diagnostic.message)
    assert(event.tick-f().resume<120,'cold reaction deadline')
    if c.state.stock==120 and not io.output_bank[1] then
      assert(c.state.starts==1 and c.run_id==f().snapshot.run)
      f().inserter.active=true; f().phase='cessation'; f().since=event.tick; f().count=f().dest.get_item_count('iron-plate')
      report('cold-owned-output-subscription-identity-and-no-startup-replay')
      verify_faults(); report('cold-shared-sampler-fault-identities-retained')
    end
  elseif f().phase=='cessation' and event.tick-f().since>=90 then
    assert(f().dest.get_item_count('iron-plate')==f().count,'disabled inserter still transfers')
    report('actual-native-circuit-cessation')
    -- Subscriptions survive power but obsolete samples do not.
    local sub; for _,v in pairs(c.subscriptions) do if v.event_name=='signal_changed' then sub=v end end
    assert(sub); local previous=sub.details.previous
    runtime.set_power(c.id,false,event.tick,nop); assert(not io.output_owner)
    assert(c.subscriptions[sub.id]==sub and sub.details.previous==previous and sub.details.resync)
    runtime.set_power(c.id,true,event.tick,nop); logic.sample(event.tick,nop)
    assert(c.queue[#c.queue].event.resync and c.queue[#c.queue].event.previous[1].count==120)
    report('computer-outage-retained-admitted-baseline-and-current-resync')
    put(f().red,{}); f().phase='disappearance'; f().since=event.tick
  elseif f().phase=='disappearance' then
    assert(event.tick-f().since<30,'disappearance deadline')
    if c.state.stock==0 then
      local change=c.state.last_changes[1]
      assert(change.previous==120 and change.current==0 and c.state.input_connected.red)
      report('native-filtered-disappearance-includes-zero')
      assert(f().red.get_wire_connector(defines.wire_connector_id.circuit_red,false).disconnect_from(connector(io,'red','input')))
      f().phase='disconnect'; f().since=event.tick
    end
  elseif f().phase=='disconnect' then
    assert(event.tick-f().since<30,'connectivity deadline')
    if c.state.input_connected.red==false then
      assert(#c.state.last_changes==0 and c.state.stock==0)
      report('native-empty-input-connectivity-only-event')
      local sub; for _,v in pairs(c.subscriptions) do if v.event_name=='signal_changed' then sub=v end end
      io.body.energy=0; lifecycle.sample_power(io,event.tick,nop); logic.sample(event.tick,nop)
      assert(c.subscriptions[sub.id]==sub and sub.details.resync and not io.output_owner)
      io.body.energy=100000; lifecycle.sample_power(io,event.tick,nop); logic.sample(event.tick,nop)
      assert(c.queue[#c.queue].event.resync and c.queue[#c.queue].event.current[1]==nil)
      report('handler-power-loss-clears-bank-and-retains-resync-subscription')
      f().phase='cleanup'
    end
  elseif f().phase=='cleanup' then
    -- Faulted source cannot suppress output cleanup; newer ownership is protected.
    guest(c,[[peripheral.find('logic_handler','red').setOutput({{signal={type='virtual',name='signal-A'},count=1}})]])
    runtime.fault(c,{code='E_PROGRAM',message='focused fault'},event.tick); assert(not io.output_owner)
    c.status='running'; c.run_id=c.id..'/cleanup'
    guest(c,[[peripheral.find('logic_handler','red').setOutput({{signal={type='virtual',name='signal-A'},count=1}})]])
    assert(connector(c,'red').disconnect_from(connector(registry.record(f().relay),'red')))
    peripheral.check_outputs(event.tick,nop); assert(not io.output_owner)
    report('source-independent-fault-and-physical-cable-loss-cleanup')
    connect(c,registry.record(f().relay),'red')
    c.status='running'; c.run_id=c.id..'/queue-pressure'
    guest(c,[[local io=peripheral.find('logic_handler','red'); io.setOutput({{signal={type='virtual',name='signal-A'},count=1}})
      io.subscribe({input='red',initial=true},'changed')]])
    for i=1,limits.event_queue_entries do assert(runtime.enqueue(c,'changed',{name='fixture_queue_pressure'},event.tick)) end
    local owner,bank,first=io.output_owner,io.output_bank,c.queue[1]
    logic.sample(event.tick,nop)
    assert(c.status=='running' and io.output_owner==owner and io.output_bank==bank and c.queue[1]==first)
    assert(c.dropped_events.total==1 and c.dropped_events.last_kind=='signal_changed')
    local sub; for _,value in pairs(c.subscriptions) do if value.event_name=='signal_changed' then sub=value end end
    assert(sub and sub.details.resync)
    local removed=table.remove(c.queue,1); c.queue_bytes=c.queue_bytes-removed.bytes
    logic.sample(event.tick,nop)
    assert(c.queue[#c.queue].event.resync and not sub.details.resync and c.dropped_events.total==1)
    assert(io.output_owner==owner and io.output_bank==bank)
    report('full-notification-queue-preserves-output-and-resynchronizes-next-delivery')
    assert(runtime.retire(c,'stopped','fixture-next-case'))
    c.status='running'; c.run_id=c.id..'/maintenance-pressure'
    guest(c,[[local io=peripheral.find('logic_handler','red'); io.setOutput({{signal={type='virtual',name='signal-A'},count=1}})
      io.subscribe({input='red',initial=true},'changed')]])
    local root=registry.get(); root.scheduler.maintenance_tick=event.tick; root.scheduler.maintenance_spent=limits.maintenance_work_per_tick
    logic.sample(event.tick,scheduler.maintenance(root,event.tick))
    assert(c.status=='faulted' and c.diagnostic.code=='E_BUSY' and not io.output_owner)
    report('exhausted-sampling-admission-is-visible-fail-closed')
    f().phase='done'; log('TC_COLD_OK')
  end
end
return M
