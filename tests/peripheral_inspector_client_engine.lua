-- Real native input observer. Does not open inspectors or synthesize GUI events.
local scene=require('tests.peripheral_inspector_engine')
local scheduler=require('scripts.scheduler')
local registry=require('scripts.registry')
local model=require('scripts.ui.peripheral-inspector-model')
local inspector=require('scripts.ui.peripheral-inspector')
local editor=require('scripts.ui.editor')
local M={run=scene.setup}
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
