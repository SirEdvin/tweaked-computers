-- Test-only sustained production scheduler measurement. Unlike the correctness
-- fixture, do not allocate full oracle images or retain revision histories every
-- tick: their later GC would contaminate scheduler timings.
local setup=require('tests.monitor_animation_setup')
local config=require('tests.monitor_performance_config')
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local model=require('scripts.monitor-model')
local runtime=require('scripts.runtime.computer')
local scene=config.scene or 'all'
assert(scene=='zero' or scene=='idle' or scene=='one' or scene=='all')
local M={}; local loaded=false
local function f() return storage.tc_animation end
local function audit(x)
  local s=registry.get().monitors; local p=s.presentation
  assert(p.front_cells<=model.limits.aggregate_cells and p.front_frames<=model.limits.tiles)
  assert(p.staging_cells<=model.limits.render_staging_cells and p.staging_frames<=model.limits.render_staging_frames)
  assert(p.retired_cells<=model.limits.render_retired_cells and p.retired_frames<=model.limits.render_retired_frames)
  assert(p.pending_cells<=model.limits.render_snapshot_cells)
  local objects=rendering.get_all_objects(); x.peak_objects=math.max(x.peak_objects,#objects)
  assert(#objects<=model.limits.render_object_limit)
  local owned={}
  local function object(o) if o and o.valid then owned[o.id]=true end end
  local function frame(r)
    if not r then return end
    object(r.panel); object(r.cursor)
    for _,cell in ipairs(r.cells) do if cell then object(cell.background); object(cell.glyph) end end
  end
  for _,g in pairs(s.groups) do frame(g.render) end
  for _,job in ipairs(p.jobs) do for _,r in ipairs(job.frames) do frame(r) end end
  for _,r in ipairs(p.retired) do frame(r) end
  for _,r in ipairs(p.orphans) do frame(r) end
  for _,id in ipairs(registry.get().order) do
    local r=registry.record(id); if r.status_art then object(r.status_art.object) end
  end
  local count=0; for _ in pairs(owned) do count=count+1 end
  assert(count==#objects,'native render objects escaped all retained ownership roots')
  for _,g in pairs(s.groups) do local r=g.render; if r then
    for i,c in ipairs(r.cells) do
      local v=r.snapshot.cells[i]
      assert(c.value[1]==v[1] and c.value[2]==v[2] and c.value[3]==v[3])
      assert(c.background.valid and c.background.visible)
      if v[1]~=32 then assert(c.glyph and c.glyph.valid and c.glyph.visible and c.glyph.sprite=='tc-glyph-'..v[1]) end
    end
  end end
end
function M.run()
  setup.run()
  local x=f(); x.phase='warmup'; x.peak_objects=0; x.measured=0; x.visible_changes=0; x.publications=0
  x.max_gap=0; x.previous={}
  x.tiles=0
  for _,wall in ipairs(x.walls) do x.tiles=x.tiles+#wall end
  if scene=='zero' then
    runtime.stop(x.computer)
    for _,wall in ipairs(x.walls) do for _,id in ipairs(wall) do assert(lifecycle.remove(id,'timing-zero-control',true)) end end
    x.tiles=0
  end
  game.speed=100 -- Accelerated simulation, never a real-time UPS/FPS claim.
end
function M.on_load()
  loaded=true
  local x=f(); local r=registry.get(); local c=registry.computer(x.computer)
  if x.phase=='frozen' then
    assert(c.state.smooth_chart==x.saved.chart and c.run_id==x.saved.run)
    assert(r.monitors.presentation==x.saved.presentation and r.ledger.total==x.saved.total)
    assert(r.scheduler.maintenance_spent==x.saved.maintenance)
    log('TC_PERF_COLD_UNCHANGED')
  end
end
function M.on_configuration_changed() error('unexpected configuration change') end
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  if x.phase=='frozen' then
    if not loaded then return end
    loaded=false; x.phase='rewarm'; x.steps=0
  end
  local root=registry.get(); local c=registry.computer(x.computer)
  local tiles=0
  for _,id in ipairs(root.order) do local r=registry.record(id)
    if r and r.body.valid then lifecycle.power_entity(r).energy=100000 end
    if r and r.kind=='monitor' then
      assert(r.body.valid and lifecycle.has_power(r),'timing scene lost a live powered tile')
      tiles=tiles+1
    end
  end
  assert(tiles==x.tiles,'timing scene tile count changed')
  local profiler=helpers.create_profiler()
  scheduler.tick(event.tick)
  profiler.stop()
  x.steps=x.steps+1
  local stopped=scene=='zero' or scene=='idle' and x.phase~='warmup'
  assert(c.status==(stopped and 'stopped' or 'running'),serpent.line(c.diagnostic))
  if x.phase=='measuring' then
    x.measured=x.measured+1
    log({'','TC_PERF_CPU tick=',event.tick,' ',profiler})
    local selection=c.monitor_sync; local p=root.monitors.presentation
    local lane=selection and p.lanes[selection.key]
    if lane and lane.presented_tick~=x.last_publication then
      local changed=false
      for _,ref in ipairs(lane.members) do
        local r=root.monitors.groups[ref.name].render; local previous=x.previous[ref.name]
        if previous then
          for i,v in ipairs(r.snapshot.cells) do local old=previous[i]
            if old[1]~=v[1] or old[3]~=v[3] or v[1]~=32 and old[2]~=v[2] then changed=true; break end
          end
        else changed=true end
        x.previous[ref.name]=r.snapshot.cells
      end
      x.publications=x.publications+1
      if changed then x.visible_changes=x.visible_changes+1 end
      if x.last_publication then x.max_gap=math.max(x.max_gap,lane.presented_tick-x.last_publication) end
      x.last_publication=lane.presented_tick
    end
    if x.measured%600==0 then
      audit(x)
      log('TC_PERF_RESOURCES ticks='..x.measured..' objects='..#rendering.get_all_objects()..' retired='..p.retired_cells..' staging='..p.staging_cells)
    end
    if x.measured==config.ticks then
      audit(x)
      if not stopped then assert(x.publications>0 and x.visible_changes>0,'no chart motion') end
      if config.max_gap then assert(x.max_gap<=config.max_gap,'publication cadence exceeded target') end
      log('TC_PERF_DONE ticks='..x.measured..' publications='..x.publications..' visible_changes='..x.visible_changes..' max_gap='..x.max_gap..' peak_objects='..x.peak_objects)
      x.phase='done'; log('TC_COLD_OK sustained-monitor-performance')
    end
  elseif x.steps>=120 then
    audit(x)
    if x.phase=='warmup' then
      if scene=='idle' then runtime.stop(x.computer) end
      x.saved={chart=c.state.smooth_chart,run=c.run_id,presentation=root.monitors.presentation,
        total=root.ledger.total,maintenance=root.scheduler.maintenance_spent}
      x.phase='frozen'; loaded=false; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
    else
      x.phase='measuring'
      local p=root.monitors.presentation; local lane=c.monitor_sync and p.lanes[c.monitor_sync.key]
      x.last_publication=lane and lane.presented_tick -- Exclude the warmup's old front from measured publications.
    end
  end
end
return M
