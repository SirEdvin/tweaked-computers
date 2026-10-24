-- Real host ledger, native registry lifetimes and policy-v2 calls through an owned VM.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local compiler=require('scripts.runtime.compiler')

local memory=require('scripts.runtime.memory')
local policy=require('scripts.runtime.resource-policy')
local budgets=require('scripts.runtime.budget-settings')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local M={}; local loaded=false
local function spend(n) local f=storage.tc_host_policy; f.actions=f.actions+n end
local function radar(x)
  local body=game.surfaces[1].create_entity{name='radar',position={x,0},force=game.forces.player}
  assert(body and body.valid)
  local rec=registry.register('radar',body)
  rec.modem={version=1,channels={},count=0}
  return rec
end
runtime.register_services('host-policy-fixture',function(rec,tick,g)
  return {computer={hostHold=function()
    local f=storage.tc_host_policy; local target=registry.record(f.target)
    g.prepare_empty_result()
    g.host_resize('radar-channels:'..target.id,160)
    target.modem.channels[9]=true; target.modem.count=1; f.effects=f.effects+1
  end,checked=function() g.prepare_empty_result(); storage.tc_host_policy.finished=true end}}
end)
local function exact(value,allowed)
  for key in pairs(value) do assert(allowed[key],'unexpected schema field '..key) end
end
local function snapshots(rec,tick)
  local out=policy.limits()
  assert(out.policy_version==2 and out.table_entries==nil and out.signal_slots==nil)
  for _,d in ipairs(budgets.definitions) do
    local entry=(d.kind=='tuning' and out.tuning or out.resources)[d.key]
    assert(entry.limit==limits[d.key] and entry.setting==d.name and entry.unit==d.unit and entry.scope==d.scope)
    if d.kind=='tuning' then assert(entry.kind=='tuning') else assert(entry.behavior==d.behavior) end
  end
  out.resources.callback_work.limit=-1
  assert(policy.limits().resources.callback_work.limit==limits.callback_work)
  local used=registry.get().ledger.total
  local status=policy.status(rec,tick)
  assert(registry.get().ledger.total==used,'status renewed or spent execution credits')
  exact(status,{policy_version=true,state=true,wait=true,resources=true,dropped_events=true,last_refusal=true})
  for _,entry in pairs(status.resources) do
    exact(entry,{used=true,limit=true,unit=true,scope=true,setting=true,over_limit=true})
    assert(entry.over_limit==(entry.used>entry.limit))
  end
  assert(status.resources.host_memory_bytes==nil and status.resources.runtime_memory_bytes==nil
    and status.resources.pending_work_bytes==nil,'unenrolled resources reported fictional usage')
  status.dropped_events.total=-1; status.resources.state_bytes.used=-1
  assert(policy.status(rec,tick).dropped_events.total>=0 and rec.state_bytes>=0)
end
function M.run()
  storage.tc_host_policy={actions=0,effects=0,phase='arm'}
  local f=storage.tc_host_policy; local root=registry.initialize()
  local target=radar(5); f.target=target.id
  local before=limits.host_memory_bytes; limits.host_memory_bytes=1
  local ok,e=pcall(policy.host_resize,'radar-channels:'..target.id,160,spend)
  assert(not ok and errors.resource_diagnostic(e) and root.host_memory==nil and target.modem.count==0,
    'empty host-account metadata bypassed capacity before publication')
  target.modem.channels[7]=true; target.modem.count=1
  local stop={}
  ok,e=pcall(policy.host_account,function() error(stop,0) end)
  assert(not ok and e==stop and root.host_memory==nil,'unpaid enrollment published a ledger')
  local account,owner=policy.host_account(spend)
  assert(account.resource=='host_memory' and account.limit==1 and account.used>1
    and owner.values[target.modem.channels] and target.host_channels==target.modem.channels)
  local used,count=account.used,owner.count
  ok,e=pcall(policy.host_resize,'radar-channels:'..target.id,192,spend)
  assert(not ok and errors.resource_diagnostic(e) and e.resource=='host_memory' and e.setting=='tc-host-memory-bytes')
  f.refusal=errors.resource_diagnostic(e)
  assert(account.used==used and owner.count==count and target.modem.channels[7] and target.modem.count==1)
  policy.host_resize('radar-channels:'..target.id,160,spend)
  assert(account.used==used,'same-size grandfathered publication charged again')
  policy.host_resize('radar-channels:'..target.id,0,spend)
  target.modem.channels={}; target.modem.count=0
  assert(owner.count==0 and next(account.values)==nil)
  limits.host_memory_bytes=before
  policy.host_account(spend)
  f.host_base=account.used
  local body=game.surfaces[1].create_entity{name='constant-combinator',position={0,0},force=game.forces.player}
  local rec=registry.register('computer',body); f.computer=rec.id
  local source=[[function start()
    local l=computer.getLimits()
    assert(l.policy_version==2 and l.table_entries==nil and l.callback_work==nil)
    assert(l.resources.callback_work.setting=='tc-callback-work')
    l.resources.callback_work.limit=-1
    assert(computer.getLimits().resources.callback_work.limit>0)
    local s=computer.getResourceStatus()
    assert(s.policy_version==2 and s.resources.runtime_memory_bytes==nil)
    assert(s.dropped_events.total==0 and not s.dropped_events.saturated)
    assert(select('#',computer.getResourceStatus())==1)
    computer.hostHold()
    local n=0; while n<300000 do n=n+1 end
    computer.checked()
  end]]
  runtime.save(rec.id,source,0)
  local run,problem=runtime.activate(rec.id,0); assert(run,problem and problem.message)
  runtime.resource_refused(rec,f.refusal,0)
  f.account=memory.new(limits.runtime_memory_bytes,256); f.owner=memory.owner(f.account)
  snapshots(rec,0)
  local old=limits.state_bytes; limits.state_bytes=1
  local status=policy.status(rec,0)
  assert(status.resources.state_bytes.over_limit and rec.state_bytes==16)
  limits.state_bytes=old
  log('TC_CONTRACT host-domain-legacy-debt-atomic-refusal-shrink-and-exact-policy-snapshots')
end
local function unchanged(f)
  local root=registry.get(); local target=registry.record(f.target)
  assert(root.host_memory.used==f.host_used and root.host_memory_owner.values[target.modem.channels]
    and target.host_channels==target.modem.channels and target.modem.channels[9] and target.modem.count==1)
  assert(f.account.used==f.used and f.owner.values[registry.computer(f.computer).invocation.checkpoint]
    and f.effects==1 and not f.finished)
end
function M.on_load()
  local f=storage.tc_host_policy
  if f.phase=='frozen' then unchanged(f); loaded=true; log('TC_HOST_POLICY_ON_LOAD_UNCHANGED') end
end
function M.on_tick(event)
  local f=storage.tc_host_policy
  if f.phase=='done' or f.phase=='frozen' and not loaded then return end
  if loaded then unchanged(f); loaded=false; f.phase='resume' end
  local rec=registry.computer(f.computer); local invocation=rec.invocation
  local ctx=runtime.context(rec,event.tick); ctx.memory_owner=f.owner
  local ok,e,control=compiler.run(rec.active,'start',invocation.item.event,function(g)
    return runtime.services(rec,event.tick,g)
  end,ctx,invocation.checkpoint)
  assert(ok or control=='wait',e and e.message)
  if f.phase=='arm' and f.effects==1 then
    assert(not ok and control=='wait'); f.tick=event.tick; f.used=f.account.used
    f.host_used=registry.get().host_memory.used; f.phase='frozen'; unchanged(f)
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  if f.phase=='resume' then assert(event.tick-f.tick<300,'host ownership continuation deadline') end
  if not ok then return end
  assert(f.effects==1 and f.finished)
  rec.invocation=nil; memory.close(f.owner,spend)
  local root=registry.get(); local target=registry.record(f.target)
  local value=target.modem.channels
  assert(runtime.stop(rec.id) and root.host_memory_owner.values[value],'computer Stop released a shared host owner')
  snapshots(rec,event.tick)
  local status=policy.status(rec,event.tick)
  assert(status.state=='stopped' and status.last_refusal.setting=='tc-host-memory-bytes')
  exact(status.last_refusal,{code=true,message=true,resource=true,setting=true,used=true,requested=true,
    limit=true,recoverable=true,line=true,column=true})
  target.modem={version=1,channels={},count=0}
  for _=1,#root.order do policy.reconcile(root,spend) end
  assert(not target.host_channels and not root.host_memory_owner.values[value] and root.host_memory.used==f.host_base)
  policy.host_resize('radar-channels:'..target.id,160,spend)
  target.modem.channels[10]=true; target.modem.count=1
  assert(registry.remove(target.id,'test-removal') and root.host_memory.used==f.host_base
    and root.host_memory_owner.count==0,'registry removal leaked its host allocation')
  assert(f.account.used==512 and f.account.reserved==0)
  f.phase='done'; log('TC_CONTRACT real-guard-host-owner-cold-stop-reset-and-removal'); log('TC_COLD_OK')
end
return M
