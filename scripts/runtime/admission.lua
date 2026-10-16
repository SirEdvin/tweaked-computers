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
function M.reserve(ctx, kind, amount)
  assert(errors.integer(amount, 0, 1000000000), 'invalid work reservation')
  assert(ctx.tick == ctx.ledger.tick, 'stale admission context')
  local ceiling
  if kind=='work' then ceiling=limits.callback_work
  elseif kind=='compile' then ceiling=limits.compile_work
  elseif kind=='allocations' then ceiling=limits.callback_allocations end
  assert(ceiling, 'unknown admission kind')
  local aggregate_ceiling=limits.host_work_per_tick-limits.maintenance_work_per_tick
  if ctx.machine[kind] + amount > ceiling or ctx.ledger.total + amount > aggregate_ceiling then
    return false
  end
  ctx.machine[kind] = ctx.machine[kind] + amount
  ctx.ledger.total = ctx.ledger.total + amount
  return true
end
-- Private compiler proof only. A fitting trace is one arithmetic reservation;
-- on refusal replay its exact accepted prefix, matching cold phase accounting.
function M.replay_compile(ctx,charges)
  assert(ctx.tick==ctx.ledger.tick,'stale admission context')
  local available=math.min(limits.compile_work-ctx.machine.compile,
    limits.host_work_per_tick-limits.maintenance_work_per_tick-ctx.ledger.total)
  local accepted=charges.total
  if accepted>available then
    accepted=0
    for _,cost in ipairs(charges) do
      if accepted+cost>available then break end
      accepted=accepted+cost
    end
  end
  ctx.machine.compile=ctx.machine.compile+accepted; ctx.ledger.total=ctx.ledger.total+accepted
  return charges.total<=available
end
return M
