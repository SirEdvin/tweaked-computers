local limits = require('scripts.runtime.limits')
local errors = require('scripts.runtime.errors')
local admission = require('scripts.runtime.admission')
local M = {}
local context, depth
function M.begin(ctx) assert(not context, 'parser is non-reentrant'); context, depth = ctx, 0 end
function M.finish() context, depth = nil, nil end
function M.enter(cost)
  if context and not admission.reserve(context, 'compile', cost or 1) then
    errors.raise('E_BUDGET', 'source compilation work exhausted')
  end
end
function M.push()
  M.enter()
  depth = depth + 1
  if depth > limits.source_nesting then errors.raise('E_LIMIT', 'source nesting exceeds compiler limit') end
end
function M.pop() depth = depth - 1 end
return M
