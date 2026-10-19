-- Diagnostic acceptance campaign, actual production ticks and unchanged budgets.
-- A completed diagnostic is NOT an envelope pass: inspect TC_ENVELOPE_GATE.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local runtime=require('scripts.runtime.computer')
local monitor=require('scripts.services.monitor')
local model=require('scripts.monitor-model')
local defs=require('scripts.device-definitions')
local profile = {computers=4,subscriptions=1,maximum=false} -- ENVELOPE_PROFILE
local M={}; local loaded=false
local function f() return storage.tc_envelope end
local function nop() end
local function build(kind,x,y)
  local b=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})
  local r=assert(lifecycle.build(b)); lifecycle.power_entity(r).energy=100000; r.powered=true
  return r
end
local function wire(a,b)
  assert(lifecycle.connector(a,'network','red').connect_to(lifecycle.connector(b,'network','red')))
end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
-- Observe the unchanged sampler's headroom; these hooks do not spend or renew it.
scheduler.register_phase('sample','00-envelope-observe',function()
  if f() then f().before_sample=registry.get().scheduler.maintenance_spent end
end)
local function gate(name,passed,detail)
  log('TC_ENVELOPE_GATE '..helpers.table_to_json{name=name,passed=passed,detail=detail})
end
local function metrics()
  local root=registry.get(); local s=root.monitors; local p=s.presentation
  local pending=0; local cells=0; local presented=0
  for _,id in ipairs(s.order) do local g=s.groups[id]
    cells=cells+g.model.width*g.model.height
    if g.render and g.render.presented_revision==g.model.revision then presented=presented+1 else pending=pending+1 end
  end
  return {groups=#s.order,cells=cells,pending=pending,presented=presented,topology=not not s.job,
    staging=p and p.staging_cells or 0,retired=p and p.retired_cells or 0,
    jobs=p and #p.jobs or 0,orphans=p and #p.orphans or 0,
    maintenance=root.scheduler.maintenance_spent,reservation=root.scheduler.render_reserved_work,
    before_sample=f().before_sample}
end
local function ready(m) return not m.topology and m.pending==0 and m.staging==0 and m.retired==0 and m.jobs==0 and m.orphans==0 end
function M.run()
  storage.tc_envelope={phase='initial',start=game.tick,computers={},logic={},walls={},steps=0,peak_objects=0}
  local x=f()
  for i=1,profile.computers do
    local col,row=(i-1)%16*8,-10-math.floor((i-1)/16)*8
    if not profile.maximum then col,row=(i-1)%2*3,-10+math.floor((i-1)/2)*3 end
    x.computers[i]=build('computer',col,row).id
    if profile.maximum or i==1 then
      local lx,ly=col+3,row
      if not profile.maximum then lx,ly=6,-8 end
      x.logic[i]=build('logic',lx,ly).id
      if profile.maximum then x.logic[i+64]=build('logic',col+3,row+3).id end
      local signal=assert(game.surfaces[1].create_entity{name='constant-combinator',position={lx+3,ly},force='player'})
      signal.get_or_create_control_behavior().add_section().filters={{index=1,value={type='virtual',name='signal-A',quality='normal'},min=1}}
      assert(signal.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(
        lifecycle.connector(registry.record(x.logic[i]),'input','red')))
    end
    if not profile.maximum then x.logic[i]=x.logic[1] end
  end
  local wall_count=profile.maximum and 10 or 2
  for i=1,wall_count do
    local w,h=6,6
    if i==7 then w,h=3,6 elseif i==8 then w,h=6,3 elseif i>8 then w,h=1,1 end
    if not profile.maximum then w,h=3,2; if i==2 then w,h=1,1 end end
    local wall={}; x.walls[i]=wall
    for y=0,h-1 do for col=0,w-1 do wall[#wall+1]=build('monitor',(i-1)%4*10+col,10+math.floor((i-1)/4)*10+y).id end end
  end
  -- Six 36-tile walls, two 18-tile walls and four singletons = 256 tiles.
  if profile.maximum then
    x.walls[11]={build('monitor',30,30).id}; x.walls[12]={build('monitor',33,30).id}
  end
  for i,id in ipairs(x.computers) do wire(registry.record(id),registry.record(x.logic[i])) end
  local tiles=0; for _,wall in ipairs(x.walls) do tiles=tiles+#wall end
  assert(tiles==(profile.maximum and 256 or 7))
  log('TC_ENVELOPE_SETUP '..helpers.table_to_json{computers=profile.computers,
    logic=profile.maximum and 128 or 1,monitor_tiles=tiles,subscriptions=profile.computers*profile.subscriptions,
    profile=profile.maximum and 'maximum' or 'representative'})
  local universe=(#prototypes.item+#prototypes.fluid+#prototypes.virtual_signal+#prototypes.recipe)*#prototypes.quality
  log('TC_ENVELOPE_QUERY '..helpers.table_to_json{universe=universe,one_input_precharge=universe*8+64*16+16,
    maximum_subscription_order_precharge=1024^2+128^2+1,maintenance=200000,baseline_nonrender=140000,boost_nonrender=40000})
end
function M.on_load() loaded=true end
function M.on_configuration_changed() error('unexpected upgrade') end
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  if x.phase=='frozen' then
    if not loaded then return end
    local root=registry.get()
    assert(root.scheduler.maintenance_spent==x.saved.spent and root.scheduler.maintenance_tick==x.saved.tick)
    assert(root.monitors.presentation==x.saved.presentation)
    x.phase='subscriptions'; x.next_computer=1; x.subscription_start=event.tick; loaded=false
    log('TC_ENVELOPE_COLD_UNCHANGED')
  end
  local root=registry.get()
  for _,id in ipairs(root.order) do local r=registry.record(id)
    if r and r.body.valid then lifecycle.power_entity(r).energy=100000 end
  end
  local before={running=0,subscriptions=0}
  for _,id in ipairs(x.computers) do local c=registry.computer(id)
    if c.status=='running' then before.running=before.running+1; before.subscriptions=before.subscriptions+count(c.subscriptions) end
  end
  local profiler=game.create_profiler(); scheduler.tick(event.tick); profiler.stop()
  x.steps=x.steps+1
  log({'','TC_ENVELOPE_CPU tick=',event.tick,' phase=',x.phase,' ',profiler})
  assert(root.scheduler.maintenance_spent<=200000 and root.ledger.total<=4800000)
  local s=root.monitors; local p=s.presentation
  if p then
    assert(p.front_cells<=80000 and p.pending_cells<=80000 and p.staging_cells<=10584 and p.retired_cells<=10584)
    assert(p.front_frames<=256 and p.staging_frames<=256 and p.retired_frames<=256)
  end
  local m=metrics()
  if x.steps%32==0 then log('TC_ENVELOPE_PROGRESS '..helpers.table_to_json(m)) end
  if x.phase=='initial' and not s.job and #s.order==(profile.maximum and 12 or 2) then
    for _,id in ipairs(s.order) do local g=s.groups[id]; model.scale(g.model,g.width_tiles,g.height_tiles,nop,0.5)
      for y=1,g.model.height do model.calls.setCursorPos(g.model,nop,1,y); model.calls.write(g.model,nop,string.rep('A',g.model.width)) end
    end
    x.phase='maximum-grid'; x.changed=event.tick
    log('TC_ENVELOPE_MAXIMUM '..helpers.table_to_json(metrics()))
  elseif x.phase=='maximum-grid' and (ready(m) or event.tick-x.changed>=256) then
    gate(profile.maximum and 'maximum-grid-256' or 'initial-grid-256',ready(m),{ticks=event.tick-x.changed,metrics=m})
    x.phase='continuous'; x.changed=event.tick
  elseif x.phase=='continuous' then
    -- Trusted host writer isolates renderer cost; not guest callback acceptance.
    for _,id in ipairs(s.order) do local g=s.groups[id]
      model.calls.setCursorPos(g.model,nop,1,1); model.calls.write(g.model,nop,string.rep(event.tick%2==0 and 'B' or 'C',g.model.width))
    end
    if event.tick-x.changed>=64 then x.phase='quiescence'; x.changed=event.tick end
  elseif x.phase=='quiescence' and (ready(m) or event.tick-x.changed>=256) then
    gate('continuous-final-256',ready(m),{ticks=event.tick-x.changed,metrics=m})
    for i=1,profile.computers do
      local input=lifecycle.connector(registry.record(x.logic[i]),'input','red')
      local signals=input.owner.get_signals(input.wire_connector_id)
      assert(input.real_connection_count>0 and #signals==1 and signals[1].signal.name=='signal-A' and signals[1].count==1)
    end
    log('TC_ENVELOPE_NATIVE_INPUTS count='..(profile.maximum and 64 or 1)..' signal=signal-A value=1')
    x.saved={spent=root.scheduler.maintenance_spent,tick=root.scheduler.maintenance_tick,presentation=p}
    x.phase='frozen'; loaded=false; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif x.phase=='subscriptions' then
    local active,subs=0,0; local failed={}
    for _,id in ipairs(x.computers) do local c=registry.computer(id)
      if c.status=='running' then active=active+1; subs=subs+count(c.subscriptions)
      elseif c.status=='faulted' then failed[#failed+1]={id=id,diagnostic=c.diagnostic} end
    end
    if #failed>0 then
      gate('combined-active-subscriptions',false,{attempted=x.next_computer-1,running=active,subscriptions=subs,before=before,failures=failed,metrics=m})
      x.phase='done'; log('TC_COLD_OK envelope-diagnostic-complete'); return
    end
    local id=x.computers[x.next_computer]
    if id then
      local c=registry.computer(id); local target=x.logic[x.next_computer]
      local source="return {api_version=1,handlers={start=function(e) computer.setState('subscriptions',0); computer.every(1,'work') end, changed=function(e) computer.setState('signals',e.sample_tick) end, work=function(e) local n=computer.getState('subscriptions'); if n<"..profile.subscriptions.." then local io=peripheral.wrap("..string.format('%q',target)..",'red'); io.subscribe({input='red',initial=false},'changed'); computer.setState('subscriptions',n+1) end; local sum=0; for i=1,128 do sum=sum+i end; computer.setState('sum',sum) end}}"
      local ok,err=runtime.save(c.id,source,c.saved_revision); assert(ok,serpent.line(err))
      local activated,why=runtime.activate(c.id,event.tick)
      if not activated then gate('combined-activation',false,{computer=x.next_computer,diagnostic=why}); x.phase='done'; log('TC_COLD_OK envelope-diagnostic-complete'); return end
      x.next_computer=x.next_computer+1
    elseif active==profile.computers and subs==profile.computers*profile.subscriptions then
      local working=0
      for _,cid in ipairs(x.computers) do if registry.computer(cid).state.sum==8256 then working=working+1 end end
      assert(working==profile.computers,'subscriptions admitted without useful work')
      gate('combined-active-subscriptions',true,{running=active,subscriptions=subs,working=working,metrics=m})
      x.phase='done'; log('TC_COLD_OK envelope-diagnostic-complete')
    elseif event.tick-x.subscription_start>=256 then
      local working=0; local queued=0; local timers=0
      for _,cid in ipairs(x.computers) do local c=registry.computer(cid)
        if c.state.sum==8256 then working=working+1 end
        queued=queued+#c.queue; timers=timers+count(c.timers)
      end
      gate('combined-active-subscriptions',false,{reason='bounded service window exhausted',ticks=event.tick-x.subscription_start,
        running=active,subscriptions=subs,working=working,queued=queued,timers=timers,before=before,metrics=m})
      x.phase='done'; log('TC_COLD_OK envelope-diagnostic-complete')
    end
  end
  assert(x.steps<1200,'diagnostic wall of actual ticks exceeded')
end
return M
