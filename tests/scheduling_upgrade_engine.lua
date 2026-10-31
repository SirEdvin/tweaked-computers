-- Shared old-runtime/candidate fixture; injected only into the existing upgrade test hook.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local shell=require('scripts.runtime.shell')
local sandbox=require('scripts.runtime.sandbox')
local limits=require('scripts.runtime.limits')
local defs=require('scripts.device-definitions')
local logic=require('scripts.services.logic')
local kv=require('scripts.services.kv')
local dashboard=require('scripts.dashboard-model')
local monitor=require('scripts.services.monitor')
local model=require('scripts.monitor-model')
local renderer=require('scripts.rendering')
local radar=require('scripts.radar')
local speaker=require('scripts.speaker')
local editor=require('scripts.ui.editor')
local editor_model=require('scripts.ui.editor-model')
local players=require('tests.editor_contract')
local M={}; local loaded=false
local player
local function x() return storage.tc_scheduling_upgrade end
local function copy(v,seen)
  if type(v)~='table' or v.object_name then return v end
  seen=seen or {}; if seen[v] then return seen[v] end
  local r={}; seen[v]=r; for k,a in pairs(v) do r[k]=copy(a,seen) end; return r
end
local function equal(a,b,forward,reverse)
  if type(a)~=type(b) then return false end
  if type(a)~='table' or a.object_name then return a==b end
  forward=forward or {}; reverse=reverse or {}
  if forward[a] or reverse[b] then return forward[a]==b and reverse[b]==a end
  forward[a]=b; reverse[b]=a
  for k,v in pairs(a) do if not equal(v,b[k],forward,reverse) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local source=[[function start(e)
  computer.setState('boots',(computer.getState('boots') or 0)+1)
  computer.setState('order','')
  computer.every(5,'periodic')
  local canceled=computer.after(7,'forbidden'); assert(computer.cancelTimer(canceled))
  computer.on('power_restored','restored')
end
function periodic(e)
  computer.setState('periods',(computer.getState('periods') or 0)+1)
  computer.setState('last_scheduled',e.scheduled_tick); computer.setState('last_missed',e.missed)
end
function message(e) computer.setState('order',computer.getState('order')..e.tag) end
function restored(e) computer.setState('restores',(computer.getState('restores') or 0)+1) end
function forbidden(e) error('canceled timer replayed') end]]
local writer_source=[[function start(e)
  computer.setState('boots',(computer.getState('boots') or 0)+1)
  local io=peripheral.find('logic_handler','red')
  assert(#io.readSignals('red')==1100)
  io.setOutput({{signal={type='virtual',name='signal-A',quality='normal'},count=19}})
  computer.setState('sub',io.subscribe({input='red',initial=true},'changed'))
  computer.setState('canceled_sub',io.subscribe({input='red',initial=false},'forbidden'))
end
function changed(e)
  assert(#e.current==1100)
  computer.setState('changes',(computer.getState('changes') or 0)+1)
end
function message(e) computer.setState('order',(computer.getState('order') or '')..e.tag) end
function forbidden(e) error('canceled signal replayed') end]]
local function build(kind,xx,y)
  local b=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={xx,y},force='player'})
  return assert(lifecycle.build(b))
end
local function wire(a,b,role)
  assert(lifecycle.connector(a,'network','red').connect_to(lifecycle.connector(b,role or 'network','red')))
end
local function activate(c,s) assert(runtime.save(c.id,s,0)); assert(runtime.activate(c.id,game.tick)) end
local function saved_record(c)
  return copy{source=c.active and c.active.source,run=c.run_id,generation=c.run_generation,status=c.status,
    state=c.state,queue=c.queue,queue_bytes=c.queue_bytes,timers=c.timers,subscriptions=c.subscriptions,
    shell=c.shell,last_dispatch_tick=c.last_dispatch_tick}
end
local function preserve()
  local f=x(); local root=registry.get(); local r={records={},ledger=copy(root.ledger),sequence=root.next_sequence,
    spent=root.scheduler.maintenance_spent,reserved=root.scheduler.render_reserved_work,last_tick=root.scheduler.last_tick}
  for _,id in ipairs(f.computers) do r.records[id]=saved_record(registry.record(id)) end
  return r
end
local function unchanged()
  local f=x(); local now=preserve()
  assert(equal(now,f.saved),'load/configuration changed accepted source, queues, timers, subscriptions, shell or credits')
  for _,r in ipairs(f.physical) do
    local rec=assert(registry.record(r.id)); assert(rec.body==r.body and rec.generation==r.generation)
    for role,b in pairs(r.roles) do assert(lifecycle.endpoint(rec,role)==b) end
  end
  assert(registry.record(f.kv).database==f.database and f.database.entries.keep.value=='retained')
  assert(registry.record(f.dashboard).dashboard==f.dashboard_model)
  local monitors=registry.get().monitors
  local g=assert(monitors.groups[monitors.membership[f.monitor]]) -- Read retained aliases before candidate notification migration.
  assert(g.model==f.model and g.render==f.front and g.model.cells==f.cells)
  assert(f.job==registry.get().monitors.presentation.lanes[g.id].job and f.job.cell==f.cell)
end
-- Real Console authority with an explicitly table-backed authoring player.
local function with_player(fn)
  local real=game
  game=setmetatable({get_player=function(i) if player and i==player.index then return player end; return real.get_player(i) end},{__index=real})
  local ok,result=pcall(fn); game=real; assert(ok,result); return result
end
local function open_console(rec,token)
  player=players.player(9001,rec.body); assert(editor.open(player,rec.id))
  local gui=player.gui.screen[editor.frame_name]
  if token then editor_model.session(player.index).token=token; gui.tags.token=token end
  with_player(function() gui.content.selected_tab_index=2; editor.on_tab{player_index=player.index,element=gui.content,tick=game.tick} end)
  return editor_model.session(player.index).token
end
function M.run()
  assert(runtime.set_power,'legacy runtime required to create the rollback save')
  storage.tc_scheduling_upgrade={phase='settling',since=game.tick,ids={},physical={},computers={},from_version=script.active_mods['tweaked-computers']}
  local f=x(); local s=game.surfaces[1]
  for i,kind in ipairs(defs.order) do local r=build(kind,(i-1)*4,0); f.ids[kind]=r.id end
  f.kv=f.ids.kv; f.dashboard=f.ids.dashboard
  kv.methods.set(nil,registry.record(f.kv),nil,game.tick,function() end,'keep','retained')
  f.database=registry.record(f.kv).database
  dashboard.set_tab(registry.record(f.dashboard),1,{title='Retained',content={type='label',id='status',text='kept'}},function() end)
  f.dashboard_model=registry.record(f.dashboard).dashboard
  for i=0,2 do
    assert(s.create_entity{name='substation',position={i*16,5},force='player'})
    local p=assert(s.create_entity{name='electric-energy-interface',position={i*16+4,5},force='player'})
    p.power_production=100000000; p.power_usage=0
  end
  f.paused=f.ids.computer; f.writer=build('computer',4,-4).id
  f.console=build('computer',-8,0).id; f.stopped=build('computer',-12,0).id
  f.faulted=build('computer',-16,0).id; f.unknown=build('computer',-20,0).id
  -- Supply the additional computers through an actual native network.
  for i=1,2 do
    assert(s.create_entity{name='substation',position={-i*12,5},force='player'})
    local p=assert(s.create_entity{name='electric-energy-interface',position={-i*12+4,5},force='player'})
    p.power_production=100000000; p.power_usage=0
  end
  wire(registry.record(f.writer),registry.record(f.ids.logic))
  local constant=assert(s.create_entity{name='constant-combinator',position={10,-4},force='player'})
  local cb=constant.get_or_create_control_behavior(); for i=cb.sections_count,1,-1 do cb.remove_section(i) end
  f.section=cb.add_section(); local filters={}
  for i=1,1100 do filters[i]={index=i,value={type='virtual',name=string.format('tc-native-%04d',i),quality='normal'},min=i} end
  f.section.filters=filters; cb.enabled=true
  assert(constant.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(lifecycle.connector(registry.record(f.ids.logic),'input','red')))
  f.monitor=f.ids.monitor
  for y=1,3 do for xx=0,3 do build('monitor',8+xx,y) end end
  for xx=1,3 do build('monitor',8+xx,0) end
  for _,id in ipairs({f.paused,f.console,f.unknown}) do activate(registry.record(id),source) end
  activate(registry.record(f.writer),writer_source)
  for _,id in ipairs({f.stopped,f.faulted}) do activate(registry.record(id),source) end
  f.computers={f.paused,f.writer,f.console,f.stopped,f.faulted,f.unknown}
end
function M.on_load()
  local f=x(); loaded=true
  if f.phase=='frozen' then
    assert(equal(registry.get(),f.load_root),'on_load mutated authoritative root')
    unchanged(); log('TC_SCHEDULING_UPGRADE_LOAD_UNCHANGED')
  end
end
function M.on_configuration_changed(event)
  local f=x(); assert(f.phase=='frozen' and not runtime.set_power)
  local change=assert(event.mod_changes['tweaked-computers'])
  assert(change.old_version=='0.1.17' and change.old_version==f.from_version and change.new_version~=change.old_version)
  assert(script.active_mods['tweaked-computers']==change.new_version)
  log('TC_SCHEDULING_UPGRADE_VERSIONS old='..change.old_version..' new='..change.new_version)
  -- Migration adds membership and changes only the old electrical compatibility metadata.
  local ledger=registry.get().ledger; local retained=copy(ledger); retained.maintenance=nil
  local expected=copy(f.saved.ledger); expected.maintenance=nil
  assert(equal(retained,expected) and registry.get().next_sequence==f.saved.sequence)
  for _,id in ipairs(f.computers) do assert(equal(saved_record(registry.record(id)),f.saved.records[id])) end
  for _,r in ipairs(f.physical) do
    local rec=assert(registry.record(r.id)); assert(rec.body==r.body and not r.power.valid and not rec.children.power and lifecycle.available(rec))
    for role,b in pairs(r.roles) do assert(lifecycle.endpoint(rec,role)==b) end
  end
  assert(#game.surfaces[1].find_entities_filtered{type='item-entity'}==0)
  assert(registry.get().scheduler.work_version==1 and registry.get().logic_observers.version==1)
  open_console(registry.record(f.console),registry.record(f.console).shell.pending[1].token)
  f.phase='upgrading'; f.upgrade_tick=game.tick; loaded=false
  log('TC_SCHEDULING_UPGRADE_CONFIG_PRESERVED')
end
function M.on_tick(event)
  local f=x(); local root=registry.get()
  if f.phase=='frozen' then return end
  if f.phase=='done' then
    if loaded then
      scheduler.tick(event.tick)
      assert(not runtime.set_power and registry.record(f.paused).state.boots==1)
      assert(registry.record(f.writer).state.order=='ab' and registry.record(f.console).state.shell_once==1)
      assert(root.scheduler.ready==f.ready and root.scheduler.due_work==f.due_work and root.logic_observers==f.observers)
      loaded=false; log('TC_UPGRADE_ORDINARY_OK')
    end
    return
  end
  if f.phase=='settling' then
    loaded=false; scheduler.tick(event.tick)
    assert(event.tick-f.since<300,'legacy setup deadline')
    local c=registry.record(f.paused); local w=registry.record(f.writer)
    assert(c.status=='running' and w.status=='running',serpent.line(w.diagnostic or c.diagnostic))
    local g=monitor.resolve(registry.record(f.monitor))
    if event.tick-f.since<30 or c.state.boots~=1 or w.state.boots~=1 or not g or not g.render then return end
    runtime.stop(f.stopped); runtime.fault(registry.record(f.faulted),{code='E_PROGRAM',message='intentional fixture fault'},event.tick)
    registry.record(f.unknown).active.compiler_version=99
    for id,timer in pairs(c.timers) do assert(timer.interval==5); f.timer=id; f.deadline=timer.deadline end
    assert(f.timer and runtime.set_power(c.id,false,event.tick)); assert(c.status=='running' and not c.powered)
    f.periods=c.state.periods; f.pause_tick=event.tick
    model.calls.write(g.model,function() end,'OLD'); renderer.participate(g)
    f.phase='paused'; return
  end
  if f.phase=='paused' then
    -- Native ticks advance while the legacy generation really remains electrically paused.
    assert(registry.record(f.paused).state.periods==f.periods and not registry.record(f.paused).powered)
    if event.tick-f.pause_tick<30 then return end
    local spend=scheduler.maintenance(root,event.tick,true)
    renderer.tick(event.tick,spend)
    local g=assert(monitor.resolve(registry.record(f.monitor))); assert(g.render and g.render.snapshot.cells[1][1]==79)
    f.front=g.render; model.calls.setBackgroundColor(g.model,spend,4); model.calls.clear(g.model,spend)
    model.calls.setCursorPos(g.model,spend,1,1); model.calls.write(g.model,spend,'NEXT'); renderer.participate(g)
    scheduler.try_maintenance(function() renderer.tick(event.tick,function(n)
      local lane=root.monitors.presentation.lanes[g.id]
      if lane and lane.job and lane.job.cell>1 then spend(limits.maintenance_work_per_tick) end
      spend(n)
    end) end)
    local job=assert(root.monitors.presentation.lanes[g.id].job); assert(not job.complete and job.cell>1,'expected a paid partial frame')
    f.job=job; f.cell=job.cell; f.model=g.model; f.cells=g.model.cells
    -- Fresh native initial observation is frozen before dispatch.
    local w=registry.record(f.writer); local sub=w.subscriptions[w.state.sub]; assert(sub and #sub.details.previous==1100)
    sub.details.initial=true; w.subscriptions[w.state.canceled_sub].details.initial=true
    logic.sample(event.tick,spend)
    assert(#w.queue==2 and #w.queue[1].event.current==1100)
    local services=runtime.services(w,event.tick,sandbox.new(runtime.context(w,event.tick),{}))
    assert(services.peripheral.call(f.ids.logic,'red','unsubscribe',w.state.canceled_sub))
    assert(#w.queue==1 and not w.subscriptions[w.state.canceled_sub])
    assert(runtime.enqueue(w,'message',{name='fixture',tag='a'},event.tick)); assert(runtime.enqueue(w,'message',{name='fixture',tag='b'},event.tick))
    local console=registry.record(f.console)
    local token=open_console(console)
    assert(with_player(function() return shell.submit(console,"computer.setState('shell_once',(computer.getState('shell_once') or 0)+1)",9001,token,event.tick,false) end))
    for _,id in ipairs(root.order) do local r=registry.record(id); if not r.native_carrier then
      local roles={}; for _,role in ipairs(defs.devices[r.kind].roles) do roles[role]=lifecycle.endpoint(r,role) end
      f.physical[#f.physical+1]={id=id,body=r.body,generation=r.generation,power=assert(r.children.power),roles=roles}
    end end
    f.saved=preserve(); f.load_root=copy(root); f.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  assert(f.phase=='upgrading')
  if not f.first_tick then
    local advance,dispatch=scheduler.advance_timers,scheduler.dispatch

    local ra,sa=radar.available,speaker.available; local idle_timer,idle_dispatch,native_power=0,0,0
    local function idle(r) return r.id==f.stopped or r.id==f.faulted end
    scheduler.advance_timers=function(r,...) if idle(r) then idle_timer=idle_timer+1 end; return advance(r,...) end
    scheduler.dispatch=function(r,...) if idle(r) then idle_dispatch=idle_dispatch+1 end; return dispatch(r,...) end
    radar.available=function(...) native_power=native_power+1; return ra(...) end
    speaker.available=function(...) native_power=native_power+1; return sa(...) end
    local ok,problem=pcall(with_player,function() scheduler.tick(event.tick) end)
    scheduler.advance_timers=advance; scheduler.dispatch=dispatch; radar.available=ra; speaker.available=sa
    assert(ok,problem); assert(idle_timer==0 and idle_dispatch==0 and native_power==0)
    f.first_tick=true; log('TC_SCHEDULING_UPGRADE_FIRST_TICK idle_timer=0 idle_dispatch=0 native_power=0')
  else with_player(function() scheduler.tick(event.tick) end) end
  local c=registry.record(f.paused); local w=registry.record(f.writer); local console=registry.record(f.console)
  assert(not w.subscriptions[w.state.canceled_sub],'canceled legacy observer was reconstructed')
  assert(c.state.boots==1 and c.run_id==f.saved.records[c.id].run and c.status=='running')
  assert(not c.state.restores and c.state.periods>=f.periods)
  if not f.overdue_verified and c.state.periods>f.periods then
    local deadline=assert(c.timers[f.timer]).deadline
    assert(c.state.periods==f.periods+1 and c.state.last_scheduled==f.deadline)
    assert(c.state.last_missed==(deadline-f.deadline)/5-1 and c.state.last_missed>0)
    f.overdue_verified=true; log('TC_SCHEDULING_UPGRADE_OVERDUE_ALIGNED_ONCE')
  end
  assert(registry.record(f.stopped).status=='stopped' and registry.record(f.faulted).status=='faulted')
  local unknown=registry.record(f.unknown); assert(unknown.status=='faulted' and unknown.active.source==f.saved.records[unknown.id].source and unknown.state.boots==1)
  assert(event.tick-f.upgrade_tick<240,'migration completion deadline')
  local g=assert(monitor.resolve(registry.record(f.monitor)))
  if w.state.order~='ab' or console.state.shell_once~=1 or not g.render or g.render==f.front or c.state.periods==f.periods then return end
  assert(f.overdue_verified and w.state.boots==1 and w.state.changes==f.saved.records[w.id].state.changes+1)
  assert(g.model==f.model and g.model.cells==f.cells and g.render.snapshot.cells[1][1]==78 and f.job.complete)
  assert(registry.record(f.kv).database==f.database and f.database.entries.keep.value=='retained')
  assert(registry.record(f.dashboard).dashboard==f.dashboard_model)
  f.ready=root.scheduler.ready; f.due_work=root.scheduler.due_work; f.observers=root.logic_observers; f.phase='done'
  log('TC_UPGRADE_OK mixed-paused-queues-1100-signals-shell-partial-frame-credits-no-replay')
end
return M
