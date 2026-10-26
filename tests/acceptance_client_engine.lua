-- Opt-in SC2 native-input/connected-peer scene. HUD only prepares world state;
-- it never submits source, clicks editor controls or synthesizes monitor touches.
local integration=require('tests.integration_engine')
local registry=require('scripts.registry')
local scheduler=require('scripts.scheduler')
local editor=require('scripts.ui.editor')
local documents=require('scripts.ui.editor-model')
local monitor=require('scripts.services.monitor')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local kv=require('scripts.services.kv')
local logic=require('scripts.services.logic')
local rotation_contract=require('tests.rotation_contract')
local M={}; local loaded=false
local function fixture() return storage.tc13 end
local function setup() return storage.tc_client_acceptance end
local function computer() return registry.computer(fixture().c) end
local function report(player)
  local x=fixture(); local c=computer(); local root=registry.get()
  local frame=player.gui.screen[editor.frame_name]
  local pane=frame and frame.content; local code=pane and pane.editor
  local session,book=documents.session(player.index)
  local draft=session and session.id and book.documents[session.id]
  local display=monitor.resolve(registry.record(x.tiles[1]))
  local cb=x.inserter.get_control_behavior()
  local peers={}; for _,p in pairs(game.connected_players) do peers[#peers+1]=p.index end; table.sort(peers)
  local controls={}
  if frame then
    local function visit(e,path,visible)
      visible=visible and e.visible
      if e.type=='button' or e.type=='tab' then
        controls[#controls+1]={path=path,enabled=e.enabled,visible=visible,caption=e.caption}
      end
      for _,child in pairs(e.children) do visit(child,path..'/'..child.name,visible) end
    end
    visit(frame,'frame',true)
  end
  local inventory={}; local bag=player.get_main_inventory()
  if bag then for i=1,#bag do local stack=bag[i]; if stack.valid_for_read then
    local ok,tags=pcall(function() return stack.tags end)
    inventory[#inventory+1]={slot=i,name=stack.name,count=stack.count,tags=ok and tags or nil}
  end end end
  local gallery={}; local owned={}; local names={}
  for kind,def in pairs(defs.devices) do
    for _,name in ipairs({def.entity_name,def.power_name,def.name}) do names[name]=true end
    for _,role in ipairs(def.roles) do if role~='network' then names[defs.pad_name(kind,role)]=true end end
  end
  for _,role in ipairs(defs.role_order) do names['tc-port-'..role]=true end
  for _,id in ipairs(setup().gallery or {}) do local r=registry.record(id)
    if r then
      local connections={}; for _,role in ipairs(defs.devices[r.kind].roles) do
        local connector=lifecycle.connector(r,role,'red'); connections[role]=connector and #connector.real_connections or 0
      end
      gallery[#gallery+1]={id=id,kind=r.kind,direction=r.body.direction,operable=r.body.operable,position=r.body.position,connections=connections}
      owned[r.body.unit_number]=true
      for _,child in pairs(r.children) do if child.valid then owned[child.unit_number]=true end end
    end
  end
  local db=registry.record(x.db)
  local gallery_native=0; local gallery_orphans=0; local gallery_ghosts=0
  if setup().gallery then
    local filter={}; for name in pairs(names) do filter[#filter+1]=name end
    for _,entity in pairs(game.surfaces[1].find_entities_filtered{area={{34,-5},{66,27}},name=filter}) do
      gallery_native=gallery_native+1; if not owned[entity.unit_number] then gallery_orphans=gallery_orphans+1 end
    end
    for _,ghost in pairs(game.surfaces[1].find_entities_filtered{area={{34,-5},{66,27}},type='entity-ghost'}) do
      if names[ghost.ghost_name] then gallery_ghosts=gallery_ghosts+1 end
    end
  end
  return {tick=game.tick,computer=c.id,status=c.status,diagnostic=c.diagnostic,state=c.state,
    saved=c.saved_source,saved_revision=c.saved_revision,active=c.active and c.active.source,
    active_revision=c.active and c.active.revision,run=c.run_id,logs=c.logs,
    ledger={tick=root.ledger.tick,total=root.ledger.total,maintenance=root.scheduler.maintenance_spent},
    stock=x.stock.get_item_count('iron-plate'),transferred=x.destination.get_item_count('iron-plate'),
    configuration={enabled=cb.circuit_enable_disable,condition=cb.circuit_condition,position=x.inserter.position},
    kv=db and db.database,db_id=x.db,inventory=inventory,gallery=gallery,gallery_native=gallery_native,gallery_orphans=gallery_orphans,gallery_ghosts=gallery_ghosts,monitor=display and {id=display.id,width=display.model.width,height=display.model.height,
      model=display.model,sequence=display.presentation and display.presentation.sequence},
    player=player.index,peers=peers,resolution=player.display_resolution,scale=player.display_scale,
    opened=frame and player.opened==frame or false,tab=pane and pane.selected_tab_index,
    source=code and code.source.text,source_index=code and code.source.index,draft=draft and draft.source,
    position=player.position,zoom=player.zoom,cursor=player.cursor_stack.valid_for_read and player.cursor_stack.name,
    frame_location=frame and frame.location,controls=controls,
    feedback=code and code.message.feedback.caption,
    message=session and session.message,validation=session and session.validation,
    joins=setup().joins,rotation_events=setup().rotation_events}
end
local function publish()
  local c=computer(); local x=fixture(); local root=registry.get()
  local world={tick=game.tick,state=c.state,status=c.status,run=c.run_id,saved_revision=c.saved_revision,
    active_revision=c.active and c.active.revision,ledger=root.ledger,transferred=x.destination.get_item_count('iron-plate'),
    database=registry.record(x.db) and registry.record(x.db).database,output=logic.inspect_output(registry.record(x.io),function() end),joins=setup().joins}
  helpers.write_file('acceptance-world.json',helpers.table_to_json(world),false,0)
  for _,p in pairs(game.connected_players) do
    helpers.write_file('acceptance-state.json',helpers.table_to_json(report(p)),false,p.index)
    helpers.write_file('acceptance-world.json',helpers.table_to_json(world),false,p.index)
  end
end
function M.run()
  integration.run()
  if remote.interfaces.freeplay then
    remote.call('freeplay','set_skip_intro',true)
    remote.call('freeplay','set_disable_crashsite',true)
  end
  game.surfaces[1].always_day=true
  storage.tc_client_acceptance={joins={},actions={},rotation_events={}}
  rotation_contract.run(fixture().c,fixture().io)
  -- Forward the production handler unchanged for every non-fixture element.
  -- This wrapper is installed at control parsing below, not during gameplay.
end
local real_rotate=script.get_event_handler(defines.events.on_player_rotated_entity)
script.on_event(defines.events.on_player_rotated_entity,function(event)
  local x=setup(); local rec=registry.by_entity(event.entity)
  if x and rec then x.rotation_events[rec.id]=(x.rotation_events[rec.id] or 0)+1 end
  return real_rotate(event)
end)
local real_click=script.get_event_handler(defines.events.on_gui_click)
script.on_event(defines.events.on_gui_click,function(event)
  local e=event.element; local p=game.get_player(event.player_index)
  if not e or not e.valid or not p then return end
  if e.parent~=p.gui.top.tc_acceptance then return real_click(event) end
  local x=fixture()
  setup().actions[#setup().actions+1]={tick=game.tick,player=p.index,action=e.name}
  if e.name=='open' then p.teleport({0,-2}); editor.open(p,x.c)
  elseif e.name=='high' then x.stock.clear_items_inside(); x.stock.insert{name='iron-plate',count=120}
  elseif e.name=='low' then
    x.stock.clear_items_inside(); x.stock.insert{name='iron-plate',count=5}
    x.supply.insert{name='iron-plate',count=200}; x.destination.clear_items_inside()
  elseif e.name=='factory' then p.opened=nil; p.teleport({5,1}); p.zoom=1.5
  elseif e.name=='screen' then p.opened=nil; p.teleport({0,4}); p.zoom=2
  elseif e.name=='gallery' then
    p.opened=nil
    p.game_view_settings.show_quickbar=false; p.game_view_settings.show_shortcut_bar=false
    if not setup().gallery then
      setup().gallery={}; setup().gallery_specs={}; local surface=game.surfaces[1]
      surface.request_to_generate_chunks({49,10},2); surface.force_generate_chunk_requests()
      for _,obstacle in pairs(surface.find_entities_filtered{area={{34,-5},{66,27}},type={'tree','simple-entity','cliff'}}) do obstacle.destroy() end
      local tiles={}; for y=-5,26 do for xx=34,65 do tiles[#tiles+1]={name='refined-concrete',position={xx,y}} end end
      surface.set_tiles(tiles)
      for row,kind in ipairs({'computer','kv','monitor','logic','configurator'}) do
        for col,d in ipairs({0,4,8,12}) do
          local body=assert(surface.create_entity{name=defs.devices[kind].entity_name,position={40+(col-1)*6,(row-1)*5},direction=d,force='player'})
          local r=assert(lifecycle.build(body)); setup().gallery[#setup().gallery+1]=r.id
          setup().gallery_specs[#setup().gallery_specs+1]={kind=kind,position=body.position}
          rendering.draw_text{text=kind..' '..d,surface=surface,target={body.position.x,body.position.y-1.5},color={1,1,1},alignment='center',scale=.7}
        end
      end
      local supply=assert(surface.create_entity{name='electric-energy-interface',position={36,-3},force='player'})
      supply.power_production=100000000; supply.power_usage=0
      for _,pos in ipairs({{36,6},{50,6},{64,6},{36,20},{50,20},{64,20}}) do surface.create_entity{name='substation',position=pos,force='player'} end
    end
    for i,kind in ipairs({'computer','kv','monitor','logic','configurator'}) do p.set_quick_bar_slot(1,i,defs.devices[kind].name) end
    p.teleport({49,10}); p.zoom=.95
  elseif e.name=='kvmax' then
    p.opened=nil; local db=assert(registry.record(x.db)); db.database=kv.import{version=1,entries={}}
    p.game_view_settings.show_quickbar=true; p.game_view_settings.show_shortcut_bar=true
    for i=1,128 do local k=tostring(i); kv.methods.set(nil,db,'red',game.tick,function() end,k,string.rep('\0',128-#k)) end
    kv.methods.expire(nil,db,'red',game.tick,function() end,'1',10)
    setup().kv_position=db.body.position; setup().kv_original=db.id
    p.teleport(db.body.position); p.zoom=3; p.set_quick_bar_slot(1,1,'tc-kv')
  elseif e.name=='wire' then p.cursor_stack.set_stack{name='red-wire',count=1}
  elseif e.name=='save' then
    if not game.is_multiplayer() then p.print('Use the native Save game menu in singleplayer.'); return end
    setup().saved={tick=game.tick,starts=computer().state.starts,revision=computer().saved_revision,run=computer().run_id,
      ledger=registry.get().ledger,total=registry.get().ledger.total}
    setup().phase='frozen'; loaded=false
    game.server_save('tc-acceptance-snapshot')
    log('TC_ACCEPTANCE_SNAPSHOT_REQUESTED')
  end
  publish()
end)
function M.on_player_joined(event)
  local p=game.get_player(event.player_index)
  if not p or not setup() then return end
  p.set_controller{type=defines.controllers.god}; p.teleport({0,-2}); p.zoom=1
  p.game_view_settings.show_entity_info=true
  if not p.gui.top.tc_acceptance then
    local bar=p.gui.top.add{type='flow',name='tc_acceptance',direction='horizontal'}
    for _,name in ipairs({'open','high','low','factory','screen','save','gallery','kvmax','wire'}) do
      bar.add{type='button',name=name,caption=name}
    end
  end
  setup().joins[#setup().joins+1]={player=p.index,tick=game.tick,starts=computer().state.starts,
    run=computer().run_id,revision=computer().saved_revision,ledger=registry.get().ledger.total}
  editor.open(p,fixture().c)
  log('TC_ACCEPTANCE_PLAYER_READY index='..p.index)
end
function M.on_load()
  loaded=true
  local x=setup()
  if x and x.phase=='frozen' then
    local c=computer(); assert(c.state.starts==x.saved.starts and c.saved_revision==x.saved.revision and c.run_id==x.saved.run)
    assert(registry.get().ledger==x.saved.ledger and registry.get().ledger.total==x.saved.total)
    log('TC_ACCEPTANCE_LOAD_UNCHANGED')
  end
end
function M.on_configuration_changed() error('unexpected acceptance scene configuration change') end
function M.on_tick(event)
  if setup().phase=='frozen' then
    if not loaded then return end
    setup().phase='resumed'; loaded=false
    log('TC_ACCEPTANCE_COLD_RESUMED')
  end
  scheduler.tick(event.tick)
  if setup().kv_position and not registry.record(fixture().db) then
    local body=game.surfaces[1].find_entity(defs.devices.kv.entity_name,setup().kv_position)
    local rec=body and registry.by_entity(body)
    if rec then fixture().db=rec.id end
  end
  for i,id in ipairs(setup().gallery or {}) do
    if not registry.record(id) then
      local spec=setup().gallery_specs[i]
      local body=game.surfaces[1].find_entity(defs.devices[spec.kind].entity_name,spec.position)
      local rec=body and registry.by_entity(body)
      if rec then setup().gallery[i]=rec.id end
    end
  end
  if event.tick%15==0 then publish() end
end
return M
