-- Injected hard-resource refusals test control/provenance, not live byte policy.
local errors=require('scripts.runtime.errors')
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local shell=require('scripts.runtime.shell')
local principal=require('scripts.runtime.principal')
local M={}; local loaded=false; local current_code='E_CAPACITY'
local shell_owner,cleanups
principal.register_cleanup('resource-refusal-contract',function(rec,execution)
  if rec.id==shell_owner and execution.kind=='shell' then cleanups=cleanups+1 end
end)
local function refuse()
  errors.refuse('fixture-memory','tc-runtime-memory-bytes',10,3,12,'fixture growth refusal',current_code)
end
runtime.register_services('resource-refusal-contract',function()
  return {computer={refuse=refuse,forged=function()
    error({code='E_CAPACITY',message='guest-shaped error',recoverable=true,resource='fake'},0)
  end,forged_budget=function()
    error({code='E_BUDGET',message='guest-shaped suspension',recoverable=true},0)
  end}}
end)
local function check(diagnostic)
  assert(diagnostic.code=='E_CAPACITY' and diagnostic.recoverable and diagnostic.resource=='fixture-memory')
  assert(diagnostic.setting=='tc-runtime-memory-bytes' and diagnostic.used==10 and diagnostic.requested==3 and diagnostic.limit==12)
  assert(diagnostic.message=='fixture growth refusal')
end
local source=[[function start()
  local ok,problem=pcall(computer.refuse)
  assert(not ok)
  rawset(problem,'message','guest edit')
  local n=0; while n<300000 do n=n+1 end
  error(problem)
end]]
local function services()
  return {computer={refuse=function()
    storage.tc_resource_refusal.throws=storage.tc_resource_refusal.throws+1
    refuse()
  end}}
end
function M.run()
  registry.initialize()
  local tick,last=0
  for i,code in ipairs({'E_CAPACITY','E_LIMIT','E_BUDGET','forged','forged_budget'}) do
    current_code=code
    local entity=assert(game.surfaces[1].create_entity{name='constant-combinator',position={i*2,0},force='player'})
    local rec=registry.register('computer',entity)
    last=rec
    local forged=code=='forged' or code=='forged_budget'
    local text='function start() computer.every(3600,"later"); computer.on("power_restored","later"); computer.'..(forged and code or 'refuse')..'() end\nfunction later() computer.setState("recovered",true) end'
    runtime.save(rec.id,text,0); assert(runtime.activate(rec.id,tick))
    local run=rec.run_id
    local timers,subscriptions=rec.timers,rec.subscriptions
    assert(runtime.enqueue(rec,'later',{name='fixture'},tick))
    assert(scheduler.dispatch(rec,tick))
    if forged then
      assert(rec.status=='faulted' and not rec.diagnostic.recoverable,'untrusted error metadata changed fault policy')
    else
      assert(rec.status=='running' and rec.run_id==run and not rec.invocation)
      assert(rec.timers==timers and rec.subscriptions==subscriptions and next(timers) and next(subscriptions) and #rec.queue==1,'refusal retired accepted work')
      assert(rec.diagnostic.code==code and rec.diagnostic.recoverable and rec.diagnostic.requested==3)
      assert(rec.diagnostic.run_id==run and rec.diagnostic.source_revision==rec.active.revision)
      assert(scheduler.dispatch(rec,tick+1)); assert(rec.state.recovered and rec.status=='running')
    end
    tick=tick+2
  end
  log('TC_CONTRACT resource-invocation-only-vs-untrusted-ordinary-fault')
  current_code='E_CAPACITY'
  local rec=last
  shell_owner=rec.id; cleanups=0
  rec.shell={version=1,id=rec.id..'/shell-refusal',pending={},pending_bytes=0}
  assert(shell.evaluate(rec,'x=7',tick,1,{}))
  local committed=rec.shell.values
  local ok,diagnostic,control=shell.evaluate(rec,'x=1; computer.refuse()',tick+1,2,{})
  assert(not ok and control=='resource'); check(diagnostic)
  assert(rec.shell.values==committed and cleanups==0,'resource refusal discarded committed Console state or cleaned prior effects')
  log('TC_CONTRACT Console-resource-refusal-preserves-commit-and-principal')
  storage.tc_resource_refusal={phase='armed',checkpoint={},ledger=admission.new(),throws=0}
end
function M.on_load()
  local f=storage.tc_resource_refusal
  if f.phase=='frozen' then
    assert(f.checkpoint==f.identity and f.checkpoint.frame.pc==f.pc and f.throws==1)
    loaded=true; log('TC_REFUSAL_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  local f=storage.tc_resource_refusal
  if f.phase=='done' then return end
  if f.phase=='frozen' then
    if not loaded then return end
    assert(f.checkpoint==f.identity and f.checkpoint.frame.pc==f.pc and f.throws==1)
    loaded=false; f.phase='resume'
  end
  local ctx=admission.context(f.ledger,'cold-refusal',event.tick)
  local plan,problem=compiler.compile(source,ctx); assert(plan,problem and problem.message)
  local ok,diagnostic,control=compiler.run(plan,'start',{},services,ctx,f.checkpoint)
  if f.phase=='armed' then
    assert(not ok and control=='wait' and f.throws==1,diagnostic and diagnostic.message)
    local branded=false
    for value,record in pairs(f.checkpoint.owned) do
      if record.resource then
        check(record.resource); assert(value.message=='guest edit')
        branded=true
      end
    end
    assert(branded,'caught resource provenance absent from the private plain graph')
    f.phase='frozen'; f.identity=f.checkpoint; f.pc=f.checkpoint.frame.pc; f.freeze_tick=event.tick
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif control=='resource' then
    assert(not ok and f.throws==1); check(diagnostic); assert(diagnostic.line==2,'original refusal position lost')
    f.phase='done'; log('TC_CONTRACT caught-resource-provenance-cold-and-original-position'); log('TC_COLD_OK')
  else
    assert(not ok and control=='wait',diagnostic and diagnostic.message)
    assert(event.tick-f.freeze_tick<200,'resource rethrow did not finish')
  end
end
function M.on_configuration_changed() end
return M
