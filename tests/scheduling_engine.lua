-- Production scheduler, actual ticks and separate cold server processes.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local admission=require('scripts.runtime.admission')
local M={}
local resume=false
local source=[[
function start()
  computer.setState('boots',(computer.getState('boots') or 0)+1)
  computer.setState('order','')
  computer.after(4,'once')
  computer.every(3,'periodic')
  local id=computer.after(5,'canceled')
  computer.setState('cancel',id); assert(computer.cancelTimer(id))
end
function once(e) computer.setState('once',(computer.getState('once') or 0)+1) end
function periodic(e)
  if not computer.getState('first_scheduled') then
    computer.setState('first_scheduled',e.scheduled_tick); computer.setState('first_missed',e.missed)
    computer.setState('first_dispatch',e.tick)
  end
  computer.setState('periods',(computer.getState('periods') or 0)+1)
end
function message(e) computer.setState('order',computer.getState('order')..e.tag) end
function canceled() error('canceled timer replayed') end
]]
local function copy(v)
  if type(v)~='table' then return v end
  local t={}; for k,x in pairs(v) do t[k]=copy(x) end; return t
end
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local function snapshot()
  local root=registry.get(); local x=storage.tc_scheduling
  local c=registry.computer(x.id)
  return {scheduler=copy(root.scheduler),ledger=copy(root.ledger),sequence=root.next_sequence,
    queue=copy(c.queue),timers=copy(c.timers),state=copy(c.state),run=c.run_id,
    last_dispatch_tick=c.last_dispatch_tick}
end
function M.run()
  local function build(x)
    local body=assert(game.surfaces[1].create_entity{name=defs.devices.computer.entity_name,position={x,0},force='player'})
    local c=assert(lifecycle.build(body))
    local power=lifecycle.power_entity(c)
    if power then power.energy=1000000 end
    runtime.save(c.id,source,0); assert(runtime.activate(c.id,game.tick))
    return c
  end
  local c=build(0); local stopped=build(4); local faulted=build(8)
  runtime.stop(stopped.id)
  runtime.fault(faulted,{code='E_PROGRAM',message='intentional stopped fixture'},game.tick)
  storage.tc_scheduling={phase='armed',id=c.id,stopped=stopped.id,faulted=faulted.id}
end
function M.on_load()
  resume=storage.tc_scheduling.phase=='frozen'
  if resume then
    assert(equal(snapshot(),storage.tc_scheduling.expected),'cold load changed scheduling, queue or credits')
    log('TC_SCHEDULING_LOAD_UNCHANGED')
  end
end
function M.on_configuration_changed() error('ordinary cold fixture is not old-archive upgrade acceptance') end
function M.on_tick(event)
  local x=storage.tc_scheduling; local c=registry.computer(x.id); local root=registry.get()
  if x.phase=='frozen' then
    if not resume then return end
    assert(equal(snapshot(),x.expected))
    scheduler.tick(x.tick)
    assert(equal(snapshot(),x.expected),'same-tick cold dispatch renewed credits or replayed work')
    assert(c.queue==x.queue and c.timers==x.timers and root.scheduler==x.scheduler)
    local ctx=admission.context(root.ledger,c.id,x.tick)
    assert(ctx.machine.work==x.work and ctx.ledger.total==x.total)
    resume=false; x.phase='resumed'; x.resume_tick=event.tick
    log('TC_SCHEDULING_COLD_RETAINED ready deadlines FIFO aliases spent-credits stopped faulted')
  end
  if x.phase=='armed' then
    scheduler.tick(event.tick)
    assert(c.state.boots==1 and c.status=='running',c.diagnostic and c.diagnostic.message)
    assert(c.timers[c.state.cancel]==nil)
    assert(runtime.enqueue(c,'message',{name='fixture',tag='a'},event.tick))
    assert(runtime.enqueue(c,'message',{name='fixture',tag='b'},event.tick))
    assert(root.scheduler.ready[c.id] and #root.scheduler.deadlines==1)
    assert(not root.scheduler.ready[x.stopped] and not root.scheduler.ready[x.faulted])
    x.queue=c.queue; x.timers=c.timers; x.scheduler=root.scheduler
    x.tick=event.tick; x.work=root.ledger.machines[c.id].work; x.total=root.ledger.total
    x.expected=snapshot(); x.phase='waiting-save'
    return
  end
  if x.phase=='waiting-save' then
    -- Deliberately freeze scheduler service so saved deadlines are overdue.
    if event.tick>=x.tick+8 then
      assert(equal(snapshot(),x.expected))
      x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
    end
    return
  end
  if x.phase=='resumed' then
    local power=lifecycle.power_entity(c)
    if power then power.energy=1000000 end
    scheduler.tick(event.tick)
    assert(c.status=='running',c.diagnostic and c.diagnostic.message)
    assert(c.state.boots==1 and registry.computer(x.stopped).status=='stopped' and registry.computer(x.faulted).status=='faulted')
    if event.tick>=x.tick+18 then
      assert(c.state.order=='ab' and c.state.once==1 and c.state.periods>=3)
      assert(c.state.first_scheduled==x.tick+3 and c.state.first_missed==math.floor((c.state.first_dispatch-x.tick-3)/3))
      assert(next(c.subscriptions)==nil and c.timers[c.state.cancel]==nil)
      assert(#root.scheduler.deadlines==1 and root.scheduler.deadline_positions[c.id]==1)
      x.phase='done'; log('TC_SCHEDULING_DONE exact-once ordered callbacks canceled-deadline no-startup-replay')
      log('TC_COLD_OK')
    end
  end
end
return M
