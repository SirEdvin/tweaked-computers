-- Unencoded native callables/proxies must never enter a saved guest container.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local M={}
local function plain(root)
  local stack,seen={root},{}
  while #stack>0 do
    local value=table.remove(stack); local kind=type(value)
    assert(kind=='table' or kind=='string' or kind=='number' or kind=='boolean' or kind=='nil',
      'checkpoint retained a native '..kind)
    if kind=='table' and not seen[value] then
      assert(getmetatable(value)==nil,'checkpoint retained a metatable')
      seen[value]=true
      for key,child in pairs(value) do stack[#stack+1]=key; stack[#stack+1]=child end
    end
  end
end
local function forms(body)
  return {'function start() '..body..' end','return {api_version=1,handlers={start=function() '..body..' end}}'}
end
function M.run()
  for _,body in ipairs({
    'local t=table.pack(type)',
    'local t=table.pack(math)',
    'local t=table.pack(); rawset(t,"f",type)',
    'local t=table.pack(); rawset(t,type,true)',
    'local t=table.pack(); rawset(t,"namespace",math)',
    'local t=table.pack(); rawset(t,"n",nil); table.insert(t,type)',
    'local t=table.pack(); rawset(t,"n",nil); table.insert(t,math)',
  }) do
    for _,source in ipairs(forms(body..'; computer.finished()')) do
      local ctx=admission.context(admission.new(),'native-container-regression',0)
      local plan,problem=compiler.compile(source,ctx); assert(plan,problem and problem.message)
      local effects=0
      local ran,diagnostic=compiler.run(plan,'start',{}, {computer={finished=function() effects=effects+1 end}},ctx)
      assert(ran and effects==1,diagnostic and diagnostic.message)
    end
    for _,source in ipairs(forms(body..'; local n=0; while n<300000 do n=n+1 end; computer.finished()')) do
      local ctx=admission.context(admission.new(),'saved-container-rejection',0)
      local plan,problem=compiler.compile(source,ctx); assert(plan,problem and problem.message)
      local checkpoint,effects={},0
      local ran,diagnostic=compiler.run(plan,'start',{}, {computer={finished=function() effects=effects+1 end}},ctx,checkpoint)
      plain(checkpoint)
      assert(not ran and diagnostic and diagnostic.code=='E_UNSUPPORTED' and effects==0,
        'unencoded native container was not refused before suspension')
    end
  end
  log('TC_CONTRACT durable-container-rejects-unencoded-native-values-without-breaking-direct-runtime')
  for _,source in ipairs(forms([[local t=table.pack(); rawset(t,type,nil); rawset(t,math,nil)
    local f=type; local m=math; local n=0; while n<300000 do n=n+1 end
    assert(f(1)=='number' and m.floor(1.5)==1); computer.finished()]])) do
    local ledger=admission.new(); local ctx=admission.context(ledger,'safe-symbols',0)
    local plan,problem=compiler.compile(source,ctx); assert(plan,problem and problem.message)
    local checkpoint,effects={},0
    local function services() return {computer={finished=function() effects=effects+1 end}} end
    local ran,diagnostic,control=compiler.run(plan,'start',{},services,ctx,checkpoint)
    assert(not ran and control=='wait' and effects==0,diagnostic and diagnostic.message); plain(checkpoint)
    for tick=1,100 do
      ran,diagnostic,control=compiler.run(plan,'start',{},services,admission.context(ledger,'safe-symbols',tick),checkpoint)
      plain(checkpoint)
      assert(ran or control=='wait',diagnostic and diagnostic.message)
      if ran then break end
    end
    assert(ran and effects==1,'safe symbolic locals or non-retaining deletion changed semantics')
  end
  log('TC_CONTRACT symbolic-callables-remain-safe-through-suspension-and-nil-key-deletion')
  storage.tc_heap_boundary={phase='armed',source=forms([[local t=table.pack(); rawset(t,type,nil); rawset(t,math,nil)
    local f=type; local m=math; local n=0; while n<300000 do n=n+1 end
    assert(f(1)=='number' and m.floor(1.5)==1); computer.finished()]])[1],
    ledger=admission.new(),checkpoint={},finished=0}
end
local loaded=false
function M.on_load()
  local f=storage.tc_heap_boundary
  if f.phase=='frozen' then
    assert(f.checkpoint.frame.pc==f.pc and f.ledger.total==f.spent and f.finished==0)
    plain(f.checkpoint); loaded=true; log('TC_HEAP_BOUNDARY_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  local f=storage.tc_heap_boundary
  if f.phase=='done' or f.phase=='frozen' and not loaded then return end
  if loaded then loaded=false; f.phase='resuming' end
  local ctx=admission.context(f.ledger,'heap-symbols-cold',event.tick)
  local plan,problem=compiler.compile(f.source,ctx); assert(plan,problem and problem.message)
  local ran,diagnostic,control=compiler.run(plan,'start',{},function(g)
    return {computer={finished=function() g.prepare_empty_result(); f.finished=f.finished+1 end}}
  end,ctx,f.checkpoint)
  plain(f.checkpoint)
  if f.phase=='armed' then
    assert(not ran and control=='wait' and f.finished==0,diagnostic and diagnostic.message)
    f.phase='frozen'; f.pc=f.checkpoint.frame.pc; f.spent=f.ledger.total; f.tick=event.tick
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif ran then
    assert(f.finished==1 and event.tick>f.tick)
    f.phase='done'; log('TC_CONTRACT plain-symbolic-heap-survives-cold-without-native-values'); log('TC_COLD_OK')
  else
    assert(control=='wait' and event.tick-f.tick<100,diagnostic and diagnostic.message)
  end
end
return M
