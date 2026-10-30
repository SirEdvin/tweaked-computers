-- Actual wired circuits and scheduler ticks in the owning production context.
-- Compiled probe callbacks below use explicit isolated ledgers for API semantics.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local logic=require('scripts.services.logic')
local peripheral=require('scripts.services.peripheral')
local editor=require('scripts.ui.editor')
local players=require('tests.editor_contract')
local defs=require('scripts.device-definitions')
local M={}
local loaded=false
local player,gui
local function with_player(fn)
  local original=game
  game=setmetatable({get_player=function(i) if player and i==player.index then return player end; return original.get_player(i) end},
    {__index=function(_,k) return original[k] end})
  local ok,result=pcall(fn); game=original
  if not ok then error(result,0) end
  return result
end
local function f() return storage.tc_recipe_signals end
local function recipe(quality) return {type='recipe',name='iron-plate',quality=quality or 'normal'} end
local function put(entity,entries)
  local cb=entity.get_or_create_control_behavior()
  for i=cb.sections_count,1,-1 do cb.remove_section(i) end
  local section=cb.add_section(); local filters={}
  for i,e in ipairs(entries) do
    filters[i]={index=i,value={type=e.signal.type,name=e.signal.name,quality=e.signal.quality or 'normal'},min=e.count}
  end
  section.filters=filters; cb.enabled=true
end
local source=[[function start(e)
  computer.setState('boots',(computer.getState('boots') or 0)+1)
  local p=peripheral.find('logic_handler','red')
  local id=p.subscribe({input='red',signals={{type='recipe',name='iron-plate'}},initial=true},'changed')
  computer.setState('subscription',id)
  p.setOutput({{signal={type='recipe',name='iron-plate'},count=7},{signal={type='item',name='iron-plate'},count=3}})
end

function changed(e)
  computer.setState('events',(computer.getState('events') or 0)+1)
  computer.setState('last',e)
end]]
local function probe(c,text)
  local ctx=admission.context(admission.new(),c.id,0)
  local plan,problem=compiler.compile('function start(e) local p=peripheral.find("logic_handler","red"); '..text..' end',ctx)
  assert(plan,problem and problem.message)
  local ok,err=compiler.run(plan,'start',{name='start'},function(g) return runtime.services(c,game.tick,g) end,ctx)
  assert(ok,err and serpent.line(err))
end
local function snapshot()
  local x=f(); local c=registry.computer(x.c); local io=registry.record(x.io)
  local sub=c.subscriptions[c.state.subscription]; local root=registry.get()
  return {state=c.state,run=c.run_id,active=c.active,queue=c.queue,subscriptions=c.subscriptions,observers=root.logic_observers,
    filter=sub.details.signals,baseline=sub.details.previous,bank=io.output_bank,owner=io.output_owner,
    legacy=x.legacy and registry.computer(x.legacy).subscriptions,
    legacy_queue=x.legacy and registry.computer(x.legacy).queue,
    ledger=root.ledger,total=root.ledger.total,tick=root.ledger.tick,machine=root.ledger.machines[c.id],
    work=root.ledger.machines[c.id].work,events=c.state.events,shell=c.shell,values=c.shell and c.shell.values}
end
local function observation_contract(c,io)
  local root=registry.get(); local s=root.logic_observers
  assert(#s.order==1 and #s.input_order==1 and s.order[1].sub==c.subscriptions[c.state.subscription])
  local body=assert(c.body.surface.create_entity{name=defs.devices.computer.entity_name,position={0,6},force='player'})
  local peer=assert(lifecycle.build(body))
  assert(lifecycle.connector(peer,'network','red').connect_to(lifecycle.connector(io,'network','red')))
  runtime.save(peer.id,'function changed(e) end',0); assert(runtime.activate(peer.id,game.tick))
  probe(c,[[computer.setState('extra_red',p.subscribe({input='red',signals={{type='item',name='iron-plate'}},initial=true},'changed'))
    computer.setState('extra_green',p.subscribe({input='green',initial=true},'changed'))]])
  probe(peer,[[computer.setState('shared',p.subscribe({input='red',initial=true},'changed'))]])
  assert(#s.order==4 and #s.input_order==2)
  local inspect=logic.inspect_input; local calls={red=0,green=0}
  logic.inspect_input=function(rec,color,...)
    assert(rec==io); calls[color]=calls[color]+1; return inspect(rec,color,...)
  end
  local ok,problem=pcall(logic.sample,game.tick,function() end)
  logic.inspect_input=inspect
  assert(ok,problem); assert(calls.red==1 and calls.green==1,'duplicate physical input observation')
  assert(#c.queue==2 and #peer.queue==1)
  assert(c.queue[1].event.input=='red' and #c.queue[1].event.current==1 and c.queue[1].event.current[1].signal.name=='iron-plate')
  assert(c.queue[2].event.input=='green' and c.queue[2].event.connected.green and c.queue[2].event.connected.red==nil)
  local shared=peer.queue[1].event.current
  c.queue[1].event.current[1].count=123456
  assert(shared[1].count~=123456 and c.subscriptions[c.state.extra_red].details.previous[1].count~=123456)
  local sequence=root.next_sequence; local order=#s.order; local queue=c.queue
  local refusal={code='E_BUDGET'}
  local charge=#s.order+#s.input_order+#c.queue*2+4
  local success,e=pcall(runtime.subscribe,c,'signal_changed','changed',c.subscriptions[c.state.extra_red].details,function(n)
    if n==charge then error(refusal,0) end
  end,true)
  assert(not success and e==refusal and root.next_sequence==sequence and #s.order==order and c.queue==queue,'refused membership consumed an ID or published state')
  success,e=pcall(runtime.unsubscribe,c,c.state.extra_red,function(n) if n==charge then error(refusal,0) end end)
  assert(not success and e==refusal and #s.order==order and c.queue==queue and #queue==2,'refused cancellation changed accepted work')
  probe(c,[[assert(computer.off(computer.getState('extra_red')))
    assert(p.unsubscribe(computer.getState('extra_green')))]])
  assert(#c.queue==0 and #s.order==2 and #s.input_order==1)
  runtime.stop(peer.id)
  assert(#peer.queue==0 and #s.order==1 and #s.input_order==1 and not s.computers[peer.id])
  assert(lifecycle.remove(peer.id,'fixture',true))
  assert(registry.initialize().logic_observers==s and #s.order==1)
  log('TC_CONTRACT logic-shared-watch-colors-filters-isolation-off-refusal-and-stop-retirement')
end
local function unchanged()
  local old,new=f().snapshot,snapshot()
  for k,v in pairs(old) do assert(new[k]==v,'recipe cold state changed: '..k) end
end
function M.run()
  log('TC_RECIPE_PROTOTYPES '..serpent.line{item=#prototypes.item,fluid=#prototypes.fluid,
    virtual=#prototypes.virtual_signal,recipe=#prototypes.recipe,quality=#prototypes.quality})
  local surface=game.surfaces[1]
  local function build(kind,x,y)
    return assert(lifecycle.build(assert(surface.create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})))
  end
  local c=build('computer',0,0); local io=build('logic',4,0)
  local legacy=build('computer',0,3)
  assert(lifecycle.connector(c,'network','red').connect_to(lifecycle.connector(io,'network','red')))
  local red=assert(surface.create_entity{name='constant-combinator',position={0,-3},force='player'})
  local green=assert(surface.create_entity{name='constant-combinator',position={4,-3},force='player'})
  put(red,{{signal=recipe(),count=12},{signal={type='recipe',name='copper-plate'},count=2147483647},
    {signal={type='item',name='iron-plate'},count=99},{signal={type='virtual',name='signal-A'},count=2}})
  local entries={{signal=recipe(),count=-5},{signal={type='recipe',name='copper-plate'},count=1},{signal={type='fluid',name='water'},count=3}}
  if script.active_mods.quality then entries[#entries+1]={signal=recipe('uncommon'),count=4} end
  put(green,entries)
  local overflow=assert(surface.create_entity{name='constant-combinator',position={0,-5},force='player'})
  put(overflow,{{signal={type='recipe',name='copper-plate'},count=1}})
  assert(overflow.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(lifecycle.connector(io,'input','red')))
  for color,entity in pairs({red=red,green=green}) do
    assert(entity.get_wire_connector(defines.wire_connector_id['circuit_'..color],true).connect_to(lifecycle.connector(io,'input',color)))
  end
  local output=assert(surface.create_entity{name='constant-combinator',position={4,4},force='player'})
  for _,color in ipairs({'red','green'}) do
    assert(output.get_wire_connector(defines.wire_connector_id['circuit_'..color],true).connect_to(lifecycle.connector(io,'output',color)))
  end
  assert(surface.create_entity{name='substation',position={3,6},force='player'})
  local supply=assert(surface.create_entity{name='electric-energy-interface',position={7,6},force='player'})
  supply.power_production=100000000; supply.power_usage=0
  storage.tc_recipe_signals={c=c.id,io=io.id,legacy=legacy.id,red=red,green=green,output=output,phase='power',start=game.tick}
end
function M.on_load()
  loaded=true
  if f().phase=='frozen' then unchanged(); log('TC_COLD_ON_LOAD_UNCHANGED recipe-bank-filter-ledger') end
end
function M.on_configuration_changed() end
function M.on_tick(event)
  local x=f(); local c=registry.computer(x.c); local io=registry.record(x.io)
  if x.phase=='done' then return end
  if x.phase=='frozen' then
    if not loaded then return end
    unchanged(); loaded=false
    assert(c.state.boots==1 and logic.inspect_output(io,function() end)[1].signal.type=='recipe')
    put(x.red,{{signal=recipe(),count=20},{signal={type='item',name='iron-plate'},count=99}})
    x.phase='resume'; x.resumed=event.tick
  else loaded=false end
  if x.hints then
    local port=io.children.input; local id=defines.wire_connector_id.circuit_green
    x.hints[#x.hints+1]={phase=x.phase,tick=event.tick,changed=port.get_signals_changed(id,x.last_hint_tick),
      connected=lifecycle.connector(io,'input','green').real_connection_count>0}
    x.last_hint_tick=event.tick
    if x.phase=='pulse-high' and port.get_signal({type='entity',name='inserter',quality='normal'},id)==42 then
      x.pulse_tick=event.tick; put(x.green,{{signal={type='entity',name='inserter'},count=1}})
    end
  end
  with_player(function() scheduler.tick(event.tick) end)
  if x.legacy_armed then
    local legacy=registry.computer(x.legacy)
    assert(legacy.status=='faulted' and legacy.diagnostic.code=='E_ARGUMENT')
    assert(not legacy.state.events and #legacy.queue==0,'legacy queued callback replayed')
  end
  assert(c.status~='faulted',c.diagnostic and c.diagnostic.message)
  assert(event.tick-x.start<240,'recipe scenario deadline '..x.phase)
  if x.phase=='power' and event.tick-x.start>=5 then
    assert(c.powered and io.powered)
    local root=registry.get(); local computers=root.computers; local visits=0
    root.computers=setmetatable({},{__index=function(_,id) visits=visits+1; return computers[id] end})
    local ok,problem=pcall(logic.sample,event.tick,function() end)
    root.computers=computers
    assert(ok,problem); assert(visits==0,'unsubscribed computers acquired signal discovery work: '..visits)
    log('TC_CONTRACT logic-unsubscribed-zero-registry-discovery')
    assert(runtime.save(c.id,source,c.saved_revision)); assert(runtime.activate(c.id,event.tick))
    x.phase='initial'
  elseif x.phase=='initial' and c.state.last then
    assert(c.status=='running',c.diagnostic and c.diagnostic.message)
    local e=c.state.last
    assert(e.initial and #e.current==1 and e.current[1].signal.type=='recipe' and e.current[1].count==12)
    assert(e.changes[1].previous==0 and e.changes[1].current==12)
    observation_contract(c,io)
    log('TC_RECIPE_NATIVE_INPUT '..serpent.line(io.children.input.get_signals(defines.wire_connector_id.circuit_red)))
    local sampled,bank,owner=io.logic_sample,logic.inspect_output(io,function() end),io.output_owner
    local observed=logic.inspect(io,event.tick,function() end)
    local identities={}
    for _,entry in ipairs(observed.red) do identities[(entry.signal.type or 'item')..'/'..entry.signal.name..'/'..(entry.signal.quality or 'normal')]=entry.count end
    assert(identities['item/iron-plate/normal']==99 and identities['recipe/iron-plate/normal']==12)
    assert(identities['recipe/copper-plate/normal']==-2147483648)
    assert(#observed.output==2 and observed.output[1].signal.type=='recipe' and observed.output[1].count==7)
    observed.output[1].signal.name='changed'; observed.output[1].count=0
    assert(io.logic_sample==sampled and serpent.line(logic.inspect_output(io,function() end))==serpent.line(bank) and io.output_owner==owner)
    assert(bank[1].signal.name=='iron-plate' and bank[1].count==7)
    probe(c,[[assert(p.readSignal('red',{type='recipe',name='iron-plate'})==12)
      assert(p.readSignal('green',{type='recipe',name='iron-plate'})==-5)
      assert(p.readSignal('red',{type='item',name='iron-plate'})==99)
      assert(p.readSignal('green',{type='item',name='iron-plate'})==0)
      assert(p.readSignal('red',{type='recipe',name='copper-plate'})==-2147483648)
      assert(p.readSignal('green',{type='recipe',name='copper-plate'})==1)
      assert(p.readSignal('red',{type='recipe',name='steel-plate'})==0)
      local kinds={}
      for _,wire in ipairs({'red','green'}) do
      local all=p.readSignals(wire)
      for _,s in ipairs(all) do
        local kind=s.signal.type or 'item'; kinds[kind]=true
        if s.signal.type=='recipe' and s.signal.name=='iron-plate' and s.signal.quality=='normal' then assert(s.count==(wire=='red' and 12 or -5)) end
        if s.signal.type=='recipe' and s.signal.name=='copper-plate' then assert(s.count==(wire=='red' and -2147483648 or 1)) end
      end
      all[1].count=123; assert(p.readSignals(wire)[1].count~=123)
      end
      assert(kinds.item and kinds.fluid and kinds.virtual and kinds.recipe)
      for _,bad in ipairs({'both','blue',false}) do
        local ok,e=pcall(p.readSignals,bad); assert(not ok and e.code=='E_ARGUMENT')
        ok,e=pcall(p.readSignal,bad,{type='recipe',name='iron-plate'}); assert(not ok and e.code=='E_ARGUMENT')
        ok,e=pcall(p.subscribe,{input=bad},'changed'); assert(not ok and e.code=='E_ARGUMENT')
      end
      local ok,e=pcall(p.readSignals); assert(not ok and e.code=='E_ARGUMENT')
      ok,e=pcall(p.readSignal,nil,{type='recipe',name='iron-plate'}); assert(not ok and e.code=='E_ARGUMENT')
      ok,e=pcall(p.subscribe,{},'changed'); assert(not ok and e.code=='E_ARGUMENT')
      local out=p.getOutput(); assert(#out==2 and (out[2].signal.type or 'item')=='item' and out[1].signal.type=='recipe')
      out[1].count=999; assert(p.getOutput()[1].count==7)
      local ok,err=pcall(p.setOutput,{{signal={type='recipe',name='tc-missing-recipe'},count=1}})
      assert(not ok and err.code=='E_RANGE')
      ok,err=pcall(p.readSignal,'red',{type='recipe',name='tc-missing-recipe'}); assert(not ok and err.code=='E_RANGE')
      ok,err=pcall(p.setOutput,{{signal={type='recipe',name='iron-plate'},count=1},{signal={type='recipe',name='iron-plate',quality='normal'},count=2}})
      assert(not ok and err.code=='E_ARGUMENT' and p.getOutput()[1].count==7)
      ok,err=pcall(p.setOutput,{{signal={type='recipe',name='iron-plate',quality='tc-missing-quality'},count=1}})
      assert(not ok and err.code=='E_RANGE' and p.getOutput()[1].count==7)
      ok,err=pcall(p.subscribe,{input='red',signals={{type='recipe',name='tc-missing-recipe'}}},'changed')
      assert(not ok and err.code=='E_RANGE')
      ok,err=pcall(p.subscribe,{input='red',signals={{type='recipe',name='iron-plate'},{type='recipe',name='iron-plate',quality='normal'}}},'changed')
      assert(not ok and err.code=='E_ARGUMENT')
      local many={}; for i=1,65 do many[i]={signal={type='recipe',name='iron-plate'},count=i} end
      ok,err=pcall(p.setOutput,many); assert(not ok and err.code=='E_ARGUMENT' and p.getOutput()[1].count==7)
      assert(p.readSignal('red',{type='entity',name='inserter'})==0)]])
    if script.active_mods.quality then
      probe(c,[[assert(p.readSignal('green',{type='recipe',name='iron-plate',quality='uncommon'})==4)
        assert(p.readSignal('red',{type='recipe',name='iron-plate',quality='uncommon'})==0)
        local count=0; for _,s in ipairs(p.readSignals('green')) do if s.signal.type=='recipe' then count=count+1 end end
        assert(count==3)]])
    end
    for _,color in ipairs({'red','green'}) do
      assert(x.output.get_signal(recipe(),defines.wire_connector_id['circuit_'..color])==7)
      assert(x.output.get_signal({type='item',name='iron-plate',quality='normal'},defines.wire_connector_id['circuit_'..color])==3)
    end
    -- Unrelated prototype counts must not affect actual-input work admission.
    local original=prototypes
    local function read_work(length)
      local proxy={}
      for _,kind in ipairs({'item','fluid','virtual_signal','recipe','quality'}) do
        local native=original[kind]
        proxy[kind]=setmetatable({},{__index=function(_,key) return native[key] end,__len=function() return length end})
      end
      prototypes=setmetatable(proxy,{__index=original})
      local work=0
      local result=logic.inspect_input(io,'red',event.tick,function(n) work=work+n end)
      assert(#result.values>=2 and result.connected)
      return work
    end
    local measured,problem=pcall(function()
      assert(read_work(1)==read_work(1000000),'unrelated prototypes changed signal read cost')
    end)
    prototypes=original; assert(measured,problem)
    -- Refuse before the native call; ownership and the old bank stay intact.
    local expected=32
    local first; local refusal={code='E_BUDGET'}; local old_bank=serpent.line(logic.inspect_output(io,function() end)); local old_owner=io.output_owner
    local api=peripheral.services(c,event.tick,{check=function() end,accept_handle=function() end,spend=function(n)
      if n==expected then first=n; error(refusal,0) end
    end}).peripheral
    local ok,problem=pcall(api.call,io.id,'red','readSignals','red')
    assert(not ok and problem==refusal and first==expected,'native call entered without work admission')
    assert(serpent.line(logic.inspect_output(io,function() end))==old_bank and io.output_owner==old_owner)
    -- The reported Console path, through real submission/authority/dispatch;
    -- only the player and native GUI objects are table-backed fixtures.
    player=players.player(8101,c.body)
    assert(editor.open(player,c.id)); gui=player.gui.screen[editor.frame_name]
    with_player(function()
      gui.content.selected_tab_index=2; editor.on_tab{player_index=player.index,element=gui.content,tick=event.tick}
      local input=gui.content.console.prompt.command
      input.text='p=peripheral.wrap("'..io.id..'","red"); for _,s in ipairs(p.readSignals("red")) do print(s.signal.type or "item",s.signal.name,s.signal.quality or "normal",s.count) end'
      editor.on_text{player_index=player.index,element=input,tick=event.tick}
      editor.on_confirmed{player_index=player.index,element=input,tick=event.tick}
      assert(input.text=='','recipe Console ingress refused')
    end)
    x.phase='shell'
  elseif x.phase=='shell' and c.shell and #c.shell.pending==0 then
    assert(not c.shell.diagnostic,serpent.line(c.shell.diagnostic))
    local found=false
    for _,entry in ipairs(c.logs) do if entry.text:find('output: recipe\tiron-plate\tnormal\t12',1,true) then found=true end end
    assert(found,'reported Console loop did not print the real recipe signal')
    with_player(function() editor.on_click{player_index=player.index,element=gui.title.close,tick=event.tick} end)
    -- Emulate a persisted pre-contract registration, including pending effects.
    -- The frozen phase prevents further scheduler ticks before the cold save.
    local legacy=registry.computer(x.legacy)
    legacy.status='running'; legacy.run_id=legacy.id..'/legacy'; legacy.active=c.active
    runtime.subscribe(legacy,'signal_changed','changed',{peripheral=io.id,generation=io.generation,
      wire='red',input='both',previous={},connected={},initial=true},function() end)
    assert(runtime.enqueue(legacy,'changed',{name='signal_changed',input='both'},event.tick))
    x.legacy_armed=true
    x.phase='frozen'; x.snapshot=snapshot(); x.native_bank=serpent.line(logic.inspect_output(io,function() end))
    log('TC_CONTRACT recipe-native-mixed-read-write-filter-quality-refusal-and-admission')
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif x.phase=='resume' and c.state.events>x.snapshot.events then
    local e=c.state.last
    assert(not e.initial and #e.current==1 and e.current[1].signal.type=='recipe' and e.current[1].count==20)
    assert(e.changes[1].previous==12 and e.changes[1].current==20 and c.state.boots==1)
    assert(c.run_id==x.snapshot.run and serpent.line(logic.inspect_output(io,function() end))==x.native_bank and io.output_owner==x.snapshot.owner)
    put(x.red,{{signal={type='item',name='iron-plate'},count=99}}); x.phase='disappear'; x.since=event.tick
  elseif x.phase=='disappear' and #c.state.last.current==0 then
    local e=c.state.last
    assert(e.changes[1].signal.type=='recipe' and e.changes[1].previous==20 and e.changes[1].current==0)
    assert(c.status=='running' and c.state.boots==1)
    probe(c,[[assert(p.unsubscribe(computer.getState('subscription')))
      computer.setState('subscription',p.subscribe({input='green',signals={{type='recipe',name='iron-plate'}},initial=true},'changed'))]])
    x.phase='green-initial'; x.since=event.tick
  elseif x.phase=='green-initial' and c.state.last.input=='green' then
    assert(c.state.last.initial and c.state.last.current[1].count==-5)
    assert(c.state.last.connected.green and c.state.last.connected.red==nil)
    put(x.green,{{signal=recipe(),count=-2147483648}})
    x.phase='green-change'
  elseif x.phase=='green-change' and c.state.last.current[1].count==-2147483648 then
    assert(c.state.last.changes[1].previous==-5 and c.state.last.changes[1].current==-2147483648)
    put(x.green,{}); x.phase='green-disappear'
  elseif x.phase=='green-disappear' and #c.state.last.current==0 then
    assert(c.state.last.changes[1].previous==-2147483648 and c.state.last.changes[1].current==0)
    probe(c,[[assert(p.unsubscribe(computer.getState('subscription')))]])
    put(x.green,{{signal={type='entity',name='inserter'},count=1}})
    x.phase='entity'; x.since=event.tick
  elseif x.phase=='entity' and event.tick-x.since>=3 then
    local bank,owner=serpent.line(logic.inspect_output(io,function() end)),io.output_owner
    probe(c,[[local a=p.readSignals('green'); assert(#a==1 and a[1].signal.type=='entity' and a[1].signal.name=='inserter' and a[1].count==1)]])
    assert(serpent.line(logic.inspect_output(io,function() end))==bank and io.output_owner==owner)
    probe(c,[[p.subscribe({input='green'},'changed')]])
    assert(io.children.input.get_signals_changed(defines.wire_connector_id.pole_copper)==nil,'missing connector is not an unchanged observation')
    x.hints={}; x.last_hint_tick=event.tick; x.phase='pulse-high'
    put(x.green,{{signal={type='entity',name='inserter'},count=42}})
  elseif x.phase=='pulse-high' and x.pulse_tick then
    local e=c.state.last
    assert(e.sample_tick==event.tick and e.input=='green' and e.current[1].count==42,'one-native-step pulse was missed')
    x.phase='pulse-low'
  elseif x.phase=='pulse-low' then
    local e=c.state.last
    assert(event.tick==x.pulse_tick+1 and e.sample_tick==event.tick and e.current[1].count==1,'pulse disappearance was not sampled next tick')
    put(x.green,{}); x.phase='empty-connected'
  elseif x.phase=='empty-connected' and #c.state.last.current==0 then
    assert(c.state.last.connected.green)
    assert(lifecycle.connector(io,'input','green').disconnect_from(x.green.get_wire_connector(defines.wire_connector_id.circuit_green,false)))
    x.phase='empty-disconnected'
  elseif x.phase=='empty-disconnected' and c.state.last.connected.green==false then
    assert(#c.state.last.current==0)
    assert(lifecycle.connector(io,'input','green').connect_to(x.green.get_wire_connector(defines.wire_connector_id.circuit_green,true)))
    x.phase='empty-reconnected'
  elseif x.phase=='empty-reconnected' and c.state.last.connected.green then
    assert(#c.state.last.current==0 and not c.state.last.initial)
    x.merge=assert(io.body.surface.create_entity{name='constant-combinator',position={7,-6},force='player'})
    put(x.merge,{})
    assert(x.green.get_wire_connector(defines.wire_connector_id.circuit_green,true).connect_to(x.merge.get_wire_connector(defines.wire_connector_id.circuit_green,true)))
    x.phase='empty-merge'; x.since=event.tick; x.events=c.state.events
  elseif x.phase=='empty-merge' and event.tick-x.since>=3 then
    assert(c.state.events==x.events and #c.queue==0,'empty merge produced a false effective delta')
    assert(x.green.get_wire_connector(defines.wire_connector_id.circuit_green,false).disconnect_from(x.merge.get_wire_connector(defines.wire_connector_id.circuit_green,false)))
    x.phase='empty-split'; x.since=event.tick
  elseif x.phase=='empty-split' and event.tick-x.since>=3 then
    assert(c.state.events==x.events and #c.queue==0,'empty split produced a false effective delta')
    x.merge.destroy()
    log('TC_NATIVE_SIGNAL_HINTS '..helpers.table_to_json(x.hints))
    log('TC_CONTRACT logic-native-one-step-pulse-empty-connect-disconnect-merge-split-and-missing-hint-connector')
    local ids={}; for id in pairs(c.subscriptions) do ids[#ids+1]=id end
    for _,id in ipairs(ids) do runtime.unsubscribe(c,id) end
    local observers=registry.get().logic_observers
    assert(#observers.order==0 and #observers.input_order==0 and next(observers.inputs)==nil and next(observers.computers)==nil,'last unsubscribe retained a watch')
    probe(c,[[p.subscribe({input='green',initial=true},'changed')]])
    logic.sample(event.tick,function() end)
    assert(#c.queue==1 and #observers.order==1)
    assert(lifecycle.remove(io.id,'fixture-endpoint-removal',true))
    assert(#c.queue==0 and #observers.order==0 and #observers.input_order==0 and next(c.subscriptions)==nil,'endpoint removal retained an observer or its queued event')
    log('TC_CONTRACT logic-last-unsubscribe-and-endpoint-removal-cancel-observation-and-queue')
    x.phase='done'; log('TC_COLD_OK recipe-red-green-isolation-legacy-fault-no-replay-and-disappearance')
  end
end
return M
