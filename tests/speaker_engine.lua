local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')

local carrier=require('scripts.speaker')
local audio=require('scripts.speaker-audio')
local speaker=require('scripts.services.speaker')
local peripheral=require('scripts.services.peripheral')
local runtime=require('scripts.runtime.computer')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local sandbox=require('scripts.runtime.sandbox')
local limits=require('scripts.runtime.limits')
local defs=require('scripts.device-definitions')
local graph=require('scripts.network')
local targets=require('scripts.configuration.targets')
local blueprints=require('scripts.blueprints')
local native_cases=require('tests.speaker_native_cases')
local example_sources={require('examples.speaker-alarm'),require('examples.speaker-melody'),require('examples.speaker-catalogue')}
local M={}; local loaded=false
local function nop() end
local function f() return storage.speaker_fixture end
local function report(name) f().groups=f().groups+1; log('TC_CONTRACT '..name) end
local function error_is(code,fn)
  local ok,e=pcall(fn); assert(not ok and type(e)=='table' and e.code==code,'expected '..code..': '..serpent.line(e))
end
local function conn(b,color) return assert(b.get_wire_connector(defines.wire_connector_id['circuit_'..color],true)) end
local function connect(a,b,color) assert(conn(a,color).connect_to(conn(b,color),false)) end
local function build(kind,x,y)
  local b=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})
  lifecycle.on_built{entity=b}; local r=assert(registry.by_entity(b)); lifecycle.power_entity(r).energy=1000000; r.powered=true; return r
end
local function native(x,y)
  return assert(game.surfaces[1].create_entity{name='programmable-speaker',position={x,y},force='player'})
end
local function guest(c,body)
  local source='function start(event) '..body..' end'
  local ctx=admission.context(admission.new(),c.id,game.tick)
  local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
  c.active={source=source,revision=0,api_version=1,compiler_version=limits.compiler_version,storage_version=1,handlers=plan.handlers}
  c.status='running'; c.run_id=c.run_id or c.id..'/fixture'
  local ok,problem=compiler.run(plan,'start',{name='start'},function(g) return runtime.services(c,game.tick,g) end,ctx)
  assert(ok,problem and (problem.code..': '..problem.message))
end
local function call(c,r,method,...) return speaker.methods[method](c,r,'red',game.tick,nop,...) end
local function power()
  for _,id in ipairs(registry.get().order) do local r=registry.record(id)
    if r.body.valid then lifecycle.power_entity(r).energy=1000000; r.powered=true end
  end
end
local function catalogue_oracle()
  local set={}; local count=0
  local function add(path)
    if not set[path] and helpers.is_valid_sound_path(path) then
      count=count+1; assert(count<=32768); set[path]=true
    end
  end
  for _,path in ipairs(prototypes.mod_data['tc-fixture-speaker-oracle'].data.paths) do add(path) end
  for name in pairs(prototypes.entity) do
    for _,family in ipairs({'build','mined','mining','rotated','open','close'}) do add('entity-'..family..'/'..name) end
  end
  for name in pairs(prototypes.item) do
    for _,family in ipairs({'open','close','pick','drop','move'}) do add('item-'..family..'/'..name) end
  end
  for name in pairs(prototypes.tile) do
    for _,family in ipairs({'walking','mined','build-small','build-medium','build-large'}) do add('tile-'..family..'/'..name) end
  end
  local result={}; for path in pairs(set) do result[#result+1]=path end; table.sort(result); return result
end
local function boolean_edges()
  for _,value in ipairs({true,false}) do
    for _,credits in ipairs({0,1,2,3,4,5,6,7,8}) do
      local ctx=admission.context(admission.new(),'boolean-edge',game.tick); local g=sandbox.new(ctx,{})
      local count=0
      local fn=g.service(function() g.prepare_boolean_result(); count=count+1; return value end)
      ctx.machine.work=limits.callback_work-credits
      local ok,result=pcall(g.call,fn)
      -- G.call entry 1 + G.service entry 1 + snapshot 1 + immediate return 3.
      assert(count==(credits>=6 and 1 or 0))
      assert(ok==(credits>=6)); if ok then assert(result==value) end
    end
  end
  local ctx=admission.context(admission.new(),'allocation-edge',game.tick); local g=sandbox.new(ctx,{})
  local count=0; local fn=g.service(function() g.prepare_boolean_result(); count=count+1; return true end)
  ctx.machine.allocations=limits.callback_allocations-2
  assert(not pcall(g.call,fn) and count==0)
  local ordinary=g.service(function() return {} end)
  assert(not pcall(ordinary)) -- A fatal budget cannot be caught/reused.
end
function M.run()
  storage.speaker_fixture={groups=0,phase='armed'}
  local c=build('computer',0,0); local db=build('kv',12,0); local b=native(6,0)
  lifecycle.on_built{entity=b}; lifecycle.on_built{entity=b}; assert(not registry.by_entity(b),'unwired build must not occupy native identity capacity')
  local before=serpent.line{parameters=b.parameters,alert=b.alert_parameters,behavior=b.get_or_create_control_behavior().circuit_parameters}
  connect(c.body,b,'red'); connect(c.body,b,'green'); connect(b,db.body,'red')
  error_is('E_NETWORK_PENDING',function() peripheral.inventory(c,'red',nop) end)
  for _=1,#registry.get().order+3 do graph.adopt_tick(game.tick,nop) end
  local r=assert(registry.by_entity(b)); assert(r.native_carrier=='speaker' and not next(r.children))
  assert(lifecycle.build(b)==r and b.operable and b.minable)
  local inv=peripheral.inventory(c,'red',nop); assert(inv[r.id] and inv[db.id])
  assert(peripheral.inventory(c,'green',nop)[r.id])
  local _,path=peripheral.authority(c,db.id,'red',nop); assert(#path==3 and graph.validate_witness(c,'red',path,nop))
  b.energy=1000000; r.powered=true
  report('native-build-frontier-idempotence-identity-both-colors-and-same-color-relay')
  local index=audio.index(nop); local aliases=0
  for _,i in ipairs(index) do
    local notes=audio.instrument(i.name,nop)
    for j,n in ipairs(notes) do assert(n.pitch==j-1 and helpers.is_valid_sound_path(n.path)); aliases=aliases+1 end
  end
  assert(aliases>100); f().aliases=aliases
  guest(c,[[
    local s=peripheral.find('speaker','red'); assert(s)
    local name=peripheral.getName(s); local green=peripheral.wrap(name,'green')
    local expected={'getInstruments','getLimits','getNotes','getSounds','playNote','playSound'}
    local methods=peripheral.getMethods(name,'red'); assert(#methods==6)
    for i,v in ipairs(expected) do assert(methods[i]==v) end
    local info=peripheral.describe(name,'red'); assert(info.footprint.width==1 and info.footprint.height==1 and info.type=='speaker')
    local names=s.getInstruments(); for i=2,#names do assert(names[i-1]<names[i]) end
    names[1]='changed'; assert(s.getInstruments()[1]~='changed')
    local notes=s.getNotes('piano'); assert(notes[1].pitch==0 and notes[1].name=='F3')
    notes[1].name='mutated'; assert(green.getNotes('piano')[1].name=='F3')
    assert(s.getLimits().speaker_notes_per_tick==8 and s.getLimits().speaker_world_submissions_per_tick==64)
    local empty=s.getSounds('this-prefix-is-absent/'); assert(#empty.sounds==0 and empty.next==nil)
    local page=s.getSounds('utility/'); assert(#page.sounds>0 and #page.sounds<=50)
    local function invalid(code,fn,...) local ok,e=pcall(fn,...); assert(not ok and e.code==code) end
    invalid('E_ARGUMENT',s.getLimits,1); invalid('E_ARGUMENT',s.getInstruments,nil)
    invalid('E_ARGUMENT',s.getNotes); invalid('E_ARGUMENT',s.getNotes,s,'piano')
    invalid('E_RANGE',s.getNotes,'Piano'); invalid('E_ARGUMENT',s.getSounds,false)
    invalid('E_ARGUMENT',s.getSounds,'','',1)
    invalid('E_RANGE',s.playNote,'piano',-1); invalid('E_RANGE',s.playNote,'piano',1,-1)
    invalid('E_RANGE',s.playNote,'piano',1,0.5); invalid('E_ARGUMENT',s.playNote,'piano',false)
    invalid('E_ARGUMENT',s.playNote,'piano',1,'F3'); invalid('E_RANGE',s.playSound,'__base__/sound/unknown.ogg')
    invalid('E_ARGUMENT',s.playSound,'utility/wire_connect_pole',1,1)
    invalid('E_ARGUMENT',s.playSound,''); invalid('E_LIMIT',s.getSounds,string.rep('x',257))
    assert(select('#',s.playNote('piano',0,nil))==1)
    assert(green.playSound('utility/wire_connect_pole',0))
    assert(not s.playSound('utility/wire_connect_pole',0))
    invalid('E_RANGE',s.playSound,'not-a-valid-sound')
  ]])
  assert(registry.get().speaker_audio.total==2)
  assert(before==serpent.line{parameters=b.parameters,alert=b.alert_parameters,behavior=b.get_or_create_control_behavior().circuit_parameters})
  report('compiled-six-method-arity-names-note-index-snapshots-errors-and-shared-effect-admission')
  boolean_edges(); report('boolean-work-allocation-boundaries-true-false-and-fatal-poison')
  local conf=build('configurator',0,6)
  connect(lifecycle.endpoint(conf,'targets'),b,'red')
  local found=false; for _,v in pairs(targets.inventory(conf,'red',nop)) do if v.entity==b then found=true; assert(not v.protected) end end; assert(found)
  local selection=game.create_inventory(1); selection[1].set_stack{name='blueprint',count=1}
  local bp=selection[1]; local mapping=bp.create_blueprint{surface=b.surface,force='player',area={{-1,-1},{14,3}}}
  assert(blueprints.prepare(bp,mapping))
  local preserved=false; for _,entry in ipairs(bp.get_blueprint_entities()) do if entry.name=='programmable-speaker' then preserved=true; assert(not entry.tags or not entry.tags.tc_settings) end end
  assert(preserved and b.valid and b.operable); selection.destroy()
  report('configurator-native-ownership-and-mixed-blueprint-preservation')
  local extra=native(6,6); local ceiling=limits.registry_entries; limits.registry_entries=registry.get().retained_count
  local refused,e=carrier.build(extra); limits.registry_entries=ceiling
  assert(not refused and e.code=='E_CAPACITY' and extra.valid and extra.minable and extra.operable)
  extra.destroy(); report('capacity-refusal-preserves-native-material')
  b.energy=0
  guest(c,[[local s=peripheral.find('speaker','red'); assert(s.getLimits().speaker_path_bytes==256)
    local ok,e=pcall(s.getInstruments); assert(not ok and e.code=='E_UNPOWERED')]])
  assert(peripheral.inventory(c,'red',nop)[db.id]); b.energy=1000000
  b.disabled_by_script=true; assert(not carrier.available(r)); b.disabled_by_script=false
  assert(b.order_deconstruction(b.force)); assert(not carrier.available(r)); b.cancel_deconstruction(b.force)
  assert(carrier.available(r))
  report('unpowered-relay-live-limits-script-disable-and-deconstruction')
  f().native_cases=native_cases.run(c,r,conf,guest,report)
  f().computer=c.id; f().speaker=r.id; f().db=db.id; f().settings=before
  f().initial_identity=r.id; f().sequence=registry.get().next_id
  f().oracle=catalogue_oracle(); f().oracle_count=0
  log('TC_CONTRACT_TOTAL '..f().groups)
end
function M.on_load() loaded=true end
function M.on_configuration_changed()
  assert(f().phase=='saved' and registry.record(f().speaker).body.valid)
  f().upgraded=true
end
local function persistence_check()
  local x=f(); local r=registry.record(x.speaker); local c=registry.record(x.computer)
  assert(r.id==x.initial_identity and registry.get().next_id==x.sequence)
  assert(x.settings==serpent.line{parameters=r.body.parameters,alert=r.body.alert_parameters,behavior=r.body.get_or_create_control_behavior().circuit_parameters})
  assert(registry.get().speaker_audio.tick==x.saved_tick and registry.get().speaker_audio.total==x.saved_total)
  assert(c.state.retained=='speaker-cold' and next(r.children)==nil)
end
function M.on_tick(e)
  local x=f(); if x.done then return end
  power()
  if loaded then
    loaded=false
    if x.phase=='saved' then
      persistence_check(); x.done=true
      log(x.upgraded and 'TC_UPGRADE_OK' or 'TC_COLD_OK'); return
    end
  end
  if x.phase=='armed' then
    local c=registry.record(x.computer); local r=registry.record(x.speaker)
    if game.tick==registry.get().speaker_audio.tick then
      assert(not call(c,r,'playSound','utility/wire_connect_pole',0))
      assert(registry.get().speaker_audio.total==2)
      x.same_tick_retained=true; return
    end
    assert(x.same_tick_retained,'first cold tick must preserve initial spent allowance')
    x.page=x.page or 1
    if x.page<=4 then
      guest(c,[[local s=peripheral.find('speaker','red')
        local after=computer.getState('cursor') or ''
        local page=s.getSounds('tc-fixture-speaker-',after)
        local number=computer.getState('page_number') or 1
        assert(#page.sounds==(number==4 and 1 or 50))
        for i,v in ipairs(page.sounds) do assert(v==string.format('tc-fixture-speaker-%03d',(number-1)*50+i)) end
        assert((page.next~=nil)==(number<4))
        if page.next then assert(page.next==page.sounds[#page.sounds]); computer.setState('cursor',page.next) end
        computer.setState('page_number',number+1)
      ]])
      x.page=x.page+1; return
    end
    if not x.oracle_complete then
      guest(c,[[local s=peripheral.find('speaker','red')
        local p=s.getSounds('',computer.getState('all_cursor') or '')
        computer.setState('all_page',p)
        if p.next then computer.setState('all_cursor',p.next) end
      ]])
      local page=c.state.all_page
      for _,path in ipairs(page.sounds) do
        x.oracle_count=x.oracle_count+1
        assert(path==x.oracle[x.oracle_count],'catalogue differs at '..x.oracle_count..': '..path..' expected '..tostring(x.oracle[x.oracle_count]))
      end
      if not page.next then
        assert(x.oracle_count==#x.oracle,'catalogue omitted native-valid paths')
        x.oracle_complete=true; log('TC_SPEAKER_CATALOGUE_ORACLE_OK '..x.oracle_count)
      end
      return
    end
    if not x.radar_checked then
      if e.tick<180 then return end
      if not native_cases.hidden(c,r,x.native_cases) then return end
      x.radar_checked=true
    end
    guest(c,[[local s=peripheral.find('speaker','red')
      local p=s.getSounds('tc-fixture-speaker-','tc-fixture-speaker-050a')
      assert(#p.sounds==50 and p.sounds[1]=='tc-fixture-speaker-051' and p.next=='tc-fixture-speaker-100')
      assert(s.playSound('tc-fixture-speaker-direct-only',0))
    ]])
    -- This direct-only late sound consumed the physical effect allowance.
    assert(not call(c,r,'playSound','utility/wire_connect_pole',0))
    for _=1,8 do assert(call(c,r,'playNote','piano',0,0)) end
    assert(not call(c,r,'playNote','piano',0,0) and not call(c,r,'playSound','utility/wire_connect_pole',0))
    x.phase='examples'; x.example_index=1; x.example_tick=e.tick
    runtime.stop(c.id)
    assert(runtime.save(c.id,example_sources[1],c.saved_revision)); assert(runtime.activate(c.id,e.tick))
  elseif x.phase=='examples' then
    scheduler.tick(e.tick)
    local c=registry.record(x.computer); local r=registry.record(x.speaker)
    assert(c.status=='running',serpent.line(c.diagnostic))
    local ready=x.example_index==1 and c.state.accepted==true
      or x.example_index==2 and c.state.step and c.state.step~=1
      or x.example_index==3 and c.state.complete==true
    if ready then
      if x.example_index==3 then
        assert(c.state.count==x.oracle_count)
        runtime.stop(c.id)
        assert(call(c,r,'playSound','utility/wire_connect_pole',0))
        for _=1,8 do assert(call(c,r,'playNote','piano',0,0)) end
        x.saved_tick=game.tick; x.saved_total=registry.get().speaker_audio.total
        c.state.retained='speaker-cold'; x.phase='saved'
        log('TC_SPEAKER_THREE_MAINTAINED_EXAMPLES_EXECUTED')
        game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
      else
        runtime.stop(c.id); x.example_index=x.example_index+1; x.example_tick=e.tick
        assert(runtime.save(c.id,example_sources[x.example_index],c.saved_revision)); assert(runtime.activate(c.id,e.tick))
      end
    end
  end
end
return M
