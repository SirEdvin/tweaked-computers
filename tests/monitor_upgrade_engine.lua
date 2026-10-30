-- Loaded by the owning mod; the legacy runner adds only this fixture and the
-- opt-in control tail to a checksum-verified private copy of released 0.1.4.
local registry=require('scripts.registry')
local scheduler=require('scripts.scheduler')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local data=require('scripts.runtime.data')
local model=require('scripts.monitor-model')
local monitor=require('scripts.services.monitor')
local peripheral=require('scripts.services.peripheral')
local renderer=require('scripts.rendering')
local defs=require('scripts.device-definitions')
local M={}; local loaded=false
local function f() return storage.tc_monitor_upgrade end
local function nop() end
local source=[[function start(e)
 computer.setState('boots',(computer.getState('boots') or 0)+1)
 computer.on('peripheral_detach','detached'); computer.on('monitor_resize','resized')
end

function detached(e) local t=computer.getState('detaches') or {}; t[e.peripheral]=true; computer.setState('detaches',t) end

function resized(e)
 computer.setState('resizes',(computer.getState('resizes') or 0)+1)
 local t=computer.getState('resized_names') or {}; t[e.peripheral]=true; computer.setState('resized_names',t)
end]]
local function build(kind,x,y)
 local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})
 local r=assert(lifecycle.build(body))
 if not lifecycle.power_entity then assert(not r.children.power and lifecycle.available(r)) end
 return r
end
local function wire(a,b) assert(lifecycle.connector(a,'network','red').connect_to(lifecycle.connector(b,'network','red'))) end
local function fuel()
 for _,id in ipairs(registry.get().order) do local r=registry.record(id)
  if r and r.body.valid then
   if lifecycle.power_entity then lifecycle.power_entity(r).energy=100000; r.powered=true
   else assert(not r.children.power and lifecycle.available(r)) end
  end
 end
end
local function maintenance_run()
 local x={kind='maintenance',phase='maintenance-settling',steps=0,from_version=script.active_mods['tweaked-computers']}
 storage.tc_monitor_upgrade=x
 local c=build('computer',-3,0); x.computer=c.id
 local wall={}; x.walls={wall}
 for y=0,5 do for col=0,5 do wall[#wall+1]=build('monitor',col,y).id end end
 x.unaffected=wall[1]; x.partial=build('monitor',10,0).id
 for _=1,200 do monitor.reconcile(game.tick,nop); if not registry.get().monitors.job then break end end
 local g=monitor.resolve(registry.record(x.unaffected)); model.calls.write(g.model,nop,'KEEP'); renderer.participate(g)
 local p=monitor.resolve(registry.record(x.partial)); model.calls.write(p.model,nop,'OLD'); renderer.participate(p)
 assert(runtime.save(c.id,source,c.saved_revision)); assert(runtime.activate(c.id,game.tick))
end
scheduler.register_phase('render','00-monitor-upgrade-pressure',function(tick,spend)
 local x=f(); if not x or x.kind~='maintenance' or x.phase~='maintenance-preparing' then return end
 renderer.tick(tick,function(n)
  local s=registry.get().monitors; local g=monitor.resolve(registry.record(x.partial))
  local lane=s.presentation and s.presentation.lanes[g.id]
  if lane and lane.job and lane.job.ready then
   local remaining=200000-registry.get().scheduler.maintenance_spent
   if remaining>0 then spend(remaining) end
   x.refused=true
  end
  spend(n)
 end)
end)
local function maintenance_tick(event)
 local x=f(); local root=registry.get(); local c=registry.computer(x.computer)
 if x.phase=='maintenance-frozen' then return end
 if x.phase=='done' then
  if loaded then
   local p=root.monitors.presentation; local work=p.work; local members=p.members
   fuel(); scheduler.tick(event.tick)
   assert(root.monitors.signature==x.candidate_signature and p.work==work and p.members==members,'ordinary load repeated demand enrollment')
   for id,front in pairs(x.final_fronts) do assert(root.monitors.groups[id].render==front,'ordinary load rebuilt an idle front') end
   assert(c.state.boots==1); loaded=false; log('TC_UPGRADE_ORDINARY_OK')
  end
  return
 end
 fuel(); scheduler.tick(event.tick); x.steps=x.steps+1; assert(x.steps<300)
 local s=root.monitors; local p=s.presentation; local ready=not s.job and p and #p.jobs==0 and #p.retired==0 and #p.orphans==0 and p.pending_cells==0
 for _,g in pairs(s.groups) do if not g.render or g.render.presented_revision~=g.model.revision then ready=false end end
 local g=monitor.resolve(registry.record(x.unaffected)); local partial=monitor.resolve(registry.record(x.partial))
 if x.phase=='maintenance-settling' and ready and c.state.boots==1 then
  assert(not p.demand_version,'legacy save already contains candidate bookkeeping')
  x.saved={id=g.id,model=g.model,cells=g.model.cells,render=g.render,glyph=g.render.cells[1].glyph,run_id=c.run_id}
  x.partial_saved={model=partial.model,cells=partial.model.cells,render=partial.render,glyph=partial.render.cells[1].glyph}
  model.calls.setCursorPos(partial.model,nop,1,1); model.calls.write(partial.model,nop,'NEXT'); renderer.participate(partial)
  x.partial_saved.cells=partial.model.cells
  x.phase='maintenance-preparing'
 elseif x.phase=='maintenance-preparing' and x.refused then
  local job=assert(p.lanes[partial.id].job); assert(job.ready and partial.render==x.partial_saved.render)
  x.progress={job=job,member=job.member,cell=job.cell,spent=root.scheduler.maintenance_spent,reserved=root.scheduler.render_reserved_work}
  x.phase='maintenance-frozen'; loaded=false; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
 elseif x.phase=='maintenance-upgrading' then
  assert(c.state.boots==1 and c.run_id==x.saved.run_id)
  assert(g.model==x.saved.model and g.model.cells==x.saved.cells and g.render==x.saved.render and x.saved.glyph.valid and x.saved.glyph.visible)
  assert(partial.model==x.partial_saved.model and partial.model.cells==x.partial_saved.cells)
  if ready then
   assert(p.demand_version==1 and s.topology_version==1 and x.progress.job.complete)
   assert(partial.render~=x.partial_saved.render and partial.render.snapshot.cells[1][1]==78 and not x.partial_saved.glyph.valid)
   x.final_fronts={}; for id,group in pairs(s.groups) do x.final_fronts[id]=group.render end
   x.candidate_signature=s.signature; x.phase='done'
   log('TC_MONITOR_MAINTENANCE_UPGRADE_OK from='..x.from_version..' to='..script.active_mods['tweaked-computers']); log('TC_UPGRADE_OK')
  end
 end
end
function M.run()
 if script.active_mods['tweaked-computers']=='0.1.16' then return maintenance_run() end
 assert(model.limits.width_tiles==4,'legacy fixture must originate in the released four-tile runtime')
 local x={phase='legacy',walls={},steps=0,stopped_setup=true,boots=1}; storage.tc_monitor_upgrade=x
 local c=build('computer',-3,0); x.computer=c.id
 for i,shape in ipairs({{3,6,0},{6,6,10}}) do
  local wall={}; x.walls[i]=wall
  for y=0,shape[2]-1 do for col=0,shape[1]-1 do wall[#wall+1]=build('monitor',shape[3]+col,y).id end end
 end
 local u=build('monitor',30,10); x.unaffected=u.id
 local partial=build('monitor',30,14); x.partial=partial.id
 for _=1,200 do monitor.reconcile(game.tick,nop); if not registry.get().monitors.job then break end end
 local s=registry.get().monitors; assert(#s.order==8)
 for _,id in ipairs(s.order) do local g=s.groups[id]
  model.calls.write(g.model,nop,'OLD'); model.calls.setPaletteColor(g.model,nop,1,0x123456)
  model.calls.setTextColor(g.model,nop,2); model.calls.setBackgroundColor(g.model,nop,4)
  model.calls.setCursorBlink(g.model,nop,true); model.calls.setCursorPos(g.model,nop,2,2)
 end
 local g=monitor.resolve(u); model.calls.setCursorPos(g.model,nop,1,1); model.calls.write(g.model,nop,'KEEP')
 wire(c,registry.record(x.walls[1][1])); wire(registry.record(x.walls[1][1]),registry.record(x.walls[1][13]))
 wire(registry.record(x.walls[1][1]),registry.record(x.walls[1][3]))
 local bridge=build('computer',6,0); wire(registry.record(x.walls[1][3]),bridge); wire(bridge,registry.record(x.walls[2][1]))
 wire(registry.record(x.walls[2][1]),registry.record(x.walls[2][6]))
 wire(registry.record(x.walls[2][1]),registry.record(x.walls[2][31]))
 wire(registry.record(x.walls[2][31]),registry.record(x.walls[2][36]))
 assert(runtime.save(c.id,source,c.saved_revision))
 -- Released 0.1.4 has no declaration compiler; retain explicit stopped data.
 local value,stats=data.copy(1,nop)
 c.state.boots=value; c.state_sizes.boots=stats.bytes+#'boots'+16
 c.state_entries=1; c.state_bytes=c.state_bytes+c.state_sizes.boots
 c.state_nodes=c.state_nodes+stats.nodes; c.state_node_sizes.boots=stats.nodes
 x.survivors={}; x.survivor_anchors={}; x.absorbed={}
 for i,wall in ipairs(x.walls) do
  local groups={}; local survivor
  for _,id in ipairs(wall) do local old=monitor.resolve(registry.record(id)); groups[old.id]=old
   if not survivor or old.anchor<survivor.anchor then survivor=old end
  end
  x.survivors[i]=survivor.id
  x.survivor_anchors[i]=survivor.anchor
  for id in pairs(groups) do if id~=survivor.id then x.absorbed[id]=true end end
 end
end
function M.on_load()
 loaded=true
 local x=f(); if not x then return end
 if x.kind=='maintenance' and x.phase=='maintenance-frozen' then
  local root=registry.get(); local job=x.progress.job
  assert(job.ready and job.member==x.progress.member and job.cell==x.progress.cell)
  assert(root.scheduler.maintenance_spent==x.progress.spent and root.scheduler.render_reserved_work==x.progress.reserved)
 end
 if x.saved then
  local c=registry.computer(x.computer); local g=monitor.resolve(registry.record(x.unaffected))
  local _,stats=data.copy(c.state,nop); assert(c.state_nodes==stats.nodes,'retained state node accounting mismatch')
  assert(c.run_id==(x.candidate_run or x.saved.run_id) and c.state.boots==(x.boots or 1))
  assert(g.id==x.saved.id and g.model==x.saved.model and g.model.cells==x.saved.cells)
 end
end
function M.on_configuration_changed(event)
 local x=f()
 if x.kind=='maintenance' then
  local change=assert(event.mod_changes['tweaked-computers'])
  assert(change.old_version=='0.1.16' and change.old_version==x.from_version
    and change.new_version==script.active_mods['tweaked-computers'] and change.new_version~=change.old_version)
  assert(x.phase=='maintenance-frozen' and not registry.get().monitors.presentation.demand_version)
  assert(x.progress.job.ready and x.progress.job.member==x.progress.member and x.progress.job.cell==x.progress.cell)
  x.phase='maintenance-upgrading'; loaded=false
  log('TC_MONITOR_MAINTENANCE_CONFIGURATION old='..change.old_version..' new='..change.new_version)
  return
 end
 assert(model.limits.width_tiles==6 and f().phase=='legacy-frozen')
 local x=f(); local g=monitor.resolve(registry.record(x.unaffected))
 assert(g.render==x.saved.render and x.saved.glyph.valid and x.saved.glyph.visible)
 -- Candidate-only activation retains the original notification/effect checks,
 -- not running-source continuity from the pre-declaration release.
 local c=registry.computer(x.computer)
 assert(c.status=='stopped' and not c.active and not c.run_id and c.state.boots==1)
 fuel(); assert(lifecycle.available(c) and not c.children.power)
 local run,reason=runtime.activate(c.id,game.tick); assert(run,serpent.line(reason)); x.candidate_run=run
 local dispatched,dispatch_error=scheduler.dispatch(c,game.tick); assert(dispatched,serpent.line(dispatch_error or c.diagnostic))
 -- Establish a paid observation before regrouping, not a fabricated old run.
 peripheral.reconcile_one(c,'red',game.tick,scheduler.maintenance(registry.get(),game.tick))
 for id in pairs(x.absorbed) do assert(c.network_views.red.inventory[id],'pre-regroup observation missing '..id) end
 x.boots=2; assert(c.state.boots==x.boots)
 x.changed=true; x.phase='upgrading'; log('TC_MONITOR_UPGRADE_CONFIGURATION')
end
function M.on_tick(event)
 local x=f(); if not x then return end
 if x.kind=='maintenance' then return maintenance_tick(event) end
 if x.phase=='legacy-frozen' then return end
 if x.phase=='done' then
  if loaded then
   local g=monitor.resolve(registry.record(x.unaffected))
   assert(x.candidate_signature==registry.get().monitors.signature and g.model.cells==x.saved.cells)
   assert(x.saved.glyph.valid and x.saved.glyph.visible and registry.computer(x.computer).state.boots==x.boots)
   fuel(); scheduler.tick(event.tick)
   local s=registry.get().monitors
   assert(not s.job and s.signature==x.candidate_signature,'ordinary reload repeated policy regrouping')
   for id,group in pairs(x.candidate_groups) do assert(s.groups[id]==group,'ordinary reload replaced a group') end
   log('TC_UPGRADE_ORDINARY_OK'); loaded=false
  end
  return
 end
 fuel(); scheduler.tick(event.tick); x.steps=x.steps+1; assert(x.steps<300,serpent.line{phase=x.phase,state=registry.computer(x.computer).state,groups=#registry.get().monitors.order,job=registry.get().monitors.job~=nil})
 local c=registry.computer(x.computer)
 local _,stats=data.copy(c.state,nop); assert(c.state_nodes==stats.nodes,'state node accounting mismatch')
 assert(c.status==(x.phase=='legacy' and 'stopped' or 'running'),serpent.line(c.diagnostic))
 local s=registry.get().monitors; local ready=not s.job
 for _,id in ipairs(s.order) do local g=s.groups[id]; if not g.render or g.render.presented_revision~=g.model.revision then ready=false end end
 if x.phase=='legacy' and ready and c.state.boots==x.boots then
  local g=monitor.resolve(registry.record(x.unaffected))
  local partial=monitor.resolve(registry.record(x.partial)); local old=partial.render
  model.calls.setCursorPos(partial.model,nop,1,1); model.calls.write(partial.model,nop,'MIXED')
  local spend=scheduler.maintenance(registry.get(),event.tick,true)
  local admitted=scheduler.try_maintenance(function()
   renderer.tick(event.tick,function(n)
    if old.sweep_cursor==2 then
     local root=registry.get(); local remaining=200000-root.scheduler.maintenance_spent
     if remaining>0 then spend(remaining) end
    end
    spend(n)
   end)
  end)
  assert(not admitted and old.sweep_cursor==2 and old.presented_revision~=partial.model.revision)
  x.partial_saved={group=partial,model=partial.model,cells=partial.model.cells,render=old,glyph=old.cells[1].glyph}
  x.saved={id=g.id,model=g.model,cells=g.model.cells,render=g.render,glyph=g.render.cells[1].glyph,run_id=c.run_id}
  x.phase='legacy-frozen'; loaded=false; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
 elseif x.phase=='upgrading' then
  assert(x.changed and c.run_id==x.candidate_run and c.state.boots==x.boots)
  local u=monitor.resolve(registry.record(x.unaffected))
  assert(u.id==x.saved.id and u.model==x.saved.model and u.model.cells==x.saved.cells)
  assert(x.saved.glyph.valid and x.saved.glyph.visible,'unaffected image was hidden or destroyed')
  local partial=monitor.resolve(registry.record(x.partial))
  assert(partial.model==x.partial_saved.model and partial.model.cells==x.partial_saved.cells)
  if ready and #s.order==4 then
   for i,wall in ipairs(x.walls) do local g=monitor.resolve(registry.record(wall[1]))
    assert(g.id==x.survivors[i] and g.width_tiles==(i==1 and 3 or 6) and g.height_tiles==6)
    for _,cell in ipairs(g.model.cells) do assert(cell[1]==32,'geometry-changing merge must clear') end
    assert(g.model.palette[1][1]==0x12/255)
    assert(g.anchor==x.survivor_anchors[i] and g.model.fg==1 and g.model.bg==2 and g.model.blink)
    assert(g.model.x==2 and g.model.y==2)
   end
   for id in pairs(x.absorbed) do if s.groups[id] or not (c.state.detaches and c.state.detaches[id]) then ready=false end end
   if (c.state.resizes or 0)<2 then ready=false end
   local p=s.presentation
   if ready and #p.retired==0 and #p.orphans==0 and #p.jobs==0 then
    assert(partial.render~=x.partial_saved.render and not x.partial_saved.glyph.valid,'partial legacy sweep was adopted')
    assert(partial.render.cells[1].value[1]==77 and partial.model.cells[1][1]==77)
    assert(not c.state.resized_names[x.saved.id],'unaffected display received a fake resize')
    x.phase='done'; x.candidate_signature=s.signature
    x.candidate_groups={}; for id,g in pairs(s.groups) do x.candidate_groups[id]=g end
    log('TC_MONITOR_UPGRADE_OK steps='..x.steps..' resizes='..c.state.resizes); log('TC_UPGRADE_OK')
   end
  end
 end
end
return M
