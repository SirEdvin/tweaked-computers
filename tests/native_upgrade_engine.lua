-- One fixture runs under the frozen guarded archive and the native candidate.
-- Native entities and real ticks are used. The authoring player is table-backed.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local shell=require('scripts.runtime.shell')
local limits=require('scripts.runtime.limits')
local defs=require('scripts.device-definitions')
local editor=require('scripts.ui.editor')
local model=require('scripts.ui.editor-model')
local players=require('tests.editor_contract')
local M={}
local loaded=false
local player
local source=[[local function private() return 17 end
function start(e)
  assert(private()==17)
  computer.setState('boots',(computer.getState('boots') or 0)+1)
  computer.setState('order','')
  computer.after(80,'later')
end
function message(e)
  assert(private()==17)
  computer.setState('order',computer.getState('order')..e.tag)
end
function later(e)
  computer.setState('later',(computer.getState('later') or 0)+1)
end]]
local function fixture() return storage.tc_native_upgrade end
local function copy(v,seen)
  if type(v)~='table' or v.object_name then return v end
  seen=seen or {}; if seen[v] then return seen[v] end
  local result={}; seen[v]=result
  for k,a in pairs(v) do result[k]=copy(a,seen) end
  return result
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
local function retained(rec)
  local result=copy{active=rec.active,saved_source=rec.saved_source,saved_revision=rec.saved_revision,
    run_id=rec.run_id,run_generation=rec.run_generation,status=rec.status,state=rec.state,
    queue=rec.queue,queue_bytes=rec.queue_bytes,timers=rec.timers,subscriptions=rec.subscriptions,
    shell=rec.shell,last_dispatch_tick=rec.last_dispatch_tick,logs=rec.logs,log_bytes=rec.log_bytes}
  result.active.compiler_version=nil
  return result
end
local function with_player(fn)
  local real=game
  game=setmetatable({get_player=function(i) if player and i==player.index then return player end; return real.get_player(i) end},{__index=real})
  local ok,result=pcall(fn); game=real
  assert(ok,result); return result
end
local function open(rec,token)
  player=players.player(9001,rec.body); assert(editor.open(player,rec.id))
  local gui=player.gui.screen[editor.frame_name]
  if token then model.session(player.index).token=token; gui.tags.token=token end
  with_player(function()
    gui.content.selected_tab_index=2
    editor.on_tab{player_index=player.index,element=gui.content,tick=game.tick}
  end)
  return model.session(player.index).token
end
local function submit(rec,text)
  return with_player(function()
    return shell.submit(rec,text,player.index,model.session(player.index).token,game.tick,rec.shell and rec.shell.id or false)
  end)
end
local function tick(event) with_player(function() scheduler.tick(event.tick) end) end
local function completed(rec)
  assert(rec.status=='running',serpent.line(rec.diagnostic))
  assert(rec.state.boots==1 and rec.state.order=='ab' and rec.state.shell==2 and rec.state.later==1)
  assert(rec.state.unapplied==nil and #rec.queue==0 and #rec.shell.pending==0 and next(rec.timers)==nil)
end
function M.run()
  assert(limits.compiler_version==2 and registry.get().ledger.version==1,'create the save with the genuine guarded archive')
  local surface=game.surfaces[1]
  local function build(kind,x,y)
    return assert(lifecycle.build(assert(surface.create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})))
  end
  local rec=build('computer',0,0); local db=build('kv',3,0)
  assert(lifecycle.connector(rec,'network','red').connect_to(lifecycle.connector(db,'network','red')))
  assert(surface.create_entity{name='substation',position={3,4},force='player'})
  local supply=assert(surface.create_entity{name='electric-energy-interface',position={6,4},force='player'})
  supply.power_production=100000000; supply.power_usage=0
  assert(runtime.save(rec.id,source,0)); assert(runtime.activate(rec.id,game.tick))
  storage.tc_native_upgrade={phase='power',id=rec.id,db=db.id,since=game.tick,from_version=script.active_mods['tweaked-computers']}
end
function M.on_load()
  local f=fixture(); loaded=true
  if f.phase=='frozen' or f.phase=='done' then
    assert(equal(registry.get(),f.load_root),'on_load changed the retained registry or aliases')
    log('TC_NATIVE_UPGRADE_LOAD_UNCHANGED')
  end
end
function M.on_configuration_changed(event)
  local f=fixture(); local root=registry.get(); local rec=registry.record(f.id)
  assert(f.phase=='frozen' and loaded)
  local change=assert(event.mod_changes['tweaked-computers'])
  assert(change.old_version==f.from_version and change.new_version~=change.old_version)
  assert(script.active_mods['tweaked-computers']==change.new_version)
  assert(limits.compiler_version==3 and rec.active.compiler_version==3 and root.ledger.version==2)
  assert(equal(retained(rec),f.retained),'configuration change altered accepted program or Console state')
  assert(rec.active==f.active and rec.state==f.state and rec.queue==f.queue and rec.queue[1]==f.first_event)
  assert(rec.timers==f.timers and rec.timers[f.timer_id]==f.timer and f.timer.deadline==f.deadline)
  assert(rec.shell==f.shell and rec.shell.values==f.graph and rec.shell.pending==f.pending and rec.shell.pending[1]==f.first_command)
  assert(root.ledger==f.ledger and root.next_sequence==f.sequence)
  local machine=assert(root.ledger.machines[rec.id])
  assert(machine.allocations==nil)
  if root.ledger.tick==f.spent.tick then
    assert(root.ledger.total>=f.spent.total and machine==f.machine and machine.compile>=f.spent.compile)
  else
    assert(root.ledger.tick==game.tick and game.tick>f.spent.tick,'credits changed without a new synchronized tick')
  end
  assert(registry.record(f.db).database==f.database and equal(f.database,f.database_snapshot))
  log('TC_NATIVE_UPGRADE_VERSIONS old='..change.old_version..' new='..change.new_version..' ledger_tick='..root.ledger.tick..' old_tick='..f.spent.tick)
  f.token=open(rec,f.token); f.phase='resume'; f.resume_tick=game.tick; loaded=false
  log('TC_NATIVE_UPGRADE_CONFIG_PRESERVED')
end
function M.on_tick(event)
  local f=fixture(); local rec=registry.record(f.id); local root=registry.get()
  if f.phase=='frozen' then return end
  if f.phase=='done' then
    if loaded then
      tick(event); completed(rec); loaded=false
      log('TC_UPGRADE_ORDINARY_OK')
    end
    return
  end
  if f.phase=='power' then
    loaded=false; tick(event)
    assert(event.tick-f.since<120,'powered startup deadline')
    assert(rec.status=='running',serpent.line(rec.diagnostic))
    if rec.state.boots~=1 then return end
    f.token=open(rec)
    assert(submit(rec,string.format('a={n=0}; a.self=a; b=a; p=peripheral.wrap(%q,"red"); m=p.get; p.set("kept","seven")',f.db)))
    f.phase='seed'; return
  end
  if f.phase=='seed' then
    tick(event)
    assert(event.tick-f.since<120,'Console graph setup deadline')
    assert(rec.status=='running',serpent.line(rec.diagnostic))
    if #rec.shell.pending>0 then return end
    assert(not rec.shell.diagnostic,serpent.line(rec.shell.diagnostic))
    assert(submit(rec,'assert(a==b and a.self==a and m==p.get); assert(m("kept")=="seven"); a.n=a.n+1; computer.setState("shell",a.n)'))
    assert(submit(rec,'assert(a.n==1 and a==b and a.self==a); a.n=a.n+1; computer.setState("shell",a.n)'))
    assert(runtime.enqueue(rec,'message',{name='upgrade',tag='a'},event.tick))
    assert(runtime.enqueue(rec,'message',{name='upgrade',tag='b'},event.tick))
    assert(runtime.save(rec.id,'function start(e) computer.setState("unapplied",true) end',rec.saved_revision))
    assert(rec.active.compiler_version==2 and root.ledger.version==1)
    f.active=rec.active; f.state=rec.state; f.queue=rec.queue; f.first_event=rec.queue[1]
    f.timers=rec.timers; f.timer_id=assert(next(rec.timers)); f.timer=rec.timers[f.timer_id]; f.deadline=f.timer.deadline
    f.shell=rec.shell; f.graph=rec.shell.values; f.pending=rec.shell.pending; f.first_command=rec.shell.pending[1]
    f.ledger=root.ledger; f.machine=assert(root.ledger.machines[rec.id]); f.sequence=root.next_sequence
    assert(f.machine.allocations>0 and root.ledger.total>0,'the guarded save must contain real paid work and allocations')
    f.spent={tick=root.ledger.tick,total=root.ledger.total,compile=f.machine.compile}
    f.database=registry.record(f.db).database; f.database_snapshot=copy(f.database)
    f.retained=retained(rec); f.load_root=copy(root); f.phase='frozen'
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  assert(f.phase=='resume')
  tick(event)
  assert(event.tick-f.resume_tick<120,'upgraded work deadline')
  assert(rec.status=='running',serpent.line(rec.diagnostic))
  assert(not rec.shell.diagnostic,serpent.line(rec.shell.diagnostic))
  assert(rec.state.boots==1 and rec.state.unapplied==nil,'migration replayed or replaced active source')
  if rec.state.later~=1 then return end
  completed(rec)
  f.phase='done'; f.load_root=copy(root)
  log('TC_UPGRADE_OK')
end
return M
