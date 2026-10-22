-- Executability is validated before retiring the previous active generation.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local model=require('scripts.ui.editor-model')
local editor_contract=require('tests.editor_contract')
local M={}
function M.run()
  registry.initialize()
  local entity=assert(game.surfaces[1].create_entity{name='constant-combinator',position={0,0},force='player'})
  local rec=registry.register('computer',entity)
  local source=[[function start()
    computer.setState('accepted',true)
    computer.every(3600,'later'); computer.on('power_restored','later')
  end
  function later() computer.setState('later',true) end]]
  runtime.save(rec.id,source,0); assert(runtime.activate(rec.id,game.tick))
  assert(scheduler.dispatch(rec,game.tick) and rec.state.accepted and rec.status=='running')
  assert(runtime.enqueue(rec,'later',{name='fixture'},game.tick))
  local before={run=rec.run_id,active=rec.active,queue=rec.queue,queue_bytes=rec.queue_bytes,
    first=rec.queue[1],timers=rec.timers,subscriptions=rec.subscriptions,generation=rec.run_generation,state=rec.state}
  local player=editor_contract.player(1,entity)
  local session,draft=model.open(player,rec.id)
  model.edit(player,session.token,'function start() computer.setState("validation_ran",true) end')
  local message,e=model.action(player,session.token,'validate',game.tick)
  assert(message and e==nil and session.validation.diagnostic==nil and rec.state.validation_ran==nil)
  for _,candidate in ipairs({
    'function start() local t={value=1}; computer.setState("unsafe",true) end',
    'function start() local function helper() return 1 end; computer.setState("unsafe",helper()) end',
    'return {api_version=1,handlers={start=function() local f=function() return 1 end; computer.setState("unsafe",f()) end}}',
  }) do
    -- These are valid supported front-end programs, but the current early
    -- continuation lowerer explicitly does not implement their constructs yet.
    local native,e=compiler.compile(candidate,admission.context(admission.new(),'candidate-grammar',game.tick))
    assert(native,e and e.message)
    model.edit(player,session.token,candidate)
    local message,problem=model.action(player,session.token,'validate',game.tick)
    assert(not message and problem and problem.code=='E_UNSUPPORTED' and draft.source==candidate)
    runtime.save(rec.id,candidate,rec.saved_revision)
    local ledger=registry.get().ledger; local spent=ledger.total
    local run,problem=runtime.activate(rec.id,game.tick,rec.saved_revision)
    assert(not run and problem and problem.code=='E_UNSUPPORTED','unexecutable continuation candidate retired the active run')
    assert(problem.line and problem.column and rec.candidate_diagnostic==problem)
    assert(rec.run_id==before.run and rec.active==before.active and rec.run_generation==before.generation and rec.status=='running')
    assert(rec.queue==before.queue and rec.queue[1]==before.first and rec.queue_bytes==before.queue_bytes)
    assert(rec.timers==before.timers and next(rec.timers) and rec.subscriptions==before.subscriptions and next(rec.subscriptions))
    assert(rec.state==before.state and rec.state.accepted and rec.state.unsafe==nil)
    assert(registry.get().ledger==ledger and ledger.total>spent,'candidate preparation reset or skipped paid work')
  end
  log('TC_CONTRACT continuation-preparation-before-active-generation-retirement')
end
return M
