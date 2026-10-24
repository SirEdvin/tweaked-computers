-- Preparation owns its prepaid peak until destination ownership is delivered.
local memory=require('scripts.runtime.memory')
local admission=require('scripts.runtime.admission')
local sandbox=require('scripts.runtime.sandbox')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local M={}
local loaded=false
local function setup()
  local account=memory.new(1000000,256)
  local target,job,other=memory.owner(account),memory.owner(account),memory.owner(account)
  local values={{value='first'},{value='second'},'shared'}
  local bytes={192,192,32+#values[3]}
  for i,value in ipairs(values) do memory.acquire(job,value,bytes[i]) end
  local before=account.used
  memory.acquire(target,values[1],bytes[1])
  local link=account.used-before
  assert(link>0); memory.release(target,values[1]); assert(account.used==before)
  memory.reserve(job,link*#values)
  memory.configure(account,account.used+account.reserved)
  local reserved,total=job.reserved,account.used+account.reserved
  local ok,problem=pcall(memory.acquire,other,values[1],bytes[1])
  assert(not ok and errors.resource_diagnostic(problem) and job.reserved==reserved and not other.values[values[1]],
    'unrelated allocation stole another job reservation')
  memory.configure(account,1)
  return {account=account,target=target,job=job,other=other,values=values,bytes=bytes,
    cursor=1,ledger=admission.new(),total=total,link=link,actions=0}
end
local function transfer(f,tick,credit)
  local ctx=admission.context(f.ledger,'memory-handoff',tick)
  if credit then assert(admission.reserve(ctx,'work',limits.callback_work-credit)) end
  local guard=sandbox.new(ctx,{})
  local ok,problem=pcall(function()
    while f.cursor<=#f.values do
      guard.spend(1)
      local value=f.values[f.cursor]
      memory.acquire(f.target,value,f.bytes[f.cursor],f.job)
      assert(f.target.values[value] and f.job.values[value] and f.account.used+f.account.reserved==f.total)
      f.actions=f.actions+1; f.cursor=f.cursor+1
    end
  end)
  assert(ok or guard.work_suspended(),type(problem)=='table' and problem.message or tostring(problem))
  return ok
end
function M.run()
  local atomic=memory.new(4096,0); local base=atomic.used
  local probe=memory.owner(atomic); local owner_bytes=atomic.used-base
  memory.close(probe,function() end)
  local next_id=atomic.next_id; local available=atomic.limit-atomic.used-owner_bytes
  local ok,problem=pcall(memory.owner,atomic,available+1)
  assert(not ok and errors.resource_diagnostic(problem) and atomic.used==base and atomic.reserved==0
    and atomic.next_id==next_id and next(atomic.owners)==nil,'failed prepaid job left an owner or consumed identity')
  assert(not pcall(memory.owner,atomic,false) and atomic.next_id==next_id,'invalid reservation silently defaulted')
  local admitted=memory.owner(atomic,available)
  assert(admitted.reserved==available and atomic.used+atomic.reserved==atomic.limit)
  memory.close(admitted,function() end); assert(atomic.used==base and atomic.reserved==0)
  local large=memory.new(9007199254740991,0)
  local ok,problem=pcall(memory.owner,large,9007199254740991)
  assert(not ok and errors.resource_diagnostic(problem) and next(large.owners)==nil,'native-range reservation overflow was not refused atomically')
  log('TC_CONTRACT job-owner-and-peak-admission-are-atomic')
  local refused=setup()
  memory.unreserve(refused.job,refused.job.reserved-refused.link+1)
  local used,reserved=refused.account.used,refused.account.reserved
  local ok,problem=pcall(memory.acquire,refused.target,refused.values[1],refused.bytes[1],refused.job)
  assert(not ok and errors.resource_diagnostic(problem) and refused.account.used==used
    and refused.account.reserved==reserved and refused.job.reserved==reserved
    and refused.target.count==0 and not refused.target.values[refused.values[1]],'failed handoff consumed credits or published ownership')
  memory.close(refused.job,function() end); memory.close(refused.target,function() end); memory.close(refused.other,function() end)
  assert(refused.account.reserved==0 and next(refused.account.values)==nil)
  local f=setup()
  assert(transfer(f,0) and f.actions==#f.values and f.job.reserved==0,
    'accepted peak could not fund ownership after a settings decrease')
  local used=f.account.used
  memory.acquire(f.target,f.values[1],f.bytes[1],f.job)
  assert(f.account.used==used and f.job.reserved==0,'shared adoption double-charged a payload/link')
  local foreign=memory.owner(memory.new(4096,0))
  local ok=pcall(memory.resize,f.target,f.values[1],f.bytes[1],foreign)
  assert(not ok and f.account.used==used,'foreign account funded local ownership')
  memory.close(foreign,function() end)
  assert(not pcall(memory.resize,f.target,f.values[1],f.bytes[1],foreign),'closed preparation still sponsored ownership')
  local credit=1; local stop={}
  assert(not pcall(memory.close,f.job,function() if credit==0 then error(stop,0) end; credit=credit-1 end))
  assert(f.job.closing and not f.job.closed)
  assert(not pcall(memory.resize,f.target,f.values[1],f.bytes[1],f.job),'closing preparation still sponsored ownership')
  memory.close(f.job,function() end)
  for _,value in ipairs(f.values) do assert(f.target.values[value] and f.account.values[value]) end
  memory.close(f.target,function() end); memory.close(f.other,function() end)
  assert(next(f.account.values)==nil and next(f.account.owners)==nil and f.account.reserved==0)
  log('TC_CONTRACT reserved-job-peak-funds-shared-handoff-without-stealing-or-double-charge')
  storage.tc_memory_handoff=setup(); storage.tc_memory_handoff.phase='armed'
end
function M.on_load()
  local f=storage.tc_memory_handoff
  if f.phase=='frozen' then
    assert(f.cursor==2 and f.actions==1 and f.account.used==f.used and f.job.reserved==f.reserved and f.ledger.total==f.spent)
    loaded=true; log('TC_MEMORY_HANDOFF_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  local f=storage.tc_memory_handoff
  if f.phase=='done' or f.phase=='frozen' and not loaded then return end
  if f.phase=='armed' then
    assert(not transfer(f,event.tick,1) and f.cursor==2 and f.actions==1)
    f.phase='frozen'; f.tick=event.tick; f.used=f.account.used; f.reserved=f.job.reserved; f.spent=f.ledger.total
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  else
    if loaded then
      assert(not transfer(f,f.tick) and f.cursor==2 and f.actions==1 and f.account.used==f.used and f.job.reserved==f.reserved)
      loaded=false
    end
    assert(transfer(f,event.tick) and f.cursor==#f.values+1 and f.actions==#f.values and f.job.reserved==0)
    memory.close(f.job,function() end)
    for _,value in ipairs(f.values) do assert(f.target.values[value]) end
    memory.close(f.target,function() end); memory.close(f.other,function() end)
    assert(next(f.account.owners)==nil and next(f.account.values)==nil and f.account.reserved==0)
    f.phase='done'; log('TC_CONTRACT memory-handoff-cold-exact-cursor-and-credits'); log('TC_COLD_OK')
  end
end
return M
