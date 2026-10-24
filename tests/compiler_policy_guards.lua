local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local parsing=require('scripts.runtime.parse_admission')
local tokenize=require('vendor.phobos.tokenize')
local continuation=require('scripts.runtime.continuation')
local M={}
function M.run()
  -- Durable validation must traverse the language without emitting a discarded backend.
  local format,concat,lower=string.format,table.concat,continuation.lower
  local validating,formats,joins=false,0,0
  string.format=function(pattern,...) if validating and pattern=='%q' then formats=formats+1 end; return format(pattern,...) end
  table.concat=function(...)
    local result=concat(...)
    if validating and result:find('__tc',1,true) then joins=joins+1 end
    return result
  end
  continuation.lower=function(...) validating=false; return lower(...) end
  local checked,problem=pcall(function()
    local body='local t={value="'..string.rep('literal',2000)..'"}; t.value=t.value.."!"; return t.value'
    for i,text in ipairs({'function validate_only() '..body..' end',
      'return {api_version=1,handlers={validate_only=function() '..body..' end}}',body}) do
      validating=true
      local plan,reason=compiler.prepare(text,admission.context(admission.new(),'validation-only-'..i,0),i==3 and 'shell' or nil)
      assert(not validating,'fixture did not reach durable lowering')
      validating=false
      assert(plan,reason and reason.message)
      assert(formats==0 and joins==0,'validation emitted discarded native source')
    end
  end)
  string.format,table.concat,continuation.lower=format,concat,lower
  assert(checked,type(problem)=='table' and problem.message or tostring(problem))
  local invalid={
    'local x=1; function start() end', 'function start() end; function start() end',
    'function computer() end', 'function obj:method() end',
    'return {api_version=1,handlers={},extra=true}',
    'return {api_version=1,api_version=1,handlers={}}',
    'return {api_version=2,handlers={}}', 'return {api_version=1,handlers={start=1}}',
    'return {api_version=1,handlers={["bad-name"]=function() end}}'
  }
  for _,body in ipairs({'return game.tick','local _ENV={}','return __tc_guard',
    'return getmetatable({})','local t={}; return t:method()',
    'escaped=1','return 1e999','goto label; ::label::'}) do
    invalid[#invalid+1]='function start() '..body..' end'
    invalid[#invalid+1]='return {api_version=1,handlers={start=function() '..body..' end}}'
  end
  for i,text in ipairs(invalid) do
    local legacy,expected=compiler.compile(text,admission.context(admission.new(),'invalid-legacy-'..i,0))
    local durable,actual=compiler.prepare(text,admission.context(admission.new(),'invalid-durable-'..i,0))
    assert(not legacy and not durable and actual.code==expected.code and actual.message==expected.message
      and actual.line==expected.line and actual.column==expected.column,'durable validation changed a source diagnostic: '..text)
  end
  for _,text in ipairs({'game.tick','computer=1','return require("x")','local t={}; t:method()'}) do
    local legacy,expected=compiler.compile(text,admission.context(admission.new(),'invalid-shell-legacy',0),'shell')
    local durable,actual=compiler.prepare(text,admission.context(admission.new(),'invalid-shell-durable',0),'shell')
    assert(not legacy and not durable and actual.code==expected.code and actual.message==expected.message
      and actual.line==expected.line and actual.column==expected.column,'durable shell validation changed a source diagnostic')
  end
  for _,key in ipairs({'generated_source_bytes','source_nodes','source_tokens','source_nesting','handler_names'}) do
    assert(limits[key]==nil,'obsolete compiler quota still advertised: '..key)
  end
  local name=string.rep('long_identifier_',16)
  local source='function '..name..'() local '..name..'_value=1; assert('..name..'_value==1) end'
  local plan,e=compiler.compile(source,admission.context(admission.new(),'long-name',1))
  assert(plan and plan.handlers[name],e and e.message)
  local ok,problem=compiler.run(plan,name,{}, {},admission.context(admission.new(),'long-name-run',2))
  assert(ok,problem and problem.message)
  local shell,se=compiler.prepare('local '..name..'=1; return '..name,admission.context(admission.new(),'long-shell',3),'shell')
  assert(shell,se and se.message)
  for _,reserved in ipairs({'_ENV','_G','__tc'..name,'game','load','require'}) do
    local denied,reason=compiler.compile('function '..reserved..'() end',admission.context(admission.new(),reserved,4))
    assert(not denied and reason.code=='E_PROGRAM')
  end
  local ordinary,diagnostic=compiler.compile('function ordinary() if true then return 1 end end',admission.context(admission.new(),'old-depth-unused',5))
  assert(ordinary,diagnostic and diagnostic.message)
  parsing.begin(nil)
  for _=1,limits.host_stack_depth do parsing.push() end
  local accepted,depth_error=pcall(parsing.push)
  parsing.finish()
  assert(not accepted and depth_error.code=='E_CAPACITY' and depth_error.message=='compiler host depth exceeded')
  local deep,deep_error=compiler.compile('function deep() return '..string.rep('not ',limits.host_stack_depth+1)..'true end',admission.context(admission.new(),'real-recursion',6))
  assert(not deep and deep_error.code=='E_CAPACITY')
  assert(compiler.compile('function after_refusal() end',admission.context(admission.new(),'after-depth-refusal',7)))
  local body='local x=0; '..string.rep('x=x+1; ',900)..' assert(x==900)'
  for _,text in ipairs({'function start() '..body..' end',
    'return {api_version=1,handlers={start=function() '..body..' end}}'}) do
    local wide,reason=compiler.prepare(text,admission.context(admission.new(),'wide',8))
    assert(wide,reason and reason.message)
    local iter,state,index=tokenize(text,'@quota-regression'); local tokens=0
    while true do
      local token; index,token=iter(state,index)
      if not token or token.token_type=='eof' then break end
      tokens=tokens+1
    end
    assert(tokens>4096 and wide.nodes>4096 and #wide.generated>131072,'fixture did not cross former compiler quotas')
    local ran,problem,status=compiler.run(wide,'start',{}, {},admission.context(admission.new(),'wide-run',9),{})
    assert(ran and status==nil,problem and problem.message or 'wide handler did not complete')
    log('TC_COMPILER_QUOTAS tokens='..tokens..' nodes='..wide.nodes..' generated='..#wide.generated)
  end
  local functions={}
  for i=1,65 do functions[i]='function f'..i..'() end' end
  local exports,reason=compiler.prepare(table.concat(functions,'\n'),admission.context(admission.new(),'exports',10))
  assert(exports and exports.handlers.f65,reason and reason.message)
  log('TC_CONTRACT compiler-long-identifiers-reserved-names-real-host-depth')
end
return M
