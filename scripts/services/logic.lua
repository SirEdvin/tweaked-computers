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
local M={signal_slots=64,filter_signals=64}
local function arity(n,want) if n~=want then errors.raise('E_ARGUMENT','unexpected argument count; use dot calls') end end
local function fields(value,allowed)
  if type(value)~='table' or getmetatable(value) then errors.raise('E_ARGUMENT','plain table required') end
  for k in pairs(value) do if not allowed[k] then errors.raise('E_ARGUMENT','unknown field') end end
end
local function signal(s,spend)
  fields(s,{type=true,name=true,quality=true})
  if s.type~='item' and s.type~='fluid' and s.type~='virtual' then errors.raise('E_ARGUMENT','explicit signal type required') end
  local q=s.quality
  if q==nil then q='normal' end
  if type(s.name)~='string' or #s.name==0 or #s.name>limits.identifier_bytes or type(q)~='string' or #q>limits.identifier_bytes then errors.raise('E_ARGUMENT','bounded prototype names required') end
  spend(#s.name+#q+8)
  local p=prototypes[s.type=='virtual' and 'virtual_signal' or s.type]
  if not p[s.name] or not prototypes.quality[q] or (s.type=='virtual' and (s.name=='signal-each' or s.name=='signal-anything' or s.name=='signal-everything')) then errors.raise('E_RANGE','unknown or wildcard signal/quality') end
  return {type=s.type,name=s.name,quality=q}
end
local function key(s) return s.type..'\0'..s.name..'\0'..s.quality end
local function selection(input)
  if input~='red' and input~='green' and input~='both' then errors.raise('E_ARGUMENT','red, green or both input required') end
  return input
end
local function array(t,max,spend)
  if type(t)~='table' or getmetatable(t) then errors.raise('E_ARGUMENT','dense array required') end
  local n=0
  for k in pairs(t) do
    spend(1); n=n+1
    if not errors.integer(k,1,max) then errors.raise('E_ARGUMENT','dense bounded array required') end
    if n>max then errors.raise('E_CAPACITY','signal capacity exceeded') end
  end
  for i=1,n do if t[i]==nil then errors.raise('E_ARGUMENT','dense array required') end end
  return n
end
local function sort(t,spend)
  spend(#t+1)
  table.sort(t,function(a,b) local x,y=key(a.signal),key(b.signal); spend(#x+#y+1); return x<y end)
  return t
end
local function canonical(signals,spend)
  local n=array(signals,M.signal_slots,spend); local result,seen={},{}
  for i=1,n do
    local entry=signals[i]; fields(entry,{signal=true,count=true})
    local s=signal(entry.signal,spend); local k=key(s)
    if seen[k] then errors.raise('E_ARGUMENT','duplicate signal identity') end
    seen[k]=true
    if not errors.integer(entry.count,-2147483648,2147483647) then errors.raise('E_RANGE','signed 32-bit integer count required') end
    if entry.count~=0 then result[#result+1]={signal=s,count=entry.count} end
  end
  return sort(result,spend)
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
  selection(input); local values={}; local size=0; local connected=status(rec)
  for _,wire in ipairs({'red','green'}) do
    if input=='both' or input==wire then
      -- No count query exists in 2.0.77. The immutable prototype universe is
      -- an upper bound on native signal tuples, including every quality. Admit
      -- that opaque materialization before get_signals, then bound our snapshot.
      local universe=(#prototypes.item+#prototypes.fluid+#prototypes.virtual_signal)*#prototypes.quality
      if not errors.integer(universe,1,1000000) then errors.raise('E_LIMIT','native signal prototype universe exceeds supported query envelope') end
      spend(universe*8+M.signal_slots*16+16)
      local c=lifecycle.connector(rec,'input',wire)
      local native=c.owner.get_signals(c.wire_connector_id) or {}
      if #native>M.signal_slots then errors.raise('E_LIMIT','native input signal inventory exceeds signal_slots') end
      for _,entry in ipairs(native) do
        local s=signal({type=entry.signal.type or 'item',name=entry.signal.name,quality=entry.signal.quality},spend); local k=key(s); local old=values[k]
        if not old then size=size+1; if size>M.signal_slots then errors.raise('E_LIMIT','combined input inventory exceeds signal_slots') end end
        local sum=(old and old.count or 0)+entry.count
        values[k]={signal=s,count=((sum+2147483648)%4294967296)-2147483648}
      end
    end
  end
  local result={}; for _,entry in pairs(values) do if entry.count~=0 then result[#result+1]=entry end end
  return sort(result,spend),connected
end
local function project(sample,connected,input,filter,spend)
  local result,c={},{}
  if input=='both' or input=='red' then c.red=connected.red end
  if input=='both' or input=='green' then c.green=connected.green end
  local allowed
  if filter then allowed={}; for _,s in ipairs(filter) do spend(#key(s)+1); allowed[key(s)]=true end end
  for _,entry in ipairs(sample) do spend(#key(entry.signal)+4); if not allowed or allowed[key(entry.signal)] then result[#result+1]=entry end end
  return result,c
end
local function delta(previous,current,spend)
  local before,after,union={},{},{}
  for _,e in ipairs(previous) do local k=key(e.signal); spend(#k+4); before[k]=e; union[k]=e.signal end
  for _,e in ipairs(current) do local k=key(e.signal); spend(#k+4); after[k]=e; union[k]=e.signal end
  local changes={}
  for k,s in pairs(union) do
    local a=before[k] and before[k].count or 0; local b=after[k] and after[k].count or 0
    if a~=b then changes[#changes+1]={signal=s,previous=a,current=b} end
  end
  return sort(changes,spend)
end
local function publish_native(rec,bank)
  local cb=rec.children.output.get_or_create_control_behavior()
  local staged=cb.add_section(); staged.active=false
  local filters={}
  for i,e in ipairs(bank) do filters[i]={index=i,value=e.signal,min=e.count} end
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
local function output(computer,rec,wire,tick,spend,signals)
  local bank=canonical(signals,spend)
  spend(limits.registry_entries+M.signal_slots*256+64)
  local count=0
  for _,id in ipairs(registry.get().order) do local r=registry.record(id); if r.kind=='logic' and r.output_owner then count=count+1 end end
  if not rec.output_owner and count>=limits.aggregate_owned_outputs then errors.raise('E_CAPACITY','owned output capacity reached') end
  local target,path=peripheral.authority(computer,rec.id,wire,spend)
  if target~=rec then errors.raise('E_UNREACHABLE','writer authority lost') end
  local old=rec.output_bank or {}
  local ok,e=pcall(publish_native,rec,bank)
  if not ok then
    local restored=pcall(publish_native,rec,old)
    if not restored then
      rec.output_recovery={bank=old,owner=rec.output_owner,message='native output restoration failed'}
      lifecycle.clear_output(rec)
    end
    errors.raise('E_ENGINE',(restored and 'native output refused; old bank restored: ' or 'native output failed; output cleared and recovery retained: ')..tostring(e):sub(1,256))
  end
  rec.output_bank=bank; rec.output_owner={computer_id=computer.id,run_id=computer.run_id,wire=wire,path=path}
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
local function subscribe(c,rec,wire,tick,spend,options,handler)
  fields(options,{input=true,signals=true,initial=true}); local input=selection(options.input)
  if options.initial~=nil and type(options.initial)~='boolean' then errors.raise('E_ARGUMENT','initial must be boolean') end
  local filter
  if options.signals~=nil then
    local n=array(options.signals,M.filter_signals,spend); if n==0 then errors.raise('E_ARGUMENT','filter cannot be empty') end
    filter={}; local seen={}
    for _,s in ipairs(options.signals) do local normalized=signal(s,spend); local k=key(normalized); if seen[k] then errors.raise('E_ARGUMENT','duplicate filter identity') end; seen[k]=true; filter[#filter+1]=normalized end
  end
  spend(limits.registry_entries+limits.aggregate_subscriptions+1)
  local active={}
  for _,id in ipairs(registry.get().order) do
    local computer=registry.get().computers[id]
    if computer then for _,sub in pairs(computer.subscriptions) do if sub.event_name=='signal_changed' then active[sub.details.peripheral]=true end end end
  end
  local n=0; for _ in pairs(active) do n=n+1 end
  if not active[rec.id] and n>=limits.active_logic_handlers then errors.raise('E_CAPACITY','sampled handler capacity reached') end
  local raw,connected
  if rec.logic_sample and rec.logic_sample.tick==tick and rec.logic_sample[input] then raw=rec.logic_sample[input]; connected=rec.logic_sample.connected
  else raw,connected=native_read(rec,input,spend) end
  local baseline,selected=project(raw,connected,input,filter,spend)
  return runtime.subscribe(c,'signal_changed',handler,{peripheral=rec.id,generation=rec.generation,wire=wire,input=input,signals=filter,
    previous=baseline,connected=selected,initial=options.initial==true,resync=false},spend)
end
local methods={}
local function method(name,n,fn)
  methods[name]=function(c,rec,wire,tick,spend,...)
    arity(select('#',...),n); return fn(c,rec,wire,tick,spend,...)
  end
end
method('readSignal',2,function(c,r,w,t,spend,input,s)
  selection(input); s=signal(s,spend); status(r); spend(32)
  local red,green=defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green
  if input=='both' then
    local a=r.children.input.get_signal(s,red); local b=r.children.input.get_signal(s,green)
    return ((a+b+2147483648)%4294967296)-2147483648
  end
  return r.children.input.get_signal(s,input=='red' and red or green)
end)
method('readSignals',1,function(c,r,w,t,spend,input) return (data.copy((native_read(r,input,spend)),spend)) end)
method('getInputStatus',0,function(c,r,w,t,spend) spend(16); local s=status(r); return {red_connected=s.red,green_connected=s.green} end)
method('getOutput',0,function(c,r,w,t,spend) return (data.copy(r.output_bank or {},spend)) end)
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
  result.signal_slots=M.signal_slots; result.filter_signals=M.filter_signals; result.sample_interval_ticks=1; result.notification_latency_ticks=limits.topology_latency_ticks
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
          subscriptions[#subscriptions+1]={computer=c,sub=sub}
          local d=sub.details; local needs=devices[d.peripheral] or {}; devices[d.peripheral]=needs
          needs[d.input]=true
          if d.input=='both' then needs.red=true; needs.green=true end
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
    if rec and rec.powered and rec.body.valid and rec.body.energy>=defs.devices.logic.watts/60 then
      local ok,result=pcall(function()
        local admitted,value=scheduler.try_maintenance(function()
          local needs=devices[name]; local connected=status(rec); local red,green
          if needs.red then red=native_read(rec,'red',spend) end
          if needs.green then green=native_read(rec,'green',spend) end
          local combined
          if needs.both then
            combined={}; local map={}
            spend(M.signal_slots*256+16)
            for _,e in ipairs(red) do map[key(e.signal)]={signal=e.signal,count=e.count} end
            for _,e in ipairs(green) do local k=key(e.signal); local old=map[k]; local n=(old and old.count or 0)+e.count; map[k]={signal=e.signal,count=((n+2147483648)%4294967296)-2147483648} end
            local n=0; for _,e in pairs(map) do n=n+1; if e.count~=0 then combined[#combined+1]=e end end
            if n>M.signal_slots then errors.raise('E_LIMIT','combined input inventory exceeds signal_slots') end
            sort(combined,spend)
          end
          local sample={red=red,green=green,both=combined,connected=connected,tick=tick}
          rec.logic_sample=sample; return sample
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
          if not c.powered then discard(c,sub); return end
          local target=peripheral.authority(c,d.peripheral,d.wire,spend)
          if target~=r or not r or r.generation~=d.generation then M.revoke(c,d.peripheral,d.wire); return end
          if not r.powered or not samples[r.id] then discard(c,sub); return end
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
            -- Prepay complete bounded event copying before queue/baseline changes.
            local copied,stats=data.copy(payload,spend,limits.event_queue_bytes)
            spend(stats.bytes+stats.nodes+128)
            if runtime.enqueue(c,sub.handler,copied,tick,nil) then
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
peripheral.register_type('logic',{methods=methods})
peripheral.register_revocation('logic-subscriptions',M.revoke)
scheduler.register_phase('sample','logic-input',M.sample)
return M
