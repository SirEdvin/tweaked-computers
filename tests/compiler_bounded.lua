-- Bounded compilation must not discard durable work on reconstruction refusal.
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local shell=require('scripts.runtime.shell')
local continuation=require('scripts.runtime.continuation')
local M={}
local loaded=false
shell.register_authority(function() return true end)
local function diagnostic(e)
  assert(e and e.code=='E_BUDGET' and e.recoverable and e.resource and e.setting,
    'bounded compilation needs an actionable recoverable diagnostic')
end
local function lowering_limit(rec,console,tick)
  local account=registry.get().host_memory
  local lower,cache=continuation.lower,limits.compiler_cache_bytes
  local entries={}
  continuation.lower=function(...)
    entries[#entries+1]=account.used+account.reserved
    return lower(...)
  end
  limits.compiler_cache_bytes=1
  local ok,problem=pcall(function()
    for _,case in ipairs({{rec.active.source},{console.shell.invocation.item.source,'shell'}}) do
      local plan,e=compiler.prepare(case[1],admission.context(admission.new(),'lowering-probe',tick),case[2])
      assert(plan,e and e.message)
    end
  end)
  continuation.lower,limits.compiler_cache_bytes=lower,cache
  assert(ok,type(problem)=='table' and problem.message or tostring(problem))
  assert(#entries==2,'fixture did not observe both real lowering entries')
  return math.max(entries[1],entries[2])
end
function M.run(native_memory)
  local saved=limits.compile_work
  limits.compile_work=1
  local plan,problem=compiler.prepare('function start() end',admission.context(admission.new(),'bounded',0))
  limits.compile_work=saved
  assert(not plan); diagnostic(problem)
  -- The durable backend has no native single-function local-register ceiling.
  local locals={}
  for i=1,220 do locals[i]='local v'..i..'='..i end
  local large='function start() '..table.concat(locals,';')..'; assert(v220==220) end'
  local root=registry.get()
  local accepted,e=compiler.prepare(large,admission.context(admission.new(),'many-locals',0))
  assert(accepted,e and e.message)
  assert(registry.get()==root,'standalone compilation initialized world storage')
  storage.tweaked_computers=false
  local corrupt,problem=compiler.prepare(large,admission.context(admission.new(),'corrupt-storage',0))
  storage.tweaked_computers=root
  assert(not corrupt and problem.message:find('unsupported host storage',1,true),'malformed storage bypassed admission')
  local depth=limits.host_stack_depth
  limits.host_stack_depth=1
  local rejected,depth_error=compiler.prepare(large,admission.context(admission.new(),'lowered-depth',0))
  limits.host_stack_depth=depth
  assert(not rejected and depth_error.recoverable and depth_error.resource=='host_stack_depth',
    'warm compiler cache bypassed the lowered host-depth policy')
  registry.initialize()

  local ids={}
  for i=1,2 do
    local entity=assert(game.surfaces[1].create_entity{name='constant-combinator',position={i*3,0},force='player'})
    ids[i]=registry.register('computer',entity).id
  end
  storage.tc_bounded={phase='start',ids=ids,compile=saved,native_memory=native_memory}
end
function M.on_load()
  if storage.tc_bounded.phase=='frozen' then loaded=true end
end
function M.on_tick(event)
  local f=storage.tc_bounded
  if f.phase=='done' then return end
  local rec=registry.computer(f.ids[1]); local console=registry.computer(f.ids[2])
  if f.phase=='start' then
    local body="local advertised=computer.getLimits(); for _,key in ipairs({'generated_source_bytes','source_nodes','source_tokens','source_nesting','handler_names'}) do assert(advertised[key]==nil) end; "
      .."computer.setState('prefix',(computer.getState('prefix') or 0)+1); local n=0; while n<200000 do n=n+1 end; computer.setState('result',n)"
    runtime.save(rec.id,'function start() '..body..' end',0)
    assert(runtime.activate(rec.id,event.tick))
    assert(shell.submit(console,body,1,1,event.tick,false))
    f.phase='running'
  elseif f.phase=='running' then
    scheduler.dispatch(rec,event.tick); scheduler.dispatch(console,event.tick)
    if rec.state.prefix and console.state.prefix then
      assert(rec.invocation and console.shell.invocation,'fixture missed durable suspension')
      f.program=rec.invocation; f.command=console.shell.invocation
      f.program_pc=f.program.checkpoint.frame.pc; f.command_pc=f.command.checkpoint.frame.pc
      f.run=rec.run_id
      limits.compile_work=1
      f.phase='refuse'
    end
  elseif f.phase=='refuse' then
    scheduler.dispatch(rec,event.tick); scheduler.dispatch(console,event.tick)
    assert(rec.invocation==f.program and console.shell.invocation==f.command,'reconstruction refusal discarded progress')
    assert(f.program.checkpoint.frame.pc==f.program_pc and f.command.checkpoint.frame.pc==f.command_pc)
    assert(rec.run_id==f.run and rec.status=='running' and rec.state.prefix==1 and console.state.prefix==1)
    diagnostic(rec.resource_refusal); diagnostic(console.resource_refusal)
    -- A new rejected candidate preserves the suspended old run and its source.
    local padding=f.native_memory and string.rep('local padding=0; ',200) or ''
    runtime.save(rec.id,'function start() '..padding..'computer.setState("wrong",true) end',rec.saved_revision)
    local run,e=runtime.activate(rec.id,event.tick)
    assert(not run); diagnostic(e)
    assert(rec.invocation==f.program and rec.run_id==f.run and rec.saved_source:find('wrong',1,true))
    f.phase='blocked'
  elseif f.phase=='blocked' then
    local calls=0; local prepare=compiler.prepare
    compiler.prepare=function(...) calls=calls+1; return prepare(...) end
    scheduler.dispatch(rec,event.tick); scheduler.dispatch(console,event.tick)
    compiler.prepare=prepare
    assert(calls==0,'unchanged impossible compilation was retried')
    assert(rec.invocation==f.program and console.shell.invocation==f.command)
    if not f.native_memory then
      f.phase='frozen'
      game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
      return
    end
    limits.compile_work=f.compile
    f.host_memory=limits.host_memory_bytes
    f.pressure_limit=lowering_limit(rec,console,event.tick)
    limits.host_memory_bytes=f.pressure_limit
    f.phase='memory-refuse'
  elseif f.phase=='memory-refuse' then
    local lower,calls=continuation.lower,0
    continuation.lower=function(...) calls=calls+1; return lower(...) end
    scheduler.dispatch(rec,event.tick); scheduler.dispatch(console,event.tick)
    continuation.lower=lower
    assert(calls==2,'memory fixture refused before reaching both lowering passes')
    assert(rec.invocation==f.program and console.shell.invocation==f.command,'native memory refusal discarded progress')
    assert(f.program.checkpoint.frame.pc==f.program_pc and f.command.checkpoint.frame.pc==f.command_pc)
    for _,e in ipairs({rec.resource_refusal,console.resource_refusal}) do
      assert(e.code=='E_CAPACITY' and e.recoverable and e.resource=='host_memory' and e.setting=='tc-host-memory-bytes')
    end
    local run,e=runtime.activate(rec.id,event.tick)
    assert(not run and e.recoverable and e.resource=='host_memory')
    assert(rec.invocation==f.program and rec.run_id==f.run and rec.saved_source:find('wrong',1,true))
    f.phase='memory-blocked'
  elseif f.phase=='memory-blocked' then
    local calls=0; local prepare=compiler.prepare
    compiler.prepare=function(...) calls=calls+1; return prepare(...) end
    scheduler.dispatch(rec,event.tick); scheduler.dispatch(console,event.tick)
    compiler.prepare=prepare
    assert(calls==0,'unchanged native memory refusal was retried')
    assert(rec.invocation==f.program and console.shell.invocation==f.command)
    f.phase='frozen'
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif f.phase=='frozen' then
    if not loaded then return end
    loaded=false
    assert(rec.invocation==f.program and console.shell.invocation==f.command)
    assert(f.program.checkpoint.frame.pc==f.program_pc and f.command.checkpoint.frame.pc==f.command_pc)
    limits.compile_work=f.compile
    if f.native_memory then
      limits.host_memory_bytes=f.pressure_limit
      assert(compiler.blocked(f.program) and compiler.blocked(f.command),'cold memory refusal lost its hold')
      limits.host_memory_bytes=f.host_memory
    end
    f.phase='resume'; f.resume_tick=event.tick
  elseif f.phase=='resume' then
    scheduler.dispatch(rec,event.tick); scheduler.dispatch(console,event.tick)
    assert(event.tick-f.resume_tick<600,'bounded reconstruction failed to resume')
    if not rec.invocation and not console.shell.invocation then
      assert(rec.state.result==200000 and console.state.result==200000)
      assert(rec.state.prefix==1 and console.state.prefix==1 and not rec.state.wrong and rec.run_id==f.run)
      f.phase='done'
      log('TC_CONTRACT bounded-compilation-program-console-refusal-cold-resume')
      log('TC_COLD_OK')
    end
  end
end
return M
