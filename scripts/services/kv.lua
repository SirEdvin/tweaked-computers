-- Local strings/hashes only. No Redis server, coercion, guest objects or clocks.
local errors=require('scripts.runtime.errors')
local shared=require('scripts.runtime.limits')
local registry=require('scripts.registry')
local scheduler=require('scripts.scheduler')
local peripheral=require('scripts.services.peripheral')
local lifecycle=require('scripts.lifecycle')
local M={}
local L={keys=128,bytes=16384,key_bytes=256,value_bytes=8192,hash_fields=128,hash_bytes=8192,
  total_hash_fields=256,command_arguments=128,snapshot_bytes=65536,
  reclaim_keys_per_device=8,reclaim_devices_per_tick=2,
  peripheral_call_bytes=shared.peripheral_call_bytes,peripheral_call_entries=shared.peripheral_call_entries}
local MAX=9007199254740991
local function fail(code,message) errors.raise(code,message) end
local function byte(s,maximum)
  if type(s)~='string' then fail('E_ARGUMENT','byte string required; no coercion') end
  if #s>maximum then fail('E_LIMIT','byte string exceeds operation limit') end
  return s
end
local function clock(tick)
  if not errors.integer(tick,0,MAX) then fail('E_RANGE','invalid simulation tick') end
end
local function empty() return {version=1,entries={},order={},bytes=0,fields=0,cursor=1} end
local function db(rec)
  local d=rec.database
  if type(d)~='table' or d.version~=1 or rec.mining_guard=='unsupported-database' then fail('E_UNSUPPORTED','database representation unsupported; contents retained') end
  return d
end
local function live(d,k,tick)
  local e=d.entries[k]
  if e and (not e.deadline or tick<e.deadline) then return e end
end
local function hash(e)
  if e and e.type~='hash' then fail('E_WRONGTYPE','WRONGTYPE expected hash') end
end
local function sorted(map,spend)
  local keys={}
  for k in pairs(map) do spend(#k+1); keys[#keys+1]=k end
  table.sort(keys,function(a,b) spend(#a+#b+1); return a<b end)
  return keys
end
-- Cloning the bounded index also establishes exact live capacity independently
-- of the sweep cursor. Old entries/field maps remain immutable until publication.
local function stage(d,tick,spend)
  spend(d.bytes+#d.order*8+1)
  local nextdb=empty()
  for _,k in ipairs(d.order) do
    local e=live(d,k,tick)
    if e then nextdb.entries[k]=e end
  end
  return nextdb
end
local function publish(rec,d,spend)
  local order=sorted(d.entries,spend); local bytes,fields=0,0
  for _,k in ipairs(order) do
    local e=d.entries[k]; bytes=bytes+#k+e.bytes; fields=fields+(e.count or 0)
  end
  if #order>L.keys or bytes>L.bytes or fields>L.total_hash_fields then fail('E_CAPACITY','database content capacity exceeded') end
  spend(#order+1)
  d.order=order; d.bytes=bytes; d.fields=fields; rec.database=d
end
local methods={}
local exact={get=1,set=2,type=1,hget=2,hexists=2,hgetall=1,hlen=1,expire=2,ttl=1,persist=1,getLimits=0}
local function arguments(name,...)
  local n=select('#',...)
  if n>L.command_arguments then fail('E_LIMIT','command argument limit exceeded') end
  if exact[name] and n~=exact[name] then fail('E_ARGUMENT','unexpected argument count; use dot calls') end
  if (name=='del' or name=='exists') and n<1 or name=='hdel' and n<2
    or name=='hset' and (n<3 or n%2~=1) then fail('E_ARGUMENT','missing/incomplete command operands') end
  return table.pack(...)
end
local function call(name,rec,tick,spend,...)
  local a=arguments(name,...); clock(tick)
  if name=='getLimits' then local out={}; for k,v in pairs(L) do out[k]=v end; spend(32); return out end
  local payload=0
  for i=1,a.n do
    if not (name=='expire' and i==2) then
      local maximum=L.key_bytes
      if name=='set' and i==2 or name=='hset' and i>1 and i%2==1 then maximum=L.value_bytes end
      byte(a[i],maximum); payload=payload+#a[i]
    end
  end
  if payload>L.peripheral_call_bytes then fail('E_LIMIT','command payload exceeds call limit') end
  spend(payload+a.n*8+1)
  if name=='expire' then
    if not errors.integer(a[2],-MAX,MAX) then fail('E_RANGE','integer simulation seconds required') end
    if a[2]>0 and a[2]>math.floor((MAX-tick)/60) then fail('E_RANGE','expiry deadline exceeds safe integer range') end
  end
  local d=db(rec); local k=a[1]; local e=live(d,k,tick)
  if name=='get' then
    if e and e.type~='string' then fail('E_WRONGTYPE','WRONGTYPE expected string') end
    if e then spend(#e.value+1); return e.value end
    return nil
  elseif name=='type' then return e and e.type or 'none'
  elseif name=='exists' then
    local n=0; for i=1,a.n do if live(d,a[i],tick) then n=n+1 end end; return n
  elseif name=='ttl' then
    if not e then return -2 end
    if not e.deadline then return -1 end
    -- Avoid adding 30 near MAX: only the bounded remaining difference is used.
    local remaining=e.deadline-tick
    return math.floor(remaining/60)+((remaining%60)>=30 and 1 or 0)
  elseif name=='hget' or name=='hexists' or name=='hlen' or name=='hgetall' then
    hash(e)
    if name=='hlen' then return e and e.count or 0 end
    if name=='hgetall' then
      local out={}
      if e then
        spend(e.bytes+e.count*2+1)
        for _,f in ipairs(sorted(e.fields,spend)) do out[f]=e.fields[f] end
      end
      return out
    end
    local value=e and e.fields[a[2]] or nil
    if name=='hexists' then return value~=nil and 1 or 0 end
    if value then spend(#value+1) end; return value
  end
  if name=='hset' or name=='hdel' then hash(e) end
  -- Every mutator builds a private candidate; no capacity/admission/type failure
  -- may change original values, counters, index aliases or deadlines.
  local candidate=stage(d,tick,spend); local result
  if name=='set' then
    candidate.entries[k]={type='string',value=a[2],bytes=#a[2]}; result='OK'
  elseif name=='del' then
    result=0
    for i=1,a.n do if candidate.entries[a[i]] then candidate.entries[a[i]]=nil; result=result+1 end end
  elseif name=='expire' or name=='persist' then
    result=0
    if e and (name=='expire' or e.deadline) then
      result=1
      if name=='expire' and a[2]<=0 then candidate.entries[k]=nil
      else
        local replacement={}; for field,value in pairs(e) do replacement[field]=value end
        replacement.deadline=name=='expire' and tick+a[2]*60 or nil
        candidate.entries[k]=replacement
      end
    end
  elseif name=='hset' or name=='hdel' then
    local fields={}; result=0
    if e then spend(e.bytes+e.count+1); for f,v in pairs(e.fields) do fields[f]=v end end
    if name=='hset' then
      for i=2,a.n,2 do if fields[a[i]]==nil then result=result+1 end; fields[a[i]]=a[i+1] end
    else
      for i=2,a.n do if fields[a[i]]~=nil then result=result+1; fields[a[i]]=nil end end
    end
    local count,bytes=0,0
    for f,v in pairs(fields) do spend(#f+#v+1); count=count+1; bytes=bytes+#f+#v end
    if count>L.hash_fields or bytes>L.hash_bytes then fail('E_CAPACITY','hash field/byte capacity exceeded') end
    if count>0 then candidate.entries[k]={type='hash',fields=fields,count=count,bytes=bytes,deadline=e and e.deadline}
    else candidate.entries[k]=nil end
  else fail('E_ARGUMENT','unknown database command') end
  publish(rec,candidate,spend); return result
end
for _,name in ipairs({'get','set','del','exists','type','hget','hset','hdel','hexists','hgetall','hlen','expire','ttl','persist','getLimits'}) do
  local command=name
  methods[command]=function(computer,rec,wire,tick,spend,...) return call(command,rec,tick,spend,...) end
end
-- Fixed host entry used by compact fixtures and lifecycle; not a guest namespace.
M.methods=methods
function M.initialize(rec)
  if rec.database==nil then rec.database=empty() end
  local ok=pcall(M.audit,rec.database,function() end)
  if not ok then rec.body.minable=false; rec.mining_guard='unsupported-database'; return end
  rec.body.minable=true; rec.mining_guard=nil
end
function M.initialize_existing()
  local root=registry.get()
  if not registry.supported(root) then return end
  -- Synchronized configuration/init only, never ordinary on_load.
  for _,id in ipairs(root.order) do
    local rec=registry.record(id)
    if rec and rec.kind=='kv' and rec.body.valid then M.initialize(rec) end
  end
end
local function noop() end
-- MSD byte sorting bounds inspection by stored bytes, even for long common
-- prefixes. Repeated full-string comparison charges can exceed a whole tick
-- for a legal full database. All scratch lists are host-only and ephemeral.
local function inspection_keys(map,spend)
  local keys={}
  for k in pairs(map) do spend(1); keys[#keys+1]=k end
  local result,stack={},{ {keys=keys,offset=1} }
  while #stack>0 do
    local group=table.remove(stack); local values=group.keys
    spend(#values*3+1)
    if #values==1 then result[#result+1]=values[1]
    elseif #values>1 then
      local buckets,bytes={},{}
      for _,k in ipairs(values) do
        local b=string.byte(k,group.offset) or -1 -- Shorter prefix sorts first.
        if not buckets[b] then buckets[b]={}; bytes[#bytes+1]=b end
        local bucket=buckets[b]; bucket[#bucket+1]=k
      end
      table.sort(bytes,function(a,b) spend(1); return a<b end)
      for i=#bytes,1,-1 do
        stack[#stack+1]={keys=buckets[bytes[i]],offset=group.offset+1}
      end
    end
  end
  return result
end
-- Detached live browser snapshot. Unlike mining snapshots this excludes expiry
-- at the exact deadline, never imports/repairs state, and requires paid reads.
function M.inspect(rec,tick,spend)
  clock(tick)
  local d=db(rec); M.audit(d,spend)
  spend(d.bytes+#d.order*80+d.fields*48+128)
  local entries={}
  for _,k in ipairs(inspection_keys(d.entries,spend)) do
    local e=live(d,k,tick)
    if e then
      local item={key=k,type=e.type}
      if e.type=='string' then item.value=e.value
      else
        item.fields={}
        for _,f in ipairs(inspection_keys(e.fields,spend)) do item.fields[#item.fields+1]={field=f,value=e.fields[f]} end
      end
      entries[#entries+1]=item
    end
  end
  return {tick=tick,entries=entries}
end
-- Snapshot representation has separately reserved metadata, with dense records
-- rather than dynamic key serialization. Even empty/NUL keys are plain values.
function M.snapshot(rec,tick,spend)
  spend=spend or noop; clock(tick)
  local d=db(rec); M.audit(d,spend); local entries={}
  spend(d.bytes+#d.order*80+d.fields*48+128)
  for _,k in ipairs(d.order) do
    local e=d.entries[k]; local item={key=k,type=e.type,deadline=e.deadline}
    if e.type=='string' then item.value=e.value
    else
      item.fields={}
      for _,f in ipairs(sorted(e.fields,spend)) do item.fields[#item.fields+1]={field=f,value=e.fields[f]} end
    end
    entries[#entries+1]=item
  end
  local snapshot={version=1,entries=entries}
  -- Validate using the same importer before enabling destructive mining.
  M.import(snapshot,spend)
  return snapshot
end
local function shape(t,allowed,maximum)
  if type(t)~='table' or getmetatable(t)~=nil then fail('E_ARGUMENT','plain snapshot table required') end
  local count=0
  for k in pairs(t) do
    count=count+1
    if count>maximum or not allowed[k] then fail('E_ARGUMENT','unknown snapshot field') end
  end
end
local function dense(t,maximum)
  if type(t)~='table' or getmetatable(t)~=nil then fail('E_ARGUMENT','dense snapshot array required') end
  local count=0
  for k in pairs(t) do
    count=count+1
    if count>maximum or not errors.integer(k,1,maximum) then fail('E_LIMIT','snapshot array limit exceeded') end
  end
  for i=1,count do if t[i]==nil then fail('E_ARGUMENT','sparse snapshot array') end end
  return count
end
function M.audit(d,spend)
  spend=spend or noop
  if type(d)~='table' or d.version~=1 or type(d.entries)~='table' then fail('E_UNSUPPORTED','unsupported retained database') end
  local n=dense(d.order,L.keys); local seen={}; local bytes,fields,count=0,0,0
  for i=1,n do
    local k=byte(d.order[i],L.key_bytes)
    if seen[k] or d.entries[k]==nil then fail('E_ARGUMENT','retained database index is not one-to-one') end
    seen[k]=true; spend(#k+1)
  end
  for k,e in pairs(d.entries) do
    count=count+1
    if count>L.keys or not seen[k] or type(e)~='table' then fail('E_ARGUMENT','retained database index mismatch') end
    byte(k,L.key_bytes)
    if e.deadline~=nil and not errors.integer(e.deadline,0,MAX) then fail('E_ARGUMENT','invalid retained deadline') end
    local size=0
    if e.type=='string' then size=#byte(e.value,L.value_bytes)
    elseif e.type=='hash' and type(e.fields)=='table' then
      local fc=0
      for f,v in pairs(e.fields) do
        fc=fc+1; if fc>L.hash_fields then fail('E_CAPACITY','retained hash field limit') end
        byte(f,L.key_bytes); byte(v,L.value_bytes); size=size+#f+#v
        if size>L.hash_bytes then fail('E_CAPACITY','retained hash byte limit') end
        spend(#f+#v+1)
      end
      if fc==0 or e.count~=fc then fail('E_ARGUMENT','retained hash accounting mismatch') end
      fields=fields+fc
    else fail('E_ARGUMENT','invalid retained database type') end
    bytes=bytes+#k+size
    if e.bytes~=size or bytes>L.bytes or fields>L.total_hash_fields then fail('E_CAPACITY','retained database accounting mismatch') end
    spend(#k+size+8)
  end
  if count~=n or bytes~=d.bytes or fields~=d.fields then fail('E_ARGUMENT','retained database inventory/accounting mismatch') end
  return true
end
function M.import(snapshot,spend)
  spend=spend or noop
  shape(snapshot,{version=true,entries=true},2)
  if snapshot.version~=1 then fail('E_UNSUPPORTED','unsupported database item snapshot; original item retained') end
  local n=dense(snapshot.entries,L.keys); local candidate=empty(); local bytes,fields=0,0
  for i=1,n do
    local item=snapshot.entries[i]
    shape(item,{key=true,type=true,value=true,fields=true,deadline=true},5)
    local k=byte(item.key,L.key_bytes)
    if candidate.entries[k] then fail('E_ARGUMENT','duplicate snapshot key') end
    if item.deadline~=nil and not errors.integer(item.deadline,0,MAX) then fail('E_RANGE','invalid absolute snapshot deadline') end
    local e={type=item.type,deadline=item.deadline}
    if e.type=='string' then
      if item.fields~=nil then fail('E_ARGUMENT','string snapshot contains hash fields') end
      e.value=byte(item.value,L.value_bytes); e.bytes=#e.value
    elseif e.type=='hash' then
      if item.value~=nil then fail('E_ARGUMENT','hash snapshot contains string value') end
      e.count=dense(item.fields,L.hash_fields)
      if e.count==0 then fail('E_ARGUMENT','empty stored hash') end
      e.fields={}; e.bytes=0
      for j=1,e.count do
        local pair=item.fields[j]; shape(pair,{field=true,value=true},2)
        local f=byte(pair.field,L.key_bytes); local v=byte(pair.value,L.value_bytes)
        if e.fields[f]~=nil then fail('E_ARGUMENT','duplicate snapshot hash field') end
        e.fields[f]=v; e.bytes=e.bytes+#f+#v
      end
      if e.bytes>L.hash_bytes then fail('E_CAPACITY','snapshot hash byte capacity exceeded') end
      fields=fields+e.count
    else fail('E_ARGUMENT','unknown snapshot key type') end
    bytes=bytes+#k+e.bytes
    if bytes>L.bytes or fields>L.total_hash_fields then fail('E_CAPACITY','snapshot content capacity exceeded') end
    spend(#k+e.bytes+(e.count or 0)*4+8); candidate.entries[k]=e
  end
  -- Conservative metadata reservation never consumes the live-content allowance.
  if bytes+n*80+fields*48+128>L.snapshot_bytes then fail('E_CAPACITY','snapshot metadata capacity exceeded') end
  local holder={}; publish(holder,candidate,spend); return holder.database
end
function M.restore(rec,snapshot)
  local candidate=M.import(snapshot)
  rec.database=candidate; M.initialize(rec)
end
function M.reclaim(rec,tick,spend)
  local d=db(rec); local size=#d.order
  if size==0 then return end
  for _=1,math.min(L.reclaim_keys_per_device,size) do
    local cursor=math.min(d.cursor,#d.order); local k=d.order[cursor]; local e=d.entries[k]
    spend(#k+e.bytes+(e.count or 0)*4+#d.order+8)
    if e.deadline and tick>=e.deadline then
      d.entries[k]=nil; table.remove(d.order,cursor)
      d.bytes=d.bytes-#k-e.bytes; d.fields=d.fields-(e.count or 0)
    else cursor=cursor+1 end
    if #d.order==0 then d.cursor=1; return end
    d.cursor=cursor>#d.order and 1 or cursor
  end
end
function M.maintenance(tick,spend)
  local root=registry.get(); local n=#root.order
  if n==0 then return end
  spend(n+1)
  local cursor=math.min(root.scheduler.kv_cursor or 1,n); local visited=0
  for _=1,n do
    local rec=registry.record(root.order[cursor]); cursor=cursor%n+1
    if rec and rec.kind=='kv' and rec.database and rec.database.version==1 and rec.mining_guard~='unsupported-database' then
      scheduler.try_maintenance(function() M.reclaim(rec,tick,spend) end)
      visited=visited+1
    end
    root.scheduler.kv_cursor=cursor
    if visited>=L.reclaim_devices_per_tick then return end
  end
end
peripheral.register_type('kv',{methods=methods})
lifecycle.register_item_adapter('kv',{initialize=M.initialize,snapshot=M.snapshot,restore=M.restore,tag='tc_kv'})
scheduler.register_phase('render','kv-reclamation',M.maintenance)
return M
