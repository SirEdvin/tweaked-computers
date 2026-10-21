-- Opt-in isolated UI1 scene. Host controls change fixture data/open windows;
-- tab, selection, Follow, text/copy and scrolling are driven by native input.
local scene=require('tests.shell_client_engine')
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local kv=require('scripts.services.kv')
local editor=require('scripts.ui.editor')
local inspector=require('scripts.ui.peripheral-inspector')
local model=require('scripts.ui.editor-model')
local inspection=require('scripts.ui.peripheral-inspector-model')
local read=inspection.read
inspection.read=function(...)
  if storage.tc_ui1 and storage.tc_ui1.query_error then error({code='E_NETWORK_PENDING'},0) end
  return read(...)
end
local M={}
local function rec(kind)
  local ids=storage.tc_shell_client
  return assert(registry.record(ids[kind=='kv' and 'db' or kind=='monitor' and 'monitor_tile' or kind]))
end
local function wire(a,b)
  return a.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(b.get_wire_connector(defines.wire_connector_id.circuit_red,true))
end
function M.run()
  scene.run()
  local db=rec('kv')
  for i=2,12 do kv.methods.set(nil,db,nil,game.tick,function() end,string.format('key-%02d',i),'stable value '..i) end
  kv.methods.hset(nil,db,nil,game.tick,function() end,'key-01','field','before')
  local s=game.surfaces[1]
  local searcher=assert(lifecycle.build(assert(s.create_entity{name='tc-recipe-searcher',position={9,-3},force='player'})))
  storage.tc_shell_client.recipe_searcher=searcher.id
  local target=assert(s.create_entity{name='constant-combinator',position={11,0},force='player'})
  assert(lifecycle.connector(rec('configurator'),'targets','red').connect_to(target.get_wire_connector(defines.wire_connector_id.circuit_red,true)))
  storage.tc_ui1={target=target,events={}}
end
M.on_player_joined=scene.on_player_joined
remote.add_interface('tc-ui1',{
  open=function(kind)
    local p=game.get_player(1)
    if kind=='editor' then inspector.close(p); editor.open(p,rec('computer').id)
    else
      local f=p.gui.screen[editor.frame_name]
      if f then editor.on_closed{player_index=p.index,element=f} end
      inspector.open(p,rec(kind).id)
    end
  end,
  arm=function(action)
    storage.tc_ui1.action=action; storage.tc_ui1.at=game.tick+360
    log('TC_UI1_ARM '..action..' '..storage.tc_ui1.at)
  end,
  fill=function()
    for i=1,55 do runtime.log(rec('computer'),string.format('Retained line %02d: native live Console witness ABCDEFGHIJ',i),game.tick) end
  end,
})
local function mutate(action)
  if action=='append' then runtime.log(rec('computer'),'NEW LIVE OUTPUT',game.tick)
  elseif action=='kv' then kv.methods.hset(nil,rec('kv'),nil,game.tick,function() end,'key-01','field','after automatic update')
  elseif action=='config' then
    local target=assert(game.surfaces[1].create_entity{name='constant-combinator',position={13,0},force='player'})
    assert(wire(storage.tc_ui1.target,target))
  elseif action=='disconnect' or action=='reconnect' then
    local a=lifecycle.connector(rec('computer'),'network','red'); local b=lifecycle.connector(rec('kv'),'network','red')
    assert(action=='disconnect' and a.disconnect_from(b) or action=='reconnect' and a.connect_to(b))
  elseif action=='power-off' then storage.tc_ui1.no_power=true
  elseif action=='power-on' then storage.tc_ui1.no_power=false
  elseif action=='query-error' then storage.tc_ui1.query_error=true
  elseif action=='query-ok' then storage.tc_ui1.query_error=false
  elseif action=='overflow' then
    for i=1,70 do runtime.log(rec('computer'),'Overflow witness '..i,game.tick) end
  else error('unknown UI1 test action '..tostring(action)) end
end
local function tree(e)
  local t={name=e.name,type=e.type,index=e.index,visible=e.visible,children={}}
  if e.type=='text-box' or e.type=='textfield' then t.text=e.text end
  if e.type=='checkbox' then t.state=e.state end
  if e.type=='label' or e.type=='button' then t.caption=e.caption end
  for _,child in pairs(e.children) do t.children[#t.children+1]=tree(child) end
  return t
end
function M.on_tick(event)
  local x=storage.tc_ui1
  if x.no_power then lifecycle.power_entity(rec('kv')).energy=0 end
  if x.at and event.tick>=x.at then
    local action=x.action; x.at=nil; x.action=nil; mutate(action)
    x.events[#x.events+1]={action=action,tick=event.tick}; log('TC_UI1_MUTATED '..action)
  end
  scene.on_tick(event)
  if event.tick%15~=0 then return end
  local p=game.get_player(1); if not p then return end
  local f=p.gui.screen[editor.frame_name] or p.gui.screen[inspector.frame_name]
  local s,b=model.session(1); local i=inspection.session(1)
  local state={tick=event.tick,events=x.events,frame=f and tree(f),editor=s and {tab=s.tab,peripheral=s.peripheral,wire=s.peripheral_wire},
    draft=s and b.documents[s.id] and b.documents[s.id].source,inspection=i and {key=i.key,field=i.field,page=i.page,field_page=i.field_page,value_page=i.value_page,
    snapshot_tick=i.snapshot and i.snapshot.tick,pending=i.pending},maintenance=registry.get().scheduler.maintenance_spent}
  helpers.write_file('ui1-state.json',helpers.table_to_json(state),false)
end
return M
