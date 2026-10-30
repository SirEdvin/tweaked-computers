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
function M.revoke(c,name,wire)
  local removed={}
  for id,sub in pairs(c.subscriptions) do
    if sub.event_name=='signal_changed' and sub.details.peripheral==name and sub.details.wire==wire then
      removed[id]=true; c.subscriptions[id]=nil
    end
  end
  local queue,bytes={},0
  for _,item in ipairs(c.queue) do
    if not removed[item.event.subscription_id] then queue[#queue+1]=item; bytes=bytes+item.bytes end
  end
  c.queue=queue; c.queue_bytes=bytes
  registry.ready_changed(c)
end
local function discard(c,sub)
  remove_queued(c,sub.id,function() end); sub.details.resync=true
end
function M.sample(tick,spend)
  local root=registry.get()
  local admitted=scheduler.try_maintenance(function() spend(limits.registry_entries+limits.aggregate_subscriptions+1) end)
  if not admitted then
    -- No transient may silently vanish if earlier maintenance used this tick.
    for _,id in ipairs(root.order) do
      local c=root.computers[id]
      if c and c.status=='running' then
        for _,sub in pairs(c.subscriptions) do
          if sub.event_name=='signal_changed' then runtime.fault(c,errors.new('E_BUSY','logic sampling maintenance exhausted; run stopped'),tick); break end
        end
      end
    end
    return
  end
  local subscriptions={}; local devices={}
  for _,id in ipairs(root.order) do
    local c=root.computers[id]
    if c and c.status=='running' then
      for _,sub in pairs(c.subscriptions) do
        if sub.event_name=='signal_changed' then
          local d=sub.details
          if d.input~='red' and d.input~='green' then
            -- Validate retained registrations before any queued callback dispatch.
            -- Never translate legacy combined input or replay its pending effects.
            runtime.fault(c,errors.new('E_ARGUMENT','retained logic subscription requires explicit red or green input; update source and restart'),tick)
            break
          end
          -- Older accepted events lacked the private dispatch marker. Keep their
          -- snapshots/byte accounting intact; never infer trust from a guest name.
          for _,item in ipairs(c.queue) do
            local e=item.event
            if not item.circuit and e.name=='signal_changed' and e.subscription_id==sub.id
              and e.run_id==c.run_id and e.peripheral==d.peripheral and e.wire==d.wire and e.input==d.input then
              item.circuit=true
            end
          end
          local needs=devices[d.peripheral] or {}; devices[d.peripheral]=needs
          subscriptions[#subscriptions+1]={computer=c,sub=sub}
          needs[d.input]=true
        end
      end
    end
  end
  local names={}; for name in pairs(devices) do names[#names+1]=name end
  local sorted_admitted=scheduler.try_maintenance(function() spend((#subscriptions)^2+(#names)^2+1) end)
  if not sorted_admitted then
    for _,entry in ipairs(subscriptions) do
      if entry.computer.status=='running' then runtime.fault(entry.computer,errors.new('E_BUSY','logic ordering work exhausted; run stopped'),tick) end
    end
    return
  end
  table.sort(subscriptions,function(a,b) return a.sub.sequence<b.sub.sequence end)
  table.sort(names)
  local samples={}
  for _,name in ipairs(names) do
    local rec=registry.record(name)
    if rec and lifecycle.available(rec) then
      local ok,result=pcall(function()
        local admitted,value=scheduler.try_maintenance(function()
          local needs=devices[name]; local connected=status(rec); local red,green
          if needs.red then red=native_read(rec,'red',spend) end
          if needs.green then green=native_read(rec,'green',spend) end
          local sample={red=red,green=green,connected=connected,tick=tick}
          return sample
        end)
        if not admitted then errors.raise('E_BUSY','logic sampling envelope exhausted; run stopped rather than losing observations') end
        return value
      end)
      samples[name]=ok and result or {failure=type(result)=='table' and result.code and result or errors.new('E_ENGINE','logic input sampling failed')}
    end
  end
  for _,entry in ipairs(subscriptions) do
    local c,sub=entry.computer,entry.sub; local d=sub.details; local r=registry.record(d.peripheral)
    if c.status=='running' and c.subscriptions[sub.id]==sub then
      local ok,result=pcall(function()
        local admitted=scheduler.try_maintenance(function()
          spend(#c.queue*2+limits.subscriptions+16)
          if not lifecycle.available(c) then discard(c,sub); return end
          local target=peripheral.authority(c,d.peripheral,d.wire,spend)
          if target~=r or not r or r.generation~=d.generation then M.revoke(c,d.peripheral,d.wire); return end
          if not samples[r.id] then discard(c,sub); return end
          if samples[r.id].failure then error(samples[r.id].failure,0) end
          local s=samples[r.id]; local current,connected=project(s[d.input],s.connected,d.input,d.signals,spend)
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
    end
  end
  for _,id in ipairs(root.order) do local c=root.computers[id]; if c then c.needs_input_resync=nil end end
end
registry.register_cleanup('logic-subscriptions',function(rec,run,reason)
  if rec.kind=='computer' then
    if reason=='authority_changed' then
      local bindings={}
      for _,sub in pairs(rec.subscriptions) do
        if sub.event_name=='signal_changed' then bindings[#bindings+1]={name=sub.details.peripheral,wire=sub.details.wire} end
      end
      for _,binding in ipairs(bindings) do M.revoke(rec,binding.name,binding.wire) end
    end
  elseif rec.kind=='logic' then
    for _,id in ipairs(registry.get().order) do local c=registry.get().computers[id]; if c then M.revoke(c,rec.id,'red'); M.revoke(c,rec.id,'green') end end
    lifecycle.clear_output(rec)
  end
end)
peripheral.register_type('logic',{methods=methods,with_principal=true})
peripheral.register_revocation('logic-subscriptions',function(c,name,wire,reason,execution)
  if not execution or execution.kind=='program' then M.revoke(c,name,wire) end
end)
scheduler.register_phase('sample','logic-input',M.sample)
return M
