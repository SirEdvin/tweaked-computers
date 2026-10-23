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
local work=require('scripts.services.inventory-work')
local M={}
local function arity(n,want) if n~=want then errors.raise('E_ARGUMENT','unexpected argument count; use dot calls') end end
local function fields(value,allowed)
  if type(value)~='table' or getmetatable(value) then errors.raise('E_ARGUMENT','plain table required') end
  for k in pairs(value) do if not allowed[k] then errors.raise('E_ARGUMENT','unknown field') end end
end
local function signal(s,spend)
  fields(s,{type=true,name=true,quality=true})
  if s.type~='item' and s.type~='fluid' and s.type~='virtual' and s.type~='recipe' then errors.raise('E_ARGUMENT','explicit supported signal type required: item, fluid, virtual or recipe') end
  local q=s.quality
  if q==nil then q='normal' end
  if type(s.name)~='string' or #s.name==0 or type(q)~='string' or #q==0 then errors.raise('E_ARGUMENT','prototype names required') end
  spend(#s.name+#q+8)
  local p=prototypes[s.type=='virtual' and 'virtual_signal' or s.type]
  if not p[s.name] or not prototypes.quality[q] or (s.type=='virtual' and (s.name=='signal-each' or s.name=='signal-anything' or s.name=='signal-everything')) then errors.raise('E_RANGE','unknown or wildcard signal/quality') end
  return {type=s.type,name=s.name,quality=q}
end
local function key(s) return s.type..'\0'..s.name..'\0'..s.quality end
local function selection(input)
  if input~='red' and input~='green' then errors.raise('E_ARGUMENT','explicit red or green input required') end
  return input
end
local function array(t,spend,job)
  if type(t)~='table' or getmetatable(t) then errors.raise('E_ARGUMENT','dense array required') end
  job=job or {}; job.n=job.n or 0; job.maximum=job.maximum or 0
  while not job.done do
    spend(1); local k=next(t,job.key)
    if k==nil then job.done=true; break end
    if type(k)~='number' or k%1~=0 or k<1 then errors.raise('E_ARGUMENT','dense array required') end
    job.n=job.n+1; job.maximum=math.max(job.maximum,k); job.key=k
  end
  if job.maximum~=job.n then errors.raise('E_ARGUMENT','dense array required') end
  return job.n
end
local function sort(t,spend,job)
  return work.sort(t,job or {},spend,function(a) return key(a.signal) end)
end
local function canonical(signals,spend,job)
  job=job or {}; job.array=job.array or {}; job.result=job.result or {}; job.seen=job.seen or {}; job.cursor=job.cursor or 1; job.sort=job.sort or {}
  job.source=job.source or signals; signals=job.source
  local n=array(signals,spend,job.array); local result,seen=job.result,job.seen
  while job.cursor<=n do
    local i=job.cursor
    local entry=signals[i]; fields(entry,{signal=true,count=true})
    local s=signal(entry.signal,spend); local k=key(s)
    if seen[k] then errors.raise('E_ARGUMENT','duplicate signal identity') end
    seen[k]=true
    if not errors.integer(entry.count,-2147483648,2147483647) then errors.raise('E_RANGE','signed 32-bit integer count required') end
    if entry.count~=0 then result[#result+1]={signal=s,count=entry.count} end
    job.cursor=i+1
  end
  return sort(result,spend,job.sort)
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
local function native_read(rec,input,spend,job)
  selection(input); job=job or {}
  if not job.native then
    local connected=status(rec); spend(connected[input] and 32 or 16)
    local c=lifecycle.connector(rec,'input',input)
    job.native=connected[input] and (c.owner.get_signals(c.wire_connector_id) or {}) or {}
    job.connected=connected; job.result={}; job.cursor=1; job.sort={}; job.tick=game.tick
  end
  while job.cursor<=#job.native do
    local entry=job.native[job.cursor]
    local s=signal({type=entry.signal.type or 'item',name=entry.signal.name,quality=entry.signal.quality},spend)
    if not errors.integer(entry.count,-2147483648,2147483647) then errors.raise('E_ENGINE','native signal count outside signed 32-bit domain') end
    if entry.count~=0 then job.result[#job.result+1]={signal=s,count=entry.count} end
    job.cursor=job.cursor+1
  end
  return sort(job.result,spend,job.sort),job.connected
end
M.read=native_read
M.canonical=canonical
-- Host-only observation, independent of guest subscriptions and writer state.
-- Read both colors before publishing any part of the candidate.
function M.inspect(rec,tick,spend)
  local red,connected=native_read(rec,'red',spend)
  local green=native_read(rec,'green',spend)
  return {tick=tick,red=red,green=green,connected=connected,output=canonical(rec.output_bank or {},spend)}
end
function M.inspect_input(rec,input,tick,spend,job)
  local values,connected=native_read(rec,input,spend,job)
  return {tick=job and job.tick or tick,values=values,connected=connected[input]}
end
function M.inspect_output(rec,spend,job) return canonical(rec.output_bank or {},spend,job) end
local function project(sample,connected,input,filter,spend,job)
  job=job or {}; job.result=job.result or {}; job.allowed=job.allowed or {}; job.filter=job.filter or 1; job.cursor=job.cursor or 1
  while filter and job.filter<=#filter do
    local k=key(filter[job.filter]); spend(#k+1); job.allowed[k]=true; job.filter=job.filter+1
  end
  while job.cursor<=#sample do
    local entry=sample[job.cursor]; local k=key(entry.signal); spend(#k+4)
    if not filter or job.allowed[k] then job.result[#job.result+1]=entry end
    job.cursor=job.cursor+1
  end
  return job.result,{[input]=connected[input]}
end
local function delta(previous,current,spend,job)
  job=job or {}; job.result=job.result or {}; job.a=job.a or 1; job.b=job.b or 1
  while job.a<=#previous or job.b<=#current do
    local a,b=previous[job.a],current[job.b]
    local ka,kb=a and key(a.signal),b and key(b.signal)
    spend((ka and #ka or 0)+(kb and #kb or 0)+4)
    local old,new,s=0,0
    if a and (not b or ka<=kb) then old=a.count; s=a.signal; job.a=job.a+1 end
    if b and (not a or kb<=ka) then new=b.count; s=b.signal; job.b=job.b+1 end
    if old~=new then job.result[#job.result+1]={signal=s,previous=old,current=new} end
  end
  return job.result
end
local function publish_native(rec,bank,filters)
  local cb=rec.children.output.get_or_create_control_behavior()
  local staged=cb.add_section(); staged.active=false
  if not filters then
    filters={}; for i,e in ipairs(bank) do filters[i]={index=i,value=e.signal,min=e.count} end
  end
  local ok,e=pcall(function()
    staged.filters=filters
    local read=staged.filters
    assert(#read==#filters,'native bank size mismatch')
    for i,f in ipairs(read) do
      local wanted=filters[i]
      assert(f.min==wanted.min and (f.value.type or 'item')==wanted.value.type and f.value.name==wanted.value.name and (f.value.quality or 'normal')==wanted.value.quality,'native bank readback mismatch')
    end
  end)
  if not ok then cb.remove_section(staged.index); error(e,0) end
  for i=cb.sections_count-1,1,-1 do cb.remove_section(i) end
  staged.active=true; cb.enabled=#bank>0
end
local principal=require('scripts.runtime.principal')
local function output(computer,rec,wire,tick,spend,signals,execution,guard)
  local job=work.job(guard,'logic-output'); job.bank=job.bank or {}; job.filters=job.filters or {}; job.authority=job.authority or {}
  local bank=canonical(signals,spend,job.bank)
  while #job.filters<#bank do
    spend(8); local i=#job.filters+1; local e=bank[i]; job.filters[i]={index=i,value=e.signal,min=e.count}
  end
  if guard then guard.prepare_empty_result() end
  -- Native replacement/readback is indivisible; no inactive section survives a yield.
  spend((#bank+#(rec.output_bank or {}))*32+64)
  local target,path=peripheral.authority(computer,rec.id,wire,spend,job.authority)
  if target~=rec then errors.raise('E_UNREACHABLE','writer authority lost') end
  if not computer.powered or not rec.powered or not lifecycle.has_power(rec)
    or not principal.live(computer,execution or principal.program(computer)) then errors.raise('E_UNPOWERED','writer authority or power lost') end
  local old=rec.output_bank or {}
  local ok,e=pcall(publish_native,rec,bank,job.filters)
  if not ok then
    local restored=pcall(publish_native,rec,old)
    if not restored then
      rec.output_recovery={bank=old,owner=rec.output_owner,message='native output restoration failed'}
      lifecycle.clear_output(rec)
    end
    errors.raise('E_ENGINE',(restored and 'native output refused; old bank restored: ' or 'native output failed; output cleared and recovery retained: ')..tostring(e):sub(1,256))
  end
  rec.output_bank=bank; rec.output_owner=principal.owner(computer,execution or principal.program(computer),wire,path)
  rec.output_recovery=nil
end
local function remove_queued(c,id,spend)
  spend(#c.queue*2+1)
  local result,bytes={},0
  for _,item in ipairs(c.queue) do
    if item.event.subscription_id~=id then result[#result+1]=item; bytes=bytes+item.bytes end
  end
  c.queue=result; c.queue_bytes=bytes
end
local function subscribe(c,rec,wire,tick,spend,guard,options,handler)
  fields(options,{input=true,signals=true,initial=true}); local input=selection(options.input)
  if options.initial~=nil and type(options.initial)~='boolean' then errors.raise('E_ARGUMENT','initial must be boolean') end
  local job=work.job(guard,'logic-subscribe'); job.array=job.array or {}; job.read=job.read or {}; job.project=job.project or {}
  local filter
  if options.signals~=nil then
    local n=array(options.signals,spend,job.array); if n==0 then errors.raise('E_ARGUMENT','filter cannot be empty') end
    job.filter=job.filter or {}; job.seen=job.seen or {}; filter=job.filter
    while #filter<n do
      local normalized=signal(options.signals[#filter+1],spend); local k=key(normalized)
      if job.seen[k] then errors.raise('E_ARGUMENT','duplicate filter identity') end
      job.seen[k]=true; filter[#filter+1]=normalized
    end
  end
  local raw,connected=native_read(rec,input,spend,job.read)
  local baseline,selected=project(raw,connected,input,filter,spend,job.project)
  return runtime.subscribe(c,'signal_changed',handler,{peripheral=rec.id,generation=rec.generation,wire=wire,input=input,signals=filter,
    previous=baseline,connected=selected,initial=options.initial==true,resync=false},spend)
end
local methods={}
local function method(name,n,fn)
  methods[name]=function(c,rec,wire,tick,spend,execution,guard,...)
    arity(select('#',...),n)
    if name=='setOutput' then return output(c,rec,wire,tick,spend,...,execution,guard) end
    if name=='clearOutput' then return output(c,rec,wire,tick,spend,{},execution,guard) end
    return fn(c,rec,wire,tick,spend,guard,...)
  end
end
method('readSignal',2,function(c,r,w,t,spend,guard,input,s)
  selection(input); s=signal(s,spend); status(r); spend(32)
  local red,green=defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green
  return r.children.input.get_signal(s,input=='red' and red or green)
end)
method('readSignals',1,function(c,r,w,t,spend,guard,input) return (native_read(r,input,spend,work.job(guard,'logic-read'))) end)
method('getInputStatus',0,function(c,r,w,t,spend) spend(16); local s=status(r); return {red_connected=s.red,green_connected=s.green} end)
method('getOutput',0,function(c,r,w,t,spend,guard) return canonical(r.output_bank or {},spend,work.job(guard,'logic-get-output')) end)
method('setOutput',1,output)
method('clearOutput',0,function(c,r,w,t,spend) output(c,r,w,t,spend,{}) end)
method('subscribe',2,subscribe)
method('unsubscribe',1,function(c,r,w,t,spend,guard,id)
  if type(id)~='string' then errors.raise('E_ARGUMENT','subscription ID required') end
  local sub=c.subscriptions[id]
  if sub and (sub.event_name~='signal_changed' or sub.details.peripheral~=r.id or sub.details.wire~=w) then errors.raise('E_ARGUMENT','subscription belongs to another binding') end
  spend(#c.queue*2+1)
  local existed=runtime.unsubscribe(c,id,spend); remove_queued(c,id,function() end); return existed
end)
method('getLimits',0,function(c,r,w,t,spend)
  local result=data.copy(limits,spend)
  result.sample_interval_ticks=1
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
end
local function discard(c,sub)
  remove_queued(c,sub.id,function() end); sub.details.resync=true; sub.details.pending=nil
end
function M.sample(tick,spend)
  local root=registry.get()
  local admitted=scheduler.try_maintenance(function() spend(limits.registry_entries+limits.aggregate_subscriptions+1) end)
  if not admitted then
    -- Deferral retains the run and last admitted baseline; next delivery resyncs.
    for _,id in ipairs(root.order) do
      local c=root.computers[id]
      if c and c.status=='running' then
        for _,sub in pairs(c.subscriptions) do
          if sub.event_name=='signal_changed' then sub.details.resync=true end
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
          local needs=devices[d.peripheral] or {}; devices[d.peripheral]=needs
          subscriptions[#subscriptions+1]={computer=c,sub=sub}
          needs[d.input]=true
        end
      end
    end
  end
  local names={}; for name in pairs(devices) do names[#names+1]=name end
  local sorted_admitted=scheduler.try_maintenance(function() spend((#subscriptions+#names)*math.max(1,math.ceil(math.log(#subscriptions+#names+1)/math.log(2)))*4+1) end)
  if not sorted_admitted then
    for _,entry in ipairs(subscriptions) do
      if entry.computer.status=='running' then entry.sub.details.resync=true end
    end
    return
  end
  table.sort(subscriptions,function(a,b) return a.sub.sequence<b.sub.sequence end)
  table.sort(names)
  local samples={}
  for _,name in ipairs(names) do
    local rec=registry.record(name)
    if rec and rec.powered and rec.body.valid and lifecycle.has_power(rec) then
      local ok,result=pcall(function()
        local admitted,value=scheduler.try_maintenance(function()
          rec.logic_pending_sample=rec.logic_pending_sample or {red={},green={},tick=tick}
          local job=rec.logic_pending_sample
          local needs=devices[name]; local connected={}; local red,green,c
          if needs.red then red,c=native_read(rec,'red',spend,job.red); connected.red=c.red end
          if needs.green then green,c=native_read(rec,'green',spend,job.green); connected.green=c.green end
          local sample={red=red,green=green,connected=connected,tick=job.tick}
          rec.logic_sample=sample; rec.logic_pending_sample=nil; return sample
        end)
        if not admitted then return {deferred=true} end
        return value
      end)
      samples[name]=ok and result or {failure=type(result)=='table' and result.code and result or errors.new('E_ENGINE','logic input sampling failed')}
    elseif rec then
      rec.logic_pending_sample=nil
    end
  end
  for _,entry in ipairs(subscriptions) do
    local c,sub=entry.computer,entry.sub; local d=sub.details; local r=registry.record(d.peripheral)
    if c.status=='running' and c.subscriptions[sub.id]==sub then
      local ok,result=pcall(function()
        local admitted=scheduler.try_maintenance(function()
          spend(#c.queue*2+limits.subscriptions+16)
          if not c.powered then discard(c,sub); return end
          if samples[d.peripheral] and samples[d.peripheral].deferred then d.resync=true; return end
          d.pending=d.pending or {authority={},project={},delta={}}
          local job=d.pending
          local target=peripheral.authority(c,d.peripheral,d.wire,spend,job.authority)
          if target~=r or not r or r.generation~=d.generation then M.revoke(c,d.peripheral,d.wire); return end
          if not r.powered or not samples[r.id] then discard(c,sub); return end
          if samples[r.id].failure then error(samples[r.id].failure,0) end
          job.sample=job.sample or samples[r.id]
          local s=job.sample; local current,connected=project(s[d.input],s.connected,d.input,d.signals,spend,job.project)
          local previous=d.initial and {} or d.previous
          local pc=d.connected
          if d.initial then pc={}; for k in pairs(connected) do pc[k]=false end end
          local changes=delta(previous,current,spend,job.delta)
          local resync=d.resync or c.needs_input_resync==true
          if d.initial or resync or #changes>0 or pc.red~=connected.red or pc.green~=connected.green then
            local payload={name='signal_changed',subscription_id=sub.id,peripheral=r.id,wire=d.wire,input=d.input,sample_tick=s.tick,
              initial=d.initial,resync=resync,previous=previous,current=current,changes=changes,previous_connected=pc,connected=connected}
            job.event=job.event or {}
            local item=runtime.prepare_event(c,sub.handler,payload,tick,spend,nil,job.event)
            if not item then return end
            spend(16) -- Publication/loss metadata and the observation commit.
            local accepted,reason=runtime.publish_event(c,item,tick)
            if accepted or reason=='overflow' then
              d.previous=current; d.connected=connected; d.resync=not accepted
              if accepted then d.initial=false end
            end
          end
          d.pending=nil
        end)
        if not admitted then d.resync=true end
      end)
      if not ok and type(result)=='table' and result.code=='E_NETWORK_PENDING' then d.pending=nil; d.resync=true
      elseif not ok and c.status=='running' then runtime.fault(c,type(result)=='table' and result.code and result or errors.new('E_ENGINE','logic sampling failed'),tick) end
    end
  end
  for _,id in ipairs(root.order) do local c=root.computers[id]; if c then c.needs_input_resync=nil end end
end
registry.register_cleanup('logic-subscriptions',function(rec,run,reason)
  if rec.kind=='computer' then
    if reason=='power_loss' then
      for _,sub in pairs(rec.subscriptions) do if sub.event_name=='signal_changed' then discard(rec,sub) end end
    elseif reason=='authority_changed' then
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
M.output=output
peripheral.register_type('logic',{methods=methods,with_principal=true,with_guard=true})
peripheral.register_revocation('logic-subscriptions',function(c,name,wire,reason,execution)
  if not execution or execution.kind=='program' then M.revoke(c,name,wire) end
end)
scheduler.register_phase('sample','logic-input',M.sample)
return M
