local compiler = require('scripts.runtime.compiler')
local admission = require('scripts.runtime.admission')
local limits = require('scripts.runtime.limits')
local examples = require('examples.planning-programs')
local environment = require('scripts.runtime.environment')
local M = {}
local function source(body)
  return 'function start(event) '..body..' end'
end
local function host_services(ctx,output)
  return function(env)
    return {computer={log=output or function() end,exhaust=function()
      env.spend(admission.host_ceiling(ctx.ledger,ctx.tick)-ctx.ledger.total+1)
    end}}
  end
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
    local ok,e=compiler.run(plan,'start',{name='start',tick=0},host_services(ctx,function(text) assert(type(text)=='string'); effects=effects+1 end),ctx)
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
  run_case('finite-native-loop-and-recursion',[[
    local n=0; for i=1,500001 do n=n+1 end; assert(n==500001)
    local function recurse(n) if n==0 then return 0 end; return 1+recurse(n-1) end
    assert(recurse(96)==96)
  ]],true)
  local effects=run_case('pcall-cannot-swallow-host-refusal',[[pcall(computer.exhaust); computer.log('unsafe')]],false,'E_BUDGET')
  assert(effects==0)
  effects=run_case('mutual-host-refusal',[[local a,b; a=function() return b() end; b=function() computer.exhaust() end; a()]],false,'E_BUDGET')
  assert(effects==0)
  run_case('dynamic-string-members',[[local s='abc'; local m=s['sub']; assert(m(s,1)=='abc'); assert(s['ma'..'tch']==nil)]],true)
  run_case('library-mutation',[[string.sub=nil]],false,'E_ARGUMENT')
  run_case('finite-format-width-and-malformed-format',[[assert(#string.format('%32s','a')==32); assert(not pcall(string.format,'%'))]],true)
  run_case('finite-temporary-growth',[[local s=string.rep('a',32768); local t={}; for i=1,2048 do t[i]=i end; assert(#s==32768 and #t==2048)]],true)
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
  plan,ctx=compiled('computer.exhaust()','refused',ledger,10)
  local ok=compiler.run(plan,'start',{},host_services(ctx),ctx); assert(not ok)
  local spent=ctx.machine.work
  local again=admission.context(ledger,'refused',10)
  assert(again.machine.work==spent)
  local healthy,neighbor=compiled('computer.log("healthy")','neighbor',ledger,10)
  local count=0
  ok,e=compiler.run(healthy,'start',{}, {computer={log=function() count=count+1 end}},neighbor)
  assert(ok,e and e.message); assert(count==1)
  assert(again.machine.work==spent and ledger.total>=spent); report('healthy-neighbor-and-same-tick-ledger')
  local zero=admission.context(admission.new(),'zero',0)
  zero.machine.compile=limits.compile_work
  plan,e=compiler.compile(source(''),zero); assert(not plan and e.code=='E_BUDGET')
  report('compile-refusal')
  -- Parse/compile every actual planning program without claiming peripheral execution.
  assert(#examples==21,'retained planning/API program inventory changed; review the fixture count')
  for _,example in ipairs(examples) do
    local candidate,diagnostic=compiler.compile(example.source,admission.context(admission.new(),example.name,0))
    assert(candidate,example.name..': '..(diagnostic and diagnostic.message or 'refused'))
  end
  report('all-twenty-one-retained-planning-and-api-programs-compile')
  run_case('semicolons-and-fresh-closures',[[; local function outer(x) return function() return x end end; local f=outer(false); assert(f()==false);]],true)
  local p,c=compiled('pcall(computer.stop); computer.log("unsafe")')
  local writes=0
  local success,diagnostic=compiler.run(p,'start',{}, {computer={log=function() writes=writes+1 end}},c)
  assert(not success and diagnostic.code=='E_STOP' and writes==0)
  report('uncatchable-stop')
  p,c=compiled('local h=peripheral.wrap(); assert(h.get()==false); local ok=pcall(function() h.get=nil end); assert(not ok)')
  success,diagnostic=compiler.run(p,'start',{}, function(guard)
    local handle=guard.namespace({get=guard.service(function() return false end)},'test peripheral')
    return {peripheral={wrap=function() return handle end}}
  end,c)
  assert(success,diagnostic and diagnostic.message)
  report('guard-aware-protected-service-handle')
  -- Caller-owned generated text is not trusted after retention or accidental mutation.
  p,c=compiled('computer.log("validated")')
  p.generated='error("caller-owned executable")'; p.nodes=-100; p.handlers={}
  local warm=admission.context(admission.new(),'cache-peer',3)
  local cold=admission.context(admission.new(),'cache-peer',3)
  local retained={compiler_version=p.compiler_version,api_version=p.api_version,source=p.source,generated='error("caller-owned executable")'}
  success,diagnostic=compiler.run(p,'start',{}, {computer={log=function() end}},warm)
  assert(success,diagnostic and diagnostic.message)
  success,diagnostic=compiler.run(retained,'start',{}, {computer={log=function() end}},cold)
  assert(success,diagnostic and diagnostic.message)
  assert(warm.machine.compile==cold.machine.compile and warm.machine.work==cold.machine.work and warm.ledger.total==cold.ledger.total)
  warm=admission.context(admission.new(),'cache-peer',4); cold=admission.context(admission.new(),'cache-peer',4)
  warm.machine.compile=limits.compile_work-300; cold.machine.compile=limits.compile_work-300
  local a,ae=compiler.run(p,'start',{}, {},warm)
  local b,be=compiler.run(retained,'start',{}, {},cold)
  assert(not a and not b and ae.code=='E_BUDGET' and be.code=='E_BUDGET')
  assert(warm.machine.compile==cold.machine.compile and warm.ledger.total==cold.ledger.total)
  report('retained-generated-data-and-cold-warm-admission')
  -- Compare partial native sort writes and comparator effects with this engine.
  local sort_source="local t={5,1,4,2,3}; local alias=t; local calls=0; local ok=pcall(table.sort,t,function(a,b) calls=calls+1; if calls==3 then error('stop') end; return a<b end); return ok,calls,table.concat(alias,',')"
  local native=table.pack(assert(load(sort_source,'@native-sort','t',_ENV))())
  local text=source('local function sort_case() '..sort_source..' end; computer.observe(sort_case())')
  local candidate,err=compiler.compile(text,admission.context(admission.new(),'native-sort-compile',0))
  assert(candidate,err and err.message)
  local observed
  local ok,diag=compiler.run(candidate,'start',{}, {computer={observe=function(...) observed=table.pack(...) end}},admission.context(admission.new(),'native-sort-run',0))
  assert(ok,diag and diag.message)
  assert(observed.n==native.n); for i=1,native.n do assert(observed[i]==native[i]) end
  report('native-sort-partial-writes-comparator-effects-and-aliases')
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
    assert(candidate.api_version==1 and candidate.compiler_version==3 and candidate.mode==nil)
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
    'return 1',
    'function start() end; return 1',
    'return 1; function start() end',
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
    'getmetatable','setmetatable','collectgarbage','xpcall','unpack','_VERSION'}
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
  refused(table.concat(declarations,'\n')..'\nfunction start() end','E_PROGRAM','native syntax')
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
  assert(diagnostic.line==2 and diagnostic.column==1)
  report('declaration-original-helper-diagnostic')
  local shared=admission.new()
  local bad_context=admission.context(shared,'declaration-malicious',12)
  writes=0
  success,diagnostic=document('function start() pcall(a); computer.log("unsafe") end; function a() return b() end; function b() computer.exhaust() end',nil,
    host_services(bad_context,function() writes=writes+1 end),bad_context)
  assert(not success and diagnostic.code=='E_BUDGET' and writes==0)
  local spent=bad_context.machine.work
  local neighbor=admission.context(shared,'declaration-neighbor',12)
  success,diagnostic=document('function start() computer.log("healthy") end',nil,
    {computer={log=function() writes=writes+1 end}},neighbor)
  assert(success,diagnostic and diagnostic.message); assert(writes==1)
  assert(admission.context(shared,'declaration-malicious',12).machine.work==spent)
  report('declaration-fatal-protected-host-refusal-and-healthy-neighbor')
  success,diagnostic=document('function start(n) if type(n)=="number" and n>0 then return start(n-1) end; if type(n)=="table" then assert(pcall(start,96)) end end')
  assert(success,diagnostic and diagnostic.message)
  report('declaration-finite-direct-protected-recursion')
  local exhausted=admission.context(admission.new(),'declaration-shared-exhaustion',13)
  candidate=assert(compiler.compile('function start() pcall(spin); computer.log("unsafe") end; function spin() computer.exhaust() end',exhausted))
  -- Reconstruction fits; the checked host operation refuses without a later log.
  exhausted.ledger.total=limits.host_work_per_tick-limits.maintenance_work_per_tick-100000
  writes=0
  success,diagnostic=compiler.run(candidate,'start',{}, host_services(exhausted,function() writes=writes+1 end),exhausted)
  assert(not success and diagnostic.code=='E_BUDGET' and writes==0)
  assert(exhausted.ledger.total>=limits.host_work_per_tick-limits.maintenance_work_per_tick-100000)
  report('declaration-pcall-cannot-renew-shared-budget')
  writes=0
  local control
  success,diagnostic,candidate,control=document('function start() pcall(stop); computer.log("unsafe") end; function stop() computer.stop() end',nil,
    {computer={log=function() writes=writes+1 end}})
  assert(not success and diagnostic.code=='E_STOP' and control=='stop' and writes==0)
  report('declaration-uncatchable-stop')
  local added={'print','rawget','rawset','rawlen','rawequal','xpcall','unpack','_VERSION'}
  local shared_body=[[
    assert(_VERSION=='Lua 5.2' and unpack==table.unpack)
    assert(tostring(unpack)=='table function' and tostring(table.unpack)==tostring(unpack))
    local t={}; local alias=t
    assert(rawequal(rawset(t,'value',false),t) and rawget(alias,'value')==false)
    rawset(t,'self',t); assert(rawequal(rawget(t,'self'),t))
    rawset(t,'value',nil); assert(select('#',rawget(t,'value'))==1 and rawget(t,'value')==nil)
    assert(select('#',rawget(t,nil))==1 and rawget(t,0/0)==nil)
    local f=function() end; rawset(t,f,computer); assert(rawequal(rawget(t,f),computer))
    assert(rawequal(nil,nil) and not rawequal(nil,false) and not rawequal({},{}))
    assert(rawequal(computer,computer) and rawequal(print,print) and rawequal('abc','a'..'bc'))
    assert(rawlen('a\000b')==3 and rawlen({})==0 and rawlen({1,false,3})==3)
    local tuple=table.pack(false,nil,3,nil)
    local a,b,c,d=unpack(tuple,1,4); assert(a==false and b==nil and c==3 and d==nil)
    assert(select('#',unpack(tuple,1,4))==4 and select('#',unpack(tuple,2,1))==0)
    assert(select('#',unpack(tuple,0,4))==5 and select('#',unpack(tuple,1,160))==160)
    for _,fn in ipairs({rawget,rawset,rawlen}) do
      for _,target in ipairs({math,computer,peripheral}) do
        local ok,e=pcall(fn,target,'x',true); assert(not ok and e.code=='E_ARGUMENT')
      end
    end
    assert(not pcall(rawget,t) and not pcall(rawset,t,'x') and not pcall(rawlen) and not pcall(rawequal,nil))
    assert(not pcall(rawset,t,nil,1) and not pcall(rawset,t,0/0,1))
    local function tuple_fn(...) return ... end
    local results=table.pack(xpcall(tuple_fn,function() error('unexpected handler') end,false,nil,3,nil))
    assert(results.n==5 and results[1] and results[2]==false and results[3]==nil and results[4]==3 and results[5]==nil)
    assert(select('#',xpcall(function() end,tuple_fn))==1)
    local problem={value=false}
    local ok,e=xpcall(function() error(problem) end,function(p) assert(rawequal(p,problem)); return false,7 end)
    assert(ok==false and e==false)
    ok,e=xpcall(function() error(computer) end,function(p) assert(rawequal(p,computer)); return p end)
    assert(not ok and rawequal(e,computer))
    ok,e=xpcall(function() error(tuple_fn) end,function(p) assert(rawequal(p,tuple_fn)); return p end)
    assert(not ok and rawequal(e,tuple_fn))
    results=table.pack(xpcall(function() error(nil) end,function(p) assert(p==nil) end))
    assert(results.n==2 and results[1]==false and results[2]==nil)
    local attempts=0
    ok,e=xpcall(function() error('first') end,function(p)
      attempts=attempts+1; if attempts==1 then error('second') end
      assert(p=='second'); return 'handled'
    end)
    assert(not ok and e=='handled' and attempts==2)
    assert(not pcall(xpcall,false,tuple_fn) and not pcall(xpcall,tuple_fn,nil))
    assert(select('#',print('value',false,nil,3,nil))==0)
    assert(select('#',print())==0)
    print({},function() end,computer,unpack)
  ]]
  for _,text in ipairs({source(shared_body),'local function check() '..shared_body..' end; function start() check() end'}) do
    local output={}
    success,diagnostic=document(text,'start',{computer={log=function(s) output[#output+1]=s end}})
    assert(success,diagnostic and diagnostic.message)
    assert(#output==3 and output[1]=='value\tfalse\tnil\t3\tnil' and output[2]==''
      and output[3]=='table\tguest function\tAPI handle\ttable function')
  end
  report('expanded-globals-export-and-private-helper-tuples-identity-and-print')
  local accepted_example=0
  for _,example in ipairs(examples) do
    if example.name=='specs/computer-runtime/lua-api.md:3' then
      local output={}
      success,diagnostic=document(example.source,nil,{computer={log=function(s) output[#output+1]=s end}})
      assert(success,diagnostic and diagnostic.message)
      assert(#output==2 and output[1]=='Lua 5.2\tfalse\tnil\t3' and output[2]=='handled: sample failure')
      accepted_example=accepted_example+1
    end
  end
  assert(accepted_example==1)
  report('main-runtime-companion-acceptance-program-executed-exact-output')
  -- Native reference executes in the exact same engine, separately from the
  -- compiled guest assertion above. In particular handler errors re-enter.
  local attempts=0
  local native=table.pack(xpcall(function(...) return ... end,function() end,false,nil,3,nil))
  assert(native.n==5 and native[1] and native[2]==false and native[3]==nil and native[4]==3 and native[5]==nil)
  local native_ok,native_error=xpcall(function() error('first',0) end,function(e)
    attempts=attempts+1; if attempts==1 then error('second',0) end; return e
  end)
  assert(not native_ok and native_error=='second' and attempts==2)
  assert(rawget({},nil)==nil and rawget({},0/0)==nil and rawlen({1,false,3})==3)
  report('exact-engine-benign-raw-and-xpcall-reference')
  local host_problem={code='E_ARGUMENT',message='private record'}
  success,diagnostic=document([[function start()
    local ok,e=xpcall(computer.failure,function(p) p.message='changed'; return p end)
    assert(not ok and e.code=='E_ARGUMENT' and e.message=='changed')
  end]],nil,{computer={failure=function() error(host_problem,0) end}})
  assert(success and host_problem.message=='private record',diagnostic and diagnostic.message)
  report('xpcall-host-diagnostic-defensive-copy')
  if game then
    success,diagnostic=document([[function start()
      local ok,e=xpcall(computer.foreign,function(p)
        assert(type(p)=='table' and p.code=='E_ARGUMENT'); return 'safe'
      end)
      assert(not ok and e=='safe')
    end]],nil,{computer={foreign=function() error(game.surfaces[1],0) end}})
    assert(success,diagnostic and diagnostic.message)
    report('xpcall-foreign-engine-error-refused-before-guest-handler')
  end
  for _,name in ipairs(added) do
    refused('function '..name..'() end')
    refused('local function '..name..'() end; function start() end')
    refused('function start() end; print("top-level")')
    success,diagnostic=document('function start('..name..') local '..name..'=false; assert('..name..'==false) end')
    assert(success,diagnostic and diagnostic.message)
    success,diagnostic=document('function start() local '..name..'=false; assert('..name..'==false) end')
    assert(success,diagnostic and diagnostic.message)
  end
  report('expanded-reservation-parameter-and-local-shadowing')
  for _,body in ipairs({
    [[xpcall(computer.exhaust,function(e) computer.log('unsafe') end); computer.log('unsafe')]],
    [[xpcall(function() error('x') end,function(e) computer.exhaust() end); computer.log('unsafe')]],
    [[pcall(function() xpcall(function() xpcall(computer.exhaust,function() computer.log('unsafe') end) end,function() computer.log('unsafe') end) end)]]
  }) do assert(run_case('xpcall-fatal-host-'..tests,body,false,'E_BUDGET')==0) end
  for _,body in ipairs({
    [[xpcall(computer.stop,function(e) computer.log('unsafe') end); computer.log('unsafe')]],
    [[xpcall(function() error('x') end,function() computer.stop() end); computer.log('unsafe')]]
  }) do assert(run_case('xpcall-stop-'..tostring(tests),body,false,'E_STOP')==0) end
  local wide={}; for i=1,160 do wide[i]='nil' end
  run_case('native-xpcall-wide-status-inclusive-tuple','local t=table.pack(xpcall(function() return '..table.concat(wide,',')..' end,function() end)); assert(t.n==161)',true)
  local constants={}; for i=1,limits.table_entries do constants[i]='false' end
  run_case('rawset-native-growth-replacement-deletion',[[
    local t={]]..table.concat(constants,',')..[[}; local alias=t
    rawset(t,1,true); assert(rawget(alias,1)==true)
    local ok,e=pcall(rawset,t,'extra',false); assert(ok and rawequal(e,t) and rawget(alias,'extra')==false)
    rawset(t,1,nil); rawset(t,'extra',false); assert(rawget(alias,1)==nil and rawget(alias,'extra')==false)
  ]],true)
  run_case('raw-maximum-string-comparison-and-length',[[
    local s=string.rep('x',16384); assert(rawequal(s,s) and rawlen(s)==16384)
    assert(rawget({},s..'x')==nil)
    local t={[1]=1,[3]=3}; assert(rawlen(t)==#t)
  ]],true)
  for _,name in ipairs({'rawget','rawset','rawlen'}) do
    local original={key=false}
    local context=admission.context(admission.new(),'foreign-raw',0)
    local guard=environment.new(context,{computer={copy=function() return original end}}); guard.initialize()
    local copy=guard.globals.computer.copy()
    assert(copy~=original and copy.key==false)
    if name=='rawset' then assert(guard.globals.rawset(copy,'key',true)==copy and original.key==false)
    elseif name=='rawget' then assert(guard.globals.rawget(copy,'key')==false)
    else assert(guard.globals.rawlen(copy)==#copy) end
    assert(not pcall(guard.globals[name],guard.globals.computer,'key',true))
  end
  report('raw-host-transfer-copy-isolation-and-protected-target-refusal')
  local print_args={}; for i=1,160 do print_args[i]='""' end
  assert(run_case('print-native-wide-tuple','print('..table.concat(print_args,',')..')',true)==1)
  report('print-over-former-tuple-limit-with-bounded-output')
  do
    assert(type(admission.bind)=='function','specialized admission binding is missing')
    local ctx=admission.context(admission.new(),'bound',10)
    local work=admission.bind(ctx)
    for _,reserve in ipairs({work}) do
      for _,bad in ipairs({-1,0.5,math.huge,0/0,'1',false,1000000001}) do
        assert(not pcall(reserve,bad),'malformed bound reservation accepted')
        assert(ctx.ledger.total==0 and ctx.machine.work==0 and ctx.machine.allocations==nil)
      end
      assert(not pcall(reserve))
    end
    assert(work(1) and ctx.ledger.total==1)
    local peer=admission.context(ctx.ledger,'peer',10)
    assert(admission.reserve(peer,'work',7) and ctx.machine.work==1 and ctx.ledger.total==8)
    ctx.ledger.maintenance={maintenance_tick=10,maintenance_spent=limits.host_work_per_tick-ctx.ledger.total}
    assert(not work(1) and ctx.ledger.total==8)
    ctx.ledger.maintenance=nil
    assert(work(1) and ctx.machine.work==2)
    admission.context(ctx.ledger,'next',11)
    assert(not pcall(work,1) and ctx.ledger.total==0)
    local forged=admission.context(admission.new(),'forged',0)
    forged.machine={work=0,compile=0}
    assert(not pcall(admission.bind,forged),'detached machine admitted')
    for _,room in ipairs({0,2,3,4,5}) do
      local c=admission.context(admission.new(),'host-shortage',0); local g=environment.new(c,{})
      c.ledger.total=admission.host_ceiling(c.ledger,0)-room
      local before=c.ledger.total; local ok=pcall(g.spend,4)
      assert(ok==(room>=4) and c.ledger.total==before+(room>=4 and 4 or 0))
      if not ok then assert(not pcall(g.spend,0)) end
    end
  end
  report('specialized-admission-malformed-stale-shared-maintenance-and-host-shortages')
  do
    local descriptions,guards={},{}
    for i=1,3 do
      local context=admission.context(admission.new(),'isolated-'..i,0)
      local g=environment.new(context,{},i==3 and {root={}} or nil)
      local namespace=g.namespace
      g.namespace=function(entries,label)
        if label=='colors' then descriptions[i]=entries end
        return namespace(entries,label)
      end
      g.initialize(); guards[i]=g
      assert(g.globals.unpack==g.globals.table.unpack)
      assert(g.globals.colors==g.globals.colours)
      if i>1 then
        assert(descriptions[i]==descriptions[1],'immutable host color description was rebuilt')
        assert(g.globals.colors~=guards[1].globals.colors)
      end
    end
    local foreign=guards[1].namespace({value=false},'foreign invocation')
    for i=2,3 do
      local ok,e=pcall(guards[i].globals.rawget,foreign,'value')
      assert(not ok and e.code=='E_ARGUMENT','shared helper accepted another invocation table')
    end
    assert(not pcall(guards[1].spend,limits.host_work_per_tick))
    for i=2,3 do assert(guards[i].globals.tostring(false)=='false') end
    assert(not pcall(guards[1].check))
  end
  report('shared-host-description-fresh-bindings-program-shell-and-failed-neighbor-isolation')
  do
    local text=[[function start()
  computer.log("before")
  local a,b,c=1,false,nil
  a,b,c=b,c,a
  local d=a
  computer.log("after")
end]]
    local function location(text,needle)
      local offset=assert(text:find(needle,1,true))
      local prefix=text:sub(1,offset-1)
      local _,lines=prefix:gsub('\n','')
      return lines+1,#(prefix:match('[^\n]*$'))+1
    end
    local plan=assert(compiler.compile(text,admission.context(admission.new(),'region-compile',0)))
    assert(plan.generated==text and not plan.generated:find('__tc.',1,true))
    report('native-source-without-operation-probes')
    run_case('native-control-flow-and-nil-assignment',[[
      local a,b,c=1,false,nil
      a,b,c=b,c,a
      local d=a
      assert(a==false and b==nil and c==1 and d==false)
      if false then local x=0; error('wrong branch')
      elseif true then local x,y=2,3; x,y=y,x; assert(x==3 and y==2) end
      local skipped=false and computer.log('unsafe') or true
      assert(skipped and (true or computer.log('unsafe')))
      local i=0
      while i<3 do local x,y=i,false; x,y=y,x; i=i+1 end
      repeat local x=i; i=i-1 until i==0
      for j=1,3 do local x,y=j,nil; x,y=y,x; assert(x==nil and y==j) end
      for j,v in ipairs({false,2,3}) do local x,y=v,j; x,y=y,x; assert(x==j and y==v) end
      local function tuple() local x,y,z=false,nil,3; return x,y,z,nil end
      assert(select('#',tuple())==4)
      computer.log('finished')
    ]],true)
    for _,body in ipairs({
      'local i=0; while i<96 do local a,b=1,false; a,b=b,a; i=i+1 end',
      'local i=0; repeat local a,b=1,false; a,b=b,a; i=i+1 until i==96',
      'for i=1,96 do local a,b=1,false; a,b=b,a end',
      'local n=0; local function next_value() n=n+1; if n<=96 then return n end end; for i in next_value do local a,b=1,false; a,b=b,a end',
      'local function recurse(n) local a,b=1,false; a,b=b,a; if n>0 then return recurse(n-1) end end; recurse(96)',
      'xpcall(function() local x=1; for i=1,96 do local y=x end end,function() computer.log("unsafe") end)'
    }) do
      assert(run_case('native-finite-control-'..tests,'computer.log("before"); '..body..'; computer.log("after")',true)==2)
    end
    local cases={
      {body='local x=false\n  local y=x\n  local z=y+1',needle='local z=y+1',code='E_PROGRAM'},
      {body='local x="x"\n  local y=x\n  computer.exhaust()',needle='computer.exhaust',code='E_BUDGET'},
      {body='local x=1\n  local y=x\n  pcall(computer.stop)',needle='pcall',code='E_STOP'}
    }
    for _,case in ipairs(cases) do
      local body='\n  computer.log("before")\n  '..case.body..'\n  computer.log("unsafe")\n'
      local count,_,e=run_case('native-dynamic-fatal-location-'..tests,body,false,case.code)
      local line,column=location(source(body),case.needle)
      assert(count==1 and e.line==line and e.column==1,'lost original dynamic/fatal source boundary')
    end
    run_case('native-dynamic-copy-format-compare-and-protection',[[
      local x='a'; local y=x
      local s=string.rep(y,8); local t=table.pack(s..y,false,nil)
      assert(string.format('%s',t[1])=='aaaaaaaaa' and t.n==3)
      local ok,e=pcall(function() local x=false; local y=x; return y+1 end)
      assert(not ok and type(e)=='string')
    ]],true)
  end
  if report_total~=false then
    if log then log('TC_CONTRACT_TOTAL '..tests) else print('TC_CONTRACT_TOTAL '..tests) end
  end
  return tests
end
return M
