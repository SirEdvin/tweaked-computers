local compiler = require('scripts.runtime.compiler')
local admission = require('scripts.runtime.admission')
local limits = require('scripts.runtime.limits')
local examples = require('examples.planning-programs')
local M = {}
local function source(body)
  return 'return {api_version=1, handlers={start=function(event) '..body..' end}}'
end
function M.run()
  local tests=0
  local function report(name) tests=tests+1; if log then log('TC_CONTRACT '..name) end end
  local function compiled(body, id, ledger, tick)
    local ctx=admission.context(ledger or admission.new(),id or 'candidate',tick or 0)
    local plan,e=compiler.compile(source(body),ctx)
    assert(plan,e and e.message)
    return plan,ctx
  end
  local function run_case(name,body,expect,code)
    local plan,ctx=compiled(body)
    local effects=0
    local ok,e=compiler.run(plan,'start',{name='start',tick=0},{computer={log=function(text) assert(type(text)=='string'); effects=effects+1 end}},ctx)
    assert(ok==expect,name..': '..(e and e.message or 'unexpected result'))
    if code then assert(e.code==code,name..': '..e.code) end
    report(name)
    return effects,ctx,e
  end
  run_case('native-control-and-tuples',[[
    local f=function() return false,nil,3 end
    local a,b,c=f(); assert(a==false and b==nil and c==3)
    local t={false,2,3}; local sum=0
    for i,v in ipairs(t) do if v then sum=sum+v end end
    local i=0; repeat i=i+1 until i==3
    while i>0 do i=i-1 end
    assert(sum==5); computer.log(string.format('%s:%d','ok',sum))
  ]],true)
  local _,loopctx=run_case('infinite-loop','while true do end',false,'E_BUDGET')
  assert(loopctx.machine.work==limits.callback_work)
  run_case('recursion','local function f() return f() end; f()',false,'E_BUDGET')
  local effects=run_case('pcall-cannot-swallow',[[pcall(function() while true do end end); computer.log('unsafe')]],false,'E_BUDGET')
  assert(effects==0)
  effects=run_case('mutual-recursion',[[local a,b; a=function() return b() end; b=function() return a() end; a()]],false,'E_BUDGET')
  assert(effects==0)
  run_case('dynamic-string-metatable',[[local s='abc'; local m=s['sub']; m(s,1)]],false,'E_ARGUMENT')
  run_case('library-mutation',[[string.sub=nil]],false,'E_ARGUMENT')
  run_case('huge-format-width',[[string.format('%999999999s','a')]],false,'E_ARGUMENT')
  run_case('huge-repetition',[[string.rep('a',100000000)]],false,'E_LIMIT')
  run_case('allocation-growth',[[local t={}; while true do t[#t+1]={} end]],false)
  run_case('sort-comparator-loop',[[local t={2,1}; table.sort(t,function(a,b) while true do end end)]],false,'E_BUDGET')
  run_case('cyclic-service-data',[[local t={}; t.self=t; computer.log(t)]],false,'E_ARGUMENT')
  run_case('ordinary-protection',[[local ok,e=pcall(function() error({code='E_ARGUMENT',message='catchable'}) end); assert(not ok and e.code=='E_ARGUMENT')]],true)
  run_case('safe-reference-description',[[assert(tostring({})=='table'); assert(tostring(function() end)=='guest function')]],true)
  for _,body in ipairs({'game.tick=1','return _ENV','return __tc','require("x")','return ("x"):sub(1)','::label::','goto label','_G.x=1','new_global=1'}) do
    local ctx=admission.context(admission.new(),'bad-source',0)
    local plan,e=compiler.compile(source(body),ctx)
    assert(not plan and e.code=='E_PROGRAM',body..': '..(e and e.message or 'accepted forbidden source'))
  end
  report('closed-source-grammar')
  local ctx=admission.context(admission.new(),'syntax',0)
  local plan,e=compiler.compile(source('local ='),ctx)
  assert(not plan and e.line and e.column); report('source-diagnostic')
  plan,e=compiler.compile(source('local x='..string.rep('not ',128)..'true'),admission.context(admission.new(),'depth',0))
  assert(not plan and e.code=='E_LIMIT'); report('parser-depth')
  -- Shared admission survives reentry on the same tick and admits a healthy peer.
  local ledger=admission.new()
  plan,ctx=compiled('while true do end','malicious',ledger,10)
  local ok=compiler.run(plan,'start',{}, {},ctx); assert(not ok)
  local spent=ctx.machine.work
  local again=admission.context(ledger,'malicious',10)
  assert(again.machine.work==spent)
  local healthy,neighbor=compiled('computer.log("healthy")','neighbor',ledger,10)
  local count=0
  ok,e=compiler.run(healthy,'start',{}, {computer={log=function() count=count+1 end}},neighbor)
  assert(ok,e and e.message); assert(count==1)
  assert(not admission.reserve(again,'work',1)); report('healthy-neighbor-and-same-tick-ledger')
  local zero=admission.context(admission.new(),'zero',0)
  zero.machine.compile=limits.compile_work
  plan,e=compiler.compile(source(''),zero); assert(not plan and e.code=='E_BUDGET')
  report('compile-refusal')
  -- Parse/compile every actual planning program without claiming peripheral execution.
  assert(#examples==9,'planning program inventory changed; review the fixture count')
  for _,example in ipairs(examples) do
    local candidate,diagnostic=compiler.compile(example.source,admission.context(admission.new(),example.name,0))
    assert(candidate,example.name..': '..(diagnostic and diagnostic.message or 'refused'))
  end
  report('all-nine-planning-programs-compile')
  run_case('semicolons-and-fresh-closures',[[; local function outer(x) return function() return x end end; local f=outer(false); assert(f()==false);]],true)
  local p,c=compiled('pcall(computer.stop); computer.log("unsafe")')
  local writes=0
  local success,diagnostic=compiler.run(p,'start',{}, {computer={log=function() writes=writes+1 end}},c)
  assert(not success and diagnostic.code=='E_STOP' and writes==0)
  report('uncatchable-stop')
  p,c=compiled('computer.log("unsafe")')
  c.machine.allocations=limits.callback_allocations
  success,diagnostic=compiler.run(p,'start',{}, {computer={log=function() writes=writes+1 end}},c)
  assert(not success and diagnostic.code=='E_BUDGET' and writes==0)
  report('construction-allocation-poison')
  p,c=compiled('local h=peripheral.wrap(); assert(h.get()==false); local ok=pcall(function() h.get=nil end); assert(not ok)')
  success,diagnostic=compiler.run(p,'start',{}, function(guard)
    local handle=guard.namespace({get=guard.service(function() return false end)},'test peripheral')
    return {peripheral={wrap=function() return handle end}}
  end,c)
  assert(success,diagnostic and diagnostic.message)
  report('guard-aware-protected-service-handle')
  -- Caller-owned generated text is not trusted after retention or accidental mutation.
  p,c=compiled('computer.log("validated")')
  p.generated='while true do end'; p.nodes=-100; p.handlers={}
  local warm=admission.context(admission.new(),'cache-peer',3)
  local cold=admission.context(admission.new(),'cache-peer',3)
  local retained={compiler_version=p.compiler_version,api_version=p.api_version,source=p.source,generated='while true do end'}
  success,diagnostic=compiler.run(p,'start',{}, {computer={log=function() end}},warm)
  assert(success,diagnostic and diagnostic.message)
  success,diagnostic=compiler.run(retained,'start',{}, {computer={log=function() end}},cold)
  assert(success,diagnostic and diagnostic.message)
  assert(warm.machine.compile==cold.machine.compile and warm.machine.work==cold.machine.work and warm.machine.allocations==cold.machine.allocations and warm.ledger.total==cold.ledger.total)
  warm=admission.context(admission.new(),'cache-peer',4); cold=admission.context(admission.new(),'cache-peer',4)
  warm.machine.compile=limits.compile_work-300; cold.machine.compile=limits.compile_work-300
  local a,ae=compiler.run(p,'start',{}, {},warm)
  local b,be=compiler.run(retained,'start',{}, {},cold)
  assert(not a and not b and ae.code=='E_BUDGET' and be.code=='E_BUDGET')
  assert(warm.machine.compile==cold.machine.compile and warm.ledger.total==cold.ledger.total)
  report('retained-generated-data-and-cold-warm-admission')
  if game then
    p,c=compiled('local host=computer.hostFixture(); computer.log("unsafe")')
    writes=0
    success,diagnostic=compiler.run(p,'start',{}, {computer={
      hostFixture=function() return game.surfaces[1] end,
      log=function() writes=writes+1 end
    }},c)
    assert(not success and diagnostic.code=='E_ARGUMENT' and writes==0)
    report('actual-engine-LuaObject-return-refused')
  end
  if log then log('TC_CONTRACT_TOTAL '..tests) else print('TC_CONTRACT_TOTAL '..tests) end
  return tests
end
return M
