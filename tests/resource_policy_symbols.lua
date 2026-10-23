-- Static source symbols remain paid; dynamic paths are admitted before publication.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local memory=require('scripts.runtime.memory')
local M={}
function M.run()
  local body=[[local key=string.char(102,108,111,111,114); local floor=math[key]
    local n=0; while n<300000 do n=n+1 end
    assert(floor(1.5)==1); computer.finished()]]
  for _,source in ipairs({'function start() '..body..' end','return {api_version=1,handlers={start=function() '..body..' end}}'}) do
    local account=memory.new(1000000,256); local owner=memory.owner(account)
    local ledger=admission.new(); local ctx=admission.context(ledger,'symbol-lifetime',0); ctx.memory_owner=owner
    local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
    local checkpoint,effects={},0
    local function services(g)
      return {computer={finished=function() g.prepare_empty_result(); effects=effects+1 end}}
    end
    local ok,e,control=compiler.run(plan,'start',nil,services,ctx,checkpoint)
    assert(not ok and control=='wait',e and e.message)
    assert(type(checkpoint.symbol_roots)=='table' and #checkpoint.symbol_roots>0,'source symbol pool missing')
    for _,token in ipairs(checkpoint.symbol_roots) do
      assert(owner.values[token] and owner.values[checkpoint.symbols[token]],'source symbol bypassed retained admission')
    end
    local dynamic=assert(checkpoint.intern['math.floor'],'computed namespace path missing')
    local future=assert(checkpoint.intern['computer.finished'],'future source path was not prepaid')
    assert(owner.values[dynamic] and owner.values['math.floor'] and owner.values[future])
    local used,spent=account.used,ledger.total
    memory.configure(account,1)
    ok,e,control=compiler.run(plan,'start',nil,services,ctx,checkpoint)
    assert(not ok and control=='wait' and account.used==used and ledger.total==spent and effects==0)
    for tick=1,100 do
      ctx=admission.context(ledger,'symbol-lifetime',tick); ctx.memory_owner=owner
      ok,e,control=compiler.run(plan,'start',nil,services,ctx,checkpoint)
      assert(ok or control=='wait',e and e.message)
      assert(account.used<=used and owner.values[future] and owner.values['computer.finished'])
      if ok then break end
    end
    assert(ok and effects==1 and account.limit==1,'paid source path could not execute after a decrease')
    memory.close(owner,function() end)
    assert(next(account.values)==nil and next(account.owners)==nil and account.reserved==0)
  end
  log('TC_CONTRACT prepaid-source-and-dynamic-symbols-survive-collection-and-lowered-limit')
end
return M
