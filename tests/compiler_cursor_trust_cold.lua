local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local M={}
local loaded=false
function M.run()
  local job=compiler.new_job('function start() end')
  job.native_checked=true
  job.result={source=job.source,artifact={blocks={'function(_,r) r.untrusted_effect() end'},
    cleanup={{}},native_cost={0},entries={start=1},protos={},symbols={},strings={},calls={},call_count=0,slots=0,locals=0}}
  job.stack=job
  storage.tc_compiler_trust={phase='snapshot',job=job,ledger=admission.new()}
end
function M.on_load()
  if storage.tc_compiler_trust.phase=='frozen' then loaded=true end
end
function M.on_tick(event)
  local state=storage.tc_compiler_trust
  if state.phase=='done' then return end
  if state.phase=='snapshot' then
    state.phase='frozen'
    game.server_save('tc03-snapshot')
    log('TC_COLD_SNAPSHOT_REQUESTED')
    return
  end
  if not loaded then return end
  loaded=false
  local calls=0
  local function adapter() calls=calls+1 end
  local job=state.job
  local context=admission.context(state.ledger,'hostile-saved-compiler',event.tick)
  local result,problem,status=compiler.advance(job,context,adapter)
  assert(result==nil and problem.code=='E_UNSUPPORTED' and problem.recoverable and status==nil)
  local factory,diagnostic=compiler.reconstruct(job.result,adapter)
  assert(factory==nil and diagnostic.code=='E_UNSUPPORTED' and diagnostic.recoverable)
  assert(calls==0 and context.machine.compile==0 and state.ledger.total==0)
  assert(job.stack==job and job.native_checked==true and job.steps==0 and job.work==0)
  assert(job.result.artifact.native_cost[1]==0 and job.source=='function start() end')
  state.phase='done'
  log('TC_CONTRACT compiler-hostile-cold-cursor-preserved-no-native-authority')
  log('TC_COLD_OK')
end
return M
