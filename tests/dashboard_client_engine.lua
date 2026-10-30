-- Native clients only: real opening/buttons and independently evaluated peer state.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local runtime=require('scripts.runtime.computer')
local defs=require('scripts.device-definitions')
local ui=require('scripts.ui.dashboard')
local model=require('scripts.dashboard-model')
local example=require('examples.dashboard-charts')
local base_example=require('examples.dashboard-program')

local M={}; local cold_loaded=false
local function f() return storage.tc_dashboard_client end
local function report(tick)
  local x=f(); local c=registry.record(x.c); local second=registry.record(x.second); local panel=registry.record(x.panel)
  local peers,selected,scales,resolutions={},{},{},{}
  for _,player in pairs(game.connected_players) do
    resolutions[tostring(player.index)]={width=player.display_resolution.width,height=player.display_resolution.height}
    peers[#peers+1]=player.index; scales[tostring(player.index)]=player.display_scale
    local s=registry.get().dashboard_sessions and registry.get().dashboard_sessions[player.index]
    selected[tostring(player.index)]=s and s.selected or 0
  end
  table.sort(peers)
  local value=helpers.table_to_json{tick=tick,model=panel.dashboard,boots=c.state.boots,second_boots=second.state.boots,
    clicks=c.state.clicks or 0,second_clicks=second.state.clicks or 0,last=second.state.last,peers=peers,selected=selected,
    joined=x.joined or false,scales=scales,resolutions=resolutions,queued=#c.queue,second_queued=#second.queue,
    cold_held=x.cold_held or false,peer_cold_done=x.peer_cold_done or false}
  helpers.write_file('dashboard-server.json',value,false,0)
  for _,player in pairs(game.connected_players) do helpers.write_file('dashboard-client.json',value,false,player.index) end
end
local function build(kind,x,y,d)
  local b=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},direction=d or 0,force='player'})
  lifecycle.on_built{entity=b}; return assert(registry.by_entity(b))
end
function M.run()
  storage.tc_dashboard_client={start=game.tick}
  local x=f(); local surface=game.surfaces[1]; surface.always_day=true
  surface.request_to_generate_chunks({0,0},2); surface.force_generate_chunk_requests()
  for _,e in ipairs(surface.find_entities_filtered{area={{-20,-20},{24,20}},type={'tree','simple-entity','cliff'}}) do e.destroy() end
  local tiles={}; for y=-18,18 do for xx=-18,22 do tiles[#tiles+1]={name='refined-concrete',position={xx,y}} end end; surface.set_tiles(tiles)
  if remote.interfaces.freeplay then remote.call('freeplay','set_skip_intro',true); remote.call('freeplay','set_disable_crashsite',true) end
  local c=build('computer',-4,0); local second=build('computer',-4,4); local panel=build('dashboard',0,0)
  x.c=c.id; x.second=second.id; x.panel=panel.id
  for _,color in ipairs({'red','green'}) do
    assert(lifecycle.connector(c,'network',color).connect_to(lifecycle.connector(panel,'network',color)))
    assert(lifecycle.connector(second,'network',color).connect_to(lifecycle.connector(panel,'network',color)))
  end
  for i,d in ipairs({0,4,8,12}) do build('dashboard',i*3,6,d) end
  local supply=assert(surface.create_entity{name='electric-energy-interface',position={15,-5},force='player'})
  supply.power_production=100000000; supply.power_usage=0
  for _,position in ipairs({{-4,-5},{-4,2},{7,-5},{8,4},{15,-5}}) do assert(surface.create_entity{name='substation',position=position,force='player'}) end
  assert(runtime.save(c.id,example,0)); assert(runtime.activate(c.id,game.tick))
  local subscriber=[[function start()
  local p=peripheral.find('dashboard','red'); assert(p); p.subscribe('clicked')
  computer.setState('boots',(computer.getState('boots') or 0)+1)
end

function clicked(e)
  computer.setState('clicks',(computer.getState('clicks') or 0)+1)
  computer.setState('last',e)
end]]
  assert(runtime.save(second.id,subscriber,0)); assert(runtime.activate(second.id,game.tick))
end
function M.on_player_joined(event)
  local player=game.get_player(event.player_index)
  local character=player.character
  if player.controller_type~=defines.controllers.god then
    player.set_controller{type=defines.controllers.god}; player.teleport({0,3}); player.zoom=1.5
  end
  if character and character.valid then character.destroy() end
  log('TC_DASHBOARD_CLIENT_JOIN '..player.index)
  local old=player.gui.screen.tc_dashboard_observer; if old then old.destroy() end
  local observer=player.gui.screen.add{type='frame',name='tc_dashboard_observer',direction='vertical',caption='Test observer'}
  observer.location={8,8}; observer.add{type='textfield',name='copied',text=''}

  if #game.connected_players>=2 and cold_loaded then
    local x=f(); assert(registry.record(x.panel).dashboard==x.retained)
    assert(registry.record(x.c).queue==x.pending and registry.record(x.second).queue==x.second_pending)
    assert(registry.record(x.c).state.clicks==1 and registry.record(x.second).state.clicks==1,'cold click replay before resume')
    x.cold_held=false; x.peer_cold_done=true; cold_loaded=false; game.tick_paused=false
    log('TC_DASHBOARD_PEER_COLD_PENDING_RETAINED')
  elseif #game.connected_players>=2 and f().frozen and not f().joined then
    assert(registry.record(f().panel).dashboard==f().retained,'late join changed retained model')
    f().joined=true; game.tick_paused=false; log('TC_DASHBOARD_CLIENT_LATE_JOIN_RETAINED')
  end
end
function M.on_load() cold_loaded=f().cold_held==true end
function M.on_configuration_changed()
  f().ready=false
  log('TC_DASHBOARD_NATIVE_DEPENDENCY_CHANGED '..tostring(model.charts~=nil))
end
function M.on_tick(event)
  local x=f()
  if x.arm_cold and not x.cold_held and not x.peer_cold_done then
    local c=registry.record(x.c); local second=registry.record(x.second)
    if c.queue[1] and c.queue[1].event.name=='dashboard_click' then
      assert(#c.queue==1 and #second.queue==1 and c.state.clicks==1 and second.state.clicks==1)
      x.cold_held=true; x.retained=registry.record(x.panel).dashboard; x.pending=c.queue; x.second_pending=second.queue
      report(event.tick); game.tick_paused=true; log('TC_DASHBOARD_PEER_COLD_PENDING_FROZEN'); return
    end
  end
  if not x.queued_seen then
    for _,id in ipairs({x.c,x.second}) do
      local c=registry.record(id)
      for _,item in ipairs(c.queue) do
        if item.event.name=='dashboard_click' then
          assert(not c.state.clicks,'guest callback ran before scheduled dispatch')
          x.queued_seen=true; log('TC_DASHBOARD_NATIVE_CLICK_QUEUED_BEFORE_DISPATCH')
        end
      end
    end
  end
  scheduler.tick(event.tick)
  local c=registry.record(x.c); local second=registry.record(x.second); local panel=registry.record(x.panel)
  assert(c.status=='running',serpent.line(c.diagnostic)); assert(second.status=='running',serpent.line(second.diagnostic))
  if c.state.boots and second.state.boots then
    assert(c.state.boots==1 and second.state.boots==1,'startup replay')
    if model.charts and not x.base_example then
      local ring=panel.dashboard.tabs['1'].charts.trend
      assert(#ring.data==8 and ring.index==4 and ring.sum.input==68,'maintained program rolling wrap')
    end
    local peers={}; local selected={}
    for _,player in pairs(game.connected_players) do
      peers[#peers+1]=player.index
      local observer=player.gui.screen.tc_dashboard_observer
      if observer and observer.copied.text==panel.id and not x.copied then
        x.copied=true; log('TC_DASHBOARD_NATIVE_ID_COPY_OK')
      end
      if observer and observer.copied.text~='save-dependency' then x.native_saved=false end
      if observer and observer.copied.text=='save-dependency' and not x.native_saved then
        x.native_saved=true; game.auto_save('dashboard-native-dependency')
        log('TC_DASHBOARD_NATIVE_DEPENDENCY_SAVE_REQUESTED')
      end
      if observer and observer.copied.text=='run-base-example' and not x.base_example then
        runtime.retire(c,'stopped','fixture-base-example')
        assert(runtime.save(c.id,base_example,c.saved_revision)); assert(runtime.activate(c.id,event.tick))
        x.base_example=true
      end
      if observer and observer.copied.text=='arm-cold-click' and not x.arm_cold then
        x.arm_cold=true; log('TC_DASHBOARD_PEER_COLD_CLICK_ARMED')
      end
      local s=registry.get().dashboard_sessions and registry.get().dashboard_sessions[player.index]
      selected[tostring(player.index)]=s and s.selected or 0
    end
    table.sort(peers)
    if not x.ui_ready then
      for _,player in pairs(game.connected_players) do
        local session=registry.get().dashboard_sessions and registry.get().dashboard_sessions[player.index]
        if session and session.selected==1 then
          local count=0; for _ in pairs(session.tabs) do count=count+1 end
          local presentation=registry.get().dashboard_presentation
          if count==6 and (not model.charts or presentation and next(presentation.states)) then
            x.ui_ready=true; log('TC_DASHBOARD_NATIVE_SIX_TABS_READY')
          end
        end
      end
    end
    report(event.tick)
    if not x.ready then x.ready=true; log('TC_DASHBOARD_CLIENT_READY') end
    if x.base_example then
      local status=model.widget(panel.dashboard.tabs['1'],'status').text
      if status=='Ready' and not x.base_ready then x.base_ready=true; log('TC_DASHBOARD_BASE_EXAMPLE_READY') end
      if status=='Acknowledged' and not x.base_clicked then x.base_clicked=true; log('TC_DASHBOARD_BASE_EXAMPLE_CLICK_OK') end
    end
    if game.is_multiplayer() and #peers==1 and selected[tostring(peers[1])]==1 and not x.frozen then
      x.frozen=true; x.retained=panel.dashboard; game.tick_paused=true; log('TC_DASHBOARD_CLIENT_FROZEN')
    end

    if (c.state.clicks or 0)>0 and (second.state.clicks or 0)>0 and not x.clicked then
      assert(c.state.clicks==second.state.clicks,'subscriber fan-out diverged')
      x.clicked=true; log('TC_DASHBOARD_NATIVE_BUTTON_FANOUT_OK')
    end
  end
end
return M
