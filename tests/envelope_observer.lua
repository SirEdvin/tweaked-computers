-- Test-only forwarding observations. Never retained in storage or guest data.
local M={}
function M.reset() M.sample={prepared=0,cleaned=0,commits=0,visibility=0,commit_work=0,max_commit=0} end
function M.prepare() M.sample.prepared=M.sample.prepared+1 end
function M.cleanup() M.sample.cleaned=M.sample.cleaned+1 end
function M.commit(operations,work)
  local s=M.sample
  s.commits=s.commits+1; s.visibility=s.visibility+operations; s.commit_work=s.commit_work+work
  s.max_commit=math.max(s.max_commit,operations)
  assert(operations<=42352 and work<=160000,'native publication ceiling')
end
M.reset()
return M
