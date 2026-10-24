-- Scalar local binding needs one value allocation, not discarded assignment vectors.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local sandbox=require('scripts.runtime.sandbox')
local errors=require('scripts.runtime.errors')
local limits=require('scripts.runtime.limits')
local M={}
local function guard_before_publication(body,marker)
  local ledger=admission.new(); local ctx=admission.context(ledger,'local-guard',0)
  local plan,e=compiler.compile('function start()\n'..body..'\nend',ctx); assert(plan,e and e.message)
  local checkpoint,seen={},0; local original=sandbox.new
  sandbox.new=function(...)
    local g=original(...); local scalar=g.scalar
    g.scalar=function(value,...)
      if value==marker then seen=seen+1; errors.raise('E_ARGUMENT','local scalar guard marker') end
      return scalar(value,...)
    end
    return g
  end
  local passed,ok,diagnostic=pcall(compiler.run,plan,'start',nil,{},ctx,checkpoint)
  sandbox.new=original
  assert(passed and not ok and diagnostic.code=='E_ARGUMENT' and diagnostic.message=='local scalar guard marker')
  assert(seen==1 and next(checkpoint.frame.locals)==nil,'local publication preceded its scalar guard')
  log('TC_CONTRACT scalar-local-binding-preserves-type-validation-before-publication')
end
local function sample(count,descriptor,multiple,indexed,native)
  local body='local n=0; local a,b=false,7; local t={0}; while n<'..count..' do '..
    (multiple and 'a,b=b,a; ' or '')..(indexed and 't[1]=n; ' or '')..
    (native and 'n=math.floor(n+1)' or 'n=n+1')..' end; computer.finished(n,a,b)'
  local source=descriptor and 'return {api_version=1,handlers={start=function() '..body..' end}}'
    or 'function start() '..body..' end'
  local ledger=admission.new(); local ctx=admission.context(ledger,'scalar-local-'..count,0)
  local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
  local checkpoint,effects={},0
  local ok,e,control=compiler.run(plan,'start',nil,function(g)
    return {computer={finished=function(n,a,b) assert(n==count and a==false and b==7); g.prepare_empty_result(); effects=effects+1 end}}
  end,ctx,checkpoint)
  assert(ok and effects==1,e and e.message or control)
  return ctx.machine.allocations,ctx.machine.work
end
local function binding_work(length,count,descriptor)
  local body='local text='..string.format('%q',string.rep('x',length))..'; local n=0; while n<'..count..
    ' do local value=text; n=n+1 end'
  local source=descriptor and 'return {api_version=1,handlers={start=function() '..body..' end}}'
    or 'function start() '..body..' end'
  local ctx=admission.context(admission.new(),'string-local',0)
  local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
  local ok,e,control=compiler.run(plan,'start',nil,{},ctx,{})
  assert(ok,e and e.message or control)
  return ctx.machine.work
end
local function paired_steps()
  for _,cleanup in ipairs({0,1,4,20}) do
    for available=-1,cleanup+2 do
      for _,kind in ipairs({'callback','aggregate','maintenance'}) do
        for _,poisoned in ipairs({false,true}) do
          local function sample(paired)
            local ctx=admission.context(admission.new(),'step-pair',1)
            if kind=='callback' then ctx.machine.work=limits.callback_work-available
            elseif kind=='aggregate' then ctx.ledger.total=admission.guest_ceiling(ctx.ledger,ctx.tick)-available
            else ctx.ledger.maintenance={maintenance_tick=ctx.tick,maintenance_spent=limits.host_work_per_tick-available} end
            local g=sandbox.new(ctx,{},nil,{owned={},owned_order={}})
            if poisoned then
              assert(not pcall(g.suspend))
              assert(g.work_suspended(),'fixture did not establish private suspension')
            end
            local reserve,calls=admission.reserve,0
            admission.reserve=function(...) calls=calls+1; return reserve(...) end
            local ok,problem=pcall(function()
              if paired then g.step(42,7,cleanup) else g.step(42,7); g.spend(cleanup) end
            end)
            admission.reserve=reserve
            local diagnostic=not ok and g.diagnostic(problem) or {}
            return {ok=ok,work=ctx.machine.work,total=ctx.ledger.total,code=diagnostic.code,
              line=diagnostic.line,column=diagnostic.column},calls
          end
          local separate=sample(false)
          local paired,calls=sample(true)
          for key,value in pairs(separate) do assert(paired[key]==value,'paired step changed '..key) end
          for key,value in pairs(paired) do assert(separate[key]==value,'paired step added '..key) end
          if paired.ok then assert(calls==1,'fitting adjacent block charges were not coalesced') end
          if poisoned then assert(calls==0,'private suspension attempted further admission') end
        end
      end
    end
  end
  log('TC_CONTRACT paired-block-admission-preserves-refusal-prefix-location-and-private-suspension')
end
function M.run()
  paired_steps()
  guard_before_publication('local value=1',1)
  guard_before_publication('local first,second=1,2',2)
  for _,descriptor in ipairs({false,true}) do
    local short=binding_work(8,100,descriptor)-binding_work(8,0,descriptor)
    local long=binding_work(2048,100,descriptor)-binding_work(2048,0,descriptor)
    assert(long==short,'scalar local binding scanned immutable string payloads')
    local base_alloc,base_work=sample(0,descriptor)
    local alloc,work=sample(1000,descriptor)
    log('TC_SCALAR_LOCAL descriptor='..tostring(descriptor)..' allocation_delta='..(alloc-base_alloc)..' work_delta='..(work-base_work))
    assert(alloc-base_alloc==1000,'scalar local updates allocated discarded target vectors: '..(alloc-base_alloc))
    local multi_base=sample(0,descriptor,true)
    local multi_alloc=sample(1000,descriptor,true)
    assert(multi_alloc-multi_base==6000,'parallel local updates allocated discarded target vectors: '..(multi_alloc-multi_base))
    local indexed_base=sample(0,descriptor,false,true)
    local indexed_alloc=sample(1000,descriptor,false,true)
    assert(indexed_alloc-indexed_base==2000,'single indexed updates allocated discarded target vectors: '..(indexed_alloc-indexed_base))
    local call_base=sample(2,descriptor,false,false,true)
    local call_alloc=sample(1002,descriptor,false,false,true)
    assert(call_alloc-call_base==4000,'host calls allocated duplicate argument vectors: '..(call_alloc-call_base))
  end
  log('TC_CONTRACT both-source-scalar-local-loops-retain-one-binding-allocation-per-update')
  local ledger=admission.new(); local ctx=admission.context(ledger,'local-old-ABI',0)
  local plan,e=compiler.compile('function start() local n=0; while n<100000 do n=n+1 end end',ctx); assert(plan,e and e.message)
  local checkpoint={}; local ok,e,control=compiler.run(plan,'start',nil,{},ctx,checkpoint)
  assert(not ok and control=='wait',e and e.message)
  local frame,values=checkpoint.frame,{}
  for key,value in pairs(frame.locals) do values[key]=value end
  for _,version in ipairs({5,6,7,8}) do
    checkpoint.version=version
    ok,e=compiler.run(plan,'start',nil,{},admission.context(ledger,'local-old-ABI',1),checkpoint)
    assert(not ok and e.code=='E_UNSUPPORTED' and checkpoint.frame==frame and checkpoint.version==version)
    for key,value in pairs(values) do assert(frame.locals[key]==value) end
    for key,value in pairs(frame.locals) do assert(values[key]==value) end
  end
  log('TC_CONTRACT prior-local-result-liveness-ABI-refused-with-accepted-locals-retained')
end
return M
