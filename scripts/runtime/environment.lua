local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local admission=require('scripts.runtime.admission')
local M={}
local string_meta=getmetatable('')
local host_index=string_meta.__index
local native_ipairs=ipairs({})
local math_names={'abs','ceil','floor','min','max','sqrt','fmod','modf','sin','cos','tan','asin','acos','atan','atan2','deg','rad','exp','log'}
local colors={}
for i,name in ipairs({'white','orange','magenta','lightBlue','yellow','lime','pink','gray','lightGray','cyan','purple','blue','brown','green','red','black'}) do colors[name]=2^(i-1) end
colors.grey=colors.gray; colors.lightGrey=colors.lightGray

-- All exits restore the caller's string scope, including nested host entry.
-- Varargs pass results through without packing them into a table.
local function leave(previous,ok,...)
  string_meta.__index=previous
  if not ok then error((...),0) end
  return ...
end
local function scoped(index,handler,fn,...)
  local previous=string_meta.__index
  string_meta.__index=index
  return leave(previous,xpcall(fn,handler,...))
end


-- new(nil,services) builds reusable host scaffolding; bind(context) starts one
-- invocation with fresh per-callback state. new(context,...) binds immediately.
function M.new(context,services,shell)
  local reserve_work
  local E={shell_enabled=shell~=nil}
  -- Weak: per-callback facades must not accumulate in reused scaffolding.
  local protected,labels=setmetatable({},{__mode='k'}),setmetatable({},{__mode='k'})
  local bindings,host_errors={},{}
  local handle_arguments,stable_services,input_rules={},{},{}
  -- Weak: borrowing facade services are per-callback closures.
  local borrowed=setmetatable({},{__mode='k'})
  local service_frames,frame_pool={},{}
  local restore_binding,output,output_flush,guest_index
  local exports,constructing
  local poison,closed,line=nil,false,1
  local sentinel={}
  local binders,building,construction={},false,0
  local function capture(problem)
    local level=2
    while true do
      local info=debug.getinfo(level,'Sl')
      if not info then break end
      if info.source=='@computer' and info.currentline>0 then
        line=math.max(1,info.currentline)
        break
      end
      level=level+1
    end
    return problem
  end
  local function fail(message,code)
    local problem=errors.new(code or 'E_ARGUMENT',message)
    host_errors[problem]=true
    error(problem,0)
  end
  local function host_failure(problem)
    local kind=type(problem)
    if problem~=sentinel and (kind=='table' or kind=='function' or kind=='userdata' or kind=='thread') then host_errors[problem]=true end
    return problem
  end
  local function fatal(reason)
    poison=reason or 'host work exhausted'
    capture(sentinel)
    error(sentinel,0)
  end
  function E.check()
    if poison then error(sentinel,0) end
    if closed then fail('execution retired','E_UNREACHABLE') end
  end
  function E.close()
    if E.invalidate_authority then E.invalidate_authority() end
    closed=true
  end
  function E.stop_requested() return poison=='stopped' end
  function E.spend(n)
    if poison or closed then E.check() end -- raises; inlined for the per-charge hot path
    if not reserve_work(n or 1) then fatal() end
  end
  function E.replay_work(charges)
    E.check()
    if not admission.replay_work(context,charges) then fatal() end
  end
  function E.execute(fn,...)
    E.check()
    local result=table.pack(scoped(guest_index,capture,fn,...))
    E.check()
    return table.unpack(result,1,result.n)
  end
  function E.construct(factory,names)
    assert(not shell and not exports,'declarations already constructed')
    exports,constructing={},names
    local ok,problem=pcall(E.execute,factory)
    constructing=nil
    if not ok then error(problem,0) end
    for name in pairs(names) do assert(type(exports[name])=='function','missing validated export') end
    return exports
  end
  function E.diagnostic(problem)
    if poison then return {code=poison=='stopped' and 'E_STOP' or 'E_BUDGET',message=poison,line=line,column=1} end
    if type(problem)=='table' and getmetatable(problem)==nil then
      return {code=type(problem.code)=='string' and string.sub(problem.code,1,64) or 'E_PROGRAM',
        message=type(problem.message)=='string' and string.sub(problem.message,1,1024) or 'program raised an error',line=line,column=1,
        field=type(problem.field)=='string' and string.sub(problem.field,1,128) or nil,
        peripheral=type(problem.peripheral)=='string' and string.sub(problem.peripheral,1,128) or nil,
        device=type(problem.device)=='string' and string.sub(problem.device,1,128) or nil}
    end
    return {code='E_PROGRAM',message=type(problem)=='string' and string.gsub(string.sub(problem,1,1024),'computer:%d+: ','') or 'program raised an error',line=line,column=1}
  end
  function E.is_plain(value) return type(value)=='table' and not protected[value] and getmetatable(value)==nil end
  local function plain(value)
    if not E.is_plain(value) then fail('guest plain table required') end
    return value
  end
  local function string_value(value)
    if type(value)~='string' then fail('string required') end
    if #value>limits.string_bytes then fail('Data string size exceeded','E_LIMIT') end
    return value
  end
  -- measuring: identical checks and charges, no output graph.
  local function copy(value,seen,depth,stats,measuring)
    E.spend(1)
    stats.nodes=stats.nodes+1
    if depth>limits.data_depth or stats.nodes>limits.data_nodes then fail('Data structure limit exceeded','E_LIMIT') end
    local kind=type(value)
    if kind=='number' then
      if not errors.finite(value) then fail('Data number must be finite') end
      stats.bytes=stats.bytes+8; return value
    elseif kind=='boolean' then stats.bytes=stats.bytes+1; return value
    elseif kind=='string' then
      string_value(value); E.spend(#value); stats.bytes=stats.bytes+#value; return value
    end
    plain(value)
    if seen[value] then fail('cyclic Data is not persistable') end
    seen[value]=true
    local result,key_kind,count,maximum=not measuring and {} or nil,nil,0,0
    for key,item in pairs(value) do
      E.spend(1); count=count+1
      if count>limits.table_entries then fail('Data table entries exceeded','E_LIMIT') end
      local kt=type(key)
      if kt=='number' then
        if not errors.integer(key,1,limits.table_entries) then fail('invalid Data index') end
        maximum=math.max(maximum,key)
      elseif kt=='string' then string_value(key); E.spend(#key); stats.bytes=stats.bytes+#key
      else fail('Data keys must be strings or dense array indexes') end
      if key_kind and key_kind~=kt then fail('Data arrays/maps cannot mix') end
      key_kind=kt; local item_copy=copy(item,seen,depth+1,stats,measuring)
      if result then result[key]=item_copy end
    end
    if key_kind=='number' and maximum~=count then fail('Data array must be dense') end
    seen[value]=nil
    return result
  end
  -- copy() of one scalar: one node at depth 0, so only these checks can fail.
  assert(limits.data_nodes>=1 and limits.data_depth>=0)
  local function snapshot_scalar(value)
    if value==nil then return end
    E.spend(1)
    local kind=type(value); local bytes
    if kind=='number' then
      if not errors.finite(value) then fail('Data number must be finite') end
      bytes=8
    elseif kind=='boolean' then bytes=1
    else string_value(value); E.spend(#value); bytes=#value end
    if bytes>limits.peripheral_call_bytes then fail('Data snapshot byte limit exceeded','E_LIMIT') end
  end
  local function snapshot(value,measuring)
    if value==nil then return nil end
    local stats={nodes=0,bytes=0}
    local result=copy(value,{},0,stats,measuring)
    if stats.bytes>limits.peripheral_call_bytes then fail('Data snapshot byte limit exceeded','E_LIMIT') end
    return result
  end
  function E.snapshot(value) return snapshot(value) end
  function E.namespace(entries,label)
    -- Scaffolding namespaces are charged by every bind, warm or cold alike.
    if building then construction=construction+1 else E.spend(1) end
    local proxy=setmetatable({},{__index=entries,__newindex=function() fail('protected API table') end,__metatable=false})
    protected[proxy]=true
    for _,value in pairs(entries) do if type(value)=='function' then labels[value]=label or 'API function' end end
    return proxy
  end
  -- Same charge and protection as namespace, but each entry is built on first
  -- use: make(key) returns the function or nil. pairs/rawget see no entries either way.
  function E.lazy_namespace(make,label)
    local entries=setmetatable({},{__index=function(t,key)
      local value=make(key)
      if value~=nil then labels[value]=label or 'API function'; rawset(t,key,value) end
      return value
    end})
    return E.namespace(entries,label)
  end
  -- A flushing sink buffers program output and admits bytes plus entry with one charge.
  function E.bind_output(fn,flush) assert(not output and type(fn)=='function'); output,output_flush=fn,flush end
  function E.flush_output() if output_flush then output_flush() end end
  function E.bind_value(value,descriptor) bindings[value]=descriptor end
  function E.binding(value) return bindings[value] end
  function E.binding_resolver(fn) assert(not restore_binding); restore_binding=fn end
  function E.restore_binding(descriptor,facade) return assert(restore_binding,'binding provider unavailable')(descriptor,facade) end
  function E.accept_handle(fn,index) assert(type(fn)=='function' and index==1); handle_arguments[fn]=index end
  function E.stable_service(fn) stable_services[fn]=true end
  function E.input_rule(fn,classify) input_rules[fn]=classify end
  -- Only for host functions that read their arguments and never retain or mutate them:
  -- arguments are checked and charged like a snapshot, then passed without copying.
  -- Ignored for services with native input or an input rule.
  function E.borrow_input(fn) borrowed[fn]=true end
  -- A closed provider transfers its detached native result, never a guest marker.
  function E.transfer_result(value)
    local frame=assert(service_frames[#service_frames],'transfer outside service')
    frame.detached=value
    return value
  end
  function E.service(fn,native_input,stable)
    -- Result checks for the scalar path; any other result falls back to a packed copy.
    local function results(frame,ok,...)
      service_frames[#service_frames]=nil
      local detached=frame.detached; frame.detached=nil
      E.check()
      if not ok then error((...),0) end
      local n=select('#',...)
      for i=1,n do
        local value=select(i,...); local kind=type(value)
        if kind=='string' then string_value(value)
        elseif kind=='number' then if not errors.finite(value) then fail('Data number must be finite') end
        elseif kind~='nil' and kind~='boolean' and not protected[value] and value~=detached then
          local result=table.pack(...)
          for j=i,n do
            value=result[j]; kind=type(value)
            if kind=='string' then string_value(value)
            elseif kind=='number' then if not errors.finite(value) then fail('Data number must be finite') end
            elseif kind~='nil' and kind~='boolean' and not protected[value] and value~=detached then result[j]=E.snapshot(value) end
          end
          return table.unpack(result,1,n)
        end
      end
      return ...
    end
    -- One body per service, not a fresh closure per call.
    local function body(...)
        E.spend(1)
        if E.invalidate_authority and not (stable or stable_services[fn]) then E.invalidate_authority() end
        -- Scalar arguments need no copy: charge and check them exactly like a
        -- snapshot, then call without packing.
        local n=select('#',...); local simple=true
        for i=1,n do
          local kind=type((select(i,...)))
          if kind~='nil' and kind~='boolean' and kind~='number' and kind~='string' then simple=false; break end
        end
        local borrowing=not simple and borrowed[fn] and not native_input and not input_rules[fn]
        if simple or borrowing then
          if borrowing then
            -- Same checks and charges, in the same order, as snapshotting each argument.
            for i=1,n do
              local value=select(i,...); local kind=type(value)
              if kind=='nil' or kind=='boolean' or kind=='number' or kind=='string' then snapshot_scalar(value)
              else snapshot(value,true) end
            end
          elseif not (native_input or input_rules[fn] and input_rules[fn](...)) then
            for i=1,n do snapshot_scalar((select(i,...))) end
          end
          local depth=#service_frames+1
          local frame=frame_pool[depth]; if not frame then frame={}; frame_pool[depth]=frame end
          service_frames[depth]=frame
          return results(frame,pcall(fn,...))
        end
        local args=table.pack(...)
        local direct=native_input or input_rules[fn] and input_rules[fn](...)
        for i=1,args.n do
          if direct then
            local kind=type(args[i])
            if kind=='table' then plain(args[i])
            elseif kind~='nil' and kind~='boolean' and kind~='number' and kind~='string' then fail('invalid native request value') end
          elseif not (handle_arguments[fn]==i and protected[args[i]]) then args[i]=E.snapshot(args[i]) end
        end
        local frame={}; service_frames[#service_frames+1]=frame
        local result=table.pack(pcall(fn,table.unpack(args,1,args.n)))
        service_frames[#service_frames]=nil
        E.check()
        if not result[1] then error(result[2],0) end
        for i=2,result.n do
          local value=result[i]; local kind=type(value)
          if kind=='string' then string_value(value)
          elseif kind=='number' then if not errors.finite(value) then fail('Data number must be finite') end
          elseif kind~='nil' and kind~='boolean' and not protected[value] and value~=frame.detached then
            result[i]=E.snapshot(value)
          end
        end
        return table.unpack(result,2,result.n)
    end
    return function(...)
      E.check()
      return scoped(host_index,host_failure,body,...)
    end
  end
  local function safe_error(problem,allow_handle)
    E.check()
    if protected[problem] then
      if not allow_handle then fail('cannot snapshot a protected API handle') end
    elseif host_errors[problem] then problem=E.snapshot(problem)
    elseif type(problem)=='userdata' or type(problem)=='thread' then fail('foreign error value') end
    return problem
  end
  -- Providers register per-callback rebinding (authority proofs, local caches).
  function E.on_bind(fn)
    binders[#binders+1]=fn
    if context then fn() end
  end
  function E.bind(ctx)
    context=ctx; reserve_work=admission.bind(ctx)
    bindings,host_errors,service_frames={},{},{}
    exports,constructing=nil,nil
    poison,closed,line=nil,false,1
    for _,fn in ipairs(binders) do fn() end
    if construction>0 then E.spend(construction) end
  end
  function E.initialize()
    building=true
    local service_map=type(services)=='function' and services(E) or services or {}
    assert(type(service_map)=='table','trusted services must be a method map')
    local env={type=type,tonumber=tonumber,select=select,_VERSION='Lua 5.2'}
    env.tostring=function(value)
      local kind=type(value)
      if kind=='table' then return protected[value] and 'API handle' or 'table' end
      if kind=='function' then return labels[value] or 'guest function' end
      if kind~='nil' and kind~='boolean' and kind~='number' and kind~='string' then fail('foreign value') end
      return tostring(value)
    end
    env.assert=function(value,...) if not value then error(select(1,...) or 'assertion failed!',0) end; return value,... end
    env.error=function(value) error(value,0) end
    env.pcall=function(fn,...)
      E.check()
      if type(fn)~='function' then fail('function required') end
      local result=table.pack(pcall(fn,...))
      E.check()
      if not result[1] then result[2]=safe_error(result[2],false) end
      return table.unpack(result,1,result.n)
    end
    env.xpcall=function(fn,handler,...)
      E.check()
      if type(fn)~='function' or type(handler)~='function' then fail('function and message handler required') end
      local result=table.pack(xpcall(fn,function(problem)
        if poison then return nil end
        return (handler(safe_error(problem,true)))
      end,...))
      E.check()
      return table.unpack(result,1,result.n)
    end
    env.rawget=function(t,...) plain(t); return rawget(t,...) end
    env.rawset=function(t,...) plain(t); return rawset(t,...) end
    env.rawlen=function(...) if type((...))=='table' then plain((...)) end; return rawlen(...) end
    env.rawequal=rawequal
    env.next=function(t,...) plain(t); return next(t,...) end
    env.pairs=function(t) plain(t); return env.next,t,nil end
    local function ipairs_next(t,i) plain(t); return native_ipairs(t,i) end
    labels[ipairs_next]='iterator'
    env.ipairs=function(t) plain(t); return ipairs_next,t,0 end
    local mathlib={pi=math.pi}
    for _,name in ipairs(math_names) do mathlib[name]=math[name] end
    local str={len=string.len,sub=string.sub,byte=string.byte,char=string.char,lower=string.lower,upper=string.upper,reverse=string.reverse,rep=string.rep}
    str.find=function(s,needle,init,literal)
      if literal~=true then fail('find requires explicit plain=true') end
      return string.find(s,needle,init,true)
    end
    str.format=function(format,...)
      if type(format)~='string' then fail('format string required') end
      local args=table.pack(...)
      local index,arg=1,0
      while index<=#format do
        if string.sub(format,index,index)~='%' then index=index+1
        elseif string.sub(format,index+1,index+1)=='%' then index=index+2
        else
          local spec,stop=string.match(format,'^[-+ #0]*%d*%.?%d*([cdiouxXeEfgGqs])()',index+1)
          if not spec then fail('invalid format') end
          arg=arg+1
          if arg>args.n then fail('missing format operand') end
          if spec=='s' then args[arg]=env.tostring(args[arg])
          elseif spec=='q' and type(args[arg])~='string' then fail('quoted format requires a string') end
          index=stop
        end
      end
      return string.format(format,table.unpack(args,1,args.n))
    end
    local tab={pack=table.pack}
    for _,name in ipairs({'unpack','concat','insert','remove','sort'}) do
      local native=table[name]
      tab[name]=function(t,...) plain(t); return native(t,...) end
    end
    env.math=E.namespace(mathlib,'math function')
    env.string=E.namespace(str,'string function')
    env.table=E.namespace(tab,'table function')
    env.unpack=tab.unpack
    guest_index=env.string
    env.colors=E.namespace(colors,'colors'); env.colours=env.colors
    for _,name in ipairs({'computer','peripheral'}) do
      local entries={}
      for method,fn in pairs(service_map[name] or {}) do
        assert(type(method)=='string' and type(fn)=='function','invalid trusted service registration')
        entries[method]=E.service(fn)
      end
      if name=='computer' and output then
        local fallback=entries.log
        entries.log=function(...)
          E.check()
          return scoped(host_index,host_failure,function(...)
            if type((...))~='string' then return fallback(...) end
            local n=select('#',...)
            if not shell and n~=1 then fail('unexpected argument count; use dot calls') end
            if shell then for i=2,n do E.snapshot((select(i,...))) end end
            output(string_value((...)))
          end,...)
        end
      end
      if name=='computer' and not shell then entries.stop=function(...)
        E.check()
        if select('#',...)~=0 then fail('stop expects no arguments') end
        fatal('stopped')
      end end
      env[name]=E.namespace(entries,name)
    end
    env.print=function(...)
      E.check()
      return scoped(host_index,host_failure,function(...)
        local n=select('#',...); local bytes=math.max(0,n-1)
        E.spend(n+1)
        local parts={}
        for i=1,n do
          local value=select(i,...)
          parts[i]=type(value)=='string' and value or env.tostring(value); bytes=bytes+#parts[i]
          if bytes>limits.console_bytes then fail('print output too large','E_LIMIT') end
        end
        if bytes>limits.console_bytes then fail('print output too large','E_LIMIT') end
        if not output_flush then E.spend(bytes+1) end
        local text=table.concat(parts,'\t')
        if output then output(text)
        elseif shell then shell.output(text)
        else env.computer.log(text) end
      end,...)
    end
    function E.format_results(result) if result.n>0 then env.print(table.unpack(result,1,result.n)) end end
    for name,value in pairs(env) do if type(value)=='function' then labels[value]=name end end
    labels[tab.unpack]='table function'
    function E.reserved_global(name) return env[name]~=nil end
    E.globals=setmetatable({},{__index=function(_,name)
      if env[name]~=nil then return env[name] end
      if shell then return shell.root[name] end
      return exports and exports[name]
    end,__newindex=function(_,name,value)
      if constructing and constructing[name] and exports[name]==nil and type(value)=='function' then
        E.spend(#name+1)
        exports[name]=value
        return
      end
      if env[name]~=nil or not shell then fail('protected global') end
      shell.root[name]=value
    end,__metatable=false})
    building=false
    if context and construction>0 then E.spend(construction) end
  end
  if context then E.bind(context) end
  return E
end
return M
