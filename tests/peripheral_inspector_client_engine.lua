-- Real native input observer. Does not open inspectors or synthesize GUI events.
local scene=require('tests.peripheral_inspector_engine')
local scheduler=require('scripts.scheduler')
local registry=require('scripts.registry')
local model=require('scripts.ui.peripheral-inspector-model')
local inspector=require('scripts.ui.peripheral-inspector')
local editor=require('scripts.ui.editor')
local M={run=scene.setup}
local cold_loaded=false
remote.add_interface('tc-inspector-cold',{freeze=function()
  local root=registry.get(); local ids=storage.tc_inspector_test.ids; local c=registry.record(ids.computer)
  local windows={}; local count=0
  for _,p in pairs(game.connected_players) do
    local s=model.session(p.index); local frame=p.gui.screen[inspector.frame_name]
    assert(s and s.snapshot and frame and p.opened==frame)
    count=count+1; windows[p.index]={session=s,token=s.token,snapshot=s.snapshot,frame=frame}
  end
  assert(count==2 and c.state.starts==1)
  storage.tc_inspector_cold={tick=game.tick,computer=c.id,database=ids.kv,
    sessions=root.peripheral_inspectors,windows=windows,count=count,
    ledger=root.ledger,ledger_tick=root.ledger.tick,ledger_total=root.ledger.total,
    maintenance=root.scheduler.maintenance_spent,run=c.run_id,state=c.state,
    contents=registry.record(ids.kv).database}
  game.tick_paused=true; game.server_save('ns7-inspector-open')
end})
function M.on_load()
  -- The native cold driver records these aliases while real windows are open.
  -- Loading only inspects them; no UI, ledger or application state is rebuilt.
  local w=storage.tc_inspector_cold
  if not w then return end
  local root=registry.get(); local c=registry.record(w.computer)
  assert(root.peripheral_inspectors==w.sessions and root.ledger==w.ledger)
  assert(root.ledger.tick==w.ledger_tick and root.ledger.total==w.ledger_total)
  assert(root.scheduler.maintenance_spent==w.maintenance)
  assert(c.run_id==w.run and c.state==w.state and c.state.starts==1)
  assert(registry.record(w.database).database==w.contents)
  for index,s in pairs(w.windows) do
    assert(model.session(index)==s.session and s.session.token==s.token)
    assert(s.session.snapshot==s.snapshot and s.frame.valid)
  end
  cold_loaded=true; log('TC_INSPECTOR_NATIVE_COLD_ON_LOAD_UNCHANGED')
end
function M.on_player_joined(event)
  local p=game.get_player(event.player_index)
  p.teleport({0,-1},game.surfaces[1]); p.zoom=1
  p.print('Isolated inspector scene. Ordinary click opens peripherals; Ctrl-click computer opens its workspace. Native Copy only.')
end
local function elements(e,result,prefix)
  if not e or not e.valid then return end
  local path=prefix..'/'..e.name
  if e.type=='text-box' or e.type=='textfield' then result[path]=e.text end
  for _,child in pairs(e.children) do elements(child,result,path) end
end
function M.on_tick(event)
  if cold_loaded then
    cold_loaded=false
    helpers.write_file('inspector-native-cold.json',helpers.table_to_json({passed=true,
      restored_tick=game.tick,save_tick=storage.tc_inspector_cold.tick,open_windows=storage.tc_inspector_cold.count,
      mode=script.feature_flags.space_travel and 'space-age' or 'base'}),false)
    log('TC_INSPECTOR_NATIVE_COLD_OK')
    -- This frozen test witness belongs only to the original saved-open snapshot,
    -- not to later live map transfers after normal session invalidation.
    storage.tc_inspector_cold=nil
  end
  scheduler.tick(event.tick)
  if event.tick%15~=0 then return end
  local s=storage.tc_inspector_test
  local report={tick=event.tick,ids=s.ids,players={},devices={},maintenance=registry.get().scheduler.maintenance_spent}
  for _,id in ipairs(registry.get().order) do
    local r=registry.record(id)
    if r and r.body.valid then report.devices[#report.devices+1]={id=id,kind=r.kind,position=r.body.position,
      direction=r.body.direction,unit=r.body.unit_number,powered=r.powered,operable=r.body.operable} end
  end
  for _,p in pairs(game.connected_players) do
    local f=p.gui.screen[inspector.frame_name]; local e=p.gui.screen[editor.frame_name]
    local session=model.session(p.index)
    local item={index=p.index,name=p.name,force=p.force.index,position=p.position,selected=p.selected and p.selected.name,
      inspector=f and f.valid and p.opened==f or false,editor=e and e.valid and p.opened==e or false,
      session=session and {id=session.id,token=session.token,key=session.key~=nil and model.escape(session.key),pending=session.pending,
        snapshot_tick=session.snapshot and session.snapshot.tick,geometry=session.snapshot and session.snapshot.kind=='monitor' and session.snapshot.details,
        logic=session.snapshot and session.snapshot.kind=='logic' and session.snapshot.details},texts={}}
    if f then elements(f,item.texts,''); item.location=f.location end
    if e then elements(e,item.texts,'') end
    report.players[#report.players+1]=item
  end
  local c=registry.record(s.ids.computer); report.program={status=c.status,starts=c.state.starts,beats=c.state.beats,run=c.run_id}
  helpers.write_file('inspector-client-state.json',helpers.table_to_json(report),false)
end
return M
