-- Explicit native sink/guard doubles; headless success is not audibility proof.
local registry=require('scripts.registry')
local speaker=require('scripts.services.speaker')
local carrier=require('scripts.speaker')
local peripheral=require('scripts.services.peripheral')
local admission=require('scripts.runtime.admission')
local sandbox=require('scripts.runtime.sandbox')
local compiler=require('scripts.runtime.compiler')
local memory=require('scripts.runtime.memory')
local limits=require('scripts.runtime.limits')
local harness=require('tests.radio_test_guard')
local catalogue_contract=require('tests.speaker_catalogue_contract')
local M={}; local loaded=false
local function real_guard_submission(record)
  local native=record.body.surface.play_sound
  for _,fail in ipairs({false,true}) do
    local account=memory.new(1000000,256)
    local owner=memory.owner(account)
    local ctx=admission.context(admission.new(),'speaker-real-guard',game.tick); ctx.memory_owner=owner
    local checkpoint={}; local calls=0; local prepaid=false
    record.body.surface.play_sound=function()
      calls=calls+1
      local pending=checkpoint.frame.pending
      local job=pending and pending.jobs and pending.jobs['speaker-submit']
      local retained=job and account.values[job]
      prepaid=job and job.attempted and job.failed==false and retained and retained.bytes==192+48*2
        and pending.result_kind=='boolean' and pending.prepared~=nil
      if fail then error('injected native failure') end
    end
    local source='function start() local ok,value=pcall(computer.submit); computer.result(ok,value) end'
    local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
    local observed
    local ok,problem=compiler.run(plan,'start',nil,function(g)
      return {computer={
        submit=function() return speaker.methods.playSound({id='speaker-real-guard'},record,'red',game.tick,g.spend,g,'utility/wire_connect_pole',0) end,
        result=function(success,value) g.prepare_empty_result(); observed={success=success,value=value} end,
      }}
    end,ctx,checkpoint)
    assert(ok,problem and problem.message)
    assert(calls==1 and observed and observed.success==not fail)
    assert(fail and observed.value.code=='E_ENGINE' or not fail and observed.value==true)
    assert(prepaid,'speaker submission metadata grew after the irreversible boundary')
    memory.close(owner,function() end)
    assert(account.reserved==0 and next(account.values)==nil and next(account.owners)==nil)
  end
  record.body.surface.play_sound=native
end
function M.run()
  registry.initialize()
  local requests={}; local current; local fail=false
  local record={id='speaker-fixture',body={position={x=3,y=7},surface={play_sound=function(request)
    requests[#requests+1]=request
    assert(request.position.x==3 and request.position.y==7 and request.override_sound_type=='game-effect')
    if fail then error('injected native failure') end
  end}}}
  local authority,available=peripheral.authority,carrier.available
  peripheral.authority=function() return record end; carrier.available=function() return true end
  local ok,problem=pcall(function()
    local function call(method,...)
      local guard=harness.new(current)
      return speaker.methods[method]({id='computer-fixture'},record,'red',game.tick,guard.spend,guard,...)
    end
    for _=1,65 do current={}; assert(call('playNote','piano',0,0)) end
    for _=1,17 do current={}; assert(call('playSound','utility/wire_connect_pole',0)) end
    assert(#requests==82)
    current={}; assert(call('playSound','utility/wire_connect_pole',0))
    assert(call('playSound','utility/wire_connect_pole',0) and #requests==83)
    log('TC_CONTRACT removed-speaker-computer-world-counts-and-attempted-call-idempotence')
    current={}; fail=true
    local success,e=pcall(call,'playSound','utility/wire_connect_pole',0)
    assert(not success and e.code=='E_ENGINE' and #requests==84)
    success,e=pcall(call,'playSound','utility/wire_connect_pole',0)
    assert(not success and e.code=='E_ENGINE' and #requests==84)
    fail=false
    log('TC_CONTRACT native-failure-is-not-replayed')
    for _,which in ipairs({'work','allocations'}) do
      local ctx=admission.context(admission.new(),'prepared-boolean-'..which,game.tick)
      local g=sandbox.new(ctx,{}); local entered=0
      local fn=g.service(function()
        g.prepare_boolean_result(); entered=entered+1; current={}
        return call('playSound','utility/wire_connect_pole',0)
      end)
      if which=='work' then ctx.machine.work=limits.callback_work-5
      else ctx.machine.allocations=limits.callback_allocations-2 end
      local before=#requests; assert(not pcall(g.call,fn)); assert(entered==0 and #requests==before)
    end
    log('TC_CONTRACT insufficient-prepaid-result-submits-nothing')
    catalogue_contract.run()
    log('TC_CONTRACT complete-configurable-pages-and-invalid-native-candidates')
    real_guard_submission(record)
    log('TC_CONTRACT real-continuation-guard-prepays-complete-speaker-result-and-job')
    log('TC_CONTRACT_TOTAL 5')
  end)
  peripheral.authority,carrier.available=authority,available
  assert(ok,serpent.line(problem))
  local source='function start() local ok,value=pcall(computer.submit); computer.result(ok,value) end'
  local plan,e=compiler.compile(source); assert(plan,e and e.message)
  storage.speaker_admission_cold={phase='arm',cases={}}
  for _,cut in ipairs({'before','after','failed','revoked'}) do
    local account=memory.new(1000000,256)
    storage.speaker_admission_cold.cases[#storage.speaker_admission_cold.cases+1]={
      cut=cut,plan=plan,checkpoint={},ledger=admission.new(),account=account,owner=memory.owner(account),calls=0,deliveries=0}
  end
end
local function cold_step(f,tick,arming)
  -- Only the native sink and authority are doubles; compilation, guards, retained
  -- admission, suspension and result delivery use their production implementations.
  local record={id='speaker-cold-fixture',body={position={x=3,y=7},surface={play_sound=function()
    f.calls=f.calls+1
    if f.cut=='failed' then error('injected native failure') end
  end}}}
  local authority,available=peripheral.authority,carrier.available
  peripheral.authority=function() if arming or f.cut~='revoked' then return record end end
  carrier.available=function() return true end
  local ctx=admission.context(f.ledger,'speaker-cold-'..f.cut,tick); ctx.memory_owner=f.owner
  local called,ok,e,control=pcall(compiler.run,f.plan,'start',nil,function(g)
    local prepare=g.prepare_boolean_result
    g.prepare_boolean_result=function()
      prepare()
      if arming and (f.cut=='before' or f.cut=='revoked') then g.suspend() end
    end
    return {computer={
      submit=function()
        local success,value=pcall(speaker.methods.playSound,{id='speaker-cold-'..f.cut},record,'red',tick,g.spend,g,'utility/wire_connect_pole',0)
        if arming then g.suspend() end -- Freeze before the caller receives either native outcome.
        if not success then error(value,0) end
        return value
      end,
      result=function(success,value)
        g.prepare_empty_result(); f.deliveries=f.deliveries+1
        f.success=success; f.value=value
      end,
    }}
  end,ctx,f.checkpoint)
  peripheral.authority,carrier.available=authority,available
  assert(called,tostring(ok))
  return ok,e,control
end
function M.on_load()
  local state=storage.speaker_admission_cold
  if state.phase=='frozen' then
    for _,f in ipairs(state.cases) do
      assert(f.checkpoint.frame==f.frame and f.frame.pending==f.pending and f.frame.pc==f.pc)
      assert(f.calls==f.saved_calls and f.deliveries==0 and f.ledger.total==f.spent)
    end
    loaded=true; log('TC_SPEAKER_ADMISSION_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  local state=storage.speaker_admission_cold
  if state.phase=='done' or state.phase=='frozen' and not loaded then return end
  if loaded then loaded=false; state.phase='resume' end
  local arming=state.phase=='arm'; local done=true
  for _,f in ipairs(state.cases) do
    if not f.done then
      local ok,e,control=cold_step(f,event.tick,arming)
      assert(ok or control=='wait',e and e.message)
      if arming then
        assert(not ok and f.deliveries==0)
        f.frame=f.checkpoint.frame; f.pending=f.frame.pending; f.pc=f.frame.pc
        local job=f.pending.jobs['speaker-submit']
        local submitted=f.cut=='after' or f.cut=='failed'
        assert(job.attempted==submitted and job.failed==(f.cut=='failed'))
        assert(f.calls==(submitted and 1 or 0) and f.pending.prepared and f.pending.result_kind=='boolean')
        assert(f.account.values[job].bytes==192+48*2)
        f.saved_calls=f.calls; f.spent=f.ledger.total
      elseif ok then
        assert(f.deliveries==1 and f.calls==(f.cut=='revoked' and 0 or 1),'speaker replayed or lost submission/delivery')
        if f.cut=='failed' or f.cut=='revoked' then
          assert(not f.success and f.value.code==(f.cut=='failed' and 'E_ENGINE' or 'E_UNREACHABLE'))
        else assert(f.success and f.value==true) end
        memory.close(f.owner,function() end)
        assert(f.account.reserved==0 and next(f.account.values)==nil and next(f.account.owners)==nil)
        f.done=true
      else done=false end
    end
  end
  if arming then
    state.phase='frozen'; state.tick=event.tick
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  assert(event.tick-state.tick<30,'speaker cold continuation deadline')
  if done then state.phase='done'; log('TC_CONTRACT real-speaker-guard-cold-before-after-failure-and-revocation'); log('TC_COLD_OK') end
end
return M
