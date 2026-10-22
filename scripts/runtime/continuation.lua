-- Compiler-generated scalar vertical slice; no native stack survives a block.
local admission=require('scripts.runtime.admission')
local errors=require('scripts.runtime.errors')
local sandbox=require('scripts.runtime.sandbox')
local parsing=require('scripts.runtime.parse_admission')
local shell_values=require('scripts.runtime.shell-values')
local M={version=1}
local function quote(s) return string.format('%q',s) end
local checkpoint_fields={version=true,source=true,handler=true,frame=true,symbols=true,intern=true,bindings=true,
  owned=true,wait_tick=true,event_initialized=true,shell_root=true,result=true,result_printed=true,value_graph=true,completed=true}
local function validate(checkpoint,executable,tick,spend)
  local function refuse(message) errors.raise('E_UNSUPPORTED',message..'; continuation retained') end
  if getmetatable(checkpoint)~=nil then refuse('invalid checkpoint metatable') end
  for key in pairs(checkpoint) do spend(1); if not checkpoint_fields[key] then refuse('unknown checkpoint field') end end
  local frame=checkpoint.frame
  if type(frame)~='table' or not errors.integer(frame.pc,0,#executable.blocks)
    or type(frame.locals)~='table' or type(frame.slots)~='table' or type(frame.tuples)~='table'
    or type(checkpoint.symbols)~='table' or type(checkpoint.intern)~='table'
    or type(checkpoint.bindings)~='table' or type(checkpoint.owned)~='table'
    or checkpoint.wait_tick~=nil and not errors.integer(checkpoint.wait_tick,0,tick) then refuse('invalid checkpoint header') end
  for key in pairs(frame.locals) do spend(1); if not errors.integer(key,1,executable.locals) then refuse('invalid local slot') end end
  for key in pairs(frame.slots) do spend(1); if not errors.integer(key,1,executable.slots) then refuse('invalid temporary slot') end end
  if frame.pending and (type(frame.pending)~='table' or frame.pending.block~=frame.pc) then refuse('invalid pending primitive') end
  local seen,stack={},{checkpoint}
  while #stack>0 do
    local value=table.remove(stack); local kind=type(value)
    spend(1+(kind=='string' and #value or 0))
    if kind=='table' then
      if getmetatable(value)~=nil then refuse('non-data checkpoint table') end
      if not seen[value] then
        seen[value]=true
        for k,v in pairs(value) do spend(2); stack[#stack+1]=k; if v~=nil then stack[#stack+1]=v end end
      end
    elseif kind~='nil' and kind~='boolean' and kind~='number' and kind~='string' then refuse('non-data checkpoint value') end
  end
end

-- The ordinary compiler validates the source before passing its AST here.
-- Unsupported slice syntax is explicit, never executed by a native fallback.
function M.lower(main,reject,position,mode)
  local blocks,locals,local_count,slots={},{},0,0
  local expression,statement,body
  local function slot() slots=slots+1; return slots end
  local function register(ref)
    local def=ref.reference_def
    if not def or def.def_type~='local' then reject(ref,'continuation slice requires local values','E_UNSUPPORTED') end
    if not locals[def] then local_count=local_count+1; locals[def]=local_count end
    return 'f.locals['..locals[def]..']'
  end
  local function value(i) return 'f.slots['..i..']' end
  local function block(n,code,nextpc)
    parsing.enter(#code+1)
    local line,column=position(n)
    blocks[#blocks+1]='function(f,r) r.guard.step('..line..','..column..'); '..code..'; return '..nextpc..' end'
    return #blocks
  end
  local function reserve() blocks[#blocks+1]=false; return #blocks end
  local function define(pc,n,code)
    parsing.enter(#code+1)
    local line,column=position(n)
    blocks[pc]='function(f,r) r.guard.step('..line..','..column..'); '..code..' end'
  end
  function expression(n,out,nextpc)
    parsing.enter(1)
    local k=n.node_type
    local target=value(out)
    if k=='number' then return block(n,target..'='..(n.src_value or tostring(n.value)),nextpc)
    elseif k=='string' then return block(n,target..'='..quote(n.value),nextpc)
    elseif k=='boolean' then return block(n,target..'='..tostring(n.value),nextpc)
    elseif k=='nil' then return block(n,target..'=nil',nextpc)
    elseif k=='local_ref' then return block(n,target..'='..register(n),nextpc)
    elseif k=='index' then
      if n.src_ex_did_not_exist then
        return block(n,target..'=r.global('..quote(n.suffix.value)..')',nextpc)
      end
      local a,b=slot(),slot()
      local pc=block(n,target..'=r.get('..value(a)..','..value(b)..')',nextpc)
      pc=expression(n.suffix,b,pc)
      return expression(n.ex,a,pc)
    elseif k=='binop' then
      local a,b=slot(),slot()
      if n.op=='and' or n.op=='or' then
        local right=expression(n.right,out,nextpc)
        local pc=block(n,target..'='..value(a)..'; if '..(n.op=='and' and '' or 'not ')..value(a)..' then return '..right..' end',nextpc)
        return expression(n.left,a,pc)
      end
      local left,right=value(a),value(b)
      if n.op=='+' or n.op=='-' or n.op=='*' or n.op=='/' or n.op=='%' or n.op=='^' then
        left='r.guard.number('..left..')'; right='r.guard.number('..right..')'
      elseif n.op=='==' or n.op=='~=' or n.op=='<' or n.op=='>' or n.op=='<=' or n.op=='>=' then
        left='r.guard.scalar('..left..')'; right='r.guard.scalar('..right..')'
      else reject(n,'unsupported continuation operator','E_UNSUPPORTED') end
      local pc=block(n,target..'=('..left..' '..n.op..' '..right..')',nextpc)
      pc=expression(n.right,b,pc)
      return expression(n.left,a,pc)
    elseif k=='unop' then
      local a=slot(); local operand=value(a)
      if n.op=='not' then operand='not '..operand
      elseif n.op=='-' then operand='-r.guard.number('..operand..')'
      elseif n.op=='#' then operand='r.guard.length('..operand..')'
      else reject(n,'unsupported continuation unary operator','E_UNSUPPORTED') end
      return expression(n.ex,a,block(n,target..'=('..operand..')',nextpc))
    elseif k=='call' then
      local callee,args=slot(),{}
      for i=1,#n.args do args[i]=slot() end
      local values={}; for i,s in ipairs(args) do values[i]=value(s) end
      local pc=block(n,target..'=r.call('..out..','..value(callee)..(#args>0 and ','..table.concat(values,',') or '')..')',nextpc)
      for i=#n.args,1,-1 do pc=expression(n.args[i],args[i],pc) end
      return expression(n.ex,callee,pc)
    end
    reject(n,'continuation slice does not yet lower '..tostring(k),'E_UNSUPPORTED')
  end
  function body(scope,nextpc,breakpc)
    local statements={}; local n=scope.body.first
    while n do statements[#statements+1]=n; n=n.next end
    for i=#statements,1,-1 do nextpc=statement(statements[i],nextpc,breakpc) end
    return nextpc
  end
  function statement(n,nextpc,breakpc)
    parsing.enter(1)
    local k=n.node_type
    if k=='empty' then return nextpc
    elseif k=='call' then return expression(n,slot(),nextpc)
    elseif k=='localstat' or k=='assignment' then
      if #n.lhs~=1 or #n.rhs~=1 then
        reject(n,'continuation slice requires one local assignment','E_UNSUPPORTED')
      end
      local out=slot()
      local lhs=n.lhs[1]
      if lhs.node_type=='local_ref' then
        return expression(n.rhs[1],out,block(n,register(lhs)..'='..value(out),nextpc))
      elseif mode=='shell' and lhs.node_type=='index' and lhs.src_ex_did_not_exist then
        return expression(n.rhs[1],out,block(n,'r.set_global('..quote(lhs.suffix.value)..','..value(out)..')',nextpc))
      end
      reject(lhs,'continuation slice requires local or shell-global assignment','E_UNSUPPORTED')
    elseif k=='dostat' then return body(n,nextpc,breakpc)
    elseif k=='breakstat' then return block(n,'',assert(breakpc))
    elseif k=='retstat' and #n.exp_list==0 then return block(n,'',0)
    elseif k=='retstat' and mode=='shell' and #n.exp_list==1 then
      local out=slot(); local ex=n.exp_list[1]
      local tuple=(ex.node_type=='call' and not ex.force_single_result) and ('f.tuples['..out..']') or 'nil'
      return expression(ex,out,block(n,'r.finish('..value(out)..','..tuple..')',0))
    elseif k=='fornum' then
      local index,limit,step=slot(),slot(),slot()
      local localvar=register(n.var)
      local head=reserve()
      local advance=block(n,value(index)..'='..value(index)..'+'..value(step),head)
      local loop=body(n,advance,nextpc)
      define(head,n,'if ('..value(step)..'>0 and '..value(index)..'<='..value(limit)..') or ('..value(step)..'<=0 and '..value(index)..'>='..value(limit)..') then '..localvar..'='..value(index)..'; return '..loop..' end; return '..nextpc)
      local convert=block(n,'local a,b,c=r.guard.number('..value(index)..'),r.guard.number('..value(limit)..'),r.guard.number('..value(step)..'); '..value(index)..','..value(limit)..','..value(step)..'=a,b,c',head)
      local pc=n.step and expression(n.step,step,convert) or block(n,value(step)..'=1',convert)
      pc=expression(n.stop,limit,pc)
      return expression(n.start,index,pc)
    elseif k=='whilestat' then
      local head=reserve(); local condition=slot()
      local loop=body(n,head,nextpc)
      local test=expression(n.condition,condition,block(n,'if '..value(condition)..' then return '..loop..' end',nextpc))
      define(head,n,'return '..test)
      return head
    elseif k=='repeatstat' then
      local head=reserve(); local condition=slot()
      local test=expression(n.condition,condition,block(n,'if not '..value(condition)..' then return '..head..' end',nextpc))
      define(head,n,'return '..body(n,test,nextpc))
      return head
    elseif k=='ifstat' then
      local pc=n.elseblock and body(n.elseblock,nextpc,breakpc) or nextpc
      for i=#n.ifs,1,-1 do
        local b=n.ifs[i]; local condition=slot()
        local branch=body(b,nextpc,breakpc)
        pc=expression(b.condition,condition,block(b,'if '..value(condition)..' then return '..branch..' end',pc))
      end
      return pc
    end
    reject(n,'continuation slice does not yet lower '..tostring(k),'E_UNSUPPORTED')
  end
  local handlers,entries={},{ }
  local first=main.body.first
  while first and first.node_type=='empty' do first=first.next end
  if mode=='shell' then handlers.command=main
  elseif first and first.node_type=='retstat' then
    local descriptor=first.exp_list[1]
    for _,field in ipairs(descriptor.fields) do
      if field.key.value=='handlers' then
        for _,handler in ipairs(field.value.fields) do handlers[handler.key.value]=handler.value.func_def end
      end
    end
  else
    local n=first
    while n do
      if n.node_type=='funcstat' then handlers[n.name.suffix.value]=n.func_def
      elseif n.node_type~='empty' then reject(n,'continuation slice does not yet lower local helper declarations','E_UNSUPPORTED') end
      n=n.next
    end
  end
  local names={}; for name in pairs(handlers) do names[#names+1]=name end; table.sort(names)
  for _,name in ipairs(names) do
    local fn=handlers[name]
    if mode~='shell' and (fn.is_vararg or fn.params and #fn.params>1) then reject(fn,'continuation slice accepts one event parameter','E_UNSUPPORTED') end
    local parameter=fn.params and fn.params[1] and register(fn.params[1])
    local entry=body(fn,0)
    if parameter then entry=block(fn,parameter..'=f.event',entry) end
    entries[#entries+1]='['..quote(name)..']='..entry
  end
  return 'return {blocks={'..table.concat(blocks,',\n')..'},entries={'..table.concat(entries,',')..'},slots='..slots..',locals='..local_count..'}'
end

function M.run(source,generated,name,event,services,context,checkpoint,shell)
  if checkpoint.version~=nil and (checkpoint.version~=M.version or checkpoint.source~=source or checkpoint.handler~=name) then
    return false,errors.new('E_UNSUPPORTED','continuation identity/ABI mismatch; retained')
  end
  if checkpoint.wait_tick==context.tick then return false,nil,'wait' end
  local factory,problem=load(generated,'@continuation','t',{})
  if not factory then return false,errors.new('E_PROGRAM',problem) end
  local executable=factory()
  if checkpoint.version==nil then
    if not executable.entries[name] then return false,errors.new('E_NOT_FOUND','handler not declared') end
    checkpoint.version=M.version; checkpoint.source=source; checkpoint.handler=name
    checkpoint.frame={pc=executable.entries[name],locals={},slots={},tuples={},event=event}
    checkpoint.symbols={}; checkpoint.intern={}; checkpoint.bindings={}; checkpoint.owned={}
  end
  local f=checkpoint.frame
  local guard=sandbox.new(context,services,shell,checkpoint)
  local r={guard=guard}
  local symbol_cache=checkpoint.intern
  function r.symbol(path)
    local symbol=symbol_cache[path]
    if not symbol then
      symbol={}; checkpoint.symbols[symbol]=path; symbol_cache[path]=symbol
    end
    return symbol
  end
  function r.global(name)
    if shell and not guard.reserved_global(name) then return guard.get(checkpoint.shell_root,name) end
    return r.symbol(name)
  end
  local encoded,decoded={},{}
  function r.encode(v)
    if type(v)~='table' and type(v)~='function' then return v end
    if encoded[v] then return encoded[v] end
    local binding=guard.binding(v)
    if not binding then
      if guard.is_plain(v) then return v end
      errors.raise('E_UNSUPPORTED','continuation cannot retain a foreign value')
    end
    local token,descriptor={},{}
    encoded[v]=token; decoded[token]=v; checkpoint.bindings[token]=descriptor
    for _,key in ipairs({'name','wire','generation','kind','method'}) do descriptor[key]=binding[key] end
    if binding.facade then descriptor.facade=r.encode(binding.facade) end
    return token
  end
  function r.decode(v)
    if type(v)~='table' then return v end
    local path=checkpoint.symbols[v]
    if path then
      local resolved
      for part in path:gmatch('[^.]+') do
        if resolved==nil then resolved=guard.global(part) else resolved=guard.get(resolved,part) end
      end
      return resolved
    end
    local binding=checkpoint.bindings[v]
    if not binding then return v end
    if not decoded[v] then
      local native=guard.restore_binding(binding,binding.facade and r.decode(binding.facade))
      decoded[v]=native; encoded[native]=v
    end
    return decoded[v]
  end
  function r.set_global(name,v)
    local targets=guard.assignment_targets(1); targets[1]={checkpoint.shell_root,name}
    local values=guard.assignment_values(1,r.decode(v))
    guard.assignment_check(1,targets,values)
    checkpoint.shell_root[name]=v
  end
  function r.finish(value,tuple) checkpoint.result=tuple or {n=1,value} end
  local codec={}
  function codec.encode(tuple)
    local result={n=tuple.n}
    for i=1,tuple.n do result[i]=r.encode(tuple[i]) end
    return result
  end
  function codec.decode(tuple)
    local result={n=tuple.n}
    for i=1,tuple.n do result[i]=r.decode(tuple[i]) end
    return result
  end
  function r.get(object,key)
    local path=checkpoint.symbols[object]
    if path then
      if type(key)~='string' or key:find('.',1,true) then errors.raise('E_ARGUMENT','invalid namespace member') end
      return r.symbol(path..'.'..key)
    end
    return r.encode(guard.get(r.decode(object),r.decode(key)))
  end
  function r.call(out,symbol,...)
    f.pending=f.pending or {block=f.pc}
    assert(f.pending.block==f.pc,'mismatched pending call')
    guard.call_checkpoint(f.pending,codec)
    local args=table.pack(...)
    for i=1,args.n do args[i]=r.decode(args[i]) end
    local result=codec.encode(table.pack(guard.call(r.decode(symbol),table.unpack(args,1,args.n))))
    f.tuples[out]=result
    return result[1]
  end
  local value_guard=setmetatable({
    restore_binding=function(d,parent)
      local token,descriptor={},{}
      for _,key in ipairs({'name','wire','generation','kind','method'}) do descriptor[key]=d[key] end
      descriptor.facade=parent; checkpoint.bindings[token]=descriptor
      return token
    end,
    binding=function(v) return checkpoint.bindings[v] end,
  },{__index=guard}) -- Ephemeral host adapter, never saved or exposed.
  local ok,result=pcall(function()
    guard.initialize()
    validate(checkpoint,executable,context.tick,guard.spend)
    if not checkpoint.event_initialized then
      f.event=guard.snapshot(event); checkpoint.event_initialized=true
    end
    if shell then
      if not checkpoint.shell_root then checkpoint.shell_root=shell_values.decode(shell.values,value_guard) end
      shell.root=checkpoint.shell_root
    end
    while f.pc~=0 do
      local fn=executable.blocks[f.pc]
      if not fn then errors.raise('E_UNSUPPORTED','invalid continuation block; retained') end
      f.pc=fn(f,r)
      f.pending=nil; guard.call_checkpoint(nil)
    end
    if shell then
      if not checkpoint.result_printed then
        local result=checkpoint.result or {n=0}
        guard.format_results(codec.decode(result)); checkpoint.result_printed=true
      end
      checkpoint.value_graph=shell_values.encode(checkpoint.shell_root,value_guard)
    end
  end)
  if not ok then
    local diagnostic=guard.diagnostic(result)
    if diagnostic.code=='E_BUDGET' then checkpoint.wait_tick=context.tick; return false,nil,'wait' end
    return false,diagnostic,guard.stop_requested() and 'stop' or nil
  end
  checkpoint.completed=true
  return true
end
return M
