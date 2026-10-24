-- Compiler-generated scalar vertical slice; no native stack survives a block.
local admission=require('scripts.runtime.admission')
local errors=require('scripts.runtime.errors')
local sandbox=require('scripts.runtime.sandbox')
local parsing=require('scripts.runtime.parse_admission')
local shell_values=require('scripts.runtime.shell-values')
local ownership=require('scripts.runtime.ownership')
local checkpoint_validation=require('scripts.runtime.checkpoint-validation')
local memory=require('scripts.runtime.memory')
local limits=require('scripts.runtime.limits')
local library_jobs=require('scripts.runtime.library-jobs')
local M={version=9}
local function quote(s) return string.format('%q',s) end
local checkpoint_fields={version=true,source=true,handler=true,frame=true,symbols=true,intern=true,bindings=true,
  owned=true,owned_order=true,symbols_order=true,symbol_roots=true,bindings_order=true,collection=true,validation=true,preparation=true,memory_bytes=true,memory_owner=true,
  wait_tick=true,event_initialized=true,shell_root=true,result=true,result_printed=true,value_graph=true,completed=true,
  tuple_capacities=true,tuple_control=true,functions=true,functions_order=true,root=true,exports=true}
local function frame_bytes(executable)
  return 20*192+35*48+16*(2*executable.locals+2*executable.slots+#executable.symbols+#executable.strings+executable.call_count)
    +80*executable.call_count+96+288+384
end
local function validate(checkpoint,executable,tick,spend,deep,owner)
  local function refuse(message) errors.raise('E_UNSUPPORTED',message..'; continuation retained') end
  if getmetatable(checkpoint)~=nil then refuse('invalid checkpoint metatable') end
  for key in pairs(checkpoint) do spend(1); if not checkpoint_fields[key] then refuse('unknown checkpoint field') end end
  local frame=checkpoint.frame
  if type(frame)~='table' or not errors.integer(frame.pc,0,#executable.blocks)
    or type(frame.locals)~='table' or type(frame.slots)~='table' or type(frame.tuples)~='table'
    or type(frame.cells)~='table' or type(checkpoint.functions)~='table' or type(checkpoint.functions_order)~='table'
    or type(checkpoint.root)~='table' or type(checkpoint.exports)~='table'
    or type(checkpoint.symbols)~='table' or type(checkpoint.intern)~='table'
    or type(checkpoint.bindings)~='table' or type(checkpoint.owned)~='table'
    or checkpoint.wait_tick~=nil and not errors.integer(checkpoint.wait_tick,0,tick) then refuse('invalid checkpoint header') end
  for _,value in ipairs({frame,frame.locals,frame.slots,frame.tuples,checkpoint.symbols,checkpoint.intern,checkpoint.bindings,checkpoint.owned}) do
    if getmetatable(value) then refuse('invalid checkpoint container') end
  end
  for _,name in ipairs({'owned_order','symbols_order','bindings_order'}) do
    if type(checkpoint[name])~='table' or getmetatable(checkpoint[name]) then refuse('invalid ownership order') end
  end
  local phase=checkpoint.preparation
  if phase~=nil and phase~='validate' and phase~='collect' and phase~='execute'
    or phase=='execute' and (checkpoint.validation~=nil or checkpoint.collection~=nil)
    or phase=='collect' and (checkpoint.validation~=nil or type(checkpoint.collection)~='table') then refuse('invalid preparation phase') end
  if checkpoint.collection~=nil and (type(checkpoint.collection)~='table' or getmetatable(checkpoint.collection)) then refuse('invalid collection cursor') end
  if checkpoint.symbol_roots~=nil and (type(checkpoint.symbol_roots)~='table' or getmetatable(checkpoint.symbol_roots)) then refuse('invalid source symbol roots') end
  if checkpoint.memory_owner~=nil and (type(checkpoint.tuple_capacities)~='table' or getmetatable(checkpoint.tuple_capacities)
    or not errors.integer(checkpoint.tuple_control,2,9007199254740991))
    or checkpoint.memory_owner==nil and (checkpoint.tuple_capacities~=nil or checkpoint.tuple_control~=nil) then refuse('invalid tuple workspace') end
  if frame.pending~=nil and (type(frame.pending)~='table' or getmetatable(frame.pending) or frame.pending.block~=frame.pc) then refuse('invalid pending primitive') end
  if frame.bridge~=nil then
    local bridge=frame.bridge
    if type(bridge)~='table' or getmetatable(bridge)
      or checkpoint.symbols[bridge.symbol]~='pcall' and checkpoint.symbols[bridge.symbol]~='xpcall'
      or not errors.integer(bridge.line,1,9007199254740991) or not errors.integer(bridge.column,1,9007199254740991) then
      refuse('invalid protected-call bridge')
    end
  end
  if frame.library~=nil then
    local library=frame.library
    if type(library)~='table' or getmetatable(library) or not library_jobs.supports(library.name)
      or type(library.job)~='table' or getmetatable(library.job)
      or not errors.integer(library.line,1,9007199254740991) or not errors.integer(library.column,1,9007199254740991) then
      refuse('invalid library continuation')
    end
  end
  if deep then checkpoint_validation.advance(checkpoint,executable,spend,owner,frame_bytes(executable)) end
end

-- The ordinary compiler validates the source before passing its AST here.
-- Unsupported slice syntax is explicit, never executed by a native fallback.
function M.lower(main,reject,position,mode)
  local blocks,flow,locals,local_count,slots={},{},{},0,0
  local symbol_paths,literals,calls={},{},{}
  local protos,proto_ids,captured={},{},{}
  local function static_path(node)
    local parts,bytes={},0
    while node and node.node_type=='index' and node.suffix.node_type=='string' do
      local key=node.suffix.value
      parsing.enter(#key+1)
      if key:find('.',1,true) then return end
      parts[#parts+1]=key; bytes=bytes+#key+1
      if node.src_ex_did_not_exist then
        parsing.enter(bytes+#parts+1)
        for i=1,#parts/2 do parts[i],parts[#parts-i+1]=parts[#parts-i+1],parts[i] end
        return table.concat(parts,'.')
      end
      node=node.ex
    end
  end
  local expression,statement,body,expressions,lower_function
  local function slot() slots=slots+1; return slots end
  local function register(ref)
    local def=ref.reference_def
    while def and def.def_type=='upval' do def=def.parent_def end
    if not def or def.def_type~='local' then reject(ref,'invalid lexical reference','E_UNSUPPORTED') end
    if not locals[def] then local_count=local_count+1; locals[def]=local_count end
    local id=locals[def]
    if #def.child_defs>0 then captured[id]=true end
    return captured[id] and 'f.cells['..id..'].value' or 'f.locals['..id..']',id
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
    elseif k=='string' then literals[n.value]=true; return output(quote(n.value))
    elseif k=='boolean' then return output(tostring(n.value))
    elseif k=='nil' then return output('nil')
    elseif k=='vararg' then
      calls[out]=true
      return output('r.varargs('..out..')',nil,true)
    elseif k=='local_ref' or k=='upval_ref' then
      local ref,id=register(n)
      return output(ref,{'l'..id})
    elseif k=='func_proto' then
      local id,captures=lower_function(n.func_def)
      local uses,ids={},{}
      for i,ref in ipairs(captures) do uses[i]='l'..ref; ids[i]=ref end
      return output('r.closure('..id..',{'..table.concat(ids,',')..'})',uses)
    elseif k=='index' then
      local path=static_path(n)
      if path then symbol_paths[path]=true end
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
      parsing.enter(8)
      blocks[pc].operands={left=a,right=b,op=n.op,output=out,nextpc=nextpc,
        numeric=n.op=='+' or n.op=='-' or n.op=='*' or n.op=='/' or n.op=='%' or n.op=='^'}
      pc=expression(n.right,b,pc)
      return expression(n.left,a,pc)
    elseif k=='unop' then
      local a=slot(); local operand=value(a)
      if n.op=='not' then operand='not '..operand
      elseif n.op=='-' then operand='-r.guard.number('..operand..')'
      elseif n.op=='#' then operand='r.guard.length('..operand..')'
      else reject(n,'unsupported continuation unary operator','E_UNSUPPORTED') end
      return expression(n.ex,a,output('('..operand..')',{'s'..a}))
    elseif k=='concat' then
      calls[out]=true
      return expressions(n.exp_list,function(tuple,uses)
        local pc=reserve()
        define(pc,n,'return r.invoke('..out..',r.symbol("@concat"),'..nextpc..',r.arguments('..tuple..'))',
          {nextpc},uses,{'s'..out,'t'..out})
        return pc
      end)
    elseif k=='constructor' then
      local fields,uses,evaluations={}, {},{}
      local array,tail=0
      for i,field in ipairs(n.fields) do
        local key,value_slot=slot(),slot()
        if field.type=='list' then
          array=array+1
          evaluations[#evaluations+1]={number=array,out=key,node=field.value}
        else evaluations[#evaluations+1]={node=field.key,out=key} end
        evaluations[#evaluations+1]={node=field.value,out=value_slot}
        if field.type=='list' and i==#n.fields and (field.value.node_type=='call' or field.value.node_type=='vararg') and not field.value.force_single_result then
          tail='f.tuples['..value_slot..']'; uses[#uses+1]='t'..value_slot
        else
          fields[#fields+1]='{'..value(key)..','..value(value_slot)..'}'
          uses[#uses+1]='s'..key; uses[#uses+1]='s'..value_slot
        end
      end
      local pc=output('r.construct({'..table.concat(fields,',')..'},'..(tail or 'nil')..','..array..')',uses)
      for i=#evaluations,1,-1 do
        local item=evaluations[i]
        if item.number then pc=block(item.node,value(item.out)..'='..item.number,pc,nil,{'s'..item.out})
        else pc=expression(item.node,item.out,pc) end
      end
      return pc
    elseif k=='call' then
      local callee=slot()
      calls[out]=true
      local pc=expressions(n.args,function(tuple,uses)
        uses[#uses+1]='s'..callee
        local pc=reserve()
        define(pc,n,'return r.invoke('..out..','..value(callee)..','..nextpc..(tuple~='' and ','..tuple or '')..')',
          {nextpc},uses,{'s'..out,'t'..out})
        return pc
      end,true)
      return expression(n.ex,callee,pc)
    end
    reject(n,'continuation slice does not yet lower '..tostring(k),'E_UNSUPPORTED')
  end
  function expressions(list,consume,spread)
    local outputs,values={},{}
    for i=1,#list do outputs[i]=slot(); values[i]=value(outputs[i]) end
    local last=list[#list]
    local tail=last and (last.node_type=='call' or last.node_type=='vararg') and not last.force_single_result
    if tail then values[#values]=nil end
    local tuple='r.list({n='..#values..(#values>0 and ','..table.concat(values,',') or '')..'},'..
      (tail and 'f.tuples['..outputs[#outputs]..']' or 'nil')..')'
    if spread then
      if tail then values[#values+1]='r.arguments(f.tuples['..outputs[#outputs]..'])' end
      tuple=table.concat(values,',')
    end
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
    elseif k=='localfunc' then
      local _,id=register(n.name)
      local out=slot()
      local assign=block(n,'r.assign({{slot='..id..(captured[id] and ',cell=true' or '')..'}}, {n=1,'..value(out)..'})',nextpc,{'s'..out,captured[id] and 'l'..id or nil},{'l'..id})
      local create=expression({node_type='func_proto',func_def=n.func_def},out,assign)
      return captured[id] and block(n,'r.new_cells({'..id..'})',create,nil,{'l'..id}) or create
    elseif k=='funcstat' then
      return statement({node_type='assignment',lhs={n.name},rhs={{node_type='func_proto',func_def=n.func_def}}},nextpc,breakpc)
    elseif k=='localstat' or k=='assignment' then
      local lhs=n.lhs[1]
      local first_id
      if lhs.node_type=='local_ref' or lhs.node_type=='upval_ref' then local _; _,first_id=register(lhs) end
      if #n.lhs==1 and lhs.node_type=='local_ref' and not captured[first_id] and n.rhs and #n.rhs==1 then
        local ref=register(lhs); local out=slot()
        local pc=block(n,'r.guard.scalar(r.decode('..value(out)..'),true); '..ref..'=r.guard.bind(1,'..value(out)..')',
          nextpc,{'s'..out},{'l'..locals[lhs.reference_def]})
        return expression(n.rhs[1],out,pc)
      end
      if #n.lhs==1 and lhs.node_type=='index' and not lhs.src_ex_did_not_exist and n.rhs and #n.rhs==1 then
        local object,key,out=slot(),slot(),slot()
        local pc=block(n,'r.assign_one('..value(object)..','..value(key)..','..value(out)..')',
          nextpc,{'s'..object,'s'..key,'s'..out})
        pc=expression(n.rhs[1],out,pc)
        pc=expression(lhs.suffix,key,pc)
        return expression(lhs.ex,object,pc)
      end
      local targets,defs,evaluations,target_uses,new_cells,refs={},{},{},{},{},{}
      for i,lhs in ipairs(n.lhs) do
        if lhs.node_type=='local_ref' or lhs.node_type=='upval_ref' then
          local _,id=register(lhs)
          targets[i]='{slot='..id..(captured[id] and ',cell=true' or '')..'}'
          if lhs.node_type=='local_ref' and not captured[id] then refs[#refs+1]='f.locals['..id..']' end
          defs[#defs+1]='l'..id
          if captured[id] then
            if k=='localstat' then new_cells[#new_cells+1]=id else target_uses[#target_uses+1]='l'..id end
          end
        elseif mode=='shell' and lhs.node_type=='index' and lhs.src_ex_did_not_exist then
          targets[i]='{name='..quote(lhs.suffix.value)..'}'
        elseif lhs.node_type=='index' and not lhs.src_ex_did_not_exist then
          local object,key=slot(),slot()
          targets[i]='{'..value(object)..','..value(key)..'}'
          evaluations[#evaluations+1]={lhs.ex,object}; evaluations[#evaluations+1]={lhs.suffix,key}
          target_uses[#target_uses+1]='s'..object; target_uses[#target_uses+1]='s'..key
        else reject(lhs,'global assignment is forbidden','E_UNSUPPORTED') end
      end
      local pc=expressions(n.rhs or {},function(tuple,uses)
        for _,ref in ipairs(target_uses) do uses[#uses+1]=ref end
        if #refs==#n.lhs then
          return block(n,table.concat(refs,',')..'=r.bind('..#refs..','..tuple..')',nextpc,uses,defs)
        end
        return block(n,(#new_cells>0 and 'r.new_cells({'..table.concat(new_cells,',')..'}); ' or '')..
          'r.assign({'..table.concat(targets,',')..'},'..tuple..')',nextpc,uses,defs)
      end)
      for i=#evaluations,1,-1 do pc=expression(evaluations[i][1],evaluations[i][2],pc) end
      return pc
    elseif k=='dostat' then return body(n,nextpc,breakpc)
    elseif k=='breakstat' then return block(n,'',assert(breakpc))
    elseif k=='retstat' and #n.exp_list==0 then return block(n,'',0)
    elseif k=='retstat' then
      calls[0]=true
      return expressions(n.exp_list,function(tuple,uses)
        return block(n,'r.finish('..tuple..')',0,uses)
      end)
    elseif k=='forlist' then
      local iterator,state,control,out=slot(),slot(),slot(),slot()
      calls[out]=true
      local head=reserve()
      local loop=body(n,head,nextpc)
      local targets,defs,new_cells,refs={},{'s'..control},{},{}
      for i,ref in ipairs(n.name_list) do
        local _,id=register(ref); targets[i]='{slot='..id..(captured[id] and ',cell=true' or '')..'}'
        if not captured[id] then refs[#refs+1]='f.locals['..id..']' end
        defs[#defs+1]='l'..id
        if captured[id] then new_cells[#new_cells+1]=id end
      end
      local test=block(n,'if f.tuples['..out..'][1]~=nil then '..(#new_cells>0 and 'r.new_cells({'..table.concat(new_cells,',')..'}); ' or '')..
        (#new_cells==0 and table.concat(refs,',')..'=r.bind('..#refs..',f.tuples['..out..']); '
          or 'r.assign({'..table.concat(targets,',')..'},f.tuples['..out..']); ')..value(control)..'=f.tuples['..out..'][1]; return '..loop..' end',
        nextpc,{'t'..out},defs,loop)
      define(head,n,'return r.invoke('..out..','..value(iterator)..','..test..','..value(state)..','..value(control)..')',
        {test},{'s'..iterator,'s'..state,'s'..control},{'t'..out})
      return expressions(n.exp_list,function(tuple,uses)
        return block(n,'local t='..tuple..'; '..value(iterator)..','..value(state)..','..value(control)..'=t[1],t[2],t[3]',
          head,uses,{'s'..iterator,'s'..state,'s'..control})
      end)
    elseif k=='fornum' then
      local index,limit,step=slot(),slot(),slot()
      local localvar,var_id=register(n.var)
      local head=reserve()
      local advance=block(n,value(index)..'='..value(index)..'+'..value(step),head,{'s'..index,'s'..step},{'s'..index})
      local loop=body(n,advance,nextpc)
      local controls={'s'..index,'s'..limit,'s'..step}
      define(head,n,'if ('..value(step)..'>0 and '..value(index)..'<='..value(limit)..') or ('..value(step)..'<=0 and '..value(index)..'>='..value(limit)..') then '..
        (captured[var_id] and 'r.new_cells({'..var_id..'}); r.assign({{slot='..var_id..',cell=true}},{n=1,'..value(index)..'});' or localvar..'='..value(index)..';')..' return '..loop..' end; return '..nextpc,
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
  function lower_function(fn)
    if proto_ids[fn] then local id=proto_ids[fn]; return id,protos[id].captures end
    local id=#protos+1; proto_ids[fn]=id
    local proto={captures={}}; protos[id]=proto
    for _,upval in ipairs(fn.upvals or {}) do
      if upval.name~='_ENV' then
        local _,ref=register({reference_def=upval}); proto.captures[#proto.captures+1]=ref
      end
    end
    local params,defs,new_cells={},{},{}
    for i,param in ipairs(fn.params or {}) do
      local _,ref=register(param); params[i]=ref; defs[#defs+1]='l'..ref
      if captured[ref] then new_cells[#new_cells+1]=ref end
    end
    local entry=body(fn,0)
    if #params>0 then entry=block(fn,'r.parameters({'..table.concat(params,',')..'},{'..table.concat(new_cells,',')..'})',entry,nil,defs)
    else entry=block(fn,'f.args=nil',entry) end
    if fn.is_vararg and not (mode=='shell' and fn==main) then entry=block(fn,'r.init_varargs('..#params..')',entry) end
    proto.entry=entry
    return id,proto.captures
  end
  local handlers,entries,helpers={},{},{}
  local exports={}
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
      elseif n.node_type=='localfunc' then helpers[#helpers+1]=n
      elseif n.node_type~='empty' then reject(n,'unsupported declaration','E_UNSUPPORTED') end
      n=n.next
    end
  end
  local names={}; for name in pairs(handlers) do names[#names+1]=name end; table.sort(names)
  for _,name in ipairs(names) do
    local fn=handlers[name]
    local id=lower_function(fn)
    if mode~='shell' and first.node_type~='retstat' then exports[#exports+1]='['..quote(name)..']='..id end
  end
  local exports_text='{'..table.concat(exports,',')..'}'
  for _,name in ipairs(names) do
    local entry=protos[proto_ids[handlers[name]]].entry
    if #exports>0 then
      local uses={}
      for _,handler in ipairs(names) do
        for _,ref in ipairs(protos[proto_ids[handlers[handler]]].captures) do uses[#uses+1]='l'..ref end
      end
      entry=block(handlers[name],'r.init_exports('..exports_text..')',entry,uses)
    end
    for i=#helpers,1,-1 do entry=statement(helpers[i],entry) end
    entries[#entries+1]='['..quote(name)..']='..entry
  end
  local live,definitions={},{}
  for i,node in ipairs(flow) do
    live[i]={}; definitions[i]={}
    for _,ref in ipairs(node.uses) do live[i][ref]=true end
    for _,ref in ipairs(node.defs) do definitions[i][ref]=true end
  end
  local predecessors,queue,head={},{},1
  for i,node in ipairs(flow) do
    for _,successor in ipairs(node.next) do
      parsing.enter(1)
      if successor~=0 then
        predecessors[successor]=predecessors[successor] or {}
        predecessors[successor][#predecessors[successor]+1]=i
      end
    end
    for _,ref in ipairs(node.uses) do queue[#queue+1]={i,ref} end
  end
  -- Propagate each new liveness fact once, rather than rescan every loop's CFG.
  while queue[head] do
    local fact=queue[head]; queue[head]=false; head=head+1
    for _,predecessor in ipairs(predecessors[fact[1]] or {}) do
      parsing.enter(1)
      local ref=fact[2]
      if not definitions[predecessor][ref] and not live[predecessor][ref] then
        live[predecessor][ref]=true; queue[#queue+1]={predecessor,ref}
      end
    end
  end
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
          local kind,id=ref:sub(1,1),tonumber(ref:sub(2))
          cleanup[#cleanup+1]='f.'..(kind=='l' and captured[id] and 'cells' or fields[kind])..'['..id..']=nil'
        end
      end
      maximum=math.max(maximum,#cleanup)
      transitions[#transitions+1]='['..successor..']=function(f) '..table.concat(cleanup,';')..' end'
    end
    cleanups[i]='{'..table.concat(transitions,',')..'}'
    local b=blocks[i]
    if b.operands then
      local o=b.operands
      blocks[i]='function(f,r) local a,b=r.guard.operands_step('..b.line..','..b.column..','..maximum..',f.slots['..o.left..'],f.slots['..o.right..'],'..tostring(o.numeric)..'); f.slots['..o.output..']=(a '..o.op..' b); return '..o.nextpc..' end'
    else
      blocks[i]='function(f,r) r.guard.step('..b.line..','..b.column..','..maximum..'); '..b.code..' end'
    end
  end
  local function quoted_set(values)
    local ordered={}; for value in pairs(values) do ordered[#ordered+1]=value end
    table.sort(ordered,function(a,b) parsing.enter(#a+#b+1); return a<b end)
    for i,value in ipairs(ordered) do ordered[i]=quote(value) end
    return '{'..table.concat(ordered,',')..'}'
  end
  local outputs={}; for out in pairs(calls) do outputs[#outputs+1]=out end
  table.sort(outputs,function(a,b) parsing.enter(1); return a<b end)
  for i,out in ipairs(outputs) do outputs[i]='['..out..']=true' end
  local functions={}
  for i,proto in ipairs(protos) do functions[i]='{entry='..proto.entry..',captures={'..table.concat(proto.captures,',')..'}}' end
  return 'return {blocks={'..table.concat(blocks,',\n')..'},cleanup={'..table.concat(cleanups,',')..'},entries={'..table.concat(entries,',')..'},protos={'..table.concat(functions,',')..'},symbols='..quoted_set(symbol_paths)..',strings='..quoted_set(literals)..',calls={'..table.concat(outputs,',')..'},call_count='..#outputs..',slots='..slots..',locals='..local_count..'}'
end

function M.run(source,factory,name,event,services,context,checkpoint,shell)
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
  if type(factory)~='function' then return false,errors.new('E_PROGRAM','unprepared continuation; source retained') end
  local executable=factory()
  if checkpoint.version==nil then
    if not executable.entries[name] then return false,errors.new('E_NOT_FOUND','handler not declared') end
    local symbols,intern,order={},{},{}
    local roots,capacities
    if memory_owner then
      roots={}
      capacities={}; for out in pairs(executable.calls) do capacities[out]=1 end
      -- Source constants are part of the accepted frame, not new growth after a decrease.
      local bytes=frame_bytes(executable)
      local items={{checkpoint,bytes},{source,#source+32},{name,#name+32}}
      for i,path in ipairs(executable.symbols) do
        local token={}
        symbols[token]=path; intern[path]=token; order[i]=token; roots[i]=token
        items[#items+1]={token,192+2*48+16}; items[#items+1]={path,#path+32}
      end
      for _,value in ipairs(executable.strings) do
        roots[#roots+1]=value; items[#items+1]={value,#value+32}
      end
      local admitted,problem=pcall(memory.acquire_all,memory_owner,items)
      if not admitted then
        local diagnostic=errors.resource_diagnostic(problem)
        return false,diagnostic or errors.new('E_ENGINE','continuation storage admission failed'),diagnostic and 'resource' or nil
      end
    end
    checkpoint.version=M.version; checkpoint.source=source; checkpoint.handler=name
    checkpoint.frame={pc=executable.entries[name],locals={},slots={},tuples={},cells={},event=event,depth=1}
    checkpoint.root=checkpoint.frame; checkpoint.functions={}; checkpoint.functions_order={}; checkpoint.exports={}
    checkpoint.symbols=symbols; checkpoint.intern=intern; checkpoint.bindings={}; checkpoint.owned={}
    checkpoint.owned_order={}; checkpoint.symbols_order=order; checkpoint.bindings_order={}; checkpoint.symbol_roots=roots
    if memory_owner then
      checkpoint.memory_owner=memory_owner.id; checkpoint.tuple_capacities=capacities; checkpoint.tuple_control=2
    end
  end
  local f=checkpoint.frame
  local guard=sandbox.new(context,services,shell,checkpoint)
  local r={guard=guard}
  local symbol_cache=checkpoint.intern
  function r.symbol(path)
    local symbol=symbol_cache[path]
    if not symbol then
      guard.host_work(4,4)
      symbol={}
      if memory_owner then memory.acquire_all(memory_owner,{{symbol,192+2*48+16},{path,#path+32}}) end
      checkpoint.symbols[symbol]=path; symbol_cache[path]=symbol
      checkpoint.symbols_order[#checkpoint.symbols_order+1]=symbol
    end
    return symbol
  end
  function r.global(name)
    if shell and not guard.reserved_global(name) then return guard.get(checkpoint.shell_root,name) end
    if checkpoint.exports[name] then return checkpoint.exports[name] end
    return r.encode(guard.global(name))
  end
  local encoded,decoded={},{}
  local method_tokens
  local function binding_token(descriptor)
    local methods
    if descriptor.facade then
      if not method_tokens then
        local index={}
        guard.host_work(1,1)
        for _,token in ipairs(checkpoint.bindings_order) do
          local binding=checkpoint.bindings[token]
          guard.host_work(2,2)
          if binding and binding.facade then
            index[binding.facade]=index[binding.facade] or {}
            index[binding.facade][binding.method]=token
          end
        end
        method_tokens=index
      end
      methods=method_tokens[descriptor.facade]
      if methods and methods[descriptor.method] then return methods[descriptor.method] end
    end
    guard.host_work(12,12)
    local token={}
    if memory_owner then
      -- Token, six-field descriptor, order slot and binding-index entry.
      local items={{token,2*192+6*48+16+48}}
      for _,key in ipairs({'name','wire','generation','kind','method'}) do
        local value=descriptor[key]
        if type(value)=='string' then items[#items+1]={value,#value+32} end
      end
      memory.acquire_all(memory_owner,items)
    end
    checkpoint.bindings[token]=descriptor
    checkpoint.bindings_order[#checkpoint.bindings_order+1]=token
    if descriptor.facade then
      methods=methods or {}; methods[descriptor.method]=token
      method_tokens[descriptor.facade]=methods
    end
    return token
  end
  function r.encode(v)
    if memory_owner and type(v)=='string' then memory.acquire(memory_owner,v,#v+32) end
    if type(v)~='table' and type(v)~='function' then return v end
    if checkpoint.symbols[v] or checkpoint.bindings[v] or checkpoint.functions[v] then return v end
    if encoded[v] then return encoded[v] end
    local path=guard.symbol(v)
    if path then return r.symbol(path) end
    local binding=guard.binding(v)
    if not binding then
      if guard.is_plain(v) then return v end
      errors.raise('E_UNSUPPORTED','continuation cannot retain a foreign value')
    end
    local descriptor={}
    for _,key in ipairs({'name','wire','generation','kind','method'}) do descriptor[key]=binding[key] end
    if binding.facade then descriptor.facade=r.encode(binding.facade) end
    local token=binding_token(descriptor)
    encoded[v]=token; decoded[token]=v
    return token
  end
  function r.decode(v)
    if type(v)~='table' then return v end
    local path=checkpoint.symbols[v]
    if path then
      local resolved=guard.resolve_symbol(path)
      if resolved~=nil then return resolved end
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
  function r.construct(fields,tail,start)
    local count=#fields+(tail and tail.n or 0)
    return guard.new(count,function()
      local result={}
      for _,pair in ipairs(fields) do result[pair[1]]=pair[2] end
      if tail then for i=1,tail.n do result[start+i-1]=tail[i] end end
      return result
    end)
  end
  function r.bind(count,values)
    for i=1,values.n do guard.scalar(r.decode(values[i]),true) end
    return guard.bind(count,table.unpack(values,1,values.n))
  end
  function r.assign_one(t,k,v)
    guard.assignment_one(t,k,v)
    t[k]=v
  end
  function r.assign(targets,values)
    local count=#targets
    local checked=guard.assignment_targets(count)
    guard.assignment_values(count,table.unpack(values,1,values.n))
    for i,target in ipairs(targets) do
      if target.name then checked[i]={checkpoint.shell_root,target.name}
      elseif target.cell then checked[i]={f.cells[target.slot],'value'}
      elseif target[1] then checked[i]={target[1],target[2]} end
    end
    guard.assignment_check(count,checked,values)
    -- Lua 5.2 publishes duplicate/aliased assignment targets right-to-left.
    for i=count,1,-1 do
      local target=targets[i]
      if target.name then checkpoint.shell_root[target.name]=values[i]
      elseif target.cell then f.cells[target.slot].value=values[i]
      elseif target[1] then target[1][target[2]]=values[i]
      else f.locals[target.slot]=values[i] end
    end
  end
  function r.new_cells(ids)
    guard.host_work(#ids*3+1,#ids*3+1)
    local cells={}
    for i,id in ipairs(ids) do cells[i]=guard.new(0,function() return {} end) end
    for i,id in ipairs(ids) do f.cells[id]=cells[i] end
  end
  function r.parameters(ids,cells)
    local targets={}
    local is_cell={}; for _,id in ipairs(cells) do is_cell[id]=true end
    for i,id in ipairs(ids) do targets[i]={slot=id,cell=is_cell[id]} end
    r.new_cells(cells); r.assign(targets,f.args or {n=0}); f.args=nil
  end
  function r.closure(proto,ids)
    assert(executable.protos[proto],'invalid compiled function')
    guard.host_work(#ids*4+4,#ids*3+4)
    local token,descriptor={}, {proto=proto,cells={}}
    for _,id in ipairs(ids) do descriptor.cells[id]=assert(f.cells[id],'missing lexical cell') end
    if memory_owner then memory.acquire(memory_owner,token,3*192+2*48+48*#ids+16) end
    checkpoint.functions[token]=descriptor; checkpoint.functions_order[#checkpoint.functions_order+1]=token
    return token
  end
  function r.init_exports(exports)
    local values={}
    for name,proto in pairs(exports) do values[name]=r.closure(proto,executable.protos[proto].captures) end
    checkpoint.exports=values
  end
  local call_output
  local function admit_tuple(tuple,out,called)
    if not memory_owner then return end
    guard.host_work(tuple.n+2,0)
    local width=tuple.n-(called and 1 or 0)
    local carrier=f==checkpoint.root and checkpoint or f
    local previous=carrier.tuple_capacities[out]
    if not errors.integer(previous,1,9007199254740991) or width<0 then
      errors.raise('E_UNSUPPORTED','invalid tuple capacity; continuation retained')
    end
    local control=math.max(carrier.tuple_control,width+1)
    local node=memory_owner.values[carrier]
    if not node then errors.raise('E_UNSUPPORTED','missing frame allocation; continuation retained') end
    -- Frame reservations survive limit decreases without retaining dead tuple identities.
    local bytes=node.record.bytes+16*(math.max(0,width-previous)+control-carrier.tuple_control)
    local strings=0
    for i=1,tuple.n do
      local value=tuple[i]
      if type(value)=='string' and not memory_owner.values[value] then strings=strings+1 end
    end
    if bytes~=node.record.bytes or strings>0 then
      guard.host_work(tuple.n+strings*6+4,strings*3+4)
      local items={}
      if bytes~=node.record.bytes then items[1]={carrier,bytes} end
      for i=1,tuple.n do
        local value=tuple[i]
        if type(value)=='string' and not memory_owner.values[value] then items[#items+1]={value,#value+32} end
      end
      memory.acquire_all(memory_owner,items)
      carrier.tuple_capacities[out]=math.max(previous,width); carrier.tuple_control=control
    end
  end
  function r.finish(tuple)
    admit_tuple(tuple,0)
    if f.parent then f.results=tuple else checkpoint.result=tuple end
  end
  function r.init_varargs(parameters)
    if f.varargs then return end
    local args=f.args or {n=0}
    local count=math.max(0,args.n-parameters)
    guard.host_work(count*2+1,count+1)
    admit_tuple({n=count},0)
    local values={n=count}
    for i=1,count do values[i]=args[parameters+i] end
    f.varargs=values
  end
  function r.varargs(out)
    local values=assert(f.varargs,'missing variadic frame')
    admit_tuple(values,out)
    f.tuples[out]=values
    return values[1]
  end
  local codec={}
  local function primitive_tuple(tuple)
    guard.atomic(tuple.n+1,0)
    for i=1,tuple.n do
      local kind=type(tuple[i])
      if kind~='nil' and kind~='boolean' and kind~='number' and kind~='string' then return false end
    end
    return true
  end
  function codec.encode(tuple,values)
    local primitive=primitive_tuple(tuple)
    admit_tuple(tuple,call_output,not values)
    -- These private tuple carriers never escape to guests; immutable scalars
    -- require no translation or defensive copy, including nil-bearing tuples.
    if primitive then return tuple end
    guard.atomic(tuple.n,tuple.n+1)
    local result={n=tuple.n}
    for i=1,tuple.n do result[i]=r.encode(tuple[i]) end
    return result
  end
  function codec.decode(tuple)
    if primitive_tuple(tuple) then return tuple end
    guard.atomic(tuple.n,tuple.n+1)
    local result={n=tuple.n}
    for i=1,tuple.n do result[i]=r.decode(tuple[i]) end
    return result
  end
  function codec.prepare(tuple)
    local values=codec.encode(tuple,true)
    guard.atomic(values.n+1,values.n+2)
    local called={n=values.n+1,true}
    for i=1,values.n do called[i+1]=values[i] end
    return {called=called,values=values}
  end
  function r.get(object,key)
    if guard.is_plain(object) then return r.encode(guard.get(object,key)) end
    return r.encode(guard.get(r.decode(object),r.decode(key)))
  end
  local owned_before,symbols_before,bindings_before,functions_before,memory_before
  function r.call(out,symbol,...)
    call_output=out
    f.tuples[out]=nil -- The overwritten call site's old cache is dead before preparing its replacement.
    owned_before=#checkpoint.owned_order; symbols_before=#checkpoint.symbols_order; bindings_before=#checkpoint.bindings_order
    functions_before=#checkpoint.functions_order
    memory_before=memory_owner and memory_owner.count
    f.pending=f.pending or {block=f.pc}
    assert(f.pending.block==f.pc,'mismatched pending call')
    guard.call_checkpoint(f.pending,codec)
    local path=checkpoint.symbols[symbol]
    local raw=path=='type' or path=='error' or path=='assert' or path=='rawequal' or path=='rawget' or path=='rawset' or path=='rawlen'
      or path=='next' or path=='pairs' or path=='ipairs' or path=='@ipairs-next' or path and path:sub(1,6)=='table.'
    local count=select('#',...)
    guard.atomic(count,0)
    local direct=true
    if not raw then
      for i=1,count do if type(select(i,...))=='table' then direct=false; break end end
    end
    local fn=r.decode(symbol)
    if not guard.is_callable(fn) then errors.raise('E_ARGUMENT','approved callable required') end
    local result
    if direct then result=table.pack(guard.call_unpacked(fn,...))
    else
      local args=table.pack(...)
      for i=1,count do args[i]=r.decode(args[i]) end
      result=table.pack(guard.call(fn,table.unpack(args,1,count)))
    end
    local prepared=f.pending.prepared
    result=prepared and f.pending.call_result==prepared.called and prepared.values or codec.encode(result,true)
    f.tuples[out]=result
    return result[1]
  end
  local transfer={}
  local function deliver(out,tuple,nextpc)
    admit_tuple(tuple,out)
    f.tuples[out]=tuple; f.slots[out]=tuple[1]
    return nextpc
  end
  function r.invoke(out,symbol,nextpc,...)
    f.pending=f.pending or {block=f.pc}
    local pending=f.pending
    pending.output=out
    if pending.guest_result then return deliver(out,pending.guest_result,nextpc) end
    local protection=checkpoint.symbols[symbol]
    if protection=='pcall' or protection=='xpcall' then
      if not pending.protection then
        local count=select('#',...)
        guard.host_work(count+4,count+4)
        local target,handler=...
        local offset=protection=='xpcall' and 2 or 1
        if offset==2 and (not checkpoint.functions[target] and not guard.is_callable(r.decode(target))
          or not checkpoint.functions[handler] and not guard.is_callable(r.decode(handler))) then
          errors.raise('E_ARGUMENT','approved function and message handler required')
        end
        local passed={n=math.max(0,count-offset),select(offset+1,...)}
        pending.protection=true; pending.target=target; pending.args=passed
        if offset==2 then pending.handler=handler end
      end
      symbol=pending.target
    end
    local descriptor=checkpoint.functions[symbol]
    local path=checkpoint.symbols[symbol]
    local bridge=path=='pcall' or path=='xpcall'
    local count=pending.protection and pending.args.n or select('#',...)
    local first
    if pending.protection then first=pending.args[1] else first=select(1,...) end
    local bounded_copy=type(first)=='string' and #first<=256 and
      (path=='string.sub' and count<=3 or count==1 and
        (path=='string.lower' or path=='string.upper' or path=='string.reverse'))
    if path=='@concat' and count<=8 then
      guard.spend(count+1)
      local bytes=0
      for i=1,count do
        local value
        if pending.protection then value=pending.args[i] else value=select(i,...) end
        if type(value)~='string' then bytes=257; break end
        bytes=bytes+#value
      end
      bounded_copy=bytes<=256
    end
    -- Small native atoms use the existing guarded call, not a library frame.
    local library=library_jobs.supports(path) and not (path=='string.char' and count<=1 or bounded_copy)
    if descriptor or bridge or library then
      local captures=descriptor and executable.protos[descriptor.proto].captures or {}
      if not pending.protection then guard.host_work(count+1,count+1) end
      guard.host_work(count+#captures+8,count+8)
      local args=pending.protection and pending.args or {n=count,...}
      local child={pc=descriptor and executable.protos[descriptor.proto].entry or f.pc,locals={},slots={},tuples={},cells={},args=args,
        parent=f,depth=f.depth+1,return_out=out}
      for _,id in ipairs(captures) do child.cells[id]=assert(descriptor.cells[id],'missing captured cell') end
      if bridge then
        local location=guard.diagnostic('')
        child.bridge={symbol=symbol,line=location.line,column=location.column}
      end
      if library then
        local location=guard.diagnostic('')
        child.library={name=path,line=location.line,column=location.column,job={}}
        guard.job_resize(child.library.job,2048)
      end
      if memory_owner then
        local capacities={}; for site in pairs(executable.calls) do capacities[site]=1 end
        child.tuple_capacities=capacities; child.tuple_control=2
        memory.acquire(memory_owner,child,frame_bytes(executable))
      end
      checkpoint.frame=child
      return transfer
    end
    local value
    if pending.protection then value=r.call(out,symbol,r.arguments(pending.args))
    else value=r.call(out,symbol,...) end
    local result=f.tuples[out]
    if pending.handling then return deliver(out,{n=2,false,result[1]},nextpc)
    elseif pending.protection then
      local protected={n=result.n+1,true}
      for i=1,result.n do protected[i+1]=result[i] end
      return deliver(out,protected,nextpc)
    end
    f.slots[out]=value
    return nextpc
  end
  local function protected_result(pending,result)
    if pending.handling then return {n=2,false,result[1]} end
    if pending.protection then
      local protected={n=result.n+1,true}
      for i=1,result.n do protected[i+1]=result[i] end
      return protected
    end
    return result
  end
  local function complete_child()
    local child=f; local parent=assert(child.parent)
    local result=child.results or {n=0}
    guard.host_work(result.n+4,result.n+4)
    result=protected_result(parent.pending,result)
    f=parent
    local admitted,problem=pcall(admit_tuple,result,child.return_out)
    f=child
    if not admitted then error(problem,0) end
    parent.pending.guest_result=result; checkpoint.frame=parent
    if memory_owner then memory.release(memory_owner,child) end
  end
  local function record_failure(problem)
    guard.check()
    if not f.failure then
      local diagnostic=guard.diagnostic(problem)
      if type(problem)=='table' and not guard.is_plain(problem) and not guard.encoded_type(problem) then problem=guard.snapshot(problem) end
      f.failure={value=r.encode(problem),diagnostic=diagnostic}
    end
  end
  local function unwind(problem)
    return memory.control(memory_owner,record_failure,problem)
  end
  local uncaught
  local function advance_failure()
    guard.step(f.failure.diagnostic.line,f.failure.diagnostic.column)
    guard.host_work(4,4)
    if f.pending and f.pending.protection then
      local pending=f.pending
      local handler_depth=pending.handler_depth or 0
      if pending.handler and handler_depth>=limits.host_stack_depth then
        -- Unwinding must not renew the logical native message-handler budget.
        local _,problem=pcall(guard.refuse_depth,handler_depth)
        problem.line=f.failure.diagnostic.line; problem.column=f.failure.diagnostic.column
        problem=guard.snapshot(problem)
        local tuple={n=2,false,problem}
        admit_tuple(tuple,pending.output)
        pending.guest_result=tuple
      elseif pending.handler then
        admit_tuple({n=2},pending.output) -- Reserve the failure carrier before leaving control unwinding.
        pending.handler_depth=handler_depth+1
        pending.target=pending.handler; pending.args={n=1,f.failure.value}; pending.handling=true
        pending.call_result=nil; pending.service_result=nil; pending.prepared=nil
        pending.jobs=nil; pending.service_args=nil; pending.result_kind=nil
      else
        local tuple={n=2,false,f.failure.value}
        admit_tuple(tuple,pending.output)
        pending.guest_result=tuple
      end
      f.failure=nil
    elseif f.parent then
      f.parent.failure=f.failure; checkpoint.frame=f.parent
      if memory_owner then memory.release(memory_owner,f) end
    else uncaught=f.failure.diagnostic; error(f.failure.value,0) end
  end
  local value_guard=setmetatable({
    restore_binding=function(d,parent)
      local descriptor={}
      for _,key in ipairs({'name','wire','generation','kind','method'}) do descriptor[key]=d[key] end
      descriptor.facade=parent
      return binding_token(descriptor)
    end,
    binding=function(v) return checkpoint.bindings[v] end,
  },{__index=guard}) -- Ephemeral host adapter, never saved or exposed.
  local function run_bridge()
    guard.step(f.bridge.line,f.bridge.column)
    return r.invoke(f.return_out,f.bridge.symbol,0,r.arguments(f.args))
  end
  local function run_library()
    local state=f.library
    guard.step(state.line,state.column)
    local function prepare(result)
      if state.result then return state.result end
      admit_tuple(result,f.return_out)
      for i=1,result.n do result[i]=r.encode(result[i]) end
      local child=f
      local parent=assert(child.parent)
      guard.atomic(result.n+2,result.n+2)
      local returned=protected_result(parent.pending,result)
      f=parent
      local ok,problem=pcall(admit_tuple,returned,child.return_out)
      f=child
      if not ok then error(problem,0) end
      state.result=result
      return result
    end
    local function compare(symbol,args)
      local nextpc=r.invoke(f.return_out,symbol,1,r.arguments(args))
      if nextpc==transfer then return end
      local result=f.tuples[f.return_out]
      f.pending=nil; guard.call_checkpoint(nil)
      return result
    end
    local library_guard=setmetatable({describe=function(value) return guard.describe(r.decode(value)) end},{__index=guard})
    local result=library_jobs.advance(state.name,library_guard,state.job,f.args,compare,prepare)
    if not result then return transfer end
    result=prepare(result)
    f.results=result; f.args=nil; f.pending=nil; f.pc=0
    guard.call_checkpoint(nil)
  end
  local progressed=false
  local ok,result=pcall(function()
    guard.initialize()
    validate(checkpoint,executable,context.tick,guard.spend,checkpoint.preparation==nil or checkpoint.preparation=='validate',memory_owner)
    if checkpoint.preparation==nil or checkpoint.preparation=='validate' then checkpoint.preparation='collect' end
    if checkpoint.preparation=='collect' then
      local reclaimed=checkpoint.collection and ownership.advance(checkpoint,guard.spend,memory_owner)
      checkpoint.preparation='execute'
      if reclaimed then return 'prepared' end -- Do not rebuild abandoned prefixes in a permanently too-small tail.
    end
    owned_before=#checkpoint.owned_order; symbols_before=#checkpoint.symbols_order; bindings_before=#checkpoint.bindings_order
    memory_before=memory_owner and memory_owner.count
    functions_before=#checkpoint.functions_order
    if not checkpoint.event_initialized then
      f.event=guard.snapshot(event); f.args={n=1,f.event}; checkpoint.event_initialized=true
    end
    if shell then
      if not checkpoint.shell_root then checkpoint.shell_root=shell_values.decode(shell.values,value_guard) end
      shell.root=checkpoint.shell_root
    end
    while true do
      f=checkpoint.frame
      if f.failure then memory.control(memory_owner,advance_failure)
      elseif f.pc==0 then
        if not f.parent then break end
        local ran,problem=pcall(complete_child)
        if not ran then unwind(problem) end
      elseif f.library then
        local ran,problem=pcall(run_library)
        if not ran then unwind(problem) end
      elseif f.bridge then
        local ran,nextpc=pcall(run_bridge)
        if not ran then unwind(nextpc)
        elseif nextpc~=transfer then
          f.results=f.tuples[f.return_out]; f.args=nil; f.pending=nil; f.pc=0
          guard.call_checkpoint(nil); progressed=true
        end
      else
      local fn=executable.blocks[f.pc]
      if not fn then errors.raise('E_UNSUPPORTED','invalid continuation block; retained') end
      local previous=f.pc
      local ran,nextpc=pcall(fn,f,r)
      if not ran then unwind(nextpc)
      elseif nextpc~=transfer then
        f.pc=nextpc
        executable.cleanup[previous][f.pc](f)
        f.pending=nil; guard.call_checkpoint(nil)
        progressed=true
      end
      end
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
    local diagnostic=uncaught or guard.diagnostic(result)
    if guard.work_suspended() then
      -- Keep paid preparation only while a failed attempt publishes no retained staging.
      local staged=owned_before and (#checkpoint.owned_order>owned_before or #checkpoint.symbols_order>symbols_before
        or #checkpoint.bindings_order>bindings_before or functions_before and #checkpoint.functions_order>functions_before or memory_owner and memory_owner.count>memory_before)
      if checkpoint.preparation~='execute' or progressed or staged then
        if progressed or staged or checkpoint.preparation==nil then checkpoint.preparation='validate' end
        if not checkpoint.collection then ownership.begin(checkpoint,executable,staged) end
      end
      checkpoint.wait_tick=context.tick; return false,nil,'wait'
    end
    if diagnostic.recoverable then return false,diagnostic,'resource' end
    return false,diagnostic,guard.stop_requested() and 'stop' or nil
  end
  if result=='prepared' then checkpoint.wait_tick=context.tick; return false,nil,'wait' end
  checkpoint.completed=true
  return true
end
return M
