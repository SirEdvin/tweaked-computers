-- Paid tuple-capacity totals survive a cold boundary inside their own map scan.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local memory=require('scripts.runtime.memory')
local limits=require('scripts.runtime.limits')
local M={}; local loaded=false
local function step(f,tick,limited)
  local ctx=admission.context(f.ledger,'tuple-validation',tick); ctx.memory_owner=f.owner
  if limited then assert(admission.reserve(ctx,'work',limits.callback_work-256)) end
  return compiler.run(f.plan,'start',nil,function(g)
    return {computer={probe=function()
      local a,b,c=g.prepare_result(11,nil,13); f.effects=f.effects+1; return a,b,c
    end}}
  end,ctx,f.checkpoint)
end
local function frozen(f)
  local c=f.checkpoint; local v=c.validation
  assert(v==f.validation and v.head==f.head and v.queue[v.head].value==c.tuple_capacities
    and v.queue[v.head].key==f.key and v.tuple_count==f.count and v.tuple_sum==f.sum)
  assert(c.frame.pc==f.pc and c.wait_tick==f.tick and f.effects==f.sites)
  assert(f.ledger.total==f.spent and f.ledger.machines['tuple-validation'].work==f.work
    and f.account.used==f.used and f.owner.values[c].record.bytes==f.frame_bytes)
end
function M.run()
  local source='function start() '..string.rep('computer.probe();',100)..' while true do end end'
  local account=memory.new(1000000,256); local owner=memory.owner(account)
  local ledger=admission.new(); local ctx=admission.context(ledger,'tuple-validation',0); ctx.memory_owner=owner
  local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
  local f={phase='scan',plan=plan,checkpoint={},ledger=ledger,account=account,owner=owner,effects=0,slices=0,sites=100}
  local ok,e,control=step(f,0)
  assert(not ok and control=='wait' and f.effects==f.sites,e and e.message)
  local count=0; for _,width in pairs(f.checkpoint.tuple_capacities) do count=count+1; assert(width==3) end
  assert(count==f.sites and f.checkpoint.tuple_control==4)
  memory.configure(account,1); storage.tc_tuple_validation=f; game.speed=100
end
function M.on_load()
  local f=storage.tc_tuple_validation
  if f.phase=='frozen' then frozen(f); loaded=true; log('TC_TUPLE_VALIDATION_ON_LOAD_UNCHANGED') end
end
function M.on_tick(event)
  local f=storage.tc_tuple_validation
  if f.phase=='done' or f.phase=='frozen' and not loaded then return end
  if loaded then
    frozen(f)
    local ok,e,control=step(f,f.tick)
    assert(not ok and control=='wait',e and e.message); frozen(f)
    loaded=false; f.phase='resume'
  end
  if event.tick==f.checkpoint.wait_tick then return end
  f.slices=f.slices+1; assert(f.slices<2000,'tuple validation did not advance')
  local ok,e,control=step(f,event.tick,true)
  assert(not ok and control=='wait' and f.effects==f.sites,e and e.message)
  local c=f.checkpoint; local v=c.validation
  if f.phase=='scan' and v and v.tuple_count>0 and v.tuple_count<f.sites then
    local job=v.queue[v.head]
    if job and job.value==c.tuple_capacities and job.key~=nil then
      f.phase='frozen'; f.validation=v; f.head=v.head; f.key=job.key; f.count=v.tuple_count; f.sum=v.tuple_sum
      assert(f.sum==2*f.count)
      f.pc=c.frame.pc; f.tick=event.tick; f.spent=f.ledger.total; f.work=f.ledger.machines['tuple-validation'].work
      f.used=f.account.used; f.frame_bytes=f.owner.values[c].record.bytes
      game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
    end
  elseif f.phase=='resume' and v~=f.validation then
    assert(v==nil and c.preparation=='collect' and c.frame.pc==f.pc)
    assert(f.validation.tuple_count==f.sites and f.validation.tuple_sum==2*f.sites
      and f.owner.values[c].record.bytes==f.frame_bytes and f.account.used==f.used)
    memory.close(f.owner,function() end)
    assert(next(f.account.values)==nil and next(f.account.owners)==nil and f.account.reserved==0)
    f.phase='done'; log('TC_CONTRACT tuple-capacity-sum-cold-mid-map-no-paid-prefix-restart-or-guest-work')
    log('TC_COLD_OK')
  end
end
return M
