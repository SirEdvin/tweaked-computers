-- Exact private tuple/prepared-result storage across a separate-process boundary.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local memory=require('scripts.runtime.memory')
local limits=require('scripts.runtime.limits')
local M={}; local loaded=false
local function step(f,tick)
  local ctx=admission.context(f.ledger,'tuple-cold',tick); ctx.memory_owner=f.owner
  return compiler.run(f.plan,'start',nil,function(g)
    return {computer={probe=function()
      local a,b,c=g.prepare_result(11,nil,13); f.effects=f.effects+1
      assert(f.phase=='arm' and f.effects==1,'prepared effect replayed')
      assert(admission.reserve(ctx,'work',limits.callback_work-ctx.machine.work))
      assert(not pcall(g.spend,1)) -- Trusted fault injection returns the real result after poisoning.
      return a,b,c
    end,finished=function() g.prepare_empty_result(); f.finished=f.finished+1 end}}
  end,ctx,f.checkpoint)
end
local function frozen(f)
  local c=f.checkpoint; local p=c.frame.pending
  assert(p==f.pending and p.call_result==nil and p.service_result==p.prepared.called)
  assert(p.prepared.values.n==3 and p.prepared.values[1]==11 and p.prepared.values[2]==nil and p.prepared.values[3]==13)
  assert(p.prepared.called.n==4 and p.prepared.called[1]==true and p.prepared.called[2]==11
    and p.prepared.called[3]==nil and p.prepared.called[4]==13)
  assert(c.tuple_capacities==f.capacities and c.tuple_control==4 and f.owner.values[c].record.bytes==f.frame_bytes)
  assert(f.account.limit==1 and f.account.used==f.used and f.account.reserved==0)
  assert(f.ledger.total==f.spent and f.ledger.machines['tuple-cold'].work==f.work
    and c.wait_tick==f.tick and f.effects==1 and f.finished==0)
end
function M.run()
  local source='function start() local a,b,c=computer.probe(); assert(a==11 and b==nil and c==13); computer.finished() end'
  local account=memory.new(1000000,256); local owner=memory.owner(account)
  local ledger=admission.new(); local ctx=admission.context(ledger,'tuple-cold',0); ctx.memory_owner=owner
  local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
  storage.tc_tuple_cold={phase='arm',plan=plan,checkpoint={},ledger=ledger,account=account,owner=owner,effects=0,finished=0}
  game.speed=100
end
function M.on_load()
  local f=storage.tc_tuple_cold
  if f.phase=='frozen' then frozen(f); loaded=true; log('TC_TUPLE_ON_LOAD_UNCHANGED') end
end
function M.on_tick(event)
  local f=storage.tc_tuple_cold
  if f.phase=='done' or f.phase=='frozen' and not loaded then return end
  if loaded then
    frozen(f)
    local ok,e,control=step(f,f.tick)
    assert(not ok and control=='wait',e and e.message); frozen(f)
    loaded=false; f.phase='resume'
  end
  local ok,e,control=step(f,event.tick)
  assert(ok or control=='wait',e and e.message)
  if f.phase=='arm' then
    local c=f.checkpoint; local p=c.frame.pending
    assert(not ok and p and p.call_result==nil and p.service_result==p.prepared.called)
    assert(f.effects==1 and f.finished==0 and c.tuple_control==4)
    f.tick=event.tick; f.pending=p; f.capacities=c.tuple_capacities
    f.frame_bytes=f.owner.values[c].record.bytes; f.used=f.account.used
    f.spent=f.ledger.total; f.work=f.ledger.machines['tuple-cold'].work
    memory.configure(f.account,1); f.phase='frozen'; frozen(f)
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  assert(event.tick-f.tick<100,'tuple result did not resume after lowered allowance')
  assert(f.account.used<=f.used and f.effects==1)
  if ok then
    assert(f.finished==1)
    memory.close(f.owner,function() end)
    assert(next(f.account.values)==nil and next(f.account.owners)==nil and f.account.reserved==0)
    f.phase='done'; log('TC_CONTRACT prepared-nil-tuple-frame-envelope-cold-no-redelivery-or-credit-renewal')
    log('TC_COLD_OK')
  end
end
return M
