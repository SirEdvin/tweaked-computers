-- Synthetic-clock lane contract; native GUI/cold acceptance is separate.
local registry=require('scripts.registry')
local shell=require('scripts.runtime.shell')
local M={}
function M.run()
  storage.tweaked_computers=nil; registry.initialize()
  local body=assert(game.surfaces[1].create_entity{name='constant-combinator',position={0,0},force='player'})
  local rec=registry.register('computer',body)
  rec.shell={version=1,id=rec.id..'/shell-fixture',pending={},pending_bytes=0}
  local initial,initial_error=shell.evaluate(rec,'x=5',0,1,{})
  assert(initial,initial_error and initial_error.message)
  local committed=rec.shell.values
  local checkpoint={}
  local source='x=10; computer.setState("prefix",(computer.getState("prefix") or 0)+1); print("before"); local n=0; while n<300000 do n=n+1 end; x=n'
  local ok,problem,control=shell.evaluate(rec,source,1,2,checkpoint)
  assert(not ok and control=='wait',problem and problem.message)
  assert(rec.shell.values==committed and checkpoint.shell_root.x==10 and rec.state.prefix==1,'staging published or prefix missing')
  local spent=registry.get().ledger.total
  ok,problem,control=shell.evaluate(rec,source,1,2,checkpoint)
  assert(not ok and control=='wait' and registry.get().ledger.total==spent)
  local tick=2
  repeat
    ok,problem,control=shell.evaluate(rec,source,tick,2,checkpoint)
    assert(ok or control=='wait',problem and problem.message)
    assert(ok or rec.shell.values==committed,'unfinished command committed scratch values')
    tick=tick+1; assert(tick<200)
  until ok
  assert(rec.state.prefix==1)
  local checked,check_error=shell.evaluate(rec,'assert(x==300000); print("after")',tick,3,{})
  assert(checked,check_error and check_error.message); tick=tick+1
  local before,after=0,0
  for _,entry in ipairs(rec.logs) do
    if entry.text=='Shell #2 output: before' then before=before+1 end
    if entry.text=='Shell #3 output: after' then after=after+1 end
  end
  assert(before==1 and after==1,'command effect replayed')
  for _,case in ipairs({{source='nil',count=1},{source='false',count=1},
    {source='false,nil,3',count=3},
    {source='print("one")',count=0},{source='computer.setState("void",true)',count=0}}) do
    local state={}; local passed,diagnostic=shell.evaluate(rec,case.source,tick,4,state)
    assert(passed,diagnostic and diagnostic.message)
    assert(state.result and state.result.n==case.count,'expression result arity changed')
    tick=tick+1
  end
  local passed,diagnostic=shell.evaluate(rec,'a,b,c=1,nil,false; a,b=b,a; a,a=4,5; assert(a==4 and b==1 and c==false); a,b,c=nil,nil,nil',tick,5,{})
  assert(passed,diagnostic and diagnostic.message)
end
return M
