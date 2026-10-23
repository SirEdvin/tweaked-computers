-- Current-job service shorthand must resize the real ledger, not a test counter.
local sandbox=require('scripts.runtime.sandbox')
local admission=require('scripts.runtime.admission')
local memory=require('scripts.runtime.memory')
local errors=require('scripts.runtime.errors')
local M={}
local function checkpoint()
  return {owned={},owned_order={},symbols={},bindings={},functions={}}
end
function M.run()
  local account=memory.new(32768,256)
  local owner=memory.owner(account)
  local context=admission.context(admission.new(),'job-signature',1)
  context.memory_owner=owner
  local saved,pending=checkpoint(),{}
  local g=sandbox.new(context,{},nil,saved)
  g.call_checkpoint(pending)
  local job=g.job('service',function() return {phase='prepare'} end)
  local before=account.used
  g.job_resize(512)
  assert(owner.values[job].record.bytes==512 and account.used>before)
  g.job_resize(job,768)
  assert(owner.values[job].record.bytes==768)
  local restored=sandbox.new(context,{},nil,saved)
  restored.call_checkpoint(pending)
  assert(restored.job('service',function() error('initializer replayed') end)==job)
  memory.configure(account,account.used)
  before=account.used
  local ok,problem=pcall(restored.job_resize,1024)
  assert(not ok and errors.resource_diagnostic(problem).recoverable)
  assert(owner.values[job].record.bytes==768 and account.used==before)
  memory.configure(account,account.used-1)
  restored.job_resize(512)
  assert(owner.values[job].record.bytes==512 and account.used<before)
  restored.call_checkpoint(nil)
  before=account.used
  assert(not pcall(restored.job_resize,1024) and account.used==before)
  local unowned=sandbox.new(admission.context(admission.new(),'missing-owner',1),{},nil,checkpoint())
  unowned.call_checkpoint({})
  unowned.job('service',function() return {} end)
  ok,problem=pcall(unowned.job_resize,512)
  assert(not ok and problem.code=='E_UNSUPPORTED','service shorthand silently skipped memory admission')
  memory.close(owner,function() end)
  assert(account.used==512)
  log('TC_CONTRACT current-job-signatures-real-memory-refusal-shrink-and-rebinding')
end
return M
