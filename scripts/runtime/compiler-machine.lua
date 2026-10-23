-- Unvalidated prototype internals; production callers must use the quarantined compiler facade.
-- Host compiler frames only. Guest execution remains continuation ABI 9.
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local M={version=1,build=require('scripts.runtime.compiler-generated.identity')}
local modules={}
for _,name in ipairs({'util','stack','indexed_linked_list','nodes','ast_util','error_code_util','tokenize','parser'}) do
  modules['vendor.phobos.'..name]=require('scripts.runtime.compiler-generated.'..name)
end
for _,name in ipairs({'compiler-pipeline','compiler-primitives'}) do
  modules['scripts.runtime.'..name]=require('scripts.runtime.compiler-generated.'..name)
end
modules['compiler.validation']=require('scripts.runtime.compiler-generated.validation')
modules['compiler.lower']=require('scripts.runtime.compiler-generated.lower')
local function symbol(name) return {native=name} end
local function pack(...) return {n=select('#',...),...} end
local function join(a,b)
  for i=1,b.n do a[a.n+i]=b[i] end
  a.n=a.n+b.n; return a
end
local libraries={}
for _,name in ipairs({'math','string','table'}) do
  local library=({math=math,string=string,table=table})[name]
  local out={}
  for key,value in pairs(library) do out[key]=type(value)=='function' and symbol(name..'.'..key) or value end
  libraries[name]=out
end
local natives={assert=assert,error=error,type=type,tostring=tostring,tonumber=tonumber,next=next,
  select=select,rawget=rawget,rawset=rawset,rawequal=rawequal,getmetatable=getmetatable}
for name,library in pairs({math=math,string=string,table=table}) do
  for key,value in pairs(library) do if type(value)=='function' then natives[name..'.'..key]=value end end
end
natives['raw.concat']=function(a,b) return a..b end
natives['raw.tostring']=tostring
natives['errors.new']=errors.new; natives['errors.finite']=errors.finite
natives['errors.raise']=errors.raise
natives['ipairs.next']=function(t,i) i=i+1; if t[i]~=nil then return i,t[i] end end
local function frame(module,id,captures,args,out,nextpc)
  local proto=assert(modules[module].protos[id],'unknown compiler function')
  local locals={}
  for i,cell in pairs(captures or {}) do locals[i]=cell end
  for i,key in ipairs(proto.params) do locals[key]={v=args[i]} end
  local varargs={n=math.max(0,args.n-#proto.params)}
  for i=1,varargs.n do varargs[i]=args[#proto.params+i] end
  return {module=module,pc=proto.entry,l=locals,s={},t={},args=varargs,out=out,nextpc=nextpc}
end
function M.new(source,mode)
  assert(type(source)=='string' and (mode==nil or mode=='shell'),'invalid compiler source/mode')
  return {version=M.version,build=M.build,source=source,mode=mode,modules={},stack={frame('scripts.runtime.compiler-pipeline',1,nil,{n=0})},phase='bootstrap',steps=0,work=0}
end
local wait={}
function M.advance(job,context,admit)
  if type(job)~='table' or job.version~=M.version or job.build~=M.build or getmetatable(job) then return nil,errors.new('E_UNSUPPORTED','invalid compiler cursor/build; source retained') end
  if job.error then return nil,job.error end
  if job.wait_tick~=nil and context and job.wait_tick==context.tick then return nil,nil,'wait' end
  if job.result then return job.result end
  local r={join=join}
  local function spend(cost)
    if context and not admission.reserve(context,'compile',cost) then
      if cost>limits.compile_work or cost>admission.guest_ceiling(context.ledger,context.tick) then
        errors.raise('E_CAPACITY','compiler native atom exceeds configured compile/host work slice')
      end
      error(wait,0)
    end
    job.work=job.work+cost
  end
  local function growth(bytes)
    if admit then admit(job,bytes) end
  end
  function r.global(name)
    if libraries[name] then return libraries[name] end
    return symbol(name)
  end
  function r.get(object,key)
    if type(object)=='string' then return assert(libraries.string[key],'unknown compiler string method') end
    return object[key]
  end
  function r.closure(f,id)
    local captures={}
    for _,key in ipairs(modules[f.module].protos[id].captures) do captures[key]=assert(f.l[key],'missing compiler capture') end
    return {module=f.module,id=id,captures=captures}
  end
  function r.append(t,start,tuple) for i=1,tuple.n do t[start+i-1]=tuple[i] end end
  function r.finish(values)
    local f=job.stack[#job.stack]; job.stack[#job.stack]=nil
    if f.loading then job.modules[f.loading]=values[1] end
    if #job.stack==0 then
      if job.phase=='bootstrap' then
        job.phase='compile'
        local callable=values[1]
        job.stack[1]=frame(callable.module,callable.id,callable.captures,{n=2,job.source,job.mode})
      else job.result=values[1] end
      return
    end
    if f.protected then values=join({n=1,true},values) end
    local parent=job.stack[#job.stack]
    parent.t[f.out]=values; parent.s[f.out]=values[1]; parent.pc=f.nextpc
  end
  local function push(callable,args,out,pc,protected)
    growth(256+48*args.n)
    local f=frame(callable.module,callable.id,callable.captures,args,out,pc)
    f.protected=protected
    job.stack[#job.stack+1]=f
  end
  local function deliver(f,out,pc,values) f.t[out]=values; f.s[out]=values[1]; f.pc=pc end
  function r.call(f,callee,args,out,pc)
    assert(type(callee)=='table','invalid trusted compiler callable: '..tostring(callee))
    if callee.module then push(callee,args,out,pc); return end
    local name=assert(callee.native,'unknown trusted compiler callable')
    if name=='require' then
      local module=args[1]
      if module=='scripts.runtime.parse_admission' then
        deliver(f,out,pc,{n=1,{enter=symbol('admission.enter'),push=symbol('admission.push'),pop=symbol('admission.pop')}})
      elseif module=='scripts.runtime.limits' then deliver(f,out,pc,{n=1,limits})
      elseif module=='scripts.runtime.errors' then deliver(f,out,pc,{n=1,{new=symbol('errors.new'),raise=symbol('errors.raise'),finite=symbol('errors.finite')}})
      elseif module=='compiler.native' then deliver(f,out,pc,{n=1,{concat=symbol('raw.concat'),tostring=symbol('raw.tostring')}})
      elseif job.modules[module] then deliver(f,out,pc,{n=1,job.modules[module]})
      else
        assert(modules[module],'unapproved compiler module '..tostring(module))
        push({module=module,id=1}, {n=0},out,pc)
        job.stack[#job.stack].loading=module
      end
    elseif name=='admission.enter' then
      f.debt=f.debt or args[1] or 1
      local amount=f.debt
      if context then amount=math.min(amount,limits.compile_work-context.machine.compile,admission.guest_ceiling(context.ledger,context.tick)-context.ledger.total) end
      if amount>0 then spend(amount); f.debt=f.debt-amount end
      if f.debt>0 then error(wait,0) end
      f.debt=nil; deliver(f,out,pc,{n=0})
    elseif name=='admission.push' then
      job.depth=(job.depth or 0)+1
      deliver(f,out,pc,{n=0})
    elseif name=='admission.pop' then job.depth=job.depth-1; deliver(f,out,pc,{n=0})
    elseif name=='string.gmatch' then deliver(f,out,pc,{n=1,{native='gmatch.next',text=args[1],pattern=args[2],index=1}})
    elseif name=='gmatch.next' then
      local values=pack(string.find(callee.text,callee.pattern,callee.index))
      if not values[1] then deliver(f,out,pc,{n=0})
      else
        callee.index=math.max(values[1]+1,values[2]+1)
        if values.n==2 then deliver(f,out,pc,{n=1,string.sub(callee.text,values[1],values[2])})
        else local captures={n=values.n-2}; for i=3,values.n do captures[i-2]=values[i] end; deliver(f,out,pc,captures) end
      end
    elseif name=='pairs' then deliver(f,out,pc,{n=3,symbol('next'),args[1],nil})
    elseif name=='ipairs' then deliver(f,out,pc,{n=3,symbol('ipairs.next'),args[1],0})
    elseif name=='pcall' then
      local callable=args[1]; local rest={n=args.n-1}; for i=2,args.n do rest[i-1]=args[i] end
      if callable.module then push(callable,rest,out,pc,true)
      else
        local fn=assert(natives[callable.native],'unsupported compiler protected native')
        deliver(f,out,pc,pack(pcall(fn,table.unpack(rest,1,rest.n))))
      end
    elseif name=='table.concat' or name=='table.sort' or name=='table.insert' or name=='table.remove' or name=='concat' then
      local primitives=job.modules['scripts.runtime.compiler-primitives']
      if not primitives then
        push({module='scripts.runtime.compiler-primitives',id=1},{n=0},out,f.pc)
        job.stack[#job.stack].loading='scripts.runtime.compiler-primitives'
      else
        local key=name:match('%.(.+)') or 'concat'
        if name=='concat' then args={n=1,args} end
        push(primitives[key],args,out,pc)
      end
    else
      local cost=1
      if name=='raw.concat' then cost=#args[1]+#args[2]+1
      elseif name=='string.sub' then cost=math.min(#args[1],math.max(0,(args[3] or #args[1])-(args[2] or 1)+1))+1
      elseif name=='string.format' then for i=1,args.n do if type(args[i])=='string' then cost=cost+#args[i] end end
      elseif name=='table.unpack' then cost=(args[3] or #args[1])-(args[2] or 1)+2 end
      spend(cost); growth(cost)
      local fn=assert(natives[name],'unsupported compiler primitive '..name)
      deliver(f,out,pc,pack(fn(table.unpack(args,1,args.n))))
    end
  end
  while not job.result do
    local f=job.stack[#job.stack]
    local block=modules[f.module] and modules[f.module].blocks[f.pc]
    if type(block)~='function' then return nil,errors.new('E_UNSUPPORTED','invalid compiler program counter') end
    local ok,problem=pcall(function()
      if not f.paid then spend(1); f.paid=true end
      growth(128); block(f,r)
    end)
    if not ok then
      if problem==wait then job.wait_tick=context and context.tick; return nil,nil,'wait' end
      local protected
      for i=#job.stack,1,-1 do if job.stack[i].protected then protected=i; break end end
      if protected then
        local failed=job.stack[protected]
        for i=#job.stack,protected,-1 do job.stack[i]=nil end
        deliver(job.stack[#job.stack],failed.out,failed.nextpc,{n=2,false,problem})
      else
        job.error=type(problem)=='table' and problem or errors.new('E_PROGRAM',tostring(problem))
        return nil,job.error
      end
    else f.paid=nil; job.steps=job.steps+1 end
  end
  return job.result
end
return M
