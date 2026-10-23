-- Host snapshots expose measured counters only; absent accounting is not zero use.
local registry=require('scripts.registry')
local limits=require('scripts.runtime.limits')
local budgets=require('scripts.runtime.budget-settings')
local memory=require('scripts.runtime.memory')
local errors=require('scripts.runtime.errors')
local M={}
local MAX=9007199254740991
local definitions={}
for _,d in ipairs(budgets.definitions) do definitions[d.key]=d end
local refusal_fields={'code','message','resource','setting','used','requested','limit','recoverable','line','column'}
local function refusal(value)
  if type(value)~='table' or not value.recoverable then return end
  local out={}; for _,key in ipairs(refusal_fields) do out[key]=value[key] end
  return out
end
function M.limits(selected)
  local out={policy_version=2,resources={},tuning={}}
  for _,d in ipairs(budgets.definitions) do
    if not selected or selected[d.key] then
      local entry={limit=limits[d.key],unit=d.unit,scope=d.scope,setting=d.name}
      if d.kind=='tuning' then entry.kind='tuning'; out.tuning[d.key]=entry
      else entry.behavior=d.behavior; out.resources[d.key]=entry end
    end
  end
  return out
end
function M.status(rec,tick)
  assert(errors.integer(tick,0,MAX),'invalid status tick')
  local out={policy_version=2,state=rec.status,resources={},dropped_events={total=0,saturated=false},
    last_refusal=refusal(rec.resource_refusal)}
  local pending=rec.invocation or rec.shell and rec.shell.invocation
  local queued=rec.shell and rec.shell.pending and #rec.shell.pending>0
  if rec.status~='faulted' then
    if pending or queued then out.state='waiting'
    elseif rec.diagnostic and rec.diagnostic.recoverable then out.state='resource_refused'
    elseif rec.status=='running' then out.state=#rec.queue>0 and 'running' or 'idle' end
  end
  if rec.status=='stopped' and not pending and not queued then out.state='stopped' end
  local drops=rec.dropped_events
  if drops then
    for _,key in ipairs({'total','saturated','last_tick','last_kind','last_reason'}) do out.dropped_events[key]=drops[key] end
  end
  local function measured(key,used)
    if used==nil then return end
    local d=assert(definitions[key]); local limit=limits[key]
    out.resources[key]={used=used,limit=limit,unit=d.unit,scope=d.scope,setting=d.name,over_limit=used>limit}
  end
  measured('state_bytes',rec.state_bytes)
  measured('event_queue_entries',rec.queue and #rec.queue)
  measured('event_queue_bytes',rec.queue_bytes)
  measured('console_entries',rec.logs and #rec.logs)
  measured('console_bytes',rec.log_bytes)
  local root=registry.get(); local ledger=root and root.ledger
  if ledger then
    local machine=ledger.tick==tick and ledger.machines[rec.id]
    measured('callback_work',machine and machine.work or 0)
    measured('compile_work',machine and machine.compile or 0)
    measured('callback_allocations',machine and machine.allocations or 0)
    local s=root.scheduler
    local maintenance=s and s.maintenance_tick==tick and s.maintenance_spent or 0
    measured('maintenance_work_per_tick',maintenance)
    measured('host_work_per_tick',(ledger.tick==tick and ledger.total or 0)+maintenance)
  end
  -- Runtime, total host, pending, shell and draft bytes await complete domain enrollment.
  return out
end
-- Fixed control metadata is available even when the configured growth limit is one.
function M.runtime_account(rec)
  local account=rec.runtime_memory
  if not account then
    account=memory.new(8448,8192)
    memory.configure(account,limits.runtime_memory_bytes)
    rec.runtime_memory=account
  else
    assert(account.version==1 and (account.resource==nil or account.resource=='runtime_memory'),'invalid runtime account')
    memory.configure(account,limits.runtime_memory_bytes)
  end
  return account
end
function M.attach(rec,invocation,context)
  local account=M.runtime_account(rec)
  local owner=invocation.memory_owner
  if owner then
    if owner.account~=account or owner.closed or owner.closing or account.owners[owner.id]~=owner then
      errors.raise('E_UNSUPPORTED','invalid invocation ownership; retained')
    end
  else
    if invocation.checkpoint.version~=nil then errors.raise('E_UNSUPPORTED','legacy unowned continuation; source retained') end
    owner=memory.owner(account); invocation.memory_owner=owner
  end
  context.memory_owner=owner
  return owner
end
function M.release(invocation)
  if invocation then memory.retire(invocation.memory_owner) end
end
function M.collect_runtime(rec,spend)
  if rec.runtime_memory then memory.collect(rec.runtime_memory,spend) end
end
local function channel_bytes(rec,spend)
  local s=rec.modem
  if type(s)~='table' or getmetatable(s) or s.version~=1 or type(s.channels)~='table' or getmetatable(s.channels)
    or not errors.integer(s.count,0,MAX) then errors.raise('E_UNSUPPORTED','invalid retained channel state; preserved') end
  local count=0
  for key,value in pairs(s.channels) do
    spend(1)
    if not errors.integer(key,0,MAX) or value~=true then errors.raise('E_UNSUPPORTED','invalid retained channel; preserved') end
    count=count+1
  end
  if count~=s.count then errors.raise('E_UNSUPPORTED','retained channel count mismatch; preserved') end
  return count==0 and 0 or 128+32*count
end
function M.host_account(spend)
  local root=registry.get()
  assert(registry.supported(root),'unsupported host storage')
  assert(root.host_memory~=nil or root.host_memory_owner==nil,'missing host memory account')
  if root.host_memory then
    local owner=root.host_memory_owner
    assert(root.host_memory.resource=='host_memory' and owner and owner.account==root.host_memory
      and not owner.closed and not owner.closing,'invalid host memory ownership')
    memory.configure(root.host_memory,limits.host_memory_bytes)
    return root.host_memory,owner
  end
  -- Enroll already accepted legacy state as debt, not new growth under today's limit.
  local retained={}
  for _,id in ipairs(root.order) do
    spend(1)
    local rec=root.devices[id]
    if rec and rec.kind=='radar' then
      local bytes=channel_bytes(rec,spend)
      if bytes>0 then retained[#retained+1]={rec=rec,value=rec.modem.channels,bytes=bytes*2+48} end
    end
  end
  spend(#retained*4+4)
  local account=memory.new(#retained>0 and MAX or limits.host_memory_bytes,0,'host_memory')
  local owner=memory.owner(account)
  for _,item in ipairs(retained) do memory.acquire(owner,item.value,item.bytes) end
  memory.configure(account,limits.host_memory_bytes)
  root.host_memory=account; root.host_memory_owner=owner
  for _,item in ipairs(retained) do item.rec.host_channels=item.value end
  return account,owner
end
function M.host_resize(key,bytes,spend)
  assert(type(key)=='string' and errors.integer(bytes,0,math.floor((MAX-48)/2))
    and (bytes==0 or bytes>=160 and (bytes-128)%32==0),'invalid channel memory estimate')
  local id=key:match('^radar%-channels:(tc%-%d+)$')
  local rec=id and registry.record(id)
  if not rec or rec.kind~='radar' then errors.raise('E_UNSUPPORTED','unknown host memory owner') end
  local _,owner=M.host_account(spend)
  spend(4)
  local channels=rec.modem.channels
  if rec.host_channels and rec.host_channels~=channels then
    memory.release(owner,rec.host_channels); rec.host_channels=nil
  end
  if bytes==0 then
    if rec.host_channels then memory.release(owner,rec.host_channels); rec.host_channels=nil end
    return
  end
  -- Radio estimates 128+32/channel; double it to cover table slots plus the record's alias.
  memory.acquire(owner,channels,bytes*2+48)
  rec.host_channels=channels
end
-- One registry identity per maintenance slice; reset cleanup never scans the world.
function M.reconcile(root,spend)
  if not root.host_memory then return end
  memory.configure(root.host_memory,limits.host_memory_bytes)
  local n=#root.order
  if n==0 then return end
  spend(2)
  local index=math.min(root.scheduler.host_memory_cursor or 1,n)
  local rec=registry.record(root.order[index])
  if rec and rec.host_channels and (not rec.modem or rec.host_channels~=rec.modem.channels) then
    memory.release(root.host_memory_owner,rec.host_channels); rec.host_channels=nil
  end
  root.scheduler.host_memory_cursor=index%n+1
end
return M
