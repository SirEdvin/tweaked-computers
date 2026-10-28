-- Explicit host doubles only for inaccessible native faults/nonfinite values.
local provider=require('scripts.services.production-statistics')
local M={}
function M.run()
  local function refuse(code,method,rec,...)
    local ok,e=pcall(provider.methods[method],nil,rec,'red',game.tick,function() end,...)
    assert(not ok and type(e)=='table' and e.code==code,serpent.line(e))
  end
  local broken={body=setmetatable({},{__index=function() error('injected native getter failure') end})}
  refuse('E_ENGINE','getTotals',broken,'item')
  local nonfinite={input_counts={['stone-furnace']=math.huge},output_counts={}}
  local rec={body={surface={pollution_statistics=nonfinite}}}
  refuse('E_UNSUPPORTED','getTotals',rec,'pollution')
  nonfinite.input_counts={['stone-furnace']=1}
  nonfinite.get_flow_count=function() return math.huge end
  refuse('E_UNSUPPORTED','getRates',rec,'pollution','one_minute')
  nonfinite.get_flow_count=function() error('injected native flow failure') end
  refuse('E_ENGINE','getRates',rec,'pollution','one_minute')
  local entered=false; local token={private='work-refusal'}
  local gate={body=setmetatable({},{__index=function() entered=true; error('unadmitted native entry') end})}
  local ok,e=pcall(provider.methods.getTotals,nil,gate,'red',game.tick,function() error(token,0) end,'item')
  assert(not ok and e==token and not entered)
  log('TC_STAT host-double-native-error-nonfinite-and-uncaught-budget')
end
return M
