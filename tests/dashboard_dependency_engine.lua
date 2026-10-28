-- Exact-release feasibility only; no Dashboard implementation acceptance.
local charts
if script.active_mods['factorio-charts'] then charts=require('__factorio-charts__/charts') end
local M={}; local resumed=false
local function destroy(objects)
  for _,object in ipairs(objects) do assert(object.valid); object.destroy(); assert(not object.valid) end
end
function M.run()
  storage.tc_dashboard_dependency={phase='probe'}
end
function M.on_load() resumed=storage.tc_dashboard_dependency.phase=='frozen' end
function M.on_configuration_changed() error('unexpected dependency configuration change') end
function M.on_tick()
  local x=storage.tc_dashboard_dependency
  if x.phase=='done' then return end
  if x.phase=='deleting' then
    assert(not x.surface.surface.valid,'private surface survived queued deletion')
    x.phase='done'; log('TC_COLD_OK'); return
  end
  if x.phase=='frozen' then
    if not resumed then return end
    if charts then
      for _,object in ipairs(x.lines) do assert(object.valid and object.time_to_live==0,'stationary line expired') end
      for _,object in ipairs(x.bars) do assert(object.valid and object.time_to_live==0,'stationary bar expired') end
      destroy(x.lines); destroy(x.bars)
      local coord=x.chunk.coord
      charts.surface.free_chunk(x.surface,x.chunk)
      for _,light in ipairs(x.chunk.light_ids) do assert(not light.valid) end
      local reused=charts.surface.allocate_chunk(x.surface)
      assert(reused.coord.x==coord.x and reused.coord.y==coord.y,'chunk not reused')
      charts.surface.free_chunk(x.surface,reused)
      assert(game.delete_surface(x.surface.surface)); x.phase='deleting'
      log('TC_DASHBOARD_DEPENDENCY cold-stationary-cleanup-reuse')
      return
    else log('TC_DASHBOARD_DEPENDENCY absent-no-import-cold') end
    x.phase='done'; log('TC_COLD_OK'); return
  end
  if charts then
    assert(script.active_mods['factorio-charts']=='1.2.0')
    x.surface=charts.surface.create('tc-dashboard-dependency')
    log('TC_DASHBOARD_DEPENDENCY surface-created')
    x.chunk=charts.surface.allocate_chunk(x.surface)
    assert(#x.chunk.light_ids==9)
    for _,size in ipairs({{900,700},{450,350},{640,360}}) do
      local camera=charts.surface.get_camera_params(x.chunk,{widget_width=size[1],widget_height=size[2]})
      assert(camera.zoom>0 and 900*camera.zoom<=size[1] and 700*camera.zoom<=size[2])
    end
    local intervals=charts.time_series.create{{name='samples',ticks=1,length=3}}
    for i=1,5 do charts.time_series.add_datapoint(intervals,{a=i,b=i*2}) end
    local ring=intervals[1]; assert(ring.index==2 and ring.sum.a==12 and ring.counts.a==3)
    local ordered
    ordered,x.lines=charts.render.line_graph(x.surface.surface,x.chunk,{data=ring.data,index=ring.index,
      length=ring.length,sum=ring.sum,counts=ring.counts,label_format=tostring,ttl=0})
    assert(#ordered==2 and ordered[1].name=='b' and #x.lines>10)
    x.bars=charts.render.stacked_bars(x.surface.surface,x.chunk,{deliveries={{work=1,wait=2},{work=3,wait=1}},
      phase_order={'work','wait'},phase_colors={work=charts.colors.get_series_color(1),wait=charts.colors.get_series_color(2)},ttl=0})
    assert(#x.bars==14)
    log('TC_DASHBOARD_DEPENDENCY native-lines-duration-bars-camera')
  else log('TC_DASHBOARD_DEPENDENCY absent-no-import') end
  x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
end
return M
