-- Save-backed scratch values, ordered ingress and private command continuations.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local compiler=require('scripts.runtime.compiler')
local sandbox=require('scripts.runtime.sandbox')
local values=require('scripts.runtime.shell-values')
local principal=require('scripts.runtime.principal')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local policy=require('scripts.runtime.resource-policy')
local memory=require('scripts.runtime.memory')
local private_jobs=require('scripts.runtime.private-jobs')
local M={}
local authorize
function M.register_authority(fn) assert(not authorize); authorize=fn end
local function supported(s)
  if type(s)~='table' or getmetatable(s) or s.version~=1 or type(s.id)~='string' or #s.id==0 or #s.id>128
    or type(s.pending)~='table' or getmetatable(s.pending) or not errors.integer(s.pending_bytes,0,9007199254740991) then return false end
  local count,bytes=0,0
  for k,item in pairs(s.pending) do
    count=count+1
    if not errors.integer(k,1,9007199254740991)
      or type(item)~='table' or getmetatable(item) or type(item.source)~='string'
      or not errors.integer(item.id,1,9007199254740991) or not errors.integer(item.player,1,9007199254740991)
      or not errors.integer(item.token,1,9007199254740991) or type(item.session)~='string' or #item.session>128 then return false end
    bytes=bytes+#item.source
  end
  for i=1,count do if s.pending[i]==nil then return false end end
  return bytes==s.pending_bytes
end
function M.session(rec)
  if rec.shell and not supported(rec.shell) then errors.raise('E_UNSUPPORTED','unknown shell schema; data retained') end
  return rec.shell
end
local function log(rec,id,kind,text,tick,spend,prepare)
  local prefix='Shell #'..tostring(id)..' '..kind..': '
  if #prefix+#text>limits.console_bytes then errors.raise('E_LIMIT','shell console entry too large') end
  runtime.log(rec,prefix..text,tick,spend,prepare)
end
function M.reset(rec,reason)
  if not rec.shell then return true end
  if not supported(rec.shell) then
    if reason=='activation' or reason=='stop' then return true end -- Preserve unknown data, never block compatible programs.
    errors.raise('E_UNSUPPORTED','unknown shell schema; data retained')
  end
  if not principal.cleanup(rec,principal.shell(rec),reason or 'reset') then return false end
  policy.release(rec.shell.invocation)
  memory.retire(rec.shell.values_owner)
  rec.shell=nil
  return true
end
function M.submit(rec,source,player,token,tick,expected)
  if type(source)~='string' or #source>limits.shell_source_bytes or source:find('[\r\n]') then
    errors.raise('E_ARGUMENT','one line of at most '..limits.shell_source_bytes..' bytes required')
  end
  if not source:find('%S') then return false end
  local s=M.session(rec)
  if expected~=(s and s.id or false) then errors.raise('E_BUSY','shell session changed; review before submitting') end
  if not rec.powered or not rec.body.valid then errors.raise('E_UNPOWERED','computer must be powered') end
  if not authorize or not authorize(rec,player,token) then errors.raise('E_UNREACHABLE','opened Console authority required') end
  if s and (#s.pending>=limits.shell_pending_entries or s.pending_bytes+#source>limits.shell_pending_bytes) then errors.raise('E_CAPACITY','shell queue full; draft retained') end
  local ctx=runtime.context(rec,tick)
  if not admission.reserve(ctx,'work',#source+limits.registry_entries+limits.shell_pending_entries+128) then errors.raise('E_BUDGET','shell ingress deferred; draft retained') end
  if not s then
    local count=0
    for _,c in pairs(registry.get().computers) do if c.shell then count=count+1 end end
    if count>=limits.shell_sessions then errors.raise('E_CAPACITY','retained shell session capacity; reset an unused shell') end
    s={version=1,id=rec.id..'/shell-'..string.format('%.0f',registry.sequence()),pending={},pending_bytes=0}
    rec.shell=s
  end
  local id=registry.sequence()
  s.pending[#s.pending+1]={source=source,id=id,player=player,token=token,session=s.id}
  s.pending_bytes=s.pending_bytes+#source
  s.status='Queued #'..string.format('%.0f',id)
  return id
end
function M.waiting(rec)
  return supported(rec.shell) and (#rec.shell.pending>0 or rec.shell.invocation~=nil)
end
function M.evaluate(rec,source,tick,command,checkpoint)
  local s=M.session(rec); local ctx=runtime.context(rec,tick)
  if checkpoint then
    local invocation=s.invocation
    local direct=not invocation or invocation.checkpoint~=checkpoint
    if direct then
      invocation={checkpoint=checkpoint,memory_owner=rec.runtime_memory and rec.runtime_memory.owners[checkpoint.memory_owner]}
    end
    local function finish(ok,diagnostic,control)
      if direct and control~='wait' then policy.release(invocation) end
      return ok,diagnostic,control
    end
    local attached,problem=pcall(policy.attach,rec,invocation,ctx)
    if not attached then
      local diagnostic=errors.resource_diagnostic(problem) or errors.new('E_UNSUPPORTED','runtime ownership unavailable; source retained')
      return finish(false,diagnostic,diagnostic.recoverable and 'resource' or nil)
    end
    local execution=principal.shell(rec); local guard
    local shell={values=s.values,output=function(text) log(rec,command,'output',text,tick,guard.spend) end}
    local plan={source=source,mode='shell',api_version=1,compiler_version=limits.compiler_version}
    local ok,diagnostic,control=compiler.run(plan,'command',{},function(g)
      guard=g
      local services=runtime.services(rec,tick,g,execution)
      services.computer.log=function(text) log(rec,command,'output',text,tick,g.spend,g.prepare_empty_result) end
      return services
    end,ctx,checkpoint,shell)
    if ok then
      local owner
      local admitted,problem=pcall(function()
        owner=memory.owner(ctx.memory_owner.account)
        private_jobs.admit(checkpoint,owner,checkpoint.value_graph,guard.spend)
      end)
      if not admitted then
        memory.retire(owner)
        local diagnostic=guard.diagnostic(problem)
        return finish(false,diagnostic,diagnostic.recoverable and 'resource' or nil)
      end
      memory.retire(s.values_owner)
      s.values_owner=owner; s.values=checkpoint.value_graph
    elseif control~='wait' and control~='resource' and checkpoint.frame and not principal.cleanup(rec,execution,'shell_failure') then
      diagnostic=errors.new('E_ENGINE','shell resource cleanup failed; committed values retained')
    end
    return finish(ok,diagnostic,control)
  end
  local plan,diagnostic=compiler.compile(source,ctx,'shell')
  if not plan then return false,diagnostic end
  if not admission.reserve(ctx,'compile',#plan.generated+plan.nodes+1) then return false,errors.new('E_BUDGET','shell reconstruction refused') end
  local execution=principal.shell(rec)
  local guard
  local shell={output=function(text) log(rec,command,'output',text,tick,guard.spend) end}
  guard=sandbox.new(ctx,function(g)
    local services=runtime.services(rec,tick,g,execution)
    services.computer.log=function(text) log(rec,command,'output',text,tick,g.spend,g.prepare_empty_result) end
    return services
  end,shell)
  local started=false
  local ok,result=pcall(function()
    guard.initialize()
    shell.root=values.decode(s.values,guard)
    local factory,problem=load(plan.generated,'@computer','t',{__tc=guard})
    if not factory then errors.raise('E_PROGRAM',problem) end
    guard.step(1)
    started=true
    local tuple=table.pack(guard.call(factory()))
    guard.format_results(tuple)
    local graph=values.encode(shell.root,guard)
    guard.check()
    s.values=graph -- Single publication; earlier real API effects are not rolled back.
  end)
  if not ok then
    diagnostic=guard.diagnostic(result)
    if started and not principal.cleanup(rec,execution,'shell_failure') then diagnostic=errors.new('E_ENGINE','shell resource cleanup failed; committed values retained') end
    return false,diagnostic
  end
  return true
end
function M.dispatch(rec,tick)
  local s=M.session(rec)
  if not M.waiting(rec) or rec.last_dispatch_tick==tick then return false end
  local item=s.invocation and s.invocation.item or s.pending[1]
  local admitted,ctx=pcall(runtime.context,rec,tick)
  if not admitted then
    if type(ctx)=='table' and ctx.code=='E_BUSY' then return false end
    s.status='Shell admission unavailable; pending source retained'
    return false
  end
  -- Prepay echo, one bounded recovery diagnostic and exact-principal teardown
  -- before any command effect. Traversal/serialization also charge before each
  -- bounded operation; a refusal can never publish a partial value graph.
  local overhead=#item.source+(#rec.logs)^2*2+#registry.get().order*4+4096
  if not s.invocation and not admission.reserve(ctx,'work',overhead) then return false end
  -- Unstarted records are consumed exactly once, even on loss of UI authority.
  rec.last_dispatch_tick=tick
  local started=s.invocation~=nil
  if not started then table.remove(s.pending,1); s.pending_bytes=s.pending_bytes-#item.source end
  local valid=rec.powered and rec.body.valid and item.session==s.id and authorize and authorize(rec,item.player,item.token)
  if not valid then
    if started then
      principal.cleanup(rec,principal.shell(rec),'command_canceled')
      policy.release(s.invocation); s.invocation=nil
    end
    s.status='Canceled #'..item.id..': Console authority or power changed'
    log(rec,item.id,'canceled','Console authority or power changed',tick); return true
  end
  if not started then
    log(rec,item.id,'player '..item.player,item.source,tick)
    s.invocation={item=item,checkpoint={}}
    s.diagnostic=nil
  end
  local ok,problem,control=M.evaluate(rec,item.source,tick,item.id,s.invocation.checkpoint)
  if control=='wait' then s.status='Waiting #'..item.id; return true end
  policy.release(s.invocation)
  s.invocation=nil
  s.status=(ok and 'Completed #' or 'Failed #')..item.id
  s.diagnostic=problem
  if problem and problem.recoverable then runtime.resource_refused(rec,problem,tick) end
  if not ok then
    log(rec,item.id,'error',(problem.code or 'E_PROGRAM')..': '..(problem.message or 'command failed')..' | '..(problem.line or 1)..':'..(problem.column or 1),tick)
  end
  return true
end
runtime.register_shell_lifecycle(M.reset)
registry.register_cleanup('shell-safety',function(rec,run,reason)
  if rec.kind~='computer' or not supported(rec.shell) then return end
  if reason=='fault' or reason=='stop' or reason=='activation' then return end
  local s=rec.shell
  if #s.pending>0 then s.status='Canceled pending commands: '..reason end
  s.pending={}; s.pending_bytes=0
  if not principal.cleanup(rec,principal.shell(rec),reason) then error('shell cleanup failed',0) end
  policy.release(s.invocation); s.invocation=nil
end)
return M
