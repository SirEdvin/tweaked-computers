-- Production scheduler, actual ticks and separate cold server processes.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local radar=require('scripts.radar')
local speaker=require('scripts.speaker')
local kv=require('scripts.services.kv')
local logic=require('scripts.services.logic')
local peripheral=require('scripts.services.peripheral')
local network=require('scripts.network')
local undo=require('scripts.computer-undo')
local blueprints=require('scripts.blueprints')
local monitor=require('scripts.services.monitor')
local art=require('scripts.device-art')
local editor_ui=require('scripts.ui.editor')
local inspector_ui=require('scripts.ui.peripheral-inspector')

local M={}
local resume=false
local function tick(t)
  local radar_available,speaker_available=radar.available,speaker.available
  local visits=0
  radar.available=function(...) visits=visits+1; return radar_available(...) end
  speaker.available=function(...) visits=visits+1; return speaker_available(...) end
  local ok,e=pcall(scheduler.tick,t)
  radar.available=radar_available; speaker.available=speaker_available
  assert(ok,e); assert(visits==0,'idle native carriers acquired proactive power work')
end
local source=[[
function start()
  computer.setState('boots',(computer.getState('boots') or 0)+1)
  computer.setState('order','')
  computer.after(4,'once')
  computer.every(3,'periodic')
  local id=computer.after(5,'canceled')
  computer.setState('cancel',id); assert(computer.cancelTimer(id))
end
function once(e) computer.setState('once',(computer.getState('once') or 0)+1) end
function periodic(e)
  if not computer.getState('first_scheduled') then
    computer.setState('first_scheduled',e.scheduled_tick); computer.setState('first_missed',e.missed)
    computer.setState('first_dispatch',e.tick)
  end
  computer.setState('periods',(computer.getState('periods') or 0)+1)
end
function message(e) computer.setState('order',computer.getState('order')..e.tag) end
function canceled() error('canceled timer replayed') end
]]
local function copy(v)
  if type(v)~='table' then return v end
  local t={}; for k,x in pairs(v) do t[k]=copy(x) end; return t
end
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local function snapshot()
  local root=registry.get(); local x=storage.tc_scheduling
  local c=registry.computer(x.id)
  return {scheduler=copy(root.scheduler),ledger=copy(root.ledger),sequence=root.next_sequence,
    queue=copy(c.queue),timers=copy(c.timers),state=copy(c.state),run=c.run_id,
    last_dispatch_tick=c.last_dispatch_tick}
end
function M.run()
  local legacy={}; local surface=game.surfaces[1]
  local body=assert(surface.create_entity{name=defs.devices.kv.name,position={44,8},force='player'})
  local rec=assert(lifecycle.build(body)); local port=rec.children.network
  kv.methods.set(nil,rec,nil,game.tick,function() end,'migration','retained')
  local database=rec.database
  local foreign=assert(surface.create_entity{name=defs.devices.kv.power_name,position=body.position,force='player'})
  rec.children.power=foreign
  assert(not lifecycle.upgrade(rec) and body.valid and port.valid and foreign.valid,'legacy conversion destroyed an unowned electrical helper')
  assert(rec.database==database and database.entries.migration.value=='retained')
  rec.children.power=nil; rec.layout_version=99
  assert(not lifecycle.upgrade(rec) and body.valid and port.valid,'unknown physical layout was converted')
  rec.layout_version=nil; assert(lifecycle.upgrade(rec) and lifecycle.available(rec) and foreign.valid)
  assert(rec.database==database and database.entries.migration.value=='retained')
  rec.physical_version=99; rec.availability_version=nil; registry.bind_child(rec.id,'power',foreign)
  lifecycle.upgrade_existing()
  assert(foreign.valid and rec.children.power==foreign and rec.availability_version==nil and not lifecycle.available(rec),'unknown physical record was mutated')
  rec.physical_version=1; lifecycle.upgrade_existing()
  assert(not foreign.valid and not rec.children.power and lifecycle.available(rec) and rec.database==database)
  assert(lifecycle.remove(rec.id,'fixture',true))
  for i,kind in ipairs(defs.order) do
    local body=assert(surface.create_entity{name=defs.devices[kind].entity_name,position={i*4,8},force='player'})
    local rec=assert(lifecycle.build(body))
    assert(not rec.children.power,'custom device created an electrical helper: '..kind)
    assert(lifecycle.available(rec),'valid custom device unavailable without electricity: '..kind)
    local roles={}
    for _,role in ipairs(defs.devices[kind].roles) do
      roles[role]=lifecycle.endpoint(rec,role)
      assert(lifecycle.connector(rec,role,'red') and lifecycle.connector(rec,role,'green'))
    end
    body.direction=4; assert(not lifecycle.available(rec),'same-event rotation trusted stale availability')
    body.direction=0; assert(lifecycle.available(rec))
    rec.availability_version=99; assert(not lifecycle.available(rec),'unknown availability metadata authorized a device')
    rec.availability_version=1; assert(lifecycle.available(rec))
    local power=assert(surface.create_entity{name=defs.devices[kind].power_name,position=body.position,force='player'})
    local unrelated=assert(surface.create_entity{name=power.name,position=body.position,force='player'})
    registry.bind_child(rec.id,'power',power); rec.availability_version=nil; rec.powered=false
    local owned_clone=assert(power.clone{position={body.position.x+8,body.position.y},surface=surface,force='player'})
    lifecycle.on_cloned{source=power,destination=owned_clone}
    assert(not owned_clone.valid,'owned obsolete electrical clone survived')
    legacy[#legacy+1]={rec=rec,body=body,roles=roles,power=power,unrelated=unrelated,
      database=rec.database,settings=rec.monitor_settings,dashboard=rec.dashboard}
  end
  lifecycle.upgrade_existing()
  for _,saved in ipairs(legacy) do
    local rec=saved.rec
    assert(not saved.power.valid and saved.unrelated.valid,'migration did not remove only the owned helper')
    assert(not rec.children.power and rec.body==saved.body and lifecycle.available(rec))
    assert(rec.database==saved.database and rec.monitor_settings==saved.settings and rec.dashboard==saved.dashboard)
    for role,entity in pairs(saved.roles) do assert(lifecycle.endpoint(rec,role)==entity) end
    local unrelated_clone=assert(saved.unrelated.clone{position={saved.body.position.x+10,saved.body.position.y},surface=surface,force='player'})
    lifecycle.on_cloned{source=saved.unrelated,destination=unrelated_clone}
    assert(unrelated_clone.valid,'unrelated electrical clone was deleted'); unrelated_clone.destroy()
    saved.unrelated.destroy()
  end
  assert(#surface.find_entities_filtered{type='item-entity'}==0,'helper migration created item drops')
  local root=registry.get(); local computers=root.computers; local signal_visits=0
  root.computers=setmetatable({},{__index=function(_,id) signal_visits=signal_visits+1; return computers[id] end})
  local sampled,failure=pcall(logic.sample,game.tick,function() end)
  root.computers=computers
  assert(sampled,failure); assert(signal_visits==0,'power-free idle populations acquired signal discovery')
  assert(#root.logic_observers.order==0 and #root.logic_observers.input_order==0)
  local record=registry.record; local output_visits=0
  registry.record=function(...) output_visits=output_visits+1; return record(...) end
  local checked,problem=pcall(peripheral.check_outputs,game.tick,function() end)
  registry.record=record
  assert(checked,problem); assert(output_visits==0,'idle devices acquired output-owner discovery: '..output_visits)
  local topology_work=0
  peripheral.reconcile(game.tick,function(n) topology_work=topology_work+n end)
  assert(topology_work==0,'uninterested computers acquired topology discovery work: '..topology_work)
  local adoption_work=0
  network.adopt_tick(game.tick,function(n) adoption_work=adoption_work+n end)
  assert(adoption_work==0,'idle roots acquired native adoption discovery work: '..adoption_work)
  local physical_visits=0
  registry.record=function(...) physical_visits=physical_visits+1; return record(...) end
  local observed,observation_error=pcall(lifecycle.reconcile,game.tick,function() end)
  registry.record=record
  assert(observed,observation_error)
  assert(physical_visits==0,'undue physical observation discovered idle identities: '..physical_visits)
  local undo_state=root.computer_undo; local original=undo_state or {pending={},ghosts={},destroyed={}}
  local undo_visits=0
  root.computer_undo=setmetatable({},{__index=function(_,key) undo_visits=undo_visits+1; return original[key] end,
    __newindex=function() undo_visits=undo_visits+1 end})
  local settled,settlement_error=pcall(undo.maintain,game.tick)
  root.computer_undo=undo_state
  assert(settled,settlement_error); assert(undo_visits==0,'settled undo state retained tick work: '..undo_visits)
  local clone_work=0; blueprints.reconcile_clones(game.tick,function(n) clone_work=clone_work+n end)
  assert(clone_work==0,'settled clones retained tick work')
  for _=1,20 do monitor.reconcile(game.tick,function() end); if not root.monitors.job then break end end
  assert(not root.monitors.job and not next(root.monitors.resizes) and #root.monitors.touches==0)
  local notification_work,notification_visits=0,0
  local display_order=root.monitors.order
  root.monitors.order=setmetatable({},{__len=function() return #display_order end,
    __index=function(_,i) notification_visits=notification_visits+1; return display_order[i] end})
  local notified,notification_error=pcall(monitor.notifications,game.tick,function(n) notification_work=notification_work+n end)
  root.monitors.order=display_order
  assert(notified,notification_error)
  assert(notification_work==0,'settled displays acquired notification discovery work: '..notification_work)
  assert(notification_visits==0,'settled displays were visited to discover notifications: '..notification_visits)
  local native_game=game; local player_walks,closed_ui_work=0,0
  _G.game=setmetatable({},{__index=function(_,key)
    if key=='connected_players' then player_walks=player_walks+1 end
    return native_game[key]
  end})
  local quiet,ui_error=pcall(function()
    editor_ui.tick(native_game.tick,function(n) closed_ui_work=closed_ui_work+n end)
    inspector_ui.tick(native_game.tick)
  end)
  _G.game=native_game
  assert(quiet,ui_error)
  assert(player_walks==0 and closed_ui_work==0,
    'closed UI acquired connected-player discovery: walks='..player_walks..' work='..closed_ui_work)
  local kv_work,art_work=0,0
  kv.maintenance(game.tick,function(n) kv_work=kv_work+n end)
  art.tick(game.tick,function() end)
  art.tick(game.tick,function(n) art_work=art_work+n end)
  assert(kv_work==0,'persistent-only databases acquired reclamation discovery work: '..kv_work)
  assert(art_work==0,'settled devices acquired art discovery work: '..art_work)
  local nop=function() end
  for _,saved in ipairs(legacy) do if saved.rec.kind=='kv' then rec=saved.rec end end
  assert(registry.record(rec.id)==rec and rec.kind=='kv')
  kv.methods.set(nil,rec,nil,game.tick,nop,'future','old')
  kv.methods.expire(nil,rec,nil,game.tick,nop,'future',1000)
  local deadline=rec.database.entries.future.deadline
  assert(registry.maintenance_next('kv').tick==deadline)
  kv_work=0; kv.maintenance(game.tick,function(n) kv_work=kv_work+n end)
  assert(kv_work==0,'future-only database acquired per-tick work')
  assert(kv.methods.persist(nil,rec,nil,game.tick,nop,'future')==1 and not registry.maintenance_next('kv'))
  local trace={}
  kv.methods.expire(nil,rec,nil,game.tick,function(n) trace[#trace+1]=n end,'future',1000)
  kv.methods.persist(nil,rec,nil,game.tick,nop,'future')
  local before=rec.database; local refused={}; local charges=0
  local published,why=pcall(kv.methods.expire,nil,rec,nil,game.tick,function()
    charges=charges+1; if charges==#trace then error(refused,0) end
  end,'future',1000)
  assert(not published and why==refused and rec.database==before and not registry.maintenance_next('kv'),
    'refused deadline publication changed database/index')
  kv.methods.expire(nil,rec,nil,game.tick,nop,'future',1000)
  kv.methods.set(nil,rec,nil,game.tick,nop,'future','replacement')
  assert(not registry.maintenance_next('kv') and kv.methods.ttl(nil,rec,nil,game.tick,nop,'future')==-1)
  kv.methods.set(nil,rec,nil,game.tick,nop,'cold-expiry',string.rep('x',8192))
  kv.methods.expire(nil,rec,nil,game.tick,nop,'cold-expiry',1)
  local small=assert(lifecycle.build(assert(surface.create_entity{name=defs.devices.kv.entity_name,position={96,12},force='player'})))
  kv.methods.set(nil,small,nil,game.tick,nop,'small','v')
  kv.methods.expire(nil,small,nil,game.tick,nop,'small',1)
  local recovery=assert(lifecycle.build(assert(surface.create_entity{name=defs.devices.kv.entity_name,position={104,12},force='player'})))
  kv.methods.set(nil,recovery,nil,game.tick,nop,'kept','accepted')
  kv.methods.expire(nil,recovery,nil,game.tick,nop,'kept',1000)
  local retained=kv.snapshot(recovery,game.tick,nop)
  local clock=registry.maintenance_clock('kv'); local clocks=registry.get().scheduler.due_work
  local diagnostic=registry.get().scheduling_diagnostic; clocks.version=99
  kv.restore(recovery,retained)
  local imported=recovery.database
  assert(imported.entries.kept.value=='accepted' and imported.entries.kept.deadline==game.tick+60000)
  local changed,issue=pcall(kv.methods.set,nil,recovery,nil,game.tick,nop,'kept','replacement')
  assert(not changed and issue.code=='E_UNSUPPORTED' and recovery.database==imported)
  assert(not registry.remove(recovery.id,'unsupported deadline fixture') and recovery.body.valid and clocks.version==99)
  clocks.version=1; kv.initialize(recovery)
  registry.get().scheduling_diagnostic=diagnostic
  assert(lifecycle.remove(recovery.id,'supported deadline fixture',true))
  assert(not clock.deadline_positions[recovery.id],'removed database retained deadline ownership')
  log('TC_CONTRACT deadline-owned-kv-and-status-art-zero-idle-future-cancel-replace-atomic-publication')

  log('TC_SCHEDULING_NINE_POWER_FREE_FAMILIES owned-helper-migration physical-proofs role-and-content-aliases')
  for i,name in ipairs({'radar','programmable-speaker'}) do
    assert(lifecycle.build(assert(game.surfaces[1].create_entity{name=name,position={i*8,16},force='player'})))
  end
  local function build(x)
    local body=assert(game.surfaces[1].create_entity{name=defs.devices.computer.entity_name,position={x,0},force='player'})
    local c=assert(lifecycle.build(body))
    runtime.save(c.id,source,0); assert(runtime.activate(c.id,game.tick))
    return c
  end
  local c=build(0); local stopped=build(4); local faulted=build(8)
  runtime.stop(stopped.id)
  runtime.fault(faulted,{code='E_PROGRAM',message='intentional stopped fixture'},game.tick)
  storage.tc_scheduling={phase='armed',id=c.id,stopped=stopped.id,faulted=faulted.id,
    database=rec.id,small_database=small.id,kv_deadline=rec.database.entries['cold-expiry'].deadline,kv_data=rec.database}
end
function M.on_load()
  resume=storage.tc_scheduling.phase=='frozen'
  if resume then
    assert(equal(snapshot(),storage.tc_scheduling.expected),'cold load changed scheduling, queue or credits')
    log('TC_SCHEDULING_LOAD_UNCHANGED')
  end
end
function M.on_configuration_changed() error('ordinary cold fixture is not old-archive upgrade acceptance') end
function M.on_tick(event)
  local x=storage.tc_scheduling; local c=registry.computer(x.id); local root=registry.get()
  if x.phase=='frozen' then
    if not resume then return end
    assert(equal(snapshot(),x.expected))
    tick(x.tick)
    assert(equal(snapshot(),x.expected),'same-tick cold dispatch renewed credits or replayed work')
    assert(c.queue==x.queue and c.timers==x.timers and root.scheduler==x.scheduler)
    local ctx=admission.context(root.ledger,c.id,x.tick)
    assert(ctx.machine.work==x.work and ctx.ledger.total==x.total)
    resume=false; x.phase='resumed'; x.resume_tick=event.tick
    log('TC_SCHEDULING_COLD_RETAINED ready deadlines FIFO aliases spent-credits stopped faulted')
  end
  if x.phase=='armed' then
    tick(event.tick)
    assert(c.state.boots==1 and c.status=='running',c.diagnostic and c.diagnostic.message)
    assert(c.timers[c.state.cancel]==nil)
    assert(runtime.enqueue(c,'message',{name='fixture',tag='a'},event.tick))
    assert(runtime.enqueue(c,'message',{name='fixture',tag='b'},event.tick))
    assert(root.scheduler.ready[c.id] and #root.scheduler.deadlines==1)
    assert(not root.scheduler.ready[x.stopped] and not root.scheduler.ready[x.faulted])
    local retained=snapshot()
    for _,entry in ipairs({{'output_owners',peripheral.check_outputs},{'topology_interests',peripheral.reconcile},{'native_adoption',network.adopt_tick},{'logic_observers',logic.sample}}) do
      local key,service=entry[1],entry[2]; local prior=root[key]
      local unknown={version=99,retained=prior}; root[key]=unknown
      local work=0; service(event.tick,function(n) work=work+n end)
      assert(root.scheduling_diagnostic and root.scheduling_diagnostic.code=='E_UNSUPPORTED')
      assert(work==0 and root[key]==unknown and unknown.retained==prior,'unknown work membership was consumed')
      root[key]=prior; root.scheduling_diagnostic=nil
      assert(equal(snapshot(),retained),'unknown membership changed accepted queues, timers or credits')
    end
    log('TC_CONTRACT unknown-service-memberships-inert-queues-timers-and-credits-retained')
    root.scheduler.due_work.version=99
    local work=0; lifecycle.reconcile(event.tick,function(n) work=work+n end)
    assert(work==0 and root.scheduler.due_work.version==99 and root.scheduling_diagnostic.code=='E_UNSUPPORTED')
    assert(not registry.remove(c.id,'unsupported-deadline-removal') and registry.record(c.id)==c and c.status=='running')
    root.scheduler.due_work.version=1; root.scheduling_diagnostic=nil
    assert(equal(snapshot(),retained),'unknown service deadlines changed accepted data or credits')
    x.queue=c.queue; x.timers=c.timers; x.scheduler=root.scheduler
    x.tick=event.tick; x.work=root.ledger.machines[c.id].work; x.total=root.ledger.total
    x.expected=snapshot(); x.phase='waiting-save'
    return
  end
  if x.phase=='waiting-save' then
    -- Deliberately freeze scheduler service so saved deadlines are overdue.
    if event.tick>=x.tick+8 then
      assert(equal(snapshot(),x.expected))
      x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
    end
    return
  end
  if x.phase=='resumed' then
    tick(event.tick)
    assert(c.status=='running',c.diagnostic and c.diagnostic.message)
    assert(c.state.boots==1 and registry.computer(x.stopped).status=='stopped' and registry.computer(x.faulted).status=='faulted')
    if event.tick>=x.tick+18 then
      assert(c.state.order=='ab' and c.state.once==1 and c.state.periods>=3)
      assert(c.state.first_scheduled==x.tick+3 and c.state.first_missed==math.floor((c.state.first_dispatch-x.tick-3)/3))
      assert(next(c.subscriptions)==nil and c.timers[c.state.cancel]==nil)
      assert(#root.scheduler.deadlines==1 and root.scheduler.deadline_positions[c.id]==1)
      log('TC_SCHEDULING_DONE exact-once ordered callbacks canceled-deadline no-startup-replay')
      local surface=game.surfaces[1]
      local lost=assert(lifecycle.build(assert(surface.create_entity{name=defs.devices.kv.entity_name,position={84,12},force='player'})))
      local damaged=assert(lifecycle.build(assert(surface.create_entity{name=defs.devices.logic.entity_name,position={80,12},force='player'})))
      x.damaged=damaged.id; x.damaged_body=damaged.body; x.retained_output=damaged.children.output
      x.lost=lost.id; x.destruction_tick=event.tick
      local input=damaged.children.input; local unit=input.unit_number
      local registration=root.entities[unit].destruction_registration
      local other_binding=root.entities[damaged.body.unit_number]
      lifecycle.on_object_destroyed{type=defines.target_type.entity,useful_id=damaged.body.unit_number,registration_number=registration,tick=event.tick}
      assert(root.entities[damaged.body.unit_number]==other_binding and lifecycle.available(damaged),'foreign destruction token mutated an owned body')
      input.destroy(); lost.body.destroy()
      assert(not lifecycle.available(damaged) and not lifecycle.connector(damaged,'input','red'))
      local notified=assert(lifecycle.build(assert(surface.create_entity{name=defs.devices.logic.entity_name,position={88,12},force='player'})))
      local vanished=assert(lifecycle.build(assert(surface.create_entity{name=defs.devices.kv.entity_name,position={92,12},force='player'})))
      registry.maintenance_set('physical',notified.id,notified,event.tick+limits.topology_latency_ticks)
      registry.maintenance_set('physical',vanished.id,vanished,event.tick+limits.topology_latency_ticks)
      x.notified=notified.id; x.vanished=vanished.id; x.notified_output=notified.children.output
      notified.children.input.destroy(); vanished.body.destroy()
      lifecycle.request_observation(lost,event.tick); lifecycle.request_observation(damaged,event.tick)
      local head=registry.maintenance_next('physical'); assert(head.owner==lost)
      local s=root.scheduler
      s.maintenance_tick=event.tick; s.maintenance_spent=limits.maintenance_work_per_tick-s.render_reserved_work-root.ledger.total-1000
      assert(s.maintenance_spent>=0)
      lifecycle.reconcile(event.tick,scheduler.maintenance(root,event.tick))
      assert(registry.record(lost.id)==lost and damaged.physical_error,'refused physical head blocked a fitting peer')
      assert(registry.maintenance_next('physical').owner==lost and registry.maintenance_next('physical').tick==event.tick,'refused observation lost its original due tick')
      log('TC_CONTRACT refused-physical-observation-retains-deadline-and-fitting-peer-progress')
      x.phase='physical-destruction'
    end
  elseif x.phase=='physical-destruction' then
    tick(event.tick)
    local damaged=registry.record(x.damaged); local notified=registry.record(x.notified)
    assert(event.tick-x.destruction_tick<=3,'native destruction event did not target physical maintenance')
    if registry.record(x.lost) or registry.record(x.vanished) or not damaged.physical_error or not notified.physical_error then return end
    assert(damaged.body==x.damaged_body and damaged.body.valid and damaged.children.output==x.retained_output and x.retained_output.valid)
    assert(notified.body.valid and notified.children.output==x.notified_output and x.notified_output.valid)
    local physical=registry.maintenance_clock('physical')
    assert(not physical.deadline_positions[x.lost] and not physical.deadline_positions[x.damaged],'settled physical failure retained periodic work')
    assert(not physical.deadline_positions[x.notified] and not physical.deadline_positions[x.vanished],'native destruction left stale observer entries')
    local record=registry.record; local visits=0
    registry.record=function(...) visits=visits+1; return record(...) end
    local observed,problem=pcall(lifecycle.reconcile,event.tick,function() end); registry.record=record
    assert(observed,problem); assert(visits==0,'settled same-tick physical work was rediscovered')
    assert(c.status=='running' and c.state.boots==1 and c.state.once==1)
    log('TC_CONTRACT native-destruction-targeted-owned-helper-recovery-no-foreign-cleanup-no-stale-deadlines')
    x.phase='maintenance-deadlines'
  elseif x.phase=='maintenance-deadlines' then
    local database=registry.record(x.database); local key=database.database.entries['cold-expiry']
    if event.tick==x.kv_deadline then
      assert(key and kv.methods.get(nil,database,nil,event.tick,function() end,'cold-expiry')==nil,
        'expiry semantics waited for physical reclamation')
      local spend=scheduler.maintenance(root,event.tick)
      root.scheduler.maintenance_spent=limits.maintenance_work_per_tick-root.scheduler.render_reserved_work-1000
      kv.maintenance(event.tick,spend)
      assert(database.database.entries['cold-expiry']==key and not registry.record(x.small_database).database.entries.small,
        'refused expiry blocked a fitting database or deleted accepted state')
      assert(registry.maintenance_next('kv').owner==database and registry.maintenance_next('kv').tick==x.kv_deadline,
        'refused expiry lost its original deadline')
      log('TC_SCHEDULING_KV_REFUSAL_OK exact-expiry-fitting-peer-old-due-tick-retained')
    end
    tick(event.tick)
    assert(database.database==x.kv_data and database.database.entries.future.value=='replacement')
    local position=registry.maintenance_clock('art').deadline_positions[c.id]
    assert(position and registry.maintenance_clock('art').deadlines[position].tick==event.tick-event.tick%10+10)
    assert(c.status_art.name=='tc-status-computer-north-blinking-'..math.floor(event.tick/10)%4,
      'running status frame missed its actual-tick animation boundary')
    assert(not registry.maintenance_clock('art').deadline_positions[x.stopped]
      and not registry.maintenance_clock('art').deadline_positions[x.faulted],
      'stopped or faulted computer retained animation work')
    if event.tick>x.kv_deadline and not database.database.entries['cold-expiry'] then
      assert(not registry.maintenance_clock('kv').deadline_positions[database.id])
      log('TC_SCHEDULING_KV_ART_COLD_OK deadlines-aliases-expiry-running-animation-cadence')
      x.phase='done'; log('TC_COLD_OK')
    end
  end
end
return M
