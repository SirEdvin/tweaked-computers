-- Actual full-client/connected-peer scene; test observations are not production UI.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local defs=require('scripts.device-definitions')
local shell=require('scripts.runtime.shell')
local monitor=require('scripts.services.monitor')
local dashboard=require('examples.production-statistics-monitor')
local M={}
local function f() return storage.tc_stat_client end
local source=[[function start() computer.setState('boots',(computer.getState('boots') or 0)+1); computer.every(30,'query') end

function query()
  local s=peripheral.find('production_statistics','red'); assert(s)
  local green=peripheral.find('production_statistics','green'); assert(green)
  local value={totals={},rates={},histories={},descriptor=peripheral.describe(peripheral.getName(s),'red')}
  for _,kind in ipairs({'item','fluid','pollution'}) do
    value.totals[kind]=s.getTotals(kind); value.rates[kind]=s.getRates(kind,'one_minute')
    local name=kind=='item' and 'iron-plate' or kind=='fluid' and 'water' or 'stone-furnace'
    value.histories[kind]=green.getHistory(kind,name,'one_minute',kind=='item' and 'normal' or nil)
  end
  local ok,history=pcall(green.getHistory,'item','iron-plate','one_minute','legendary')
  if ok then value.legendary=history elseif history.code~='E_RANGE' then error(history) end
  value.copper=green.getHistory('item','copper-plate','one_minute')
  computer.setState('snapshot',value)
  computer.setState('queries',(computer.getState('queries') or 0)+1)
end]]
local function build(kind,x,y,d)
  local b=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},direction=d or 0,force='player'})
  lifecycle.on_built{entity=b}; return assert(registry.by_entity(b))
end
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local function native(kind)
  local surface=game.surfaces[1]
  if kind=='item' then return game.forces.player.get_item_production_statistics(surface) end
  if kind=='fluid' then return game.forces.player.get_fluid_production_statistics(surface) end
  return surface.pollution_statistics
end
local function verify(snapshot)
  assert(snapshot.descriptor.surface.index==game.surfaces[1].index and snapshot.descriptor.type=='production_statistics')
  for _,kind in ipairs({'item','fluid','pollution'}) do
    local stats=native(kind)
    for _,side in ipairs({'input','output'}) do
      local counts=stats[side..(kind=='item' and '_quality_counts' or '_counts')]
      assert(equal(snapshot.totals[kind][side],counts),'client totals parity '..kind..' '..side)
      for key,value in pairs(counts) do
        if kind=='item' then
          for item in pairs(value) do value[item]=stats.get_flow_count{name={name=item,quality=key},category=side,precision_index=defines.flow_precision_index.one_minute,count=false} end
        else counts[key]=stats.get_flow_count{name=key,category=side,precision_index=defines.flow_precision_index.one_minute,count=false} end
      end
      assert(equal(snapshot.rates[kind][side],counts),'client rates parity '..kind..' '..side)
    end
  end
  for _,kind in ipairs({'item','fluid','pollution','legendary','copper'}) do
    local h=kind=='legendary' and snapshot.legendary or kind=='copper' and snapshot.copper or snapshot.histories[kind]
    if h then
      local stats=native((kind=='legendary' or kind=='copper') and 'item' or kind)
      local name=(kind=='item' or kind=='legendary' or kind=='copper') and {name=kind=='copper' and 'copper-plate' or 'iron-plate',quality=kind=='legendary' and 'legendary' or 'normal'} or kind=='fluid' and 'water' or 'stone-furnace'
      for _,side in ipairs({'input','output'}) do
        assert(#h[side]==300)
        for i=1,300 do
          assert(h[side][i]==stats.get_flow_count{name=name,category=side,precision_index=defines.flow_precision_index.one_minute,sample_index=i,count=false},'client history parity '..kind..' '..side..' '..i)
        end
      end
    end
  end
end
function M.run()
  storage.tc_stat_client={views={},start=game.tick}
  local x=f(); local surface=game.surfaces[1]; surface.always_day=true
  surface.request_to_generate_chunks({4,1},2); surface.force_generate_chunk_requests()
  for _,e in ipairs(surface.find_entities_filtered{area={{-16,-16},{24,16}},type={'tree','simple-entity','cliff'}}) do e.destroy() end
  local tiles={}; for y=-14,14 do for xx=-14,22 do tiles[#tiles+1]={name='refined-concrete',position={xx,y}} end end; surface.set_tiles(tiles)
  if remote.interfaces.freeplay then remote.call('freeplay','set_skip_intro',true); remote.call('freeplay','set_disable_crashsite',true) end
  local c=build('computer',-4,0); x.c=c.id
  for i,d in ipairs({0,4,8,12}) do
    local s=build('production_statistics',(i-1)*4,0,d); x.views[i]=s.id
    build('production_statistics',(i-1)*4,5,d)
    for _,color in ipairs({'red','green'}) do
      local prior=i==1 and c or registry.record(x.views[i-1])
      assert(lifecycle.connector(prior,'network',color).connect_to(lifecycle.connector(s,'network',color)))
    end
  end
  local display_computer=build('computer',-4,-4); local display_stats=build('production_statistics',0,-4)
  local screen=build('monitor',3,-4); build('monitor',4,-4); build('monitor',3,-3); build('monitor',4,-3)
  assert(lifecycle.connector(display_computer,'network','red').connect_to(lifecycle.connector(display_stats,'network','red')))
  assert(lifecycle.connector(display_stats,'network','red').connect_to(lifecycle.connector(screen,'network','red')))
  assert(runtime.save(display_computer.id,dashboard,0)); assert(runtime.activate(display_computer.id,game.tick))
  x.dashboard=display_computer.id; x.screen=screen.id
  local supply=assert(surface.create_entity{name='electric-energy-interface',position={17,-7},force='player'})
  supply.power_production=100000000; supply.power_usage=0
  for _,p in ipairs({{-4,-7},{9,-7},{17,-7}}) do assert(surface.create_entity{name='substation',position=p,force='player'}) end
  assert(runtime.save(c.id,source,0)); assert(runtime.activate(c.id,game.tick))
end
function M.on_player_joined(event)
  local p=game.get_player(event.player_index); p.set_controller{type=defines.controllers.god}; p.teleport({4,1}); p.zoom=1.5
  local old=p.gui.screen.tc_stat_observation; if old then old.destroy() end
  local panel=p.gui.screen.add{type='frame',name='tc_stat_observation',direction='vertical',caption='Statistics test observation'}
  panel.location={20,20}; panel.add{type='label',name='summary',caption='Waiting for native parity'}
  panel.add{type='textfield',name='paste_name',text=''}
  log('TC_STAT_CLIENT_JOIN '..p.index)
  local x=f(); local c=registry.record(x.c)
  if #game.connected_players>=2 and x.frozen and not x.late_join then
    assert(c.state.snapshot==x.frozen.snapshot,'late join replaced retained snapshot')
    local old=registry.record(x.views[1]); local position=old.body.position
    assert(lifecycle.remove(old.id,'peer-fixture',true))
    local replacement=build('production_statistics',position.x,position.y)
    for _,color in ipairs({'red','green'}) do
      assert(lifecycle.connector(c,'network',color).connect_to(lifecycle.connector(replacement,'network',color)))
      assert(lifecycle.connector(replacement,'network',color).connect_to(lifecycle.connector(registry.record(x.views[2]),'network',color)))
    end
    lifecycle.power_entity(replacement).energy=1000; replacement.powered=true
    x.old_identity=old.id; x.views[1]=replacement.id
    local ok,e=shell.evaluate(c,"local ok,e=pcall(captured,'item'); assert(not ok and e.code=='E_UNREACHABLE')",game.tick,2); assert(ok,serpent.line(e))
    x.late_join=true; x.resume_tick=game.tick; game.tick_paused=false
    log('TC_STAT_PEER_RESUMED synchronized-join-stale-identity-refused')
  elseif #game.connected_players>=2 and x.peer_done then
    local ok,e=shell.evaluate(c,"local ok,e=pcall(captured,'item'); assert(not ok and e.code=='E_UNREACHABLE')",game.tick,3); assert(ok,serpent.line(e))
    x.cold_stale=true; log('TC_STAT_PEER_COLD_STALE_OK restored-captured-method-refused')
  end
end
function M.on_load() end
function M.on_configuration_changed() error('unexpected client fixture configuration change') end
function M.on_tick(event)
  local x=f(); local c=registry.record(x.c)
  scheduler.tick(event.tick)
  assert(c.status=='running',serpent.line(c.diagnostic))
  local value=c.state.snapshot
  if value and value.histories.item.tick==event.tick then
    verify(value)
    local peers={}; for _,p in pairs(game.connected_players) do peers[#peers+1]=p.index end; table.sort(peers)
    local snapshot=helpers.table_to_json{tick=event.tick,snapshot=value,queries=c.state.queries,boots=c.state.boots,
      old_identity=x.old_identity,current_identity=x.views[1],late_join=x.late_join,peer_done=x.peer_done,cold_stale=x.cold_stale or false,peers=peers}
    helpers.write_file('stat-server.json',snapshot,false,0)
    for _,p in pairs(game.connected_players) do
      helpers.write_file('stat-client.json',snapshot,false,p.index)
      local panel=p.gui.screen.tc_stat_observation
      if panel then panel.summary.caption='All categories 1m @'..event.tick..' native keys + 300 samples/side agree' end
    end
    if not x.ready then x.ready=true; x.ready_tick=event.tick; log('TC_STAT_CLIENT_READY') end
    if game.is_multiplayer() and #game.connected_players==1 and not x.frozen then
      c.shell={version=1,id='statistics-client-shell',pending={},pending_bytes=0}
      local ok,e=shell.evaluate(c,"s=peripheral.find('production_statistics','red'); captured=s.getTotals",game.tick,1); assert(ok,serpent.line(e))
      x.frozen={snapshot=value}; game.tick_paused=true; log('TC_STAT_PEER_FROZEN retained-data-before-late-join')
    end
    if x.late_join and event.tick-x.resume_tick>=60 and not x.peer_done then
      assert(c.state.boots==1); x.peer_done=true; log('TC_STAT_MULTIPLAYER_OK joining-peer-native-snapshots-and-stale-identity')
    end
    if not game.is_multiplayer() and x.captures and event.tick-x.start>=270 and not x.chart_ready
      and game.get_player(1).opened_gui_type==defines.gui_type.production then
      local display=registry.record(x.dashboard)
      assert(display.status=='running' and display.state.statistics_monitor,serpent.line(display.diagnostic))
      local group=assert(monitor.resolve(registry.record(x.screen))); assert(group.model.cells[1][1]==string.byte('I'))
      log('TC_STAT_CLIENT_MAINTAINED_DASHBOARD_OK')
      game.take_screenshot{surface=game.surfaces[1],position={3.5,-3.5},resolution={640,480},zoom=4,
        show_gui=false,show_entity_info=false,force_render=true,path='stat-dashboard.png'}
      x.chart_ready=true; game.tick_paused=true; log('TC_STAT_CHART_READY item normal')
    end
  end
  -- Controlled native flow input, not a private/synthetic history implementation.
  if event.tick-x.start<=120 then
    native('item').on_flow('iron-plate',2); native('item').on_flow('copper-plate',-1)
    if script.active_mods.quality then native('item').on_flow({name='iron-plate',quality='legendary'},1) end
    native('fluid').on_flow('water',.5); native('fluid').on_flow('steam',-.25)
    game.surfaces[1].pollute({0,0},.125,'stone-furnace')
  end
  for _,p in pairs(game.connected_players) do
    local panel=p.gui.screen.tc_stat_observation
    if panel and panel.paste_name.text~='' and panel.paste_name.text~=x.last_copy then
      local copied=registry.record(panel.paste_name.text)
      assert(copied and copied.kind=='production_statistics','native copy did not preserve identity')
      x.last_copy=panel.paste_name.text; x.copied=x.copied or {}; x.copied[x.last_copy]=true
      log('TC_STAT_NATIVE_COPY_OK '..panel.paste_name.text)
    end
  end
  if x.ready and not x.captures and #game.connected_players>0 and event.tick-x.ready_tick>=60 then
    x.captures=true
    for i,id in ipairs(x.views) do game.take_screenshot{surface=game.surfaces[1],position=registry.record(id).body.position,resolution={512,512},zoom=4,
      show_gui=false,show_entity_info=true,force_render=true,path='stat-view-'..i..'.png'} end
    game.take_screenshot{surface=game.surfaces[1],position={4,1},resolution={1280,720},zoom=1.5,show_gui=false,show_entity_info=true,force_render=true,path='stat-family.png'}
    log('TC_STAT_CLIENT_SCREENSHOTS_REQUESTED')
  end
end
return M
