-- One synchronized fair scheduler. No per-computer on_tick or saved functions.
local registry = require('scripts.registry')
local runtime = require('scripts.runtime.computer')
local compiler = require('scripts.runtime.compiler')
local limits = require('scripts.runtime.limits')
local errors = require('scripts.runtime.errors')
local admission = require('scripts.runtime.admission')
local budgets = require('scripts.runtime.budget-settings')
local shell = require('scripts.runtime.shell')
local principal = require('scripts.runtime.principal')
local M = {}
local migrated_root
local function migrate(root,tick)
  if migrated_root~=root or root.runtime_upgrade_pending then
    if not runtime.migrate(root,tick) then return false end
    migrated_root=root
  end
  return true
end
local hooks={lifecycle={},sample={},notifications={},render={}} -- Arrays sorted by name at registration.
local refusal={} -- Host-only ephemeral maintenance deferral identity.
local render_reservation=0
local max_render_reservation=160000
local function render_state_valid(s,tick)
  if type(s)~='table' then return false end
  if not errors.integer(s.last_tick,-1,tick) then return false end
  if s.maintenance_tick~=nil and (not errors.integer(s.maintenance_tick,0,tick)
    or not errors.integer(s.maintenance_spent,0,budgets.maintenance_max)) then return false end
  if s.render_demand_work~=nil or s.render_demand_tick~=nil then
    if not errors.integer(s.render_demand_work,0,max_render_reservation)
      or not errors.integer(s.render_demand_tick,0,tick) then return false end
  end
  if s.render_reserved_work~=nil and not errors.integer(s.render_reserved_work,0,max_render_reservation) then return false end
  if s.last_render_boost_tick~=nil and not errors.integer(s.last_render_boost_tick,0,tick) then return false end
  return true
end
local monitor_refresh
local dashboard_validate
function M.register_dashboard_validator(fn)
  assert(not dashboard_validate and type(fn)=='function'); dashboard_validate=fn
end
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
-- ready(root,tick) reads synchronized storage only and must not allocate; it
-- returns true for state it cannot interpret so the hook's own validation runs.
function M.register_phase(phase,name,fn,ready)
  local list=hooks[phase]
  assert(list and type(name)=='string' and type(fn)=='function' and type(ready)=='function','invalid scheduler phase hook')
  for _,hook in ipairs(list) do assert(hook.name~=name,'invalid scheduler phase hook') end
  assert(#list<limits.host_hooks,'phase hook capacity')
  local i=#list+1
  while i>1 and list[i-1].name>name do list[i]=list[i-1]; i=i-1 end
  list[i]={name=name,fn=fn,ready=ready}
end
-- Shared readiness for ordered membership lanes: unknown shapes run the hook.
function M.order_pending(s) return type(s)~='table' or type(s.order)~='table' or s.order[1]~=nil end
-- Read-only diagnostic for fixtures: the registered hook's current readiness.
function M.hook_ready(phase,name,root,tick)
  for _,hook in ipairs(assert(hooks[phase],'unknown phase')) do
    if hook.name==name then return hook.ready(root,tick) and true or false end
  end
  error('unknown scheduler phase hook '..phase..'/'..name)
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
  -- Old saves have no alias. Attach only on synchronized admission, never load.
  assert(root.ledger.maintenance==nil or root.ledger.maintenance==s,'invalid maintenance ledger alias')
  root.ledger.maintenance=s
  return function(n)
    assert(s.maintenance_tick==tick,'stale maintenance admission')
    assert(errors.integer(n,0,1000000000),'invalid maintenance cost')
    -- Read live ceilings even for an already captured spend callback. A setting
    -- increase cannot reclaim guest credits already spent under the old split.
    local guest_spent=root.ledger.tick==tick and root.ledger.total or 0
    local ceiling=math.min(limits.maintenance_work_per_tick-(for_render and 0 or s.render_reserved_work),
      limits.host_work_per_tick-guest_spent)
    if s.maintenance_spent+n>ceiling then error(refusal,0) end
    s.maintenance_spent=s.maintenance_spent+n
  end
end
function M.try_maintenance(fn)
  local ok,result=pcall(fn)
  if not ok and result~=refusal then error(result,0) end
  return ok,result
end
local function work(root,fn)
  local ok,result=pcall(fn)
  if not ok and result~=refusal then
    if type(result)=='table' and result.code=='E_UNSUPPORTED' then root.scheduling_diagnostic=result
    else error(result,0) end
  end
  return ok,result
end
local function phase(name,root,tick,get_spend)
  for _,hook in ipairs(hooks[name]) do
    -- Readiness is checked directly: idle hooks cost no closure, pcall or charge.
    if hook.ready(root,tick) then
      local spend=get_spend()
      -- Samplers own admission and must run their fail-closed refusal path even
      -- when previous phases spent the maintenance ledger. No silent missed tick.
      M.try_maintenance(function() if name~='sample' then spend(1) end; hook.fn(tick,spend) end)
      if registry.get().scheduling_diagnostic then return end
    end
  end
end
-- Per-tick spend callbacks are created only when work actually needs them.
local lazy_root,lazy_tick,lazy_spend,lazy_render
local function tick_spend()
  if not lazy_spend then lazy_spend=M.maintenance(lazy_root,lazy_tick) end
  return lazy_spend
end
local function render_spend()
  if not lazy_render then lazy_render=M.maintenance(lazy_root,lazy_tick,true) end
  return lazy_render
end
function M.advance_timers(rec,tick,spend)
  if rec.status~='running' or not principal.available(rec) then return end
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
  registry.timers_changed(rec)
end
local function dispatch_program(rec,tick)
  if rec.status~='running' or #rec.queue==0 or rec.last_dispatch_tick==tick then return false end
  if not principal.available(rec) then return false end
  if not runtime.check_active(rec) then
    runtime.fault(rec,errors.new('E_UNSUPPORTED','unsupported retained computer/source header; source/state retained'),tick,true)
    return false
  end
  local root=registry.get()
  if not rec.body.valid then runtime.fault(rec,errors.new('E_NOT_FOUND','computer body no longer exists'),tick); return false end
  -- Admit actual source/API work, not a fictional whole-invocation allowance.
  if (root.ledger.tick==tick and root.ledger.total or 0)>=admission.host_ceiling(root.ledger,tick) then return false end
  local context_ok,ctx=pcall(runtime.context,rec,tick)
  if not context_ok then
    if type(ctx)=='table' and ctx.code=='E_BUSY' then return false end
    runtime.fault(rec,errors.new('E_UNSUPPORTED','malformed admission record; source/state/credits retained'),tick,true)
    return false
  end
  local item=rec.queue[1]
  if item.event.name=='dashboard_click' then
    local admitted,valid=M.try_maintenance(function()
      return dashboard_validate and dashboard_validate(rec,item,M.maintenance(root,tick)) or false
    end)
    if not admitted then return false end
    if not valid then
      table.remove(rec.queue,1); rec.queue_bytes=rec.queue_bytes-item.bytes
      registry.ready_changed(rec)
      rec.last_dispatch_tick=tick; return true
    end
  end
  local function consume(input,guard)
    if input and monitor_refresh and item.event.name=='monitor_resize' then
      guard.spend(8)
      monitor_refresh(input)
    end
    rec.last_dispatch_tick=tick
    table.remove(rec.queue,1); rec.queue_bytes=rec.queue_bytes-item.bytes
    registry.ready_changed(rec)
    if item.event.name~='dashboard_click' then
      item.event.tick=tick
      if input then input.tick=tick end
    end
  end
  local ok,diagnostic,control=compiler.run(rec.active,item.handler,item.event,
    function(guard,frame) return runtime.services(rec,frame or tick,guard) end,ctx,item.circuit==true,consume,rec)
  if control=='defer' then return false end
  if rec.last_dispatch_tick~=tick then consume() end
  if not ok then
    if control=='stop' then runtime.retire(rec,'stopped','stop')
    else runtime.fault(rec,diagnostic,tick,diagnostic.code=='E_UNSUPPORTED') end
  end
  return true
end
function M.dispatch(rec,tick)
  if rec.last_dispatch_tick==tick then return false end
  if not rec.body.valid then return dispatch_program(rec,tick) end
  if not principal.available(rec) then return false end
  local root=registry.get()
  if not migrate(root,tick) then return false end
  if (root.ledger.tick==tick and root.ledger.total or 0)>=admission.host_ceiling(root.ledger,tick) then return false end
  local pending=shell.waiting(rec)
  local program=rec.status=='running' and #rec.queue>0
  if pending and (not program or rec.next_work_class~='program') then
    local dispatched=shell.dispatch(rec,tick)
    if dispatched then rec.next_work_class='program' end
    return dispatched
  end
  local dispatched=dispatch_program(rec,tick)
  if dispatched then rec.next_work_class='shell' end
  return dispatched
end
function M.viewer_tick(kind,tick,spend,refresh)
  if tick%15~=0 then return end
  local root=registry.get(); local valid,item=pcall(registry.maintenance_next,kind)
  if not valid then root.scheduling_diagnostic=item; return end
  if not item or item.tick>tick then return end
  local pending={}; local clock=registry.maintenance_clock(kind)
  if clock.initialized~=1 then root.scheduling_diagnostic=errors.new('E_UNSUPPORTED','unsupported viewer deadlines; session retained'); return end
  for _=1,#clock.deadlines do
    item=registry.maintenance_next(kind); if not item or item.tick>tick then break end
    local size,work=#clock.deadlines,16
    while size>0 do work=work+16; size=math.floor(size/2) end
    if not M.try_maintenance(function() spend(work) end) then break end
    registry.maintenance_remove(kind,item.id)
    local ok,admitted,keep=pcall(M.try_maintenance,function() return refresh(tonumber(item.id),item.owner,tick,spend) end)
    if not ok or not admitted or keep=='pending' then pending[#pending+1]=item
    elseif keep then registry.maintenance_set(kind,item.id,item.owner,tick-tick%15+15) end
    if not ok then
      for _,entry in ipairs(pending) do registry.maintenance_set(kind,entry.id,entry.owner,entry.tick) end
      error(admitted,0)
    end
  end
  for _,entry in ipairs(pending) do registry.maintenance_set(kind,entry.id,entry.owner,entry.tick) end
end
function M.tick(tick)
  local root=registry.get()
  if not registry.supported(root) then return end -- Unknown storage stays inert.
  if not registry.scheduling_supported(root) then
    root.scheduling_diagnostic=errors.new('E_UNSUPPORTED','unsupported scheduling membership; source/queues/timers/credits retained')
    return
  end
  if root.scheduling_diagnostic then return end
  if not migrate(root,tick) then return end
  local ledger=root.ledger
  if type(ledger)~='table' or ledger.version~=2 or not errors.integer(ledger.total,0,1000000000)
    or not errors.integer(ledger.tick,-1,9007199254740991) or tick<ledger.tick
    or not render_state_valid(root.scheduler,tick)
    or ledger.maintenance~=nil and ledger.maintenance~=root.scheduler then
    -- Validate the shared retained clock/header before timers or callbacks can
    -- mutate anything. Do not repair/reset an unknown ledger on reload.
    for _,rec in pairs(root.computers) do
      if rec.status=='running' then runtime.fault(rec,errors.new('E_UNSUPPORTED','unsupported admission header/clock; source/state/credits retained'),tick,true) end
    end
    return
  end
  if root.scheduler.last_tick==tick then return end -- No same-tick replay/credit refresh.
  root.scheduler.last_tick=tick
  lazy_root,lazy_tick,lazy_spend,lazy_render=root,tick,nil,nil
  phase('lifecycle',root,tick,tick_spend)
  if root.scheduling_diagnostic then return end
  phase('sample',root,tick,tick_spend)
  if root.scheduling_diagnostic then return end
  phase('notifications',root,tick,tick_spend)
  if root.scheduling_diagnostic then return end
  local s=root.scheduler
  local due
  while true do
    local valid,item=work(root,registry.next_timer)
    if not valid or not item or item.tick>tick then break end
    local spend=tick_spend()
    if not work(root,function() spend(1); registry.timer_remove(item.id) end) then break end
    local rec=root.computers[item.id]
    if rec and rec.generation==item.generation and rec.run_id==item.run_id then
      M.try_maintenance(function()
        if rec.status=='running' then
          if not runtime.check_active(rec) then runtime.fault(rec,errors.new('E_UNSUPPORTED','unsupported retained computer/source header; source/state retained'),tick,true)
          else M.advance_timers(rec,tick,spend) end
        end
      end)
      -- Reinsert after this pass: a refused due owner cannot block its peers.
      registry.timer_remove(rec.id)
      due=due or {}
      due[#due+1]=rec
    end
  end
  if root.scheduling_diagnostic then return end
  if due then for _,rec in ipairs(due) do registry.timers_changed(rec) end end
  -- Freeze identities before callbacks can publish new work or retire neighbors.
  if s.ready_head~=nil then
    local spend=tick_spend()
    local admitted,round=work(root,function()
      return registry.ready_round(function(n) return M.try_maintenance(function() spend(n) end) end)
    end)
    if admitted then
      for _,item in ipairs(round) do
        local rec=root.computers[item.id]
        if s.ready[item.id]==item and rec and rec.generation==item.generation
          and rec.run_id==item.run_id and (rec.shell and rec.shell.id)==item.shell_id then
          M.dispatch(rec,tick)
          registry.ready_changed(rec)
        elseif s.ready[item.id]==item then
          registry.retire_ready(item)
          if rec then registry.ready_changed(rec) end
        end
      end
    end
  end
  phase('render',root,tick,render_spend)
end
return M
