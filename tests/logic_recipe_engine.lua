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
local source=[[return {api_version=1,handlers={
  start=function(e)
    computer.setState('boots',(computer.getState('boots') or 0)+1)
    local p=peripheral.find('logic_handler','red')
    local id=p.subscribe({input='red',signals={{type='recipe',name='iron-plate'}},initial=true},'changed')
    computer.setState('subscription',id)
    p.setOutput({{signal={type='recipe',name='iron-plate'},count=7},{signal={type='item',name='iron-plate'},count=3}})
  end,
  changed=function(e)
    computer.setState('events',(computer.getState('events') or 0)+1)
    computer.setState('last',e)
  end
}}]]
local function probe(c,text)
  local ctx=admission.context(admission.new(),c.id,0)
  local plan,problem=compiler.compile('return {api_version=1,handlers={start=function(e) local p=peripheral.find("logic_handler","red"); '..text..' end}}',ctx)
  assert(plan,problem and problem.message)
  local ok,err=compiler.run(plan,'start',{name='start'},function(g) return runtime.services(c,game.tick,g) end,ctx)
  assert(ok,err and serpent.line(err))
end
local function snapshot()
  local x=f(); local c=registry.computer(x.c); local io=registry.record(x.io)
  local sub=c.subscriptions[c.state.subscription]; local root=registry.get()
  return {state=c.state,run=c.run_id,active=c.active,queue=c.queue,subscriptions=c.subscriptions,
    filter=sub.details.signals,baseline=sub.details.previous,bank=io.output_bank,owner=io.output_owner,
    ledger=root.ledger,total=root.ledger.total,tick=root.ledger.tick,machine=root.ledger.machines[c.id],
    work=root.ledger.machines[c.id].work,events=c.state.events,shell=c.shell,values=c.shell and c.shell.values}
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
  assert(lifecycle.connector(c,'network','red').connect_to(lifecycle.connector(io,'network','red')))
  local red=assert(surface.create_entity{name='constant-combinator',position={0,-3},force='player'})
  local green=assert(surface.create_entity{name='constant-combinator',position={4,-3},force='player'})
  put(red,{{signal=recipe(),count=12},{signal={type='recipe',name='copper-plate'},count=2147483647},
    {signal={type='item',name='iron-plate'},count=99},{signal={type='virtual',name='signal-A'},count=2}})
  local entries={{signal=recipe(),count=-5},{signal={type='recipe',name='copper-plate'},count=1},{signal={type='fluid',name='water'},count=3}}
  if script.active_mods.quality then entries[#entries+1]={signal=recipe('uncommon'),count=4} end
  put(green,entries)
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
  storage.tc_recipe_signals={c=c.id,io=io.id,red=red,green=green,output=output,phase='power',start=game.tick}
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
    assert(c.state.boots==1 and io.output_bank[2].signal.type=='recipe')
    put(x.red,{{signal=recipe(),count=20},{signal={type='item',name='iron-plate'},count=99}})
    x.phase='resume'; x.resumed=event.tick
  else loaded=false end
  with_player(function() scheduler.tick(event.tick) end)
  assert(c.status~='faulted',c.diagnostic and c.diagnostic.message)
  assert(event.tick-x.start<240,'recipe scenario deadline '..x.phase)
  if x.phase=='power' and event.tick-x.start>=5 then
    assert(c.powered and io.powered)
    assert(runtime.save(c.id,source,c.saved_revision)); assert(runtime.activate(c.id,event.tick))
    x.phase='initial'
  elseif x.phase=='initial' and c.state.last then
    assert(c.status=='running',c.diagnostic and c.diagnostic.message)
    local e=c.state.last
    assert(e.initial and #e.current==1 and e.current[1].signal.type=='recipe' and e.current[1].count==12)
    assert(e.changes[1].previous==0 and e.changes[1].current==12)
    log('TC_RECIPE_NATIVE_INPUT '..serpent.line(io.children.input.get_signals(defines.wire_connector_id.circuit_red)))
    probe(c,[[assert(p.readSignal('red',{type='recipe',name='iron-plate'})==12)
      assert(p.readSignal('green',{type='recipe',name='iron-plate'})==-5)
      assert(p.readSignal('both',{type='recipe',name='iron-plate'})==7)
      assert(p.readSignal('both',{type='item',name='iron-plate'})==99)
      assert(p.readSignal('both',{type='recipe',name='copper-plate'})==-2147483648)
      assert(p.readSignal('both',{type='recipe',name='steel-plate'})==0)
      local all=p.readSignals('both'); local kinds={}; local last=''
      for _,s in ipairs(all) do
        local key=s.signal.type..'/'..s.signal.name..'/'..s.signal.quality
        assert(key>last); last=key; kinds[s.signal.type]=true
        if s.signal.type=='recipe' and s.signal.name=='iron-plate' and s.signal.quality=='normal' then assert(s.count==7) end
        if s.signal.type=='recipe' and s.signal.name=='copper-plate' then assert(s.count==-2147483648) end
      end
      assert(kinds.item and kinds.fluid and kinds.virtual and kinds.recipe)
      all[1].count=123; assert(p.readSignals('both')[1].count~=123)
      local out=p.getOutput(); assert(#out==2 and out[1].signal.type=='item' and out[2].signal.type=='recipe')
      out[2].count=999; assert(p.getOutput()[2].count==7)
      local ok,err=pcall(p.setOutput,{{signal={type='recipe',name='tc-missing-recipe'},count=1}})
      assert(not ok and err.code=='E_RANGE')
      ok,err=pcall(p.readSignal,'red',{type='recipe',name='tc-missing-recipe'}); assert(not ok and err.code=='E_RANGE')
      ok,err=pcall(p.setOutput,{{signal={type='recipe',name='iron-plate'},count=1},{signal={type='recipe',name='iron-plate',quality='normal'},count=2}})
      assert(not ok and err.code=='E_ARGUMENT' and p.getOutput()[2].count==7)
      ok,err=pcall(p.setOutput,{{signal={type='recipe',name='iron-plate',quality='tc-missing-quality'},count=1}})
      assert(not ok and err.code=='E_RANGE' and p.getOutput()[2].count==7)
      ok,err=pcall(p.subscribe,{input='red',signals={{type='recipe',name='tc-missing-recipe'}}},'changed')
      assert(not ok and err.code=='E_RANGE')
      ok,err=pcall(p.subscribe,{input='red',signals={{type='recipe',name='iron-plate'},{type='recipe',name='iron-plate',quality='normal'}}},'changed')
      assert(not ok and err.code=='E_ARGUMENT')
      local many={}; for i=1,65 do many[i]={signal={type='recipe',name='iron-plate'},count=i} end
      ok,err=pcall(p.setOutput,many); assert(not ok and err.code=='E_ARGUMENT' and p.getOutput()[2].count==7)
      ok,err=pcall(p.readSignal,'red',{type='entity',name='inserter'}); assert(not ok and err.code=='E_ARGUMENT')]])
    if script.active_mods.quality then
      probe(c,[[assert(p.readSignal('both',{type='recipe',name='iron-plate',quality='uncommon'})==4)
        local count=0; for _,s in ipairs(p.readSignals('both')) do if s.signal.type=='recipe' then count=count+1 end end
        assert(count==3)]])
    end
    for _,color in ipairs({'red','green'}) do
      assert(x.output.get_signal(recipe(),defines.wire_connector_id['circuit_'..color])==7)
      assert(x.output.get_signal({type='item',name='iron-plate',quality='normal'},defines.wire_connector_id['circuit_'..color])==3)
    end
    -- Refuse at the supported-type envelope, including the new recipe registry.
    local expected=(#prototypes.item+#prototypes.fluid+#prototypes.virtual_signal+#prototypes.recipe)*#prototypes.quality*8+logic.signal_slots*16+16
    local first; local refusal={code='E_BUDGET'}; local old_bank=io.output_bank; local old_owner=io.output_owner
    local api=peripheral.services(c,event.tick,{check=function() end,accept_handle=function() end,spend=function(n)
      if n==expected then first=n; error(refusal,0) end
    end}).peripheral
    local ok,problem=pcall(api.call,io.id,'red','readSignals','red')
    assert(not ok and problem==refusal and first==expected,'recipe registry omitted from query precharge')
    assert(io.output_bank==old_bank and io.output_owner==old_owner)
    -- The reported Console path, through real submission/authority/dispatch;
    -- only the player and native GUI objects are table-backed fixtures.
    player=players.player(8101,c.body)
    assert(editor.open(player,c.id)); gui=player.gui.screen[editor.frame_name]
    with_player(function()
      gui.content.selected_tab_index=2; editor.on_tab{player_index=player.index,element=gui.content,tick=event.tick}
      local input=gui.content.console.prompt.command
      input.text='p=peripheral.wrap("'..io.id..'","red"); for _,s in ipairs(p.readSignals("red")) do print(s.signal.type,s.signal.name,s.signal.quality,s.count) end'
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
    x.phase='frozen'; x.snapshot=snapshot()
    log('TC_CONTRACT recipe-native-mixed-read-write-filter-quality-refusal-and-admission')
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif x.phase=='resume' and c.state.events>x.snapshot.events then
    local e=c.state.last
    assert(not e.initial and #e.current==1 and e.current[1].signal.type=='recipe' and e.current[1].count==20)
    assert(e.changes[1].previous==12 and e.changes[1].current==20 and c.state.boots==1)
    assert(c.run_id==x.snapshot.run and io.output_bank==x.snapshot.bank and io.output_owner==x.snapshot.owner)
    put(x.red,{{signal={type='item',name='iron-plate'},count=99}}); x.phase='disappear'; x.since=event.tick
  elseif x.phase=='disappear' and #c.state.last.current==0 then
    local e=c.state.last
    assert(e.changes[1].signal.type=='recipe' and e.changes[1].previous==20 and e.changes[1].current==0)
    assert(c.status=='running' and c.state.boots==1)
    x.phase='done'; log('TC_COLD_OK recipe-bank-filter-identity-once-only-and-disappearance')
  end
end
return M
