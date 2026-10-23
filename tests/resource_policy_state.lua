-- Real settings, scheduler ticks and cold reload of grandfathered application state.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local limits=require('scripts.runtime.limits')
local defs=require('scripts.device-definitions')
local M={}; local loaded=false
local source=[[function start()
  computer.setState('starts',(computer.getState('starts') or 0)+1)
  computer.setState('kept',string.rep('x',16000))
end
function recover()
  assert(computer.getState('starts')==1,'startup replayed')
  local before=computer.getState('kept'); assert(#before==16000)
  computer.setState('kept',before)
  computer.setState('kept',string.sub(before,1,8000))
  local ok,e=pcall(computer.setState,'kept',before)
  assert(not ok and e.recoverable and e.resource=='state_bytes' and e.limit==32)
  assert(#computer.getState('kept')==8000)
  ok,e=pcall(computer.setState,'new',false)
  assert(not ok and e.recoverable and e.setting=='tc-state-bytes')
  assert(computer.getState('new')==nil)
  assert(computer.deleteState('kept') and computer.deleteState('starts'))
end
function raised()
  computer.setState('renewed',true)
end]]
local function setting(value)
  settings.global['tc-state-bytes']={value=value}
  assert(script.get_event_handler(defines.events.on_runtime_mod_setting_changed)){
    setting='tc-state-bytes',setting_type='runtime-global',tick=game.tick}
  assert(limits.state_bytes==value)
end
function M.run()
  local body=assert(game.surfaces[1].create_entity{name=defs.devices.computer.entity_name,position={0,0},force='player'})
  lifecycle.on_built{entity=body}; local rec=assert(registry.by_entity(body))
  lifecycle.power_entity(rec).energy=1000000; rec.powered=true
  assert(runtime.save(rec.id,source,rec.saved_revision))
  assert(runtime.activate(rec.id,game.tick))
  storage.tc_state_policy={id=rec.id,phase='seed',run_id=rec.run_id,started=game.tick,old_limit=limits.state_bytes}
end
function M.on_load()
  local f=storage.tc_state_policy
  if f.phase=='frozen' then
    local rec=registry.record(f.id)
    assert(rec.run_id==f.run_id and rec.state==f.state and rec.state_bytes==f.bytes and rec.state.starts==1)
    assert(limits.state_bytes==32 and rec.state_bytes>limits.state_bytes)
    assert(registry.get().ledger.total==f.work and registry.get().ledger.tick==f.tick)
    loaded=true; log('TC_STATE_POLICY_ON_LOAD_UNCHANGED')
  end
end
function M.on_tick(event)
  local f=storage.tc_state_policy; if f.phase=='done' then return end
  if f.phase=='frozen' and not loaded then return end
  local rec=registry.record(f.id)
  lifecycle.power_entity(rec).energy=1000000; rec.powered=true
  assert(event.tick-f.started<300,'state-policy fixture deadline')
  if loaded then
    loaded=false; f.phase='recover'
    assert(runtime.enqueue(rec,'recover',{name='fixture'},event.tick))
  end
  scheduler.tick(event.tick)
  assert(rec.status=='running',rec.diagnostic and rec.diagnostic.message)
  if rec.invocation or #rec.queue>0 then return end
  assert(rec.run_id==f.run_id)
  if f.phase=='seed' then
    assert(rec.state.starts==1 and #rec.state.kept==16000)
    local ledger=registry.get().ledger
    f.state=rec.state; f.bytes=rec.state_bytes; f.work=ledger.total; f.tick=ledger.tick
    setting(32)
    assert(rec.state==f.state and rec.state_bytes==f.bytes and ledger.total==f.work)
    f.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif f.phase=='recover' then
    assert(next(rec.state)==nil and rec.state_bytes==16 and rec.state_entries==0 and rec.state_nodes==1)
    local work=registry.get().ledger.total; setting(f.old_limit)
    assert(registry.get().ledger.total==work,'raising storage renewed work')
    f.phase='raised'; assert(runtime.enqueue(rec,'raised',{name='fixture'},event.tick))
  else
    assert(f.phase=='raised' and rec.state.renewed)
    assert(runtime.stop(rec.id) and rec.status=='stopped' and rec.state.renewed)
    f.phase='done'; log('TC_CONTRACT state-lower-cold-read-shrink-refuse-delete-raise-and-stop'); log('TC_COLD_OK')
  end
end
return M
