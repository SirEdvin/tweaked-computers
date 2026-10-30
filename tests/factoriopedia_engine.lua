-- Packaged native engine / compiled guest contracts, separate from fault injection.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local compiler=require('scripts.runtime.compiler')
local peripheral=require('scripts.services.peripheral')
local provider=require('scripts.services.factoriopedia-interface')
local limits=require('scripts.runtime.limits')
local admission=require('scripts.runtime.admission')
local defs=require('scripts.device-definitions')
local contracts=require('tests.factoriopedia_contract')
local shell=require('scripts.runtime.shell')
local example=require('examples.factoriopedia-program')
local M={}; local resumed=false
local function f() return storage.tc_fact_fixture end
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local function build(kind,x,y)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player',
    quality=kind=='factoriopedia_interface' and script.active_mods.quality and 'legendary' or 'normal'})
  lifecycle.on_built{entity=body}; return assert(registry.by_entity(body))
end
local function connect(a,b,color)
  assert(lifecycle.connector(a,'network',color).connect_to(lifecycle.connector(b,'network',color),false))
end
local prefix=[[local s=peripheral.find('factoriopedia_interface','red'); assert(s)
local function refused(code,fn,...)
  local ok,e=pcall(fn,...); assert(not ok and type(e)=='table' and e.code==code,code..' expected')
  return e
end
]]
local function research()
  local snapshot={recipes={},technologies={}}
  for name,recipe in pairs(game.forces.player.recipes) do snapshot.recipes[name]=recipe.enabled end
  for name,technology in pairs(game.forces.player.technologies) do snapshot.technologies[name]=technology.researched end
  return snapshot
end
local function guest(c,body,document)
  local before=research(); local unit=c.body.unit_number
  local ctx=runtime.context(c,game.tick)
  local plan,e=compiler.compile(document or 'function start(e) '..body..' end',ctx)
  assert(plan,serpent.line(e))
  local ok,problem=compiler.run(plan,'start',{},function(g) return runtime.services(c,game.tick,g) end,ctx)
  assert(ok,serpent.line(problem))
  assert(c.body.valid and c.body.unit_number==unit and equal(before,research()),'query mutated native body/research/recipe state')
end
local busy=[[function start(e) computer.every(1,'work') end

function work(e) computer.setState('samples',(computer.getState('samples') or 0)+1) end]]
local query_source=[[function start(e) computer.setState('query_starts',(computer.getState('query_starts') or 0)+1); computer.every(1,'query') end

function query(e)
  local s=peripheral.find('factoriopedia_interface','red')
  assert(s.getItem('iron-plate').stack_size>0)
  local n=computer.getState('queries') or 0
  if n%5==0 then
    for _,method in ipairs({s.listItems,s.listFluids}) do
      local ok,value=pcall(method)
      if ok then assert(#value>0) else assert(value.code=='E_LIMIT') end
    end
  end
  computer.setState('queries',n+1)
end]]
local exhausted_source=[[function start(e)
  local s=peripheral.find('factoriopedia_interface','red')
  pcall(function() for i=1,1000 do s.getItem('iron-plate') end end)
  computer.setState('escaped',true)
end]]
local cases={
  {'discovery-five-methods-and-arity',[[
    local id=peripheral.getNames('red'); local methods
    for _,name in ipairs(id) do if peripheral.getType(name,'red')=='factoriopedia_interface' then methods=peripheral.getMethods(name,'red') end end
    assert(#methods==5 and methods[1]=='getFluid' and methods[2]=='getItem' and methods[3]=='getLimits' and methods[4]=='listFluids' and methods[5]=='listItems')
    refused('E_ARGUMENT',s.getItem); refused('E_ARGUMENT',s.getItem,'iron-plate',nil)
    refused('E_ARGUMENT',s.getItem,s,'iron-plate'); refused('E_ARGUMENT',s.getItem,3)
    refused('E_ARGUMENT',s.getFluid,{}); refused('E_ARGUMENT',s.getFluid,'')
    refused('E_ARGUMENT',s.listItems,nil); refused('E_ARGUMENT',s.listFluids,s)
    refused('E_ARGUMENT',s.getLimits,nil)
    assert(refused('E_RANGE',s.getItem,'IRON-PLATE').field=='name')
    refused('E_RANGE',s.getFluid,'iron-plate'); refused('E_RANGE',s.getItem,'water')
    local l=s.getLimits(); assert(l.table_entries==1024 and not l.catalogue_entries)
    l.table_entries=1; assert(s.getLimits().table_entries==1024)
  ]]},
  {'namespace-native-item-fluid-fields-and-isolation',[[
    local a=s.getItem('tc-fp-overlap'); local b=s.getFluid('tc-fp-overlap')
    assert(a.type=='item' and b.type=='fluid' and a.name==b.name)
    assert(a.stack_size==17 and a.hidden and a.hidden_in_factoriopedia and a.factoriopedia_alternative=='iron-plate')
    assert(a.fuel_value==0 and #a.fuel_categories==0 and a.burnt_result==nil and a.place_result==nil)
    assert(b.default_temperature==-20 and b.max_temperature==80 and b.gas_temperature==123 and b.heat_capacity==123 and b.fuel_value==0)
    computer.setState('item',a); computer.setState('fluid',b)
    a.name='changed'; a.fuel_categories[1]='invented'; b.max_temperature=0
    assert(s.getItem('tc-fp-overlap').name=='tc-fp-overlap' and #s.getItem('tc-fp-overlap').fuel_categories==0)
    assert(s.getFluid('tc-fp-overlap').max_temperature==80)
    assert(s.getFluid('tc-fp-equal').max_temperature==-5)
  ]]},
  {'fuel-spoil-subtypes-and-reference-rocket',[[
    local a=s.getItem('tc-fp-fuel'); assert(a.fuel_value==2000000 and #a.fuel_categories==2 and a.burnt_result=='iron-plate')
    local spoiling,spoil=pcall(s.getItem,'tc-fp-spoil')
    if spoiling then
      assert(spoil.spoil_ticks==600 and spoil.spoil_result=='iron-plate')
      local trigger=s.getItem('tc-fp-trigger'); assert(trigger.spoil_ticks==180 and trigger.spoil_result==nil)
    else assert(spoil.code=='E_RANGE') end
    assert(s.getItem('firearm-magazine').prototype_type=='ammo')
    assert(s.getItem('tc-computer').place_result=='tc-computer-shell')
    local fractional=s.getItem('tc-fp-fractional')
    assert(fractional.stack_size==13 and fractional.rocket_capacity==math.floor(fractional.default_rocket_lift_weight/fractional.weight))
    assert(s.getItem('tc-fp-heavy').rocket_capacity==0)
    assert(s.getItem('tc-fp-no-orbit').rocket_capacity>0)
    local zero=s.getItem('tc-fp-zero'); assert(zero.weight==0 and zero.rocket_capacity==nil)
    assert(s.getItem('parameter-0').parameter and s.getFluid('parameter-0').parameter)
    computer.setState('fractional',fractional)
  ]]},
  {'complete-name-membership-and-defensive-order',[[
    local items=s.listItems(); local fluids=s.listFluids()
    for i=2,#items do assert(items[i-1]<items[i]) end
    for i=2,#fluids do assert(fluids[i-1]<fluids[i]) end
    computer.setState('items',items); computer.setState('fluids',fluids)
    items[1]='changed'; fluids[1]='changed'
    assert(s.listItems()[1]~='changed' and s.listFluids()[1]~='changed')
  ]]}
}
local function native_fields(record,kind)
  local p=prototypes[kind][record.name]
  local allowed={name=true,type=true,prototype_type=true,group=true,subgroup=true,order=true,hidden=true,hidden_in_factoriopedia=true,parameter=true,factoriopedia_alternative=true}
  assert(record.type==kind and record.prototype_type==p.type and record.group==p.group.name and record.subgroup==p.subgroup.name)
  for _,key in ipairs({'name','order','hidden','hidden_in_factoriopedia','parameter'}) do assert(record[key]==p[key],key) end
  assert(record.factoriopedia_alternative==(p.factoriopedia_alternative and p.factoriopedia_alternative.name))
  if kind=='item' then
    for _,key in ipairs({'stack_size','stackable','weight','fuel_value','quality_affects_spoil_ticks'}) do assert(record[key]==p[key],key) end
    for _,key in ipairs({'stack_size','stackable','weight','default_rocket_lift_weight','rocket_capacity','fuel_value','fuel_categories','burnt_result','spoil_ticks','quality_affects_spoil_ticks','spoil_result','place_result','default_import_location'}) do allowed[key]=true end
    assert(record.spoil_ticks==p.get_spoil_ticks('normal'))
    assert(equal(record.fuel_categories,p.fuel_categories or {}))
    for _,key in ipairs({'burnt_result','spoil_result','place_result','default_import_location'}) do assert(record[key]==(p[key] and p[key].name),key) end
    assert(record.default_rocket_lift_weight==prototypes.utility_constants.default_rocket_lift_weight)
  else
    for _,key in ipairs({'default_temperature','max_temperature','gas_temperature','heat_capacity','fuel_value','emissions_multiplier'}) do assert(record[key]==p[key],key) end
    for _,key in ipairs({'default_temperature','max_temperature','gas_temperature','heat_capacity','fuel_value','emissions_multiplier'}) do allowed[key]=true end
  end
  for key in pairs(record) do assert(allowed[key],'undocumented metadata field '..key) end
end
local function native_names(record,kind)
  local count=0; local found={}
  for _,name in ipairs(record) do assert(not found[name] and prototypes[kind][name]); found[name]=true end
  for name in pairs(prototypes[kind]) do count=count+1; assert(found[name],name) end
  assert(#record==count)
end
function M.run()
  storage.tc_fact_fixture={phase='power',start=game.tick,case=1,large=M.large==true}
  local x=f(); local surface=game.surfaces[1]; local tiles={}
  for y=-10,10 do for xx=-10,20 do tiles[#tiles+1]={name='landfill',position={xx,y}} end end
  surface.set_tiles(tiles)
  local c=build('computer',0,0); local s=build('factoriopedia_interface',3,0); local n=build('computer',0,4)
  connect(c,s,'red'); connect(c,s,'green')
  local relay=build('kv',6,0); connect(s,relay,'red'); x.relay=relay.id
  local mixed=build('factoriopedia_interface',9,0); connect(relay,mixed,'green'); x.mixed=mixed.id
  x.c=c.id; x.s=s.id; x.neighbor=n.id
  local power=assert(surface.create_entity{name='electric-energy-interface',position={6,6},force='player'})
  power.power_production=100000000; power.power_usage=0
  assert(surface.create_entity{name='substation',position={3,3},force='player'})
  runtime.save(c.id,busy,0); assert(runtime.activate(c.id,game.tick))
  runtime.save(n.id,busy,0); assert(runtime.activate(n.id,game.tick))
  local force=game.create_force('tc-fp-fresh')
  assert(not force.recipes['tc-factoriopedia-interface'].enabled and not force.recipes['tc-recipe-searcher'].enabled)
  force.technologies['tc-circuit-computers'].researched=true; lifecycle.unlocks()
  assert(not force.recipes['tc-factoriopedia-interface'].enabled and not force.recipes['tc-recipe-searcher'].enabled)
  force.technologies['tc-recipe-searcher'].researched=true; lifecycle.unlocks()
  assert(force.recipes['tc-factoriopedia-interface'].enabled and force.recipes['tc-recipe-searcher'].enabled)
  log('TC_FACT fresh-research-together')
end
function M.on_load() resumed=f().phase=='frozen' end
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  local c=registry.record(x.c); local s=registry.record(x.s)
  if x.phase=='frozen' then
    if not resumed then return end
    assert(c==x.saved.computer and s==x.saved.interface and c.state==x.saved.state and c.state.item==x.saved.item)
    assert(c.active.source==x.saved.source and c.state.query_starts==x.saved.starts and c.state.queries==x.saved.queries)
    assert(c.body.unit_number==x.saved.unit and s.body.unit_number==x.saved.interface_unit)
    assert(lifecycle.connector(c,'network','red').connection_count==x.saved.red and lifecycle.connector(c,'network','green').connection_count==x.saved.green)
    assert(registry.get().ledger.total==x.saved.total)
    assert(registry.get().ledger.tick==x.saved.tick and registry.get().ledger.machines[c.id].work==x.saved.work)
    assert(not admission.reserve(runtime.context(c,x.saved.tick),'work',1),'cold renewed credits')
    native_fields(c.state.item,'item'); native_fields(c.state.fluid,'fluid')
    x.phase='done'; log('TC_FACT cold-snapshots-identity-credits-no-replay'); log('TC_COLD_OK'); return
  end
  assert(event.tick-x.start<600,'factoriopedia deadline '..x.phase)
  local scheduler_profile=x.phase=='contention' and helpers.create_profiler() or nil
  scheduler.tick(event.tick)
  if scheduler_profile then
    scheduler_profile.stop(); log({'','TC_FACT_SCHEDULER ',x.large and 'large-refusal ' or 'standard ',scheduler_profile})
  end
  assert(c.status=='running',serpent.line(c.diagnostic))
  if not c.powered or not s.powered then return end
  if x.phase=='power' then
    contracts.run(c,s)
    for _,name in ipairs({'iron-plate','firearm-magazine','tc-computer','tc-fp-fuel','tc-fp-fractional','tc-fp-heavy','tc-fp-zero','parameter-0'}) do
      native_fields(provider.methods.getItem(c,s,'red',event.tick,function() end,name),'item')
    end
    if prototypes.item['tc-fp-spoil'] then
      assert(s.body.quality.name=='legendary')
      for _,name in ipairs({'tc-fp-spoil','tc-fp-trigger'}) do native_fields(provider.methods.getItem(c,s,'red',event.tick,function() end,name),'item') end
    end
    x.phase='cases'; return
  end
  if x.phase=='cases' then
    local case=cases[x.case]
    if case then
      if x.large and x.case==4 then
        guest(c,prefix..[[refused('E_LIMIT',s.listItems); refused('E_LIMIT',s.listFluids); assert(s.getItem('iron-plate').stack_size>0 and s.getFluid('water').fuel_value==0)]])
        log('TC_FACT native-large-both-catalogues-complete-refusal-and-independent-lookups')
      else guest(c,prefix..case[2]); log('TC_FACT '..case[1]) end
      x.case=x.case+1
      if case[1]=='namespace-native-item-fluid-fields-and-isolation' then native_fields(c.state.item,'item'); native_fields(c.state.fluid,'fluid') end
      if not x.large and case[1]=='complete-name-membership-and-defensive-order' then native_names(c.state.items,'item'); native_names(c.state.fluids,'fluid') end
      return
    end
    assert(registry.record(x.neighbor).state.samples>=#cases,'neighbor starved')
    x.phase='example'; return
  elseif x.phase=='example' then
    guest(c,nil,example); assert(c.state.factoriopedia_example)
    log('TC_FACT exact-shipped-example-both-list-methods')
    x.phase='example-zero'; return
  elseif x.phase=='example-zero' then
    local zero,count=example:gsub('"iron%-plate"','"tc-fp-zero"'); assert(count==1)
    guest(c,nil,zero)
    local found=false; for _,entry in ipairs(c.logs) do if entry.text=='No finite mass-limited rocket count' then found=true end end
    assert(found,'example absent-count branch did not log')
    log('TC_FACT shipped-example-zero-weight-branch')
    x.phase='authority'; return
  elseif x.phase=='authority' then
    local nop=function() end
    assert(peripheral.inventory(c,'red',nop)[x.relay] and peripheral.inventory(c,'green',nop)[s.id])
    assert(not peripheral.inventory(c,'red',nop)[x.mixed],'mixed colors granted authority')
    s.powered=false
    guest(c,prefix..[[assert(s.getLimits().table_entries==1024); assert(s.getItem('iron-plate').name=='iron-plate'); assert(#s.listItems()>0)]])
    assert(peripheral.inventory(c,'red',nop)[x.relay],'unpowered relay lost discovery')
    s.powered=true
    guest(c,prefix..[[assert(s.getItem('iron-plate').name=='iron-plate')]])
    c.shell={version=1,id='factoriopedia-fixture-shell',pending={},pending_bytes=0}
    local ok,e=shell.evaluate(c,"s=peripheral.find('factoriopedia_interface','red'); captured=s.getItem",game.tick,1); assert(ok,serpent.line(e))
    s.body.force=game.forces['tc-fp-fresh']
    ok,e=shell.evaluate(c,"local ok,e=pcall(captured,'iron-plate'); assert(not ok and e.code=='E_UNREACHABLE')",game.tick,2); assert(ok,serpent.line(e))
    s.body.force=game.forces.player
    local other=game.create_surface('tc-fp-other',{width=32,height=32})
    local cross=assert(s.body.clone{position={0,0},surface=other,force='player'})
    local rec=assert(registry.by_entity(cross)); assert(rec.id~=s.id and rec.surface_index~=c.surface_index)
    guest(c,"assert(peripheral.wrap('"..rec.id.."','red')==nil)")
    assert(lifecycle.remove(rec.id,'fixture',true))
    local position=s.body.position; assert(lifecycle.remove(s.id,'fixture',true))
    local replacement=build('factoriopedia_interface',position.x,position.y)
    connect(c,replacement,'red'); connect(c,replacement,'green'); connect(replacement,registry.record(x.relay),'red')
    x.s=replacement.id; assert(not replacement.children.power)
    ok,e=shell.evaluate(c,"local ok,e=pcall(captured,'iron-plate'); assert(not ok and e.code=='E_UNREACHABLE')",game.tick,2); assert(ok,serpent.line(e))
    assert(shell.reset(c,'fixture'))
    log('TC_FACT authority-both-colors-relay-mixed-power-force-surface-and-stale-method')
    local specimen=build('factoriopedia_interface',12,8)
    for _,direction in ipairs({4,8,12,0}) do
      local before=specimen.body.direction; specimen.body.direction=direction
      lifecycle.on_rotated{entity=specimen.body,previous_direction=before}; assert(specimen.direction==direction)
    end
    local cloned=assert(specimen.body.clone{position={16,8},surface=game.surfaces[1],force='player'})
    local clone=assert(registry.by_entity(cloned)); assert(clone.id~=specimen.id and lifecycle.available(clone))
    local helper=lifecycle.endpoint(clone,'network'); local inventory=game.create_inventory(1); local quality=cloned.quality.name
    lifecycle.on_removed{entity=cloned}; assert(cloned.mine{inventory=inventory,raise_destroyed=false})
    assert(inventory.get_item_count{name='tc-factoriopedia-interface',quality=quality}==1 and not helper.valid and not registry.record(clone.id))
    inventory.destroy()
    local partner=build('factoriopedia_interface',16,8)
    connect(specimen,partner,'red'); connect(specimen,partner,'green')
    local selection=game.create_inventory(1); selection[1].set_stack{name='blueprint',count=1}
    local blueprint=selection[1]
    blueprint.create_blueprint{surface=game.surfaces[1],force='player',area={{11,7},{18,9}}}
    local surface=game.surfaces[1]; surface.request_to_generate_chunks({40,12},1); surface.force_generate_chunk_requests()
    local tiles={}; for y=8,16 do for xx=36,44 do tiles[#tiles+1]={name='landfill',position={xx,y}} end end
    surface.set_tiles(tiles)
    for _,entity in ipairs(surface.find_entities_filtered{area={{36,8},{44,16}},type={'tree','simple-entity','cliff'}}) do entity.destroy() end
    local ghosts=blueprint.build_blueprint{surface=surface,force='player',position={40,12},direction=defines.direction.east,
      raise_built=true,skip_fog_of_war=false,build_mode=defines.build_mode.forced}
    local revived={}
    for _,ghost in ipairs(ghosts) do
      local _,body=ghost.revive{raise_revive=true}; assert(body)
      local record=assert(registry.by_entity(body)); assert(record.kind=='factoriopedia_interface' and record.id~=specimen.id and record.id~=partner.id)
      revived[#revived+1]=record
    end
    assert(#revived==2)
    for _,record in ipairs(revived) do
      assert(lifecycle.connector(record,'network','red').connection_count==1 and lifecycle.connector(record,'network','green').connection_count==1)
    end
    for _,record in ipairs(revived) do
      local body=record.body; assert(lifecycle.remove(record.id,'fixture',true) and not body.valid)
    end
    selection.destroy(); assert(lifecycle.remove(specimen.id,'fixture',true) and lifecycle.remove(partner.id,'fixture',true))
    local doomed=build('factoriopedia_interface',20,8); local doomed_power=doomed.body
    assert(doomed.body.die() and not doomed_power.valid and not registry.record(doomed.id))
    log('TC_FACT cardinal-clone-mining-one-drop-wired-blueprint-destruction-and-helper-cleanup')
    assert(runtime.save(c.id,query_source,c.saved_revision)); assert(runtime.activate(c.id,event.tick))
    local exhausted=build('computer',-4,0); connect(exhausted,replacement,'red')
    assert(runtime.save(exhausted.id,exhausted_source,0)); assert(runtime.activate(exhausted.id,event.tick))
    x.exhausted=exhausted.id; x.since=event.tick; x.neighbor_before=registry.record(x.neighbor).state.samples
    x.phase='contention'; return
  elseif x.phase=='contention' then
    local profiler=helpers.create_profiler()
    local native=prototypes.item['iron-plate']; local weight=native.weight
    profiler.stop(); log({'','TC_FACT_NATIVE_LOOKUP ',profiler})
    assert(weight>0)
    if event.tick-x.since<25 then return end
    local exhausted=registry.record(x.exhausted)
    assert(exhausted.status=='faulted' and exhausted.diagnostic.code=='E_BUDGET' and not exhausted.state.escaped,'pcall caught fatal work exhaustion')
    assert(c.state.queries>=20 and registry.record(x.neighbor).state.samples>x.neighbor_before)
    log('TC_FACT contention '..serpent.line{queries=c.state.queries,neighbor=registry.record(x.neighbor).state.samples,neighbor_before=x.neighbor_before,total=registry.get().ledger.total})
    local work=build('computer',-4,4); connect(work,s,'red')
    assert(not work.children.power and lifecycle.available(work))
    assert(runtime.save(work.id,busy,0)); assert(runtime.activate(work.id,event.tick))
    local ctx=runtime.context(work,event.tick)
    local plan,problem=compiler.compile(exhausted_source,ctx); assert(plan,serpent.line(problem))
    assert(admission.reserve(ctx,'work',limits.callback_work-ctx.machine.work-2000))
    local ok,diagnostic=compiler.run(plan,'start',{},function(g) return runtime.services(work,event.tick,g) end,ctx)
    assert(not ok and diagnostic.code=='E_BUDGET' and not work.state.escaped,'prepaid work exhaustion escaped real guest boundary')
    assert(ctx.machine.work>=limits.callback_work-2000)
    assert(lifecycle.remove(work.id,'fixture',true))
    log('TC_FACT real-guest-prepaid-work-refusal-no-renewal')
    x.phase='freeze'; return
  elseif x.phase=='freeze' then
    local ctx=runtime.context(c,event.tick); local machine=registry.get().ledger.machines[c.id]
    assert(admission.reserve(ctx,'work',limits.callback_work-machine.work))
    x.saved={computer=c,interface=s,state=c.state,item=c.state.item,tick=registry.get().ledger.tick,work=machine.work,
      source=c.active.source,starts=c.state.query_starts,queries=c.state.queries,unit=c.body.unit_number,interface_unit=s.body.unit_number,
      red=lifecycle.connector(c,'network','red').connection_count,green=lifecycle.connector(c,'network','green').connection_count,total=registry.get().ledger.total}
    x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  end
end
return M
