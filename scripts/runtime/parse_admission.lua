local limits = require('scripts.runtime.limits')
local errors = require('scripts.runtime.errors')
local admission = require('scripts.runtime.admission')
local memory = require('scripts.runtime.memory')
local M = {}
local context, depth, summary, workspace
local PROOF_BYTES = 192+2*48
local function refuse(cost)
  if cost>limits.compile_work-context.machine.compile then
    errors.refuse('compile_work','tc-compile-work',context.machine.compile,cost,limits.compile_work,
      'source compilation work exhausted; source retained','E_BUDGET')
  end
  local ceiling=admission.guest_ceiling(context.ledger,context.tick)
  errors.refuse('host_work_per_tick','tc-host-work-per-tick',context.ledger.total,cost,ceiling,
    'source compilation host work exhausted; source retained','E_BUDGET')
end
function M.begin(ctx) assert(not context, 'parser is non-reentrant'); context, depth = ctx, 0 end
function M.finish()
  context, depth, summary, workspace = nil, nil, nil, nil
end
function M.attach(owner) workspace=owner end
function M.record()
  if workspace then memory.reserve(workspace,PROOF_BYTES) end
  summary={total=0,bytes=0}
  return summary
end
function M.proof_bytes() return PROOF_BYTES end
function M.enter(cost)
  cost=cost or 1
  if context and not admission.reserve(context, 'compile', cost) then
    refuse(cost)
  end
  if summary then summary.total=summary.total+cost end
end
function M.allocate(bytes)
  if workspace then memory.reserve(workspace,bytes) end
  if summary then summary.bytes=summary.bytes+bytes end
end
function M.replay(charges)
  local bytes=PROOF_BYTES+charges.bytes
  local account=workspace and workspace.account
  if (not account or bytes<=account.limit-account.used-account.reserved)
    and (not context or charges.total<=math.min(limits.compile_work-context.machine.compile,
      admission.guest_ceiling(context.ledger,context.tick)-context.ledger.total)) then
    if workspace then memory.reserve(workspace,bytes) end
    if context then assert(admission.replay_compile(context,charges)) end
    return true
  end
  -- Recompile without spending here: the real traversal preserves refusal order.
  return false
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
