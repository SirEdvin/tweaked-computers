-- Function-only four-row producer adaptation in real production ticks. This is a
-- pacing/model/publication comparison, not graphical speedup acceptance.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local runtime=require('scripts.runtime.computer')
local monitor=require('scripts.services.monitor')
local defs=require('scripts.device-definitions')
local source=require('examples.monitor-plot-baseline')
local M={}; local loaded=false
local function f() return storage.tc_plot_baseline end
local function nop() end
local function build(kind,x,y)
 local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})
 local r=assert(lifecycle.build(body)); lifecycle.power_entity(r).energy=100000; r.powered=true; return r
end
local function wire(a,b) assert(lifecycle.connector(a,'network','red').connect_to(lifecycle.connector(b,'network','red'))) end
function M.run()
 assert(#source==2829)
 local x={phase='running',steps=0,peak_work=0,peak_allocations=0,batches=0}; storage.tc_plot_baseline=x
 local c=build('computer',-3,0); x.computer=c.id
 local wall={}; for y=0,3 do for col=0,3 do wall[#wall+1]=build('monitor',col,y) end end
 local bridge=build('computer',6,0); local small=build('monitor',10,0)
 wire(c,wall[1]); wire(wall[1],wall[4]); wire(wall[4],bridge); wire(bridge,small)
 for _=1,200 do monitor.reconcile(game.tick,nop); if not registry.get().monitors.job then break end end
 x.large=monitor.resolve(wall[1]).id; x.small=monitor.resolve(small).id
 assert(runtime.save(c.id,source,c.saved_revision)); assert(runtime.activate(c.id,game.tick))
end
function M.on_load() loaded=true end
function M.on_configuration_changed() error('unexpected configuration phase') end
function M.on_tick(event)
 local x=f(); if x.phase=='done' then return end
 local root=registry.get(); local c=registry.computer(x.computer)
 if x.phase=='frozen' then
  if not loaded then return end
  assert(c.run_id==x.saved.run_id and c.state.plot_job==x.saved.job and c.state.plot_job.row==x.saved.row)
  assert(c.state.plot_screen==x.saved.screen and root.scheduler.maintenance_spent==x.saved.spent)
  x.phase='running'; loaded=false; x.resumed=true; log('TC_BASELINE_COLD_RETAINED')
 end
 for _,id in ipairs(root.order) do lifecycle.power_entity(registry.record(id)).energy=100000 end
 local profiler=helpers.create_profiler(); scheduler.tick(event.tick); profiler.stop()
 assert(c.status=='running' or x.phase=='draining' and c.status=='stopped',serpent.line(c.diagnostic)); x.steps=x.steps+1; assert(x.steps<250)
 local machine=root.ledger.machines[c.id]
 if machine then x.peak_work=math.max(x.peak_work,machine.work); x.peak_allocations=math.max(x.peak_allocations,machine.allocations) end
 local g=root.monitors.groups[x.large]; local job=c.state.plot_job
 if g.model.revision~=(x.revision or 1) then
  x.batches=x.batches+1; x.first_model=x.first_model or event.tick; x.revision=g.model.revision
  log('TC_BASELINE_BATCH tick='..event.tick..' revision='..g.model.revision..' next_row='..(job and job.row or 0))
 end
 if g.render and g.render.presented_revision>1 then x.first_present=x.first_present or event.tick end
 if x.steps%20==0 then log({'','TC_BASELINE_SCHEDULER_CPU step=',x.steps,' ',profiler}) end
 if not x.saved and job and job.row>=13 then
  x.saved={run_id=c.run_id,job=job,row=job.row,screen=c.state.plot_screen,spent=root.scheduler.maintenance_spent}
  x.phase='frozen'; loaded=false; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
 elseif x.phase=='running' and x.resumed and x.steps>=110 then
  runtime.stop(c.id); x.phase='draining'
 end
 if x.phase=='draining' then
  local p=root.monitors.presentation; local ready=#p.jobs==0 and #p.retired==0 and p.pending_cells==0
  for _,id in ipairs({x.large,x.small}) do local display=root.monitors.groups[id]
   if not display.render or display.render.presented_revision~=display.model.revision then ready=false end
  end
  if ready then
   assert(x.batches>=14 and x.first_present>=x.first_model and x.peak_work<=100000 and x.peak_allocations<=16384)
   log('TC_BASELINE_PLOT_OK batches='..x.batches..' first_model='..x.first_model..' first_present='..x.first_present..
    ' peak_work='..x.peak_work..' peak_allocations='..x.peak_allocations)
   x.phase='done'; log('TC_COLD_OK')
  end
 end
end
return M
