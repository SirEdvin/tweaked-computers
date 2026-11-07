local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local examples=require('examples.planning-programs')
local M={}
local function context() return admission.context(admission.new(),'native-source',0) end
function M.run()
  local source=[[local function private(n) if n==0 then return 0 end; return 1+private(n-1) end
function start() assert(later()==64); computer.log('native') end
function later() return private(64) end]]
  local plan,problem=compiler.compile(source,context())
  assert(plan,problem and problem.message)
  assert(plan.generated==source,'compiler still rewrites native operations')
  local observed=0
  local ok,e=compiler.run(plan,'start',{}, {computer={log=function(text) assert(text=='native'); observed=observed+1 end}},context())
  assert(ok,e and e.message); assert(observed==1)
  plan.generated='error("untrusted executable")'; plan.handlers={injected=true}; plan.nodes=-1
  assert(compiler.run(plan,'start',{}, {computer={log=function() observed=observed+1 end}},context()))
  assert(observed==2)
  ok,e=compiler.run(plan,'injected',{}, {},context()); assert(not ok and e.code=='E_NOT_FOUND')
  log('TC_CONTRACT native-source-and-private-authority')
  local pieces={}
  for i=1,160 do pieces[#pieces+1]='local function private_'..i..'() return '..i..' end' end
  for i=1,64 do
    local name=i==1 and 'start' or 'export_'..i
    pieces[#pieces+1]='function '..name..'() assert(private_160()==160) end'
  end
  local wide=table.concat(pieces,'\n')
  plan,e=compiler.compile(wide,context()); assert(plan,e and e.message)
  ok,e=compiler.run(plan,'start',{}, {},context()); assert(ok,e and e.message)
  log('TC_CONTRACT native-source-existing-local-capacity')
  for _,bad in ipairs({
    'function start() game.tick=1 end',
    'function start() return _ENV end',
    'function start() local x=("abc"):sub(1) end',
    'function start() start=function() end end',
    'function start() function start() end end',
    'function start() later() end; local function later() end',
    'function start() end; print("effect")',
    'local x=1; function start() end',
    'function start() goto nowhere end'
  }) do
    plan,e=compiler.compile(bad,context()); assert(not plan and e.code=='E_PROGRAM',bad)
  end
  for _,prefix in ipairs({'','\239\187\191','#!/ignored\n','\239\187\191#!/ignored\n'}) do
    local text=prefix..'-- prefix retained\nfunction start()\n error("located")\nend'
    plan,e=compiler.compile(text,context()); assert(plan,e and e.message)
    ok,e=compiler.run(plan,'start',{}, {},context())
    local extra=prefix:find('\n',1,true) and 1 or 0
    assert(not ok and e.line==3+extra and e.column==1,'native source coordinate changed')
  end
  log('TC_CONTRACT native-source-validation-and-coordinates')
  for _,example in ipairs(examples) do
    plan,e=compiler.compile(example.source,context())
    assert(plan,example.name..': '..(e and e.message or 'compile failed'))
  end
  assert(#examples==21)
  local incomplete=context(); incomplete.machine.compile=limits.compile_work
  plan,e=compiler.compile(source,incomplete); assert(not plan and e.code=='E_BUDGET')
  log('TC_CONTRACT native-source-examples-and-host-refusal')
  log('TC_CONTRACT_TOTAL 4')
end
return M
