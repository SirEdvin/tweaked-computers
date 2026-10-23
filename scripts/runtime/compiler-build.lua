-- Offline trusted-source transform. Run through tools/compiler_build.py, never in Factorio.
local parse=require('vendor.phobos.parser')
local admission=require('scripts.runtime.parse_admission')
local M={}
local function q(s) return string.format('%q',s) end
function M.generate(source,name)
  admission.begin(nil)
  local main,diagnostics=parse(source,name)
  admission.finish()
  if #diagnostics>0 then error(require('vendor.phobos.error_code_util').get_message(diagnostics[1])) end
  local blocks,protos,ids,defs={},{},{},{}
  local function cell(ref)
    local def=ref.reference_def
    while def.def_type=='upval' do def=def.parent_def end
    if not defs[def] then defs[def]=#defs+1; defs[#defs+1]=def end
    return defs[def]
  end
  local function add(s) blocks[#blocks+1]=s; return #blocks end
  local function reserve() return add(false) end
  local function link(code,pc) return add(code..'; f.pc='..pc) end
  local expression,statement,body,func,sequence
  local slots=0
  local function slot() slots=slots+1; return slots end
  local function value(i) return 'f.s['..i..']' end
  local function result(i) return 'f.t['..i..']' end
  local function assign(i,code,pc) return link(value(i)..'='..code,pc) end
  function sequence(xs,consume)
    local args,values={},{}
    for i=1,#xs do args[i]=slot(); values[i]=value(args[i]) end
    local tail=xs[#xs]
    local spread=tail and not tail.force_single_result and (tail.node_type=='call' or tail.node_type=='vararg')
    if spread then values[#values]=nil end
    local tuple='{n='..#values..(#values>0 and ','..table.concat(values,',') or '')..'}'
    if spread then tuple='r.join('..tuple..','..result(args[#args])..')' end
    local pc=consume(tuple)
    for i=#xs,1,-1 do pc=expression(xs[i],args[i],pc) end
    return pc
  end
  function expression(n,out,pc)
    local k=n.node_type
    if k=='nil' then return assign(out,'nil',pc)
    elseif k=='boolean' or k=='number' then return assign(out,tostring(n.value),pc)
    elseif k=='string' then return assign(out,q(n.value),pc)
    elseif k=='local_ref' or k=='upval_ref' then return assign(out,'f.l['..cell(n)..'].v',pc)
    elseif k=='vararg' then return link(result(out)..'=f.args; '..value(out)..'=f.args[1]',pc)
    elseif k=='func_proto' then
      local id=func(n.func_def)
      return assign(out,'r.closure(f,'..id..')',pc)
    elseif k=='index' then
      if n.src_ex_did_not_exist then return assign(out,'r.global('..q(n.suffix.value)..')',pc) end
      local a,b=slot(),slot()
      return expression(n.ex,a,expression(n.suffix,b,assign(out,'r.get('..value(a)..','..value(b)..')',pc)))
    elseif k=='unop' then
      local a=slot(); return expression(n.ex,a,assign(out,'('..n.op..' '..value(a)..')',pc))
    elseif k=='binop' then
      local a,b=slot(),slot()
      if n.op=='and' or n.op=='or' then
        local right=expression(n.right,out,pc)
        return expression(n.left,a,add('if '..(n.op=='or' and 'not ' or '')..value(a)..' then f.pc='..right..' else '..value(out)..'='..value(a)..'; f.pc='..pc..' end'))
      end
      return expression(n.left,a,expression(n.right,b,assign(out,'('..value(a)..' '..n.op..' '..value(b)..')',pc)))
    elseif k=='concat' then
      return sequence(n.exp_list,function(tuple) return add('r.call(f,r.global("concat"),'..tuple..','..out..','..pc..')') end)
    elseif k=='call' then
      local callee=slot()
      if n.is_selfcall then
        local object=slot()
        local call=sequence(n.args,function(tuple) return add('r.call(f,'..value(callee)..',r.join({n=1,'..value(object)..'},'..tuple..'),'..out..','..pc..')') end)
        call=assign(callee,'r.get('..value(object)..','..q(n.suffix.value)..')',call)
        return expression(n.ex,object,call)
      end
      return expression(n.ex,callee,sequence(n.args,function(tuple) return add('r.call(f,'..value(callee)..','..tuple..','..out..','..pc..')') end))
    elseif k=='constructor' then
      local fields,tail={},0
      for i=#n.fields,1,-1 do
        local field=n.fields[i]; local a,b=slot(),slot()
        if field.type=='list' then
          local index=0; for j=1,i do if n.fields[j].type=='list' then index=index+1 end end
          local spread=i==#n.fields and not field.value.force_single_result and (field.value.node_type=='call' or field.value.node_type=='vararg')
          local write=spread and 'r.append('..value(out)..','..index..','..result(b)..')' or value(out)..'['..index..']='..value(b)
          pc=expression(field.value,b,link(write,pc))
        else pc=expression(field.key,a,expression(field.value,b,link(value(out)..'['..value(a)..']='..value(b),pc))) end
      end
      return assign(out,'{}',pc)
    end
    error('unsupported trusted expression '..tostring(k))
  end
  function body(scope,pc,breakpc,labels)
    labels=labels or {}
    local list={}; local n=scope.body.first
    while n do list[#list+1]=n; if n.node_type=='label' then labels[n.name]=labels[n.name] or reserve() end; n=n.next end
    for i=#list,1,-1 do pc=statement(list[i],pc,breakpc,labels) end
    return pc
  end
  function statement(n,pc,breakpc,labels)
    local k=n.node_type
    if k=='empty' then return pc
    elseif k=='call' then return expression(n,slot(),pc)
    elseif k=='localfunc' then
      local id=cell(n.name); local fn=func(n.func_def)
      return link('f.l['..id..']={}; f.l['..id..'].v=r.closure(f,'..fn..')',pc)
    elseif k=='funcstat' then return statement({node_type='assignment',lhs={n.name},rhs={{node_type='func_proto',func_def=n.func_def}}},pc,breakpc,labels)
    elseif k=='localstat' or k=='assignment' then
      local targets,evals={},{}
      for i,lhs in ipairs(n.lhs) do
        if lhs.node_type=='local_ref' or lhs.node_type=='upval_ref' then targets[i]={id=cell(lhs)}
        else
          assert(lhs.node_type=='index' and not lhs.src_ex_did_not_exist,'trusted global assignment')
          local a,b=slot(),slot(); targets[i]={object=a,key=b}; evals[#evals+1]={lhs.ex,a}; evals[#evals+1]={lhs.suffix,b}
        end
      end
      local start=sequence(n.rhs or {},function(tuple)
        local out={'local t='..tuple}
        for i=#targets,1,-1 do
          local target=targets[i]
          if target.id then
            out[#out+1]='f.l['..target.id..']'..(k=='localstat' and '={v=t['..i..']}' or '.v=t['..i..']')
          else out[#out+1]=value(target.object)..'['..value(target.key)..']=t['..i..']' end
        end
        return link(table.concat(out,'; '),pc)
      end)
      for i=#evals,1,-1 do start=expression(evals[i][1],evals[i][2],start) end
      return start
    elseif k=='retstat' then return sequence(n.exp_list,function(tuple) return add('r.finish('..tuple..')') end)
    elseif k=='dostat' then return body(n,pc,breakpc,labels)
    elseif k=='breakstat' then return assert(breakpc)
    elseif k=='label' then blocks[labels[n.name]]='f.pc='..pc; return labels[n.name]
    elseif k=='gotostat' then return assert(labels[n.target_name],n.target_name)
    elseif k=='ifstat' then
      local otherwise=n.elseblock and body(n.elseblock,pc,breakpc,labels) or pc
      for i=#n.ifs,1,-1 do
        local branch=n.ifs[i]; local test=slot()
        otherwise=expression(branch.condition,test,add('f.pc='..value(test)..' and '..body(branch,pc,breakpc,labels)..' or '..otherwise))
      end
      return otherwise
    elseif k=='whilestat' or k=='repeatstat' then
      local head=reserve(); local test=slot()
      if k=='whilestat' then
        local loop=body(n,head,pc,labels)
        blocks[head]='f.pc='..expression(n.condition,test,add('f.pc='..value(test)..' and '..loop..' or '..pc))
        return head
      else
        local condition=expression(n.condition,test,add('f.pc='..value(test)..' and '..pc..' or '..head))
        blocks[head]='f.pc='..body(n,condition,pc,labels); return head
      end
    elseif k=='fornum' then
      local a,b,c=slot(),slot(),slot(); local head=reserve(); local id=cell(n.var)
      local advance=link(value(a)..'='..value(a)..'+'..value(c),head)
      local loop=body(n,advance,pc,labels)
      blocks[head]='if ('..value(c)..'>0 and '..value(a)..'<='..value(b)..') or ('..value(c)..'<=0 and '..value(a)..'>='..value(b)..') then f.l['..id..']={v='..value(a)..'}; f.pc='..loop..' else f.pc='..pc..' end'
      local start=n.step and expression(n.step,c,head) or assign(c,'1',head)
      return expression(n.start,a,expression(n.stop,b,start))
    elseif k=='forlist' then
      local a,b,c,t=slot(),slot(),slot(),slot(); local head=reserve()
      local loop=body(n,head,pc,labels)
      local writes={value(c)..'='..result(t)..'[1]'}
      for i,ref in ipairs(n.name_list) do writes[#writes+1]='f.l['..cell(ref)..']={v='..result(t)..'['..i..']}' end
      local test=add('if '..result(t)..'[1]~=nil then '..table.concat(writes,'; ')..'; f.pc='..loop..' else f.pc='..pc..' end')
      blocks[head]='r.call(f,'..value(a)..',{n=2,'..value(b)..','..value(c)..'},'..t..','..test..')'
      return sequence(n.exp_list,function(tuple) return link('local t='..tuple..'; '..value(a)..','..value(b)..','..value(c)..'=t[1],t[2],t[3]',head) end)
    end
    error('unsupported trusted statement '..tostring(k))
  end
  function func(fn)
    if ids[fn] then return ids[fn] end
    local id=#protos+1; ids[fn]=id; protos[id]=false
    local captures={}
    for _,ref in ipairs(fn.upvals) do if ref.name~='_ENV' then captures[#captures+1]=cell({reference_def=ref}) end end
    local params={}
    if fn.is_method then params[1]=cell({reference_def=fn.locals[1]}) end
    for _,ref in ipairs(fn.params) do params[#params+1]=cell(ref) end
    local entry=body(fn,add('r.finish({n=0})'))
    protos[id]='{entry='..entry..',params={'..table.concat(params,',')..'},captures={'..table.concat(captures,',')..'}}'
    return id
  end
  func(main)
  local out={'-- Generated by tools/compiler_build.py; trusted compiler only.','local B={}'}
  for i,code in ipairs(blocks) do out[#out+1]='B['..i..']=function(f,r) '..assert(code)..' end' end
  out[#out+1]='return {blocks=B,protos={'..table.concat(protos,',')..'}}'
  return table.concat(out,'\n')..'\n',#blocks,#protos
end
return M
