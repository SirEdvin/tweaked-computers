local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local parsing=require('scripts.runtime.parse_admission')
local M={}
function M.run()
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
  local old=limits.source_nesting
  limits.source_nesting=0
  local ordinary,diagnostic=compiler.compile('function ordinary() if true then return 1 end end',admission.context(admission.new(),'old-depth-unused',5))
  limits.source_nesting=old
  assert(ordinary,diagnostic and diagnostic.message)
  parsing.begin(nil)
  for _=1,limits.host_stack_depth do parsing.push() end
  local accepted,depth_error=pcall(parsing.push)
  parsing.finish()
  assert(not accepted and depth_error.code=='E_CAPACITY' and depth_error.message=='compiler host depth exceeded')
  local deep,deep_error=compiler.compile('function deep() return '..string.rep('not ',limits.host_stack_depth+1)..'true end',admission.context(admission.new(),'real-recursion',6))
  assert(not deep and deep_error.code=='E_CAPACITY')
  assert(compiler.compile('function after_refusal() end',admission.context(admission.new(),'after-depth-refusal',7)))
  log('TC_CONTRACT compiler-long-identifiers-reserved-names-real-host-depth')
end
return M
