-- Local strings/hashes only. No Redis server, coercion, guest objects or clocks.
local errors=require('scripts.runtime.errors')
local shared=require('scripts.runtime.limits')
local registry=require('scripts.registry')
local scheduler=require('scripts.scheduler')
local peripheral=require('scripts.services.peripheral')
local lifecycle=require('scripts.lifecycle')
local preparation=require('scripts.services.kv-preparation')
local ownership=require('scripts.services.kv-memory')
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
local function query_limits(rec,spend,j,g)
  local out=j and j.limits or {policy_version=2,resources={}}
  if not j or not j.limits then
    if g then g.job_resize(16384) end
    for _,definition in ipairs(budgets.definitions) do
      if definition.key:sub(1,3)=='kv_' then
        local value=shared[definition.key]
        out[definition.key:sub(4)]=value
        out.resources[definition.key]={limit=value,unit=definition.unit,scope=definition.scope,
          setting=definition.name,behavior=definition.behavior}
      end
    end
    out.peripheral_call_bytes=out.command_bytes
  end
  local d=rec.database
  if not d or d.version~=1 or rec.mining_guard=='unsupported-database' then spend(32); return out end
  local scan=j and j.usage_scan or {index=1}
  if not out.usage then
    out.usage={keys=#d.order,bytes=d.bytes,total_hash_fields=d.fields,
      key_bytes=0,value_bytes=0,hash_fields=0,hash_bytes=0,
      snapshot_bytes=snapshot_bytes(d.bytes,#d.order,d.fields),over_limit=false}
  end
  if j then j.limits=out; j.usage_scan=scan end
  while scan.index<=#d.order do
    if not scan.entry then
      spend(1)
      local k=d.order[scan.index]; local e=d.entries[k]
      out.usage.key_bytes=math.max(out.usage.key_bytes,#k)
      if e.type=='string' then out.usage.value_bytes=math.max(out.usage.value_bytes,#e.value)
      else
        out.usage.hash_fields=math.max(out.usage.hash_fields,e.count)
        out.usage.hash_bytes=math.max(out.usage.hash_bytes,e.bytes)
      end
      scan.entry=true
    end
    local e=d.entries[d.order[scan.index]]
    if e.fields then
      while true do
        spend(1)
        local field,value=next(e.fields,scan.field)
        if field==nil then break end
        out.usage.key_bytes=math.max(out.usage.key_bytes,#field)
        out.usage.value_bytes=math.max(out.usage.value_bytes,#value); scan.field=field
      end
    end
    scan.index=scan.index+1; scan.entry=nil; scan.field=nil
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
local function publish(rec,d,spend,prepare,result,previous,j,g)
  local order=j and preparation.sorted(d.entries,spend,j,g) or sorted(d.entries,spend)
  local totals=j and j.totals or {index=1,bytes=0,fields=0}
  if j then j.totals=totals end
  while totals.index<=#order do
    spend(1)
    local k=order[totals.index]; local e=d.entries[k]
    totals.bytes=totals.bytes+#k+e.bytes; totals.fields=totals.fields+(e.count or 0)
    totals.index=totals.index+1
  end
  local bytes,fields=totals.bytes,totals.fields
  if previous then
    capacity('keys',previous.keys,#order)
    capacity('bytes',previous.bytes,bytes)
    capacity('total_hash_fields',previous.fields,fields)
    capacity('snapshot_bytes',snapshot_bytes(previous.bytes,previous.keys,previous.fields),snapshot_bytes(bytes,#order,fields))
  end
  d.order=order; d.bytes=bytes; d.fields=fields
  if j and j.owner_id then ownership.prepare(j.owner_id,d,spend,j) end
  spend(1)
  if prepare then result=prepare(result) end
  rec.database=d
  if rec.id then rec.kv_basis=d end
  rec.kv_revision=(rec.kv_revision or 0)+1
  if j and j.owner_id then ownership.publish(rec,j.owner_id); j.owner_id=nil end
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
local function call(name,rec,tick,spend,prepare,j,g,...)
  local a=arguments(name,...); clock(tick)
  if name=='getLimits' then return query_limits(rec,spend,j,g) end
  local payload=j and j.payload or 0
  local i=j and j.argument or 1
  while i<=a.n do
    spend(1)
    if not (name=='expire' and i==2) then byte(a[i]); payload=payload+#a[i] end
    i=i+1
    if j then j.argument=i; j.payload=payload end
  end
  if name=='expire' then
    if not errors.integer(a[2],-MAX,MAX) then fail('E_RANGE','integer simulation seconds required') end
    if a[2]>0 and a[2]>math.floor((MAX-tick)/60) then fail('E_RANGE','expiry deadline exceeds safe integer range') end
  end
  local d=db(rec); local k=a[1]; local e=live(d,k,j and j.tick or tick)
  if j and e and e.deadline then j.deadline=math.min(j.deadline or e.deadline,e.deadline) end
  if j and j.deadline and tick>=j.deadline then fail('E_BUSY','database expired during preparation; retry the command') end
  -- Existing addresses remain usable after key/command limits are lowered.
  local validation=j and j.validation or {index=1,recovery=d.entries[k]~=nil}
  if j then j.validation=validation end
  if not validation.done then
    if not validation.started then
      if name=='set' then validation.recovery=e and e.type=='string' and #a[2]<=#e.value
      elseif name=='hset' then validation.recovery=e and e.type=='hash'; validation.index=2
      elseif name=='del' or name=='exists' then validation.recovery=true end
      validation.started=true
    end
    while validation.index<=a.n do
      spend(1)
      local index=validation.index
      if name=='hset' then
        if not validation.recovery or e.fields[a[index]]==nil or #a[index+1]>#e.fields[a[index]] then validation.recovery=false end
      elseif name=='del' or name=='exists' then
        if not d.entries[a[index]] then validation.recovery=false end
        if index>1 and not d.entries[a[index]] then capacity('key_bytes',0,#a[index],'E_LIMIT') end
      elseif (name=='hget' or name=='hexists' or name=='hdel') and index>1 then
        local retained=d.entries[k]
        if not (retained and retained.type=='hash' and retained.fields[a[index]]~=nil) then capacity('key_bytes',0,#a[index],'E_LIMIT') end
      end
      validation.index=index+(name=='hset' and 2 or 1)
    end
    local minimum=exact[name] or (name=='hset' and 3 or name=='hdel' and 2 or 1)
    capacity('command_arguments',validation.recovery and minimum or 0,a.n,'E_LIMIT')
    capacity('command_bytes',validation.recovery and d.bytes or 0,payload,'E_LIMIT')
    if not d.entries[k] or (name=='set' or name=='hset') and not e then capacity('key_bytes',0,#k,'E_LIMIT') end
    validation.done=true
  end
  if name=='get' then
    if e and e.type~='string' then fail('E_WRONGTYPE','WRONGTYPE expected string') end
    if e then spend(#e.value+1); return e.value end
    return nil
  elseif name=='type' then return e and e.type or 'none'
  elseif name=='exists' then
    local scan=j and j.exists or {index=1,count=0}
    if j then j.exists=scan end
    while scan.index<=a.n do
      spend(1)
      local value=live(d,a[scan.index],j and j.tick or tick)
      if value then
        if j and value.deadline then
          j.deadline=math.min(j.deadline or value.deadline,value.deadline)
          if tick>=j.deadline then fail('E_BUSY','database expired during preparation; retry the command') end
        end
        scan.count=scan.count+1
      end
      scan.index=scan.index+1
    end
    return scan.count
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
      if j and not j.read then
        if g then g.job_resize(4096+(e and e.count or 0)*192) end
        j.read={}
      end
      local out=j and j.read or {}
      if e then
        if j then
          while not j.read_done do
            spend(1)
            local f,v=next(e.fields,j.read_cursor)
            if f==nil then j.read_done=true else out[f]=v; j.read_cursor=f end
          end
        else
          spend(e.bytes+e.count*2+1)
          for _,f in ipairs(sorted(e.fields,spend)) do out[f]=e.fields[f] end
        end
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
  if j and not j.owner_id then
    j.owner_id=ownership.begin(rec,j.computer_id and registry.record(j.computer_id),payload,a.n,spend)
  end
  local candidate=j and preparation.stage(d,j.tick,spend,j,g) or stage(d,tick,spend)
  local previous=j and j.previous or {keys=#candidate.order,bytes=candidate.bytes,fields=candidate.fields}
  if j then j.previous=previous end
  local result=j and j.result
  if not j or not j.mutated then
  if name=='set' then
    capacity('value_bytes',e and e.type=='string' and #e.value or 0,#a[2],'E_LIMIT')
    candidate.entries[k]={type='string',value=a[2],bytes=#a[2]}; result='OK'
  elseif name=='del' then
    result=result or 0
    local index=j and j.edit_index or 1
    while index<=a.n do
      spend(1)
      if candidate.entries[a[index]] then candidate.entries[a[index]]=nil; result=result+1 end
      index=index+1
      if j then j.edit_index=index; j.result=result end
    end
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
    local fields
    if j then fields=preparation.fields(e,spend,j,g)
    else
      fields={}
      if e then spend(e.bytes+e.count+1); for f,v in pairs(e.fields) do fields[f]=v end end
    end
    result=result or 0
    local index=j and j.edit_index or 2
    while index<=a.n do
      spend(1)
      if name=='hset' then
        if fields[a[index]]==nil then result=result+1 end
        fields[a[index]]=a[index+1]; index=index+2
      else
        if fields[a[index]]~=nil then result=result+1; fields[a[index]]=nil end
        index=index+1
      end
      if j then j.edit_index=index; j.result=result end
    end
    local scan=j and j.field_totals or {count=0,bytes=0}
    if j then j.field_totals=scan end
    while not scan.done do
      spend(1)
      local f,v=next(fields,scan.cursor)
      if f==nil then scan.done=true
      else
        if name=='hset' then
          local old=e and e.fields[f]
          capacity('key_bytes',old~=nil and #f or 0,#f,'E_LIMIT')
          capacity('value_bytes',old and #old or 0,#v,'E_LIMIT')
        end
        scan.count=scan.count+1; scan.bytes=scan.bytes+#f+#v; scan.cursor=f
      end
    end
    local count,bytes=scan.count,scan.bytes
    capacity('hash_fields',e and e.count or 0,count)
    capacity('hash_bytes',e and e.bytes or 0,bytes)
    if count>0 then candidate.entries[k]={type='hash',fields=fields,count=count,bytes=bytes,deadline=e and e.deadline}
    else candidate.entries[k]=nil end
  else fail('E_ARGUMENT','unknown database command') end
  if j then j.mutated=true; j.result=result end
  end
  if j and j.deadline and tick>=j.deadline then fail('E_BUSY','database expired during preparation; retry the command') end
  if j and name=='expire' and a[2]>0 and candidate.entries[k] then
    candidate.entries[k].deadline=tick+a[2]*60
  end
  return publish(rec,candidate,spend,prepare,result,previous,j,g)
end
local guarded_methods={}
local function invoke(command,computer,rec,tick,spend,guard,...)
  local n=select('#',...)
  local j={tick=tick,argument=1,payload=0,operands=n,computer_id=computer and computer.id}
  local durable=guard and guard.continuation_enabled
  if durable then
    if rec.kv_basis~=rec.database then rec.kv_basis=rec.database; rec.kv_revision=(rec.kv_revision or 0)+1 end
    j=guard.job('kv:'..command,function()
      local policy={}; for _,d in ipairs(budgets.definitions) do if d.key:sub(1,3)=='kv_' then policy[d.key]=shared[d.key] end end
      return {id=rec.id,generation=rec.generation,revision=rec.kv_revision or 0,tick=tick,argument=1,payload=0,operands=n,
        computer_id=computer and computer.id,policy=policy}
    end)
    if not j.admitted then guard.job_resize(4096+n*64); j.admitted=true end
  end
  local function run(...)
    if durable and j.policy then
      for key,value in pairs(j.policy) do if shared[key]~=value then fail('E_BUSY','KV admission settings changed; retry the command') end end
      if j.id~=rec.id or j.generation~=rec.generation or j.revision~=(rec.kv_revision or 0)
        or j.deadline and tick>=j.deadline then
        fail('E_BUSY','database changed or expired during preparation; retry the command')
      end
    end
    return call(command,rec,tick,spend,guard and guard.prepare_result,j,durable and guard or nil,...)
  end
  local ok,result=pcall(run,...)
  if not ok then
    if j.owner_id and not (durable and guard.work_suspended()) then ownership.cancel(j.owner_id); j.owner_id=nil end
    error(result,0)
  end
  return result
end
for _,name in ipairs({'get','set','del','exists','type','hget','hset','hdel','hexists','hgetall','hlen','expire','ttl','persist','getLimits'}) do
  local command=name
  methods[command]=function(computer,rec,wire,tick,spend,...) return invoke(command,computer,rec,tick,spend,nil,...) end
  guarded_methods[command]=function(computer,rec,wire,tick,spend,guard,...)
    return invoke(command,computer,rec,tick,spend,guard,...)
  end
end
-- Fixed host entry used by compact fixtures and lifecycle; not a guest namespace.
M.methods=methods
M.guarded_methods=guarded_methods
function M.initialize(rec)
  if rec.database==nil then rec.database=empty() end
  local ok=pcall(M.audit,rec.database,function() end)
  if not ok then rec.body.minable=false; rec.mining_guard='unsupported-database'; return end
  rec.body.minable=true; rec.mining_guard=nil
  ownership.ensure(rec,function() end)
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
      rec.kv_revision=(rec.kv_revision or 0)+1
    else cursor=cursor+1 end
    if #d.order==0 then d.cursor=1; return end
    d.cursor=cursor>#d.order and 1 or cursor
  end
end
function M.maintenance(tick,spend)
  if not scheduler.try_maintenance(function() ownership.maintenance(spend) end) then return end
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
