-- Scalar local binding needs one value allocation, not discarded assignment vectors.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local sandbox=require('scripts.runtime.sandbox')
local errors=require('scripts.runtime.errors')
local M={}
local function guard_before_publication()
  local ledger=admission.new(); local ctx=admission.context(ledger,'local-guard',0)
  local plan,e=compiler.compile('function start()\nlocal value=1\nend',ctx); assert(plan,e and e.message)
  local checkpoint,seen={},0; local original=sandbox.new
  sandbox.new=function(...)
    local g=original(...); local scalar=g.scalar
    g.scalar=function(value)
      if value==1 then seen=seen+1; errors.raise('E_ARGUMENT','local scalar guard marker') end
      return scalar(value)
    end
    return g
  end
  local passed,ok,diagnostic=pcall(compiler.run,plan,'start',nil,{},ctx,checkpoint)
  sandbox.new=original
  assert(passed and not ok and diagnostic.code=='E_ARGUMENT' and diagnostic.message=='local scalar guard marker')
  assert(seen==1 and next(checkpoint.frame.locals)==nil,'local publication preceded its scalar guard')
  log('TC_CONTRACT scalar-local-binding-preserves-type-validation-before-publication')
end
local function sample(count,descriptor)
  local body='local n=0; while n<'..count..' do n=n+1 end; computer.finished(n)'
  local source=descriptor and 'return {api_version=1,handlers={start=function() '..body..' end}}'
    or 'function start() '..body..' end'
  local ledger=admission.new(); local ctx=admission.context(ledger,'scalar-local-'..count,0)
  local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
  local checkpoint,effects={},0
  local ok,e,control=compiler.run(plan,'start',nil,function(g)
    return {computer={finished=function(n) assert(n==count); g.prepare_empty_result(); effects=effects+1 end}}
  end,ctx,checkpoint)
  assert(ok and effects==1,e and e.message or control)
  return ctx.machine.allocations,ctx.machine.work
end
function M.run()
  guard_before_publication()
  for _,descriptor in ipairs({false,true}) do
    local base_alloc,base_work=sample(0,descriptor)
    local alloc,work=sample(1000,descriptor)
    log('TC_SCALAR_LOCAL descriptor='..tostring(descriptor)..' allocation_delta='..(alloc-base_alloc)..' work_delta='..(work-base_work))
    assert(alloc-base_alloc==1000,'scalar local updates allocated discarded target vectors: '..(alloc-base_alloc))
  end
  log('TC_CONTRACT both-source-scalar-local-loops-retain-one-binding-allocation-per-update')
  local ledger=admission.new(); local ctx=admission.context(ledger,'local-old-ABI',0)
  local plan,e=compiler.compile('function start() local n=0; while n<100000 do n=n+1 end end',ctx); assert(plan,e and e.message)
  local checkpoint={}; local ok,e,control=compiler.run(plan,'start',nil,{},ctx,checkpoint)
  assert(not ok and control=='wait',e and e.message)
  local frame,values=checkpoint.frame,{}
  for key,value in pairs(frame.locals) do values[key]=value end
  checkpoint.version=3
  ok,e=compiler.run(plan,'start',nil,{},admission.context(ledger,'local-old-ABI',1),checkpoint)
  assert(not ok and e.code=='E_UNSUPPORTED' and checkpoint.frame==frame and checkpoint.version==3)
  for key,value in pairs(values) do assert(frame.locals[key]==value) end
  for key,value in pairs(frame.locals) do assert(values[key]==value) end
  log('TC_CONTRACT prior-local-result-liveness-ABI-refused-with-accepted-locals-retained')
end
return M
