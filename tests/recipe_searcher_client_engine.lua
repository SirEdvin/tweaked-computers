-- Actual-client appearance and connected late-join scene; no production GUI added.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local defs=require('scripts.device-definitions')
local M={}; local loaded=false
local source=[[function start(e) computer.every(15,'query') end

function query(e)
  local s=peripheral.find('recipe_searcher','red'); assert(s)
  local a=s.findRecipes('item','advanced-circuit')
  local b=peripheral.find('recipe_searcher','green').findRecipes('item','advanced-circuit')
  assert(#a==#b)
  for i,v in ipairs(a) do assert(v.name==b[i].name and v.enabled==b[i].enabled) end
  computer.setState('recipes',a); computer.setState('queries',(computer.getState('queries') or 0)+1)
end]]
local function f() return storage.tc_recipe_client end
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local function build(kind,x,y,direction)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},direction=direction or 0,force='player'})
  lifecycle.on_built{entity=body}; return assert(registry.by_entity(body))
end
function M.run()
  storage.tc_recipe_client={phase='boot',start=game.tick,views={},joined={}}
  local x=f(); local surface=game.surfaces[1]; surface.always_day=true
  surface.request_to_generate_chunks({4,1},2); surface.force_generate_chunk_requests()
  for _,e in ipairs(surface.find_entities_filtered{area={{-16,-16},{24,16}},type={'tree','simple-entity','cliff'}}) do e.destroy() end
  local tiles={}; for y=-14,14 do for xx=-14,22 do tiles[#tiles+1]={name='refined-concrete',position={xx,y}} end end
  surface.set_tiles(tiles)
  if remote.interfaces.freeplay then
    remote.call('freeplay','set_skip_intro',true); remote.call('freeplay','set_disable_crashsite',true)
  end
  local c=build('computer',-4,0); x.c=c.id
  for i,d in ipairs({0,4,8,12}) do
    local s=build('recipe_searcher',(i-1)*4,0,d); x.views[i]=s.id
    local dark=build('recipe_searcher',(i-1)*4,5,d)
    rendering.draw_text{text=({'NORTH','EAST','SOUTH','WEST'})[i],surface=surface,target={s.body.position.x,-1.3},color={1,1,1},alignment='center',scale=.8}
    rendering.draw_text{text='UNPOWERED',surface=surface,target={dark.body.position.x,6},color={1,.7,.3},alignment='center',scale=.7}
  end
  for _,color in ipairs({'red','green'}) do
    assert(lifecycle.connector(c,'network',color).connect_to(lifecycle.connector(registry.record(x.views[1]),'network',color)))
    for i=2,4 do assert(lifecycle.connector(registry.record(x.views[i-1]),'network',color).connect_to(lifecycle.connector(registry.record(x.views[i]),'network',color))) end
  end
  build('kv',-4,-4); build('logic',1,-4); build('configurator',6,-4); build('monitor',9,-4)
  assert(surface.create_entity{name='assembling-machine-3',position={13,-4},force='player'})
  local supply=assert(surface.create_entity{name='electric-energy-interface',position={17,-7},force='player'})
  supply.power_production=100000000; supply.power_usage=0
  for _,pos in ipairs({{-4,-7},{9,-7},{17,-7}}) do assert(surface.create_entity{name='substation',position=pos,force='player'}) end
  game.forces.player.recipes['advanced-circuit'].enabled=false
  assert(runtime.save(c.id,source,0)); assert(runtime.activate(c.id,game.tick))
end
local function readback()
  local x=f(); local c=registry.record(x.c); local peers={}
  for _,p in pairs(game.connected_players) do peers[#peers+1]=p.index end
  table.sort(peers)
  return {tick=game.tick,computer=c.id,queries=c.state.queries,recipes=c.state.recipes,
    retained=x.retained,phase=x.phase,peers=peers,force_enabled=game.forces.player.recipes['advanced-circuit'].enabled,
    late_join_retained=x.late_join_retained,cold=x.cold}
end
local function publish()
  local data=helpers.table_to_json(readback())
  helpers.write_file('recipe-server-state.json',data,false,0)
  for _,p in pairs(game.connected_players) do helpers.write_file('recipe-client-state.json',data,false,p.index) end
end
function M.on_player_joined(event)
  local p=game.get_player(event.player_index)
  p.set_controller{type=defines.controllers.god}; p.teleport({4,1}); p.zoom=1.5
  p.insert{name='tc-recipe-searcher',count=10}; p.set_quick_bar_slot(1,1,'tc-recipe-searcher')
  p.game_view_settings.show_entity_info=true
  local x=f(); x.joined[p.index]=true
  if x.retained then
    assert(equal(registry.record(x.c).state.recipes,x.retained),'late join changed retained query data/order')
    x.late_join_retained=true
    log('TC_RECIPE_PEER_JOIN index='..p.index..' retained=true')
  else log('TC_RECIPE_PEER_JOIN index='..p.index..' retained=false') end
end
function M.on_load()
  loaded=true
  local x=f()
  if x.retained then
    assert(equal(registry.record(x.c).state.recipes,x.retained))
    log('TC_RECIPE_CLIENT_ON_LOAD_UNCHANGED')
  end
end
function M.on_configuration_changed() error('unexpected scene configuration change') end
function M.on_tick(event)
  local x=f(); local c=registry.record(x.c)
  if loaded then x.cold=x.retained~=nil; loaded=false end
  scheduler.tick(event.tick)
  assert(c.status=='running',serpent.line(c.diagnostic))
  if c.state.queries and x.phase=='boot' then
    local disabled=false
    for _,r in ipairs(c.state.recipes) do if r.name=='advanced-circuit' then assert(not r.enabled); disabled=true end end
    assert(disabled); game.forces.player.recipes['advanced-circuit'].enabled=true; x.phase='enabled'; x.before=c.state.queries
  elseif x.phase=='enabled' and c.state.queries>x.before then
    for _,r in ipairs(c.state.recipes) do if r.name=='advanced-circuit' then assert(r.enabled) end end
    x.retained=c.state.recipes; x.phase='ready'; x.saved_tick=event.tick
    game.server_save('tc-recipe-client-snapshot'); log('TC_RECIPE_CLIENT_READY saved-query-and-live-force-change')
  end
  if x.phase=='ready' then
    assert(equal(c.state.recipes,x.retained))
    if event.tick%30==0 then publish() end
    if event.tick==x.saved_tick+30 then log('TC_RECIPE_CLIENT_CAPTURE_READY') end
    if event.tick==x.saved_tick+60 then
      for i,id in ipairs(x.views) do
        game.take_screenshot{surface=game.surfaces[1],position=registry.record(id).body.position,resolution={512,512},zoom=4,
          show_gui=false,show_entity_info=true,force_render=true,path='recipe-view-'..i..'.png'}
      end
      game.take_screenshot{surface=game.surfaces[1],position={4,1},resolution={1280,720},zoom=1.5,
        show_gui=false,show_entity_info=true,force_render=true,path='recipe-family.png'}
      log('TC_RECIPE_CLIENT_SCREENSHOTS_REQUESTED')
    end
    if #game.connected_players>=2 and x.late_join_retained then
      publish()
      if not x.multiplayer_done then x.multiplayer_done=true; log('TC_RECIPE_MULTIPLAYER_OK connected-peers=2 matching-red-green-data-order-and-live-force') end
    end
  end
end
return M
