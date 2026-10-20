local compiler = require('scripts.runtime.compiler')
local admission = require('scripts.runtime.admission')
local limits = require('scripts.runtime.limits')
local examples = require('examples.planning-programs')
local M = {}
local function source(body)
  return 'return {api_version=1, handlers={start=function(event) '..body..' end}}'
end
function M.run(report_total)
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
  for _,body in ipairs({'game.tick=1','return _ENV','return __tc','require("x")','return ("x"):sub(1)','::label::','goto label','_G.x=1','new_global=1','print(1)'}) do
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
  -- A comparator can change the original table while native sorting uses a
  -- staged copy. Its effects remain, but final sorted writes must still fit.
  local targets,values={},{}
  for i=1,limits.tuple_entries do targets[i]='t[offset+'..(i+2)..']'; values[i]='true' end
  local assignment=table.concat(targets,',')..'='..table.concat(values,',')
  assert(limits.table_entries%limits.tuple_entries==0,'review sort fixture for changed limits')
  for _,room in ipairs({false,true}) do
    local text=source('local t={2,1}; local changed=false; local ok,e=pcall(table.sort,t,function(a,b) '..
      'if not changed then changed=true; t[1],t[2]=nil,nil; for chunk=0,'..(limits.table_entries/limits.tuple_entries-1)..
      ' do local offset=chunk*'..limits.tuple_entries..'; '..assignment..' end; '..
      (room and ('t['..(limits.table_entries+1)..'],t['..(limits.table_entries+2)..']=nil,nil; ') or '')..
      'end; return a<b end); '..
      (room and 'assert(ok and t[1]==1 and t[2]==2); ' or 'assert(not ok and e.code=="E_LIMIT" and t[1]==nil and t[2]==nil); ')..
      'local count=0; for k,v in pairs(t) do count=count+1 end; assert(count=='..limits.table_entries..')')
    local candidate,err=compiler.compile(text,admission.context(admission.new(),'sort-capacity-compile',0))
    assert(candidate,err and err.message)
    local ok,diag=compiler.run(candidate,'start',{}, {},admission.context(admission.new(),'sort-capacity-run',0))
    assert(ok,diag and diag.message)
  end
  report('sort-capacity-after-comparator-mutation')
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
  -- Saved declaration documents go through the actual program frontend/run,
  -- never the shell emitter or a hand-lowered equivalent.
  local function document(text, name, services, context)
    context=context or admission.context(admission.new(),'declarations',0)
    local candidate,err=compiler.compile(text,context)
    assert(candidate,err and err.message)
    assert(candidate.api_version==1 and candidate.compiler_version==2 and candidate.mode==nil)
    local accepted,diagnostic,control=compiler.run(candidate,name or 'start',{},services or {},context)
    return accepted,diagnostic,candidate,control,context
  end
  success,diagnostic= document([[
local function increment(value) return value+1 end
function start(event)
  assert(event~=nil)
  local f=sample
  local t={f,sample}
  assert(type(f)=='function' and tostring(f)=='guest function' and t[1]==t[2])
  assert(f(4)==5 and t[2](6)==7)
  local ok,a,b,c=pcall(tuple,false,nil,3)
  assert(ok and a==false and b==nil and c==3)
  assert(select('#',tuple(false,nil,3))==3)
  assert(select('#',empty())==0 and select('#',oneNil())==1)
  assert(select('#',pcall(empty))==1)
  local g=returned(); assert(g==sample and g(9)==10)
  local captured=capture(sample); assert(captured(10)==11)
  local caught,err=pcall(fail); assert(not caught and err==false)
  local owned={value=false}; alias(owned); assert(owned.value==true)
  assert(missing()==nil and missing(false)==false)
  assert(even(6) and not odd(6))
  local sample=false; sample=true; assert(sample)
  assert(shadow(false)==true)
  do local sample; function sample() return 12 end; assert(sample()==12) end
  assert(f(4)==5)
end
function sample(value) return increment(value) end
function tuple(...) return ... end
function empty() end
function oneNil() return nil end
function returned() return sample end
function capture(f) return function(v) return f(v) end end
function alias(t) t.value=true end
function missing(value) return value end
function even(n) if n==0 then return true end; return odd(n-1) end
function odd(n) if n==0 then return false end; return even(n-1) end
function shadow(sample) sample=not sample; return sample end
function fail() error(false) end
]])
  assert(success,diagnostic and diagnostic.message)
  report('declaration-calls-values-scope-and-tuples')
  local candidate
  success,diagnostic,candidate=document('local function private() return 7 end; function sample() assert(private()==7) end','sample')
  assert(success,diagnostic and diagnostic.message)
  assert(candidate.handlers.sample and not candidate.handlers.start and not candidate.handlers.private)
  success,diagnostic=compiler.run(candidate,'private',{}, {},admission.context(admission.new(),'private',0))
  assert(not success and diagnostic.code=='E_NOT_FOUND')
  report('declaration-optional-start-and-private-inventory')
  success,diagnostic=document([[
local function recurse(n) if n==0 then return later() end; return recurse(n-1) end
function start() assert(recurse(3)==42) end
function later() return 42 end
]])
  assert(success,diagnostic and diagnostic.message)
  report('declaration-private-self-and-public-forward-reference')
  writes=0
  success,diagnostic,candidate=document([[
local function private() return false end
local function start() return "private start" end
function sample()
  assert(start()=="private start" and private()==false)
  computer.log("fresh")
  private=function() return true end
end
]],'sample',{computer={log=function() writes=writes+1 end}})
  assert(success,diagnostic and diagnostic.message)
  assert(not candidate.handlers.start)
  success,diagnostic=compiler.run(candidate,'sample',{}, {computer={log=function() writes=writes+1 end}},
    admission.context(admission.new(),'fresh-declaration-dispatch',1))
  assert(success,diagnostic and diagnostic.message); assert(writes==2)
  report('declaration-fresh-private-bindings-and-private-start')
  local function refused(text,code,message)
    local rejected,err=compiler.compile(text,admission.context(admission.new(),'declaration-refusal',0))
    assert(not rejected,text..': accepted forbidden document')
    assert(err.code==(code or 'E_PROGRAM'),err.message)
    assert(err.line and err.column,err.message)
    if message then assert(err.message:find(message,1,true),err.message) end
  end
  for _,text in ipairs({
    'function sample() end; function sample() end',
    'local function sample() end; function sample() end',
    'function sample() end; local function sample() end',
    'local function x() end; local function x() end; function start() end',
    'function start() end; return {api_version=1,handlers={}}',
    'return {api_version=1,handlers={}}; function start() end',
    'function start() end; start()',
    'local count=0; function start() end',
    'local p=peripheral.wrap("x"); function start() end',
    'computer.setState("x",1); function start() end',
    'x=1; function start() end',
    'do function start() end end',
    'if true then function start() end end',
    'while false do end; function start() end',
    'function object.method() end', 'function object:method() end',
    'sample=function() end',
    'function start() sample=1 end; function sample() end',
    'function start() function sample() end end; function sample() end',
    'function start() new_global=1 end',
    'function start() return helper() end; local function helper() end',
    '', '-- comment only', 'local function helper() end'
  }) do refused(text) end
  report('declaration-closed-shape-and-immutable-exports')
  local reserved={'_ENV','_G','__tc_private','assert','error','ipairs','pairs','next','pcall','select',
    'tonumber','tostring','type','math','string','table','colors','colours','computer','peripheral','print',
    'game','storage','script','remote','defines','settings','rendering','require','load','loadstring',
    'loadfile','dofile','debug','os','io','coroutine','package','rawget','rawset','rawequal','rawlen',
    'getmetatable','setmetatable','collectgarbage'}
  for _,name in ipairs(reserved) do
    refused('function '..name..'() end')
    refused('local function '..name..'() end; function start() end')
  end
  refused('function '..string.rep('x',limits.identifier_bytes+1)..'() end')
  report('declaration-reserved-public-and-private-identifiers')
  local declarations={}
  for i=1,limits.handler_names do declarations[i]='function f'..i..'() end' end
  local maximum=table.concat(declarations,'\n')
  success,diagnostic,candidate=document(maximum,'f'..limits.handler_names)
  assert(success,diagnostic and diagnostic.message)
  local export_count=0; for _ in pairs(candidate.handlers) do export_count=export_count+1 end
  assert(export_count==limits.handler_names)
  refused(maximum..'\nfunction overflow() end','E_LIMIT','handler count')
  report('declaration-maximum-export-inventory')
  declarations={}
  for i=1,limits.handler_names do
    local name='f'..string.rep('x',limits.identifier_bytes-4)..string.format('%03d',i)
    declarations[i]='function '..name..'() assert(type('..name..')=="function") end'
  end
  success,diagnostic=document(table.concat(declarations,'\n'),'f'..string.rep('x',limits.identifier_bytes-4)..'064')
  assert(success,diagnostic and diagnostic.message)
  report('declaration-maximum-identifier-and-binding-work')
  declarations={}
  for i=1,limits.handler_names+1 do declarations[i]='local function h'..i..'() end' end
  success,diagnostic=document(table.concat(declarations,'\n')..'\nfunction start() h1(); h'..#declarations..'() end')
  assert(success,diagnostic and diagnostic.message)
  -- Native lexical limits still apply; no new unbounded private registry.
  for i=#declarations+1,210 do declarations[i]='local function h'..i..'() end' end
  refused(table.concat(declarations,'\n')..'\nfunction start() end','E_PROGRAM','generated source')
  report('declaration-private-helper-envelope')
  writes=0
  success,diagnostic=document([[
local function helper() end
function start()
  assert(not pcall(computer.setState,"public",sample))
  assert(not pcall(computer.setState,"private",helper))
  computer.log("still usable")
end
function sample() end
]],nil,{computer={setState=function() writes=writes+100 end,log=function() writes=writes+1 end}})
  assert(success,diagnostic and diagnostic.message); assert(writes==1)
  report('declaration-functions-are-not-durable-data')
  local fault_source='local function helper()\n  error("helper failure")\nend\nfunction start() helper() end'
  success,diagnostic=document(fault_source)
  assert(not success and diagnostic.code=='E_PROGRAM' and diagnostic.message=='helper failure')
  assert(diagnostic.line==2 and diagnostic.column==3)
  report('declaration-original-helper-diagnostic')
  local shared=admission.new()
  local bad_context=admission.context(shared,'declaration-malicious',12)
  writes=0
  success,diagnostic=document('function start() pcall(a); computer.log("unsafe") end; function a() return b() end; function b() return a() end',nil,
    {computer={log=function() writes=writes+1 end}},bad_context)
  assert(not success and diagnostic.code=='E_BUDGET' and writes==0)
  local spent=bad_context.machine.work
  local neighbor=admission.context(shared,'declaration-neighbor',12)
  success,diagnostic=document('function start() computer.log("healthy") end',nil,
    {computer={log=function() writes=writes+1 end}},neighbor)
  assert(success,diagnostic and diagnostic.message); assert(writes==1)
  assert(admission.context(shared,'declaration-malicious',12).machine.work==spent)
  report('declaration-fatal-protected-recursion-and-healthy-neighbor')
  success,diagnostic=document('function start() pcall(start) end')
  assert(not success and diagnostic.code=='E_BUDGET')
  report('declaration-direct-recursion-is-bounded')
  local exhausted=admission.context(admission.new(),'declaration-shared-exhaustion',13)
  candidate=assert(compiler.compile('function start() pcall(spin); computer.log("unsafe") end; function spin() while true do end end',exhausted))
  -- Leave a controlled shared
  -- execution envelope, smaller than the per-machine work ceiling.
  exhausted.ledger.total=limits.host_work_per_tick-limits.maintenance_work_per_tick-100000
  writes=0
  success,diagnostic=compiler.run(candidate,'start',{}, {computer={log=function() writes=writes+1 end}},exhausted)
  assert(not success and diagnostic.code=='E_BUDGET' and writes==0)
  assert(exhausted.machine.work>0 and exhausted.machine.work<limits.callback_work)
  report('declaration-pcall-cannot-renew-shared-budget')
  writes=0
  local control
  success,diagnostic,candidate,control=document('function start() pcall(stop); computer.log("unsafe") end; function stop() computer.stop() end',nil,
    {computer={log=function() writes=writes+1 end}})
  assert(not success and diagnostic.code=='E_STOP' and control=='stop' and writes==0)
  report('declaration-uncatchable-stop')
  if report_total~=false then
    if log then log('TC_CONTRACT_TOTAL '..tests) else print('TC_CONTRACT_TOTAL '..tests) end
  end
  return tests
end
return M
