-- Actual production-owner ticks: full world, real groups, compiled callers,
-- snapshot coalescing, native visibility and cold state. No graphical claims.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local runtime=require('scripts.runtime.computer')
local peripheral=require('scripts.services.peripheral')
local monitor=require('scripts.services.monitor')
local model=require('scripts.monitor-model')
local renderer=require('scripts.rendering')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local defs=require('scripts.device-definitions')
local plot_source=require('examples.monitor-plot-program')
local M={}; local loaded=false
local function f() return storage.tc_present_live end
local function nop() end
local source=[[return {api_version=1,handlers={
start=function(e)
 computer.setState('boots',(computer.getState('boots') or 0)+1)
 computer.setState('n',0)
 local refs={}
 for _,wire in ipairs({'red','green'}) do
  for _,name in ipairs(peripheral.getNames(wire)) do refs[#refs+1]={name=name,wire=wire} end
 end
 peripheral.setMonitorSyncGroup(refs)
 computer.on('monitor_resize','resize'); computer.every(1,'paint')
end,
resize=function(e) computer.setState('repaint',true) end,
paint=function(e)
 local n=computer.getState('n')+1; computer.setState('n',n)
 if n<=70 or computer.getState('repaint') then
  for _,ref in ipairs(peripheral.getMonitorSyncGroup().members) do
   local w,h=peripheral.call(ref.name,ref.wire,'getSize')
   peripheral.call(ref.name,ref.wire,'setCursorPos',1,1)
   peripheral.call(ref.name,ref.wire,'write',string.rep(n<60 and 'A' or 'Z',w))
  end
  computer.setState('repaint',false)
 end
end
}}]]
local function guest(c,text)
 local ctx=admission.context(admission.new(),c.id,game.tick)
 local plan,e=compiler.compile('return {api_version=1,handlers={start=function(e) '..text..' end}}',ctx)
 assert(plan,e and e.message)
 local ok,why=compiler.run(plan,'start',{},function(g) return runtime.services(c,game.tick,g) end,ctx)
 assert(ok,serpent.line(why))
end
local function build(kind,x,y,d)
 local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},direction=d or 0,force='player'})
 local r=assert(lifecycle.build(body)); lifecycle.power_entity(r).energy=100000; r.powered=true
 return r
end
local function wire(a,b,color) assert(lifecycle.connector(a,'network',color).connect_to(lifecycle.connector(b,'network',color))) end
local function fuel()
 for _,id in ipairs(registry.get().order) do local r=registry.record(id)
  if r and r.body.valid then lifecycle.power_entity(r).energy=100000 end
 end
 if f().outage then local r=registry.record(f().outage); lifecycle.power_entity(r).energy=0 end
 if f().owner_outage then lifecycle.power_entity(registry.record(f().computer)).energy=0 end
end
scheduler.register_phase('render','00-presentation-pressure',function(tick,spend)
 local x=f(); if not x or x.phase~='dense' or x.pressured then return end
 renderer.tick(tick,function(n)
  local root=registry.get(); local remaining=200000-root.scheduler.maintenance_spent
  if n>=120000 and remaining>=n then
   x.pressure_fronts={}
   for _,id in ipairs(x.ids) do x.pressure_fronts[id]=root.monitors.groups[id].render end
   x.pressured=true; x.pressure_tick=tick; x.pressure_work=n
   spend(remaining-n+1) -- Explicit synthetic one-unit-short pressure, not CPU work.
  end
  spend(n)
 end)
end)
function M.run()
 local x={phase='running',walls={},steps=0,peak_staging=0,peak_retired=0,published=0}; storage.tc_present_live=x
 local c=build('computer',-3,0); x.computer=c.id
 local positions={{0,0},{10,0},{20,0},{30,0},{0,10},{10,10},{20,10}}
 for i,pos in ipairs(positions) do
  local wall={}; x.walls[i]=wall
  for y=0,5 do for col=0,5 do wall[#wall+1]=build('monitor',pos[1]+col,pos[2]+y,i<=4 and (i-1)*4 or 0).id end end
 end
 for i=0,3 do build('monitor',30+i*3,10) end
 for _=1,200 do monitor.reconcile(game.tick,nop); if not registry.get().monitors.job then break end end
 local s=registry.get().monitors; assert(not s.job and #s.order==11)
 for i,wall in ipairs(x.walls) do
  local g=monitor.resolve(registry.record(wall[1])); assert(#g.members==36)
  if i>4 then
   model.scale(g.model,6,6,nop,0.5)
   for y=1,g.model.height do model.calls.setCursorPos(g.model,nop,1,y); model.calls.write(g.model,nop,string.rep('D',g.model.width)) end
  else
   for y=1,g.model.height do model.calls.setCursorPos(g.model,nop,1,y); model.calls.write(g.model,nop,string.rep('A',g.model.width)) end
  end
 end
 for _,color in ipairs({'red','green'}) do
  local previous=c
  for i=1,4 do
   local first=registry.record(x.walls[i][1]); local last=registry.record(x.walls[i][6])
   wire(previous,first,color); wire(first,last,color); previous=last
  end
 end
 assert(runtime.save(c.id,source,c.saved_revision)); assert(runtime.activate(c.id,game.tick))
 guest(c,[[local members={}; for _,name in ipairs(peripheral.getNames('red')) do members[#members+1]={name=name,wire='red'} end
 assert(select('#',peripheral.setMonitorSyncGroup(members))==0)
 assert(select('#',peripheral.getMonitorSyncGroup())==1)
 local old=peripheral.getMonitorSyncGroup(); assert(#old.members==4 and old.status=='waiting')
 old.members[1].name='not-a-monitor'; assert(peripheral.getMonitorSyncGroup().members[1].name~='not-a-monitor')
 local bad={nil,false,1,'bad'}
 for i=2,4 do local ok,e=pcall(peripheral.setMonitorSyncGroup,bad[i]); assert(not ok and e.code=='E_ARGUMENT') end
 local ok,e=pcall(peripheral.setMonitorSyncGroup); assert(not ok and e.code=='E_ARGUMENT')
 ok,e=pcall(peripheral.setMonitorSyncGroup,{{name=members[1].name,wire='blue'}}); assert(not ok and e.code=='E_ARGUMENT')
 ok,e=pcall(peripheral.setMonitorSyncGroup,{{name=members[1].name,wire='red',extra=true}}); assert(not ok and e.code=='E_ARGUMENT')
 ok,e=pcall(peripheral.setMonitorSyncGroup,{{name='absent',wire='red'}}); assert(not ok and e.code=='E_UNREACHABLE')
 assert(#peripheral.getMonitorSyncGroup().members==4)
 ]])
 guest(c,[[local refs=peripheral.getMonitorSyncGroup().members
 local function rejected(value,code)
  local ok,e=pcall(peripheral.setMonitorSyncGroup,value); assert(not ok and e.code==code)
  assert(#peripheral.getMonitorSyncGroup().members==4)
 end
 rejected(nil,'E_ARGUMENT'); rejected({[2]=refs[1]},'E_ARGUMENT')
 rejected({refs[1],extra=true},'E_ARGUMENT')
 local cyclic={}; cyclic[1]=cyclic; rejected(cyclic,'E_ARGUMENT')
 local many={}; for i=1,9 do many[i]=refs[1] end; rejected(many,'E_LIMIT')
 peripheral.setMonitorSyncGroup({}); assert(peripheral.getMonitorSyncGroup().status=='none')
 peripheral.setMonitorSyncGroup({refs[1]}); assert(#peripheral.getMonitorSyncGroup().members==1)
 peripheral.setMonitorSyncGroup(refs)
 ]])
 local refs={}; for _,ref in ipairs(c.monitor_sync.members) do refs[#refs+1]={name=ref.name,wire=ref.wire} end
 renderer.select(c,game.tick,nop,{refs[1]})
 local measured=0; renderer.select(c,game.tick,function(n) measured=measured+n end,{refs[1]})
 renderer.select(c,game.tick,nop,refs); local previous=c.monitor_sync; local available=measured-1
 local admitted=pcall(renderer.select,c,game.tick,function(n) available=available-n; if available<0 then error({code='E_BUSY'},0) end end,{refs[1]})
 assert(not admitted and c.monitor_sync==previous,'one-unit-short selection replaced old configuration')
 local green=lifecycle.connector(c,'network','green'); local endpoint=lifecycle.connector(registry.record(x.walls[1][1]),'network','green')
 assert(green.disconnect_from(endpoint))
 guest(c,"local refs=peripheral.getMonitorSyncGroup().members; local ok,e=pcall(peripheral.setMonitorSyncGroup,{{name=refs[1].name,wire='red'},{name=refs[1].name,wire='green'}}); assert(not ok and e.code=='E_UNREACHABLE'); assert(#peripheral.getMonitorSyncGroup().members==4)")
 assert(green.connect_to(endpoint))
 local database=build('kv',-3,4); wire(c,database,'red')
 guest(c,"local ok,e=pcall(peripheral.setMonitorSyncGroup,{{name="..string.format('%q',database.id)..",wire='red'}}); assert(not ok and e.code=='E_WRONGTYPE')")
 lifecycle.remove(database.id,'fixture',true)
 local other=build('computer',-3,4); wire(other,registry.record(x.walls[1][1]),'red')
 other.status='running'; other.run_id=other.id..'/fixture'; other.active={handlers={start=true}}
 guest(other,"local name=peripheral.getNames('red')[1]; local ok,e=pcall(peripheral.setMonitorSyncGroup,{{name=name,wire='red'}}); assert(not ok and e.code=='E_BUSY'); peripheral.call(name,'red','setCursorBlink',false); assert(peripheral.getMonitorSyncGroup().status=='none')")
 assert(c.monitor_sync==previous and next(registry.get().monitors.presentation.lanes[previous.key].participation))
 runtime.stop(other.id)
 x.ids={}; for _,ref in ipairs(c.monitor_sync.members) do x.ids[#x.ids+1]=ref.name end
 log('TC_PRESENT_SELECTION_CONTRACT_OK')
end
function M.on_load() loaded=true end
function M.on_configuration_changed() error('unexpected configuration phase') end
local function settled(s,c)
 if s.job then return false end
 for _,id in ipairs(s.order) do if not monitor.available(s.groups[id],nop) then return false end end
 if next(s.resizes) or c.state.repaint then return false end
 for _,item in ipairs(c.queue) do if item.event.name=='monitor_resize' then return false end end
 local p=s.presentation
 if not p or #p.jobs>0 or #p.orphans>0 or #p.retired>0 or p.pending_cells>0 then return false end
 for _,id in ipairs(s.order) do local g=s.groups[id]
  if not g.render or g.render.presented_revision~=g.model.revision then return false end
 end
 return true
end
local function audit(s)
 local p=s.presentation; if not p then return end
 assert(p.staging_cells>=0 and p.staging_cells<=10584 and p.retired_cells>=0 and p.retired_cells<=10584)
 assert(p.front_cells>=0 and p.front_cells<=80000 and p.pending_cells>=0 and p.pending_cells<=80000)
 assert(p.front_frames<=256 and p.staging_frames<=256 and p.retired_frames<=256)
 local staged,retired,pending=0,0,0
 local fronts,frames=0,0
 for _,g in pairs(s.groups) do if g.render then fronts=fronts+g.render.slots; frames=frames+1 end end
 for _,r in ipairs(p.orphans) do fronts=fronts+r.slots; frames=frames+1 end
 assert(fronts==p.front_cells and frames==p.front_frames)
 assert(#rendering.get_all_objects()<=model.limits.render_object_limit)
 for _,job in ipairs(p.jobs) do staged=staged+job.slots end
 for _,r in ipairs(p.retired) do retired=retired+r.slots end
 for _,lane in pairs(p.lanes) do if lane.pending then pending=pending+lane.pending.slots end end
 assert(staged==p.staging_cells and retired==p.retired_cells and pending==p.pending_cells and #p.jobs<=256)
 for _,job in ipairs(p.jobs) do if not job.cancelled and not job.complete then for _,r in ipairs(job.frames) do if r then
  for i,cell in ipairs(r.cells) do if cell and not r.reused[i] then
   assert(cell.background.valid and not cell.background.visible)
   if cell.glyph then assert(cell.glyph.valid and not cell.glyph.visible) end
  end end
  if r.cursor and not r.shared_cursor then assert(not r.cursor.visible) end
 end end end end
 if not registry.computer(f().computer).monitor_sync then return end
 local selection=registry.computer(f().computer).monitor_sync
 local lane=p.lanes[selection.key]; if not lane or lane.presented_sequence==0 then return end
 local seq,tick
 for _,ref in ipairs(selection.members) do local g=s.groups[ref.name]; local r=g and g.render
  if r then
   if seq then assert(r.presented_sequence==seq and r.presented_tick==tick,'partial selected publication') end
   seq,tick=r.presented_sequence,r.presented_tick
  end
 end
end
function M.on_tick(event)
 local x=f(); if x.phase=='done' then return end
 local root=registry.get(); local c=registry.computer(x.computer); local s=root.monitors
 if x.phase=='frozen' then
  if not loaded then return end
  local saved=x.saved; local p=s.presentation
  assert(p==saved.presentation and p.jobs==saved.jobs and saved.job==p.lanes[c.monitor_sync.key].job)
  assert(c.state.boots==saved.boots and c.state.n==saved.n and s.groups[x.ids[1]].render==saved.front)
  assert(root.scheduler.maintenance_spent==saved.spent and root.scheduler.maintenance_tick==saved.tick)
  assert(not scheduler.try_maintenance(function() scheduler.maintenance(root,saved.tick,true)(200001-saved.spent) end))
  renderer.tick(saved.tick,scheduler.maintenance(root,saved.tick,true)); assert(root.scheduler.maintenance_spent==saved.spent)
  x.phase='running'; loaded=false; x.resumed=true; log('TC_PRESENT_COLD_RETAINED')
 end
 fuel()
 local profiler=game.create_profiler(); scheduler.tick(event.tick); profiler.stop()
 assert(c.status=='running' or x.phase=='stopped' and c.status=='stopped'
   or x.phase=='faulting' and c.status=='faulted',serpent.line(c.diagnostic))
 x.steps=x.steps+1; assert(x.steps<1500,'presentation and staged-example scenario deadline')
 assert(root.scheduler.maintenance_spent<=200000 and root.ledger.total<=1000000)
 audit(s)
 if x.steps%30==0 then log({'','TC_PRESENT_SCHEDULER_CPU step=',x.steps,' ',profiler}) end
 if x.pressured and x.pressure_tick==event.tick then
  local spent=root.scheduler.maintenance_spent
  assert(not scheduler.try_maintenance(function() scheduler.maintenance(root,event.tick,true)(x.pressure_work) end))
  assert(root.scheduler.maintenance_spent==spent)
  for id,front in pairs(x.pressure_fronts) do assert(s.groups[id].render==front and front.cells[1].background.visible) end
  log('TC_PRESENT_COMMIT_ONE_SHORT_OK')
 end
 local p=s.presentation; local lane=c.monitor_sync and p and p.lanes[c.monitor_sync.key]
 if lane then x.published=math.max(x.published,lane.presented_sequence) end
 if not x.saved and lane and lane.job and lane.job.member<=#lane.job.frames and lane.pending and lane.presented_sequence>0 then
  x.saved={presentation=p,jobs=p.jobs,job=lane.job,front=s.groups[x.ids[1]].render,spent=root.scheduler.maintenance_spent,
   tick=event.tick,boots=c.state.boots,n=c.state.n}
  x.phase='frozen'; loaded=false; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
 elseif x.phase=='running' and x.resumed and c.state.n>70 and settled(s,c) then
  assert(x.published>=3 and c.state.boots==1)
  for _,id in ipairs(x.ids) do assert(s.groups[id].render.cells[1].value[1]==90) end
  log('TC_PRESENT_FULL_WORLD_OK steps='..x.steps..' selected_sequence='..x.published..' groups='..#s.order)
  x.phase='dense'; x.changed_at=event.tick; x.before_dense=s.groups[x.ids[1]].render.cells[2].glyph
  for _,id in ipairs(x.ids) do local g=s.groups[id]
   for y=1,g.model.height do model.calls.setCursorPos(g.model,nop,1,y); model.calls.write(g.model,nop,string.rep('X',g.model.width)) end
   renderer.participate(g)
  end
 elseif x.phase=='dense' and settled(s,c) then
  assert(event.tick-x.changed_at<=256 and not x.before_dense.valid and x.pressured)
  for _,id in ipairs(x.ids) do for _,cell in ipairs(s.groups[id].render.cells) do assert(cell.value[1]==88) end end
  log('TC_PRESENT_DENSE_GROUP_OK')
  for _,ref in ipairs(c.monitor_sync.members) do guest(c,"peripheral.call("..string.format('%q',ref.name)..",'red','setTextScale',0.5)") end
  x.phase='overcapacity'; x.changed_at=event.tick
 elseif x.phase=='overcapacity' and lane and lane.status=='blocked' and lane.diagnostic.code=='E_CAPACITY' then
  assert(#c.monitor_sync.members==4)
  for _,ref in ipairs(c.monitor_sync.members) do guest(c,"peripheral.call("..string.format('%q',ref.name)..",'red','setTextScale',1)") end
  x.phase='capacity-restore'; x.changed_at=event.tick
 elseif x.phase=='capacity-restore' and settled(s,c) then
  assert(event.tick-x.changed_at<=256)
  log('TC_PRESENT_CAPACITY_RESTORED_OK')
  -- New local geometries: 3x6 north, 6x3 east, 6x6 south, 1x1 west.
  for i=1,4 do for j,id in ipairs(x.walls[i]) do
   if i<=2 and (j-1)%6>=3 or i==4 and j~=1 then lifecycle.remove(id,'fixture-resize',true) end
  end end
  local bridges={build('computer',6,0),build('computer',16,0)}
  for _,color in ipairs({'red','green'}) do
   for i=1,2 do
    local endpoint=registry.record(x.walls[i][i<=2 and 3 or 6])
    wire(registry.record(x.walls[i][1]),endpoint,color)
    if i<=2 then
      wire(endpoint,bridges[i],color); wire(bridges[i],registry.record(x.walls[i+1][1]),color)
    end
   end
  end
  x.phase='mixed'; x.changed_at=event.tick
 elseif x.phase=='mixed' and not s.job and settled(s,c) then
  local expected={{3,6},{6,3},{6,6},{1,1}}
  for i=1,4 do local g=monitor.resolve(registry.record(x.walls[i][1])); assert(g.width_tiles==expected[i][1] and g.height_tiles==expected[i][2]) end
  assert(event.tick-x.changed_at<=256)
  log('TC_PRESENT_MIXED_GEOMETRY_OK')
  x.strips={}
  for i=1,6 do
   local vertical=build('monitor',50,i)
   local horizontal=build('monitor',60+i,0)
   if i==1 then x.strips={vertical.id,horizontal.id} end
  end
  x.phase='strips'; x.changed_at=event.tick
 elseif x.phase=='strips' and settled(s,c) then
  for i,id in ipairs(x.strips) do local g=monitor.resolve(registry.record(id))
   assert(g.width_tiles==(i==1 and 1 or 6) and g.height_tiles==(i==1 and 6 or 1))
   assert(g.render.width==g.model.width and g.render.height==g.model.height and #g.render.cells==g.model.width*g.model.height)
  end
  log('TC_PRESENT_NATIVE_STRIPS_OK')
  x.outage=x.walls[1][1]; x.phase='outage'; x.changed_at=event.tick
 elseif x.phase=='outage' and s.groups[x.ids[1]] and not c.monitor_sync_diagnostic then
  local g=monitor.resolve(registry.record(x.outage))
  if g.render and g.render.hidden then
   assert(lane.status=='blocked' and lane.diagnostic.code=='E_UNPOWERED')
   guest(c,"local status=peripheral.getMonitorSyncGroup(); local m=peripheral.wrap(status.members[1].name,status.members[1].wire); assert(m.getLimits().cells==10584)")
   x.outage=nil; x.phase='restoring'; x.changed_at=event.tick
  end
 elseif x.phase=='restoring' and settled(s,c) then
  assert(event.tick-x.changed_at<=256)
  x.wait_sequence=lane.presented_sequence; x.changed_at=event.tick
  for i=1,3 do guest(c,"peripheral.call("..string.format('%q',c.monitor_sync.members[i].name)..",'red','setCursorBlink',false)") end
  x.phase='waiting-round'
 elseif x.phase=='waiting-round' and event.tick-x.changed_at>=10 then
  assert(lane.presented_sequence==x.wait_sequence and lane.status=='waiting')
  guest(c,"peripheral.call("..string.format('%q',c.monitor_sync.members[4].name)..",'red','setCursorBlink',false)")
  x.phase='complete-round'
 elseif x.phase=='complete-round' and settled(s,c) then
  assert(lane.presented_sequence>x.wait_sequence); log('TC_PRESENT_NOOP_BARRIER_OK')
  x.owner_outage=true; x.owner_selection=c.monitor_sync; x.changed_at=event.tick; x.phase='owner-outage'
 elseif x.phase=='owner-outage' and event.tick-x.changed_at>=5 then
  assert(not c.powered and c.monitor_sync==x.owner_selection and lane.status=='blocked')
  x.owner_outage=nil; x.phase='owner-restoring'; x.changed_at=event.tick
 elseif x.phase=='owner-restoring' and c.powered and settled(s,c) then
  assert(c.monitor_sync==x.owner_selection and event.tick-x.changed_at<=256)
  guest(c,"assert(select('#',peripheral.setMonitorSyncGroup({}))==0); assert(peripheral.getMonitorSyncGroup().status=='none')")
  assert(not c.monitor_sync); x.phase='released'
 elseif x.phase=='released' and settled(s,c) then
  log('TC_PRESENT_RELEASE_POWER_CLEANUP_OK')
  runtime.stop(c.id); assert(runtime.save(c.id,plot_source,c.saved_revision)); assert(runtime.activate(c.id,event.tick))
  x.phase='plot'; x.plot_peak_work=0; x.plot_peak_allocations=0; x.plot_sample=0
 elseif x.phase=='plot' then
  local machine=root.ledger.machines[c.id]
  if machine then
   x.plot_peak_work=math.max(x.plot_peak_work,machine.work)
   x.plot_peak_allocations=math.max(x.plot_peak_allocations,machine.allocations)
  end
  local sample=c.state.plot_sample or 0
  if sample>x.plot_sample then
   x.plot_sample=sample
   local value=math.sin(event.tick/120)
   for _,view in ipairs(c.state.plot_views) do local g=s.groups[view.name]
    local col=1+(sample-1)%view.width; local row=1+math.floor((1-value)*(view.height-1)/2+0.5)
    for i=1,view.width do assert(g.model.cells[(row-1)*view.width+i][1]==(i==col and 42 or 32)) end
   end
  end
  if sample>=3 and lane and lane.presented_sequence>=2 then
   assert(#c.state.plot_views==4 and x.plot_peak_work<=100000 and x.plot_peak_allocations<=16384)
   for _,view in ipairs(c.state.plot_views) do
    local image=s.groups[view.name].render.snapshot
    local row=1+math.floor((1-math.sin(image.sealed_tick/120))*(image.height-1)/2+0.5)
    assert(image.y==row and view.wire=='red')
   end
   log('TC_PRESENT_PLOT_OK samples='..sample..' peak_work='..x.plot_peak_work..' peak_allocations='..x.plot_peak_allocations)
   for _,color in ipairs({'red','green'}) do
    assert(lifecycle.connector(registry.record(x.walls[3][6]),'network',color).disconnect_from(
      lifecycle.connector(registry.record(x.walls[4][1]),'network',color)))
   end
   x.phase='plot-disconnected'; x.changed_at=event.tick
  end
 elseif x.phase=='plot-disconnected' and not s.job and c.state.plot_stage=='draw' and #c.state.plot_views==3 and lane and #lane.members==3 then
  assert(event.tick-x.changed_at<400)
  local added=build('monitor',-3,-4); x.added=added.id; wire(c,added,'red')
  x.phase='plot-added'; x.changed_at=event.tick
 elseif x.phase=='plot-added' and not s.job and c.state.plot_stage=='draw' and #c.state.plot_views==4 and lane and #lane.members==4 then
  local found=false; for _,view in ipairs(c.state.plot_views) do if view.name==monitor.resolve(registry.record(x.added)).id then found=true end end
  if not found then return end
  assert(event.tick-x.changed_at<400)
  lifecycle.remove(x.added,'fixture-plot-remove',true)
  for _,color in ipairs({'red','green'}) do wire(registry.record(x.walls[3][6]),registry.record(x.walls[4][1]),color) end
  x.phase='plot-reconnected'; x.changed_at=event.tick
 elseif x.phase=='plot-reconnected' and not s.job and c.state.plot_stage=='draw' and #c.state.plot_views==4 and lane and #lane.members==4 then
  local found=false; local last=monitor.resolve(registry.record(x.walls[4][1])).id
  for _,view in ipairs(c.state.plot_views) do if view.name==last then found=true end end
  if not found then return end
  assert(event.tick-x.changed_at<400)
  guest(c,"peripheral.call("..string.format('%q',last)..",'red','setTextScale',5)")
  x.tiny=last; x.phase='plot-resized'; x.changed_at=event.tick
 elseif x.phase=='plot-resized' and not s.job and c.state.plot_stage=='draw' and lane and lane.presented_sequence>0 then
  local tiny
  for _,view in ipairs(c.state.plot_views) do if view.name==x.tiny then tiny=view end end
  if not tiny or tiny.width~=2 or tiny.height~=1 then return end
  assert(event.tick-x.changed_at<400 and c.status=='running')
  log('TC_PRESENT_PLOT_REDISCOVERY_TINY_OK')
  -- Stop cancels a selected in-flight epoch, while retaining successful model writes.
  local g=s.groups[x.tiny]; local accepted=g.model.cells
  runtime.stop(c.id); assert(not c.monitor_sync and g.model.cells==accepted)
  x.phase='stopped'
 elseif x.phase=='stopped' then
  local p=s.presentation
  if #p.jobs>0 or #p.retired>0 or #p.orphans>0 or p.pending_cells>0 then return end
  assert(c.status=='stopped' and not c.monitor_sync)
  log('TC_PRESENT_STOP_RETIREMENT_OK')
  local ref={name=x.tiny,wire='red'}
  local text="return {api_version=1,handlers={start=function(e) local name="..string.format('%q',ref.name)..
    "; peripheral.setMonitorSyncGroup({{name=name,wire='red'}}); peripheral.call(name,'red','setCursorPos',1,1); "..
    "peripheral.call(name,'red','write','F'); error('fixture accepted-write fault') end}}"
  assert(runtime.save(c.id,text,c.saved_revision)); assert(runtime.activate(c.id,event.tick))
  x.phase='faulting'; x.changed_at=event.tick
 elseif x.phase=='faulting' and c.status=='faulted' then
  local g=s.groups[x.tiny]
  assert(not c.monitor_sync and g.model.cells[1][1]==70)
  local p=s.presentation
  if #p.jobs>0 or #p.retired>0 or #p.orphans>0 or p.pending_cells>0 then return end
  assert(g.render.cells[1].value[1]==70 and event.tick-x.changed_at<=256)
  log('TC_PRESENT_FAULT_ACCEPTED_WRITES_OK'); x.phase='done'; log('TC_COLD_OK')
 end
end
return M
