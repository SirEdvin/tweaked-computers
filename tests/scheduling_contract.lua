-- Structural/runtime contract; native cold and client acceptance are separate.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local shell=require('scripts.runtime.shell')
shell.register_authority(function(rec,player,token) return player==1 and token==1 end) -- GUI authority double only.
local M={}
local serial=0
local function fresh()
  storage.tweaked_computers=nil
  return registry.initialize()
end
local function computer(source,tick)
  serial=serial+1
  local body=assert(game.surfaces[1].create_entity{name='constant-combinator',position={serial*2,40},force='player'})
  local rec=registry.register('computer',body)
  runtime.save(rec.id,source,0)
  assert(runtime.activate(rec.id,tick or 0))
  return rec
end
local function api(rec,tick)
  return runtime.services(rec,tick,{spend=function() end,check=function() end}).computer
end
function M.run()
  local total=0
  local function report(name) total=total+1; log('TC_CONTRACT scheduling-'..name) end
  local advance,dispatch=scheduler.advance_timers,scheduler.dispatch
  local visits={timers=0,dispatch=0}
  scheduler.advance_timers=function(...)
    visits.timers=visits.timers+1; return advance(...)
  end
  scheduler.dispatch=function(...)
    visits.dispatch=visits.dispatch+1; return dispatch(...)
  end
  local ok,problem=pcall(function()
    local root=fresh()
    local idle={}
    for i=1,32 do idle[i]=computer('function event(e) computer.setState("calls",(computer.getState("calls") or 0)+1) end') end
    scheduler.tick(0)
    visits.timers=0; visits.dispatch=0
    for tick=1,10 do scheduler.tick(tick) end
    assert(visits.timers==0,'idle timer discovery visits: '..visits.timers)
    assert(visits.dispatch==0,'idle dispatch discovery visits: '..visits.dispatch)
    assert(runtime.enqueue(idle[17],'event',{name='fixture'},11))
    scheduler.tick(11)
    assert(idle[17].state.calls==1 and visits.dispatch==1 and visits.timers==0)
    scheduler.tick(12); assert(visits.dispatch==1)
    report('idle-population-zero-visits-and-event-wakeup')

    root=fresh()
    local rec=computer('function event(e) computer.setState("scheduled",e.scheduled_tick); computer.setState("missed",e.missed) end')
    local a=api(rec,0)
    local once=a.after(100,'event')
    local recurring=a.every(100,'event')
    visits.timers=0; visits.dispatch=0
    for tick=0,99 do scheduler.tick(tick) end
    assert(visits.timers==0 and visits.dispatch==0,'future deadline visited its owner')
    scheduler.tick(100)
    assert(visits.timers==1 and rec.state.scheduled==100 and #rec.queue==1)
    assert(api(rec,100).cancelTimer(recurring) and not api(rec,100).cancelTimer(recurring))
    assert(not api(rec,100).cancelTimer(once) and #rec.queue==0)
    scheduler.tick(101); assert(visits.timers==1 and visits.dispatch==1)
    report('future-due-equal-deadlines-and-cancel-after-enqueue')

    root=fresh()
    rec=computer('function event(e) computer.setState("scheduled",e.scheduled_tick); computer.setState("missed",e.missed) end')
    a=api(rec,0); recurring=a.every(2,'event')
    -- An admitted queue item coalesces later intervals without replaying them.
    assert(runtime.enqueue(rec,'event',{name='fixture'},0))
    rec.last_dispatch_tick=10
    scheduler.advance_timers(rec,2,function() end)
    scheduler.advance_timers(rec,10,function() end)
    assert(#rec.queue==2 and rec.queue[2].event.scheduled_tick==2 and rec.queue[2].event.missed==4)
    assert(rec.timers[recurring].deadline==12)
    assert(api(rec,10).cancelTimer(recurring))
    report('aligned-overdue-recurring-coalescence')

    root=fresh()
    local peers={}
    for i=1,4 do
      peers[i]=computer('function event(e) computer.setState("calls",(computer.getState("calls") or 0)+1) end')
      runtime.enqueue(peers[i],'event',{name='fixture'},0)
      runtime.enqueue(peers[i],'event',{name='fixture'},0)
    end
    local order={}
    scheduler.dispatch=function(rec,tick)
      order[#order+1]=rec.id
      return dispatch(rec,tick)
    end
    scheduler.tick(0)
    for _,c in ipairs(peers) do assert(c.state.calls==1 and #c.queue==1) end
    local spent=root.ledger.total
    scheduler.tick(0); assert(root.ledger.total==spent and #order==4)
    -- A fully refused round still rotates, without faulting or renewing credits.
    admission.context(root.ledger,peers[1].id,1).ledger.total=limits.host_work_per_tick-limits.maintenance_work_per_tick
    scheduler.tick(1)
    for _,c in ipairs(peers) do assert(c.state.calls==1 and c.status=='running') end
    assert(order[5]~=order[1],'ready start did not rotate')
    scheduler.tick(2)
    assert(order[9]~=order[5],'refused ready round monopolized its head')
    for _,c in ipairs(peers) do assert(c.state.calls==2 and #c.queue==0) end
    report('ready-round-fairness-once-per-tick-and-refused-rotation')

    root=fresh()
    rec=computer('function event(e) computer.setState("program",(computer.getState("program") or 0)+1) end')
    runtime.enqueue(rec,'event',{name='fixture'},0)
    local command=shell.submit(rec,'computer.setState("shell",true)',1,1,0,false)
    assert(command and root.scheduler.ready[rec.id])
    scheduler.tick(0)
    assert(rec.state.shell and not rec.state.program and #rec.queue==1 and not shell.waiting(rec))
    scheduler.tick(1)
    assert(rec.state.program==1 and not root.scheduler.ready[rec.id])
    local sleeper=computer('function event(e) computer.setState("woke",true) end',2)
    runtime.enqueue(rec,'event',{name='fixture'},2)
    scheduler.dispatch=function(c,tick)
      if c==rec then assert(runtime.enqueue(sleeper,'event',{name='fixture'},tick)) end
      return dispatch(c,tick)
    end
    scheduler.tick(2)
    assert(rec.state.program==2 and not sleeper.state.woke and #sleeper.queue==1)
    scheduler.tick(3)
    assert(sleeper.state.woke and #sleeper.queue==0)
    scheduler.dispatch=dispatch
    report('program-console-arbitration-and-reentrant-next-round-wakeup')

    root=fresh()
    rec=computer('function event(e) end')
    a=api(rec,0)
    for i=1,200 do
      local id=a.after(i+1,'event'); assert(a.cancelTimer(id))
    end
    assert(#root.scheduler.deadlines==0 and next(root.scheduler.deadline_positions)==nil)
    runtime.enqueue(rec,'event',{name='fixture'},0)
    assert(root.scheduler.ready[rec.id])
    runtime.stop(rec.id)
    assert(not root.scheduler.ready[rec.id] and #root.scheduler.deadlines==0)
    report('bounded-cancellation-and-generation-retirement')

    root=fresh()
    rec=computer('function event(e) computer.setState("calls",(computer.getState("calls") or 0)+1) end')
    runtime.enqueue(rec,'event',{name='fixture'},0)
    api(rec,0).after(20,'event')
    local queue,timers,ledger=rec.queue,rec.timers,root.ledger
    local sequence=root.next_sequence
    root.scheduler.work_version=nil; root.scheduler.ready=nil
    root.scheduler.deadlines=nil; root.scheduler.deadline_positions=nil
    assert(registry.initialize()==root and rec.queue==queue and rec.timers==timers and root.ledger==ledger)
    assert(root.next_sequence==sequence and root.scheduler.ready_count==1 and #root.scheduler.deadlines==1)
    local ready,deadlines=root.scheduler.ready,root.scheduler.deadlines
    assert(registry.initialize()==root and root.scheduler.ready==ready and root.scheduler.deadlines==deadlines)
    scheduler.tick(0); assert(rec.state.calls==1)
    report('one-time-legacy-membership-without-queue-timer-or-ledger-reset')

    root=fresh()
    rec=computer('function event(e) error("unsupported membership executed") end')
    runtime.enqueue(rec,'event',{name='fixture'},0)
    queue=rec.queue; ledger=root.ledger; local total=ledger.total
    root.scheduler.work_version=999
    scheduler.tick(0)
    assert(rec.queue==queue and #queue==1 and rec.status=='running' and ledger.total==total)
    assert(root.scheduling_diagnostic.code=='E_UNSUPPORTED' and root.scheduler.last_tick==-1)
    assert(registry.initialize()==root and root.scheduler.work_version==999 and rec.queue==queue)
    report('unsupported-membership-is-inert-and-preserves-recovery')

    root=fresh()
    rec=computer('function event(e) end')
    runtime.enqueue(rec,'event',{name='fixture'},0)
    root.scheduler.ready[rec.id].next='missing'
    queue=rec.queue
    scheduler.tick(0)
    assert(rec.queue==queue and #queue==1 and not rec.last_dispatch_tick and root.scheduling_diagnostic.code=='E_UNSUPPORTED')
    report('malformed-ready-links-do-not-execute-or-loop')

    root=fresh()
    rec=computer('function event(e) computer.setState("calls",(computer.getState("calls") or 0)+1) end')
    runtime.enqueue(rec,'event',{name='fixture'},0)
    root.scheduler.ready[rec.id].generation=rec.generation+1
    scheduler.tick(0)
    assert(not rec.state.calls and root.scheduler.ready[rec.id].generation==rec.generation)
    scheduler.tick(1); assert(rec.state.calls==1 and root.scheduler.ready_count==0)
    report('stale-generation-refused-and-current-demand-requeued')

    root=fresh()
    peers={}
    for i=1,24 do
      local c=computer('function event(e) end')
      local a=api(c,0); local deadline=(i*7)%31+1
      peers[i]={rec=c,timer=a.after(deadline,'event'),deadline=deadline}
    end
    local function heap()
      local s=root.scheduler; local count=0
      for id,index in pairs(s.deadline_positions) do count=count+1; assert(s.deadlines[index].id==id) end
      assert(count==#s.deadlines)
      for i,item in ipairs(s.deadlines) do
        assert(s.deadline_positions[item.id]==i)
        if i>1 then
          local p=s.deadlines[math.floor(i/2)]
          assert(p.tick<item.tick or p.tick==item.tick and p.id<item.id)
        end
      end
    end
    heap()
    for i=2,24,2 do assert(api(peers[i].rec,0).cancelTimer(peers[i].timer)); heap() end
    for tick=0,32 do scheduler.tick(tick); heap() end
    assert(#root.scheduler.deadlines==0 and root.scheduler.ready_count==0)
    report('indexed-heap-arbitrary-insertion-removal-and-drain')

    root=fresh()
    peers={}
    for i=1,8 do
      peers[i]=computer('function event(e) computer.setState("calls",(computer.getState("calls") or 0)+1) end')
      runtime.enqueue(peers[i],'event',{name='fixture'},0)
    end
    local maintenance=limits.maintenance_work_per_tick
    limits.maintenance_work_per_tick=1 -- Fixture-only: one ready-node visit fits.
    local passed,failure=pcall(function()
      for tick=0,7 do scheduler.tick(tick) end
      for _,c in ipairs(peers) do assert(c.state.calls==1 and #c.queue==0,'partial ready snapshot starved a fitting item') end
      assert(root.scheduler.ready_count==0)
    end)
    limits.maintenance_work_per_tick=maintenance
    assert(passed,failure)
    report('partial-ready-round-under-one-visit-maintenance')

    root=fresh()
    rec=computer('function event(e) end')
    api(rec,0).after(1,'event')
    local timer_work=0
    scheduler.advance_timers(rec,1,function(n) timer_work=timer_work+n end)
    root=fresh(); peers={}
    for i=1,32 do
      local c=computer('function event(e) computer.setState("calls",(computer.getState("calls") or 0)+1) end')
      api(c,0).after(1,'event'); peers[i]=c
    end
    limits.maintenance_work_per_tick=timer_work+16
    passed,failure=pcall(function()
      scheduler.tick(1)
      local admitted=0; for _,c in ipairs(peers) do if next(c.timers)==nil then admitted=admitted+1 end end
      assert(admitted>0,'due inventory precharge starved every individually fitting timer')
      for tick=2,40 do scheduler.tick(tick) end
      for _,c in ipairs(peers) do assert(c.state.calls==1 and next(c.timers)==nil,'due peer starved or replayed') end
      assert(#root.scheduler.deadlines==0 and root.scheduler.ready_count==0)
    end)
    limits.maintenance_work_per_tick=maintenance
    assert(passed,failure)
    report('fitting-timers-progress-before-unrelated-due-inventory')
  end)
  scheduler.advance_timers=advance; scheduler.dispatch=dispatch
  if not ok then error(problem,0) end
  log('TC_CONTRACT_TOTAL '..total)
  return total
end
return M
