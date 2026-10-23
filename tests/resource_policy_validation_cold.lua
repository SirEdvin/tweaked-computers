-- Synthetic low credits, real cold processes and the actual compiler guard.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local M={}
local loaded=false
local function frozen(f)
  local c=f.checkpoint; local v=c.validation
  assert(v==f.validation and v.head==f.head and v.queue[v.head].value==f.garbage and v.queue[v.head].key==f.key)
  assert(c.frame.pc==f.pc and c.wait_tick==f.tick and f.ledger.tick==f.tick and f.ledger.total==f.total)
  assert(f.ledger.machines.validation.work==f.work and f.ledger.machines.validation.compile==f.compile)
end
function M.run()
  local source='function start() while true do end end'
  local ledger=admission.new(); local c={}
  local plan={source=source,api_version=1,compiler_version=limits.compiler_version}
  local ok,problem,control=compiler.run(plan,'start',{}, {},admission.context(ledger,'validation',0),c)
  assert(not ok and control=='wait',problem and problem.message)
  local garbage={}
  local shared=string.rep('x',1024)
  for i=1,2500 do garbage[i]=shared end
  garbage.self=garbage
  local keys={}; for k in pairs(garbage) do keys[#keys+1]=k end
  c.owned[garbage]={keys=keys}; c.owned_order[#c.owned_order+1]=garbage
  storage.tc_validation_fixture={phase='scan',checkpoint=c,garbage=garbage,plan=plan,ledger=ledger,
    saved_work=limits.callback_work,origin=game.tick,slices=0}
  game.speed=100
end
function M.on_load()
  local f=storage.tc_validation_fixture
  if f.phase=='frozen' then frozen(f); log('TC_VALIDATION_ON_LOAD_UNCHANGED'); loaded=true end
end
function M.on_tick(event)
  local f=storage.tc_validation_fixture
  if f.phase=='done' then return end
  if f.phase=='frozen' then
    if not loaded then return end
    frozen(f); f.phase='resume'
  end
  local c=f.checkpoint
  if event.tick==f.ledger.tick then
    local total=f.ledger.total
    local ok,problem,control=compiler.run(f.plan,'start',{}, {},admission.context(f.ledger,'validation',event.tick),c)
    assert(not ok and control=='wait' and f.ledger.total==total,problem and problem.message)
    return
  end
  limits.callback_work=4096
  local context=admission.context(f.ledger,'validation',event.tick)
  local ok,problem,control=compiler.run(f.plan,'start',{}, {},context,c)
  assert(not ok and control=='wait',problem and problem.message)
  assert(context.machine.work<=4096 and f.slices<2000,'checkpoint validation failed to advance within bounded slices')
  f.slices=f.slices+1
  if c.validation then
    if f.previous_validation then
      assert(c.validation==f.previous_validation and c.validation.head>=f.previous_head,'validation restarted a paid prefix')
    end
    f.previous_validation=c.validation; f.previous_head=c.validation.head
  end
  if f.phase=='resume' and c.validation then assert(c.frame.pc==f.pc,'guest ran during checkpoint validation') end
  if f.phase=='scan' and c.validation then
    local v=c.validation; local job=v.queue[v.head]
    if job.value==f.garbage and job.key~=nil then
      f.phase='frozen'; f.validation=v; f.head=v.head; f.key=job.key
      f.pc=c.frame.pc; f.tick=event.tick; f.total=f.ledger.total
      f.work=context.machine.work; f.compile=context.machine.compile
      game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
    end
  elseif f.phase=='resume' and not c.owned[f.garbage] then
    assert(c.validation==nil and c.frame.pc==f.pc
      and (c.collection~=nil and c.preparation=='collect' or c.collection==nil and c.preparation=='execute'),
      'guest ran before the paid preparation boundary: '..serpent.line({phase=c.preparation,collection=c.collection~=nil,pc=c.frame.pc,expected=f.pc}))
    assert(f.slices>2)
    limits.callback_work=f.saved_work
    f.phase='done'; log('TC_COLD_OK bounded-checkpoint-validation mid-table no-prefix-restart')
  end
end
function M.on_configuration_changed() end
return M
