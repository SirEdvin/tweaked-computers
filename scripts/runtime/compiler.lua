local parse = require('vendor.phobos.parser')
local tokenize = require('vendor.phobos.tokenize')
local parser_errors = require('vendor.phobos.error_code_util')
local limits = require('scripts.runtime.limits')
local admission = require('scripts.runtime.admission')
local parsing = require('scripts.runtime.parse_admission')
local errors = require('scripts.runtime.errors')
local environment = require('scripts.runtime.environment')
local M = {}
-- Host-only, bounded, exact-source validation cache. No caller-owned plan or
-- executable closure is trusted. Replay every original charge, in order, so
-- warm/cold peers retain identical admission and partial-refusal behavior.
local cache,order={},{}
local function plan_copy(p)
  local names={}; for k,v in pairs(p.handlers) do names[k]=v end
  return {compiler_version=p.compiler_version,api_version=p.api_version,source=p.source,
    generated=p.generated,handlers=names,nodes=p.nodes,mode=p.mode}
end
local globals = {}
for _, name in ipairs({'assert','error','ipairs','pairs','next','pcall','select','tonumber','tostring','type',
  'print','rawget','rawset','rawlen','rawequal','xpcall','unpack','_VERSION',
  'math','string','table','colors','colours','computer','peripheral'}) do globals[name] = true end

local function position(node)
  if not node then return 1,1 end
  local tok=node.function_token or node.return_token or node.op_token or node.open_token or node.local_token
    or node.while_token or node.repeat_token or node.for_token or node.do_token or node.break_token
    or node.if_token or node.semi_colon_token
  if node.line or tok then return node.line or tok.line or 1,node.column or tok.column or 1 end
  return position((node.lhs and node.lhs[1]) or node.ex or node.name or (node.ifs and node.ifs[1]))
end
local function reject(node, message, code)
  local err = errors.new(code or 'E_PROGRAM', message)
  err.line, err.column = position(node)
  error(err, 0)
end
local function identifier(name, node)
  if type(name) ~= 'string' or #name > limits.identifier_bytes or name == '_ENV' or name == '_G' or name:sub(1,4) == '__tc' then
    reject(node, 'forbidden or oversized identifier')
  end
  return name
end
local function global(node)
  return node.node_type == 'index' and node.src_ex_did_not_exist
end

local forbidden={game=true,storage=true,script=true,remote=true,defines=true,settings=true,
  require=true,load=true,loadfile=true,dofile=true,debug=true,os=true,io=true,coroutine=true}
-- Declaration names cannot disguise either an approved API or an excluded
-- facility. Keep this separate from the Console's existing binding policy.
local declaration_reserved={print=true,rendering=true,loadstring=true,package=true,
  rawget=true,rawset=true,rawequal=true,rawlen=true,getmetatable=true,setmetatable=true,collectgarbage=true}
local function shell_name(name,node,write)
  identifier(name,node)
  if forbidden[name] or write and (globals[name] or name=='print') then reject(node,'unavailable shell global: '..name) end
  return name
end

local function validate(main,mode)
  local nodes,nesting=0,0
  local exports={}
  local expr,body,statement,func
  local function visit(n)
    parsing.enter(1)
    nodes,nesting=nodes+1,nesting+1
    if nodes>limits.source_nodes or nesting>limits.source_nesting then reject(n,'source AST limit exceeded','E_LIMIT') end
  end
  local function leave() nesting=nesting-1 end
  local function list(xs) for _,n in ipairs(xs or {}) do expr(n) end end
  function func(n)
    visit(n)
    if n.is_method then reject(n,'colon declarations are not supported') end
    for _,p in ipairs(n.params) do identifier(p.name,p) end
    body(n)
    leave()
  end
  function expr(n)
    visit(n)
    local k=n.node_type
    if k=='number' then
      if not errors.finite(n.value) then reject(n,'nonfinite numeric literal') end
    elseif k=='string' or k=='nil' or k=='boolean' or k=='vararg' then
    elseif k=='local_ref' or k=='upval_ref' then identifier(n.name,n)
    elseif k=='index' then
      if global(n) then
        local name=identifier(n.suffix.value,n.suffix)
        if mode=='shell' then shell_name(name,n.suffix,false)
        elseif not globals[name] and not exports[name] then reject(n.suffix,'unavailable global: '..name) end
      else expr(n.ex); expr(n.suffix) end
    elseif k=='call' then
      if n.is_selfcall then reject(n,'colon calls are not supported') end
      expr(n.ex); list(n.args)
    elseif k=='func_proto' then func(n.func_def)
    elseif k=='constructor' then
      for _,field in ipairs(n.fields) do
        if field.type=='list' then expr(field.value)
        elseif field.type=='rec' or field.type=='record' then expr(field.key); expr(field.value)
        else reject(n,'unsupported constructor field: '..tostring(field.type)) end
      end
    elseif k=='unop' then
      if n.op~='not' and n.op~='-' and n.op~='#' then reject(n,'unsupported unary operator') end
      expr(n.ex)
    elseif k=='binop' then
      if n.op~='and' and n.op~='or' and n.op~='+' and n.op~='-' and n.op~='*' and n.op~='/'
        and n.op~='%' and n.op~='^' and n.op~='==' and n.op~='~=' and n.op~='<' and n.op~='>'
        and n.op~='<=' and n.op~='>=' then reject(n,'unsupported binary operator') end
      expr(n.left); expr(n.right)
    elseif k=='concat' then list(n.exp_list)
    else reject(n,'unsupported expression: '..tostring(k)) end
    leave()
  end
  local function target(lhs)
    if lhs.node_type=='local_ref' or lhs.node_type=='upval_ref' then identifier(lhs.name,lhs)
    elseif mode=='shell' and global(lhs) then shell_name(lhs.suffix.value,lhs.suffix,true)
    elseif lhs.node_type=='index' and not global(lhs) then expr(lhs.ex); expr(lhs.suffix)
    else reject(lhs,'global assignment is forbidden') end
  end
  function statement(n)
    visit(n)
    local k=n.node_type
    if k=='empty' or k=='breakstat' then
    elseif k=='localstat' then
      for _,p in ipairs(n.lhs) do identifier(p.name,p) end
      list(n.rhs)
    elseif k=='localfunc' then identifier(n.name.name,n.name); func(n.func_def)
    elseif k=='funcstat' then target(n.name); func(n.func_def)
    elseif k=='assignment' then
      for _,lhs in ipairs(n.lhs) do target(lhs) end
      list(n.rhs)
    elseif k=='call' then expr(n)
    elseif k=='retstat' then list(n.exp_list)
    elseif k=='dostat' then body(n)
    elseif k=='whilestat' then expr(n.condition); body(n)
    elseif k=='repeatstat' then body(n); expr(n.condition)
    elseif k=='fornum' then
      identifier(n.var.name,n.var); expr(n.start); expr(n.stop)
      if n.step then expr(n.step) end
      body(n)
    elseif k=='forlist' then
      for _,p in ipairs(n.name_list) do identifier(p.name,p) end
      list(n.exp_list); body(n)
    elseif k=='ifstat' then
      for _,branch in ipairs(n.ifs) do expr(branch.condition); body(branch) end
      if n.elseblock then body(n.elseblock) end
    else reject(n,'unsupported statement: '..tostring(k)) end
    leave()
  end
  function body(scope)
    local stat=scope.body.first
    while stat do statement(stat); stat=stat.next end
  end
  if mode=='shell' then body(main); return exports,nodes end
  -- Discover exports without changing lexical order or consuming native locals.
  local seen,count={},0
  local stat=main.body.first
  while stat do
    parsing.enter(1)
    local kind=stat.node_type
    if kind~='empty' then
      local node
      if kind=='funcstat' and global(stat.name) and not stat.func_def.is_method then node=stat.name.suffix
      elseif kind=='localfunc' then node=stat.name
      else reject(stat,'declaration document permits only simple function declarations') end
      local name=identifier(node.value or node.name,node)
      parsing.enter(#name+1)
      if globals[name] or forbidden[name] or declaration_reserved[name] then reject(node,'reserved declaration name: '..name) end
      if seen[name] then reject(node,'duplicate declaration name: '..name) end
      seen[name]=true
      if kind=='funcstat' then
        count=count+1; exports[name]=true
        if count>limits.handler_names then reject(node,'handler count exceeded','E_LIMIT') end
      end
    end
    stat=stat.next
  end
  if count==0 then reject(main.body.first,'exported function required') end
  stat=main.body.first
  while stat do
    if stat.node_type=='funcstat' then visit(stat); func(stat.func_def); leave()
    else statement(stat) end
    stat=stat.next
  end
  return exports,nodes
end

local function native_source(source,expression)
  if source:sub(1,3)=='\239\187\191' then source=source:sub(4) end
  if source:sub(1,1)=='#' then source=source:gsub('^[^\n]*','') end
  return expression and 'return '..source or source
end

function M.compile(source, context, mode)
  if mode~=nil and mode~='shell' then return nil,errors.new('E_ARGUMENT','unknown compiler mode') end
  if type(source) ~= 'string' then return nil, errors.new('E_ARGUMENT','source must be a string') end
  if #source > limits.source_bytes then return nil, errors.new('E_LIMIT','source byte limit exceeded') end
  local cache_key=(mode or 'program')..'\0'..source
  local retained=cache[cache_key]; local charges=not retained and {} or nil
  local expression_source=false
  parsing.begin(context,charges)
  local ok, plan = pcall(function()
    if retained then
      if context and not admission.replay_compile(context,retained.charges) then
        errors.raise('E_BUDGET','source compilation work exhausted')
      end
      return plan_copy(retained.plan)
    end
    parsing.enter(#source * 2 + 1)
    -- The bounded pinned tokenizer also validates identifiers before AST parsing.
    local iter,state,index = tokenize(source,'@computer')
    local count = 0
    while true do
      local tok; index,tok = iter(state,index)
      if not tok or tok.token_type == 'eof' then break end
      count = count + 1
      if count > limits.source_tokens then reject(tok,'source token limit exceeded','E_LIMIT') end
      if tok.token_type == 'ident' then identifier(tok.value,tok) end
    end
    local main, diagnostics, expression
    if mode=='shell' then
      main,diagnostics=parse('return '..source,'@computer')
      expression=#diagnostics==0
      if not expression then main,diagnostics=parse(source,'@computer') end
    else main,diagnostics=parse(source,'@computer') end
    if #diagnostics > 0 then
      local d = diagnostics[1]
      local e = errors.new('E_PROGRAM',parser_errors.get_message(d))
      -- Phobos's synthetic EOF token has no coordinates. Reuse the already
      -- admitted original tokenizer's final position, not the expression prefix.
      e.line = d.start_position and d.start_position.line or state.line
      e.column = d.start_position and d.start_position.column or #source+1-state.line_offset
      error(e,0)
    end
    expression_source=expression==true
    local names,nodes=validate(main,mode)
    parsing.enter(#source+(expression and 7 or 0))
    local generated=native_source(source,expression)
    -- Syntax verification does not execute the declaration document or command.
    local factory, diagnostic = load(generated,'@computer','t',{})
    if not factory then
      local problem=errors.new('E_PROGRAM','native syntax: '..diagnostic:gsub('computer:%d+: ',''))
      problem.line=tonumber(diagnostic:match('computer:(%d+):')) or 1
      problem.column=1
      error(problem,0)
    end
    return {compiler_version=limits.compiler_version, api_version=1, source=source,
      generated=generated, handlers=names, nodes=nodes,mode=mode}
  end)
  parsing.finish()
  if not ok then
    if type(plan) ~= 'table' then plan = errors.new('E_PROGRAM',tostring(plan)) end
    if expression_source and plan.line==1 and type(plan.column)=='number' then plan.column=math.max(1,plan.column-7) end
    return nil,plan
  end
  if charges and not charges.overflow then
    if #order>=8 then cache[table.remove(order,1)]=nil end
    cache[cache_key]={plan=plan_copy(plan),charges=charges}; order[#order+1]=cache_key
  end
  return plan
end

function M.same_handlers(left,right)
  if type(left)~='table' or getmetatable(left) then return false end
  for name,value in pairs(left) do if value~=true or right[name]~=true then return false end end
  for name in pairs(right) do if left[name]~=true then return false end end
  return true
end
function M.run(plan, name, event, services, context, circuit, before)
  if type(plan) ~= 'table' or plan.mode~=nil or plan.compiler_version ~= limits.compiler_version or plan.api_version ~= 1 then
    return false,errors.new('E_PROGRAM','unsupported compiler/API version; source retained')
  end
  if before then admission.begin_preparation(context) end
  local function failure(problem,control)
    if before and admission.finish_preparation(context) then control='defer' end
    return false,problem,control
  end
  -- Revalidate or replay the private exact-source proof every dispatch, retaining
  -- identical cold/warm credits. Saved/caller-generated text is never executed.
  local executable,diagnostic = M.compile(plan.source,context)
  if not executable then return failure(diagnostic) end
  if plan.storage_version~=nil and not M.same_handlers(plan.handlers,executable.handlers) then
    return failure(errors.new('E_UNSUPPORTED','invalid retained exports; source/data retained'))
  end
  if not executable.handlers[name] then return failure(errors.new('E_NOT_FOUND','handler not declared')) end
  -- Same admission for every fresh environment, regardless of executable cache/process history.
  if not admission.reserve(context,'compile',#executable.generated + executable.nodes + 1) then
    return failure(errors.new('E_BUDGET','handler reconstruction refused'))
  end
  local env=environment.new(context,services)
  local ok,result = pcall(function()
    env.initialize()
    local factory, diagnostic = load(executable.generated,'@computer','t',env.globals)
    if not factory then errors.raise('E_PROGRAM',diagnostic) end
    local handlers=env.construct(factory,executable.handlers)
    local input=circuit and event or env.snapshot(event)
    if before then before(input,env); admission.finish_preparation(context) end
    return env.execute(handlers[name],input)
  end)
  env.close()
  if not ok then return failure(env.diagnostic(result),env.stop_requested() and 'stop' or nil) end
  return true
end
return M
