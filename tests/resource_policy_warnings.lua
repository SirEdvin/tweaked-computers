-- Real scheduler/log admission; native save/reload. No warning event or guest lane.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local policy=require('scripts.runtime.resource-policy')
local resources=require('scripts.ui.resource-status')
local limits=require('scripts.runtime.limits')
local M={}
local loaded=false
local MAX=9007199254740991
local function drop(rec,tick)
  local ok,reason=runtime.enqueue(rec,'receive',{name='timer'},tick)
  assert(not ok and reason=='overflow')
end
local function retained(s,tick)
  local rec=s.rec
  assert(rec.status=='running' and rec.run_id==s.run and rec.queue==s.queue and rec.queue[1]==s.first)
  assert(#rec.queue==1 and rec.queue_bytes==s.bytes and not rec.invocation)
  local status=resources.read(rec,tick)
  assert(status.resources.event_queue_entries.used==1 and status.resources.event_queue_entries.limit==1)
  assert(status.dropped_events.total==rec.dropped_events.total)
  status.dropped_events.total=0
  assert(policy.status(rec,tick).dropped_events.total==rec.dropped_events.total,'status exposes mutable diagnostics')
  assert(resources.details(resources.read(rec,tick)):find('Dropped events (cumulative):',1,true))
end
local function bounded(fn)
  local entries,logs,bytes,interval=limits.event_queue_entries,limits.console_entries,limits.console_bytes,limits.event_drop_warning_interval
  limits.event_queue_entries=1; limits.console_entries=1; limits.console_bytes=1024; limits.event_drop_warning_interval=10
  local ok,e=pcall(fn)
  limits.event_queue_entries,limits.console_entries,limits.console_bytes,limits.event_drop_warning_interval=entries,logs,bytes,interval
  assert(ok,type(e)=='table' and e.message or tostring(e))
end
function M.run()
  registry.initialize()
  bounded(function()
    local body=assert(game.surfaces[1].create_entity{name='constant-combinator',position={0,0},force='player'})
    local rec=registry.register('computer',body)
    runtime.save(rec.id,'function receive() local s=computer.getResourceStatus(); computer.setState("observed",s.dropped_events.total); s.dropped_events.total=0 end',0)
    assert(runtime.activate(rec.id,game.tick)); rec.powered=false
    assert(runtime.enqueue(rec,'receive',{name='timer'},game.tick))
    drop(rec,game.tick); drop(rec,game.tick)
    storage.tc_warnings={phase='first',rec=rec,run=rec.run_id,queue=rec.queue,first=rec.queue[1],bytes=rec.queue_bytes}
    assert(#rec.logs==0,'event publication must not perform unadmitted log work')
  end)
end
function M.on_load()
  local s=storage.tc_warnings
  if s and s.phase=='frozen' then
    assert(s.rec.dropped_events.warning_tick==s.warning_tick and s.rec.dropped_events.warning_pending)
    assert(#s.rec.logs==1 and s.rec.logs[1].text=='replacement')
    loaded=true; log('TC_WARNING_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  local s=storage.tc_warnings
  if s.phase=='done' or s.phase=='frozen' and not loaded then return end
  bounded(function()
    local rec,tick=s.rec,event.tick
    retained(s,tick)
    if s.phase=='first' then
      scheduler.tick(tick)
      assert(#rec.logs==1 and rec.logs[1].text:find('Dropped events (cumulative): 2',1,true),'scheduler omitted overflow warning')
      assert(rec.dropped_events.warning_tick==tick and not rec.dropped_events.warning_pending)
      local spent=registry.get().scheduler.maintenance_spent
      scheduler.tick(tick)
      assert(#rec.logs==1 and registry.get().scheduler.maintenance_spent==spent,'same-tick warning replay renewed work')
      runtime.log(rec,'replacement',tick)
      assert(#rec.logs==1 and rec.logs[1].text=='replacement' and rec.log_truncated)
      drop(rec,tick)
      assert(rec.dropped_events.total==3 and rec.dropped_events.warning_pending)
      s.warning_tick=tick; s.phase='frozen'
      retained(s,tick)
      game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
    end
    if s.phase=='frozen' then assert(loaded); loaded=false; s.phase='interval' end
    if s.phase=='interval' then
      scheduler.tick(tick)
      if tick<s.warning_tick+limits.event_drop_warning_interval then
        assert(rec.logs[1].text=='replacement' and rec.dropped_events.warning_tick==s.warning_tick,'cold reload reset warning throttle')
        return
      end
      assert(rec.logs[1].text=='Dropped events (cumulative): 3' and rec.dropped_events.warning_tick==tick)
      rec.dropped_events.total=MAX-1
      drop(rec,tick); drop(rec,tick)
      assert(rec.dropped_events.total==MAX and rec.dropped_events.saturated)
      s.warning_tick=tick; s.phase='admission'; return
    end
    if tick<s.warning_tick+limits.event_drop_warning_interval then scheduler.tick(tick); return end
    if s.phase=='admission' then
      local root=registry.get(); local spend=scheduler.maintenance(root,tick)
      spend(math.min(limits.host_work_per_tick,limits.maintenance_work_per_tick)-128)
      local ok=scheduler.try_maintenance(function() runtime.warn_event_drops(rec,tick,spend) end)
      assert(not ok and rec.dropped_events.warning_pending and rec.dropped_events.warning_tick==s.warning_tick)
      assert(rec.logs[1].text=='Dropped events (cumulative): 3','failed warning admission evicted prior log')
      s.phase='tiny'; return
    end
    if s.phase=='tiny' then
      limits.console_bytes=1
      scheduler.tick(tick)
      assert(rec.dropped_events.warning_pending and rec.dropped_events.warning_tick==s.warning_tick)
      assert(rec.logs[1].text=='Dropped events (cumulative): 3' and rec.status=='running')
      s.phase='finish'; return
    end
    assert(s.phase=='finish')
    scheduler.tick(tick)
    assert(rec.logs[1].text=='Dropped events (cumulative): 9007199254740991 (saturated)',rec.logs[1].text)
    assert(not rec.dropped_events.warning_pending and rec.dropped_events.warning_tick==tick)
    retained(s,tick)
    local status=resources.read(rec,tick)
    assert(resources.summary(status):find('9007199254740991+',1,true))
    assert(resources.details(status):find('9007199254740991 (saturated)',1,true))
    local drops=rec.dropped_events
    assert(runtime.stop(rec.id)); runtime.reset_state(rec.id)
    assert(runtime.activate(rec.id,tick) and rec.dropped_events==drops and drops.total==MAX and drops.saturated)
    rec.powered=true
    assert(runtime.enqueue(rec,'receive',{name='timer'},tick))
    assert(scheduler.dispatch(rec,tick) and rec.state.observed==MAX and drops.total==MAX,'guest status lost precision or defensive ownership')
    s.phase='done'
    log('TC_CONTRACT warnings-full-queue-cold-throttle-eviction-saturation-and-prepaid-log-admission')
    log('TC_COLD_OK')
  end)
end
return M
