local parse = require('vendor.phobos.parser')
local tokenize = require('vendor.phobos.tokenize')
local limits = require('scripts.runtime.limits')
local admission = require('scripts.runtime.admission')
local parsing = require('scripts.runtime.parse_admission')
local errors = require('scripts.runtime.errors')
local sandbox = require('scripts.runtime.sandbox')
local M = {}
local globals = {}
for _, name in ipairs({'assert','error','ipairs','pairs','next','pcall','select','tonumber','tostring','type',
  'math','string','table','colors','colours','computer','peripheral'}) do globals[name] = true end

local function position(node)
  if not node then return 1,1 end
  local tok=node.function_token or node.return_token or node.op_token or node.open_token or node.local_token
    or node.while_token or node.repeat_token or node.for_token or node.do_token or node.break_token
    or node.if_token or node.semi_colon_token
  if node.line or tok then return node.line or tok.line or 1,node.column or tok.column or 1 end
  return position((node.lhs and node.lhs[1]) or node.ex or node.name or (node.ifs and node.ifs[1]))
end

local function coordinates(node) local line,column=position(node); return line..','..column end
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

local function emit(main)
  local nodes, nesting, generated, temp = 0, 0, 0, 0
  local expr, body, statement, func
  local function visit(n)
    parsing.enter(1)
    nodes, nesting = nodes + 1, nesting + 1
    if nodes > limits.source_nodes or nesting > limits.source_nesting then reject(n, 'source AST limit exceeded', 'E_LIMIT') end
  end
  local function leave(text)
    nesting = nesting - 1
    return text
  end
  local function text(s)
    parsing.enter(#s)
    generated = generated + #s
    if generated > limits.generated_source_bytes then reject(nil, 'generated text limit exceeded', 'E_LIMIT') end
    return s
  end
  local function list(xs)
    if #xs > limits.tuple_entries then reject(xs[1], 'tuple width exceeded', 'E_LIMIT') end
    local out = {}
    for i,n in ipairs(xs) do out[i] = expr(n) end
    return table.concat(out, ',')
  end
  function func(n)
    visit(n)
    if n.is_method then reject(n, 'colon declarations are not supported') end
    local names = {}
    for i,p in ipairs(n.params) do names[i] = identifier(p.name,p) end
    if #names > limits.tuple_entries then reject(n, 'parameter width exceeded', 'E_LIMIT') end
    if n.is_vararg then names[#names+1] = '...' end
    local result = 'function('..table.concat(names, ',')..') __tc.enter('..coordinates(n)..','..#n.params..'); '..body(n)..' end'
    return leave(result)
  end
  function expr(n)
    visit(n)
    local k, s = n.node_type
    if k == 'number' then
      if not errors.finite(n.value) then reject(n, 'nonfinite numeric literal') end
      s = n.src_value or tostring(n.value)
    elseif k == 'string' then s = string.format('%q', n.value)
    elseif k == 'nil' then s = 'nil'
    elseif k == 'boolean' then s = tostring(n.value)
    elseif k == 'local_ref' or k == 'upval_ref' then s = identifier(n.name,n)
    elseif k == 'vararg' then s = '__tc.values(...)'
    elseif k == 'index' then
      if global(n) then
        local name = identifier(n.suffix.value,n.suffix)
        if not globals[name] then reject(n.suffix, 'unavailable global: '..name) end
        s = '__tc.global('..string.format('%q',name)..')'
      else s = '__tc.get('..expr(n.ex)..','..expr(n.suffix)..')' end
    elseif k == 'call' then
      if n.is_selfcall then reject(n, 'colon calls are not supported') end
      s = '__tc.call('..expr(n.ex)..(#n.args > 0 and ','..list(n.args) or '')..')'
    elseif k == 'func_proto' then s = '__tc.closure('..func(n.func_def)..')'
    elseif k == 'constructor' then
      if #n.fields > limits.table_entries then reject(n, 'table width exceeded','E_LIMIT') end
      local out = {}
      for i,f in ipairs(n.fields) do
        if f.type == 'list' then out[i] = expr(f.value)
        elseif f.type == 'rec' or f.type == 'record' then out[i] = '['..expr(f.key)..']='..expr(f.value)
        else reject(n, 'unsupported constructor field: '..tostring(f.type)) end
      end
      s = '__tc.new('..#n.fields..',function() return {'..table.concat(out,',')..'} end)'
    elseif k == 'unop' then
      if n.op == 'not' then s = '(not __tc.scalar('..expr(n.ex)..'))'
      elseif n.op == '-' then s = '(-__tc.number('..expr(n.ex)..'))'
      elseif n.op == '#' then s = '__tc.length('..expr(n.ex)..')'
      else reject(n,'unsupported unary operator') end
    elseif k == 'binop' then
      if n.op == 'and' or n.op == 'or' then
        s = '(__tc.scalar('..expr(n.left)..') '..n.op..' '..expr(n.right)..')'
      elseif n.op == '+' or n.op == '-' or n.op == '*' or n.op == '/' or n.op == '%' or n.op == '^' then
        s = '(__tc.number('..expr(n.left)..') '..n.op..' __tc.number('..expr(n.right)..'))'
      elseif n.op == '==' or n.op == '~=' or n.op == '<' or n.op == '>' or n.op == '<=' or n.op == '>=' then
        s = '(__tc.scalar('..expr(n.left)..') '..n.op..' __tc.scalar('..expr(n.right)..'))'
      else reject(n,'unsupported binary operator') end
    elseif k == 'concat' then
      -- Primitive operands only: no metatable dispatch. Bound complete output before native concat.
      s = '__tc.concat('..list(n.exp_list)..')'
    else reject(n, 'unsupported expression: '..tostring(k)) end
    if n.force_single_result then s = '('..s..')' end
    return leave(text(s))
  end
  function body(scope)
    local out, stat = {}, scope.body.first
    while stat do out[#out+1] = statement(stat); stat = stat.next end
    return table.concat(out, '\n')
  end
  function statement(n)
    visit(n)
    local k, s = n.node_type
    if k == 'empty' then s = ';'
    elseif k == 'localstat' then
      local names = {}; for i,p in ipairs(n.lhs) do names[i] = identifier(p.name,p) end
      if #names>limits.tuple_entries then reject(n,'local width exceeded','E_LIMIT') end
      s = 'local '..table.concat(names,',')..' = __tc.bind('..#names..(n.rhs and #n.rhs > 0 and ','..list(n.rhs) or '')..');'
    elseif k == 'localfunc' then
      local name = identifier(n.name.name,n.name)
      s = 'local '..name..'; '..name..'=__tc.closure('..func(n.func_def)..');'
    elseif k == 'funcstat' then
      -- Desugar through the same fully preflighted assignment path.
      s = statement({node_type='assignment', lhs={n.name}, rhs={{node_type='func_proto',func_def=n.func_def}}})
    elseif k == 'assignment' then
      if #n.lhs > limits.tuple_entries then reject(n,'assignment width exceeded','E_LIMIT') end
      temp = temp + 1
      local prefix = '__tc_a'..temp..'_'
      local count=#n.lhs
      local indexed=0
      local out,targets={'do', 'local '..prefix..'targets=__tc.assignment_targets('..count..');'},{}
      for i,lhs in ipairs(n.lhs) do
        if lhs.node_type == 'local_ref' or lhs.node_type == 'upval_ref' then targets[i] = identifier(lhs.name,lhs)
        elseif lhs.node_type == 'index' and not global(lhs) then
          indexed=indexed+1
          out[#out+1] = prefix..'targets['..i..']={'..expr(lhs.ex)..','..expr(lhs.suffix)..'};'
          targets[i] = prefix..'targets['..i..'][1]['..prefix..'targets['..i..'][2]]'
        else reject(lhs, 'global assignment is forbidden') end
      end
      local rhs=#n.rhs>0 and ','..list(n.rhs) or ''
      out[#out+1] = 'local '..prefix..'values=__tc.assignment_values('..count..rhs..');'
      out[#out+1] = '__tc.assignment_check('..count..','..prefix..'targets,'..prefix..'values);'
      -- Two bounded private vectors avoid multiplying the native local/register
      -- count by tuple width. Publish statically emitted native writes in Lua
      -- 5.2's right-to-left order, after all target/RHS evaluations and checks.
      for i=count,1,-1 do out[#out+1]=targets[i]..'='..prefix..'values['..i..'];' end
      out[#out+1]='end'
      if indexed==0 then
        -- Plain lexical writes need no heap staging or private native locals.
        s=table.concat(targets,',')..'=__tc.move('..count..rhs..');'
      else s = table.concat(out, '\n') end
    elseif k == 'call' then s = expr(n)..';'
    elseif k == 'retstat' then s = 'do return __tc.values('..list(n.exp_list)..') end'
    elseif k == 'breakstat' then s = 'do break end'
    elseif k == 'dostat' then s = 'do '..body(n)..' end'
    elseif k == 'whilestat' then s = 'while '..expr(n.condition)..' do __tc.step('..coordinates(n.while_token)..'); '..body(n)..' end'
    elseif k == 'repeatstat' then s = 'repeat __tc.step('..coordinates(n.repeat_token)..'); '..body(n)..' until '..expr(n.condition)
    elseif k == 'fornum' then
      s = 'for '..identifier(n.var.name,n.var)..' = __tc.number('..expr(n.start)..'),__tc.number('..expr(n.stop)..'),__tc.number('..(n.step and expr(n.step) or '1')..') do __tc.loop('..coordinates(n.for_token)..',1); '..body(n)..' end'
    elseif k == 'forlist' then
      local names = {}; for i,p in ipairs(n.name_list) do names[i] = identifier(p.name,p) end
      if #names>limits.tuple_entries then reject(n,'iterator width exceeded','E_LIMIT') end
      s = 'for '..table.concat(names,',')..' in __tc.iter('..list(n.exp_list)..') do __tc.loop('..coordinates(n.for_token)..','..#names..'); '..body(n)..' end'
    elseif k == 'ifstat' then
      local out = {}
      for i,b in ipairs(n.ifs) do out[#out+1] = (i == 1 and 'if ' or 'elseif ')..expr(b.condition)..' then '..body(b) end
      if n.elseblock then out[#out+1] = 'else '..body(n.elseblock) end
      out[#out+1] = 'end'; s = table.concat(out,'\n')
    else reject(n,'unsupported statement: '..tostring(k)) end
    return leave(text('__tc.step('..coordinates(n)..'); '..s))
  end
  local ret, stat = nil, main.body.first
  while stat do
    if stat.node_type ~= 'empty' then
      if ret or stat.node_type ~= 'retstat' then reject(stat,'document must only return a literal descriptor') end
      ret = stat
    end
    stat = stat.next
  end
  if not ret or #ret.exp_list ~= 1 or ret.exp_list[1].node_type ~= 'constructor' then reject(ret,'literal descriptor required') end
  local descriptor, seen = {}, {}
  for _,f in ipairs(ret.exp_list[1].fields) do
    if f.type == 'list' or f.key.node_type ~= 'string' or seen[f.key.value] then reject(ret,'invalid or duplicate descriptor key') end
    seen[f.key.value] = true; descriptor[f.key.value] = f.value
  end
  local count = 0
  for name in pairs(seen) do
    count = count + 1
    if name ~= 'api_version' and name ~= 'handlers' then reject(ret,'unknown descriptor key') end
  end
  if count ~= 2 or not seen.api_version or not seen.handlers then reject(ret,'descriptor requires api_version and handlers') end
  if descriptor.api_version.node_type ~= 'number' or descriptor.api_version.value ~= 1 then reject(ret,'unsupported api_version') end
  if descriptor.handlers.node_type ~= 'constructor' then reject(ret,'literal handlers required') end
  local handlers, names = {}, {}
  for _,f in ipairs(descriptor.handlers.fields) do
    if f.type == 'list' or f.key.node_type ~= 'string' or f.value.node_type ~= 'func_proto' then reject(ret,'literal named function handler required') end
    local name = identifier(f.key.value, f.key)
    if not name:match('^[a-zA-Z_][a-zA-Z_0-9]*$') or names[name] then reject(f.key,'invalid or duplicate handler name') end
    names[name] = true
    handlers[#handlers+1] = '['..string.format('%q',name)..']='..func(f.value.func_def)
    if #handlers > limits.handler_names then reject(ret,'handler count exceeded','E_LIMIT') end
  end
  local output = 'return {'..table.concat(handlers,',\n')..'}'
  if #output > limits.generated_source_bytes then reject(ret,'generated source too large','E_LIMIT') end
  parsing.enter(#output)
  return output, names, nodes
end

function M.compile(source, context)
  if type(source) ~= 'string' then return nil, errors.new('E_ARGUMENT','source must be a string') end
  if #source > limits.source_bytes then return nil, errors.new('E_LIMIT','source byte limit exceeded') end
  parsing.begin(context)
  local ok, plan = pcall(function()
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
    local main, diagnostics = parse(source,'@computer')
    if #diagnostics > 0 then
      local d = diagnostics[1]
      local e = errors.new('E_PROGRAM',d.location_str or 'invalid Lua syntax')
      e.line,e.column = d.start_position and d.start_position.line or 1,d.start_position and d.start_position.column or 1
      error(e,0)
    end
    local generated,names,nodes = emit(main)
    -- Native load here is only syntax verification of bounded, emitted text; no candidate code runs.
    local factory, diagnostic = load(generated,'@computer','t',{})
    if not factory then errors.raise('E_PROGRAM','generated source: '..diagnostic) end
    return {compiler_version=limits.compiler_version, api_version=1, source=source,
      generated=generated, handlers=names, nodes=nodes}
  end)
  parsing.finish()
  if not ok then
    if type(plan) ~= 'table' then plan = errors.new('E_PROGRAM',tostring(plan)) end
    return nil,plan
  end
  return plan
end

function M.run(plan, name, event, services, context)
  if type(plan) ~= 'table' or plan.compiler_version ~= limits.compiler_version or plan.api_version ~= 1 then
    return false,errors.new('E_PROGRAM','unsupported compiler/API version; source retained')
  end
  -- Revalidate exact retained source every dispatch. This deliberately cache-free
  -- foundation has identical cold/warm and partially-exhausted admission, and
  -- never trusts generated text supplied by a saved/corrupt caller-owned plan.
  local executable,diagnostic = M.compile(plan.source,context)
  if not executable then return false,diagnostic end
  if not executable.handlers[name] then return false,errors.new('E_NOT_FOUND','handler not declared') end
  -- Same admission for every fresh environment, regardless of executable cache/process history.
  if not admission.reserve(context,'compile',#executable.generated + executable.nodes + 1) then
    return false,errors.new('E_BUDGET','handler reconstruction refused')
  end
  local guard = sandbox.new(context,services)
  local ok,result = pcall(function()
    guard.initialize()
    local factory, diagnostic = load(executable.generated,'@computer','t',{__tc=guard})
    if not factory then errors.raise('E_PROGRAM',diagnostic) end
    guard.step(1)
    local count = 0
    for _ in pairs(executable.handlers) do count = count + 1 end
    guard.prepare_descriptor(count)
    local handlers = factory()
    return guard.call(handlers[name],guard.snapshot(event))
  end)
  if not ok then return false,guard.diagnostic(result),guard.stop_requested() and 'stop' or nil end
  return true
end
return M
