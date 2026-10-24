local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local continuation=require('scripts.runtime.continuation')
local limits=require('scripts.runtime.limits')
local contracts=require('tests.compiler_jobs')
local M={}; local loaded=false
local target='vendor.phobos.parser'
function M.stage(module) target=module; return M end
-- Explicit test-only workspace adapter; this is not host-memory integration acceptance.
local function test_workspace() end
local function frozen(f)
  assert(f.job.steps==f.steps and f.job.work==f.work and f.job.wait_tick==f.tick)
  assert(f.ledger.total==f.spent and f.job.stack[#f.job.stack].pc==f.pc)
end
function M.run()
  local source='function start() local n=0;\n'..string.rep('n=n+1; -- exceeds former source/token/node caps\n',900)..' computer.finished(n) end'
  storage.tc_compiler_job={phase='compile',source=source,job=compiler.new_job(source),ledger=admission.new(),ticks=0,target=target}
  game.speed=100
end
function M.on_load()
  local f=storage.tc_compiler_job
  if f.phase=='frozen' then frozen(f); loaded=true; log('TC_COMPILER_JOB_ON_LOAD_UNCHANGED') end
end
function M.on_tick(event)
  local f=storage.tc_compiler_job
  if f.phase=='done' or f.phase=='frozen' and not loaded then return end
  if loaded then
    frozen(f)
    local ctx=admission.context(f.ledger,'compiler-cold',f.tick)
    assert(select(3,compiler.advance(f.job,ctx,test_workspace))=='wait'); frozen(f)
    loaded=false; f.phase='resume'
  end
  f.ticks=f.ticks+1; assert(f.ticks<2000,'compiler failed to progress')
  local ctx=admission.context(f.ledger,'compiler-cold',event.tick)
  assert(admission.reserve(ctx,'compile',limits.compile_work-100000))
  local plan,e,status=compiler.advance(f.job,ctx,test_workspace)
  assert(not e,e and e.message)
  if not plan then
    assert(status=='wait')
    local frame=f.job.stack[2]
    if f.phase=='compile' and f.job.phase=='compile' and frame and frame.module==f.target then
      f.phase='frozen'; f.steps=f.job.steps; f.work=f.job.work; f.tick=event.tick; f.spent=f.ledger.total
      f.pc=f.job.stack[#f.job.stack].pc
      game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
    end
    return
  end
  assert(f.phase=='resume' and f.ticks>1 and plan.nodes>4096)
  local reference,problem,trace=contracts.drive(f.source,nil,false,100000)
  assert(reference,problem and problem.message)
  assert(contracts.generated(reference.artifact)==contracts.generated(plan.artifact))
  local reference_work=0; for _,step in ipairs(trace) do reference_work=reference_work+step.work end
  assert(reference_work==f.job.work,'cold compiler changed accounting')
  -- Exercise the produced native blocks through the existing ABI, not an alternate guest runtime.
  local effects=0; local checkpoint={}; local native_work=0
  local factory=compiler.reconstruct(plan,function(cost,guard) native_work=native_work+cost; guard.spend(1) end)
  for tick=event.tick+1,event.tick+2000 do
    local context=admission.context(f.ledger,'compiler-execute',tick)
    local ok,problem,control=continuation.run(f.source,factory,'start',{},function(guard)
      return {computer={finished=function(value)
        guard.prepare_empty_result(); assert(value==900); effects=effects+1
      end}}
    end,context,checkpoint)
    if ok then break end
    assert(not problem and control=='wait',problem and problem.message)
  end
  assert(effects==1 and native_work>0)
  f.phase='done'; log('TC_CONTRACT compiler-cold-paid-parser-progress-native-block-result')
  log('TC_COLD_OK')
end
return M
