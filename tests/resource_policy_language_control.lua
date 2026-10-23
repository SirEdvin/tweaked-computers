-- Private controls must never enter guest handlers; ordinary refusals must.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local errors=require('scripts.runtime.errors')
local memory=require('scripts.runtime.memory')
local policy=require('scripts.runtime.resource-policy')
local M={}
local function retained_refusal()
  for _,protect in ipairs({'pcall(grow)','xpcall(grow,function(e) return e end)'}) do
    local source=[[function start()
      local root={kept=true}
      local function grow() computer.tighten(); rawset(root,'new',true) end
      local ok,e=]]..protect..[[
      assert(not ok and e.recoverable and e.resource=='runtime_memory','missing protected memory refusal')
      assert(e.setting=='tc-runtime-memory-bytes' and e.line==3 and e.column>0,'refusal lost source location')
      assert(root.kept and root.new==nil)
      computer.relax(); computer.finished()
    end]]
    local plan,e=compiler.compile(source); assert(plan,e and e.message)
    local account=policy.runtime_account({}); local owner=memory.owner(account); local original_limit=account.limit
    local ledger=admission.new(); local checkpoint={}; local finished=0; local tightened=false
    local function services(g)
      return {computer={tighten=function()
        g.prepare_empty_result(); memory.configure(account,account.used+account.reserved); tightened=true
      end,relax=function() g.prepare_empty_result(); memory.configure(account,original_limit) end,
      finished=function() g.prepare_empty_result(); finished=finished+1 end}}
    end
    local ok,problem,control
    for tick=1,20 do
      local ctx=admission.context(ledger,'protected-retention',tick); ctx.memory_owner=owner
      ok,problem,control=compiler.run(plan,'start',nil,services,ctx,checkpoint)
      assert(ok or control=='wait',serpent.line{protect=protect,problem=problem,control=control})
      if ok then break end
    end
    assert(ok and tightened and finished==1,'real retained refusal escaped the protected call')
    memory.close(owner,function() end)
    assert(next(account.values)==nil and next(account.owners)==nil and account.reserved==0)
  end
  log('TC_CONTRACT actual-heap-refusal-unwinds-pcall-xpcall-with-source-location')
end
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
  retained_refusal()
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
