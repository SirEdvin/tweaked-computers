-- One synchronized fair scheduler. No per-computer on_tick or saved functions.
local registry = require('scripts.registry')
local runtime = require('scripts.runtime.computer')
local compiler = require('scripts.runtime.compiler')
local limits = require('scripts.runtime.limits')
local errors = require('scripts.runtime.errors')
local M = {}
local hooks={lifecycle={},sample={},notifications={},render={}}
local refusal={} -- Host-only ephemeral maintenance deferral identity.
function M.register_phase(phase,name,fn)
  assert(hooks[phase] and type(name)=='string' and type(fn)=='function' and not hooks[phase][name],'invalid scheduler phase hook')
  local n=0; for _ in pairs(hooks[phase]) do n=n+1 end; assert(n<limits.host_hooks,'phase hook capacity')
  hooks[phase][name]=fn
end
function M.maintenance(root,tick)
  local s=root.scheduler
  assert(errors.integer(tick,0,9007199254740991) and tick>=s.last_tick,'scheduler clock moved backwards')
  if s.maintenance_tick~=tick then s.maintenance_tick=tick; s.maintenance_spent=0 end
  return function(n)
    assert(errors.integer(n,0,1000000000),'invalid maintenance cost')
    if s.maintenance_spent+n>limits.maintenance_work_per_tick then error(refusal,0) end
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
  for _,key in ipairs(names) do M.try_maintenance(function() spend(1); hooks[name][key](tick,spend) end) end
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
  if not runtime.check_active(rec) then
    runtime.fault(rec,errors.new('E_UNSUPPORTED','unsupported retained computer/source header; source/state retained'),tick)
    return false
  end
  local root=registry.get()
  if not rec.body.valid then runtime.fault(rec,errors.new('E_NOT_FOUND','computer body no longer exists'),tick); return false end
  -- Preserve enough aggregate headroom for one complete bounded callback. If a
  -- neighbor spent it, wait rather than faulting an untouched waiting run.
  local maximum=limits.compile_work+limits.callback_work+limits.callback_allocations
  if root.ledger.tick==tick and root.ledger.total+maximum>limits.host_work_per_tick-limits.maintenance_work_per_tick then return false end
  local context_ok,ctx=pcall(runtime.context,rec,tick)
  if not context_ok then
    if type(ctx)=='table' and ctx.code=='E_BUSY' then return false end
    runtime.fault(rec,errors.new('E_UNSUPPORTED','malformed admission record; source/state/credits retained'),tick)
    return false
  end
  local item=rec.queue[1]
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
    or not errors.integer(ledger.tick,-1,9007199254740991) or tick<ledger.tick then
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
  if n==0 then phase('render',tick,spend); return end
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
  phase('render',tick,spend)
end
return M
