local limits = require('scripts.runtime.limits')
local errors = require('scripts.runtime.errors')
local M = {}
-- This plain ledger is owned by the synchronized scheduler, never by a guest/cache.
function M.new()
  return {version = 2, tick = -1, total = 0, machines = {}}
end
local function plain(value) return type(value)=='table' and getmetatable(value)==nil end
function M.upgrade(ledger)
  if not plain(ledger) or (ledger.version~=1 and ledger.version~=2)
    or not errors.integer(ledger.tick,-1,9007199254740991)
    or not errors.integer(ledger.total,0,1000000000) or not plain(ledger.machines) then return false end
  local count,total,seen=0,0,{}
  for id,machine in pairs(ledger.machines) do
    count=count+1
    if count>limits.active_computers or type(id)~='string' or #id==0 or not plain(machine)
      or seen[machine] or not errors.integer(machine.work,0,1000000000)
      or not errors.integer(machine.compile,0,1000000000) then return false end
    seen[machine]=true
    if ledger.version==1 then
      if not errors.integer(machine.allocations,0,1000000000) then return false end
      total=total+machine.allocations
    elseif machine.allocations~=nil then return false end
    total=total+machine.work+machine.compile
  end
  if total>ledger.total then return false end
  if ledger.version==1 then
    for _,machine in pairs(ledger.machines) do machine.work=0; machine.allocations=nil end
    ledger.version=2 -- Keep all historical charges in the aggregate until the next tick.
  end
  return true
end
function M.context(ledger, id, tick)
  assert(ledger.version == 2, 'unsupported admission ledger')
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
    machine = {work = 0, compile = 0}
    ledger.machines[id] = machine
  end
  assert(plain(machine) and errors.integer(machine.work,0,1000000000)
    and errors.integer(machine.compile,0,1000000000) and machine.allocations==nil,'invalid admission record')
  return {ledger = ledger, machine = machine, tick = tick, id = id}
end
-- A live decrease cannot reuse maintenance credits already spent this tick.
function M.host_ceiling(ledger,tick)
  local s=ledger.maintenance
  local spent=s and s.maintenance_tick==tick and s.maintenance_spent or 0
  return math.max(0,limits.host_work_per_tick-math.max(limits.maintenance_work_per_tick,spent))
end
local function current(ctx)
  assert(ctx.ledger.version==2 and ctx.tick==ctx.ledger.tick
    and ctx.ledger.machines[ctx.id]==ctx.machine,'stale admission context')
end
function M.begin_preparation(ctx)
  current(ctx)
  assert(not ctx.preparation,'nested preparation')
  ctx.preparation={total=ctx.ledger.total,compile=ctx.machine.compile}
end
function M.finish_preparation(ctx)
  local preparation=ctx.preparation
  ctx.preparation=nil
  return preparation and preparation.deferred or false
end
local function refused(ctx,kind,amount)
  local preparation=ctx.preparation
  if preparation then
    preparation.deferred=ctx.ledger.total-preparation.total+amount<=M.host_ceiling(ctx.ledger,ctx.tick)
      and (kind~='compile' or ctx.machine.compile-preparation.compile+amount<=limits.compile_work)
  end
  return false
end
function M.reserve(ctx, kind, amount)
  assert(errors.integer(amount, 0, 1000000000), 'invalid work reservation')
  current(ctx)
  assert(kind=='work' or kind=='compile','unknown admission kind')
  if kind=='compile' and ctx.machine.compile+amount>limits.compile_work
    or ctx.ledger.total+amount>M.host_ceiling(ctx.ledger,ctx.tick) then return refused(ctx,kind,amount) end
  ctx.machine[kind]=ctx.machine[kind]+amount
  ctx.ledger.total=ctx.ledger.total+amount
  return true
end
-- Bind immutable identity only; shared host admission remains live.
function M.bind(ctx)
  current(ctx)
  local ledger,machine,tick,id=ctx.ledger,ctx.machine,ctx.tick,ctx.id
  return function(n)
    if n~=1 then assert(errors.integer(n,0,1000000000),'invalid work reservation') end
    assert(ledger.version==2 and tick==ledger.tick and ledger.machines[id]==machine,'stale admission context')
    local total=ledger.total+n
    if total>M.host_ceiling(ledger,tick) then return refused(ctx,'work',n) end
    machine.work,ledger.total=machine.work+n,total
    return true
  end
end
-- Private host traces only. Refusal retains the exact accepted charge prefix.
local function replay(ctx,kind,ceiling,charges)
  current(ctx)
  local available=math.min(ceiling-ctx.machine[kind],M.host_ceiling(ctx.ledger,ctx.tick)-ctx.ledger.total)
  local accepted,refusal=charges.total
  if accepted>available then
    accepted=0
    for _,cost in ipairs(charges) do
      if accepted+cost>available then refusal=cost; break end
      accepted=accepted+cost
    end
  end
  ctx.machine[kind]=ctx.machine[kind]+accepted; ctx.ledger.total=ctx.ledger.total+accepted
  if refusal then return refused(ctx,kind,refusal) end
  return charges.total<=available
end
function M.replay_compile(ctx,charges) return replay(ctx,'compile',limits.compile_work,charges) end
function M.replay_work(ctx,charges) return replay(ctx,'work',math.huge,charges) end
return M
