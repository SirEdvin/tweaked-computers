-- Native rendered acceptance scene, sharing the real scheduler and guest quotas.
-- The source is deliberately a dense whole-image producer, not a FPS benchmark.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local runtime=require('scripts.runtime.computer')
local monitor=require('scripts.services.monitor')
local model=require('scripts.monitor-model')
local defs=require('scripts.device-definitions')
local config=require('tests.acceptance_monitor_config')
local M={}
local function state() return storage.tc_monitor_acceptance end
local function build(kind,x,y,d)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},direction=d or 0,force='player'})
  return assert(lifecycle.build(body))
end
local function wire(a,b)
  assert(lifecycle.connector(a,'network','red').connect_to(lifecycle.connector(b,'network','red')))
end
local function configure(p)
  p.set_controller{type=defines.controllers.god}; p.teleport({15,5}); p.zoom=0.8
  p.game_view_settings.show_entity_info=true
  p.game_view_settings.show_minimap=false; p.game_view_settings.show_side_menu=false
  p.game_view_settings.show_research_info=false
  p.game_view_settings.show_entity_tooltip=false
  p.game_view_settings.show_quickbar=false; p.game_view_settings.show_shortcut_bar=false
end
local source=[[return {api_version=1,handlers={
start=function(e)
  computer.setState('starts',(computer.getState('starts') or 0)+1)
  computer.on('monitor_touch','touch')
  computer.every(120,'draw'); computer.after(1,'draw')
end,
touch=function(e)
  computer.setState('touch',{player=e.player_index,x=e.x,y=e.y,name=e.peripheral})
  computer.setState('touches',(computer.getState('touches') or 0)+1)
end,
draw=function(e)
  if computer.getState('draw_refs') then return end
  if (computer.getState('frame') or 0)>=6 and e.name~='test_paint' then return end
  local refs={}
  for _,name in ipairs(peripheral.getNames('red')) do refs[#refs+1]={name=name,wire='red'} end
  if #refs>1 then peripheral.setMonitorSyncGroup(refs) end
  local n=(computer.getState('frame') or 0)+1; computer.setState('frame',n)
  computer.setState('draw_refs',refs)
  computer.setState('draw_scale',MAXIMUM and 0.5 or (n>2 and n%2==1 and 1.5 or 1))
  -- Scale changes reset the whole round; repaint its last participant first.
  computer.setState('resize_cursor',1); computer.setState('paint_cursor',#refs)
  computer.after(1,'resize')
end,
resize=function(e)
  local refs=computer.getState('draw_refs'); local i=computer.getState('resize_cursor')
  local ref=refs[i]
  if ref then
    local m=peripheral.wrap(ref.name,ref.wire); local desired=computer.getState('draw_scale')
    if m.getTextScale()~=desired then m.setTextScale(desired) end
    computer.setState('resize_cursor',i+1); computer.after(1,'resize')
  else computer.after(1,'paint') end
end,
paint=function(e)
  local refs=computer.getState('draw_refs'); local i=computer.getState('paint_cursor')
  local ref=refs[i]; local n=computer.getState('frame')
  local m=peripheral.wrap(ref.name,ref.wire)
  local w,h=m.getSize(); local ink=n%2==1 and 'A' or 'B'
  m.setPaletteColor(colors.blue,n%2==1 and 0.05 or 0.8,0.1,n%2==1 and 0.8 or 0.05)
  m.setBackgroundColor(colors.blue); m.setTextColor(colors.white); m.clear()
  for y=1,h do m.setCursorPos(1,y); m.write(string.rep(ink,w)) end
  m.setCursorPos(math.max(1,w-1),h); m.setCursorBlink(true)
  if i>1 then computer.setState('paint_cursor',i-1); computer.after(1,'paint')
  else
    computer.deleteState('draw_refs'); computer.deleteState('draw_scale')
    computer.deleteState('resize_cursor'); computer.deleteState('paint_cursor')
  end
end}}]]
function M.run()
  if remote.interfaces.freeplay then remote.call('freeplay','set_skip_intro',true); remote.call('freeplay','set_disable_crashsite',true) end
  local surface=game.surfaces[1]
  surface.request_to_generate_chunks({15,5},3); surface.force_generate_chunk_requests()
  for _,e in pairs(surface.find_entities_filtered{area={{-12,-12},{44,26}}}) do e.destroy() end
  local tiles={}; for y=-12,25 do for x=-12,43 do tiles[#tiles+1]={name='refined-concrete',position={x,y}} end end
  surface.set_tiles(tiles); surface.always_day=true
  game.map_settings.enemy_expansion.enabled=false; game.map_settings.pollution.enabled=false
  local x={steps=0,computers={},walls={},observed={}}; storage.tc_monitor_acceptance=x
  local c=build('computer',-3,0); x.computers[1]=c.id
  local shapes=config.layout=='four-walls' and {{6,6},{6,6},{6,6},{6,6}} or {{1,1},{3,6},{6,3},{6,6}}
  local previous=c
  for i,shape in ipairs(shapes) do
    local wall={}; x.walls[i]=wall
    local xx=(i-1)*10
    for yy=0,shape[2]-1 do for col=0,shape[1]-1 do wall[#wall+1]=build('monitor',xx+col,yy,config.layout=='four-walls' and (i-1)*4 or 0).id end end
    local first=registry.record(wall[1]); wire(previous,first)
    local last=registry.record(wall[shape[1]]); if first~=last then wire(first,last) end
    previous=last
    if i==1 and config.layout~='four-walls' or i==2 or i==3 then local bridge=build('computer',xx+6,0); wire(previous,bridge); previous=bridge end
    rendering.draw_text{text=shape[1]..'x'..shape[2],surface=surface,target={xx+shape[1]/2,-1},color={1,1,1},alignment='center'}
  end
  local large=build('computer',-3,12); x.computers[2]=large.id; local wall={}; x.walls[5]=wall
  for yy=12,17 do for xx=0,5 do wall[#wall+1]=build('monitor',xx,yy).id end end
  wire(large,registry.record(wall[1]))
  rendering.draw_text{text='6x6 scale 0.5 / 10584 cells',surface=surface,target={3,11},color={1,1,1},alignment='center'}
  local supply=assert(surface.create_entity{name='electric-energy-interface',position={-5,8},force='player'})
  supply.power_production=1000000000; supply.power_usage=0
  x.supply=supply
  for _,pos in ipairs({{-4,7},{10,7},{24,7},{38,7},{-4,20},{8,20}}) do surface.create_entity{name='substation',position=pos,force='player'} end
  local cohort_source=source:gsub('MAXIMUM','false'); local maximum_source=source:gsub('MAXIMUM','true')
  x.sources={cohort_source,maximum_source}
  x.phase='boot'
end
function M.on_player_joined(event)
  local player=game.get_player(event.player_index); configure(player)
  if not player.gui.top.tc_monitor_acceptance then
    local bar=player.gui.top.add{type='flow',name='tc_monitor_acceptance',direction='horizontal'}
    for _,name in ipairs({'paint','overview','maximum'}) do bar.add{type='button',name=name,caption=name} end
  end
end
local real_click=script.get_event_handler(defines.events.on_gui_click)
script.on_event(defines.events.on_gui_click,function(event)
  local player=game.get_player(event.player_index); local e=event.element
  if not player or not e or not e.valid or e.parent~=player.gui.top.tc_monitor_acceptance then return real_click(event) end
  if e.name=='overview' then configure(player)
  elseif e.name=='maximum' then player.teleport({3,15}); player.zoom=2
  elseif e.name=='paint' then
    local ok=scheduler.try_maintenance(function()
      local spend=scheduler.maintenance(registry.get(),event.tick)
      for _,id in ipairs(state().computers) do assert(runtime.enqueue(registry.computer(id),'draw',{name='test_paint'},event.tick,spend)) end
    end)
    log('TC_ACCEPTANCE_PAINT_REQUEST player='..player.index..' admitted='..tostring(ok))
  end
end)
function M.on_load() end
function M.on_configuration_changed() error('unexpected monitor scene configuration change') end
function M.on_tick(event)
  local x=state(); scheduler.tick(event.tick); x.steps=x.steps+1
  if x.phase=='boot' and x.steps>=10 and not registry.get().monitors.job then
    for i,id in ipairs(x.computers) do local c=registry.computer(id); assert(runtime.save(id,x.sources[i],0)); assert(runtime.activate(id,event.tick)) end
    x.phase='running'; log('TC_ACCEPTANCE_MONITORS_STARTED')
  elseif x.phase=='running' then
    for _,id in ipairs(x.computers) do local c=registry.computer(id); assert(c.status=='running',serpent.line(c.diagnostic)) end
    for i,wall in ipairs(x.walls) do
      local g=assert(monitor.resolve(registry.record(wall[1]))); local r=g.render
      if r and r.presented_revision~=x.observed[i] then
        local mark=r.snapshot.cells[1][1]
        if mark==65 or mark==66 then
          for _,cell in ipairs(r.snapshot.cells) do assert(cell[1]==mark,'mixed dense frame') end
          x.observed[i]=r.presented_revision
          log('TC_ACCEPTANCE_VISIBLE wall='..i..' step='..x.steps..' glyph='..mark..' cells='..#r.snapshot.cells)
        end
      end
    end
    local quiescent=true
    for _,id in ipairs(x.computers) do local c=registry.computer(id)
      if (c.state.frame or 0)<5 or c.state.draw_refs then quiescent=false end
    end
    local function public_image(m)
      return helpers.table_to_json{width=m.width,height=m.height,scale=m.scale,x=m.x,y=m.y,
        blink=m.blink,fg=m.fg,bg=m.bg,palette=m.palette,cells=m.cells}
    end
    if not x.power_cut and x.steps>=500 and quiescent then
      x.power_cut=x.steps
      x.outage_models={}
      for i,wall in ipairs(x.walls) do x.outage_models[i]=public_image(monitor.resolve(registry.record(wall[1])).model) end
      x.supply.power_production=0; x.supply.energy=0
      log('TC_ACCEPTANCE_NATIVE_POWER_CUT step='..x.steps)
    elseif x.power_cut and x.steps==x.power_cut+40 then
      for i,wall in ipairs(x.walls) do assert(public_image(monitor.resolve(registry.record(wall[1])).model)==x.outage_models[i],'power changed public image') end
      x.supply.power_production=1000000000
      log('TC_ACCEPTANCE_NATIVE_POWER_RESTORED step='..x.steps)
    end
    if x.steps==180 or x.steps==300 or x.steps==420 or x.steps==520 or x.steps==580 then
      game.take_screenshot{surface=game.surfaces[1],position={15,5},resolution={1280,720},zoom=0.8,show_gui=false,force_render=true,path='dense-'..x.steps..'.png'}
      game.take_screenshot{surface=game.surfaces[1],position={3,15},resolution={1024,1024},zoom=3,show_gui=false,force_render=true,path='maximum-'..x.steps..'.png'}
      log('TC_ACCEPTANCE_MONITOR_CAPTURE step='..x.steps)
    end
    if x.steps==config.ticks then
      for i=1,5 do
        assert(x.observed[i],'no dense publication wall '..i)
        local r=monitor.resolve(registry.record(x.walls[i][1])).render
        assert(r and r.snapshot.cells[1][1]==66,'final dense B frame missing wall '..i)
      end
      log('TC_ACCEPTANCE_MONITORS_DONE steps='..x.steps..' walls=5')
    end
    if event.tick%15==0 then
      local view={tick=game.tick,computers={},walls={},peers={}}
      for _,p in pairs(game.connected_players) do view.peers[#view.peers+1]=p.index end; table.sort(view.peers)
      for _,id in ipairs(x.computers) do local c=registry.computer(id)
        local selection=c.monitor_sync; local lane=selection and registry.get().monitors.presentation.lanes[selection.key]
        view.computers[#view.computers+1]={id=id,state=c.state,run=c.run_id,
          sequence=lane and lane.presented_sequence,presented_tick=lane and lane.presented_tick}
      end
      for _,wall in ipairs(x.walls) do local g=monitor.resolve(registry.record(wall[1])); local r=g and g.render
        local marked=0; for _,id in ipairs(wall) do if registry.record(id).body.to_be_deconstructed('player') then marked=marked+1 end end
        view.walls[#view.walls+1]={id=g.id,width=g.model.width,height=g.model.height,
          left=g.left,top=g.top,direction=g.direction,world_width=g.world_width,world_height=g.world_height,
          width_tiles=g.width_tiles,height_tiles=g.height_tiles,scale=g.model.scale,marked=marked,
          presented_tick=r and r.presented_tick,sequence=r and r.presented_sequence,
          cells=r and r.snapshot.cells,palette=r and r.snapshot.palette}
      end
      helpers.write_file('acceptance-monitor-world.json',helpers.table_to_json(view),false,0)
      for _,p in pairs(game.connected_players) do helpers.write_file('acceptance-monitor-world.json',helpers.table_to_json(view),false,p.index) end
    end
  end
end
return M
