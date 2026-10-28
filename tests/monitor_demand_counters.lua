-- Ephemeral structural instrumentation only; never saved or used for admission.
local M={}; local counts
function M.count(key,n) if counts then counts[key]=(counts[key] or 0)+(n or 1) end end
function M.begin() counts={} end
function M.finish() local result=counts; counts=nil; return result end
function M.visibility() M.count('visibility') end
return M
