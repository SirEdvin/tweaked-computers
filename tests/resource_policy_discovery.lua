-- Desired retained-growth refusal through the real guard/owner and native graph.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local peripheral=require('scripts.services.peripheral')
local sandbox=require('scripts.runtime.sandbox')
local admission=require('scripts.runtime.admission')
local memory=require('scripts.runtime.memory')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local M={}
local function build(kind,x)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,0},force='player'})
  lifecycle.on_built{entity=body}; local r=assert(registry.by_entity(body)); r.powered=true
  lifecycle.power_entity(r).energy=100000; return r
end
local function copy(value)
  if type(value)~='table' then return value end
  local out={}; for k,v in pairs(value) do out[k]=copy(v) end; return out
end
local function same(a,b)
  assert(type(a)==type(b),'private progress shape changed')
  if type(a)~='table' then assert(a==b,'private progress changed'); return end
  for k,v in pairs(a) do same(v,b[k]) end
  for k in pairs(b) do assert(a[k]~=nil,'private progress grew after refusal') end
end
local function covered(owner,value,seen)
  local kind=type(value)
  if kind~='table' and kind~='string' then return end
  if seen[value] then return end; seen[value]=true
  local node=assert(owner.values[value],'unaccounted private graph value: '..tostring(value))
  if kind=='string' then assert(node.record.bytes>=#value+32); return end
  local fields=0
  for k,v in pairs(value) do fields=fields+1; covered(owner,k,seen); covered(owner,v,seen) end
  assert(node.record.bytes>=192+48*fields,'private table grew beyond its admitted shape')
end
function M.assert_owned(owner,value) covered(owner,value,{}) end
local function growth_trial(c,m,refuse_at,optional)
  local account=memory.new(limits.runtime_memory_bytes,4096); local baseline=account.used
  local owner=memory.owner(account)
  local ctx=admission.context(admission.new(),c.id,game.tick); ctx.memory_owner=owner
  local g=sandbox.new(ctx,{},nil,{owned={},owned_order={},symbols={},bindings={},functions={}})
  local pending={}; g.call_checkpoint(pending)
  local job=g.job('peripheral-inventory-red',function() return {} end)
  local calls,before,used=0
  for _,name in ipairs({'job_admit','job_resize'}) do
    local original=g[name]
    g[name]=function(...)
      calls=calls+1
      if calls==refuse_at then
        before=copy(job); used=account.used; memory.configure(account,used)
      end
      return original(...)
    end
  end
  local ok,result=pcall(peripheral.services(c,game.tick,g).peripheral.isPresent,m.id,'red')
  if refuse_at then
    if optional then assert(ok and result,'optional cache metadata refused an otherwise admitted read')
    else assert(not ok and errors.resource_diagnostic(result),'growth boundary escaped memory refusal') end
    same(before,job); assert(account.used==used,'failed growth partially changed accounting')
  else assert(ok and result); covered(owner,job,{}) end
  memory.close(owner,function() end)
  assert(account.used==baseline and account.reserved==0 and next(account.values)==nil,'discovery owner leaked')
  return calls
end
local function cache_trial(c,m,room,disabled,memory_room)
  local account=memory.new(limits.runtime_memory_bytes,4096); local baseline=account.used
  local owner=memory.owner(account)
  local ctx=admission.context(admission.new(),c.id,game.tick); ctx.memory_owner=owner
  local g=sandbox.new(ctx,{},nil,{owned={},owned_order={},symbols={},bindings={},functions={}})
  local proof
  local admit=g.job_admit
  g.job_admit=function(value,items)
    local result=admit(value,items)
    if type(value)=='table' and value.job==false and value.total then proof=value end
    return result
  end
  local api=peripheral.services(c,game.tick,g).peripheral
  g.call_checkpoint({}); assert(api.isPresent(m.id,'red')); assert(proof)
  covered(owner,proof,{})
  local previous=proof.job
  local pending={}; g.call_checkpoint(pending)
  local job=g.job('peripheral-inventory-red',function() return {} end)
  local hit=false; local attempt=g.try_job_work
  g.try_job_work=function(...)
    if disabled then return false end
    hit=attempt(...); return hit
  end
  if room then ctx.machine.work=limits.callback_work-room; ctx.ledger.total=0 end
  local used=account.used
  if memory_room then memory.configure(account,used+memory_room) end
  local before=ctx.machine.work
  local ok,result=pcall(api.isPresent,m.id,'red')
  if memory_room==0 then
    assert(not ok and errors.resource_diagnostic(result) and next(job)==nil and account.used==used,
      'cache linked an unadmitted job root at full memory')
  elseif ok then
    assert(result); covered(owner,job,{})
    if not disabled then assert(hit and job.graph==previous.graph and job.inventory==previous.inventory,'cache copied or failed to share owned proof') end
  else assert(g.work_suspended(),'cache pressure failed outside work admission') end
  local observed={ok=ok,work=ctx.machine.work-before,total=ctx.ledger.total,job=copy(job),hit=hit}
  local total=proof.total
  memory.close(owner,function() end)
  assert(account.used==baseline and account.reserved==0 and next(account.values)==nil,'cached graph owner leaked')
  return observed,total
end
function M.run()
  registry.initialize()
  local c,m=build('computer',0),build('monitor',3)
  c.status='running'; c.run_id=c.id..'/ownership'
  assert(lifecycle.connector(c,'network','red').connect_to(lifecycle.connector(m,'network','red')))
  local account=memory.new(limits.runtime_memory_bytes,4096)
  local owner=memory.owner(account)
  local ctx=admission.context(admission.new(),c.id,game.tick); ctx.memory_owner=owner
  local checkpoint={owned={},owned_order={},symbols={},bindings={},functions={}}
  local g=sandbox.new(ctx,{},nil,checkpoint)
  local pending={}; g.call_checkpoint(pending)
  local job=g.job('peripheral-inventory-red',function() return {} end)
  local before=account.used; memory.configure(account,before)
  local api=peripheral.services(c,game.tick,g).peripheral
  local ok,result=pcall(api.isPresent,m.id,'red')
  local fields=0; for _ in pairs(job) do fields=fields+1 end
  log('TC_INVENTORY_OWNERSHIP_OBSERVED ok='..tostring(ok)..' used_before='..before..' used_after='..account.used..
    ' root_charge='..owner.values[job].record.bytes..' root_fields='..fields..' graph_owned='..tostring(job.graph and owner.values[job.graph]~=nil))
  assert(not ok and errors.resource_diagnostic(result),'native inventory grew a retained private graph at full memory without capacity refusal')
  assert(next(job)==nil,'refused discovery published retained job growth')
  memory.close(owner,function() end)
  local count=growth_trial(c,m)
  for i=1,count do growth_trial(c,m,i,i==count) end
  log('TC_DISCOVERY_OWNERSHIP_OK growth-boundaries='..count..' full-memory atomic-prefix graph-covered released')
  local _,total=cache_trial(c,m)
  for room=0,total-1 do
    local slow=cache_trial(c,m,room,true)
    local fast=cache_trial(c,m,room,false)
    assert(not fast.hit and fast.ok==slow.ok and fast.work==slow.work and fast.total==slow.total,'cache refusal changed work prefix')
    same(slow.job,fast.job)
  end
  cache_trial(c,m,nil,false,0)
  log('TC_DISCOVERY_CACHE_OK work-prefixes='..total..' owned-aliases full-memory-root-refusal metadata-accounted released')
end
return M
