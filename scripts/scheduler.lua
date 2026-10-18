-- One synchronized fair scheduler. No per-computer on_tick or saved functions.
local registry = require('scripts.registry')
local runtime = require('scripts.runtime.computer')
local compiler = require('scripts.runtime.compiler')
local limits = require('scripts.runtime.limits')
local errors = require('scripts.runtime.errors')
local admission = require('scripts.runtime.admission')
local M = {}
local hooks={lifecycle={},sample={},notifications={},render={}}
local refusal={} -- Host-only ephemeral maintenance deferral identity.
local render_reservation=0
local max_render_reservation=160000
local function render_state_valid(s,tick)
  if type(s)~='table' then return false end
  if not errors.integer(s.last_tick,-1,tick) then return false end
  if s.maintenance_tick~=nil and (not errors.integer(s.maintenance_tick,0,tick)
    or not errors.integer(s.maintenance_spent,0,limits.maintenance_work_per_tick)) then return false end
  if s.render_demand_work~=nil or s.render_demand_tick~=nil then
    if not errors.integer(s.render_demand_work,0,max_render_reservation)
      or not errors.integer(s.render_demand_tick,0,tick) then return false end
  end
  if s.render_reserved_work~=nil and not errors.integer(s.render_reserved_work,0,max_render_reservation) then return false end
  if s.last_render_boost_tick~=nil and not errors.integer(s.last_render_boost_tick,0,tick) then return false end
  return true
end
local monitor_refresh
function M.register_monitor_refresh(fn)
  assert(type(fn)=='function' and not monitor_refresh,'invalid monitor event refresh')
  monitor_refresh=fn
end
function M.reserve_render_work(n)
  assert(render_reservation==0 and errors.integer(n,1,max_render_reservation),'invalid render reservation')
  render_reservation=n
end
-- Host-only presenter demand; it cannot change the already frozen current tick.
function M.request_render_work(root,tick,n,spend)
  local s=root.scheduler
  assert(errors.integer(tick,0,9007199254740991) and render_state_valid(s,tick)
    and tick>=s.last_tick and tick>=(s.render_demand_tick or 0)
    and errors.integer(n,0,max_render_reservation),'invalid render demand')
  spend(4); s.render_demand_work=n; s.render_demand_tick=tick
end
function M.register_phase(phase,name,fn)
  assert(hooks[phase] and type(name)=='string' and type(fn)=='function' and not hooks[phase][name],'invalid scheduler phase hook')
  local n=0; for _ in pairs(hooks[phase]) do n=n+1 end; assert(n<limits.host_hooks,'phase hook capacity')
  hooks[phase][name]=fn
end
function M.maintenance(root,tick,for_render)
  local s=root.scheduler
  assert(errors.integer(tick,0,9007199254740991) and render_state_valid(s,tick)
    and tick>=s.last_tick,'invalid maintenance state or backwards clock')
  if s.maintenance_tick~=tick then
    local requested=s.render_demand_work or 0
    local reserved=render_reservation
    if requested>reserved and (not s.last_render_boost_tick or tick-s.last_render_boost_tick>=2) then
      reserved=requested; s.last_render_boost_tick=tick
    end
    s.maintenance_tick=tick; s.maintenance_spent=0; s.render_reserved_work=reserved
  elseif s.render_reserved_work==nil then
    s.render_reserved_work=render_reservation -- Legacy same-tick ledger, no credit reset.
  end
  local ceiling=limits.maintenance_work_per_tick-(for_render and 0 or s.render_reserved_work)
  return function(n)
    assert(s.maintenance_tick==tick,'stale maintenance admission')
    assert(errors.integer(n,0,1000000000),'invalid maintenance cost')
    if s.maintenance_spent+n>ceiling then error(refusal,0) end
    s.maintenance_spent=s.maintenance_spent+n
  end
end
function M.try_maintenance(fn)
  local ok,result=pcall(fn)
  if not ok and result~=refusal then error(result,0) end
  return ok,result
end
local function phase(name,tick,spend)
  local names={}; for key in pairs(hooks[name]) do names[#names+1]=key end; table.sort(names)
  for _,key in ipairs(names) do
    -- Samplers own admission and must run their fail-closed refusal path even
    -- when previous phases spent the maintenance ledger. No silent missed tick.
    M.try_maintenance(function() if name~='sample' then spend(1) end; hooks[name][key](tick,spend) end)
  end
end
function M.advance_timers(rec,tick,spend)
  if rec.status~='running' or not rec.powered then return end
  spend(limits.timers*limits.timers+#rec.queue+1)
  local due={}
  for _,timer in pairs(rec.timers) do if timer.deadline<=tick then due[#due+1]=timer end end
  table.sort(due,function(a,b) if a.deadline~=b.deadline then return a.deadline<b.deadline end; return a.sequence<b.sequence end)
  for _,timer in ipairs(due) do
    local missed=timer.interval and math.floor((tick-timer.deadline)/timer.interval) or 0
    local deadline=timer.interval and timer.deadline+(missed+1)*timer.interval or nil
    if deadline and not errors.integer(deadline,0,9007199254740991) then runtime.fault(rec,errors.new('E_RANGE','recurring deadline exhausted'),tick); return end
    local pending
    spend(#rec.queue+1)
    for _,item in ipairs(rec.queue) do if item.timer_id==timer.id then pending=item; break end end
    if pending then
      spend(1)
      -- A queued recurring notification and further overdue intervals remain one
      -- notification with its original scheduled_tick, never an unbounded burst.
      pending.event.missed=pending.event.missed+missed+1
    else
      local event={name='timer',timer_id=timer.id,scheduled_tick=timer.deadline,
        interval_ticks=timer.interval,missed=missed,payload=timer.payload}
      if not runtime.enqueue(rec,timer.handler,event,tick,spend,{timer_id=timer.id}) then return end
    end
    if timer.interval then timer.deadline=deadline else rec.timers[timer.id]=nil end
  end
end
function M.dispatch(rec,tick)
  if rec.status~='running' or not rec.powered or #rec.queue==0 or rec.last_dispatch_tick==tick then return false end
  -- Physical sampling can defer under maintenance pressure. Never dispatch from
  -- an old positive power observation; standalone runtime fixtures have no tag.
  if rec.physical_version and (rec.physical_error or rec.power_checked_tick~=tick) then return false end
  if not runtime.check_active(rec) then
    runtime.fault(rec,errors.new('E_UNSUPPORTED','unsupported retained computer/source header; source/state retained'),tick)
    return false
  end
  local root=registry.get()
  if not rec.body.valid then runtime.fault(rec,errors.new('E_NOT_FOUND','computer body no longer exists'),tick); return false end
  -- Preserve enough aggregate headroom for one complete bounded callback. If a
  -- neighbor spent it, wait rather than faulting an untouched waiting run.
  -- Independently configurable ceilings can sum above the shared allowance.
  -- Reserve no more than that allowance so small fitting callbacks still run;
  -- admission remains authoritative and faults callbacks that actually exceed it.
  local maximum=math.min(limits.compile_work+limits.callback_work+limits.callback_allocations,
    limits.host_work_per_tick-limits.maintenance_work_per_tick)
  if root.ledger.tick==tick and root.ledger.total+maximum>limits.host_work_per_tick-limits.maintenance_work_per_tick then return false end
  local context_ok,ctx=pcall(runtime.context,rec,tick)
  if not context_ok then
    if type(ctx)=='table' and ctx.code=='E_BUSY' then return false end
    runtime.fault(rec,errors.new('E_UNSUPPORTED','malformed admission record; source/state/credits retained'),tick)
    return false
  end
  local item=rec.queue[1]
  if monitor_refresh and item.event.name=='monitor_resize' then
    if not admission.reserve(ctx,'work',8) then return false end
    monitor_refresh(item.event)
  end
  rec.last_dispatch_tick=tick
  table.remove(rec.queue,1); rec.queue_bytes=rec.queue_bytes-item.bytes
  item.event.tick=tick
  local ok,diagnostic,control=compiler.run(rec.active,item.handler,item.event,function(guard) return runtime.services(rec,tick,guard) end,ctx)
  if not ok then
    if control=='stop' then runtime.retire(rec,'stopped','stop')
    else runtime.fault(rec,diagnostic,tick) end
  end
  return true
end
function M.tick(tick)
  local root=registry.get()
  if not registry.supported(root) then return end -- Unknown storage stays inert.
  local ledger=root.ledger
  if type(ledger)~='table' or ledger.version~=1 or not errors.integer(ledger.total,0,1000000000)
    or not errors.integer(ledger.tick,-1,9007199254740991) or tick<ledger.tick
    or not render_state_valid(root.scheduler,tick) then
    -- Validate the shared retained clock/header before timers or callbacks can
    -- mutate anything. Do not repair/reset an unknown ledger on reload.
    for _,rec in pairs(root.computers) do
      if rec.status=='running' then runtime.fault(rec,errors.new('E_UNSUPPORTED','unsupported admission header/clock; source/state/credits retained'),tick) end
    end
    return
  end
  local spend=M.maintenance(root,tick)
  if root.scheduler.last_tick==tick then return end -- No same-tick replay/credit refresh.
  -- Pay both bounded identity walks before hooks can exhaust maintenance. This
  -- also covers inactive records and refusals later in the timer walk.
  spend(limits.registry_entries*2+1)
  root.scheduler.last_tick=tick
  phase('lifecycle',tick,spend)
  phase('sample',tick,spend)
  phase('notifications',tick,spend)
  -- Advance clocks before callback dispatch; the cursor also rotates maintenance
  -- scanning so a large earlier timer set cannot starve later identities.
  local n=#root.order
  if n==0 then phase('render',tick,M.maintenance(root,tick,true)); return end
  local start=math.min(root.scheduler.cursor,n)
  local maintenance_start=math.min(root.scheduler.maintenance_cursor or 1,n)
  local admitted=false
  for offset=0,n-1 do
    local i=(maintenance_start+offset-1)%n+1
    local rec=root.computers[root.order[i]]
    M.try_maintenance(function()
      if rec and rec.status=='running' then
        if not runtime.check_active(rec) then runtime.fault(rec,errors.new('E_UNSUPPORTED','unsupported retained computer/source header; source/state retained'),tick)
        else M.advance_timers(rec,tick,spend) end
      end
    end)
  end
  root.scheduler.maintenance_cursor=maintenance_start%n+1
  for offset=0,n-1 do
    local i=(start+offset-1)%n+1
    local rec=root.computers[root.order[i]]
    if rec and M.dispatch(rec,tick) then
      root.scheduler.cursor=i%n+1; admitted=true
    end
  end
  if not admitted then root.scheduler.cursor=start%n+1 end
  phase('render',tick,M.maintenance(root,tick,true))
end
return M
