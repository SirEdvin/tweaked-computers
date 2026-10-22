local limits = require('scripts.runtime.limits')
local errors = require('scripts.runtime.errors')
local admission = require('scripts.runtime.admission')
local M = {}
local context, depth, trace
function M.begin(ctx,charges) assert(not context, 'parser is non-reentrant'); context, depth, trace = ctx, 0, charges end
function M.finish() context, depth, trace = nil, nil, nil end
function M.enter(cost)
  cost=cost or 1
  if context and not admission.reserve(context, 'compile', cost) then
    errors.raise('E_BUDGET', 'source compilation work exhausted')
  end
  if trace then
    if (#trace+1)*16+64<=limits.compiler_cache_bytes then
      trace[#trace+1]=cost; trace.total=(trace.total or 0)+cost
    else trace.overflow=true; trace=nil end
  end
end
function M.push()
  M.enter()
  depth = depth + 1
  if depth > limits.source_nesting then errors.raise('E_LIMIT', 'source nesting exceeds compiler limit') end
end
function M.pop() depth = depth - 1 end
return M
