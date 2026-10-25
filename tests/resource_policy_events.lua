-- Queue pressure loses only the newest delivery, never the accepted run.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local limits=require('scripts.runtime.limits')
local M={}
local loaded=false
local serial=0
local function computer(pending)
  serial=serial+1
  local entity=assert(game.surfaces[1].create_entity{name='constant-combinator',position={serial*2,0},force='player'})
  local rec=registry.register('computer',entity)
  runtime.save(rec.id,'function start() computer.setState("kept",true); computer.setState("starts",(computer.getState("starts") or 0)+1) end\nfunction receive() end',0)
  assert(runtime.activate(rec.id,game.tick))
  if not pending then assert(scheduler.dispatch(rec,game.tick) and rec.state.kept) end
  return rec
end
local function preserved(rec,before,total,reason)
  assert(rec.status=='running' and rec.run_id==before.run and rec.active==before.active)
  assert(rec.state==before.state and rec.state.kept and rec.timers==before.timers and rec.subscriptions==before.subscriptions)
  assert(rec.queue==before.queue and rec.queue_bytes==before.bytes and rec.queue[1]==before.first)
  local drops=assert(rec.dropped_events,'queue overflow lacks durable loss diagnostics')
  assert(drops.total==total and drops.last_tick==game.tick and drops.last_reason==reason and not drops.saturated)
end
local function snapshot(rec)
  return {run=rec.run_id,active=rec.active,state=rec.state,timers=rec.timers,subscriptions=rec.subscriptions,
    queue=rec.queue,bytes=rec.queue_bytes,first=rec.queue[1]}
end
function M.run()
  registry.initialize()
  local burst=computer()
  for i=1,129 do
    assert(runtime.enqueue(burst,'receive',{name='fixture',value=i,empty={}},game.tick),'byte-admissible event rejected by the old count ceiling')
    assert(burst.queue[i].bytes>128,'event envelope/entry metadata was not charged')
  end
  assert(#burst.queue==129 and burst.queue_bytes<=limits.event_queue_bytes and not burst.dropped_events)
  local bytes=limits.event_queue_bytes
  local ok,problem=pcall(function()
    limits.event_queue_bytes=1
    local started=computer()
    assert(started.state.starts==1 and #started.queue==0 and not started.dropped_events,'lifecycle start was dropped as an event')
    local pending_start=computer(true)
    assert(pending_start.invocation and pending_start.invocation.pending_start and not pending_start.state.kept)
    limits.event_queue_bytes=bytes
    local rec=computer()
    assert(runtime.enqueue(rec,'receive',{name='fixture',value=1},game.tick))
    limits.event_queue_bytes=rec.queue_bytes
    local before=snapshot(rec)
    local accepted,reason=runtime.enqueue(rec,'receive',{name='fixture',value=2},game.tick)
    assert(not accepted and reason=='overflow','full byte allowance admitted another event')
    preserved(rec,before,1,'event_queue_bytes')
    assert(rec.dropped_events.last_kind=='fixture')
    assert(not runtime.enqueue(rec,'receive',{name='fixture',value=3},game.tick))
    preserved(rec,before,2,'event_queue_bytes')
    limits.event_queue_bytes=bytes
    rec=computer()
    local item=assert(runtime.prepare_event(rec,'receive',{name='fixture',value=1},game.tick))
    limits.event_queue_bytes=item.bytes
    assert(runtime.publish_event(rec,item,game.tick),'exact queue-byte boundary refused')
    before=snapshot(rec)
    limits.event_queue_bytes=rec.queue_bytes+item.bytes-1
    accepted,reason=runtime.enqueue(rec,'receive',{name='fixture',value=2},game.tick)
    assert(not accepted and reason=='overflow')
    preserved(rec,before,1,'event_queue_bytes')
    limits.event_queue_bytes=1
    accepted,reason=runtime.enqueue(rec,'receive',{name='fixture',value=string.rep('x',100)},game.tick)
    assert(not accepted and reason=='overflow','oversized preparation escaped as an ordinary fault')
    preserved(rec,before,2,'event_queue_bytes')
    local pending=assert(runtime.prepare_event(rec,'receive',{name='fixture'},game.tick))
    assert(pending.overflow=='event_queue_bytes' and rec.dropped_events.total==2,'preparation counted an uncommitted loss')
    assert(not runtime.publish_event(rec,pending,game.tick))
    preserved(rec,before,3,'event_queue_bytes')
    local cold_rec=rec
    limits.event_queue_bytes=bytes
    rec=computer()
    runtime.subscribe(rec,'modem_message','receive')
    runtime.subscribe(rec,'modem_message','receive')
    runtime.subscribe(rec,'modem_message','receive')
    assert(runtime.enqueue(rec,'receive',{name='fixture'},game.tick))
    limits.event_queue_bytes=rec.queue_bytes
    before=snapshot(rec)
    assert(not runtime.emit(rec.id,'modem_message',{message='new'},game.tick))
    preserved(rec,before,3,'event_queue_bytes')
    rec.timers.once={id=rec.run_id..'/timer-fixture-once',handler='receive',deadline=game.tick,sequence=1}
    rec.timers.recurring={id=rec.run_id..'/timer-fixture-recurring',handler='receive',deadline=game.tick,sequence=2,interval=2}
    -- Timers are normally indexed by their actual IDs.
    local once,recurring=rec.timers.once,rec.timers.recurring
    rec.timers={ [once.id]=once,[recurring.id]=recurring }
    local losses=rec.dropped_events.total
    scheduler.advance_timers(rec,game.tick,function() end)
    assert(rec.timers[once.id]==nil and recurring.deadline==game.tick+2 and rec.dropped_events.total==losses+2)
    scheduler.advance_timers(rec,game.tick,function() end)
    assert(rec.dropped_events.total==losses+2,'dropped timer retried on the same tick')
    before=snapshot(rec); losses=rec.dropped_events.total
    limits.event_queue_bytes=1
    assert(not runtime.emit(rec.id,'modem_message',{message=string.rep('x',100)},game.tick))
    preserved(rec,before,losses+3,'event_queue_bytes')
    local total=rec.dropped_events.total
    local called,failure=pcall(runtime.enqueue,rec,'absent',{name='fixture'},game.tick)
    assert(not called and failure.code=='E_ARGUMENT' and rec.dropped_events.total==total,'invalid authority counted as queue loss')
    local sentinel={}
    called,failure=pcall(runtime.enqueue,rec,'receive',{name='fixture'},game.tick,function() error(sentinel,0) end)
    assert(not called and failure==sentinel and rec.dropped_events.total==total,'work deferral counted as event loss')
    rec.dropped_events.total=9007199254740991
    assert(not runtime.enqueue(rec,'receive',{name='fixture'},game.tick))
    assert(rec.dropped_events.total==9007199254740991 and rec.dropped_events.saturated)
    limits.event_queue_bytes=bytes
    local drops=rec.dropped_events
    assert(runtime.stop(rec.id)); runtime.reset_state(rec.id)
    assert(runtime.activate(rec.id,game.tick) and rec.dropped_events==drops and drops.saturated,'Stop/reset/Run reset physical loss diagnostics')
    local power=computer()
    runtime.subscribe(power,'power_restored','receive')
    assert(runtime.enqueue(power,'receive',{name='timer'},game.tick))
    assert(runtime.set_power(power.id,false,game.tick))
    before=snapshot(power); limits.event_queue_bytes=power.queue_bytes
    assert(runtime.set_power(power.id,true,game.tick))
    preserved(power,before,1,'event_queue_bytes')
    assert(power.dropped_events.last_kind=='power_restored' and power.needs_input_resync)
    assert(not runtime.set_power(power.id,true,game.tick) and power.dropped_events.total==1)
    limits.event_queue_bytes=bytes
    storage.tc_event_drops={phase='arm',rec=cold_rec,drops=cold_rec.dropped_events,queue=cold_rec.queue,
      first=cold_rec.queue[1],bytes=cold_rec.queue_bytes,run=cold_rec.run_id,total=cold_rec.dropped_events.total,
      start=pending_start,start_invocation=pending_start.invocation,burst=burst,burst_queue=burst.queue,burst_bytes=burst.queue_bytes}
    log('TC_CONTRACT event-drop-newest-boundaries-oversized-fanout-and-durable-counters')
  end)
  limits.event_queue_bytes=bytes
  assert(ok,type(problem)=='table' and problem.message or tostring(problem))
end
local function unchanged(state)
  local rec=state.rec
  assert(state.burst.queue==state.burst_queue and #state.burst.queue==129 and state.burst.queue_bytes==state.burst_bytes)
  for i,item in ipairs(state.burst.queue) do assert(item.event.value==i and next(item.event.empty)==nil) end
  assert(rec.status=='running' and rec.run_id==state.run and rec.state.kept)
  assert(rec.queue==state.queue and rec.queue[1]==state.first and rec.queue_bytes==state.bytes)
  assert(rec.dropped_events==state.drops and state.drops.total==state.total)
  assert(not state.start.state.kept and state.start.invocation==state.start_invocation and state.start.invocation.pending_start)
end
function M.on_load()
  local state=storage.tc_event_drops
  if state and state.phase=='frozen' then unchanged(state); loaded=true; log('TC_EVENT_LOSS_ON_LOAD_UNCHANGED') end
end
function M.on_tick(event)
  local state=storage.tc_event_drops
  if state.phase=='done' or state.phase=='frozen' and not loaded then return end
  unchanged(state)
  if state.phase=='arm' then
    state.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  assert(loaded); loaded=false
  local allowance=limits.event_queue_bytes; limits.event_queue_bytes=1
  assert(not runtime.enqueue(state.burst,'receive',{name='fixture'},event.tick))
  unchanged(state)
  assert(state.burst.dropped_events.total==1 and state.burst.dropped_events.last_reason=='event_queue_bytes')
  limits.event_queue_bytes=allowance
  assert(runtime.enqueue(state.rec,'receive',{name='fixture',value='after cold load'},event.tick))
  assert(state.rec.queue[1]==state.first and state.rec.queue[2].event.sequence>state.first.event.sequence)
  assert(state.drops.total==state.total)
  local bytes=limits.event_queue_bytes; limits.event_queue_bytes=1
  assert(scheduler.dispatch(state.start,event.tick) and state.start.state.kept and state.start.state.starts==1)
  assert(state.start.invocation==nil and #state.start.queue==0 and state.start.dropped_events==nil)
  limits.event_queue_bytes=bytes
  assert(runtime.enqueue(state.burst,'receive',{name='fixture',value=130,empty={}},event.tick))
  assert(#state.burst.queue==130 and state.burst.queue[130].event.sequence>state.burst.queue[129].event.sequence)
  state.phase='done'; log('TC_CONTRACT event-loss-counters-and-accepted-FIFO-cold-preserved'); log('TC_COLD_OK')
end
return M
