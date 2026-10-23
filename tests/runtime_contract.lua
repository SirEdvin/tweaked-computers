local compiler = require('scripts.runtime.compiler')
local admission = require('scripts.runtime.admission')
local limits = require('scripts.runtime.limits')
local examples = require('examples.planning-programs')
local sandbox = require('scripts.runtime.sandbox')
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
  assert(not plan and e.code=='E_CAPACITY' and e.recoverable and e.resource=='host_stack_depth'
    and e.setting=='tc-host-stack-depth' and e.limit==limits.host_stack_depth); report('parser-depth')
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
  assert(#examples==10,'planning program inventory changed; review the fixture count')
  for _,example in ipairs(examples) do
    local candidate,diagnostic=compiler.compile(example.source,admission.context(admission.new(),example.name,0))
    assert(candidate,example.name..': '..(diagnostic and diagnostic.message or 'refused'))
  end
  report('all-ten-planning-programs-compile')
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
    'getmetatable','setmetatable','collectgarbage','xpcall','unpack','_VERSION'}
  for _,name in ipairs(reserved) do
    refused('function '..name..'() end')
    refused('local function '..name..'() end; function start() end')
  end
  local long_name=string.rep('x',limits.identifier_bytes+1)
  success,diagnostic=document('function '..long_name..'() end',long_name)
  assert(success,diagnostic and diagnostic.message)
  report('declaration-reserved-public-and-private-identifiers')
  local declarations={}
  for i=1,limits.handler_names do declarations[i]='function f'..i..'() end' end
  local maximum=table.concat(declarations,'\n')
  success,diagnostic,candidate=document(maximum,'f'..limits.handler_names)
  assert(success,diagnostic and diagnostic.message)
  local export_count=0; for _ in pairs(candidate.handlers) do export_count=export_count+1 end
  assert(export_count==limits.handler_names)
  success,diagnostic=document(maximum..'\nfunction overflow() end','overflow')
  assert(success,diagnostic and diagnostic.message)
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
    assert(not pcall(unpack,tuple,0) and not pcall(unpack,tuple,1,100000))
    for _,fn in ipairs({rawget,rawset,rawlen}) do
      for _,target in ipairs({math,computer,peripheral}) do
        local ok,e=pcall(fn,target,'x',true); assert(not ok and e.code=='E_ARGUMENT')
      end
    end
    assert(not pcall(rawget,t) and not pcall(rawset,t,'x') and not pcall(rawlen) and not pcall(rawequal,nil))
    assert(not pcall(rawset,t,nil,1) and not pcall(rawset,t,0/0,1))
    local function tuple_fn(...) return ... end
    local function construct(...) return {false,...},function() return {} end end
    local constructed,plain=construct(nil,7,nil)
    assert(constructed[1]==false and constructed[2]==nil and constructed[3]==7 and rawlen(plain())==0)
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
  for _,text in ipairs({source(shared_body),'function start() '..shared_body..' end'}) do
    local output={}
    success,diagnostic=document(text,'start',{computer={log=function(s) output[#output+1]=s end}})
    assert(success,diagnostic and diagnostic.message)
    assert(#output==3 and output[1]=='value\tfalse\tnil\t3\tnil' and output[2]==''
      and output[3]=='table\tguest function\tAPI handle\ttable function')
  end
  report('expanded-globals-both-saved-forms-tuples-identity-and-print')
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
    success,diagnostic=document('return {api_version=1,handlers={'..name..'=function() assert(type(print)=="function") end}}',name)
    assert(success,diagnostic and diagnostic.message)
  end
  report('expanded-reservation-lexical-shadowing-and-legacy-handler-keys')
  for _,body in ipairs({
    [[xpcall(function() while true do end end,function(e) computer.log('unsafe') end); computer.log('unsafe')]],
    [[xpcall(function() error('x') end,function(e) while true do end end); computer.log('unsafe')]],
    [[pcall(function() xpcall(function() error('x') end,function(e) error('again') end) end); computer.log('unsafe')]],
    [[xpcall(function() error('x') end,function(e) local function f() return f() end; return f() end); computer.log('unsafe')]],
    [[xpcall(function() error('x') end,function(e) while true do local t={} end end); computer.log('unsafe')]],
    [[pcall(function() xpcall(function() xpcall(function() while true do end end,function() computer.log('unsafe') end) end,function() computer.log('unsafe') end) end)]]
  }) do
    assert(run_case('xpcall-fatal-'..tostring(tests),body,false,'E_BUDGET')==0)
  end
  for _,body in ipairs({
    [[xpcall(computer.stop,function(e) computer.log('unsafe') end); computer.log('unsafe')]],
    [[xpcall(function() error('x') end,function() computer.stop() end); computer.log('unsafe')]]
  }) do assert(run_case('xpcall-stop-'..tostring(tests),body,false,'E_STOP')==0) end
  local wide={}; for i=1,limits.tuple_entries do wide[i]='nil' end
  run_case('xpcall-status-inclusive-tuple-overflow','xpcall(function() return '..table.concat(wide,',')..' end,function() end)',false,'E_BUDGET')
  wide[#wide]=nil
  run_case('xpcall-exact-status-inclusive-tuple','local t=table.pack(xpcall(function() return '..table.concat(wide,',')..' end,function() end)); assert(t.n=='..limits.tuple_entries..')',true)
  local constants={}; for i=1,limits.table_entries do constants[i]='false' end
  run_case('rawset-full-table-replacement-deletion-atomic-growth',[[
    local t={]]..table.concat(constants,',')..[[}; local alias=t
    rawset(t,1,true); assert(rawget(alias,1)==true)
    local ok,e=pcall(rawset,t,'extra',false); assert(not ok and e.code=='E_LIMIT' and rawget(alias,'extra')==nil)
    rawset(t,1,nil); rawset(t,'extra',false); assert(rawget(alias,1)==nil and rawget(alias,'extra')==false)
  ]],true)
  -- Exact host-controlled admission witnesses observe aliases even when fatal
  -- poison correctly prevents the compiled guest from doing its own readback.
  for _,kind in ipairs({'work','allocations'}) do
    local function setup()
      local context=admission.context(admission.new(),'raw-boundary',0)
      local guard=sandbox.new(context,{}); guard.initialize()
      local t=guard.new(1,function() return {key=false} end)
      return context,guard,t,guard.global('rawset')
    end
    local context,guard,t,fn=setup(); local before=context.machine[kind]
    assert(guard.call(fn,t,'key',true)==t); local cost=context.machine[kind]-before
    context,guard,t,fn=setup()
    context.machine[kind]=limits[kind=='work' and 'callback_work' or 'callback_allocations']-cost
    assert(pcall(guard.call,fn,t,'key',true) and t.key==true)
    context,guard,t,fn=setup()
    context.machine[kind]=limits[kind=='work' and 'callback_work' or 'callback_allocations']-cost+1
    assert(not pcall(guard.call,fn,t,'key',true) and t.key==false)
    assert(guard.diagnostic({}).code=='E_BUDGET')
    assert(not pcall(fn,{},'key',true))
  end
  report('rawset-exact-work-allocation-and-one-unit-short-no-mutation')
  run_case('raw-maximum-string-comparison-and-length',[[
    local s=string.rep('x',16384); assert(rawequal(s,s) and rawlen(s)==16384)
    assert(not pcall(function() return rawget({},s..'x') end))
    local t={[1]=1,[3]=3}; assert(rawlen(t)==#t)
  ]],true)
  for _,name in ipairs({'rawget','rawset','rawlen'}) do
    local context=admission.context(admission.new(),'foreign-raw',0)
    local guard=sandbox.new(context,{}); guard.initialize()
    local fn=guard.global(name)
    local ok,e=pcall(fn,{},'key',true)
    assert(not ok and e.code=='E_ARGUMENT')
  end
  report('raw-host-table-ownership-refused')
  local print_args={}; for i=1,limits.tuple_entries do print_args[i]='""' end
  assert(run_case('print-maximum-tuple','print('..table.concat(print_args,',')..')',true)==1)
  print_args[#print_args+1]='""'
  assert(compiler.compile(source('print('..table.concat(print_args,',')..')'),
    admission.context(admission.new(),'print-former-tuple-boundary',0)))
  report('print-former-tuple-boundary-not-a-source-restriction')
  if report_total~=false then
    if log then log('TC_CONTRACT_TOTAL '..tests) else print('TC_CONTRACT_TOTAL '..tests) end
  end
  return tests
end
-- Opt-in desired-contract checks, kept separate until the continuation gate.
function M.resource_policy()
  for _,text in ipairs({source([[
    computer.log('before'); local n=0
    while n<300000 do n=n+1 end
    computer.log(tostring(n))
  ]]), [[function start()
    computer.log('before'); local n=0
    while n<300000 do n=n+1 end
    computer.log(tostring(n))
  end]],source([[
    computer.log('before'); local n=0
    for i=1,300000 do n=n+1 end
    computer.log(tostring(n))
  ]]), [[function start()
    computer.log('before'); local n=0
    for i=1,300000 do n=n+1 end
    computer.log(tostring(n))
  end]]}) do
    local ledger=admission.new()
    local plan=assert(compiler.compile(text,admission.context(ledger,'continuity',0)))
    local checkpoint,effects={},{}
    local function services()
      return {computer={log=function(value) effects[#effects+1]=value end}}
    end
    local ok,problem,control=compiler.run(plan,'start',{},services,admission.context(ledger,'continuity',1),checkpoint)
    assert(not ok and control=='wait','slice must suspend, not fail: '..(problem and problem.message or tostring(control)))
    assert(#effects==1 and effects[1]=='before','completed prefix must execute once')
    local first_work=ledger.total
    ok,problem,control=compiler.run(plan,'start',{},services,admission.context(ledger,'continuity',1),checkpoint)
    assert(not ok and control=='wait' and ledger.total==first_work and #effects==1,'same-tick retry renewed work or replayed prefix')
    local tick=2
    repeat
      ok,problem,control=compiler.run(plan,'start',{},services,admission.context(ledger,'continuity',tick),checkpoint)
      assert(ok or control=='wait',problem and problem.message)
      tick=tick+1; assert(tick<200,'finite continuation made no progress')
    until ok
    assert(#effects==2 and effects[2]=='300000','locals lost or completed effect replayed')
  end
  -- Force exhaustion after the service effect but before guarded return delivery.
  local ledger=admission.new()
  local plan=assert(compiler.compile(source("computer.log('before'); computer.log('after')"),admission.context(ledger,'return-boundary',0)))
  local checkpoint,effects={},{}
  local context=admission.context(ledger,'return-boundary',1)
  local function provider(g)
    return {computer={log=function(text)
      g.prepare_empty_result()
      effects[#effects+1]=text
      if text=='before' then assert(admission.reserve(context,'work',limits.callback_work-context.machine.work)) end
    end}}
  end
  local ok,problem,control=compiler.run(plan,'start',{},provider,context,checkpoint)
  assert(not ok and control=='wait' and #effects==1,problem and problem.message)
  context=admission.context(ledger,'return-boundary',2)
  ok,problem,control=compiler.run(plan,'start',{},provider,context,checkpoint)
  assert(ok and #effects==2 and effects[1]=='before' and effects[2]=='after',problem and problem.message)
  local plan=assert(compiler.compile(source('while true do end'),admission.context(admission.new(),'invalid-checkpoint-compile',0)))
  for _,damage in ipairs({'pc','function','header','validation','validation-identity','validation-field','tuple','ownership-order','pending','preparation','preparation-conflict','tuple-capacities','tuple-control'}) do
    local state={}; local ledger=admission.new()
    local waiting,_,control=compiler.run(plan,'start',{}, {},admission.context(ledger,'invalid-checkpoint',1),state)
    assert(not waiting and control=='wait')
    if damage=='pc' then state.frame.pc=999999
    elseif damage=='function' then state.frame.slots[1]=function() end
    elseif damage=='validation' then state.validation=false
    elseif damage=='validation-identity' then state.validation={version=2,root={},queue={},head=1,seen={}}
    elseif damage=='validation-field' then state.validation={version=2,root=state,queue={},head=1,seen={},foreign=function() end}
    elseif damage=='tuple' then state.frame.tuples[1]={n=-1}
    elseif damage=='ownership-order' then state.owned_order=false
    elseif damage=='pending' then state.frame.pending=false
    elseif damage=='preparation' then state.preparation='foreign'
    elseif damage=='preparation-conflict' then state.preparation='execute'
    elseif damage=='tuple-capacities' then state.tuple_capacities=false
    elseif damage=='tuple-control' then state.tuple_control=-1
    else state.version=999 end
    local passed,diagnostic=compiler.run(plan,'start',{}, {},admission.context(ledger,'invalid-checkpoint',2),state)
    assert(not passed and diagnostic.code=='E_UNSUPPORTED','malformed checkpoint executed or reset')
    assert(damage~='pc' or state.frame.pc==999999,'invalid checkpoint repaired silently')
  end
end
return M
