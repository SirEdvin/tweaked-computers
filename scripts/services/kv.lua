-- Local strings/hashes only. No Redis server, coercion, guest objects or clocks.
local errors=require('scripts.runtime.errors')
local shared=require('scripts.runtime.limits')
local registry=require('scripts.registry')
local scheduler=require('scripts.scheduler')
local peripheral=require('scripts.services.peripheral')
local lifecycle=require('scripts.lifecycle')
local M={}
local budgets=require('scripts.runtime.budget-settings')
local MAX=9007199254740991
local function fail(code,message) errors.raise(code,message) end
local function byte(s)
  if type(s)~='string' then fail('E_ARGUMENT','byte string required; no coercion') end
  return s
end
local function capacity(key,used,requested,code)
  local limit=shared['kv_'..key]
  if requested>limit and requested>used then
    errors.refuse('kv_'..key,'tc-kv-'..key:gsub('_','-'),used,requested-used,limit,
      'KV '..key..' growth exceeds configured capacity',code)
  end
end
local function snapshot_bytes(bytes,keys,fields) return bytes+keys*80+fields*48+128 end
local function query_limits(rec,spend)
  local out={policy_version=2,resources={}}
  for _,definition in ipairs(budgets.definitions) do
    if definition.key:sub(1,3)=='kv_' then
      local value=shared[definition.key]
      out[definition.key:sub(4)]=value
      out.resources[definition.key]={limit=value,unit=definition.unit,scope=definition.scope,
        setting=definition.name,behavior=definition.behavior}
    end
  end
  out.peripheral_call_bytes=out.command_bytes
  local d=rec.database
  if not d or d.version~=1 or rec.mining_guard=='unsupported-database' then spend(32); return out end
  out.usage={keys=#d.order,bytes=d.bytes,total_hash_fields=d.fields,
    key_bytes=0,value_bytes=0,hash_fields=0,hash_bytes=0,
    snapshot_bytes=snapshot_bytes(d.bytes,#d.order,d.fields),over_limit=false}
  for k,e in pairs(d.entries) do
    spend(1); out.usage.key_bytes=math.max(out.usage.key_bytes,#k)
    if e.type=='string' then out.usage.value_bytes=math.max(out.usage.value_bytes,#e.value)
    else
      out.usage.hash_fields=math.max(out.usage.hash_fields,e.count)
      out.usage.hash_bytes=math.max(out.usage.hash_bytes,e.bytes)
      for field,value in pairs(e.fields) do
        spend(1); out.usage.key_bytes=math.max(out.usage.key_bytes,#field)
        out.usage.value_bytes=math.max(out.usage.value_bytes,#value)
      end
    end
  end
  for key,value in pairs(out.usage) do
    if type(value)=='number' and value>out[key] then out.usage.over_limit=true end
  end
  out.snapshot_metadata_bytes=out.usage.snapshot_bytes-d.bytes
  out.effective_bytes=math.min(out.bytes,math.max(0,out.snapshot_bytes-out.snapshot_metadata_bytes))
  spend(32)
  return out
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
    if e then
      nextdb.entries[k]=e; nextdb.order[#nextdb.order+1]=k
      nextdb.bytes=nextdb.bytes+#k+e.bytes; nextdb.fields=nextdb.fields+(e.count or 0)
    end
  end
  return nextdb
end
local function publish(rec,d,spend,prepare,result,previous)
  local order=sorted(d.entries,spend); local bytes,fields=0,0
  for _,k in ipairs(order) do
    local e=d.entries[k]; bytes=bytes+#k+e.bytes; fields=fields+(e.count or 0)
  end
  if previous then
    capacity('keys',previous.keys,#order)
    capacity('bytes',previous.bytes,bytes)
    capacity('total_hash_fields',previous.fields,fields)
    capacity('snapshot_bytes',snapshot_bytes(previous.bytes,previous.keys,previous.fields),snapshot_bytes(bytes,#order,fields))
  end
  spend(#order+1)
  if prepare then result=prepare(result) end
  d.order=order; d.bytes=bytes; d.fields=fields; rec.database=d
  return result
end
local methods={}
local exact={get=1,set=2,type=1,hget=2,hexists=2,hgetall=1,hlen=1,expire=2,ttl=1,persist=1,getLimits=0}
local function arguments(name,...)
  local n=select('#',...)
  if exact[name] and n~=exact[name] then fail('E_ARGUMENT','unexpected argument count; use dot calls') end
  if (name=='del' or name=='exists') and n<1 or name=='hdel' and n<2
    or name=='hset' and (n<3 or n%2~=1) then fail('E_ARGUMENT','missing/incomplete command operands') end
  return table.pack(...)
end
local function call(name,rec,tick,spend,prepare,...)
  local a=arguments(name,...); clock(tick)
  if name=='getLimits' then return query_limits(rec,spend) end
  local payload=0
  for i=1,a.n do
    if not (name=='expire' and i==2) then
      byte(a[i]); payload=payload+#a[i]
    end
  end
  spend(payload+a.n*8+1)
  if name=='expire' then
    if not errors.integer(a[2],-MAX,MAX) then fail('E_RANGE','integer simulation seconds required') end
    if a[2]>0 and a[2]>math.floor((MAX-tick)/60) then fail('E_RANGE','expiry deadline exceeds safe integer range') end
  end
  local d=db(rec); local k=a[1]; local e=live(d,k,tick)
  -- Existing addresses remain usable after key/command limits are lowered.
  local recovery=d.entries[k]~=nil
  if name=='set' then recovery=e and e.type=='string' and #a[2]<=#e.value
  elseif name=='hset' then
    recovery=e and e.type=='hash'
    for i=2,a.n,2 do
      if not recovery or e.fields[a[i]]==nil or #a[i+1]>#e.fields[a[i]] then recovery=false; break end
    end
  elseif name=='del' or name=='exists' then
    recovery=true
    for i=1,a.n do if not d.entries[a[i]] then recovery=false; break end end
  end
  local minimum=exact[name] or (name=='hset' and 3 or name=='hdel' and 2 or 1)
  capacity('command_arguments',recovery and minimum or 0,a.n,'E_LIMIT')
  capacity('command_bytes',recovery and d.bytes or 0,payload,'E_LIMIT')
  if not d.entries[k] or (name=='set' or name=='hset') and not e then capacity('key_bytes',0,#k,'E_LIMIT') end
  if name=='del' or name=='exists' then
    for i=2,a.n do if not d.entries[a[i]] then capacity('key_bytes',0,#a[i],'E_LIMIT') end end
  elseif name=='hget' or name=='hexists' or name=='hdel' then
    for i=2,a.n do
      local retained=d.entries[k]
      if not (retained and retained.type=='hash' and retained.fields[a[i]]~=nil) then
        capacity('key_bytes',0,#a[i],'E_LIMIT')
      end
    end
  end
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
  local previous={keys=#candidate.order,bytes=candidate.bytes,fields=candidate.fields}
  if name=='set' then
    capacity('value_bytes',e and e.type=='string' and #e.value or 0,#a[2],'E_LIMIT')
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
    if name=='hset' then
      for f,v in pairs(fields) do
        local old=e and e.fields[f]
        capacity('key_bytes',old~=nil and #f or 0,#f,'E_LIMIT')
        capacity('value_bytes',old and #old or 0,#v,'E_LIMIT')
      end
    end
    capacity('hash_fields',e and e.count or 0,count)
    capacity('hash_bytes',e and e.bytes or 0,bytes)
    if count>0 then candidate.entries[k]={type='hash',fields=fields,count=count,bytes=bytes,deadline=e and e.deadline}
    else candidate.entries[k]=nil end
  else fail('E_ARGUMENT','unknown database command') end
  return publish(rec,candidate,spend,prepare,result,previous)
end
local guarded_methods={}
for _,name in ipairs({'get','set','del','exists','type','hget','hset','hdel','hexists','hgetall','hlen','expire','ttl','persist','getLimits'}) do
  local command=name
  methods[command]=function(computer,rec,wire,tick,spend,...) return call(command,rec,tick,spend,nil,...) end
  guarded_methods[command]=function(computer,rec,wire,tick,spend,guard,...)
    return call(command,rec,tick,spend,guard.prepare_result,...)
  end
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
local function dense(t)
  if type(t)~='table' or getmetatable(t)~=nil then fail('E_ARGUMENT','dense snapshot array required') end
  local count=0
  for k in pairs(t) do
    count=count+1
    if not errors.integer(k,1,MAX) then fail('E_ARGUMENT','invalid snapshot array index') end
  end
  for i=1,count do if t[i]==nil then fail('E_ARGUMENT','sparse snapshot array') end end
  return count
end
function M.audit(d,spend)
  spend=spend or noop
  if type(d)~='table' or d.version~=1 or type(d.entries)~='table' then fail('E_UNSUPPORTED','unsupported retained database') end
  shape(d,{version=true,entries=true,order=true,bytes=true,fields=true,cursor=true},6)
  if getmetatable(d.entries)~=nil then fail('E_ARGUMENT','plain retained database entries required') end
  local n=dense(d.order); local seen={}; local bytes,fields,count=0,0,0
  if not errors.integer(d.cursor,1,math.max(1,n)) then fail('E_ARGUMENT','invalid retained expiry cursor') end
  for i=1,n do
    local k=byte(d.order[i])
    if seen[k] or d.entries[k]==nil then fail('E_ARGUMENT','retained database index is not one-to-one') end
    seen[k]=true; spend(#k+1)
  end
  for k,e in pairs(d.entries) do
    count=count+1
    if not seen[k] or type(e)~='table' then fail('E_ARGUMENT','retained database index mismatch') end
    shape(e,{type=true,value=true,fields=true,bytes=true,count=true,deadline=true},6)
    byte(k)
    if e.deadline~=nil and not errors.integer(e.deadline,0,MAX) then fail('E_ARGUMENT','invalid retained deadline') end
    local size=0
    if e.type=='string' then
      if e.fields~=nil or e.count~=nil then fail('E_ARGUMENT','retained string has hash fields') end
      size=#byte(e.value)
    elseif e.type=='hash' and type(e.fields)=='table' and getmetatable(e.fields)==nil and e.value==nil then
      local fc=0
      for f,v in pairs(e.fields) do
        fc=fc+1
        byte(f); byte(v); size=size+#f+#v
        spend(#f+#v+1)
      end
      if fc==0 or e.count~=fc then fail('E_ARGUMENT','retained hash accounting mismatch') end
      fields=fields+fc
    else fail('E_ARGUMENT','invalid retained database type') end
    bytes=bytes+#k+size
    if e.bytes~=size then fail('E_ARGUMENT','retained database accounting mismatch') end
    spend(#k+size+8)
  end
  if count~=n or bytes~=d.bytes or fields~=d.fields then fail('E_ARGUMENT','retained database inventory/accounting mismatch') end
  return true
end
function M.import(snapshot,spend)
  spend=spend or noop
  shape(snapshot,{version=true,entries=true},2)
  if snapshot.version~=1 then fail('E_UNSUPPORTED','unsupported database item snapshot; original item retained') end
  local n=dense(snapshot.entries); local candidate=empty()
  for i=1,n do
    local item=snapshot.entries[i]
    shape(item,{key=true,type=true,value=true,fields=true,deadline=true},5)
    local k=byte(item.key)
    if candidate.entries[k] then fail('E_ARGUMENT','duplicate snapshot key') end
    if item.deadline~=nil and not errors.integer(item.deadline,0,MAX) then fail('E_RANGE','invalid absolute snapshot deadline') end
    local e={type=item.type,deadline=item.deadline}
    if e.type=='string' then
      if item.fields~=nil then fail('E_ARGUMENT','string snapshot contains hash fields') end
      e.value=byte(item.value); e.bytes=#e.value
    elseif e.type=='hash' then
      if item.value~=nil then fail('E_ARGUMENT','hash snapshot contains string value') end
      e.count=dense(item.fields)
      if e.count==0 then fail('E_ARGUMENT','empty stored hash') end
      e.fields={}; e.bytes=0
      for j=1,e.count do
        local pair=item.fields[j]; shape(pair,{field=true,value=true},2)
        local f=byte(pair.field); local v=byte(pair.value)
        if e.fields[f]~=nil then fail('E_ARGUMENT','duplicate snapshot hash field') end
        e.fields[f]=v; e.bytes=e.bytes+#f+#v
      end
    else fail('E_ARGUMENT','unknown snapshot key type') end
    spend(#k+e.bytes+(e.count or 0)*4+8); candidate.entries[k]=e
  end
  -- Transport validates representation, never the current new-growth policy.
  local holder={}; publish(holder,candidate,spend); return holder.database
end
function M.restore(rec,snapshot)
  local candidate=M.import(snapshot)
  rec.database=candidate; M.initialize(rec)
end
function M.reclaim(rec,tick,spend)
  local d=db(rec); local size=#d.order
  if size==0 then return end
  for _=1,size do
    local cursor=math.min(d.cursor,#d.order); local k=d.order[cursor]; local e=d.entries[k]
    spend(8)
    if e.deadline and tick>=e.deadline then
      -- Swap/pop keeps each paid cleanup step independent of database size.
      d.entries[k]=nil; d.order[cursor]=d.order[#d.order]; d.order[#d.order]=nil
      d.bytes=d.bytes-#k-e.bytes; d.fields=d.fields-(e.count or 0)
    else cursor=cursor+1 end
    if #d.order==0 then d.cursor=1; return end
    d.cursor=cursor>#d.order and 1 or cursor
  end
end
function M.maintenance(tick,spend)
  local root=registry.get(); local n=#root.order
  if n==0 then return end
  local cursor=math.min(root.scheduler.kv_cursor or 1,n)
  for _=1,n do
    local rec=registry.record(root.order[cursor]); cursor=cursor%n+1
    local ok=scheduler.try_maintenance(function()
      spend(1)
      if rec and rec.kind=='kv' and rec.database and rec.database.version==1 and rec.mining_guard~='unsupported-database' then
        M.reclaim(rec,tick,spend)
      end
    end)
    root.scheduler.kv_cursor=cursor
    if not ok then return end
  end
end
peripheral.register_type('kv',{methods=guarded_methods,with_guard=true})
lifecycle.register_item_adapter('kv',{initialize=M.initialize,snapshot=M.snapshot,restore=M.restore,tag='tc_kv'})
scheduler.register_phase('render','kv-reclamation',M.maintenance)
return M
