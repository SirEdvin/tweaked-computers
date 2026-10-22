-- Existing library-created tables exercise retention without adding heap syntax.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local ownership=require('scripts.runtime.ownership')
local M={}
function M.run()
  local ledger=admission.new(); local effects={}
  local source=[[function start()
    local n=0
    while n<10000 do
      local t=table.pack(n); rawset(t,'self',t); n=n+1
    end
    computer.log(n)
  end]]
  local plan,e=compiler.compile(source,admission.context(ledger,'churn',0)); assert(plan,e and e.message)
  local checkpoint={}; local tick=1
  repeat
    local ok,problem,control=compiler.run(plan,'start',{}, {computer={log=function(v) effects[#effects+1]=v end}},
      admission.context(ledger,'churn',tick),checkpoint)
    assert(ok or control=='wait',problem and problem.message)
    assert(tick<500,'ownership validation/collection starved guest progress')
    tick=tick+1
    if ok then break end
  until false
  assert(tick>2 and #effects==1 and effects[1]==10000)
  local slots,locals=0,0
  for key in pairs(checkpoint.frame.slots) do slots=math.max(slots,key) end
  for key in pairs(checkpoint.frame.tuples) do slots=math.max(slots,key) end
  for key in pairs(checkpoint.frame.locals) do locals=math.max(locals,key) end
  ownership.begin(checkpoint,{slots=slots,locals=locals})
  ownership.advance(checkpoint,function() end)
  assert(next(checkpoint.frame.locals)==nil and next(checkpoint.frame.slots)==nil and next(checkpoint.frame.tuples)==nil,
    'dead frame slots retained completed values')
  assert(#checkpoint.owned_order==1,'discarded library tables/cycles remain strongly retained')
  checkpoint.frame.locals={}; checkpoint.frame.slots={}; checkpoint.frame.tuples={}; checkpoint.frame.event=nil
  ownership.begin(checkpoint,{slots=0,locals=0})
  ownership.advance(checkpoint,function() end)
  assert(#checkpoint.owned_order==0 and next(checkpoint.bindings)==nil and next(checkpoint.symbols)==nil)
  log('TC_CONTRACT guest-allocation-churn-reclaims-indices-and-cycles')
end
return M
