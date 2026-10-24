-- Exact packaged production provider, native wires and actual scheduler ticks.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local compiler=require('scripts.runtime.compiler')
local peripheral=require('scripts.services.peripheral')
local provider=require('scripts.services.recipe-searcher')
local shell=require('scripts.runtime.shell')
local contracts=require('tests.recipe_searcher_contract')
local defs=require('scripts.device-definitions')
local M={}; local loaded=false
local function f() return storage.tc_recipe_fixture end
local function nop() end
local function report(name) log('TC_RECIPE '..name) end
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local function build(kind,x,y,force,surface)
  local body=assert((surface or game.surfaces[1]).create_entity{name=defs.devices[kind].entity_name,position={x,y},force=force or 'player'})
  lifecycle.on_built{entity=body}; return assert(registry.by_entity(body))
end
local function connect(a,b,color)
  assert(lifecycle.connector(a,'network',color).connect_to(lifecycle.connector(b,'network',color),false))
end
local function guest(c,body)
  local source='return {api_version=1,handlers={start=function(e) '..body..' end}}'
  local ctx=runtime.context(c,game.tick)
  local plan,problem=compiler.compile(source,ctx); assert(plan,serpent.line(problem))
  local ok,diagnostic=compiler.run(plan,'start',{},function(g) return runtime.services(c,game.tick,g) end,ctx)
  assert(ok,serpent.line(diagnostic))
end
local prefix=[[local s=peripheral.find('recipe_searcher','red'); assert(s)
local function refused(code,fn,...)
  local ok,e=pcall(fn,...); assert(not ok and type(e)=='table' and e.code==code,code..' expected, got '..tostring(e))
  return e
end
]]
local cases={
  {'typed-mod-catalogue-and-no-match',[[
    local items=s.findRecipes('item','tc-rs-overlap')
    assert(#items==2 and items[1].name=='tc-rs-hidden' and items[2].name=='tc-rs-item','item namespace/order')
    local fluids=s.findRecipes('fluid','tc-rs-overlap')
    assert(#fluids==2 and fluids[1].name=='tc-rs-fluid' and fluids[2].name=='tc-rs-metadata','fluid namespace/order')
    assert(#s.findRecipes('item','tc-rs-empty')==0)
    assert(#s.findRecipes('item','tc-rs-overlap','smelting')==0)
    assert(#s.findRecipes('item','tc-rs-overlap','tc-rs-additional')==1)
    assert(#s.findRecipes('item','tc-rs-overlap',nil)==2)
    local h=items[1]; assert(h.hidden and h.hidden_from_player_crafting and h.hidden_from_flow_stats and h.hidden_in_factoriopedia)
    assert(not h.enabled and not h.enabled_by_default and h.category=='tc-rs-recycling')
  ]]},
  {'strict-arity-domain-and-registry-errors',[[
    refused('E_ARGUMENT',s.findRecipes); refused('E_ARGUMENT',s.findRecipes,'item')
    refused('E_ARGUMENT',s.findRecipes,s,'item','iron-plate')
    refused('E_ARGUMENT',s.findRecipes,'item',''); refused('E_ARGUMENT',s.findRecipes,'item',{})
    refused('E_ARGUMENT',s.findRecipes,'item','iron-plate',{},1)
    refused('E_ARGUMENT',s.findRecipes,'item','iron-plate',{})
    refused('E_ARGUMENT',s.getLimits,1)
    refused('E_RANGE',s.findRecipes,'recipe','iron-plate')
    refused('E_RANGE',s.findRecipes,'item','TC-RS-OVERLAP')
    refused('E_RANGE',s.findRecipes,'fluid','tc-rs-empty')
    refused('E_RANGE',s.findRecipes,'item','iron-plate','tc-missing-category')
    local l=s.getLimits(); assert(l.policy_version==2 and l.recipe_search_results==nil and l.callback_work==nil)
    assert(l.resources.callback_work.limit==computer.getLimits().resources.callback_work.limit)
    l.resources.callback_work.limit=1; assert(s.getLimits().resources.callback_work.limit==computer.getLimits().resources.callback_work.limit)
  ]]},
  {'exact-fifty-complete-sorted',[[
    local a=s.findRecipes('item','tc-rs-fifty'); assert(#a==50)
    for i,v in ipairs(a) do
      assert(v.name==string.format('tc-rs-50-%02d',i) and #v.ingredients==1 and #v.products==1)
      assert(v.products[1].amount==1 and v.products[1].probability==1)
    end
  ]]},
  {'fiftyone-complete-category-filtering',[[
    assert(#s.findRecipes('item','tc-rs-fiftyone')==51)
    assert(#s.findRecipes('item','tc-rs-single51','tc-rs-primary')==51)
    local a=s.findRecipes('item','tc-rs-fiftyone','tc-rs-refined')
    assert(#a==2 and a[1].name=='tc-rs-51-01' and a[2].name=='tc-rs-51-02')
    local b=s.findRecipes('item','tc-rs-fiftyone','tc-rs-primary'); assert(#b==49)
  ]]},
  {'complete-metadata-and-defensive-snapshots',[[
    local a=s.findRecipes('item','tc-rs-complex'); assert(#a==1)
    local v=a[1]; assert(v.name=='tc-rs-metadata' and v.energy==7.5 and #v.products==3 and #v.ingredients==2)
    assert(#v.additional_categories==2 and v.additional_categories[1]=='tc-rs-additional')
    local p=v.products[1]; assert(p.amount==nil and p.amount_min==1 and p.amount_max==3 and p.probability==.5)
    assert(p.extra_count_fraction==.25 and p.ignored_by_stats==1 and p.ignored_by_productivity==1)
    assert(v.products[3].temperature==80 and v.products[3].fluidbox_index==1)
    local i=v.ingredients[2]; assert(i.minimum_temperature==20 and i.maximum_temperature==90 and i.temperature==nil)
    assert(i.fluidbox_index==1)
    computer.setState('metadata',v)
    v.ingredients[2].amount=999; table.remove(v.products)
    local b=s.findRecipes('item','tc-rs-complex'); assert(b[1].ingredients[2].amount==10 and #b[1].products==3)
  ]]},
  {'large-complete-metadata',[[local a=s.findRecipes('item','tc-rs-large'); assert(#a==1 and #a[1].products==600)]]},
  {'live-force-enabled-without-reboot',[[
    local a=s.findRecipes('item','tc-rs-overlap','tc-rs-additional')
    computer.setState('enabled',a[1].enabled)
  ]]}
}
local busy=[[return {api_version=1,handlers={start=function(e) computer.every(1,'work') end,
 work=function(e) computer.setState('samples',(computer.getState('samples') or 0)+1) end}}]]
local query_source=[[return {api_version=1,handlers={start=function(e) computer.every(1,'query') end,
 query=function(e)
   local s=peripheral.find('recipe_searcher','red'); local a=s.findRecipes('item','tc-rs-fifty')
   assert(#a==50); computer.setState('queries',(computer.getState('queries') or 0)+1)
 end}}]]
local exhausted_source=[[return {api_version=1,handlers={start=function(e)
  local s=peripheral.find('recipe_searcher','red')
  local ok,e=pcall(function() for i=1,100 do local a=s.findRecipes('item','tc-rs-fifty'); assert(#a==50) end end)
  computer.setState('escaped',true)
end}}]]
local function snapshot()
  local x=f(); local root=registry.get(); local c=registry.record(x.c)
  return {computer=c,state=c.state,active=c.active,query=c.state.retained,searcher=registry.record(x.s),
    run=c.run_id,ledger=root.ledger,total=root.ledger.total,spent=root.ledger.machines[c.id].work,
    tick=root.ledger.tick,wires=lifecycle.connector(c,'network','red').connection_count}
end
local function unchanged()
  local a,b=f().expected,snapshot()
  for k,v in pairs(a) do assert(v==b[k],'cold mutation/alias loss '..k) end
end
function M.run()
  storage.tc_recipe_fixture={phase='power',start=game.tick,case=1}
  local x=f(); local srf=game.surfaces[1]; local tiles={}
  for y=-12,12 do for xx=-12,20 do tiles[#tiles+1]={name='landfill',position={xx,y}} end end
  srf.set_tiles(tiles)
  local c=build('computer',0,0); local s=build('recipe_searcher',3,0); local relay=build('kv',6,0); local neighbor=build('computer',0,4)
  connect(c,s,'red'); connect(c,s,'green'); connect(s,relay,'red')
  x.c=c.id; x.s=s.id; x.relay=relay.id; x.neighbor=neighbor.id
  x.power=assert(srf.create_entity{name='electric-energy-interface',position={6,6},force='player'})
  x.power.power_production=100000000; x.power.power_usage=0
  assert(srf.create_entity{name='substation',position={3,3},force='player'})
  runtime.save(c.id,busy,0); assert(runtime.activate(c.id,game.tick))
  runtime.save(neighbor.id,busy,0); assert(runtime.activate(neighbor.id,game.tick))
  local force=game.forces.player
  force.technologies['tc-circuit-computers'].researched=true
  lifecycle.unlocks(); assert(not force.recipes['tc-recipe-searcher'].enabled)
  force.technologies['tc-recipe-searcher'].researched=true
  lifecycle.unlocks(); assert(force.recipes['tc-recipe-searcher'].enabled)
  local fresh=game.create_force('tc-rs-fresh')
  assert(not fresh.recipes['tc-recipe-searcher'].enabled)
  report('native-independent-research-and-fresh-force')
end
function M.on_load()
  loaded=true
  if f().phase=='frozen' then unchanged(); report('on-load-identity-state-wires-and-spent-credits-unchanged') end
end
function M.on_configuration_changed()
  unchanged(); assert(game.forces.player.technologies['tc-recipe-searcher'].researched)
  assert(game.forces.player.recipes['tc-recipe-searcher'].enabled); f().upgraded=true
  report('configuration-change-independent-researched-unlock')
end
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  local c=registry.record(x.c); local s=registry.record(x.s)
  if x.phase=='frozen' then
    if not loaded then return end
    unchanged(); local ctx=runtime.context(c,x.expected.tick)
    assert(not admission.reserve(ctx,'work',1),'cold renewed spent query credits')
    loaded=false; x.phase='resume'
  else loaded=false end
  assert(event.tick-x.start<900,'recipe fixture deadline '..x.phase)
  local scheduler_profile=helpers.create_profiler()
  scheduler.tick(event.tick)
  scheduler_profile.stop()
  if x.phase=='contention' then log({'','TC_RECIPE_SCHEDULER ',scheduler_profile}) end
  assert(c.status=='running',serpent.line(c.diagnostic))
  if not c.powered or not s.powered then return end
  if x.phase=='power' then x.phase='cases'; return end
  if x.phase=='cases' then
    local case=cases[x.case]
    if case then

      guest(c,prefix..case[2]); report(case[1]); x.case=x.case+1
      if case[1]=='complete-metadata-and-defensive-snapshots' then
        local actual=c.state.metadata; local native=prototypes.recipe['tc-rs-metadata']
        assert(equal(actual.ingredients,native.ingredients) and equal(actual.products,native.products))
        local conditions=native.surface_conditions or {}; assert(#actual.surface_conditions==#conditions)
        for i,condition in ipairs(conditions) do
          local a=actual.surface_conditions[i]; assert(a.property==condition.property)
          assert(a.min==(condition.min~=-math.huge and condition.min or nil))
          assert(a.max==(condition.max~=math.huge and condition.max or nil))
        end
      end
      return
    end
    assert(c.state.enabled==false); game.forces.player.recipes['tc-rs-item'].enabled=true
    guest(c,prefix..cases[#cases][2]); assert(c.state.enabled==true)
    local foreign=build('computer',-4,0,game.forces['tc-rs-fresh']); local fs=build('recipe_searcher',-7,0,game.forces['tc-rs-fresh'])
    connect(foreign,fs,'red'); foreign.powered=true; fs.powered=true
    lifecycle.power_entity(foreign).energy=2000; lifecycle.power_entity(fs).energy=1000
    foreign.status='running'; foreign.run_id='fixture-foreign'
    guest(foreign,prefix..cases[#cases][2]); assert(foreign.state.enabled==false)
    assert(not peripheral.inventory(c,'red',nop)[fs.id])
    assert(lifecycle.remove(foreign.id,'fixture',true) and lifecycle.remove(fs.id,'fixture',true))
    report('live-script-change-and-independent-forces')
    x.phase='authority'; return
  elseif x.phase=='authority' then
    contracts.run(c,s)
    local specimen=build('recipe_searcher',12,8)
    for _,direction in ipairs({4,8,12,0}) do
      local previous=specimen.body.direction; specimen.body.direction=direction
      lifecycle.on_rotated{entity=specimen.body,previous_direction=previous}
      assert(specimen.direction==direction and lifecycle.connector(specimen,'network','red'))
    end
    local cloned_body=assert(specimen.body.clone{position={16,8},surface=game.surfaces[1],force='player'})
    local cloned=assert(registry.by_entity(cloned_body)); assert(cloned.id~=specimen.id)
    local helper=lifecycle.power_entity(cloned); local inventory=game.create_inventory(1)
    lifecycle.on_removed{entity=cloned_body}
    assert(cloned_body.mine{inventory=inventory,raise_destroyed=false})
    assert(inventory.get_item_count('tc-recipe-searcher')==1 and not helper.valid and not registry.record(cloned.id))
    inventory.destroy(); assert(lifecycle.remove(specimen.id,'fixture',true))
    report('native-cardinal-clone-one-drop-and-helper-cleanup')
    assert(peripheral.inventory(c,'red',nop)[x.relay] and peripheral.inventory(c,'green',nop)[s.id])
    lifecycle.power_entity(s).energy=0; s.powered=false
    guest(c,prefix..[[assert(s.getLimits().policy_version==2 and s.getLimits().recipe_search_results==nil); refused('E_UNPOWERED',s.findRecipes,'item','iron-plate')]])
    assert(peripheral.inventory(c,'red',nop)[x.relay],'unpowered relay lost discovery')
    lifecycle.power_entity(s).energy=1000; s.powered=true
    guest(c,prefix..[[assert(#s.findRecipes('item','tc-rs-fifty')==50)]])
    -- Trusted shell evaluation exercises retained captured-method revalidation;
    -- GUI submission/focus is not part of this fixture's evidence.
    c.shell={version=1,id='recipe-fixture-shell',pending={},pending_bytes=0}
    local ok,e=shell.evaluate(c,"s=peripheral.find('recipe_searcher','red'); captured=s.findRecipes",game.tick,1); assert(ok,serpent.line(e))
    s.body.force=game.forces['tc-rs-fresh']
    ok,e=shell.evaluate(c,"local ok,e=pcall(captured,'item','iron-plate'); assert(not ok and e.code=='E_UNREACHABLE')",game.tick,2); assert(ok,serpent.line(e))
    s.body.force=game.forces.player
    local other=game.create_surface('tc-rs-other',{width=32,height=32})
    local cross_body=assert(s.body.clone{position={0,0},surface=other,force='player'})
    local cross=assert(registry.by_entity(cross_body)); assert(cross.id~=s.id and cross.surface_index~=c.surface_index)
    guest(c,"assert(peripheral.wrap('"..cross.id.."','red')==nil)")
    assert(lifecycle.remove(cross.id,'fixture',true))
    local position=s.body.position; assert(lifecycle.remove(s.id,'fixture',true))
    local replacement=build('recipe_searcher',position.x,position.y); connect(c,replacement,'red'); connect(c,replacement,'green'); connect(replacement,registry.record(x.relay),'red')
    x.s=replacement.id; lifecycle.power_entity(replacement).energy=1000; replacement.powered=true
    ok,e=shell.evaluate(c,"local ok,e=pcall(captured,'item','iron-plate'); assert(not ok and e.code=='E_UNREACHABLE')",game.tick,2); assert(ok,serpent.line(e))
    assert(shell.reset(c,'fixture'))
    report('red-green-unpowered-limits-relay-restoration-captured-replacement')
    runtime.save(c.id,query_source,c.saved_revision); assert(runtime.activate(c.id,event.tick))
    local exhausted=build('computer',0,-4); connect(exhausted,registry.record(x.s),'red')
    runtime.save(exhausted.id,exhausted_source,0); assert(runtime.activate(exhausted.id,event.tick)); x.exhausted=exhausted.id
    x.phase='contention'; x.since=event.tick; return
  elseif x.phase=='contention' then
    assert(registry.record(x.neighbor).state.samples>0)
    for _,product in ipairs({'tc-rs-empty','tc-rs-fifty','iron-plate'}) do
      local profiler=helpers.create_profiler()
      local matches=prototypes.get_recipe_filtered{{filter='has-product-item',elem_filters={{filter='name',name=product}}}}
      profiler.stop(); log({'','TC_RECIPE_NATIVE_FILTER '..product..' count='..#matches..' ',profiler})
    end
    if event.tick-x.since<20 then return end
    local exhausted=registry.record(x.exhausted)
    assert(exhausted.status=='faulted' and exhausted.diagnostic.code=='E_BUDGET' and not exhausted.state.escaped,
      'guest pcall caught fatal repeated-query exhaustion: '..serpent.line(exhausted.diagnostic))
    assert(c.state.queries and c.state.queries>=15,'production query scheduler did not progress')
    log('TC_RECIPE_CONTENTION '..serpent.line{queries=c.state.queries,neighbor=registry.record(x.neighbor).state.samples,
      catalogue=#prototypes.recipe,total=registry.get().ledger.total})
    guest(c,prefix..[[computer.setState('retained',s.findRecipes('item','tc-rs-overlap'))]])
    local ctx=runtime.context(c,event.tick)
    assert(admission.reserve(ctx,'work',limits.callback_work-ctx.machine.work))
    x.expected=snapshot(); x.phase='frozen'
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  elseif x.phase=='resume' then
    local prior=c.state.retained
    guest(c,prefix..[[computer.setState('retained',s.findRecipes('item','tc-rs-overlap'))]])
    assert(equal(prior,c.state.retained))
    report('ordinary-cold-complete-query-and-neighbor-progress')
    x.phase='done'; if x.upgraded then log('TC_UPGRADE_OK') else log('TC_COLD_OK') end
  end
end
return M
