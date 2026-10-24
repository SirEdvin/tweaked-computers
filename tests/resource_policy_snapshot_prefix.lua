-- A suspended copy may not accumulate abandoned owned prefixes across retries.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local memory=require('scripts.runtime.memory')
local limits=require('scripts.runtime.limits')
local M={}
function M.run()
  local event={}; for i=1,128 do event[i]={i} end
  local source='function start(event) assert(#event==128); computer.finished() end'
  local account=memory.new(1000000,256); local owner=memory.owner(account)
  local ledger=admission.new(); local ctx=admission.context(ledger,'snapshot-prefix',0); ctx.memory_owner=owner
  local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
  local checkpoint,effects={},0
  local function services(g)
    return {computer={finished=function() g.prepare_empty_result(); effects=effects+1 end}}
  end
  local saw_prefix=false
  for tick=1,50 do
    ctx=admission.context(ledger,'snapshot-prefix',tick); ctx.memory_owner=owner
    assert(admission.reserve(ctx,'work',limits.callback_work-1024))
    local ok,e,control=compiler.run(plan,'start',event,services,ctx,checkpoint)
    assert(not ok and control=='wait' and effects==0,e and e.message)
    if #checkpoint.owned_order>0 then saw_prefix=true end
    assert(#checkpoint.owned_order<=#event,'abandoned snapshot prefixes accumulated across retries')
    assert(account.used+account.reserved<=account.limit)
  end
  assert(saw_prefix,'test did not enter partial Data copying')
  ctx=admission.context(ledger,'snapshot-prefix',51); ctx.memory_owner=owner
  local ok,e,control=compiler.run(plan,'start',event,services,ctx,checkpoint)
  for tick=52,60 do
    if ok then break end
    assert(control=='wait',e and e.message)
    ctx=admission.context(ledger,'snapshot-prefix',tick); ctx.memory_owner=owner
    ok,e,control=compiler.run(plan,'start',event,services,ctx,checkpoint)
  end
  assert(ok and effects==1,e and e.message)
  memory.close(owner,function() end)
  assert(next(account.values)==nil and next(account.owners)==nil and account.reserved==0)
  log('TC_CONTRACT abandoned-snapshot-prefixes-reclaim-before-retry-and-complete-once')
end
return M
