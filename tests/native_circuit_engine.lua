-- Native inventories through the real compiler/provider; no raised budgets.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local scheduler=require('scripts.scheduler')
local logic=require('scripts.services.logic')
local defs=require('scripts.device-definitions')
local inspector=require('scripts.ui.peripheral-inspector')
local inspector_model=require('scripts.ui.peripheral-inspector-model')
local players=require('tests.editor_contract')
local M={}
local loaded=false
local function f() return storage.tc_native_circuit end
local function put(entity,entries)
  local cb=entity.get_or_create_control_behavior()
  for i=cb.sections_count,1,-1 do cb.remove_section(i) end
  local section=cb.add_section(); local filters={}
  for i,e in ipairs(entries) do
    local s=e.signal
    filters[i]={index=i,value={type=s.type,name=s.name,quality=s.quality or 'normal'},min=e.count}
  end
  section.filters=filters; cb.enabled=true
end
local function inventory(n)
  local result={}
  for i=1,n do result[i]={signal={type='virtual',name=string.format('tc-native-%04d',i),quality='normal'},count=i%2==0 and i or -i} end
  return result
end
local function probe(body,keep_run)
  local c=registry.computer(f().computer)
  local source='function start(e) local p=peripheral.find("logic_handler","red"); '..body..' end; function changed(e) end'
  local context=admission.context(admission.new(),c.id,game.tick)
  local plan,problem=compiler.compile(source,context); assert(plan,problem and serpent.line(problem))
  if not keep_run then
    c.status='running'; c.run_id=c.id..'/native-probe'
    c.active={source=source,revision=1,api_version=1,compiler_version=limits.compiler_version,storage_version=1,handlers=plan.handlers}
  end
  local ok,e=compiler.run(plan,'start',{name='start'},function(g) return runtime.services(c,game.tick,g) end,context)
  assert(ok,e and serpent.line(e))
  return context.machine
end
local function check_input(wire,n)
  local io=registry.record(f().logic)
  local connector=lifecycle.connector(io,'input',wire)
  local raw=connector.owner.get_signals(connector.wire_connector_id) or {}
  assert(#raw==n,'native source inventory missing: '..#raw..' expected '..n)
  local fingerprint=0
  for i,e in ipairs(raw) do fingerprint=fingerprint+i*e.count end
  local tail=raw[n]
  local text=string.format([[local a=p.readSignals(%q)
    assert(#a==%d and rawlen(a)==%d)
    local count,sum=0,0
    for i,e in ipairs(a) do count=count+1; sum=sum+i*e.count end
    assert(count==%d and sum==%d)
    local tail=a[%d]
    assert(tail.count==%d and tail.signal.name==%q and tail.signal.type==%s and tail.signal.quality==%s)
    tail.count=0; tail.signal.name='guest mutation'
    local b=peripheral.call(peripheral.getName(p),'red','readSignals',%q)
    assert(#b==%d and b[%d].count==%d and b[%d].signal.name==%q)
    assert(not rawequal(a,b) and not rawequal(a[%d].signal,b[%d].signal))
  ]],wire,n,n,n,fingerprint,n,tail.count,tail.signal.name,
    tail.signal.type and string.format('%q',tail.signal.type) or 'nil',
    tail.signal.quality and string.format('%q',tail.signal.quality) or 'nil',
    wire,n,n,tail.count,n,tail.signal.name,n,n)
  local measured=probe(text)
  local after=connector.owner.get_signals(connector.wire_connector_id)
  assert(after[n].count==tail.count and after[n].signal.name==tail.signal.name)
  log('TC_NATIVE_READ '..serpent.line{wire=wire,count=n,work=measured.work,allocations=measured.allocations})
end
local event_source=[[function start(e)
  computer.setState('boots',(computer.getState('boots') or 0)+1)
  local p=peripheral.find('logic_handler','red')
  local a=p.readSignals('red'); p.setOutput(a)
  for i,s in ipairs(a) do a[i]=s.signal end
  computer.setState('sub',p.subscribe({input='red',signals=a,initial=true},'changed'))
  p.subscribe({input='red',initial=true},'changed')
  a[1100].name='mutated request'
end

function changed(e)
  assert(#e.current==1100 and #e.changes==1100 and #e.previous==0 and e.initial)
  local n=0
  for _,s in ipairs(e.current) do assert(s.signal.name~='mutated request' and s.count~=0); n=n+1 end
  assert(n==1100)
  e.current[1100].count=0; e.current[1100].signal.name='mutated event'
  computer.setState('events',(computer.getState('events') or 0)+1)
end]]
local function check_inspector()
  local io=registry.record(f().logic); local real=game
  local root=registry.get(); local saved_scheduler,saved_ledger=root.scheduler,root.ledger
  root.scheduler={last_tick=-1}; root.ledger=admission.new() -- Isolate the table-GUI clock, not production credits.
  local p=players.player(9201,io.body); local tick=math.ceil((game.tick+15)/15)*15
  game=setmetatable({tick=tick,connected_players={p},get_player=function() return p end},{__index=real})
  local ok,e=pcall(function()
    local frame=assert(inspector.open(p,io.id)); local session=inspector_model.session(p.index)
    local function refresh()
      game.tick=tick; inspector.tick(tick); tick=tick+15
    end
    for _=1,4 do refresh() end
    assert(session.snapshot and not session.pending and not session.redraw)
    local d=session.snapshot.details; local regions=frame.details.logic_regions
    local native=logic.inspect(io,real.tick,function() end)
    for _,wire in ipairs({'red','green','output'}) do
      local grid=(wire=='output' and regions.outputs or regions.inputs)[wire..'_slots'].signal_grid
      assert(#grid.children==#native[wire] and #d[wire]==#native[wire])
      for i,entry in ipairs(native[wire]) do
        local s=entry.signal; local kind=s.type or 'item'; local namespace=kind=='virtual' and 'virtual-signal' or kind
        local slot=assert(grid['signal_'..i])
        assert(slot.number==entry.count and slot.tags.identity==namespace..'/'..s.name..'/'..(s.quality or 'normal'))
      end
    end
    local tray=regions.inputs.red_slots; tray.vertical_scroll_position=600
    inspector.on_click{player_index=p.index,element=frame.identity.select_name}
    local writes=frame.identity.api_name.text_writes
    for _=1,4 do refresh() end
    assert(tray==frame.details.logic_regions.inputs.red_slots and tray.vertical_scroll_position==600)
    assert(frame.identity.api_name.text_writes==writes and frame.identity.api_name.focused)
    inspector.close(p); assert(not frame.valid and not inspector_model.session(p.index))
  end)
  inspector.close(p); game=real; root.scheduler=saved_scheduler; root.ledger=saved_ledger; assert(ok,e)
  log('TC_CONTRACT native-inspector-complete-unsorted-grid-counts-identities-and-retained-widgets')
end
function M.run()
  local surface=game.surfaces[1]
  local function build(kind,x,y)
    return assert(lifecycle.build(assert(surface.create_entity{name=defs.devices[kind].name,position={x,y},force='player'})))
  end
  local c=build('computer',0,0); local io=build('logic',4,0)
  assert(lifecycle.connector(c,'network','red').connect_to(lifecycle.connector(io,'network','red')))
  local red=assert(surface.create_entity{name='constant-combinator',position={0,-3},force='player'})
  local green=assert(surface.create_entity{name='constant-combinator',position={4,-3},force='player'})
  for color,entity in pairs({red=red,green=green}) do
    assert(entity.get_wire_connector(defines.wire_connector_id['circuit_'..color],true).connect_to(lifecycle.connector(io,'input',color)))
  end
  assert(surface.create_entity{name='substation',position={3,5},force='player'})
  local supply=assert(surface.create_entity{name='electric-energy-interface',position={7,5},force='player'})
  supply.power_production=100000000; supply.power_usage=0
  storage.tc_native_circuit={computer=c.id,logic=io.id,red=red,green=green,phase='reads',since=game.tick,step=1}
  put(red,inventory(64)); put(green,{{signal={name='iron-plate',quality='normal'},count=-27}})
end
function M.on_load() loaded=f().phase=='frozen' end
function M.on_configuration_changed() end
function M.on_tick(event)
  local x=f()
  if x.phase=='done' then return end
  if x.phase=='frozen' then
    if not loaded then return end
    loaded=false
    local c=registry.computer(x.computer); local io=registry.record(x.logic)
    assert(c.queue==x.queue and c.subscriptions==x.subscriptions and c.queue_bytes==x.bytes)
    assert(io.output_owner==x.owner and c.run_id==x.run and c.state.boots==1 and not c.state.events)
    assert(#c.queue==2 and #c.queue[2].event.current==1100)
    put(x.green,{{signal={name='iron-plate'},count=91}})
    x.phase='delivery'; x.since=event.tick
  elseif x.phase=='events' then
    local c=registry.computer(x.computer)
    if c.state.boots==1 then
      logic.sample(event.tick,scheduler.maintenance(registry.get(),event.tick))
      assert(#c.queue==2 and c.queue_bytes<4096)
      for _,sub in pairs(c.subscriptions) do
        assert(#sub.details.previous==1100)
        if sub.details.signals then assert(#sub.details.signals==1100 and sub.details.signals[1100].name~='mutated request') end
        assert(sub.details.previous~=c.queue[1].event.current and sub.details.previous[1100].signal~=c.queue[1].event.current[1100].signal)
      end
      assert(c.queue[1].event.current[1100].signal~=c.queue[2].event.current[1100].signal)
      c.queue[1].circuit=nil -- Emulate the older host-only queue record.
      registry.get().logic_observers=nil
      registry.initialize() -- Synchronized migration, never an on_load rebuild.
      assert(c.queue[1].circuit==true and #registry.get().logic_observers.order==2)
      for _,entry in ipairs(c.queue[1].event.current) do entry.signal.quality='normal' end
      for _,sub in pairs(c.subscriptions) do
        for _,entry in ipairs(sub.details.previous) do entry.signal.quality='normal' end
      end
      local io=registry.record(x.logic)
      x.queue=c.queue; x.subscriptions=c.subscriptions; x.bytes=c.queue_bytes; x.owner=io.output_owner; x.run=c.run_id
      io.logic_sample={tick=event.tick,red={}}; io.output_bank={{signal={name='iron-plate'},count=-1}}
      x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
    end
  end
  scheduler.tick(event.tick)
  assert(event.tick-x.since<60,'native circuit fixture deadline')
  if event.tick-x.since<4 then return end
  if x.phase=='reads' then
    local sizes={64,65,150,1100}
    check_input('red',sizes[x.step]); check_input('green',1)
    probe(string.format([[local a=p.readSignals('red'); p.setOutput(a)
      local b=p.getOutput(); assert(#b==%d and b[%d].count==a[%d].count)
      b[%d].count=0; assert(p.getOutput()[%d].count==a[%d].count)
      local ok,e=pcall(p.setOutput,{{signal={name='iron-plate'},count=1},{signal={type='item',name='iron-plate',quality='normal'},count=2}})
      assert(not ok and e.code=='E_ARGUMENT' and #p.getOutput()==%d)
      ok,e=pcall(p.setOutput,{{signal={name='iron-plate'},count=2147483648}})
      assert(not ok and e.code=='E_RANGE' and #p.getOutput()==%d)
    ]],sizes[x.step],sizes[x.step],sizes[x.step],sizes[x.step],sizes[x.step],sizes[x.step],sizes[x.step],sizes[x.step]))
    if sizes[x.step]==1100 then check_inspector() end
    log('TC_CONTRACT native-compiled-read-'..sizes[x.step])
    if x.step<#sizes then
      x.step=x.step+1; put(x.red,inventory(sizes[x.step])); x.since=event.tick
    else
      probe([[local a=p.readSignals('red')
        for i,s in ipairs(a) do a[i]=s.signal end
        assert(#a==1100 and a[1100].name~=nil)
        a[1100].name='mutated'; a[1]=nil
        local ok,e=pcall(computer.setState,'native',a); assert(not ok and (e.code=='E_LIMIT' or e.code=='E_ARGUMENT'))
        ok,e=pcall(rawset,a,1101,{}); assert(not ok and e.code=='E_LIMIT')
      ]])
      probe([[p.setOutput({{signal={name='iron-plate'},count=17}})
        local a=p.getOutput(); assert(#a==1 and a[1].count==17 and (a[1].signal.type or 'item')=='item')
        p.setOutput(a); assert(p.getOutput()[1].count==17)
        local ok,e=pcall(p.setOutput,{{signal={type=false,name='iron-plate'},count=1}})
        assert(not ok and e.code=='E_ARGUMENT' and p.getOutput()[1].count==17)
        a[1].signal.extra=function() end; ok,e=pcall(p.setOutput,a); assert(not ok and e.code=='E_ARGUMENT')
        a=p.getOutput(); a[1].signal=a; ok,e=pcall(p.setOutput,a); assert(not ok and e.code=='E_ARGUMENT')
        a=p.readSignals('red')
        ok,e=pcall(computer.after,1,'changed',{name='signal_changed',current=a})
        assert(not ok and (e.code=='E_LIMIT' or e.code=='E_ARGUMENT'))
      ]])
      local entries={{signal={type='virtual',name='tc-native-'..string.rep('long-name-',12),quality='normal'},count=42}}
      for _,kind in ipairs({'item','fluid','virtual','recipe','entity','space-location','asteroid-chunk','quality'}) do
        local catalogue=prototypes[kind=='virtual' and 'virtual_signal' or kind:gsub('-','_')]
        local name
        for key in pairs(catalogue) do
          if kind~='virtual' or key=='signal-A' then name=key; break end
        end
        if name then entries[#entries+1]={signal={type=kind,name=name,quality='normal'},count=#entries+10} end
      end
      put(x.red,entries); x.mixed_count=#entries; x.phase='mixed'; x.since=event.tick
    end
  elseif x.phase=='mixed' then
    check_input('red',x.mixed_count)
    probe([[p.setOutput(p.readSignals('red'))]])
    check_inspector()
    local original=lifecycle.connector; local calls=0
    lifecycle.connector=function(rec,role,wire)
      local c=original(rec,role,wire)
      if rec.id==x.logic and role=='input' then
        return {real_connection_count=c.real_connection_count,wire_connector_id=c.wire_connector_id,owner={get_signals=function(id)
          calls=calls+1; return c.owner.get_signals(id)
        end}}
      end
      return c
    end
    local ok,e=pcall(probe,[[p.readSignals('red'); p.readSignals('red'); p.readSignals('green')]])
    lifecycle.connector=original; assert(ok,e); assert(calls==3,'reads reused an observation')
    log('TC_CONTRACT native-categories-long-name-defaults-fresh-gets-and-mutation-isolation')
    runtime.stop(x.computer); put(x.red,inventory(1100)); x.phase='prepare-events'; x.since=event.tick
  elseif x.phase=='prepare-events' then
    local c=registry.computer(x.computer)
    runtime.save(c.id,event_source,c.saved_revision); assert(runtime.activate(c.id,event.tick))
    x.phase='events'; x.since=event.tick
  elseif x.phase=='delivery' then
    local c=registry.computer(x.computer); local io=registry.record(x.logic)
    assert(c.status=='running',c.diagnostic and serpent.line(c.diagnostic))
    assert(not io.output_bank and not io.logic_sample)
    for _,sub in pairs(c.subscriptions) do assert(sub.details.previous[1100].signal.name~='mutated event') end
    if c.state.events==2 then
      assert(#c.queue==0 and c.queue_bytes==0 and c.state.boots==1 and io.output_owner==x.owner)
      log('TC_CONTRACT native-large-filter-isolation-queued-delivery-and-cold-no-replay')
      probe([[assert(p,'post-load peripheral missing'); local a=p.readSignals('green')
        assert(#a==1,'post-load inventory missing'); assert(a[1].count==91)]],true)
      for _,sub in pairs(c.subscriptions) do
        local a=sub.details.previous
        for i=1,math.floor(#a/2) do a[i],a[#a-i+1]=a[#a-i+1],a[i] end
      end
      local spend=scheduler.maintenance(registry.get(),event.tick)
      logic.sample(event.tick,spend)
      assert(#c.queue==0 and c.queue_bytes==0,'reordered/default-expanded baseline produced a false delta')
      for _,sub in pairs(c.subscriptions) do sub.details.initial=true end
      logic.sample(event.tick,spend); assert(#c.queue==2)
      c.powered=false; logic.sample(event.tick,spend)
      assert(#c.queue==2 and not c.queue[1].event.resync,'obsolete electrical flag affected sampling')
      c.powered=true; c.body.direction=4; logic.sample(event.tick,spend)
      assert(#c.queue==0 and c.queue_bytes==0)
      c.body.direction=0; logic.sample(event.tick,spend)
      assert(#c.queue==2 and c.queue[1].event.resync and #c.queue[1].event.previous==1100)
      probe([[assert(p.unsubscribe(computer.getState('sub')))]],true)
      assert(#c.queue==1 and c.queue_bytes==c.queue[1].bytes)
      log('TC_CONTRACT native-reordered-defaulted-physical-resync-power-independent-unsubscribe-and-fresh-post-load-read')
      while #c.queue<limits.event_queue_entries do
        assert(runtime.enqueue(c,'changed',{name='backlog'},event.tick))
      end
      for _,sub in pairs(c.subscriptions) do sub.details.initial=true end
      logic.sample(event.tick,spend)
      assert(c.status=='faulted' and c.diagnostic.code=='E_CAPACITY' and #c.queue==0 and c.queue_bytes==0)
      assert(not io.output_owner and #logic.inspect_output(io,function() end)==0)
      local observers=registry.get().logic_observers
      assert(#observers.order==0 and #observers.input_order==0 and next(observers.inputs)==nil and next(observers.computers)==nil,'fault retained a signal observer')
      log('TC_CONTRACT native-genuine-queue-entry-overflow-clears-owner-and-byte-counter')
      x.phase='sample-pressure'; x.since=event.tick
    end
  elseif x.phase=='sample-pressure' then
    local c=registry.computer(x.computer); local events=c.state.events
    runtime.save(c.id,'function changed(e) error("refused observation dispatched") end',c.saved_revision)
    assert(runtime.activate(c.id,event.tick))
    probe([[p.subscribe({input='red',initial=true},'changed')]],true)
    local root=registry.get(); local s=root.scheduler
    local spend=scheduler.maintenance(root,event.tick)
    local guest=root.ledger.tick==event.tick and root.ledger.total or 0
    local remaining=math.min(limits.maintenance_work_per_tick-s.render_reserved_work,limits.host_work_per_tick-guest)-s.maintenance_spent
    assert(remaining>=0); spend(remaining)
    logic.sample(event.tick,spend)
    assert(c.status=='faulted' and c.diagnostic.code=='E_BUSY' and #c.queue==0 and c.state.events==events)
    assert(#root.logic_observers.order==0 and #root.logic_observers.input_order==0)
    log('TC_CONTRACT native-exhausted-real-maintenance-explicit-sampling-fault-no-slow-poll')
    x.phase='done'; log('TC_COLD_OK native-direct-circuits')
  end
end
return M
