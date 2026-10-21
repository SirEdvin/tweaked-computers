-- Labelled host-boundary fault injection beside real engine tests; not native metadata evidence.
local provider=require('scripts.services.recipe-searcher')
local M={}
function M.run(c,s)
  local original=prototypes
  local actual=original.recipe['tc-rs-item']
  local base={name=actual.name,category=actual.category,additional_categories=actual.additional_categories,
    energy=actual.energy,enabled=actual.enabled,hidden=actual.hidden,hidden_from_player_crafting=actual.hidden_from_player_crafting,
    hidden_from_flow_stats=actual.hidden_from_flow_stats,hidden_in_factoriopedia=actual.hidden_in_factoriopedia,
    ingredients=actual.ingredients,products=actual.products,surface_conditions={}}
  local function failure(code,change)
    local rec={}; for k,v in pairs(base) do rec[k]=v end; change(rec)
    prototypes=setmetatable({get_recipe_filtered=function() return {['tc-rs-item']=rec} end},{__index=original})
    local ok,e=pcall(provider.methods.findRecipes,c,s,'red',game.tick,function() end,'item','tc-rs-overlap')
    assert(not ok and type(e)=='table' and e.code==code,'expected '..code..': '..serpent.line(e))
  end
  local ok,e=pcall(function()
    failure('E_UNSUPPORTED',function(rec) rec.energy=math.huge end)
    failure('E_UNSUPPORTED',function(rec) rec.products={{type='item',name='tc-rs-overlap',probability=0/0,amount=1}} end)
    failure('E_UNSUPPORTED',function(rec) rec.ingredients={{type='fluid',name='water',amount=1,fluidbox_index=.5}} end)
    failure('E_UNSUPPORTED',function(rec) rec.surface_conditions={{property='pressure',min=math.huge}} end)
    failure('E_LIMIT',function(rec) rec.category=string.rep('x',16385) end)
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
