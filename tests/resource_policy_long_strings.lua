-- Byte/owner-bounded strings through real scheduling, state, timers and cold work.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local defs=require('scripts.device-definitions')
local data=require('scripts.runtime.data')
local sandbox=require('scripts.runtime.sandbox')
local memory=require('scripts.runtime.memory')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local M={}; local loaded=false
local source=[[function start()
  computer.setState('started',true)
end
function strings(event)
  local value,key=event.payload.value,event.payload.key
  assert(#value==21000 and #key==17001 and string.byte(value,3)==0)
  local reversed=string.reverse(value)
  assert(#reversed==21000 and string.sub(reversed,1,3)=='\0bA')
  assert(string.reverse(reversed)==value)
  local upper=string.upper(value)
  assert(string.sub(upper,1,3)=='AB\0' and #upper==21000)
  assert(string.lower(upper)==string.lower(value))
  assert(string.len(value)==21000 and tostring(value)==value)
  assert(string.sub(value,1,-21002)=='')
  local formatted=string.format('%s!',value)
  assert(#formatted==21001 and formatted==value..'!')
  assert(table.concat({value,'!'},'')==formatted)
  local first,last=string.find(formatted,'!',1,true)
  assert(first==21001 and last==21001)
  local record={[key]=value}
  computer.setState('text',record)
  local readback=computer.getState('text')
  assert(readback[key]==value and readback~=record)
  readback[key]='changed'
  assert(computer.getState('text')[key]==value)
  local ok,e=pcall(computer.setState,'too_big',{value,value,value,value})
  assert(not ok and e.code=='E_CAPACITY' and computer.getState('too_big')==nil)
  assert(computer.getState('text')[key]==value)
  local jumbo=string.rep(value,3)
  ok,e=pcall(computer.setState,'too_wide',{[jumbo]=jumbo})
  assert(not ok and e.code=='E_CAPACITY' and e.recoverable and e.resource=='atomic_allocations')
  assert(computer.getState('too_wide')==nil and computer.getState('text')[key]==value)
  computer.after(1,'checked',{key=key,value=value})
end
function checked(event)
  assert(computer.getState('text')[event.payload.key]==event.payload.value)
  assert(computer.deleteState('text'))
  computer.setState('done',true)
end]]
local function state() return storage.long_string_policy_fixture end
local function copy_boundary()
  local account=memory.new(1000000,256); local owner=memory.owner(account)
  local ledger=admission.new(); local pending={}
  local checkpoint={owned={},owned_order={},symbols={},bindings={},functions={}}
  local input={string.rep('x',limits.callback_allocations-1)}
  local result,paid
  for tick=0,4 do
    local context=admission.context(ledger,'string-copy-boundary',tick); context.memory_owner=owner
    local g=sandbox.new(context,{},nil,checkpoint); g.call_checkpoint(pending,{})
    local ok,value=pcall(g.snapshot,input,'boundary')
    if ok then result=value; break end
    assert(g.work_suspended(),'fitting copy step refused instead of deferring')
    local frame=pending.jobs.boundary.stack[1]
    if frame.copy_paid then
      assert(frame.result[1]==nil and context.machine.allocations==limits.callback_allocations)
      paid=true
    end
  end
  assert(paid and result and result~=input and result[1]==input[1],'paid copy restarted before owned publication')
  local context=admission.context(ledger,'string-copy-boundary',5); context.memory_owner=owner
  local g=sandbox.new(context,{},nil,checkpoint)
  local ok,e=pcall(g.snapshot,string.rep('y',limits.callback_allocations+1))
  local diagnostic=errors.resource_diagnostic(e)
  assert(not ok and diagnostic and diagnostic.resource=='atomic_allocations' and not g.work_suspended())
  ok,e=pcall(g.snapshot,{[string.rep('y',limits.callback_allocations+1)]=true})
  diagnostic=errors.resource_diagnostic(e)
  assert(not ok and diagnostic and diagnostic.resource=='atomic_allocations' and not g.work_suspended())
  memory.close(owner,function() end)
  assert(next(account.values)==nil and account.reserved==0)
  log('TC_CONTRACT string-copy-paid-step-publication-refusal-and-owner-release')
end
function M.run()
  copy_boundary()
  local value=string.rep('Ab\0',7000); local key='k'..string.rep('q',17000)
  local input={[key]=value}
  local copy,stats=data.copy(input,function() end)
  assert(copy~=input and copy[key]==value and stats.bytes>16384)
  local ok,e=pcall(data.copy,input,function() end,stats.bytes-1)
  assert(not ok and e.code=='E_CAPACITY' and input[key]==value)
  assert(data.copy(input,function() end,stats.bytes)[key]==value)
  log('TC_CONTRACT byte-bounded-long-data-keys-values-and-exact-capacity-refusal')
  registry.initialize()
  local body=assert(game.surfaces[1].create_entity{name=defs.devices.computer.entity_name,position={0,0},force='player'})
  local rec=assert(lifecycle.build(body)); lifecycle.power_entity(rec).energy=1000000; rec.powered=true
  assert(runtime.save(rec.id,source,rec.saved_revision)); assert(runtime.activate(rec.id,game.tick))
  assert(runtime.enqueue(rec,'strings',{name='strings',payload={key=key,value=value}},game.tick))
  storage.long_string_policy_fixture={id=rec.id,phase='running',started=game.tick,run_id=rec.run_id}
end
function M.on_load()
  local s=state()
  if s and s.phase=='frozen' then
    local rec=assert(registry.record(s.id))
    local frame=rec.invocation.checkpoint.frame
    local job=frame.library.job
    assert(frame.library.name=='string.reverse' and job.bytes==s.bytes and job.index==s.index)
    assert(rec.run_id==s.run_id and not rec.state.done)
    assert(registry.get().ledger.tick==s.tick and registry.get().ledger.total==s.work)
    loaded=true
  end
end
function M.on_tick(event)
  local s=state(); if not s or s.phase=='done' or s.phase=='frozen' and not loaded then return end
  local rec=assert(registry.record(s.id))
  assert(event.tick-s.started<400,'long-string fixture deadline: '..serpent.line(rec.diagnostic))
  if loaded then loaded=false; s.phase='resumed'; log('TC_CONTRACT cold-string-transform-paid-frontier-and-ledger-preserved') end
  lifecycle.power_entity(rec).energy=1000000; rec.powered=true
  scheduler.tick(event.tick)
  assert(rec.status=='running' and not rec.diagnostic,serpent.line(rec.diagnostic))
  if s.phase=='running' and rec.invocation then
    local frame=rec.invocation.checkpoint.frame
    local library=frame.library
    if library and library.name=='string.reverse' and library.job.bytes>0 and not frame.results then
      s.bytes=library.job.bytes; s.index=library.job.index; s.phase='frozen'
      s.tick=registry.get().ledger.tick; s.work=registry.get().ledger.total
      assert(rec.invocation.memory_owner.values[frame.args[1]],'long input lost its lifetime owner')
      game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
    end
  end
  if rec.state.done and not rec.invocation then
    assert(s.phase=='resumed' and rec.state.started and not rec.state.text and not rec.state.too_big)
    assert(#rec.queue==0 and (not rec.dropped_events or rec.dropped_events.total==0))
    assert(runtime.stop(rec.id)); s.phase='done'
    log('TC_CONTRACT long-string-library-state-event-timer-defensive-copy-and-refusal')
    log('TC_COLD_OK')
  end
end
return M
