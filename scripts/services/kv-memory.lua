-- KV lifecycle owners share the host account; never borrow the radar owner.
local registry=require('scripts.registry')
local policy=require('scripts.runtime.resource-policy')
local memory=require('scripts.runtime.memory')
local graphs=require('scripts.runtime.private-jobs')
local limits=require('scripts.runtime.limits')
local M={}
local MAX=9007199254740991
local function noop() end
local function state()
  local root=registry.get()
  root.kv_memory=root.kv_memory or {live={},jobs={},retired={}}
  return root.kv_memory
end
local function peak(d,payload,arguments)
  -- Includes graph records/links, graph-admission vectors and private index copies.
  return 16384+d.bytes*2+#d.order*8192+d.fields*4096+(payload or 0)*2+(arguments or 0)*4096
end
local function graph(owner,value,spend)
  graphs.admit({owned={},symbols={},bindings={},functions={}},owner,value,spend)
end
function M.ensure(rec,spend)
  local s=state(); local account=policy.host_account(spend)
  local live=s.live[rec.id]
  if live and live.value==rec.database and live.revision==(rec.kv_revision or 0) then return live.owner end
  if live and live.value==rec.database then
    memory.resize(live.owner,rec.database.entries,192+48*#rec.database.order)
    memory.resize(live.owner,rec.database.order,192+48*#rec.database.order)
  end
  -- Legacy inventory and reclamation are already accepted, not new admission.
  memory.configure(account,MAX)
  local owner
  local ok,problem=pcall(function()
    owner=memory.owner(account,peak(rec.database))
    graph(owner,rec.database,spend)
    memory.unreserve(owner)
  end)
  memory.configure(account,limits.host_memory_bytes)
  if not ok then if owner then memory.close(owner,noop) end; error(problem,0) end
  if live then s.retired[live.owner.id]=live.owner end
  s.live[rec.id]={owner=owner,value=rec.database,revision=rec.kv_revision or 0}
  return owner
end
function M.begin(rec,computer,payload,arguments,spend)
  M.ensure(rec,spend)
  local account=policy.host_account(spend)
  local owner=memory.owner(account,peak(rec.database,payload,arguments))
  state().jobs[owner.id]={owner=owner,device=rec.id,computer=computer and computer.id,run_id=computer and computer.run_id}
  return owner.id
end
function M.cancel(id)
  local s=state(); local job=s.jobs[id]
  if job then
    -- Refusal/cancellation cannot leave an otherwise unreachable reservation.
    memory.close(job.owner,noop); s.jobs[id]=nil
  end
end
function M.prepare(id,d,spend,j)
  local owner=assert(state().jobs[id],'missing KV preparation owner').owner
  j=j or {}
  local function acquire(items)
    while (j.own_step or 1)<=#items do
      spend(1)
      local item=items[j.own_step or 1]
      memory.acquire(owner,item[1],item[2])
      j.own_step=(j.own_step or 1)+1
    end
    j.own_step=nil
  end
  local function record(value)
    local items,count={},0
    for k,v in pairs(value) do
      count=count+1
      if type(k)=='string' then items[#items+1]={k,#k+32} end
      if type(v)=='string' then items[#items+1]={v,#v+32} end
    end
    items[#items+1]={value,192+48*count}
    return items
  end
  if not j.own_root then
    local items=record(d)
    items[#items+1]={d.entries,192+48*#d.order}
    items[#items+1]={d.order,192+48*#d.order}
    acquire(items); j.own_root=true; j.own_index=1
  end
  while j.own_index<=#d.order do
    local k=d.order[j.own_index]; local e=d.entries[k]
    if not j.own_entry then
      local items=record(e); items[#items+1]={k,#k+32}
      if e.fields then items[#items+1]={e.fields,192+48*e.count} end
      acquire(items); j.own_entry=true
    end
    if e.fields then
      while true do
        local f,v=next(e.fields,j.own_field)
        if f==nil then break end
        acquire({{f,#f+32},{v,#v+32}}); j.own_field=f
      end
    end
    j.own_index=j.own_index+1; j.own_entry=nil; j.own_field=nil
  end
end
function M.publish(rec,id)
  local s=state(); local job=assert(s.jobs[id],'missing KV publication owner')
  local old=s.live[rec.id]
  memory.unreserve(job.owner)
  s.live[rec.id]={owner=job.owner,value=rec.database,revision=rec.kv_revision or 0}
  s.jobs[id]=nil
  if old then s.retired[old.owner.id]=old.owner end
end
function M.maintenance(spend)
  local root=registry.get(); local s=root.kv_memory
  if not s then return end
  for id,live in pairs(s.live) do
    spend(1)
    local rec=registry.record(id)
    if not rec then s.retired[live.owner.id]=live.owner; s.live[id]=nil
    elseif rec.database and rec.database.version==1 and rec.mining_guard~='unsupported-database'
      and (live.value~=rec.database or live.revision~=(rec.kv_revision or 0)) then M.ensure(rec,spend) end
  end
  for id,job in pairs(s.jobs) do
    spend(1)
    local computer=job.computer and registry.record(job.computer)
    if not registry.record(job.device) or job.computer and (not computer or computer.run_id~=job.run_id) then
      s.retired[id]=job.owner; s.jobs[id]=nil
    end
  end
  for id,owner in pairs(s.retired) do memory.close(owner,spend); s.retired[id]=nil end
end
registry.register_cleanup('kv-preparation',function(rec)
  local s=registry.get().kv_memory
  if not s then return end
  for id,job in pairs(s.jobs) do
    if job.device==rec.id or job.computer==rec.id then M.cancel(id) end
  end
end)
return M
