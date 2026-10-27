-- Host-only impossible metadata/exception injection; native evidence is separate.
local provider=require('scripts.services.factoriopedia-interface')
local M={}
function M.run(c,s)
  local original=prototypes; local item=original.item['iron-plate']
  local function refused(code,fn,...)
    local ok,e=pcall(fn,c,s,'red',game.tick,function() end,...)
    assert(not ok and type(e)=='table' and e.code==code,serpent.line(e))
  end
  local ok,e=pcall(function()
    for _,field in ipairs({'weight','fuel_value','stack_size','spoil_ticks','default_rocket_lift_weight'}) do
      local proxy=setmetatable({},{__index=function(_,key)
        if key==field then return math.huge end
        if key=='get_spoil_ticks' and field=='spoil_ticks' then return function() return math.huge end end
        return item[key]
      end})
      prototypes=setmetatable({item={['iron-plate']=proxy},utility_constants={default_rocket_lift_weight=field=='default_rocket_lift_weight' and math.huge or original.utility_constants.default_rocket_lift_weight}},{__index=original})
      refused('E_UNSUPPORTED',provider.methods.getItem,'iron-plate')
    end
    prototypes=setmetatable({item=setmetatable({},{__index=function() error('injected native access') end})},{__index=original})
    refused('E_ENGINE',provider.methods.getItem,'iron-plate')
    prototypes=setmetatable({item=setmetatable({},{__pairs=function() error('injected native enumeration') end})},{__index=original})
    refused('E_ENGINE',provider.methods.listItems)
    prototypes=setmetatable({item={},fluid={}},{__index=original})
    assert(#provider.methods.listItems(c,s,'red',game.tick,function() end)==0)
    assert(#provider.methods.listFluids(c,s,'red',game.tick,function() end)==0)
    prototypes=setmetatable({item=setmetatable({},{__pairs=function()
      local names={'z','a','Z'}; local i=0
      return function() i=i+1; return names[i],item end
    end})},{__index=original})
    local names=provider.methods.listItems(c,s,'red',game.tick,function() end)
    assert(#names==3 and names[1]=='Z' and names[2]=='a' and names[3]=='z')
    local entered=false; local token={private='refused-work'}
    prototypes=setmetatable({item=setmetatable({},{__index=function() entered=true; return item end})},{__index=original})
    local accepted,problem=pcall(provider.methods.getItem,c,s,'red',game.tick,function() error(token,0) end,'iron-plate')
    assert(not accepted and problem==token and not entered)
    local scans=0
    prototypes=setmetatable({item=setmetatable({['iron-plate']=item},{__pairs=function() scans=scans+1; error('lookup enumerated catalogue') end})},{__index=original})
    local work=0; provider.methods.getItem(c,s,'red',game.tick,function(n) work=work+n end,'iron-plate')
    assert(scans==0 and work>0)
  end)
  prototypes=original
  if not ok then error(e,0) end
  log('TC_FACT host-only-unsupported-native-failure-empty-and-zero-credit')
end
return M
