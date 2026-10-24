local limits = require('scripts.runtime.limits')
local errors = require('scripts.runtime.errors')
local admission = require('scripts.runtime.admission')
local M = {}
local context, depth, trace
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
function M.finish() context, depth, trace = nil, nil, nil end
function M.record(charges) trace=charges end
function M.enter(cost)
  cost=cost or 1
  if context and not admission.reserve(context, 'compile', cost) then
    refuse(cost)
  end
  if trace then
    if (#trace+1)*16+64<=limits.compiler_cache_bytes then
      trace[#trace+1]=cost; trace.total=(trace.total or 0)+cost
    else trace.overflow=true; trace=nil end
  end
end
function M.replay(charges)
  if not context then return end
  local ok,cost=admission.replay_compile(context,charges)
  if not ok then refuse(cost) end
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
