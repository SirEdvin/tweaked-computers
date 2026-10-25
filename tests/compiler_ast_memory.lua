local nodes=require('vendor.phobos.nodes')
local ill=require('vendor.phobos.indexed_linked_list')
local parsing=require('scripts.runtime.parse_admission')
local admission=require('scripts.runtime.admission')
local memory=require('scripts.runtime.memory')
local limits=require('scripts.runtime.limits')
local M={}
local function inputs(value,seen)
  if type(value)~='table' or seen[value] then return end
  seen[value]=true
  for key,child in pairs(value) do inputs(key,seen); inputs(child,seen) end
end
local function graph_bytes(value,seen)
  if type(value)~='table' or seen[value] then return 0 end
  seen[value]=true
  local bytes=192
  for key,child in pairs(value) do bytes=bytes+48+graph_bytes(key,seen)+graph_bytes(child,seen) end
  return bytes
end
function M.run()
  local expression={node_type='number',value=1}
  local cases={
    {'env_scope',{main={}}}, {'functiondef',{source='@ast'}},
    {'invalid',{error_code_inst={}}}, {'empty',{}}, {'ifstat',{}},
    {'testblock',{condition=expression}}, {'elseblock',{}},
    {'whilestat',{condition=expression}}, {'dostat',{}},
    {'fornum',{var=expression,start=expression,stop=expression}},
    {'forlist',{exp_list={expression}}}, {'repeatstat',{condition=expression}},
    {'funcstat',{func_def={},name=expression}}, {'localstat',{}},
    {'localfunc',{func_def={},name=expression}}, {'label',{name='label'}},
    {'retstat',{}}, {'breakstat',{}}, {'gotostat',{target_name='label'}},
    {'call',{ex=expression}}, {'assignment',{}}, {'loopstat',{}},
    {'local_ref',{name='local',reference_def={def_type='local'},position={line=2,column=3,leading={}}}},
    {'upval_ref',{name='upval',reference_def={def_type='upval'}}},
    {'index',{ex=expression,suffix=expression}}, {'unop',{op='-',ex=expression}},
    {'binop',{op='+',left=expression,right=expression}}, {'concat',{exp_list={expression}}},
    {'number',{value=0}}, {'string',{value=''}}, {'nil',{}}, {'boolean',{value=false}},
    {'vararg',{}}, {'func_proto',{func_def={}}}, {'constructor',{}},
  }
  for _,kind in ipairs({'blank','comment','string','number','ident','invalid','eof','+'}) do
    cases[#cases+1]={'token',{token_type=kind,value=kind=='number' and 0 or '',
      src_quote='"',src_value='',line=2,column=3}}
  end
  for _,kind in ipairs({'comment','string'}) do
    cases[#cases+1]={'token',{token_type=kind,value='',src_is_block_str=true,
      src_has_leading_newline=false,src_pad='',leading={}}}
  end
  -- Optional slots and aliases must be covered as well as empty defaults.
  local full={body={count=0,lookup={},scope={}},parent_scope={},child_scopes={},locals={},labels={},
    linked_breaks={},func_protos={},upvals={},params={},ifs={},linked_gotos={},exp_list={expression},
    name_list={},lhs={},rhs={},args={},fields={},consumed_nodes={},error_code_insts={},
    force_single_result=true,src_paren_wrappers={},concat_src_paren_wrappers={},
    is_method=true,is_vararg=true,is_main=true,is_selfcall=true,suffix=expression,step=expression,
    do_jump_back=true,src_ex_did_not_exist=true,src_is_ident=true,src_is_block_str=false,
    src_quote='"',src_value='',src_has_leading_newline=false,src_pad='',
    linked_loop={},linked_label={},elseblock={},position={line=2,column=3,leading={}},leading={}}
  for _,field in ipairs({'param_comma','vararg','open_paren','close_paren','function','end','eof',
    'semi_colon','if','then','else','while','do','for','eq','first_comma','second_comma','in',
    'repeat','until','local','name','open','close','return','break','target','goto','colon',
    'dot','suffix_open','suffix_close','op'}) do full[field..'_token']={} end
  for _,field in ipairs({'exp_list_comma','comma','lhs_comma','rhs_comma','args_comma','op'}) do
    full[field..'_tokens']={}
  end
  local defaults=#cases
  for i=1,defaults do
    local params={}
    for key,value in pairs(full) do params[key]=value end
    for key,value in pairs(cases[i][2]) do params[key]=value end
    cases[#cases+1]={cases[i][1],params}
  end
  local reserve=memory.reserve
  local charges,ctx,account
  memory.reserve=function(owner,bytes)
    if charges then charges[#charges+1]={used=account.used+account.reserved,bytes=bytes,work=ctx.machine.compile} end
    return reserve(owner,bytes)
  end
  local total=0
  local ok,problem=pcall(function()
    for _,case in ipairs(cases) do
      local fn=assert(nodes['new_'..case[1]])
      account=memory.new(limits.host_memory_bytes,0,'host_memory')
      local owner=memory.owner(account)
      ctx=admission.context(admission.new(),'ast-constructor',0)
      local seen={}; inputs(case[2],seen)
      charges={}; parsing.begin(ctx); parsing.attach(owner)
      local node=fn(case[2])
      parsing.finish()
      assert(owner.reserved>=graph_bytes(node,seen),'AST constructor allocated an unadmitted graph: '..case[1])
      if case[1]=='token' then
        local p=case[2]
        assert(node.token_type==p.token_type and node.line==p.line and node.column==p.column)
        if p.token_type=='eof' or p.token_type=='+' then assert(node.value==nil)
        else assert(node.value==p.value) end
        if p.token_type=='comment' or p.token_type=='string' then
          assert(node.src_is_block_str==(p.src_is_block_str or false))
          if p.src_is_block_str then
            assert(node.src_pad==p.src_pad and node.src_has_leading_newline==p.src_has_leading_newline)
          elseif p.token_type=='string' then
            assert(node.src_quote==p.src_quote and node.src_value==p.src_value)
          else assert(node.src_quote==nil and node.src_value==nil) end
        end
        if p.token_type=='invalid' then assert(type(node.error_code_insts)=='table') end
      end
      local recorded=charges; charges=nil
      memory.close(owner,function() end)
      assert(account.used==256 and account.reserved==0)
      for _,charge in ipairs(recorded) do
        total=total+1
        account=memory.new(charge.used+charge.bytes-1,0,'host_memory')
        owner=memory.owner(account)
        ctx=admission.context(admission.new(),'ast-refusal',0)
        parsing.begin(ctx); parsing.attach(owner)
        local admitted,e=pcall(fn,case[2]); parsing.finish()
        assert(not admitted and e.recoverable and e.resource=='host_memory'
          and e.used==charge.used and e.requested==charge.bytes and ctx.machine.compile==charge.work,
          'AST constructor crossed a refused allocation: '..case[1])
        memory.close(owner,function() end)
        assert(account.used==256 and account.reserved==0)
      end
    end
    -- Position updates must admit all new slots before mutating an existing node.
    account=memory.new(256+128+3*48-1,0,'host_memory')
    local owner=memory.owner(account)
    ctx=admission.context(admission.new(),'ast-position',0)
    parsing.begin(ctx); parsing.attach(owner)
    local node={}; local position={line=2,column=3,leading={}}
    local admitted,e=pcall(nodes.set_position,node,position); parsing.finish()
    assert(not admitted and e.recoverable and next(node)==nil,'AST position mutated before complete admission')
    memory.close(owner,function() end)
    -- A failed parse discards the complete private list, including paid prefixes.
    local function list_sequence(check)
      local list=ill.new()
      for _=1,5 do ill.append(list) end
      ill.prepend(list)
      local middle=list.first.next.next
      local reindexes=0
      for i=1,128 do
        local lookup=list.lookup
        if i%2==0 then ill.insert_before(list,middle) else ill.insert_after(list,middle) end
        if lookup~=list.lookup then reindexes=reindexes+1 end
      end
      if check then
        assert(reindexes>0,'linked-list probe did not reach lookup reconstruction')
        local n,previous=0,nil
        local node=list.first
        while node do
          n=n+1
          assert(node.list==list and node.prev==previous and list.lookup[node.index]==node)
          assert(not previous or previous.index<node.index)
          previous=node; node=node.next
        end
        assert(n==list.count and previous==list.last and owner.reserved>=graph_bytes(list,{}))
      end
      ill.remove(list,middle)
      ill.clear(list)
      assert(list.count==0 and not list.first and not list.last and next(list.lookup)==nil)
    end
    account=memory.new(limits.host_memory_bytes,0,'host_memory'); owner=memory.owner(account)
    ctx=admission.context(admission.new(),'ast-list',0)
    charges={}; parsing.begin(ctx); parsing.attach(owner)
    list_sequence(true); parsing.finish()
    local recorded=charges; charges=nil
    memory.close(owner,function() end)
    for _,charge in ipairs(recorded) do
      account=memory.new(charge.used+charge.bytes-1,0,'host_memory'); owner=memory.owner(account)
      ctx=admission.context(admission.new(),'ast-list-refusal',0)
      parsing.begin(ctx); parsing.attach(owner)
      local admitted,e=pcall(list_sequence,false); parsing.finish()
      assert(not admitted and e.recoverable and e.resource=='host_memory'
        and e.used==charge.used and e.requested==charge.bytes and ctx.machine.compile==charge.work,
        'linked list crossed a refused allocation')
      memory.close(owner,function() end)
      assert(account.used==256 and account.reserved==0)
    end
    log('TC_AST_LIST_MEMORY boundaries='..#recorded)
    log('TC_AST_MEMORY cases='..#cases..' boundaries='..total)
  end)
  parsing.finish(); memory.reserve=reserve
  assert(ok,type(problem)=='table' and problem.message or tostring(problem))
  log('TC_CONTRACT ast-constructor-graphs-and-every-one-byte-short-boundary')
end
return M
