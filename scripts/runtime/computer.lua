local registry = require('scripts.registry')
local compiler = require('scripts.runtime.compiler')
local admission = require('scripts.runtime.admission')
local limits = require('scripts.runtime.limits')
local errors = require('scripts.runtime.errors')
local data = require('scripts.runtime.data')
local principal = require('scripts.runtime.principal')
local M = {}
local providers = {}
local shell_lifecycle
function M.register_shell_lifecycle(fn) assert(not shell_lifecycle); shell_lifecycle=fn end
local general={peripheral_attach=true,peripheral_detach=true,monitor_resize=true,monitor_touch=true,power_restored=true,modem_message=true}
local MAX=9007199254740991
local function root() local r=registry.get(); if not registry.supported(r) then errors.raise('E_UNSUPPORTED','unsupported storage; data retained') end; return r end
local function arity(n,min,max) if n<min or n>(max or min) then errors.raise('E_ARGUMENT','unexpected argument count; use dot calls') end end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
function M.context(rec,tick) return admission.context(root().ledger,rec.id,tick) end
function M.log(rec,text,tick,spend)
  if type(text)~='string' then errors.raise('E_ARGUMENT','log requires a string') end
  if #text>limits.console_bytes then errors.raise('E_LIMIT','log entry too large') end
  if spend then spend(#text+(#rec.logs)^2+1) end
  while #rec.logs>=limits.console_entries or rec.log_bytes+#text>limits.console_bytes do
    local old=table.remove(rec.logs,1); rec.log_bytes=rec.log_bytes-#old.text
    rec.log_truncated=true
  end
  rec.logs[#rec.logs+1]={text=text,tick=tick}; rec.log_bytes=rec.log_bytes+#text
end
function M.retire(rec,status,reason)
  local cleaned=registry.cleanup(rec,rec.run_id,reason or status)
  rec.queue={}; rec.queue_bytes=0; rec.timers={}; rec.subscriptions={}
  rec.invocation=nil
  rec.status=cleaned and status or 'faulted'
  if not cleaned then rec.diagnostic=errors.new('E_ENGINE','host teardown failed; cleanup recovery retained') end
  return cleaned
end
function M.fault(rec,diagnostic,tick)
  M.retire(rec,'faulted','fault')
  -- Host diagnostics have scalar fields and may be shared by sampler deliveries.
  -- Own the retained table before attaching this computer's authoritative identity.
  local owned={}; for key,value in pairs(diagnostic) do owned[key]=value end
  diagnostic=owned
  diagnostic.source_revision=rec.active and rec.active.revision or nil
  diagnostic.run_id=rec.run_id
  rec.diagnostic=diagnostic
  M.log(rec,(diagnostic.code or 'E_PROGRAM')..': '..(diagnostic.message or 'program failed'):sub(1,512),tick)
end
function M.stop(id)
  root(); local rec=registry.computer(id)
  local ok=M.retire(rec,'stopped','stop')
  if shell_lifecycle then ok=shell_lifecycle(rec,'stop') and ok end
  return ok
end
function M.resource_refused(rec,diagnostic,tick)
  local owned={}; for key,value in pairs(diagnostic) do owned[key]=value end
  owned.source_revision=rec.active and rec.active.revision or nil; owned.run_id=rec.run_id
  rec.diagnostic=owned
  local text=owned.code..': '..owned.message
  if #text<=limits.console_bytes then M.log(rec,text,tick) else rec.log_truncated=true end
end
function M.reset_state(id)
  root()
  local rec=registry.computer(id)
  if rec.status=='running' then errors.raise('E_BUSY','stop the computer before resetting state') end
  rec.state={}; rec.state_sizes={}; rec.state_bytes=16; rec.state_entries=0
  rec.state_nodes=1; rec.state_node_sizes={}
end
function M.save(id,source,expected_revision)
  root(); local rec=registry.computer(id)
  if type(source)~='string' then errors.raise('E_ARGUMENT','source must be a string') end
  if #source>limits.source_bytes then errors.raise('E_LIMIT','source byte limit exceeded') end
  if not errors.integer(expected_revision,0,MAX) or expected_revision~=rec.saved_revision then errors.raise('E_BUSY','source revision conflict; retain draft and review current source') end
  if rec.saved_revision==MAX then errors.raise('E_CAPACITY','source revision exhausted') end
  rec.saved_source=source; rec.saved_revision=rec.saved_revision+1
  return rec.saved_revision
end
function M.validate(id,tick)
  local rec=registry.computer(id)
  return compiler.compile(rec.saved_source,M.context(rec,tick))
end
function M.activate(id,tick,expected_revision)
  local r=root(); local rec=registry.computer(id)
  if expected_revision~=nil and expected_revision~=rec.saved_revision then return nil,errors.new('E_BUSY','saved revision changed') end
  if rec.schema_version~=1 then return nil,errors.new('E_UNSUPPORTED','unsupported computer schema; data retained') end
  local active=0
  for _,other in pairs(r.computers) do if other.status=='running' then active=active+1 end end
  if rec.status~='running' and active>=limits.active_computers then return nil,errors.new('E_CAPACITY','active computer capacity reached') end
  if not errors.integer(rec.run_generation,0,MAX-1) then return nil,errors.new('E_CAPACITY','run generation exhausted') end
  local plan,e=M.validate(id,tick)
  if not plan then rec.candidate_diagnostic=e; return nil,e end
  -- Validation is finished before the previous generation is retired.
  if not M.retire(rec,'stopped','activation') then return nil,rec.diagnostic end
  if shell_lifecycle and not shell_lifecycle(rec,'activation') then return nil,errors.new('E_ENGINE','shell cleanup failed; session retained') end
  rec.run_generation=rec.run_generation+1
  rec.run_id=rec.id..'/run-'..string.format('%.0f',rec.run_generation)
  rec.active={source=plan.source,revision=rec.saved_revision,api_version=1,compiler_version=limits.compiler_version,storage_version=limits.storage_version,handlers=plan.handlers}
  rec.status='running'; rec.diagnostic=nil; rec.candidate_diagnostic=nil
  if plan.handlers.start then M.enqueue(rec,'start',{name='start'},tick) end
  return rec.run_id
end
function M.check_active(rec)
  local a=rec.active
  return rec.schema_version==1 and type(a)=='table' and a.api_version==1 and a.compiler_version==limits.compiler_version and a.storage_version==limits.storage_version and type(a.source)=='string' and type(a.handlers)=='table' and type(rec.run_id)=='string'
end
local function handler(rec,name)
  if type(name)~='string' or not M.check_active(rec) or rec.active.handlers[name]~=true then errors.raise('E_ARGUMENT','declared handler name required') end
  return name
end
function M.subscribe(rec,event_name,handler_name,details,spend)
  -- Trusted providers may register their own documented event kinds here;
  -- computer.on below separately restricts the guest general-event surface.
  handler(rec,handler_name)
  if type(event_name)~='string' or #event_name==0 or #event_name>limits.identifier_bytes then errors.raise('E_ARGUMENT','bounded event name required') end
  if spend then spend(limits.registry_entries+limits.aggregate_subscriptions+limits.subscriptions+1) end
  local copied
  if details~=nil then copied=data.copy(details,spend) end
  local total=0; for _,c in pairs(root().computers) do total=total+count(c.subscriptions) end
  if count(rec.subscriptions)>=limits.subscriptions or total>=limits.aggregate_subscriptions then errors.raise('E_CAPACITY','subscription capacity reached') end
  local seq=registry.sequence(); local id=rec.run_id..'/sub-'..string.format('%.0f',seq)
  rec.subscriptions[id]={id=id,event_name=event_name,handler=handler_name,sequence=seq,details=copied}
  return id
end
function M.unsubscribe(rec,id,spend)
  local prefix=rec.run_id..'/sub-'
  if type(id)~='string' or #id>128 or id:sub(1,#prefix)~=prefix then errors.raise('E_ARGUMENT','ID belongs to another computer/run') end
  if spend then spend(#id+1) end
  local exists=rec.subscriptions[id]~=nil; rec.subscriptions[id]=nil; return exists
end
function M.prepare_event(rec,name,payload,tick,spend,metadata)
  if rec.status~='running' then return false,'inactive' end
  handler(rec,name)
  if not rec.powered and payload.name~='timer' and payload.name~='start' then return false,'unpowered' end
  local event,stats=data.copy(payload,spend,limits.event_queue_bytes)
  if type(event)~='table' or type(event.name)~='string' then errors.raise('E_ARGUMENT','named event payload required') end
  if stats.nodes+7>limits.data_nodes then errors.raise('E_LIMIT','event leaves no room for envelope metadata') end
  -- Host overrides all authoritative envelope fields, never trusts injected ones.
  event.tick=tick; event.computer_id=rec.id; event.run_id=rec.run_id
  local bytes=stats.bytes+128+#rec.id+#rec.run_id
  return {handler=name,event=event,bytes=bytes,timer_id=metadata and metadata.timer_id}
end
-- Immediate trusted publication of an owned, prepaid prepare_event result.
function M.publish_event(rec,item,tick)
  if rec.status~='running' or item.event.run_id~=rec.run_id then return false,'inactive' end
  local bytes=item.bytes
  if #rec.queue>=limits.event_queue_entries or rec.queue_bytes+bytes>limits.event_queue_bytes then
    M.fault(rec,errors.new('E_CAPACITY','event queue overflow; run stopped and owned outputs cleared'),tick)
    return false,'overflow'
  end
  item.event.sequence=registry.sequence()
  rec.queue[#rec.queue+1]=item
  rec.queue_bytes=rec.queue_bytes+bytes
  return true
end
function M.enqueue(rec,name,payload,tick,spend,metadata)
  local item,reason=M.prepare_event(rec,name,payload,tick,spend,metadata)
  if not item then return false,reason end
  return M.publish_event(rec,item,tick)
end
function M.emit(id,event_name,payload,tick,spend)
  local rec=registry.computer(id)
  if not general[event_name] then errors.raise('E_ARGUMENT','unsupported general event') end
  if rec.status~='running' or not rec.powered then return false end
  if spend then spend(#rec.queue+limits.subscriptions^2+limits.subscriptions+1) end
  local subscriptions={}
  for _,sub in pairs(rec.subscriptions) do if sub.event_name==event_name then subscriptions[#subscriptions+1]=sub end end
  table.sort(subscriptions,function(a,b) return a.sequence<b.sequence end)

  -- Do not alias caller payload or a subscription's event copy.
  local copied,stats=data.copy(payload or {},spend,limits.event_queue_bytes); copied.name=event_name
  -- Reserve every delivery before publication; deferral cannot deliver a prefix.
  if spend then spend(#subscriptions*(stats.bytes+stats.nodes*2+#event_name+32)) end
  for _,sub in ipairs(subscriptions) do
    if not M.enqueue(rec,sub.handler,copied,tick,nil) then return false end
  end
  return true
end
function M.set_power(id,powered,tick,spend)
  root()
  local rec=registry.computer(id)
  if type(powered)~='boolean' then errors.raise('E_ARGUMENT','boolean power state required') end
  if rec.powered==powered then return false end
  -- Reserve bounded restoration notification copies before the power change.
  if spend then spend(#rec.queue+1+(powered and limits.subscriptions*512+limits.subscriptions^2 or 0)) end
  rec.powered=powered
  if not powered then
    rec.outage_start_tick=tick
    if not registry.cleanup(rec,rec.run_id,'power_loss') then M.retire(rec,'faulted','cleanup_failure') end
    local retained={}; local bytes=0
    for _,item in ipairs(rec.queue) do
      if item.event.name=='timer' or item.event.name=='start' then retained[#retained+1]=item; bytes=bytes+item.bytes end
    end
    rec.queue=retained; rec.queue_bytes=bytes
  else
    rec.needs_input_resync=true -- Host logic sampling consumes this before dispatch.
    if rec.status=='running' then M.emit(id,'power_restored',{outage_start_tick=rec.outage_start_tick,restored_tick=tick},tick) end
    rec.outage_start_tick=nil
  end
  return true
end
function M.register_services(name,fn)
  assert(type(name)=='string' and type(fn)=='function' and not providers[name],'invalid/duplicate host service provider')
  assert(count(providers)<limits.host_hooks,'host provider capacity')
  providers[name]=fn
end
function M.services(rec,tick,guard,execution)
  execution=execution or principal.program(rec)
  local function spend(n) guard.spend(n) end
  local function current()
    guard.check()
    principal.check(rec,execution)
  end
  local api={}
  local function method(name,min,max,fn)
    api[name]=function(...)
      current(); arity(select('#',...),min,max)
      return fn(...)
    end
  end
  method('getID',0,0,function() return rec.id end)
  method('getLabel',0,0,function() return rec.label end)
  method('setLabel',0,1,function(label)
    if label~=nil and (type(label)~='string' or #label>limits.identifier_bytes) then errors.raise('E_ARGUMENT','bounded label or nil required') end
    spend(label and #label+1 or 1); rec.label=label
  end)
  method('getTick',0,0,function() return tick end)
  method('getLimits',0,0,function() return (data.copy(limits,spend)) end)
  method('getState',1,1,function(key)
    data.key(key); spend(#key+1)
    if rec.state[key]~=nil then return (data.copy(rec.state[key],spend)) end
    return nil
  end)
  method('setState',2,2,function(key,value)
    data.key(key); spend(#key+1)
    local copied,stats=data.copy(value,spend)
    local old=rec.state_sizes[key] or 0; local size=stats.bytes+#key+16
    local entries=rec.state_entries+(rec.state[key]==nil and 1 or 0)
    local nodes=rec.state_nodes-(rec.state_node_sizes[key] or 0)+stats.nodes
    if entries>limits.state_entries or rec.state_bytes-old+size>limits.state_bytes or nodes>limits.data_nodes then errors.raise('E_CAPACITY','state capacity exceeded') end
    rec.state[key]=copied; rec.state_sizes[key]=size; rec.state_entries=entries; rec.state_bytes=rec.state_bytes-old+size
    rec.state_nodes=nodes; rec.state_node_sizes[key]=stats.nodes
  end)
  method('deleteState',1,1,function(key)
    data.key(key); spend(#key+1)
    if rec.state[key]==nil then return false end
    rec.state[key]=nil; rec.state_bytes=rec.state_bytes-rec.state_sizes[key]; rec.state_sizes[key]=nil; rec.state_entries=rec.state_entries-1
    rec.state_nodes=rec.state_nodes-rec.state_node_sizes[key]; rec.state_node_sizes[key]=nil
    return true
  end)
  method('log',1,1,function(text) M.log(rec,text,tick,spend) end)
  method('on',2,2,function(event_name,handler_name)
    if not general[event_name] then errors.raise('E_ARGUMENT','unsupported general event name') end
    return M.subscribe(rec,event_name,handler_name,nil,spend)
  end)
  local function owned_id(id,kind)
    if type(id)~='string' or #id>128 or id:sub(1,#rec.run_id+#kind+2)~=rec.run_id..'/'..kind..'-' then errors.raise('E_ARGUMENT','ID belongs to another computer/run') end
  end
  method('off',1,1,function(id) return M.unsubscribe(rec,id,spend) end)
  local function timer(delay,name,payload,recurring)
    if not errors.integer(delay,1,MAX-tick) then errors.raise('E_RANGE','positive safe integer duration required') end
    handler(rec,name); spend(limits.timers+#rec.queue+1)
    local pending=count(rec.timers)
    for _,item in ipairs(rec.queue) do if item.timer_id and not rec.timers[item.timer_id] then pending=pending+1 end end
    if pending>=limits.timers then errors.raise('E_CAPACITY','timer capacity reached') end
    local copied,size
    if payload~=nil then
      copied,size=data.copy(payload,spend,limits.event_queue_bytes-512)
      if size.nodes+10>limits.data_nodes then errors.raise('E_LIMIT','timer payload leaves no room for event metadata') end
    end
    local seq=registry.sequence(); local id=rec.run_id..'/timer-'..string.format('%.0f',seq)
    rec.timers[id]={id=id,handler=name,deadline=tick+delay,interval=recurring and delay or nil,payload=copied,payload_bytes=size and size.bytes or 0,sequence=seq}
    return id
  end
  method('after',2,3,function(delay,name,payload) return timer(delay,name,payload,false) end)
  method('every',2,3,function(delay,name,payload) return timer(delay,name,payload,true) end)
  method('cancelTimer',1,1,function(id)
    owned_id(id,'timer'); spend(#id+#rec.queue*2+limits.timers+1)
    local exists=rec.timers[id]~=nil; rec.timers[id]=nil
    local retained={}; local bytes=0
    for _,item in ipairs(rec.queue) do
      if item.timer_id==id then exists=true else retained[#retained+1]=item; bytes=bytes+item.bytes end
    end
    rec.queue=retained; rec.queue_bytes=bytes; return exists
  end)
  local map={computer=api,peripheral={}}
  local names={}; for name in pairs(providers) do names[#names+1]=name end; table.sort(names)
  for _,name in ipairs(names) do
    local extras=providers[name](rec,tick,guard,execution)
    for namespace,methods in pairs(extras or {}) do
      assert(namespace=='computer' or namespace=='peripheral','unknown service namespace')
      for key,fn in pairs(methods) do assert(not map[namespace][key] and type(fn)=='function','service collision'); map[namespace][key]=fn end
    end
  end
  if execution.kind=='shell' then
    for _,name in ipairs({'stop','on','off','after','every','cancelTimer'}) do
      api[name]=function() current(); errors.raise('E_UNSUPPORTED','use a saved handler program or explicit UI lifecycle controls') end
    end
  end
  return map
end
return M
