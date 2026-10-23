-- Populated by the actual released ZIP, not a fabricated old schema. The
-- candidate must preserve ownership/data and must not run start() on upgrade.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local monitor=require('scripts.services.monitor')
local model=require('scripts.monitor-model')
local kv=require('scripts.services.kv')
local scene=require('tests.resource_policy_multiplayer_scene')
local M={}; local loaded=false
local function f() return storage.tc_policy_upgrade end
local function rec() return registry.computer(storage.tc_shell_client.computer) end
local function nop() end
local function graph(root)
  local seen,records={},{}
  local function visit(t)
    if type(t)~='table' or rawget(t,'__self') or seen[t] then return end
    seen[t]=true; local r={target=t,entries={}}; records[#records+1]=r
    for k,v in pairs(t) do r.entries[#r.entries+1]={k,v}; visit(k); visit(v) end
  end
  visit(root); return records
end
local function retained()
  local x=f(); local c=rec(); local db=registry.record(storage.tc_shell_client.db)
  local logic=registry.record(storage.tc_shell_client.logic)
  assert(c.run_id==x.run and c.run_generation==x.generation and c.status=='running','run identity/status lost')
  assert(c.state==x.state and c.state.boots==1 and not c.state.timer,'state lost/startup replay')
  assert(c.active==x.active and c.active.source==x.active_source and c.saved_source==x.saved and c.saved_revision==x.revision,'active/saved sources changed')
  assert(c.timers==x.timers and c.queue==x.queue,'timers/queue replaced')
  assert(db.database==x.database and db.database.entries.secret.value=='retained-value','KV replaced')
  assert(db.database.entries.secret.deadline==x.deadline and db.database.entries.hash.fields.field=='retained-hash','KV TTL/hash changed')
  assert(logic.output_bank==x.output and logic.output_owner==x.owner,'output ownership changed')
  local output=logic.children.output.get_control_behavior()
  assert(output.enabled and output.get_section(1).get_slot(1).min==13,'native output changed')
  assert(monitor.resolve(registry.record(storage.tc_shell_client.monitor_tile))==x.display and x.display.model==x.model,'display replaced')
  assert(x.model.cells[1][1]==75,'display content lost')
  assert(x.display.render==x.front and x.front.cells[1].value[1]==75,'published display front replaced/lost')
end
local function frozen()
  retained()
  for _,r in ipairs(f().graph) do
    local n=0; for _ in pairs(r.target) do n=n+1 end
    assert(n==#r.entries,'retained legacy graph key count changed')
    for _,e in ipairs(r.entries) do assert(r.target[e[1]]==e[2],'retained legacy graph value/alias changed') end
  end
end
function M.run()
  scene.run(); runtime.stop(storage.tc_shell_client.computer)
  storage.tc_policy_upgrade={phase='power',release=script.active_mods['tweaked-computers']}
  assert(f().release=='0.1.13','expected genuine 0.1.13 baseline')
end
function M.on_load()
  loaded=true
  if f().phase=='frozen' then frozen(); log('TC_LEGACY_LOAD_UNCHANGED') end
end
function M.on_configuration_changed()
  frozen(); f().upgraded=true; f().phase='verify'; f().graph=nil
  log('TC_LEGACY_CONFIGURATION_RETAINED')
end
function M.on_tick(e)
  local x=f(); local c=rec()
  if x.phase=='done' then return end
  if x.phase=='frozen' then
    if loaded then frozen(); x.phase='done'; log('TC_COLD_OK genuine-0.1.13-ordinary-load') end
    return
  end
  loaded=false
  if x.phase=='power' then
    scheduler.tick(e.tick)
    local display=monitor.resolve(registry.record(storage.tc_shell_client.monitor_tile))
    if not c.powered or not display then return end
    local source="return {api_version=1,handlers={start=function() computer.setState('boots',(computer.getState('boots') or 0)+1); computer.every(100000,'timer'); peripheral.wrap('"..storage.tc_shell_client.logic.."','red').setOutput({{signal={type='virtual',name='signal-C'},count=13}}) end,later=function(e) computer.setState('order',(computer.getState('order') or '')..e.tag) end,timer=function() computer.setState('timer',true) end}}"
    assert(runtime.save(c.id,source,c.saved_revision)); assert(runtime.activate(c.id,e.tick)); x.phase='start'; return
  end
  if x.phase=='start' then
    scheduler.tick(e.tick)
    assert(c.status=='running',c.diagnostic and c.diagnostic.message)
    if c.state.boots~=1 then return end
    local db=registry.record(storage.tc_shell_client.db); local logic=registry.record(storage.tc_shell_client.logic)
    kv.methods.set(nil,db,'red',e.tick,nop,'secret','retained-value')
    kv.methods.hset(nil,db,'red',e.tick,nop,'hash','field','retained-hash')
    kv.methods.expire(nil,db,'red',e.tick,nop,'secret',100000)
    local display=assert(monitor.resolve(registry.record(storage.tc_shell_client.monitor_tile)))
    model.calls.write(display.model,nop,'KEEP'); x.phase='display'; return
  end
  if x.phase=='display' then
    scheduler.tick(e.tick)
    local display=assert(monitor.resolve(registry.record(storage.tc_shell_client.monitor_tile)))
    if not display.render or display.render.presented_revision~=display.model.revision then return end
    local db=registry.record(storage.tc_shell_client.db); local logic=registry.record(storage.tc_shell_client.logic)
    assert(logic.output_bank and logic.output_owner and next(c.timers),'legacy fixture must own output and timer')
    assert(display.render.cells[1].value[1]==75,'legacy native front not published')
    assert(runtime.enqueue(c,'later',{name='fixture',tag='a'},e.tick)); assert(runtime.enqueue(c,'later',{name='fixture',tag='b'},e.tick))
    assert(runtime.save(c.id,'function start() error("saved source replayed") end',c.saved_revision))
    x.run=c.run_id; x.generation=c.run_generation; x.state=c.state; x.active=c.active; x.active_source=c.active.source; x.saved=c.saved_source; x.revision=c.saved_revision
    x.timers=c.timers; x.queue=c.queue; x.database=db.database; x.deadline=db.database.entries.secret.deadline
    x.output=logic.output_bank; x.owner=logic.output_owner; x.display=display; x.model=display.model; x.front=display.render
    -- Compiler/schema metadata may be deliberately migrated; accepted data may not.
    x.graph=graph({c.active.handlers,c.state,c.queue,c.timers,db.database,display.model,logic.output_bank})
    x.phase='frozen'; frozen(); game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED genuine-0.1.13'); return
  end
  if x.phase=='verify' then
    retained(); scheduler.tick(e.tick); retained()
    assert(c.status=='running',c.diagnostic and c.diagnostic.message)
    if c.state.order=='ab' then
      x.phase='done'; log('TC_UPGRADE_OK genuine-0.1.13 run-source-state-FIFO-timers-output-KV-display-no-startup-replay')
    end
  end
end
return M
