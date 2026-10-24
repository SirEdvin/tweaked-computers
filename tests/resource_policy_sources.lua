-- Saved and active source ownership, including native cold/material recovery.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local policy=require('scripts.runtime.resource-policy')
local memory=require('scripts.runtime.memory')
local limits=require('scripts.runtime.limits')
local scheduler=require('scripts.scheduler')
local material=require('scripts.lifecycle-data')
local M={}; local loaded=false
local function nop() end
local function computer(x)
  local body=assert(game.surfaces[1].create_entity{name='constant-combinator',position={x,0},force='player'})
  return registry.register('computer',body)
end
function M.run()
  registry.initialize()
  local rec=computer(0); local other=computer(3)
  local legacy=computer(-3)
  legacy.saved_source='-- accepted before source ownership'; legacy.saved_revision=7
  legacy.active={source=legacy.saved_source,revision=7,api_version=1,
    compiler_version=limits.compiler_version,storage_version=1,handlers={}}
  local configured=limits.host_memory_bytes; limits.host_memory_bytes=1
  local stop={}
  local ok,problem=pcall(policy.host_account,function()
    local account=registry.get().host_memory
    if account and account.owners[2] then error(stop,0) end
  end)
  local account=registry.get().host_memory
  assert(not ok and problem==stop and account.used==384 and account.reserved==0)
  assert(not registry.get().source_memory_version and not rec.saved_source_memory and not legacy.active_source_memory)
  assert(account.limit==1 and legacy.saved_revision==7 and legacy.active.source==legacy.saved_source)
  policy.host_account(nop)
  assert(legacy.saved_source_memory and legacy.active_source_memory and account.used>account.limit)
  assert(account.values[legacy.saved_source].owners==2)
  registry.remove(legacy.id,'legacy-source-fixture'); policy.reconcile(registry.get(),nop)
  limits.host_memory_bytes=configured
  local source='--'..string.rep('x',20000)..'\nfunction start() computer.setState("starts",(computer.getState("starts") or 0)+1) end'
  runtime.save(rec.id,source,0)
  runtime.save(other.id,source,0)
  local account=policy.host_account(nop)
  assert(limits.source_bytes==nil)
  assert(rec.saved_source_memory and other.saved_source_memory)
  assert(account.values[source].owners==2,'shared saved source payload was duplicated')
  local run,e=runtime.activate(rec.id,0); assert(run,e and e.message)
  assert(rec.active_source_memory and account.values[source].owners==3)
  -- A shorter string still needs new payload storage when aliases keep the old one.
  local available=limits.host_memory_bytes; limits.host_memory_bytes=account.used
  local used=account.used
  local ok,problem=pcall(runtime.save,other.id,'short',other.saved_revision)
  assert(not ok and problem.recoverable and other.saved_source==source and other.saved_revision==1)
  assert(account.values[source].owners==3 and account.used==used and account.reserved==0)
  limits.host_memory_bytes=available
  local changed=source..'\n-- different saved revision'
  runtime.save(rec.id,changed,rec.saved_revision)
  assert(rec.active.source==source and account.values[source].owners==2 and account.values[changed].owners==1)
  local old_source,revision,used=rec.saved_source,rec.saved_revision,account.used
  local default=limits.host_memory_bytes
  limits.host_memory_bytes=used
  local ok,problem=pcall(runtime.save,rec.id,changed..'growth',revision)
  assert(not ok and problem.recoverable and problem.resource=='host_memory')
  assert(rec.saved_source==old_source and rec.saved_revision==revision and rec.run_id==run
    and account.used==used and account.reserved==0,'refused Save changed accepted source or accounting')
  -- Activation must reserve new source metadata before stopping the old run.
  local started,refused=runtime.activate(rec.id,1)
  assert(not started and refused.recoverable and rec.run_id==run and rec.status=='running')
  assert(rec.active.source==source and account.used==used and account.reserved==0)
  limits.host_memory_bytes=1
  runtime.save(rec.id,'',revision)
  assert(rec.saved_source=='' and rec.active.source==source and not account.values[changed])
  runtime.save(rec.id,'',rec.saved_revision)
  local snapshot=material.computer_snapshot(rec,false)
  assert(snapshot.active.source==source and snapshot.saved_source=='')
  assert(runtime.stop(rec.id)); assert(rec.active.source==source and account.values[source])
  storage.tc_source_policy={phase='frozen',id=rec.id,other=other.id,source=source,snapshot=snapshot,
    default=default,used=account.used,run=run,owner=rec.saved_source_memory,active=rec.active_source_memory}
  log('TC_CONTRACT source-storage-shared-owners-refusal-before-retirement-grandfathered-shrink')
end
function M.on_load()
  if storage.tc_source_policy.phase=='saved' then loaded=true end
end
function M.on_tick(event)
  local f=storage.tc_source_policy
  if f.phase=='done' then return end
  local rec=registry.record(f.id); local account=policy.host_account(nop)
  if f.phase=='frozen' then
    limits.host_memory_bytes=1; policy.host_account(nop)
    assert(account.used==f.used and rec.saved_source_memory==f.owner and rec.active_source_memory==f.active)
    f.phase='saved'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif f.phase=='saved' and loaded then
    loaded=false
    limits.host_memory_bytes=1; policy.host_account(nop)
    assert(account.used==f.used and rec.saved_source_memory==f.owner and rec.active_source_memory==f.active)
    assert(rec.active.source==f.source and rec.run_id==f.run and rec.status=='stopped' and not rec.state.starts)
    local restored=computer(6)
    material.restore_computer(restored,f.snapshot,false)
    assert(restored.active.source==f.source and restored.saved_source=='' and not restored.run_id)
    assert(restored.saved_source_memory and restored.active_source_memory,'material recovery lost ownership')
    -- Cleanup can pause halfway through an owner without releasing live aliases.
    assert(registry.remove(rec.id,'source-fixture'))
    local stop={}; local credits=1
    local ok,problem=pcall(policy.reconcile,registry.get(),function(n)
      if n>credits then error(stop,0) end; credits=credits-n
    end)
    assert(not ok and problem==stop and account.closing and account.values[f.source])
    assert(restored.active_source_memory.values[f.source] and not restored.active_source_memory.closing)
    assert(registry.remove(f.other,'source-fixture'))
    assert(registry.remove(restored.id,'source-fixture'))
    policy.reconcile(registry.get(),nop)
    assert(account.used==384 and account.reserved==0 and next(account.values)==nil,'removed source owners leaked')
    limits.host_memory_bytes=f.default
    local fresh=computer(9)
    runtime.save(fresh.id,f.source,0)
    local run,e=runtime.activate(fresh.id,event.tick); assert(run,e and e.message)
    f.fresh=fresh.id; f.phase='execute'; f.deadline=event.tick+120
  elseif f.phase=='execute' then
    local fresh=registry.computer(f.fresh)
    scheduler.dispatch(fresh,event.tick)
    assert(event.tick<f.deadline,'large saved source did not execute')
    if not fresh.invocation then
      assert(fresh.state.starts==1)
      f.phase='done'; log('TC_CONTRACT source-storage-cold-material-transfer-release-and-large-activation'); log('TC_COLD_OK')
    end
  end
end
return M
