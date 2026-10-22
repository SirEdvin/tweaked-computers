-- Compiler-generated scalar vertical slice; no native stack survives a block.
local admission=require('scripts.runtime.admission')
local errors=require('scripts.runtime.errors')
local sandbox=require('scripts.runtime.sandbox')
local parsing=require('scripts.runtime.parse_admission')
local shell_values=require('scripts.runtime.shell-values')
local ownership=require('scripts.runtime.ownership')
local checkpoint_validation=require('scripts.runtime.checkpoint-validation')
local M={version=2}
local function quote(s) return string.format('%q',s) end
local checkpoint_fields={version=true,source=true,handler=true,frame=true,symbols=true,intern=true,bindings=true,
  owned=true,owned_order=true,symbols_order=true,bindings_order=true,collection=true,validation=true,memory_bytes=true,memory_owner=true,
  wait_tick=true,event_initialized=true,shell_root=true,result=true,result_printed=true,value_graph=true,completed=true}
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
  for _,value in ipairs({frame,frame.locals,frame.slots,frame.tuples,checkpoint.symbols,checkpoint.intern,checkpoint.bindings,checkpoint.owned}) do
    if getmetatable(value) then refuse('invalid checkpoint container') end
  end
  for _,name in ipairs({'owned_order','symbols_order','bindings_order'}) do
    if type(checkpoint[name])~='table' or getmetatable(checkpoint[name]) then refuse('invalid ownership order') end
  end
  if checkpoint.collection~=nil and (type(checkpoint.collection)~='table' or getmetatable(checkpoint.collection)) then refuse('invalid collection cursor') end
  if frame.pending~=nil and (type(frame.pending)~='table' or getmetatable(frame.pending) or frame.pending.block~=frame.pc) then refuse('invalid pending primitive') end
  checkpoint_validation.advance(checkpoint,executable,spend)
end

-- The ordinary compiler validates the source before passing its AST here.
-- Unsupported slice syntax is explicit, never executed by a native fallback.
function M.lower(main,reject,position,mode)
  local blocks,flow,locals,local_count,slots={},{},{},0,0
  local expression,statement,body,expressions
  local function slot() slots=slots+1; return slots end
  local function register(ref)
    local def=ref.reference_def
    if not def or def.def_type~='local' then reject(ref,'continuation slice requires local values','E_UNSUPPORTED') end
    if not locals[def] then local_count=local_count+1; locals[def]=local_count end
    return 'f.locals['..locals[def]..']'
  end
  local function value(i) return 'f.slots['..i..']' end
  local function block(n,code,nextpc,uses,defs,branch)
    parsing.enter(#code+1)
    local line,column=position(n)
    blocks[#blocks+1]={line=line,column=column,code=code..'; return '..nextpc}
    flow[#blocks]={uses=uses or {},defs=defs or {},next={nextpc,branch}}
    return #blocks
  end
  local function reserve() blocks[#blocks+1]=false; return #blocks end
  local function define(pc,n,code,successors,uses,defs)
    parsing.enter(#code+1)
    local line,column=position(n)
    blocks[pc]={line=line,column=column,code=code}
    flow[pc]={uses=uses or {},defs=defs or {},next=successors}
  end
  function expression(n,out,nextpc)
    parsing.enter(1)
    local k=n.node_type
    local target=value(out)
    local function output(code,uses,tuple)
      return block(n,target..'='..code,nextpc,uses,{'s'..out,tuple and 't'..out or nil})
    end
    if k=='number' then return output(n.src_value or tostring(n.value))
    elseif k=='string' then return output(quote(n.value))
    elseif k=='boolean' then return output(tostring(n.value))
    elseif k=='nil' then return output('nil')
    elseif k=='local_ref' then
      local ref=register(n)
      return output(ref,{'l'..locals[n.reference_def]})
    elseif k=='index' then
      if n.src_ex_did_not_exist then
        return output('r.global('..quote(n.suffix.value)..')')
      end
      local a,b=slot(),slot()
      local pc=output('r.get('..value(a)..','..value(b)..')',{'s'..a,'s'..b})
      pc=expression(n.suffix,b,pc)
      return expression(n.ex,a,pc)
    elseif k=='binop' then
      local a,b=slot(),slot()
      if n.op=='and' or n.op=='or' then
        local right=expression(n.right,out,nextpc)
        local pc=block(n,target..'='..value(a)..'; if '..(n.op=='and' and '' or 'not ')..value(a)..' then return '..right..' end',nextpc,{'s'..a},{'s'..out},right)
        return expression(n.left,a,pc)
      end
      local left,right=value(a),value(b)
      if n.op=='+' or n.op=='-' or n.op=='*' or n.op=='/' or n.op=='%' or n.op=='^' then
        left='r.guard.number('..left..')'; right='r.guard.number('..right..')'
      elseif n.op=='==' or n.op=='~=' or n.op=='<' or n.op=='>' or n.op=='<=' or n.op=='>=' then
        left='r.guard.scalar('..left..')'; right='r.guard.scalar('..right..')'
      else reject(n,'unsupported continuation operator','E_UNSUPPORTED') end
      local pc=output('('..left..' '..n.op..' '..right..')',{'s'..a,'s'..b})
      pc=expression(n.right,b,pc)
      return expression(n.left,a,pc)
    elseif k=='unop' then
      local a=slot(); local operand=value(a)
      if n.op=='not' then operand='not '..operand
      elseif n.op=='-' then operand='-r.guard.number('..operand..')'
      elseif n.op=='#' then operand='r.guard.length('..operand..')'
      else reject(n,'unsupported continuation unary operator','E_UNSUPPORTED') end
      return expression(n.ex,a,output('('..operand..')',{'s'..a}))
    elseif k=='call' then
      local callee=slot()
      local pc=expressions(n.args,function(tuple,uses)
        uses[#uses+1]='s'..callee
        return output('r.call('..out..','..value(callee)..',r.arguments('..tuple..'))',uses,true)
      end)
      return expression(n.ex,callee,pc)
    end
    reject(n,'continuation slice does not yet lower '..tostring(k),'E_UNSUPPORTED')
  end
  function expressions(list,consume)
    local outputs,values={},{}
    for i=1,#list do outputs[i]=slot(); values[i]=value(outputs[i]) end
    local last=list[#list]
    local tail=last and last.node_type=='call' and not last.force_single_result
    if tail then values[#values]=nil end
    local tuple='r.list({n='..#values..(#values>0 and ','..table.concat(values,',') or '')..'},'..
      (tail and 'f.tuples['..outputs[#outputs]..']' or 'nil')..')'
    local uses={}
    for i=1,#list do uses[i]=(tail and i==#list and 't' or 's')..outputs[i] end
    local pc=consume(tuple,uses)
    for i=#list,1,-1 do pc=expression(list[i],outputs[i],pc) end
    return pc
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
      local targets,defs={},{}
      for i,lhs in ipairs(n.lhs) do
        if lhs.node_type=='local_ref' then
          register(lhs)
          targets[i]='{slot='..locals[lhs.reference_def]..'}'
          defs[#defs+1]='l'..locals[lhs.reference_def]
        elseif mode=='shell' and lhs.node_type=='index' and lhs.src_ex_did_not_exist then
          targets[i]='{name='..quote(lhs.suffix.value)..'}'
        else reject(lhs,'continuation slice requires local or shell-global assignment','E_UNSUPPORTED') end
      end
      return expressions(n.rhs or {},function(tuple,uses)
        return block(n,'r.assign({'..table.concat(targets,',')..'},'..tuple..')',nextpc,uses,defs)
      end)
    elseif k=='dostat' then return body(n,nextpc,breakpc)
    elseif k=='breakstat' then return block(n,'',assert(breakpc))
    elseif k=='retstat' and #n.exp_list==0 then return block(n,'',0)
    elseif k=='retstat' and mode=='shell' then
      return expressions(n.exp_list,function(tuple,uses)
        return block(n,'r.finish('..tuple..')',0,uses)
      end)
    elseif k=='fornum' then
      local index,limit,step=slot(),slot(),slot()
      local localvar=register(n.var)
      local head=reserve()
      local advance=block(n,value(index)..'='..value(index)..'+'..value(step),head,{'s'..index,'s'..step},{'s'..index})
      local loop=body(n,advance,nextpc)
      local controls={'s'..index,'s'..limit,'s'..step}
      define(head,n,'if ('..value(step)..'>0 and '..value(index)..'<='..value(limit)..') or ('..value(step)..'<=0 and '..value(index)..'>='..value(limit)..') then '..localvar..'='..value(index)..'; return '..loop..' end; return '..nextpc,
        {loop,nextpc},controls,{'l'..locals[n.var.reference_def]})
      local convert=block(n,'local a,b,c=r.guard.number('..value(index)..'),r.guard.number('..value(limit)..'),r.guard.number('..value(step)..'); '..value(index)..','..value(limit)..','..value(step)..'=a,b,c',head,controls,controls)
      local pc=n.step and expression(n.step,step,convert) or block(n,value(step)..'=1',convert,nil,{'s'..step})
      pc=expression(n.stop,limit,pc)
      return expression(n.start,index,pc)
    elseif k=='whilestat' then
      local head=reserve(); local condition=slot()
      local loop=body(n,head,nextpc)
      local test=expression(n.condition,condition,block(n,'if '..value(condition)..' then return '..loop..' end',nextpc,{'s'..condition},nil,loop))
      define(head,n,'return '..test,{test})
      return head
    elseif k=='repeatstat' then
      local head=reserve(); local condition=slot()
      local test=expression(n.condition,condition,block(n,'if not '..value(condition)..' then return '..head..' end',nextpc,{'s'..condition},nil,head))
      local loop=body(n,test,nextpc)
      define(head,n,'return '..loop,{loop})
      return head
    elseif k=='ifstat' then
      local pc=n.elseblock and body(n.elseblock,nextpc,breakpc) or nextpc
      for i=#n.ifs,1,-1 do
        local b=n.ifs[i]; local condition=slot()
        local branch=body(b,nextpc,breakpc)
        pc=expression(b.condition,condition,block(b,'if '..value(condition)..' then return '..branch..' end',pc,{'s'..condition},nil,branch))
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
    if parameter then entry=block(fn,parameter..'=f.event',entry,nil,{'l'..locals[fn.params[1].reference_def]}) end
    entries[#entries+1]='['..quote(name)..']='..entry
  end
  local live,definitions={},{}
  for i,node in ipairs(flow) do
    live[i]={}; definitions[i]={}
    for _,ref in ipairs(node.uses) do live[i][ref]=true end
    for _,ref in ipairs(node.defs) do definitions[i][ref]=true end
  end
  local changed
  repeat
    changed=false
    for i,node in ipairs(flow) do
      for _,successor in ipairs(node.next) do
        for ref in pairs(live[successor] or {}) do
          parsing.enter(1)
          if not definitions[i][ref] and not live[i][ref] then live[i][ref]=true; changed=true end
        end
      end
    end
  until not changed
  local cleanups={}
  local fields={s='slots',t='tuples',l='locals'}
  for i,node in ipairs(flow) do
    local transitions,maximum={},0
    local candidates={}
    for ref in pairs(live[i]) do candidates[ref]=true end
    for ref in pairs(definitions[i]) do candidates[ref]=true end
    local ordered={}; for ref in pairs(candidates) do ordered[#ordered+1]=ref end
    table.sort(ordered,function(a,b) parsing.enter(1); return a<b end)
    for _,successor in ipairs(node.next) do
      local cleanup={}
      for _,ref in ipairs(ordered) do
        parsing.enter(1)
        if not (live[successor] or {})[ref] then
          cleanup[#cleanup+1]='f.'..fields[ref:sub(1,1)]..'['..ref:sub(2)..']=nil'
        end
      end
      maximum=math.max(maximum,#cleanup)
      transitions[#transitions+1]='['..successor..']=function(f) '..table.concat(cleanup,';')..' end'
    end
    cleanups[i]='{'..table.concat(transitions,',')..'}'
    local b=blocks[i]
    blocks[i]='function(f,r) r.guard.step('..b.line..','..b.column..'); r.guard.spend('..maximum..'); '..b.code..' end'
  end
  return 'return {blocks={'..table.concat(blocks,',\n')..'},cleanup={'..table.concat(cleanups,',')..'},entries={'..table.concat(entries,',')..'},slots='..slots..',locals='..local_count..'}'
end

function M.run(source,generated,name,event,services,context,checkpoint,shell)
  if checkpoint.version~=nil and (checkpoint.version~=M.version or checkpoint.source~=source or checkpoint.handler~=name) then
    return false,errors.new('E_UNSUPPORTED','continuation identity/ABI mismatch; retained')
  end
  if checkpoint.wait_tick==context.tick then return false,nil,'wait' end
  local memory_owner=context.memory_owner
  if memory_owner and (memory_owner.closed or memory_owner.closing)
    or checkpoint.memory_owner~=nil and (not memory_owner or memory_owner.id~=checkpoint.memory_owner)
    or checkpoint.version~=nil and memory_owner and checkpoint.memory_owner~=memory_owner.id then
    return false,errors.new('E_UNSUPPORTED','continuation memory owner mismatch; retained')
  end
  local factory,problem=load(generated,'@continuation','t',{})
  if not factory then return false,errors.new('E_PROGRAM',problem) end
  local executable=factory()
  if checkpoint.version==nil then
    if not executable.entries[name] then return false,errors.new('E_NOT_FOUND','handler not declared') end
    checkpoint.version=M.version; checkpoint.source=source; checkpoint.handler=name
    checkpoint.frame={pc=executable.entries[name],locals={},slots={},tuples={},event=event}
    checkpoint.symbols={}; checkpoint.intern={}; checkpoint.bindings={}; checkpoint.owned={}
    checkpoint.owned_order={}; checkpoint.symbols_order={}; checkpoint.bindings_order={}
    if memory_owner then checkpoint.memory_owner=memory_owner.id end
  end
  local f=checkpoint.frame
  local guard=sandbox.new(context,services,shell,checkpoint)
  local r={guard=guard}
  local symbol_cache=checkpoint.intern
  function r.symbol(path)
    local symbol=symbol_cache[path]
    if not symbol then
      symbol={}; checkpoint.symbols[symbol]=path; symbol_cache[path]=symbol
      checkpoint.symbols_order[#checkpoint.symbols_order+1]=symbol
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
    checkpoint.bindings_order[#checkpoint.bindings_order+1]=token
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
  function r.list(prefix,tail)
    local count=prefix.n+(tail and tail.n or 0)
    guard.host_work(count+1,count+1)
    if tail then for i=1,tail.n do prefix[prefix.n+i]=tail[i] end end
    prefix.n=count
    return prefix
  end
  function r.arguments(tuple) return table.unpack(tuple,1,tuple.n) end
  function r.assign(targets,values)
    local count=#targets
    local checked=guard.assignment_targets(count)
    local decoded={n=values.n}
    for i=1,values.n do decoded[i]=r.decode(values[i]) end
    guard.assignment_values(count,table.unpack(decoded,1,decoded.n))
    for i,target in ipairs(targets) do
      if target.name then checked[i]={checkpoint.shell_root,target.name} end
    end
    guard.assignment_check(count,checked,decoded)
    -- Lua 5.2 publishes duplicate/aliased assignment targets right-to-left.
    for i=count,1,-1 do
      local target=targets[i]
      if target.name then checkpoint.shell_root[target.name]=values[i]
      else f.locals[target.slot]=values[i] end
    end
  end
  function r.finish(tuple) checkpoint.result=tuple end
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
  function codec.prepare(tuple)
    local values=codec.encode(tuple)
    local called={n=values.n+1,true}
    for i=1,values.n do called[i+1]=values[i] end
    return {called=called,values=values}
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
    local fn=r.decode(symbol)
    if not guard.is_callable(fn) then errors.raise('E_ARGUMENT','approved callable required') end
    local result=table.pack(guard.call(fn,table.unpack(args,1,args.n)))
    local prepared=f.pending.prepared
    result=prepared and f.pending.call_result==prepared.called and prepared.values or codec.encode(result)
    f.tuples[out]=result
    return result[1]
  end
  local value_guard=setmetatable({
    restore_binding=function(d,parent)
      local token,descriptor={},{}
      for _,key in ipairs({'name','wire','generation','kind','method'}) do descriptor[key]=d[key] end
      descriptor.facade=parent; checkpoint.bindings[token]=descriptor
      checkpoint.bindings_order[#checkpoint.bindings_order+1]=token
      return token
    end,
    binding=function(v) return checkpoint.bindings[v] end,
  },{__index=guard}) -- Ephemeral host adapter, never saved or exposed.
  local ok,result=pcall(function()
    guard.initialize()
    validate(checkpoint,executable,context.tick,guard.spend)
    if checkpoint.collection then ownership.advance(checkpoint,guard.spend,memory_owner) end
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
      local previous=f.pc
      f.pc=fn(f,r)
      executable.cleanup[previous][f.pc](f)
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
    if guard.work_suspended() then
      if not checkpoint.collection then ownership.begin(checkpoint,executable) end
      checkpoint.wait_tick=context.tick; return false,nil,'wait'
    end
    if diagnostic.recoverable then return false,diagnostic,'resource' end
    return false,diagnostic,guard.stop_requested() and 'stop' or nil
  end
  checkpoint.completed=true
  return true
end
return M
