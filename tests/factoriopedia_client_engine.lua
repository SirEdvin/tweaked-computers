-- Actual client/peer scene. Native tooltips are test UI, not a production browser.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local defs=require('scripts.device-definitions')
local shell=require('scripts.runtime.shell')
local M={}
local function f() return storage.tc_fact_client end
local source=[[function start(e) computer.setState('boots',(computer.getState('boots') or 0)+1); computer.every(30,'query') end

function query(e)
  local a=peripheral.find('factoriopedia_interface','red'); local b=peripheral.find('factoriopedia_interface','green')
  assert(a and b)
  local i=a.getItem('tc-fp-fractional'); assert(i.weight==b.getItem('tc-fp-fractional').weight)
  computer.setState('item',i); computer.setState('fluid',a.getFluid('tc-fp-overlap'))
  computer.setState('items',a.listItems()); computer.setState('fluids',a.listFluids())
  computer.setState('queries',(computer.getState('queries') or 0)+1)
end]]
local function build(kind,x,y,d)
  local b=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},direction=d or 0,force='player'})
  lifecycle.on_built{entity=b}; return assert(registry.by_entity(b))
end
function M.run()
  storage.tc_fact_client={views={},start=game.tick}
  local x=f(); local surface=game.surfaces[1]; surface.always_day=true
  surface.request_to_generate_chunks({4,1},2); surface.force_generate_chunk_requests()
  for _,e in ipairs(surface.find_entities_filtered{area={{-16,-16},{24,16}},type={'tree','simple-entity','cliff'}}) do e.destroy() end
  local tiles={}; for y=-14,14 do for xx=-14,22 do tiles[#tiles+1]={name='refined-concrete',position={xx,y}} end end
  surface.set_tiles(tiles)
  if remote.interfaces.freeplay then remote.call('freeplay','set_skip_intro',true); remote.call('freeplay','set_disable_crashsite',true) end
  local c=build('computer',-4,0); x.c=c.id
  for i,d in ipairs({0,4,8,12}) do
    local s=build('factoriopedia_interface',(i-1)*4,0,d); x.views[i]=s.id
    build('factoriopedia_interface',(i-1)*4,5,d)
    for _,color in ipairs({'red','green'}) do
      local prior=i==1 and c or registry.record(x.views[i-1])
      assert(lifecycle.connector(prior,'network',color).connect_to(lifecycle.connector(s,'network',color)))
    end
  end
  build('recipe_searcher',-4,-4); build('kv',0,-4); build('configurator',4,-4)
  local supply=assert(surface.create_entity{name='electric-energy-interface',position={17,-7},force='player'})
  supply.power_production=100000000; supply.power_usage=0
  for _,p in ipairs({{-4,-7},{9,-7},{17,-7}}) do assert(surface.create_entity{name='substation',position=p,force='player'}) end
  assert(runtime.save(c.id,source,0)); assert(runtime.activate(c.id,game.tick))
end
function M.on_player_joined(event)
  local p=game.get_player(event.player_index)
  p.set_controller{type=defines.controllers.god}; p.teleport({4,1}); p.zoom=1.5
  local old=p.gui.screen.tc_fact_tooltips; if old then old.destroy() end
  local frame=p.gui.screen.add{type='frame',name='tc_fact_tooltips',direction='vertical',caption='Native metadata acceptance'}
  frame.location={40,40}
  for _,name in ipairs({'iron-plate','tc-fp-fractional','tc-fp-heavy'}) do
    frame.add{type='sprite-button',sprite='item/'..name,elem_tooltip={type='item',name=name}}
  end
  frame.add{type='sprite-button',sprite='fluid/tc-fp-overlap',elem_tooltip={type='fluid',name='tc-fp-overlap'}}
  frame.add{type='textfield',name='paste_name',text=''}
  log('TC_FACT_CLIENT_JOIN '..p.index)
  local x=f()
  if #game.connected_players>=2 and x.frozen and not x.late_join then
    assert(registry.record(x.c).state.item==x.frozen.item,'late join replaced retained snapshot')
    local c=registry.record(x.c); local old=registry.record(x.views[1]); local position=old.body.position
    assert(lifecycle.remove(old.id,'peer-fixture',true))
    local replacement=build('factoriopedia_interface',position.x,position.y)
    for _,color in ipairs({'red','green'}) do
      assert(lifecycle.connector(c,'network',color).connect_to(lifecycle.connector(replacement,'network',color)))
      assert(lifecycle.connector(replacement,'network',color).connect_to(lifecycle.connector(registry.record(x.views[2]),'network',color)))
    end
    assert(not replacement.children.power and lifecycle.available(replacement))
    x.old_identity=old.id; x.views[1]=replacement.id
    local ok,e=shell.evaluate(c,"local ok,e=pcall(captured,'tc-fp-fractional'); assert(not ok and e.code=='E_UNREACHABLE')",game.tick,2)
    assert(ok,serpent.line(e))
    x.late_join=true; x.resume_tick=game.tick; game.tick_paused=false
    log('TC_FACT_PEER_RESUMED synchronized-join-stale-identity-refused')
  elseif #game.connected_players>=2 and x.peer_done then
    local ok,e=shell.evaluate(registry.record(x.c),"local ok,e=pcall(captured,'tc-fp-fractional'); assert(not ok and e.code=='E_UNREACHABLE')",game.tick,3)
    assert(ok,serpent.line(e)); x.cold_stale=true
    log('TC_FACT_PEER_COLD_STALE_OK restored-captured-method-refused')
  end
end
function M.on_load() end
function M.on_configuration_changed() error('unexpected client fixture configuration change') end
function M.on_tick(event)
  scheduler.tick(event.tick)
  local x=f(); local c=registry.record(x.c)
  assert(c.status=='running',serpent.line(c.diagnostic))
  for _,p in pairs(game.connected_players) do
    local panel=p.gui.screen.tc_fact_tooltips
    if panel and panel.paste_name.text~='' and not x.copy_done then
      local found=false; for _,id in ipairs(x.views) do if panel.paste_name.text==id then found=true end end
      assert(found,'native Copy/paste did not preserve exact identity')
      x.copy_done=true; log('TC_FACT_NATIVE_COPY_OK '..panel.paste_name.text)
    end
  end
  if c.state.queries and event.tick%30==0 then
    local peers={}; for _,p in pairs(game.connected_players) do peers[#peers+1]=p.index end; table.sort(peers)
    local snapshot=helpers.table_to_json({tick=event.tick,item=c.state.item,fluid=c.state.fluid,items=c.state.items,fluids=c.state.fluids,queries=c.state.queries,
      boots=c.state.boots,old_identity=x.old_identity,current_identity=x.views[1],late_join=x.late_join,peer_done=x.peer_done,cold_stale=x.cold_stale or false,peers=peers})
    helpers.write_file('fact-server.json',snapshot,false,0)
    for _,p in pairs(game.connected_players) do helpers.write_file('fact-client.json',snapshot,false,p.index) end
    if not x.ready then x.ready=true; x.ready_tick=event.tick; log('TC_FACT_CLIENT_READY') end
    if game.is_multiplayer() and #game.connected_players==1 and not x.frozen then
      c.shell={version=1,id='factoriopedia-client-shell',pending={},pending_bytes=0}
      local ok,e=shell.evaluate(c,"s=peripheral.find('factoriopedia_interface','red'); captured=s.getItem",game.tick,1)
      assert(ok,serpent.line(e))
      x.frozen={item=c.state.item,fluid=c.state.fluid,items=c.state.items,fluids=c.state.fluids}
      game.tick_paused=true; log('TC_FACT_PEER_FROZEN retained-data-before-late-join')
    end
    if x.late_join and event.tick-x.resume_tick>=60 and not x.peer_done then
      assert(c.state.item.name==x.frozen.item.name and c.state.item.weight==x.frozen.item.weight)
      assert(c.state.fluid.default_temperature==x.frozen.fluid.default_temperature and #c.state.items==#x.frozen.items and #c.state.fluids==#x.frozen.fluids)
      x.peer_done=true; log('TC_FACT_MULTIPLAYER_OK joining-peer-snapshots-and-stale-identity')
    end
  end
  if x.ready and not x.captures and #game.connected_players>0 and event.tick-x.ready_tick>=60 then
    x.captures=true
    for i,id in ipairs(x.views) do
      game.take_screenshot{surface=game.surfaces[1],position=registry.record(id).body.position,resolution={512,512},zoom=4,
        show_gui=false,show_entity_info=true,force_render=true,path='fact-view-'..i..'.png'}
    end
    game.take_screenshot{surface=game.surfaces[1],position={4,1},resolution={1280,720},zoom=1.5,
      show_gui=false,show_entity_info=true,force_render=true,path='fact-family.png'}
    log('TC_FACT_CLIENT_SCREENSHOTS_REQUESTED')
  end
end
return M
