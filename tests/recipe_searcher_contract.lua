-- Native policy binding checks; M.run separately labels host-only fault injection.
local provider=require('scripts.services.recipe-searcher')
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local runtime=require('scripts.runtime.computer')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local policy=require('scripts.runtime.resource-policy')
local memory=require('scripts.runtime.memory')
local limits=require('scripts.runtime.limits')
local M={}
function M.policy()
  registry.initialize()
  local function build(kind,x)
    local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,40},force='player'})
    local rec,e=lifecycle.build(body); assert(rec,serpent.line(e))
    lifecycle.power_entity(rec).energy=1000000; rec.powered=true
    return rec
  end
  local computer=build('computer',0); local searcher=build('recipe_searcher',3)
  for _,wire in ipairs({'red','green'}) do
    assert(lifecycle.connector(computer,'network',wire).connect_to(lifecycle.connector(searcher,'network',wire),false))
  end
  local source=[[function start(event)
    local s=peripheral.find('recipe_searcher','red'); assert(s)
    local green=peripheral.wrap(peripheral.getName(s),'green')
    local p=s.getLimits(); assert(p.policy_version==2)
    assert(select('#',s.getLimits())==1 and next(p.tuning)==nil)
    assert(p.callback_work==nil and p.recipe_search_results==nil and p.table_entries==nil and p.network_nodes==nil)
    local common=computer.getLimits()
    local keys={'callback_work','callback_allocations','host_work_per_tick','runtime_memory_bytes',
      'host_memory_bytes','pending_work_bytes','host_stack_depth'}
    local count=0
    for _ in pairs(p.resources) do count=count+1 end
    assert(count==#keys)
    for _,key in ipairs(keys) do
      local descriptor=assert(p.resources[key]); local expected=common.resources[key]
      for field,value in pairs(expected) do assert(descriptor[field]==value) end
      for field,value in pairs(descriptor) do assert(expected[field]==value) end
    end
    assert(p.resources.kv_keys==nil and p.resources.state_bytes==nil)
    p.resources.callback_work.limit=1; p.resources.host_memory_bytes.setting='changed'
    local again=green.getLimits()
    assert(again.resources.callback_work.limit==common.resources.callback_work.limit)
    assert(again.resources.host_memory_bytes.setting=='tc-host-memory-bytes')
    for _,call in ipairs({function() s.getLimits(nil) end,function() s.getLimits(s) end}) do
      local ok,e=pcall(call); assert(not ok and e.code=='E_ARGUMENT')
    end
    if event.powered then
      local recipes=s.findRecipes('item','iron-plate','smelting'); assert(#recipes>0)
      for i=2,#recipes do assert(recipes[i-1].name<recipes[i].name) end
    else
      local ok,e=pcall(s.findRecipes,'item','iron-plate'); assert(not ok and e.code=='E_UNPOWERED')
    end
  end]]
  local plan,e=compiler.compile(source); assert(plan,e and e.message)
  computer.active={source=source,revision=0,api_version=1,compiler_version=limits.compiler_version,storage_version=1,handlers=plan.handlers}
  computer.status='running'; computer.run_id=computer.id..'/recipe-policy'
  local ledger=admission.new()
  for _,powered in ipairs({true,false}) do
    lifecycle.power_entity(searcher).energy=powered and 1000000 or 0; searcher.powered=powered
    local invocation={checkpoint={}}; local ctx=admission.context(ledger,computer.id,game.tick)
    local owner=policy.attach(computer,invocation,ctx)
    local ok,problem,control=compiler.run(plan,'start',{powered=powered},function(g)
      return runtime.services(computer,game.tick,g)
    end,ctx,invocation.checkpoint)
    assert(ok,serpent.line{problem=problem,control=control})
    memory.close(owner,function() end)
  end
  runtime.stop(computer.id)
  log('TC_CONTRACT native-recipe-policy-powered-unpowered-arity-and-defensive-descriptors')
  log('TC_CONTRACT_TOTAL 1')
end
function M.run(c,s)
  local original=prototypes
  local actual=original.recipe['tc-rs-item']
  local base={name=actual.name,category=actual.category,additional_categories=actual.additional_categories,
    energy=actual.energy,enabled=actual.enabled,hidden=actual.hidden,hidden_from_player_crafting=actual.hidden_from_player_crafting,
    hidden_from_flow_stats=actual.hidden_from_flow_stats,hidden_in_factoriopedia=actual.hidden_in_factoriopedia,
    ingredients=actual.ingredients,products=actual.products,surface_conditions={}}
  local function failure(code,change)
    local rec={}; for k,v in pairs(base) do rec[k]=v end; change(rec)
    prototypes=setmetatable({get_recipe_filtered=function() return {['tc-rs-item']=rec} end,
      recipe=setmetatable({['tc-rs-item']=rec},{__index=original.recipe})},{__index=original})
    local ok,e=pcall(provider.methods.findRecipes,c,s,'red',game.tick,function() end,'item','tc-rs-overlap')
    assert(not ok and type(e)=='table' and e.code==code,'expected '..code..': '..serpent.line(e))
  end
  local ok,e=pcall(function()
    failure('E_UNSUPPORTED',function(rec) rec.energy=math.huge end)
    failure('E_UNSUPPORTED',function(rec) rec.products={{type='item',name='tc-rs-overlap',probability=0/0,amount=1}} end)
    failure('E_UNSUPPORTED',function(rec) rec.ingredients={{type='fluid',name='water',amount=1,fluidbox_index=.5}} end)
    failure('E_UNSUPPORTED',function(rec) rec.surface_conditions={{property='pressure',min=math.huge}} end)
    failure('E_UNSUPPORTED',function(rec) rec.category=false end)
    prototypes=setmetatable({get_recipe_filtered=function() error('injected native failure') end},{__index=original})
    local accepted,problem=pcall(provider.methods.findRecipes,c,s,'red',game.tick,function() end,'item','tc-rs-overlap')
    assert(not accepted and problem.code=='E_ENGINE')
    local entered=false; local refusal={private='host-credit-refusal'}
    prototypes=setmetatable({get_recipe_filtered=function() entered=true; return {} end},{__index=original})
    accepted,problem=pcall(provider.methods.findRecipes,c,s,'red',game.tick,function() error(refusal,0) end,'item','tc-rs-overlap')
    assert(not accepted and problem==refusal and not entered,'native lookup entered before credit admission')
    local function query_work(length)
      local proxy={}
      for _,kind in ipairs({'recipe','recipe_category'}) do
        local catalogue=original[kind]
        proxy[kind]=setmetatable({},{__index=function(_,key) return catalogue[key] end,__len=function() return length end})
      end
      prototypes=setmetatable(proxy,{__index=original})
      local work=0
      local result=provider.methods.findRecipes(c,s,'red',game.tick,function(n) work=work+n end,
        'item','tc-rs-overlap','tc-rs-additional')
      assert(#result==1 and result[1].name=='tc-rs-item')
      return work
    end
    assert(query_work(1)==query_work(1000000),'unrelated recipes/categories changed query cost')
  end)
  prototypes=original
  if not ok then error(e,0) end
  log('TC_RECIPE host-only-unsupported-native-failure-and-zero-credit-injection')
end
return M
