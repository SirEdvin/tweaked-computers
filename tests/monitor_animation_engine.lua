-- Actual production ticks and exact packaged guest source. Publication cadence
-- is not client FPS; native GUI delivery/rendering remains user-owned validation.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local monitor=require('scripts.services.monitor')
local model=require('scripts.monitor-model')
local editor=require('scripts.ui.editor-model')
local defs=require('scripts.device-definitions')
local limits=require('scripts.runtime.limits')
local compiler=require('scripts.runtime.compiler')
local source=require('tests.monitor_animation_source') -- Test-only archive wrapper.
local layout=require('tests.monitor_animation_layout')
local contention
if pcall(require,'tests.peripheral_inspector_contention_config') then
  contention=require('tests.peripheral_inspector_contention_observer')
end
local M={}; local loaded=false
local function f() return storage.tc_animation end
local compile=compiler.compile
compiler.compile=function(...)
  local x=f(); local measured=x and x.steps>0 and x.steps%60==0
  local profiler=measured and helpers.create_profiler()
  local result,problem=compile(...)
  if profiler then profiler.stop(); log({'','TC_ANIMATION_COMPILER ',profiler}) end
  if problem then return result,problem end
  return result
end
local function nop() end
local function build(kind,x,y,d)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},direction=d or 0,force='player'})
  local r=assert(lifecycle.build(body)); lifecycle.power_entity(r).energy=100000; r.powered=true; return r
end
local function wire(a,b,color)
  assert(lifecycle.connector(a,'network',color).connect_to(lifecycle.connector(b,'network',color)))
end
local function oracle(m,phase,r)
  -- Independent pixel oracle: decode the terminal glyph/color pair instead of
  -- repeating the guest's sparse cell-mask encoder or trusting its row cache.
  local w,h=m.width,m.height; local pw,ph=w*2,(h-1)*3; local heights={}
  for x=1,pw do
    heights[x]=1+math.floor((1-math.sin(phase+(x-1)*2*math.pi/(pw-1)))*(ph-3)/2+0.5)
  end
  local function curve(x,y)
    local a,b=heights[x+1],heights[math.max(1,x)]
    return y>=math.min(a,b) and y<=math.max(a,b)
  end
  local title=(' SINE / LIVE'..string.rep(' ',w)):sub(1,w)
  for y=1,h do for x=1,w do
    local i=(y-1)*w+x; local c=m.cells[i]
    if y==1 then
      assert(c[1]==title:byte(x) and c[2]==0 and c[3]==15,'mixed/incomplete chart title')
    else
      assert(c[1]==32 or c[1]>=128 and c[1]<=159,'chart must use subpixel blocks, not dot/text markers')
      local px,py=(x-1)*2,(y-2)*3; local has_curve=false
      for dy=0,2 do for dx=0,1 do if curve(px+dx,py+dy) then has_curve=true end end end
      for dy=0,2 do for dx=0,1 do
        local bit=dy*2+dx
        local ink=c[1]~=32 and bit<5 and math.floor((c[1]-128)/2^bit)%2==1
        local actual=ink and c[2] or c[3]
        local expected=curve(px+dx,py+dy) and 5 or not has_curve and py+dy==math.floor(ph/2) and 7 or 15
        assert(actual==expected,'mixed/incomplete subpixel chart')
      end end
    end
    if r then
      local cell=r.cells[i]
      assert(cell.value[1]==c[1] and cell.value[2]==c[2] and cell.value[3]==c[3])
      assert(cell.background.valid and cell.background.visible)
      if c[1]~=32 then assert(cell.glyph and cell.glyph.valid and cell.glyph.visible and cell.glyph.sprite=='tc-glyph-'..c[1]) end
    end
  end end
end
function M.run()
  local x={phase='drawing',steps=0,walls={},records={},intervals={},max_gap=0,publications=0,peak_work=0,peak_allocations=0}
  storage.tc_animation=x
  local c=build('computer',-3,0); x.computer=c.id
  local shapes=layout=='mixed' and {{6,6},{3,6},{3,6},{1,1}} or {{6,6},{6,6},{6,6},{6,6}}
  for n,shape in ipairs(shapes) do
    local wall={}; x.walls[n]=wall
    for y=0,shape[2]-1 do for col=0,shape[1]-1 do wall[#wall+1]=build('monitor',(n-1)*10+col,y,(n-1)*4).id end end
  end
  local bridges={build('computer',16,0),build('computer',26,0)}
  for _,color in ipairs({'red','green'}) do
    local previous=c
    for n,wall in ipairs(x.walls) do
      local first,last=registry.record(wall[1]),registry.record(wall[shapes[n][1]])
      wire(previous,first,color); if first~=last then wire(first,last,color) end; previous=last
      if n==2 or n==3 then wire(previous,bridges[n-1],color); previous=bridges[n-1] end
    end
  end
  for _=1,200 do monitor.reconcile(game.tick,nop); if not registry.get().monitors.job then break end end
  assert(not registry.get().monitors.job and #registry.get().monitors.order==4)
  local player={valid=true,index=1,force=c.body.force,surface=c.body.surface,can_reach_entity=function(body) return body==c.body end}
  local session=editor.open(player,c.id); editor.edit(player,session.token,source)
  local valid,why=editor.action(player,session.token,'validate',game.tick); assert(valid,serpent.line(why))
  assert(editor.action(player,session.token,'save',game.tick))
  local started,problem=editor.action(player,session.token,'run',game.tick); assert(started,serpent.line(problem))
end
function M.on_load()
  loaded=true
  local x=f()
  if x.phase=='frozen' then
    local root=registry.get(); local c=registry.computer(x.computer)
    assert(c.state.smooth_chart==x.saved.chart and c.run_id==x.saved.run)
    assert(root.monitors.presentation==x.saved.presentation and root.ledger.total==x.saved.total)
    assert(root.scheduler.maintenance_spent==x.saved.maintenance)
    log('TC_ANIMATION_COLD_UNCHANGED')
  end
end
function M.on_configuration_changed() error('unexpected configuration change') end
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  local root=registry.get(); local c=registry.computer(x.computer)
  if x.phase=='frozen' then
    if not loaded then return end
    -- The harness deliberately stops scheduling while the snapshot is written.
    -- Measure uninterrupted windows, not artificial paused/save boundary ticks.
    loaded=false; x.phase='drawing'; x.resumed=true; x.last_sample=nil
  end
  for _,id in ipairs(root.order) do
    local r=registry.record(id); if r and r.body.valid then lifecycle.power_entity(r).energy=id==x.outage and 0 or 100000 end
  end
  if contention then contention.begin(event.tick) end
  local profiler=helpers.create_profiler()
  scheduler.tick(event.tick)
  profiler.stop()
  if contention then contention.finish() end
  x.steps=x.steps+1; assert(x.steps<2200,'animation fixture deadline')
  if x.phase=='drawing' and x.steps>=64 then log({'','TC_ANIMATION_CPU tick=',event.tick,' ',profiler}) end
  assert(c.status=='running',serpent.line(c.diagnostic))
  local machine=root.ledger.machines[c.id]
  if machine then
    x.peak_work=math.max(x.peak_work,machine.work); x.peak_allocations=math.max(x.peak_allocations,machine.allocations)
    assert(machine.work<=limits.callback_work and machine.allocations<=limits.callback_allocations)
  end
  local s=root.monitors; local p=s.presentation
  if p then
    assert(p.staging_cells<=model.limits.render_staging_cells and p.retired_cells<=model.limits.render_retired_cells)
    assert(#rendering.get_all_objects()<=model.limits.render_object_limit)
  end
  local chart=c.state.smooth_chart
  if chart then for _,v in ipairs(chart.views or {}) do
    local g=s.groups[v.name]
    if g and v.phase and not x.outage then
      oracle(g.model,v.phase)
      x.records[v.name]=x.records[v.name] or {}; x.records[v.name][g.model.revision]=v.phase
    end
  end end
  local selection=c.monitor_sync; local lane=selection and p and p.lanes[selection.key]
  if lane and lane.presented_sequence>0 and lane.presented_tick~=x.last_publication then
    local phase; local complete=true
    for _,ref in ipairs(lane.members) do
      local r=s.groups[ref.name].render
      local value=r and x.records[ref.name] and x.records[ref.name][r.snapshot.revision]
      if not value then complete=false; break end
      if phase then assert(value==phase,'selected monitors published different phases') end
      phase=value; oracle(r.snapshot,phase,r)
      assert(r.presented_tick==lane.presented_tick and r.presented_sequence==lane.presented_sequence)
    end
    if complete and #lane.members==4 and x.phase=='drawing' and x.steps>=64 then
      x.publications=x.publications+1
      if x.last_sample then
        local gap=lane.presented_tick-x.last_sample
        if gap>2 then log('TC_ANIMATION_GAP tick='..lane.presented_tick..' previous='..x.last_sample..' gap='..gap) end
        x.intervals[#x.intervals+1]=gap; x.max_gap=math.max(x.max_gap,gap)
      end
      x.last_sample=lane.presented_tick
      if x.publications%30==0 then log({'','TC_ANIMATION_SCHEDULER ',profiler}) end
    end
    x.last_publication=lane.presented_tick
  end
  if not x.saved and #x.intervals>=30 then
    x.saved={chart=chart,run=c.run_id,presentation=p,total=root.ledger.total,maintenance=root.scheduler.maintenance_spent}
    x.phase='frozen'; loaded=false; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif x.phase=='drawing' and x.resumed and #x.intervals>=360 then
    log('TC_ANIMATION_CADENCE intervals='..#x.intervals..' max_gap='..x.max_gap..' peak_work='..x.peak_work..' peak_allocations='..x.peak_allocations)
    assert(x.max_gap<=2,'30 Hz publication target failed: max gap '..x.max_gap..' ticks')
    x.outage=x.walls[2][1]; x.phase='outage'; x.changed=event.tick
  elseif x.phase=='outage' and chart and #chart.views==3 and lane and lane.presented_sequence>=3 then
    x.outage=nil; x.phase='restoring'; x.changed=event.tick
  elseif x.phase=='restoring' and chart and #chart.views==4 and lane and lane.presented_sequence>=3 then
    x.phase='done'; log('TC_COLD_OK animation-30Hz coherent-native-fronts retained-settings-and-credits power-recovery')
  end
end
return M
