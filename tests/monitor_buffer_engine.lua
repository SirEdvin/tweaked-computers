-- Isolated native-backend feasibility probe, not the production buffered renderer.
-- Explicit 6x6 geometry bypasses the old grouping ceiling ONLY in this fixture.
local registry=require('scripts.registry')
local scheduler=require('scripts.scheduler')
local limits=require('scripts.runtime.limits')
local model=require('scripts.monitor-model')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local network=require('scripts.network')
local monitor=require('scripts.services.monitor')
local M={}; local loaded=false
local function f() return storage.tc_buffer_probe end
local function nop() end
local function walk(frame,fn)
  fn(frame.panel); fn(frame.cursor)
  for _,cell in ipairs(frame.cells) do fn(cell.background); fn(cell.glyph) end
end
local function object_count(x)
  local n=0
  for _,row in ipairs(x.frames) do n=n+4*#row.front.cells+4 end
  return n
end
local function commit_work(x) return object_count(x)*3+#x.frames*8 end
local function assert_visibility(x,old_visible,new_visible)
  for _,row in ipairs(x.frames) do
    assert(row.display.render==row.front or row.display.render==row.back)
    walk(row.front,function(o) assert(o.valid and o.visible==old_visible,'old native visibility changed') end)
    walk(row.back,function(o) assert(o.valid and o.visible==new_visible,'staged native visibility changed') end)
  end
end
-- Reserve native valid/visible reads and visibility writes before preflight.
-- No admission, object construction or guest code occurs after the first write.
local function publish(x,tick,spend)
  spend(commit_work(x))
  for _,row in ipairs(x.frames) do
    assert(row.display.render==row.front and #row.front.cells==#row.back.cells)
    walk(row.front,function(o) assert(o.valid and o.visible) end)
    walk(row.back,function(o) assert(o.valid and not o.visible) end)
  end
  for _,row in ipairs(x.frames) do
    walk(row.front,function(o) o.visible=false end)
    walk(row.back,function(o) o.visible=true end)
  end
  for _,row in ipairs(x.frames) do
    row.front.hidden=true; row.back.hidden=false
    row.back.presented_tick=tick; row.back.presented_revision=2
    row.display.render=row.back
  end
  x.presented_tick=tick; x.sequence=x.sequence+1
end
local function sprite(g,u,v,w,h,visible,tint,layer)
  local ax,ay=model.world(g,u,v); local bx,by=model.world(g,u+w,v+h)
  return rendering.draw_sprite{surface=g.surface_index,sprite='tc-monitor-fill',
    target={(ax+bx)/2,(ay+by)/2},x_scale=math.abs(bx-ax)*32,y_scale=math.abs(by-ay)*32,
    tint=tint,visible=visible,render_layer=layer}
end
local function begin_frame(g,visible)
  local cw,ch,ox,oy=model.geometry(g)
  return {cells={},hidden=not visible,
    panel=sprite(g,2/64,2/64,6-4/64,6-4/64,visible,{0,0,0,1},'higher-object-under'),
    cursor=sprite(g,ox,oy+ch-g.model.scale/64,cw,g.model.scale/64,visible,{1,1,1,1},'item-in-inserter-hand')}
end
local function make_cell(g,i,visible)
  local m=g.model; local cw,ch,ox,oy=model.geometry(g)
  local x,y=(i-1)%m.width,math.floor((i-1)/m.width)
  local wx,wy=model.world(g,ox+(x+0.5)*cw,oy+(y+0.5)*ch)
  return {
    background=sprite(g,ox+x*cw,oy+y*ch,cw,ch,visible,
      visible and {0.05,0.15,0.5,1} or {0.35,0.05,0.05,1},'higher-object-above'),
    glyph=rendering.draw_sprite{surface=g.surface_index,sprite=visible and 'tc-glyph-88' or 'tc-glyph-79',
      target={wx,wy},x_scale=m.scale/2,y_scale=m.scale/2,orientation=g.direction/16,
      tint={0.8,1,0.3,1},visible=visible,render_layer='train-stop-top'}}
end
local function stage(x,key,visible,spend)
  local remaining=model.limits.render_cells_per_tick
  while x.member<=#x.frames and remaining>0 do
    local row=x.frames[x.member]; local g=row.display
    if not row[key] then
      spend(16); row[key]=begin_frame(g,visible); row[key].cursor.blink_interval=30
    end
    local frame=row[key]; local total=g.model.width*g.model.height
    while x.cell<=total and remaining>0 do
      spend(48); frame.cells[x.cell]=make_cell(g,x.cell,visible)
      assert(frame.cells[x.cell].background.visible==visible and frame.cells[x.cell].glyph.visible==visible)
      if key=='back' then
        local old=row.front.cells[x.cell]
        assert(old.background.visible and old.glyph.visible,'preparation erased the front image')
        assert(row.display.render==row.front and not row.back.presented_tick)
      end
      x.cell=x.cell+1; remaining=remaining-1; x.prepared=x.prepared+1
    end
    if x.cell>total then
      if key=='front' then row.display.render=frame end
      x.member=x.member+1; x.cell=1
    end
  end
  x.max_batch=math.max(x.max_batch,model.limits.render_cells_per_tick-remaining)
  if x.member>#x.frames then x.member=1; x.cell=1; return true end
  return false
end
local function start_case(x)
  x.frames={}; x.member=1; x.cell=1; x.prepared=0; x.max_batch=0
  x.sequence=0; x.presented_tick=nil
  local count=x.case==1 and 1 or 4
  local scale=x.case==1 and 0.5 or 1
  local cells=0
  for i=1,count do
    local m=model.new(6,6); model.scale(m,6,6,nop,scale)
    cells=cells+m.width*m.height
    local g={model=m,left=(i-1)*8,top=0,world_width=6,world_height=6,
      width_tiles=6,height_tiles=6,direction=(i-1)*4,surface_index=1}
    x.frames[i]={display=g}
  end
  assert(cells==10584); x.cells=cells; x.phase='bootstrap'
end
local function cleanup(x,spend)
  local remaining=model.limits.render_cells_per_tick
  while x.cleanup_generation<=2 and remaining>0 do
    local key=x.cleanup_generation==1 and 'front' or 'back'
    local row=x.frames[x.member]; local frame=row[key]
    while x.cell<=#frame.cells and remaining>0 do
      spend(8)
      local cell=frame.cells[x.cell]; cell.background.destroy(); cell.glyph.destroy()
      x.cell=x.cell+1; remaining=remaining-1
    end
    if x.cell>#frame.cells then
      spend(8); frame.panel.destroy(); frame.cursor.destroy()
      x.member=x.member+1; x.cell=1
      if x.member>#x.frames then x.member=1; x.cleanup_generation=x.cleanup_generation+1 end
    end
  end
  return x.cleanup_generation>2
end
local function refusal(x,tick)
  local root=registry.get(); local spend=scheduler.maintenance(root,tick,true)
  local work=commit_work(x)
  spend(limits.maintenance_work_per_tick-work+1)
  local before=root.scheduler.maintenance_spent
  for _=1,2 do
    assert(not scheduler.try_maintenance(function() publish(x,tick,spend) end),'one-unit-short commit succeeded')
    assert(root.scheduler.maintenance_spent==before and x.sequence==0 and not x.presented_tick)
    assert_visibility(x,true,false)
  end
  x.refused_tick=tick; x.refused_spent=before
  log('TC_BUFFER_REFUSAL case='..x.case..' work='..work..' retained='..before)
end
-- Trusted setup/teardown is outside CPU/admission measurements. The 256 real
-- vertices exist and are validated within one event, avoiding duplicate native
-- ownership between the production mod and this isolated fixture mod.
local function physical_paths()
  local nodes={}
  for i=1,limits.network_nodes do
    local y=math.floor((i-1)/16); local x=(i-1)%16
    if y%2==1 then x=15-x end
    local kind=i==1 and 'computer' or 'monitor'
    local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,
      position={x*3-24,y*3-24},force='player'})
    nodes[i]=assert(lifecycle.build(body))
    if i>1 then
      assert(lifecycle.connector(nodes[i-1],'network','red').connect_to(lifecycle.connector(nodes[i],'network','red')))
    end
  end
  local discovery_work=0
  local members,parents=network.discover(nodes[1],'red',function(n) discovery_work=discovery_work+n end)
  assert(#members==limits.network_nodes-1)
  local paths={}
  for i=#nodes-3,#nodes do paths[#paths+1]=network.witness(nodes[1],nodes[i],parents,nop) end
  assert(#paths[4]==limits.network_nodes)
  return nodes,paths,discovery_work
end
local function teardown_paths(nodes)
  for i=#nodes,1,-1 do assert(lifecycle.remove(nodes[i].id,'buffer-probe-teardown',true)) end
  assert(#registry.get().order==0)
end
function M.run()
  registry.initialize()
  storage.tc_buffer_probe={case=1,phase='armed',baseline_objects=#rendering.get_all_objects()}
  start_case(f())
end
function M.on_load() loaded=true end
function M.on_tick(event)
  local x=f()
  if x.phase=='done' then return end
  if x.phase=='frozen' then
    if not loaded then return end
    local root=registry.get()
    assert(root.scheduler.maintenance_tick==x.refused_tick and root.scheduler.maintenance_spent==x.refused_spent)
    local old=scheduler.maintenance(root,x.refused_tick,true)
    assert(not scheduler.try_maintenance(function() publish(x,x.refused_tick,old) end))
    assert_visibility(x,true,false)
    log('TC_BUFFER_COLD_RETAINED')
    x.phase='commit'; loaded=false
  end
  local spend=scheduler.maintenance(registry.get(),event.tick,true)
  if x.phase=='bootstrap' then
    if stage(x,'front',true,spend) then x.phase='prepare' end
  elseif x.phase=='prepare' then
    if stage(x,'back',false,spend) then x.phase='refuse' end
  elseif x.phase=='refuse' then
    refusal(x,event.tick)
    if x.case==1 then
      x.phase='frozen'; loaded=false
      game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
    else x.phase='commit' end
  elseif x.phase=='commit' then
    local nodes,paths,discovery_work
    if x.case==2 then nodes,paths,discovery_work=physical_paths() end
    local before=registry.get().scheduler.maintenance_spent
    local profiler=game.create_profiler()
    local proof_work=0
    if paths then
      for _,path in ipairs(paths) do
        assert(network.validate_witness(nodes[1],'red',path,function(n) spend(n); proof_work=proof_work+n end))
      end
    end
    publish(x,event.tick,spend)
    profiler.stop()
    log({'','TC_BUFFER_CPU case=',x.case,' ',profiler})
    assert(registry.get().scheduler.maintenance_spent-before==commit_work(x)+proof_work)
    assert(x.max_batch<=1024 and x.sequence==1 and x.presented_tick==event.tick)
    assert_visibility(x,false,true)
    for _,row in ipairs(x.frames) do assert(row.display.render==row.back and row.back.presented_tick==event.tick) end
    local objects=object_count(x)
    assert(#rendering.get_all_objects()-x.baseline_objects==objects)
    log('TC_BUFFER_PRESENT case='..x.case..' tick='..event.tick..' cells='..x.cells..
      ' objects='..objects..' work='..commit_work(x)..' max_batch='..x.max_batch)
    if paths then
      local lengths={}; for _,path in ipairs(paths) do lengths[#lengths+1]=tostring(#path) end
      log('TC_BUFFER_PATHS lengths='..table.concat(lengths,',')..' discovery_work='..discovery_work..' witness_work='..proof_work)
      local root=registry.get(); local after_commit=root.scheduler.maintenance_spent
      local maintenance_profiler=game.create_profiler()
      local advanced=scheduler.try_maintenance(function() monitor.reconcile(event.tick,spend) end)
      maintenance_profiler.stop()
      log({'','TC_BUFFER_TOPOLOGY_CPU ',maintenance_profiler})
      x.reservation_probe={commit_and_proof=after_commit-before,
        non_render_headroom=limits.maintenance_work_per_tick-after_commit,
        topology_spent=root.scheduler.maintenance_spent-after_commit,
        topology_completed=advanced,job_created=root.monitors and root.monitors.job~=nil or false}
      log('TC_BUFFER_RESERVATION commit_and_proof='..x.reservation_probe.commit_and_proof..
        ' non_render_headroom='..x.reservation_probe.non_render_headroom..
        ' topology_spent='..x.reservation_probe.topology_spent..
        ' topology_completed='..tostring(advanced)..' job_created='..tostring(x.reservation_probe.job_created))
      if not advanced then log('TC_BUFFER_TOPOLOGY_DEFERRED incremental-initialization-progress-retained') end
      teardown_paths(nodes)
    end
    x.phase='cleanup'; x.cleanup_generation=1; x.member=1; x.cell=1
  elseif x.phase=='cleanup' then
    if cleanup(x,spend) then
      assert(#rendering.get_all_objects()==x.baseline_objects,'probe leaked native objects')
      if x.case==1 then x.case=2; start_case(x)
      else x.phase='done'; log('TC_BUFFER_BACKEND_OK'); log('TC_COLD_OK') end
    end
  end
end
-- Trusted fixture reuse; these functions are never installed as guest services.
M.native={start=start_case,stage=stage,publish=publish,work=commit_work,visibility=assert_visibility}
return M
