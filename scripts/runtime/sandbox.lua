local limits = require('scripts.runtime.limits')
local errors = require('scripts.runtime.errors')
local admission = require('scripts.runtime.admission')
local memory = require('scripts.runtime.memory')
local M = {}

function M.new(context, services, shell, durable)
  local G = {shell_enabled=shell~=nil,continuation_enabled=durable~=nil}
  local poison, line, column, depth = nil, 1, 1, 0
  local owned = durable and durable.owned or setmetatable({}, {__mode='k'})
  local protected = setmetatable({}, {__mode='k'})
  -- shortcut: table payloads only; finish frame/temporary accounting before production wiring.
  local heap=durable and context.memory_owner
  local function string_charge(items,value)
    if type(value)=='string' then items[#items+1]={value,#value+32} end
  end
  local function table_charges(items,t,keys,changed,values)
    G.host_work(#keys*12+4,#keys*4+4)
    items[#items+1]={t,192+48*#keys}
    for _,k in ipairs(keys) do
      local v=t[k]
      if changed and changed[k]~=nil then v=values[k] end
      string_charge(items,k); string_charge(items,v)
    end
  end
  local function retained(value)
    if durable and (type(value)=='function' or type(value)=='table' and protected[value]) then
      errors.raise('E_UNSUPPORTED','continuation containers require encoded callable/API values')
    end
  end
  local function own(t)
    if durable then
      local keys={}
      for k,v in pairs(t) do G.host_work(1,1); retained(k); retained(v); keys[#keys+1]=k end
      if heap then
        local items={}; table_charges(items,t,keys)
        memory.acquire_all(heap,items)
      end
      if not owned[t] then durable.owned_order[#durable.owned_order+1]=t end
      owned[t]={keys=keys}
    else owned[t]=true end
    return t
  end
  local callable = setmetatable({}, {__mode='k'})
  local handle_arguments = setmetatable({}, {__mode='k'}) -- Host-only opt-in, not Data.
  local bindings=setmetatable({},{__mode='k'})
  local symbol_values,symbol_names={},{}
  function G.symbol(value) return symbol_names[value] end
  function G.resolve_symbol(name) return symbol_values[name] end
  function G.encoded_type(value)
    if not durable or type(value)~='table' then return end
    if durable.functions and durable.functions[value] then return 'function' end
    local binding=durable.bindings[value]
    if binding then return binding.method and 'function' or 'table' end
    local path=durable.symbols[value]
    if path then return type(symbol_values[path]) end
  end
  local restore_binding
  local call_frames,service_frames={},{}
  local call_checkpoint,checkpoint_codec
  function G.call_checkpoint(checkpoint,codec) call_checkpoint=checkpoint; checkpoint_codec=codec end
  local function checkpoint_result(result,prepared)
    if prepared then return prepared.called end
    if checkpoint_codec then return checkpoint_codec.encode(result) end
    -- Scalar vertical slice only; wider value/binding graphs are a later gate.
    for i=2,result.n do
      local t=type(result[i])
      if t~='nil' and t~='boolean' and t~='string' and t~='number' then
        errors.raise('E_UNSUPPORTED','continuation slice requires scalar host results')
      end
    end
    return result
  end
  local function restored_result(result)
    if result and checkpoint_codec then return checkpoint_codec.decode(result) end
    return result
  end
  local function prepare_checkpoint(result)
    if call_checkpoint and checkpoint_codec then
      G.host_work(result.n*2+4,result.n*2+4)
      call_checkpoint.prepared=checkpoint_codec.prepare(result)
    end
  end
  function G.bind_value(value,descriptor) bindings[value]=descriptor end
  function G.binding(value) return bindings[value] end
  function G.is_callable(value) return callable[value]~=nil end
  function G.binding_resolver(fn) assert(not restore_binding); restore_binding=fn end
  function G.restore_binding(descriptor,facade) return assert(restore_binding,'binding provider unavailable')(descriptor,facade) end
  function G.is_plain(value) return owned[value] and not protected[value] and getmetatable(value)==nil end
  function G.accept_handle(fn,index)
    assert(type(fn)=='function' and index==1,'invalid trusted handle introspector')
    handle_arguments[fn]=index
  end
  local sentinel = {} -- Private, ephemeral and never returned through guest pcall.
  local function fatal(reason)
    poison = reason or 'callback budget exhausted'
    error(sentinel,0)
  end
  function G.check() if poison then error(sentinel,0) end end
  function G.stop_requested() return poison=='stopped' end
  function G.work_suspended() return poison~=nil and poison~='stopped' end
  function G.spend(n)
    G.check()
    if not admission.reserve(context,'work',n or 1) then fatal() end
  end
  -- Host-only proofs; never exposed as guest values or accepted from guest Data.
  function G.replay_work(charges)
    G.check()
    if not admission.replay_work(context,charges) then fatal() end
  end
  local function allocate(n)
    G.check()
    if not admission.reserve(context,'allocations',n) then fatal('callback allocation budget exhausted') end
  end
  function G.host_work(work,allocations) G.spend(work); allocate(allocations) end
  function G.step(source_line,source_column) line=source_line or line; column=source_column or column; G.spend(1) end
  function G.enter(source_line,source_column,parameters)
    G.step(source_line,source_column); G.spend(parameters); allocate(parameters)
  end
  function G.loop(source_line,source_column,bindings)
    G.step(source_line,source_column); G.spend(bindings)
  end
  function G.bind(n,...)
    if n>limits.tuple_entries then fatal('local width exceeded') end
    G.spend(n+1); allocate(n); return G.values(...)
  end
  function G.diagnostic(e)
    if poison then return {code=poison == 'stopped' and 'E_STOP' or 'E_BUDGET', message=poison, line=line, column=column} end
    local record=durable and owned[e]
    local resource=errors.resource_diagnostic(e) or type(record)=='table' and record.resource
    if type(resource)=='table' then
      local diagnostic={}; for key,value in pairs(resource) do diagnostic[key]=value end
      diagnostic.line=diagnostic.line or line; diagnostic.column=diagnostic.column or column
      return diagnostic
    end
    if type(e) == 'table' and getmetatable(e) == nil then
      return {code=type(e.code)=='string' and e.code:sub(1,64) or 'E_PROGRAM',message=type(e.message)=='string' and e.message:sub(1,1024) or 'program raised an error',line=line,column=column,
        field=type(e.field)=='string' and e.field:sub(1,128) or nil,
        peripheral=type(e.peripheral)=='string' and e.peripheral:sub(1,128) or nil,
        device=type(e.device)=='string' and e.device:sub(1,128) or nil}
    end
    -- Native exception may contain generated text but cannot contain a host table address.
    return {code='E_PROGRAM',message=type(e)=='string' and e:sub(1,1024):gsub('computer:%d+: ','') or 'program raised an error',line=line,column=column}
  end
  local function fail(message) errors.raise('E_ARGUMENT',message) end
  local function integer(n,a,b)
    if not errors.integer(n,a,b) then fail('integer outside allowed range') end
    return n
  end
  local function string_value(s)
    if type(s) ~= 'string' then fail('string required') end
    if #s > limits.string_bytes then errors.raise('E_LIMIT','string size exceeded') end
    return s
  end
  local function plain(t)
    if type(t) ~= 'table' or not owned[t] or protected[t] or getmetatable(t) ~= nil then fail('guest-owned plain table required') end
    return t
  end
  local function key(k)
    local typ = type(k)
    if typ == 'nil' or (typ=='number' and k~=k) then fail('invalid table key') end
    if typ=='string' then string_value(k); G.spend(#k+1)
    elseif typ=='table' then if not owned[k] and not protected[k] and not G.encoded_type(k) then fail('untrusted key') end
    elseif typ=='function' then if not callable[k] then fail('untrusted key') end
    elseif typ~='number' and typ~='boolean' then fail('invalid key type') end
  end
  function G.scalar(v)
    G.spend(1)
    local typ=type(v)
    if typ=='string' then string_value(v); G.spend(#v)
    elseif typ=='table' then if not owned[v] and not protected[v] and not G.encoded_type(v) then fail('untrusted value') end
    elseif typ=='function' then if not callable[v] then fail('untrusted function') end
    elseif typ~='number' and typ~='boolean' and typ~='nil' then fail('untrusted value') end
    return v
  end
  function G.number(n)
    G.spend(1)
    if type(n)=='string' then string_value(n); G.spend(#n); n=tonumber(n) end
    if type(n)~='number' then fail('numeric operand required') end
    return n
  end
  function G.values(...)
    local n=select('#',...)
    if n>limits.tuple_entries then fatal('tuple width exceeded') end
    G.spend(n+1)
    return ...
  end
  function G.prepare_descriptor(n)
    integer(n,0,limits.handler_names); G.spend(n+1); allocate(n*2+1)
  end
  function G.closure(fn) allocate(1); G.spend(1); callable[fn]='guest function'; return fn end
  -- Closed host helpers prepay the immediate return before publication. Match
  -- the active callee, not an enclosing guest/pcall frame.
  local function prepare_return(fn,...)
    local frame=call_frames[#call_frames]
    if not frame or frame.fn~=fn then return end
    local result=table.pack(...)
    assert(not frame.prepared_return and result.n<=limits.tuple_entries)
    G.spend(result.n+1); allocate(result.n+1)
    for i=1,result.n do G.scalar(result[i]) end
    frame.prepared_return=result
    prepare_checkpoint(result)
    return true
  end
  function G.call(fn,...)
    G.check()
    if type(fn)~='function' then fail('callable function required') end
    -- Top-level handlers are compiler-generated; nested values are guarded closures.
    local n=select('#',...)
    if n>limits.tuple_entries then fatal('argument width exceeded') end
    G.spend(n+1); allocate(n+1)
    if depth>=limits.callback_depth then fatal('callback call depth exhausted') end
    local caller_line,caller_column=line,column
    depth=depth+1
    local frame={fn=fn}; call_frames[#call_frames+1]=frame
    local result=call_checkpoint and restored_result(call_checkpoint.call_result)
    if not result then
      result=table.pack(pcall(fn,...))
      if call_checkpoint and result[1] then
        call_checkpoint.call_result=checkpoint_result(result,frame.prepared_return and call_checkpoint.prepared)
      end
    end
    call_frames[#call_frames]=nil
    depth=depth-1
    G.check()
    if not result[1] then error(result[2],0) end
    if result.n-1>limits.tuple_entries then fatal('return width exceeded') end
    if frame.prepared_return then
      local expected=frame.prepared_return
      if result.n~=expected.n+1 then fatal('trusted return width contract violated') end
      for i=1,expected.n do if not rawequal(result[i+1],expected[i]) then fatal('trusted return contract violated') end end
    elseif frame.boolean_result then
      if result.n~=2 or type(result[2])~='boolean' then fatal('trusted boolean return contract violated') end
    else
      G.spend(result.n); allocate(result.n)
      for i=2,result.n do G.scalar(result[i]) end
    end
    line,column=caller_line,caller_column
    return table.unpack(result,2,result.n)
  end
  function G.iter(fn,state,control)
    if type(fn)~='function' then fail('iterator function required') end
    G.spend(3); allocate(1)
    return function(s,k) return G.call(fn,s,k) end,state,control
  end
  function G.get(t,k)
    G.spend(1); key(k)
    -- In particular this never delegates to the host string metatable.
    if type(t)~='table' then fail('indexing requires a table; string methods are forbidden') end
    if protected[t] then return protected[t][k] end
    return plain(t)[k]
  end
  local function inventory(t)
    local count=0
    for _ in pairs(t) do G.spend(1); count=count+1; if count>limits.table_entries then errors.raise('E_LIMIT','table entry limit exceeded') end end
    return count
  end
  function G.move(n,...)
    integer(n,0,limits.tuple_entries); G.spend(n)
    return G.values(...)
  end
  function G.assignment_targets(n)
    integer(n,0,limits.tuple_entries); G.spend(n*3+1); allocate(n*3+1)
    return {} -- Private generated-code vector; never guest-owned or exported.
  end
  function G.assignment_values(n,...)
    local actual=select('#',...)
    if actual>limits.tuple_entries then fatal('assignment tuple width exceeded') end
    G.spend(n+actual+1); allocate(math.max(n,actual)+1)
    local values=table.pack(...)
    for i=1,actual do G.scalar(values[i]) end
    return values
  end
  local function changed_keys(t,updates)
    local old=owned[t].keys
    G.host_work(#old+#updates+1,#old+#updates+1)
    local present,keys={},{}
    for _,k in ipairs(old) do present[k]=true end
    for _,update in ipairs(updates) do present[update[1]]=update[2] end
    for _,k in ipairs(old) do if present[k] then keys[#keys+1]=k; present[k]=false end end
    for _,update in ipairs(updates) do
      local k=update[1]
      if present[k] then keys[#keys+1]=k; present[k]=false end
    end
    return keys
  end
  function G.assignment_check(n,targets,values)
    G.spend(n*3+1); allocate(n)
    local staged={}
    -- Native Lua 5.2 publishes multiple assignments right-to-left. Match that
    -- order for duplicate/aliased targets or preflight can undercount growth.
    for i=n,1,-1 do
      local pair=targets[i]
      if pair then
        local t,k,v=pair[1],pair[2],values[i]
        plain(t); key(k)
        if not staged[t] then staged[t]={count=inventory(t),keys={},updates={},values=heap and {}} end
        local state=staged[t]
        local present=state.keys[k]
        if present==nil then present=t[k]~=nil end
        if (v~=nil)~=present then state.count=state.count+(v~=nil and 1 or -1) end
        state.keys[k]=v~=nil
        if heap then state.values[k]=v end
        if durable then state.updates[#state.updates+1]={k,v~=nil} end
        if state.count>limits.table_entries then errors.raise('E_LIMIT','table growth exceeded') end
      end
    end
    if durable then
      for t,state in pairs(staged) do state.next_keys=changed_keys(t,state.updates) end
      if heap then
        local items={}
        for t,state in pairs(staged) do table_charges(items,t,state.next_keys,state.keys,state.values) end
        memory.acquire_all(heap,items)
      end
      for t,state in pairs(staged) do owned[t].keys=state.next_keys end
    end
    -- Publication is statically emitted native writes after complete preflight.
  end
  function G.new(count, factory)
    integer(count,0,limits.table_entries); G.spend(count+1); allocate(count+1)
    if depth>=limits.callback_depth then fatal('callback call depth exhausted') end
    depth=depth+1
    local ok,t=pcall(factory)
    depth=depth-1
    G.check()
    if not ok then error(t,0) end
    own(t)
    inventory(t)
    for k,v in pairs(t) do key(k); G.scalar(v) end
    return t
  end
  function G.reindex(t) plain(t); own(t) end
  function G.length(v)
    G.spend(1)
    if type(v)=='string' then string_value(v); return #v end
    plain(v); inventory(v); return #v
  end
  function G.concat(...)
    local n=select('#',...); integer(n,0,limits.tuple_entries)
    local pieces,bytes={},0
    G.spend(n); allocate(n)
    for i=1,n do
      local v=select(i,...)
      if type(v)=='number' then v=tostring(v) end
      string_value(v); bytes=bytes+#v
      if bytes>limits.string_bytes then errors.raise('E_LIMIT','concatenation size exceeded') end
      pieces[i]=v
    end
    G.spend(bytes*2+1); allocate(bytes)
    return table.concat(pieces)
  end
  local function copy(v,seen,level,stats)
    G.spend(1)
    if level>limits.data_depth then errors.raise('E_LIMIT','Data nesting exceeded') end
    local typ=type(v)
    stats.nodes=stats.nodes+1
    if stats.nodes>limits.data_nodes then errors.raise('E_LIMIT','Data nodes exceeded') end
    if typ=='number' then if not errors.finite(v) then fail('Data number must be finite') end; stats.bytes=stats.bytes+8; return v end
    if typ=='boolean' then stats.bytes=stats.bytes+1; return v end
    if typ=='string' then string_value(v); stats.bytes=stats.bytes+#v; G.spend(#v); allocate(#v); return v end
    if typ~='table' or getmetatable(v)~=nil or protected[v] or G.encoded_type(v) then fail('plain Data required') end
    if seen[v] then fail('cyclic Data is not persistable') end
    seen[v]=true
    allocate(1)
    local t,kind,count,max={}
    count,max=0,0
    for k,x in pairs(v) do
      G.spend(1); count=count+1
      if count>limits.table_entries then errors.raise('E_LIMIT','Data table entries exceeded') end
      local kt=type(k)
      if kt=='number' then integer(k,1,limits.table_entries); max=math.max(max,k)
      elseif kt=='string' then string_value(k); stats.bytes=stats.bytes+#k; G.spend(#k); allocate(#k)
      else fail('Data keys must be strings or dense array indexes') end
      if kind and kind~=kt then fail('Data arrays/maps cannot mix') end
      kind=kt; t[k]=copy(x,seen,level+1,stats)
    end
    if kind=='number' and max~=count then fail('Data array must be dense') end
    seen[v]=nil; own(t)
    return t
  end
  function G.snapshot(v)
    if v==nil then return nil end
    local stats={nodes=0,bytes=0}
    local result=copy(v,{},0,stats)
    if stats.bytes>limits.peripheral_call_bytes then errors.raise('E_LIMIT','Data snapshot byte limit exceeded') end
    if durable and type(result)=='table' then
      local resource=errors.resource_diagnostic(v) or owned[v] and owned[v].resource
      if resource then
        local diagnostic={}; for key,value in pairs(resource) do diagnostic[key]=value end
        diagnostic.line=diagnostic.line or line; diagnostic.column=diagnostic.column or column
        owned[result].resource=diagnostic
      end
    end
    return result
  end
  function G.namespace(entries,label)
    G.spend(1); allocate(1)
    local proxy={}; protected[proxy]=entries
    for _,v in pairs(entries) do if type(v)=='function' then callable[v]=label or 'API function' end end
    return proxy
  end
  -- Host-only; only the closed speaker effect dispatch requests this. Reserve
  -- its scalar snapshot and immediate guarded call's return before dispatch.
  function G.prepare_boolean_result()
    local service=service_frames[#service_frames]
    assert(service,'boolean admission requires a trusted service')
    if service.boolean_result then return end
    G.spend(1)
    local frame=call_frames[#call_frames]
    if frame and frame.fn==service.wrapper then
      G.spend(3); allocate(2); frame.boolean_result=true
    end
    prepare_checkpoint({n=1,false})
    service.boolean_result=true
  end
  function G.prepare_empty_result()
    local service=assert(service_frames[#service_frames],'empty admission requires a trusted service')
    if service.empty_result then return end
    if not prepare_return(service.wrapper) then prepare_checkpoint({n=0}) end
    service.empty_result=true
  end
  function G.prepare_result(...)
    local service=assert(service_frames[#service_frames],'result admission requires a trusted service')
    assert(not service.prepared_result and not service.empty_result and not service.boolean_result,'duplicate result admission')
    local result=table.pack(...)
    if result.n>limits.tuple_entries then fatal('service result width exceeded') end
    for i=1,result.n do
      if not (type(result[i])=='table' and protected[result[i]]) then result[i]=G.snapshot(result[i]) end
    end
    if not prepare_return(service.wrapper,table.unpack(result,1,result.n)) then prepare_checkpoint(result) end
    service.prepared_result=result
    return table.unpack(result,1,result.n)
  end
  function G.service(fn)
    local wrapper
    wrapper=function(...)
      G.spend(1) -- Must precede trusted service's authority/admission/effect boundary.
      local n=select('#',...); integer(n,0,limits.tuple_entries)
      local args=table.pack(...)
      for i=1,n do
        if not (handle_arguments[fn]==i and type(args[i])=='table' and protected[args[i]]) then
          args[i]=G.snapshot(args[i])
        end
      end
      local frame={wrapper=wrapper}
      local called=call_checkpoint and restored_result(call_checkpoint.service_result)
      if not called then
        service_frames[#service_frames+1]=frame
        called=table.pack(pcall(fn,table.unpack(args,1,n)))
        service_frames[#service_frames]=nil
        if called[1] and frame.prepared_result then
          local expected=frame.prepared_result
          if called.n~=expected.n+1 then errors.raise('E_ENGINE','trusted service result width contract violated') end
          for i=1,expected.n do
            if not rawequal(called[i+1],expected[i]) then errors.raise('E_ENGINE','trusted service result contract violated') end
          end
        end
        if called[1] and frame.boolean_result then
          if called.n~=2 or type(called[2])~='boolean' then errors.raise('E_ENGINE','trusted boolean service contract violated') end
          if call_checkpoint and call_checkpoint.prepared then
            -- Both outcomes use the same prepaid scalar slots, never a post-effect allocation.
            call_checkpoint.prepared.called[2]=called[2]; call_checkpoint.prepared.values[1]=called[2]
          end
        end
        if called[1] and frame.empty_result and called.n~=1 then errors.raise('E_ENGINE','trusted empty service contract violated') end
        if called[1] and not (frame.prepared_result or frame.boolean_result or frame.empty_result) then
          for i=2,called.n do
            if not (type(called[i])=='table' and protected[called[i]]) then called[i]=G.snapshot(called[i]) end
          end
        end
        if call_checkpoint and called[1] then
          call_checkpoint.service_result=checkpoint_result(called,(frame.prepared_result or frame.boolean_result or frame.empty_result) and call_checkpoint.prepared)
        end
      end
      if not called[1] then error(called[2],0) end
      local result={n=called.n-1}; for i=2,called.n do result[i-1]=called[i] end
      if result.n>limits.tuple_entries then fatal('service result width exceeded') end
      local prepared=call_checkpoint and call_checkpoint.prepared
      local prepaid=prepared and call_checkpoint.service_result==prepared.called
      if prepaid then
        local frame=call_frames[#call_frames]
        if frame and frame.fn==wrapper then frame.prepared_return=result end
      end
      G.check()
      return table.unpack(result,1,result.n)
    end
    return wrapper
  end

  function G.initialize()
  local service_map = type(services)=='function' and services(G) or services or {}
  assert(type(service_map)=='table', 'trusted services must be a method map')
  local env={}
  env.type=function(v) G.spend(1); return G.encoded_type(v) or type(v) end
  env.tostring=function(v)
    G.spend(1)
    local typ=G.encoded_type(v) or type(v)
    if typ=='table' then return protected[v] and 'API handle' or 'table' end
    if typ=='function' then return callable[v] or 'guest function' end
    if typ~='nil' and typ~='boolean' and typ~='number' and typ~='string' then fail('untrusted value') end
    if typ=='string' then string_value(v); G.spend(#v) end
    return tostring(v)
  end
  env.tonumber=function(v,base)
    G.spend(1)
    if type(v)=='string' then string_value(v); G.spend(#v) end
    if base~=nil then integer(base,2,36); if type(v)~='string' then fail('base conversion requires a string') end; return tonumber(v,base) end
    if type(v)~='string' and type(v)~='number' then return nil end
    return tonumber(v)
  end
  env.assert=function(value,...) G.spend(1); if not value then error(select(1,...) or 'assertion failed!',0) end; return value,... end
  env.error=function(value) G.spend(1); error(value,0) end
  env.pcall=function(fn,...)
    G.spend(1)
    local result=table.pack(pcall(G.call,fn,...))
    G.check()
    if not result[1] and type(result[2])=='table' and not owned[result[2]] then result[2]=G.snapshot(result[2]) end
    G.spend(result.n)
    if result.n>limits.tuple_entries then fatal('protected return width exceeded') end
    return table.unpack(result,1,result.n)
  end
  env.xpcall=function(fn,handler,...)
    G.spend(1)
    if not callable[fn] or not callable[handler] then fail('approved function and message handler required') end
    local n=select('#',...); G.spend(n+1); allocate(n+2)
    local args=table.pack(...)
    local caller_depth=depth
    local result=table.pack(xpcall(function() return G.call(fn,table.unpack(args,1,args.n)) end,function(problem)
      -- Native message handling may re-enter after an ordinary handler error.
      -- Keep each bridge frame charged until native protection has returned;
      -- G.call unwinds its own depth before propagating that error.
      if poison then return nil end
      G.spend(1)
      if depth>=limits.callback_depth then fatal('callback call depth exhausted') end
      depth=depth+1
      if type(problem)=='table' and not owned[problem] and not protected[problem] then problem=G.snapshot(problem) end
      G.scalar(problem) -- Reject foreign objects/oversized scalars before guest message code.
      return (G.call(handler,problem))
    end))
    depth=caller_depth
    G.check()
    if result.n>limits.tuple_entries then fatal('protected return width exceeded') end
    G.spend(result.n); allocate(result.n)
    for i=1,result.n do G.scalar(result[i]) end
    return table.unpack(result,1,result.n)
  end
  local function required(n,...)
    if select('#',...)<n then fail('missing required argument') end
  end
  env.rawget=function(...)
    required(2,...)
    local t,k=...
    plain(t); G.spend(1)
    if k==nil or type(k)=='number' and k~=k then return nil end
    key(k)
    return rawget(t,k)
  end
  env.rawset=function(...)
    required(3,...)
    local t,k,v=...
    plain(t); G.scalar(v)
    if v~=nil then retained(k); retained(v) end
    local targets=G.assignment_targets(1); targets[1]={t,k}
    local values=G.assignment_values(1,v)
    prepare_return(env.rawset,t)
    G.assignment_check(1,targets,values)
    rawset(t,k,v)
    return t
  end
  env.rawlen=function(...)
    required(1,...)
    return G.length((...))
  end
  env.rawequal=function(...)
    required(2,...)
    local a,b=...
    G.scalar(a); G.scalar(b)
    return rawequal(a,b)
  end
  env._VERSION='Lua 5.2'
  env.select=function(index,...)
    local n=select('#',...); G.spend(n+1); integer(n,0,limits.tuple_entries)
    if index=='#' then return n end
    integer(index,-limits.tuple_entries,limits.tuple_entries)
    if index==0 then fail('select index must be nonzero') end
    return select(index,...)
  end
  env.next=function(t,k)
    plain(t); G.spend(1); if k~=nil then key(k) end
    local next_key,value=next(t,k)
    if next_key==nil then return nil end
    return next_key,value
  end
  env.pairs=function(t) plain(t); G.spend(1); return env.next,t,nil end
  local function ipairs_next(t,i)
    plain(t); integer(i,0,limits.table_entries); G.spend(1)
    i=i+1; if t[i]~=nil then return i,t[i] end
    return nil -- Lua 5.2 iterator termination has one nil result, not zero.
  end
  callable[ipairs_next]='iterator'
  symbol_values['@ipairs-next']=ipairs_next; symbol_names[ipairs_next]='@ipairs-next'
  env.ipairs=function(t) plain(t); G.spend(1); return ipairs_next,t,0 end

  local mathlib={pi=math.pi}
  for _,name in ipairs({'abs','ceil','floor','min','max','sqrt','fmod','modf','sin','cos','tan','asin','acos','atan','atan2','deg','rad','exp','log'}) do
    local native=math[name]
    mathlib[name]=function(...)
      local n=select('#',...); G.spend(n+1); integer(n,1,limits.tuple_entries)
      local args=table.pack(...)
      for i=1,n do args[i]=G.number(args[i]); if not errors.finite(args[i]) then fail('finite math operands required') end end
      local result=table.pack(native(table.unpack(args,1,n)))
      for i=1,result.n do if not errors.finite(result[i]) then errors.raise('E_RANGE','nonfinite math result') end end
      return table.unpack(result,1,result.n)
    end
  end
  local str={}
  str.len=function(s) G.spend(1); return #string_value(s) end
  local function slice(s,i,j)
    string_value(s); local len=#s
    i=i==nil and 1 or G.number(i); j=j==nil and len or G.number(j)
    if not errors.finite(i) or not errors.finite(j) then fail('finite string indexes required') end
    i=i<0 and math.max(len+math.ceil(i)+1,1) or math.min(math.max(math.floor(i),1),len+1)
    j=j<0 and math.max(len+math.ceil(j)+1,0) or math.min(math.floor(j),len)
    return i,j,math.max(0,j-i+1)
  end
  str.sub=function(s,i,j) local a,b,n=slice(s,i,j); G.spend(n+1); allocate(n); return string.sub(s,a,b) end
  str.byte=function(s,i,j)
    if j==nil then j=i or 1 end
    local a,b,n=slice(s,i,j); integer(n,0,limits.tuple_entries); G.spend(n+1); allocate(n); return string.byte(s,a,b)
  end
  str.char=function(...)
    local n=select('#',...); integer(n,0,limits.tuple_entries); G.spend(n+1); allocate(n)
    local args=table.pack(...); for i=1,n do integer(args[i],0,255) end
    return string.char(table.unpack(args,1,n))
  end
  for _,name in ipairs({'lower','upper','reverse'}) do
    str[name]=function(s) string_value(s); G.spend(#s*2+1); allocate(#s); return string[name](s) end
  end
  str.rep=function(s,n,sep)
    string_value(s); integer(n,-9007199254740991,9007199254740991)
    if sep==nil then sep='' end; string_value(sep)
    local bytes=n>0 and #s*n+#sep*(n-1) or 0
    if bytes>limits.string_bytes then errors.raise('E_LIMIT','repeated output too large') end
    G.spend(#s+#sep+bytes+1); allocate(bytes)
    if bytes==0 then return '' end
    return string.rep(s,n,sep)
  end
  str.find=function(s,needle,init,plain_find)
    string_value(s); string_value(needle)
    if plain_find~=true then fail('find requires explicit plain=true') end
    init=init==nil and 1 or G.number(init)
    if not errors.finite(init) then fail('finite find index required') end
    init=init<0 and math.max(#s+math.ceil(init)+1,1) or math.max(math.floor(init),1)
    local work=math.max(0,#s-init+1)*(#needle+1)
    G.spend(work+1)
    if init>#s+1 then return nil end
    local first,last=string.find(s,needle,init,true)
    if first==nil then return nil end
    return first,last
  end
  str.format=function(format,...)
    string_value(format); local argc=select('#',...); integer(argc,0,limits.tuple_entries)
    G.spend(#format*2+argc+1)
    local args=table.pack(...); local output,index,arg=0,1,0
    while index<=#format do
      local c=format:sub(index,index)
      if c~='%' then output=output+1; index=index+1
      elseif format:sub(index+1,index+1)=='%' then output=output+1; index=index+2
      else
        local flags,width,precision,spec,stop=format:match('^([-+ #0]*)(%d*)(%.?%d*)([cdiouxXeEfgGqs])()',index+1)
        if not spec or #flags>5 or #width>5 or #precision>6 then fail('invalid or oversized format') end
        local w=width=='' and 0 or tonumber(width)
        local p=precision=='' and 0 or tonumber(precision:sub(2))
        if not p then fail('invalid precision') end
        integer(w,0,limits.string_bytes); integer(p,0,limits.string_bytes)
        arg=arg+1; if arg>argc then fail('missing format operand') end
        local v=args[arg]; local bound
        if spec=='s' then v=env.tostring(v); args[arg]=v; bound=math.max(#v,w)
        elseif spec=='q' then string_value(v); bound=#v*4+2
        else v=G.number(v); if not errors.finite(v) then fail('finite format operand required') end; args[arg]=v; bound=math.max(w,512+p) end
        output=output+bound; index=stop
      end
      if output>limits.string_bytes then errors.raise('E_LIMIT','formatted output too large') end
    end
    G.spend(output+1); allocate(output)
    local result=string.format(format,table.unpack(args,1,argc))
    if #result>limits.string_bytes then fatal('format estimate exceeded') end
    return result
  end
  local tab={}
  local function dense(t)
    plain(t); local n=inventory(t)
    for i=1,n do G.spend(1); if t[i]==nil then fail('dense sequence required') end end
    return n
  end
  tab.pack=function(...) local n=select('#',...); integer(n,0,limits.tuple_entries); G.spend(n+1); allocate(n+1); return own(table.pack(...)) end
  tab.unpack=function(t,i,j)
    plain(t); inventory(t)
    if i==nil then i=1 end; if j==nil then j=#t end
    integer(i,1,limits.table_entries+1); integer(j,0,limits.table_entries)
    local n=math.max(0,j-i+1); integer(n,0,limits.tuple_entries); G.spend(n+1); allocate(n)
    return table.unpack(t,i,j)
  end
  tab.concat=function(t,sep,i,j)
    local n=dense(t); if sep==nil then sep='' end; string_value(sep)
    if i==nil then i=1 end; if j==nil then j=n end; integer(i,1,n+1); integer(j,0,n)
    local bytes=math.max(0,j-i)*#sep
    for k=i,j do G.spend(1); local v=t[k]; if type(v)=='number' then v=tostring(v) end; string_value(v); bytes=bytes+#v end
    if bytes>limits.string_bytes then errors.raise('E_LIMIT','concat output too large') end
    G.spend(bytes+1); allocate(bytes)
    return table.concat(t,sep,i,j)
  end
  tab.insert=function(t,...)
    local n=dense(t); local argc=select('#',...); local pos,value
    if argc==1 then pos,value=n+1,... elseif argc==2 then pos,value=... else fail('insert arity') end
    integer(pos,1,n+1); G.scalar(value)
    retained(value)
    if n>=limits.table_entries then errors.raise('E_LIMIT','table full') end
    G.spend(n-pos+3); allocate(1)
    local keys=durable and changed_keys(t,{{n+1,pos<=n or value~=nil},{pos,value~=nil}})
    prepare_return(tab.insert)
    if heap then
      local items={}; table_charges(items,t,keys); string_charge(items,value)
      memory.acquire_all(heap,items)
    end
    table.insert(t,pos,value)
    if keys then owned[t].keys=keys end
  end
  tab.remove=function(t,pos)
    local n=dense(t); if pos==nil then pos=n end; integer(pos,0,n+1)
    if pos==0 and n~=0 then fail('remove position out of bounds') end
    G.spend(math.max(0,n-pos)*2+3)
    -- Factorio's host helper need not have stock Lua 5.2 return arity. Publish
    -- the bounded sequence shift directly and always return one value, nil
    -- included, as Lua 5.2.4 ltablib.c does for empty/past-end removal.
    local keys=durable and changed_keys(t,{{math.max(pos,n),false}})
    local removed=t[pos]
    prepare_return(tab.remove,removed)
    if heap then
      local items={}; table_charges(items,t,keys)
      memory.acquire_all(heap,items)
    end
    for i=pos,n-1 do t[i]=t[i+1] end
    t[math.max(pos,n)]=nil
    if keys then owned[t].keys=keys end
    return removed
  end
  tab.sort=function(t,less)
    local n=dense(t)
    if less~=nil and type(less)~='function' then fail('sort comparator must be callable') end
    G.spend(n*n+n*2+1); allocate(n)
    local staged={}; for i=1,n do staged[i]=t[i] end
    table.sort(staged,function(a,b)
      if less then return G.call(less,a,b) end
      G.scalar(a); G.scalar(b); return a<b
    end)
    G.check()
    -- Comparators are guest callbacks and may have changed the original table.
    -- Recheck the complete publication before restoring any sorted slots.
    local count=inventory(t)
    G.spend(n)
    for i=1,n do if t[i]==nil then count=count+1 end end
    if count>limits.table_entries then errors.raise('E_LIMIT','sort publication exceeds table capacity') end
    local keys
    if durable then
      local updates={}; for i=1,n do updates[i]={i,true} end
      keys=changed_keys(t,updates)
    end
    prepare_return(tab.sort)
    if heap then
      local items={}; table_charges(items,t,keys)
      memory.acquire_all(heap,items)
    end
    for i=1,n do t[i]=staged[i] end
    if keys then owned[t].keys=keys end
  end
  env.math=G.namespace(mathlib,'math function')
  env.string=G.namespace(str,'string function')
  env.table=G.namespace(tab,'table function')
  env.unpack=tab.unpack
  local colors={}
  local color_names={'white','orange','magenta','lightBlue','yellow','lime','pink','gray','lightGray','cyan','purple','blue','brown','green','red','black'}
  for i,name in ipairs(color_names) do colors[name]=2^(i-1) end
  colors.grey=colors.gray; colors.lightGrey=colors.lightGray
  env.colors=G.namespace(colors,'colors'); env.colours=env.colors
  for _,name in ipairs({'computer','peripheral'}) do
    local entries={}
    local method_count=0
    for method,fn in pairs(service_map[name] or {}) do
      method_count=method_count+1
      assert(method_count<=limits.tuple_entries and type(method)=='string' and type(fn)=='function', 'invalid trusted service registration')
      entries[method]=G.service(fn)
    end
    if name=='computer' and not shell then entries.stop=function(...)
      if select('#',...)~=0 then fail('stop expects no arguments') end
      fatal('stopped')
    end end
    env[name]=G.namespace(entries,name)
  end
  env.print=function(...)
    local n=select('#',...); local parts={}; local bytes=math.max(0,n-1)
    G.spend(n+1); allocate(n)
    for i=1,n do
      parts[i]=env.tostring(select(i,...)); bytes=bytes+#parts[i]
      if bytes>limits.console_bytes then errors.raise('E_LIMIT','print output too large') end
    end
    if bytes>limits.console_bytes then errors.raise('E_LIMIT','print output too large') end
    G.spend(bytes+1); allocate(bytes)
    local text=table.concat(parts,'\t')
    prepare_return(env.print)
    if shell then shell.output(text) else G.get(env.computer,'log')(text) end
  end
  if shell then
    function G.shell_root() return shell.root end
    function G.format_results(result)
      if result.n>0 then env.print(table.unpack(result,1,result.n)) end
    end
  end
  for name,v in pairs(env) do if type(v)=='function' then callable[v]=name end end
  callable[tab.unpack]='table function' -- One identity/description for both aliases.
  for name,value in pairs(env) do
    if type(value)=='table' or type(value)=='function' then
      symbol_values[name]=value; symbol_names[value]=symbol_names[value] or name
      if protected[value] then
        for member,entry in pairs(protected[value]) do
          if type(entry)=='function' then
            local path=name..'.'..member
            symbol_values[path]=entry; symbol_names[entry]=symbol_names[entry] or path
          end
        end
      end
    end
  end
  function G.reserved_global(name) return env[name]~=nil end
  function G.global(name)
    G.spend(1)
    if env[name]~=nil then return env[name] end
    if shell then return G.get(shell.root,name) end
  end
  end
  return G
end
return M
