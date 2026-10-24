local limits = require('scripts.runtime.limits')
local errors = require('scripts.runtime.errors')
local admission = require('scripts.runtime.admission')
local memory = require('scripts.runtime.memory')
local M = {}
local context, depth, trace, workspace
local function refuse(cost)
  if cost>limits.compile_work-context.machine.compile then
    errors.refuse('compile_work','tc-compile-work',context.machine.compile,cost,limits.compile_work,
      'source compilation work exhausted; source retained','E_BUDGET')
  end
  local ceiling=admission.guest_ceiling(context.ledger,context.tick)
  errors.refuse('host_work_per_tick','tc-host-work-per-tick',context.ledger.total,cost,ceiling,
    'source compilation host work exhausted; source retained','E_BUDGET')
end
function M.begin(ctx,charges) assert(not context, 'parser is non-reentrant'); context, depth, trace = ctx, 0, charges end
function M.finish() context, depth, trace, workspace = nil, nil, nil, nil end
function M.attach(owner) workspace=owner end
function M.record(charges) trace=charges end
local function record(cost)
  if not trace then return end
  if (#trace+1)*16+64<=limits.compiler_cache_bytes then
    -- Negative entries are byte reservations, interleaved with positive work.
    trace[#trace+1]=cost
    local key=cost<0 and 'bytes' or 'total'
    trace[key]=(trace[key] or 0)+math.abs(cost)
  else trace.overflow=true; trace=nil end
end
function M.enter(cost)
  cost=cost or 1
  if context and not admission.reserve(context, 'compile', cost) then
    refuse(cost)
  end
  record(cost)
end
function M.allocate(bytes)
  if workspace then memory.reserve(workspace,bytes) end
  if bytes>0 then record(-bytes) end
end
function M.replay(charges)
  local bytes=charges.bytes or 0
  if bytes==0 then
    if context then
      local ok,cost=admission.replay_compile(context,charges)
      if not ok then refuse(cost) end
    end
    return
  end
  local account=workspace and workspace.account
  if (not account or bytes<=account.limit-account.used-account.reserved)
    and (not context or charges.total<=math.min(limits.compile_work-context.machine.compile,
      admission.guest_ceiling(context.ledger,context.tick)-context.ledger.total)) then
    M.allocate(bytes)
    if context then assert(admission.replay_compile(context,charges)) end
    return
  end
  -- On refusal, replay both resources in order to preserve the paid prefix.
  for _,cost in ipairs(charges) do
    if cost<0 then M.allocate(-cost) else M.enter(cost) end
  end
end
function M.push()
  M.enter()
  depth = depth + 1
  if depth > limits.host_stack_depth then
    errors.refuse('host_stack_depth','tc-host-stack-depth',depth-1,1,limits.host_stack_depth,'compiler host depth exceeded')
  end
end
function M.pop() depth = depth - 1 end
return M
