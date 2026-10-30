-- Native INPUT sampling and one OUTPUT bank; NETWORK remains discovery only.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local peripheral=require('scripts.services.peripheral')
local lifecycle=require('scripts.lifecycle')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local data=require('scripts.runtime.data')
local defs=require('scripts.device-definitions')
local M={}
local signal_prototypes={item='item',fluid='fluid',virtual='virtual_signal',recipe='recipe',entity='entity',
  ['space-location']='space_location',['asteroid-chunk']='asteroid_chunk',quality='quality'}
local function arity(n,want) if n~=want then errors.raise('E_ARGUMENT','unexpected argument count; use dot calls') end end
local function fields(value,allowed)
  if type(value)~='table' or getmetatable(value) then errors.raise('E_ARGUMENT','plain table required') end
  for k in pairs(value) do if not allowed[k] then errors.raise('E_ARGUMENT','unknown field') end end
end
local function signal(s,spend)
  fields(s,{type=true,name=true,quality=true})
  local kind=s.type==nil and 'item' or s.type
  if type(kind)~='string' or not signal_prototypes[kind] then errors.raise('E_ARGUMENT','native signal type required') end
  local q=s.quality
  if q==nil then q='normal' end
  if type(s.name)~='string' or #s.name==0 or type(q)~='string' then errors.raise('E_ARGUMENT','prototype names required') end
  spend(#s.name+#q+8)
  local p=prototypes[signal_prototypes[kind]]
  if not p[s.name] or not prototypes.quality[q] or (s.type=='virtual' and (s.name=='signal-each' or s.name=='signal-anything' or s.name=='signal-everything')) then errors.raise('E_RANGE','unknown or wildcard signal/quality') end
  return {type=s.type,name=s.name,quality=s.quality}
end
local function key(s) return (s.type or 'item')..'\0'..s.name..'\0'..(s.quality or 'normal') end
local function selection(input)
  if input~='red' and input~='green' then errors.raise('E_ARGUMENT','explicit red or green input required') end
  return input
end
local function array(t,spend)
  if type(t)~='table' or getmetatable(t) then errors.raise('E_ARGUMENT','dense array required') end
  local n=0
  for k in pairs(t) do
    spend(1); n=n+1
    if not errors.integer(k,1,9007199254740991) then errors.raise('E_ARGUMENT','dense array required') end
  end
  for i=1,n do if t[i]==nil then errors.raise('E_ARGUMENT','dense array required') end end
  return n
end
local function validate_output(signals,spend)
  local n=array(signals,spend); local result,seen={},{}
  for i=1,n do
    local entry=signals[i]; fields(entry,{signal=true,count=true})
    local s=signal(entry.signal,spend); local k=key(s)
    if seen[k] then errors.raise('E_ARGUMENT','duplicate signal identity') end
    seen[k]=true
    if not errors.integer(entry.count,-2147483648,2147483647) then errors.raise('E_RANGE','signed 32-bit integer count required') end
    if entry.count~=0 then result[#result+1]={signal=s,count=entry.count} end
  end
  -- LogisticFilterIndex is uint16 in the pinned native section API.
  if #result>65535 then errors.raise('E_RANGE','native output section index exceeded') end
  return result
end
local function status(rec)
  local result={}
  for _,wire in ipairs({'red','green'}) do
    local c=lifecycle.connector(rec,'input',wire)
    if not c then errors.raise('E_UNREACHABLE','input endpoint unavailable') end
    result[wire]=c.real_connection_count>0
  end
  return result
end
local function native_read(rec,input,spend)
  selection(input); local connected=status(rec)
  spend(32)
  local c=lifecycle.connector(rec,'input',input)
  return c.owner.get_signals(c.wire_connector_id) or {},connected
end
-- Host-only observation, independent of guest subscriptions and writer state.
-- Read both colors before publishing any part of the candidate.
function M.inspect_output(rec,spend)
  spend(32)
  local cb=rec.children.output.get_or_create_control_behavior()
  local section=cb.sections_count>0 and cb.get_section(1)
  local result={}
  for _,filter in ipairs(section and section.filters or {}) do
    local s=filter.value
    result[#result+1]={signal={type=s.type,name=s.name,quality=s.quality},count=filter.min}
  end
  return result
end
function M.inspect(rec,tick,spend)
  local red,connected=native_read(rec,'red',spend)
  local green=native_read(rec,'green',spend)
  return {tick=tick,red=red,green=green,connected=connected,output=M.inspect_output(rec,spend)}
end
function M.inspect_input(rec,input,tick,spend)
  local values,connected=native_read(rec,input,spend)
  return {tick=tick,values=values,connected=connected[input]}
end

local function project(sample,connected,input,filter,spend)
  local result,c={},{}
  c[input]=connected[input]
  local allowed
  if not filter then return sample,c end
  allowed={}; for _,s in ipairs(filter) do allowed[key(s)]=true end
  for _,entry in ipairs(sample) do if allowed[key(entry.signal)] then result[#result+1]=entry end end
  return result,c
end
local function delta(previous,current,spend)
  local before,after,union={},{},{}
  for _,e in ipairs(previous) do local k=key(e.signal); before[k]=e; union[k]=e.signal end
  for _,e in ipairs(current) do local k=key(e.signal); after[k]=e; union[k]=e.signal end
  local changes={}
  for k,s in pairs(union) do
    local a=before[k] and before[k].count or 0; local b=after[k] and after[k].count or 0
    if a~=b then changes[#changes+1]={signal=s,previous=a,current=b} end
  end
  return changes
end
local function publish_native(rec,bank)
  local cb=rec.children.output.get_or_create_control_behavior()
  local staged=cb.add_section(); staged.active=false
  local filters={}
  for i,e in ipairs(bank) do
    local s=e.signal
    filters[i]={index=i,value={type=s.type,name=s.name,quality=s.quality or 'normal'},min=e.count}
  end
  local ok,e=pcall(function()
    staged.filters=filters
    local read=staged.filters
    assert(#read==#filters,'native bank size mismatch')
    for i,f in ipairs(read) do
      local wanted=filters[i]
      assert(f.min==wanted.min and key(f.value)==key(wanted.value),'native bank readback mismatch')
    end
  end)
  if not ok then cb.remove_section(staged.index); error(e,0) end
  for i=cb.sections_count-1,1,-1 do cb.remove_section(i) end
  staged.active=true; cb.enabled=#bank>0
end
local principal=require('scripts.runtime.principal')
local function output(computer,rec,wire,tick,spend,signals,execution)
  local bank=validate_output(signals,spend)
  spend(#registry.owned_outputs().order*2+8)
  spend(64)
  local target,path=peripheral.authority(computer,rec.id,wire,spend)
  if target~=rec then errors.raise('E_UNREACHABLE','writer authority lost') end
  local old=M.inspect_output(rec,spend)
  local ok,e=pcall(publish_native,rec,bank)
  if not ok then
    local restored=pcall(publish_native,rec,old)
    if not restored then
      rec.output_recovery={bank=old,owner=rec.output_owner,message='native output restoration failed'}
      lifecycle.clear_output(rec)
    end
    errors.raise('E_ENGINE',(restored and 'native output refused; old bank restored: ' or 'native output failed; output cleared and recovery retained: ')..tostring(e):sub(1,256))
  end
  rec.output_owner=principal.owner(computer,execution or principal.program(computer),wire,path)
  registry.output_changed(rec)
  rec.output_recovery=nil
end
local function remove_queued(c,id,spend)
  spend(#c.queue*2+1)
  local result,bytes={},0
  for _,item in ipairs(c.queue) do
    if item.event.subscription_id~=id then result[#result+1]=item; bytes=bytes+item.bytes end
  end
  c.queue=result; c.queue_bytes=bytes
  registry.ready_changed(c)
end
local function subscribe(c,rec,wire,tick,spend,options,handler)
  fields(options,{input=true,signals=true,initial=true}); local input=selection(options.input)
  if options.initial~=nil and type(options.initial)~='boolean' then errors.raise('E_ARGUMENT','initial must be boolean') end
  local filter
  if options.signals~=nil then
    local n=array(options.signals,spend); if n==0 then errors.raise('E_ARGUMENT','filter cannot be empty') end
    filter={}; local seen={}
    for _,s in ipairs(options.signals) do local normalized=signal(s,spend); local k=key(normalized); if seen[k] then errors.raise('E_ARGUMENT','duplicate filter identity') end; seen[k]=true; filter[#filter+1]=normalized end
  end
  local raw,connected=native_read(rec,input,spend)
  local baseline,selected=project(raw,connected,input,filter,spend)
  return runtime.subscribe(c,'signal_changed',handler,{peripheral=rec.id,generation=rec.generation,wire=wire,input=input,signals=filter,
    previous=baseline,connected=selected,initial=options.initial==true,resync=false},spend,true)
end
local methods={}
local function method(name,n,fn)
  methods[name]=function(c,rec,wire,tick,spend,execution,...)
    arity(select('#',...),n)
    if name=='setOutput' then return output(c,rec,wire,tick,spend,...,execution) end
    if name=='clearOutput' then return output(c,rec,wire,tick,spend,{},execution) end
    return fn(c,rec,wire,tick,spend,...)
  end
end
method('readSignal',2,function(c,r,w,t,spend,input,s)
  selection(input); s=signal(s,spend); status(r); spend(32)
  local red,green=defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green
  return r.children.input.get_signal(s,input=='red' and red or green)
end)
method('readSignals',1,function(c,r,w,t,spend,input) return (native_read(r,input,spend)) end)
method('getInputStatus',0,function(c,r,w,t,spend) spend(16); local s=status(r); return {red_connected=s.red,green_connected=s.green} end)
method('getOutput',0,function(c,r,w,t,spend) return M.inspect_output(r,spend) end)
method('setOutput',1,output)
method('clearOutput',0,function(c,r,w,t,spend) output(c,r,w,t,spend,{}) end)
method('subscribe',2,subscribe)
method('unsubscribe',1,function(c,r,w,t,spend,id)
  if type(id)~='string' then errors.raise('E_ARGUMENT','subscription ID required') end
  local sub=c.subscriptions[id]
  if sub and (sub.event_name~='signal_changed' or sub.details.peripheral~=r.id or sub.details.wire~=w) then errors.raise('E_ARGUMENT','subscription belongs to another binding') end
  spend(#c.queue*2+1)
  local existed=runtime.unsubscribe(c,id,spend); remove_queued(c,id,function() end); return existed
end)
method('getLimits',0,function(c,r,w,t,spend)
  local result=data.copy(limits,spend)
  result.sample_interval_ticks=1; result.notification_latency_ticks=limits.topology_latency_ticks
  return result
end)
local function observers()
  local s=registry.get().logic_observers
  if type(s)~='table' or s.version~=1 or type(s.order)~='table' or type(s.inputs)~='table'
    or type(s.input_order)~='table' or type(s.computers)~='table' then
    errors.raise('E_UNSUPPORTED','unsupported logic observation membership; source and observations retained')
  end
  return s
end
local function forget(s,entry)
  local computer=s.computers[entry.computer.id]
  if not computer or computer[entry.sub.id]~=entry then return end
  computer[entry.sub.id]=nil
  if not next(computer) then s.computers[entry.computer.id]=nil end
  for i,e in ipairs(s.order) do if e==entry then table.remove(s.order,i); break end end
  local input=entry.input
  if input then
    input.subscribers[entry.sub.id]=nil
    if not next(input.subscribers) then
      s.inputs[input.key]=nil
      for i,e in ipairs(s.input_order) do if e==input then table.remove(s.input_order,i); break end end
    end
  end
end
local function subscription_changed(c,sub,adding,spend)
  local s=observers()
  if spend then spend(#s.order+#s.input_order+#c.queue*2+4) end
  local entries=s.computers[c.id]
  if not adding then
    if entries and entries[sub.id] then forget(s,entries[sub.id]) end
    remove_queued(c,sub.id,function() end)
    return
  end
  local d=sub.details
  local entry={computer=c,sub=sub,generation=c.generation,run_id=c.run_id}
  if type(d)=='table' and type(d.peripheral)=='string' and type(d.generation)=='number'
    and (d.input=='red' or d.input=='green') then
    local k=d.peripheral..'/'..d.generation..'/'..d.input
    local input=s.inputs[k]
    if not input then
      input={key=k,id=d.peripheral,generation=d.generation,color=d.input,subscribers={}}
      s.inputs[k]=input
      local i=#s.input_order+1
      while i>1 and s.input_order[i-1].key>k do i=i-1 end
      table.insert(s.input_order,i,input)
    end
    input.subscribers[sub.id]=entry; entry.input=input
  end
  if not entries then entries={}; s.computers[c.id]=entries end
  entries[sub.id]=entry
  local i=#s.order+1
  while i>1 and s.order[i-1].sub.sequence>sub.sequence do i=i-1 end
  table.insert(s.order,i,entry)
end
runtime.register_subscription_lifecycle('signal_changed',subscription_changed)
registry.register_initializer('logic-observers',function(root)
  if not registry.supported(root) or root.logic_observers~=nil then return end
  root.logic_observers={version=1,order={},inputs={},input_order={},computers={}}
  for _,id in ipairs(root.order) do
    local c=root.computers[id]
    if c and c.status=='running' and type(c.subscriptions)=='table' then
      for _,sub in pairs(c.subscriptions) do
        if sub.event_name=='signal_changed' then
          subscription_changed(c,sub,true)
          local d=sub.details
          for _,item in ipairs(c.queue) do
            local e=item.event
            if type(d)=='table' and not item.circuit and e.name=='signal_changed' and e.subscription_id==sub.id
              and e.run_id==c.run_id and e.peripheral==d.peripheral and e.wire==d.wire and e.input==d.input then item.circuit=true end
          end
        end
      end
    end
  end
end)
function M.revoke(c,name,wire)
  local entries=observers().computers[c.id]
  if not entries then return end
  local removed={}
  for id,entry in pairs(entries) do
    local d=entry.sub.details
    if d.peripheral==name and d.wire==wire then removed[#removed+1]=id end
  end
  table.sort(removed)
  for _,id in ipairs(removed) do runtime.unsubscribe(c,id) end
end
local function discard(c,sub)
  remove_queued(c,sub.id,function() end); sub.details.resync=true
end
function M.sample(tick,spend)
  local root=registry.get(); local valid,s=pcall(observers)
  if not valid then root.scheduling_diagnostic=s; return end
  if #s.order==0 then return end
  local subscriptions={}
  local admitted=scheduler.try_maintenance(function()
    spend(#s.order+#s.input_order+1)
    for i,entry in ipairs(s.order) do subscriptions[i]=entry end
  end)
  if not admitted then
    -- Retirement removes entries; keep taking the current head, not a stale index.
    while s.order[1] do
      local entry=s.order[1]; local c=entry.computer
      if c.status=='running' then runtime.fault(c,errors.new('E_BUSY','logic sampling maintenance exhausted; run stopped'),tick)
      else forget(s,entry) end
    end
    return
  end
  local samples={}
  for _,input in ipairs(s.input_order) do
    local rec=registry.record(input.id)
    if rec and rec.generation==input.generation and lifecycle.available(rec) then
      local ok,result=pcall(function()
        local admitted,value=scheduler.try_maintenance(function()
          return M.inspect_input(rec,input.color,tick,spend)
        end)
        if not admitted then errors.raise('E_BUSY','logic sampling envelope exhausted; run stopped rather than losing observations') end
        return value
      end)
      samples[input.key]=ok and result or {failure=type(result)=='table' and result.code and result or errors.new('E_ENGINE','logic input sampling failed')}
    end
  end
  local observed={}
  for _,entry in ipairs(subscriptions) do
    local c,sub=entry.computer,entry.sub; local d=sub.details
    if root.computers[c.id]==c and c.status=='running' and c.subscriptions[sub.id]==sub and c.generation==entry.generation and c.run_id==entry.run_id then
      observed[c.id]=c
      local ok,result=pcall(function()
        local admitted=scheduler.try_maintenance(function()
          if type(d)~='table' or not entry.input or d.input~=entry.input.color or d.peripheral~=entry.input.id or d.generation~=entry.input.generation then
            errors.raise('E_ARGUMENT','retained logic subscription requires its original explicit red or green input; update source and restart')
          end
          spend(#c.queue*2+limits.subscriptions+16)
          if not lifecycle.available(c) then discard(c,sub); return end
          local r=registry.record(d.peripheral)
          local target=peripheral.authority(c,d.peripheral,d.wire,spend)
          if target~=r or not r or r.generation~=d.generation then M.revoke(c,d.peripheral,d.wire); return end
          local sample=samples[entry.input.key]
          if not sample then discard(c,sub); return end
          if sample.failure then error(sample.failure,0) end
          local current,connected=project(sample.values,{[d.input]=sample.connected},d.input,d.signals,spend)
          local previous=d.initial and {} or d.previous
          local pc=d.connected
          if d.initial then pc={}; for k in pairs(connected) do pc[k]=false end end
          local changes=delta(previous,current,spend)
          local resync=d.resync or c.needs_input_resync==true
          if d.initial or resync or #changes>0 or pc.red~=connected.red or pc.green~=connected.green then
            local payload={name='signal_changed',subscription_id=sub.id,peripheral=r.id,wire=d.wire,input=d.input,sample_tick=tick,
              initial=d.initial,resync=resync,previous=previous,current=current,changes=changes,previous_connected=pc,connected=connected}
            spend(256)
            if runtime.enqueue(c,sub.handler,payload,tick,nil,{circuit=true}) then
              d.previous=current; d.connected=connected; d.initial=false; d.resync=false
            end
          end
        end)
        if not admitted then errors.raise('E_BUSY','logic notification envelope exhausted; run stopped rather than losing observations') end
      end)
      if not ok and c.status=='running' then runtime.fault(c,type(result)=='table' and result.code and result or errors.new('E_ENGINE','logic sampling failed'),tick) end
    else forget(s,entry) end
  end
  for _,c in pairs(observed) do c.needs_input_resync=nil end
end
registry.register_cleanup('logic-subscriptions',function(rec,run,reason)
  if rec.kind=='computer' then
    local s=observers(); local entries=s.computers[rec.id]; local removed={}
    for id in pairs(entries or {}) do removed[#removed+1]=id end
    table.sort(removed)
    for _,id in ipairs(removed) do runtime.unsubscribe(rec,id) end
  elseif rec.kind=='logic' then
    local s=observers(); local affected={}
    for _,color in ipairs({'red','green'}) do
      local input=s.inputs[rec.id..'/'..rec.generation..'/'..color]
      if input then for _,entry in pairs(input.subscribers) do affected[entry.computer.id]=entry.computer end end
    end
    for _,c in pairs(affected) do M.revoke(c,rec.id,'red'); M.revoke(c,rec.id,'green') end
    lifecycle.clear_output(rec)
  end
end)
peripheral.register_type('logic',{methods=methods,with_principal=true})
peripheral.register_revocation('logic-subscriptions',function(c,name,wire,reason,execution)
  if not execution or execution.kind=='program' then M.revoke(c,name,wire) end
end)
scheduler.register_phase('sample','logic-input',M.sample)
return M
