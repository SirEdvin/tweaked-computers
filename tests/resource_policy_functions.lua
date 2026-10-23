-- Durable source functions/cells/protection, not native closure reconstruction.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local memory=require('scripts.runtime.memory')
local limits=require('scripts.runtime.limits')
local M={}; local loaded=false
local body=[[
  local value={n=0}; local alias=value
  local x=4
  local function change(a,b,c)
    assert(a==false and b==nil and c==7)
    x=x+1
    computer.prefix()
    local function inner()
      local n=0
      while n<300000 do n=n+1 end
      alias.n=n
      return false,nil,value
    end
    return inner()
  end
  local ok,a,b,c=pcall(change,false,nil,7)
  assert(ok and a==false and b==nil and rawequal(c,alias) and alias.n==300000 and x==5)
  local function factorial(n) if n==0 then return 1 end; return n*factorial(n-1) end
  assert(factorial(6)==720)
  local fs={}
  for i=1,3 do fs[i]=function() return i end end
  assert(fs[1]()==1 and fs[2]()==2 and fs[3]()==3)
  for _,i in ipairs({4,5,6}) do fs[i]=function() return i end end
  assert(fs[4]()==4 and fs[5]()==5 and fs[6]()==6)
  local err={message='owned'}
  local caught,e=pcall(function() error(err) end)
  assert(caught==false and rawequal(e,err))
  local outer,inner=pcall(function() return pcall(function() error(false) end) end)
  assert(outer and inner==false)
  local ok,a,b,c=pcall(function() return computer.tuple() end)
  assert(ok and a==false and b==nil and c==9)
  assert(select('#',pcall(function() end))==1)
  local safe=pcall(function() computer.writeData({fn=change}) end)
  assert(not safe)
  computer.finished()
]]
local function create(source)
  local plan,e=compiler.compile(source); assert(plan,e and e.message)
  local account=memory.new(8000000,256)
  return {plan=plan,ledger=admission.new(),checkpoint={},account=account,owner=memory.owner(account),prefix=0,finished=0,writes=0}
end
local function step(f,tick)
  local ctx=admission.context(f.ledger,'functions',tick); ctx.memory_owner=f.owner
  return compiler.run(f.plan,'start',nil,function(g)
    return {computer={prefix=function() g.prepare_empty_result(); f.prefix=f.prefix+1 end,
      tuple=function() return false,nil,9 end,
      writeData=function() f.writes=f.writes+1 end,
      finished=function() g.prepare_empty_result(); f.finished=f.finished+1 end}}
  end,ctx,f.checkpoint)
end
function M.run()
  storage.tc_functions={phase='arm',cases={
    create('function start() '..body..' end'),
    create('return {api_version=1,handlers={start=function() '..body..' end}}'),
  }}
end
function M.on_load()
  local state=storage.tc_functions
  if state.phase=='frozen' then
    for _,f in ipairs(state.cases) do
      assert(f.checkpoint.frame==f.frame and f.frame.pc==f.pc and f.frame.parent and f.frame.parent.parent)
      assert(f.ledger.total==f.spent and f.prefix==1 and f.finished==0)
    end
    loaded=true; log('TC_FUNCTIONS_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  local state=storage.tc_functions
  if state.phase=='done' or state.phase=='frozen' and not loaded then return end
  if loaded then loaded=false; state.phase='resume' end
  local done=true
  for _,f in ipairs(state.cases) do
    if not f.done then
      local ok,e,control=step(f,event.tick)
      assert(ok or control=='wait',e and (e.message..' at '..tostring(e.line)..':'..tostring(e.column)))
      if ok then assert(f.prefix==1 and f.finished==1 and f.writes==0); f.done=true else done=false end
      if state.phase=='arm' then
        assert(not ok and f.prefix==1 and f.checkpoint.frame.parent and f.checkpoint.frame.parent.parent)
        f.frame=f.checkpoint.frame; f.pc=f.frame.pc; f.spent=f.ledger.total
      end
    end
  end
  if state.phase=='arm' then
    state.phase='frozen'; state.tick=event.tick; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  assert(event.tick-state.tick<300,'nested function continuation deadline')
  if done then
    for _,f in ipairs(state.cases) do memory.close(f.owner,function() end); assert(f.account.used==512) end
    state.phase='done'; log('TC_CONTRACT durable-nested-calls-cells-recursion-protection-and-cold'); log('TC_COLD_OK')
  end
end
return M
