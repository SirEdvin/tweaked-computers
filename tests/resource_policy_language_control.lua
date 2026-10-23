-- Private controls must never enter guest handlers; ordinary refusals must.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local errors=require('scripts.runtime.errors')
local M={}
local function run(source)
  local plan,e=compiler.compile(source); assert(plan,e and e.message)
  local checkpoint,ledger,effects={},admission.new(),{handled=0,after=0}
  local function services(g)
    return {computer={
      refuse=function() errors.refuse('runtime_memory','tc-runtime-memory-bytes',10,1,10,'test memory refusal') end,
      atomic=function() g.atomic(9000000,0) end,
      handled=function() g.prepare_empty_result(); effects.handled=effects.handled+1 end,
      after=function() g.prepare_empty_result(); effects.after=effects.after+1 end,
      pause=function()
        local j=g.job('pause',function() return {paused=false} end)
        if not j.paused then g.spend(1); j.paused=true; g.suspend() end
        g.prepare_empty_result()
      end,
    }}
  end
  for tick=1,20 do
    local ok,problem,control=compiler.run(plan,'start',nil,services,admission.context(ledger,'refusal',tick),checkpoint)
    if control~='wait' then return ok,problem,control,effects end
    assert(effects.handled==0 and effects.after==0,'private suspension escaped protection')
  end
  error('control fixture did not finish')
end
function M.run()
  local ok,e,control,effects=run([[function start()
    local outer,success,problem=pcall(xpcall,computer.refuse,function(e)
      assert(e.recoverable and e.resource=='runtime_memory')
      computer.handled(); return e
    end)
    assert(outer and not success and problem.setting=='tc-runtime-memory-bytes')
    local success,problem=pcall(computer.atomic)
    assert(not success and problem.recoverable and problem.resource=='atomic_work')
    computer.after()
  end]])
  assert(ok,e and e.message); assert(effects.handled==1 and effects.after==1)
  ok,e,control,effects=run('function start()\n computer.refuse()\n computer.after()\nend')
  assert(not ok and control=='resource' and e.recoverable and e.line==2 and effects.after==0)
  ok,e,control,effects=run([[function start()
    local ok=xpcall(function() computer.pause() end,function() computer.handled() end)
    assert(ok); computer.after()
  end]])
  assert(ok and effects.handled==0 and effects.after==1,e and e.message)
  ok,e,control,effects=run([[function start()
    pcall(xpcall,function() computer.stop() end,function() computer.handled() end)
    computer.after()
  end]])
  assert(not ok and control=='stop' and e.code=='E_STOP' and e.line==2 and effects.handled==0 and effects.after==0)
  ok,e,control,effects=run('function start()\n local ok,e=xpcall(error,error,"re-entry")\n assert(not ok and e.recoverable and e.resource=="call_depth" and e.line==2 and e.column>0)\n computer.after()\nend')
  assert(ok and effects.after==1,e and e.message)
  log('TC_CONTRACT private-suspension-stop-and-protected-refusal-locations')
end
return M
