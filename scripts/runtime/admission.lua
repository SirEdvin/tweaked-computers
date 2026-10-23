local limits = require('scripts.runtime.limits')
local errors = require('scripts.runtime.errors')
local M = {}
-- This plain ledger is owned by the synchronized scheduler, never by a guest/cache.
function M.new()
  return {version = 1, tick = -1, total = 0, machines = {}}
end
function M.context(ledger, id, tick)
  assert(ledger.version == 1, 'unsupported admission ledger')
  assert(type(id) == 'string' and #id > 0, 'invalid admission identity')
  assert(errors.integer(tick, 0, 9007199254740991), 'invalid admission tick')
  assert(tick >= ledger.tick, 'admission clock moved backwards')
  if tick > ledger.tick then
    ledger.tick, ledger.total, ledger.machines = tick, 0, {}
  end
  local machine = ledger.machines[id]
  if not machine then
    local n = 0
    for _ in pairs(ledger.machines) do n = n + 1 end
    if n >= limits.active_computers then errors.raise('E_BUSY', 'active admission capacity reached') end
    machine = {work = 0, compile = 0, allocations = 0}
    ledger.machines[id] = machine
  end
  return {ledger = ledger, machine = machine, tick = tick}
end
-- The scheduler attaches its authoritative plain ledger during synchronized
-- maintenance. Retain that alias across reload, not a second spent counter.
-- A live decrease cannot give guests maintenance credits already spent this tick.
function M.guest_ceiling(ledger,tick)
  local s=ledger.maintenance
  local spent=s and s.maintenance_tick==tick and s.maintenance_spent or 0
  return math.max(0,limits.host_work_per_tick-math.max(limits.maintenance_work_per_tick,spent))
end
function M.reserve(ctx, kind, amount)
  assert(errors.integer(amount, 0, 9007199254740991), 'invalid work reservation')
  assert(ctx.tick == ctx.ledger.tick, 'stale admission context')
  local ceiling
  if kind=='work' then ceiling=limits.callback_work
  elseif kind=='compile' then ceiling=limits.compile_work
  elseif kind=='allocations' then ceiling=limits.callback_allocations end
  assert(ceiling, 'unknown admission kind')
  local aggregate_ceiling=M.guest_ceiling(ctx.ledger,ctx.tick)
  if amount > ceiling-ctx.machine[kind] or amount > aggregate_ceiling-ctx.ledger.total then
    return false
  end
  ctx.machine[kind] = ctx.machine[kind] + amount
  ctx.ledger.total = ctx.ledger.total + amount
  return true
end
-- Private, already-admitted host traces only. A fitting trace is one reservation;
-- refusal retains the exact accepted prefix, not all-or-nothing accounting.
local function replay(ctx,kind,ceiling,charges)
  assert(ctx.tick==ctx.ledger.tick,'stale admission context')
  local available=math.min(ceiling-ctx.machine[kind],
    M.guest_ceiling(ctx.ledger,ctx.tick)-ctx.ledger.total)
  local accepted=charges.total
  if accepted>available then
    accepted=0
    for _,cost in ipairs(charges) do
      if accepted+cost>available then break end
      accepted=accepted+cost
    end
  end
  ctx.machine[kind]=ctx.machine[kind]+accepted; ctx.ledger.total=ctx.ledger.total+accepted
  return charges.total<=available
end
function M.replay_compile(ctx,charges) return replay(ctx,'compile',limits.compile_work,charges) end
function M.replay_work(ctx,charges) return replay(ctx,'work',limits.callback_work,charges) end
return M
