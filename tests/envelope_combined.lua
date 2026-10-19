-- Representative combined factory: real ticks, native wires, compiled guests.
-- All observations are outside the full-scheduler CPU interval except the small
-- common forwarding counter probes explicitly recorded in wrapper provenance.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local runtime=require('scripts.runtime.computer')
local model=require('scripts.monitor-model')
local monitor=require('scripts.services.monitor')
local defs=require('scripts.device-definitions')
local observer=require('tests.envelope_observer')
local config=require('tests.envelope_config')
local M={}; local loaded=false
local function f() return storage.tc_envelope_combined end
local function count(t) local n=0; for _,sub in pairs(t) do if sub.event_name=='signal_changed' then n=n+1 end end; return n end
local function nop() end
local function report(name,value) log('TC_COMBINED_'..name..' '..helpers.table_to_json(value)) end
local function gate(name,passed,detail) log('TC_ENVELOPE_GATE '..helpers.table_to_json{name=name,passed=passed,detail=detail}) end
local function build(kind,x,y)
  local b=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})
  local r=assert(lifecycle.build(b)); lifecycle.power_entity(r).energy=100000; r.powered=true; return r
end
local function wire(a,b,ar,br)
  assert(lifecycle.connector(a,ar or 'network','red').connect_to(lifecycle.connector(b,br or 'network','red')))
end
local function native_wire(e,r,role)
  assert(e.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(lifecycle.connector(r,role,'red')))
end
local function snapshot()
  local root=registry.get(); local x=f()
  return {spent=root.scheduler.maintenance_spent,tick=root.scheduler.maintenance_tick,presentation=root.monitors.presentation,
    state=registry.computer(x.computers[1]).state,run=registry.computer(x.computers[1]).run_id,database=registry.record(x.kv).database}
end
local function unchanged()
  local a,b=f().saved,snapshot()
  for k,v in pairs(a) do assert(b[k]==v,'cold mutation '..k) end
end
function M.on_load() loaded=true; if f().phase=='frozen' then unchanged() end end
function M.on_configuration_changed() error('unexpected configuration change') end
function M.run()
  local profiler=game.create_profiler()
  if remote.interfaces.freeplay then
    remote.call('freeplay','set_skip_intro',true)
    remote.call('freeplay','set_disable_crashsite',true)
  end
  local x={phase='boot',start=game.tick,steps=0,computers={},walls={},publications=0,changes=0,latencies={},peaks={},last_work={},max_work_gap={}}
  storage.tc_envelope_combined=x
  local s=game.surfaces[1]; local tiles={}
  for y=-12,12 do for col=-12,16 do tiles[#tiles+1]={name='landfill',position={col,y}} end end
  s.set_tiles(tiles)
  for _,e in ipairs(s.find_entities_filtered{area={{-12,-12},{16,12}},type={'tree','simple-entity','cliff'}}) do e.destroy() end
  for _,pos in ipairs({{0,0},{3,0},{0,-3},{3,-3}}) do x.computers[#x.computers+1]=build('computer',pos[1],pos[2]).id end
  local io=build('logic',6,0); x.logic=io.id
  local db=build('kv',6,-3); x.kv=db.id
  local cfg=build('configurator',6,3); x.configurator=cfg.id
  local c={}; for i,id in ipairs(x.computers) do c[i]=registry.record(id) end
  wire(c[1],c[2]); wire(c[1],c[3]); wire(c[2],c[4]); wire(c[2],io); wire(c[4],db); wire(io,cfg)
  for n,shape in ipairs({{3,2},{1,1}}) do
    local wall={}; x.walls[n]=wall
    for y=0,shape[2]-1 do for col=0,shape[1]-1 do wall[#wall+1]=build('monitor',col+(n-1)*6,5+y).id end end
  end
  wire(c[1],registry.record(x.walls[1][1])); wire(cfg,registry.record(x.walls[2][1]))
  local input=assert(s.create_entity{name='constant-combinator',position={9,0},force='player'})
  x.input=input
  local cb=input.get_or_create_control_behavior()
  while cb.sections_count>0 do cb.remove_section(1) end
  cb.add_section().filters={{index=1,value={type='virtual',name='signal-A',quality='normal'},min=1}}
  native_wire(input,io,'input')
  for i=1,2 do
    local target=assert(s.create_entity{name='constant-combinator',position={9,3+i*2},force='player'})
    native_wire(target,cfg,'targets')
  end
  -- Real electric supply also makes the native window free of power warnings.
  local supply=assert(s.create_entity{name='electric-energy-interface',position={-5,0},force='player'})
  supply.power_production=100000000; supply.power_usage=0
  s.create_entity{name='substation',position={-3,2},force='player'}
  s.create_entity{name='substation',position={7,-5},force='player'}
  s.create_entity{name='substation',position={9,5},force='player'}
  s.always_day=true
  report('SETUP',{computers=4,subscriptions=4,logic=1,kv=1,configurators=1,targets=2,monitor_tiles=7,shapes={{3,2},{1,1}},source='compiled descriptor handlers',signal_period=24})
  profiler.stop(); log({'','TC_COMBINED_CONSTRUCTION ',profiler})
end
local function program(index)
  local x=f(); local names={}
  for _,wall in ipairs(x.walls) do names[#names+1]=assert(monitor.resolve(registry.record(wall[1]))).id end
  local views=string.format("{{name=%q,wire='red'},{name=%q,wire='red'}}",names[1],names[2])
  local source=[[return {api_version=1,handlers={
    start=function(e)
      local names=peripheral.getNames('red')
      computer.setState('discovered',#names)
      local io=peripheral.wrap(LOGIC,'red')
      io.subscribe({input='red',initial=true},'changed')
      computer.setState('work',0)
      PRODUCER_START
      computer.setState('timer',computer.every(2,'work'))
    end,
    changed=function(e)
      local value=0
      for _,entry in ipairs(e.current) do value=entry.count end
      computer.setState('signal',value)
      computer.setState('sample_tick',e.sample_tick)
      computer.setState('delivery_tick',e.tick)
      if value==100 then computer.cancelTimer(computer.getState('timer')) end
      PRODUCER_CHANGED
    end,
    touched=function(e)
      local n=(computer.getState('touch') or 0)+1
      computer.setState('touch',n)
      computer.setState('touch_tick',e.tick)
      local m=peripheral.wrap(e.peripheral,e.wire)
      m.setCursorPos(1,2); m.write('TOUCH '..tostring(n))
      -- Both selected members must participate even when the other is unchanged.
      local refs=VIEWS
      for _,ref in ipairs(refs) do peripheral.call(ref.name,ref.wire,'setCursorBlink',false) end
    end,
    work=function(e)
      local sum=0
      for i=1,128 do sum=sum+i end
      computer.setState('sum',sum)
      computer.setState('work',computer.getState('work')+1)
      computer.setState('work_tick',e.tick)
      local db=peripheral.wrap(DATABASE,'red')
      local value=string.rep(tostring(INDEX),1024)
      db.set('worker-INDEX',value)
      assert(db.get('worker-INDEX')==value)
      PRODUCER_WORK
    end
  }}]]
  local producer_start="peripheral.setMonitorSyncGroup("..views.."); computer.on('monitor_touch','touched')"
  local producer_work=[[local views=VIEWS
      local char=computer.getState('work')%2==0 and 'B' or 'C'
      for _,ref in ipairs(views) do
        local m=peripheral.wrap(ref.name,ref.wire)
        local w,h=m.getSize()
        m.setCursorPos(1,1); m.write(string.rep(char,w))
      end
      local cfg=peripheral.wrap(CONFIGURATOR,'red')
      computer.setState('targets',#cfg.getDevices('red'))]]
  source=source:gsub('PRODUCER_START',index==1 and producer_start or '')
  source=source:gsub('PRODUCER_CHANGED',function() return index==1 and [[local refs=VIEWS
      for _,ref in ipairs(refs) do
        local m=peripheral.wrap(ref.name,ref.wire)
        m.setCursorPos(1,3); m.write(string.char(64+value))
      end
      computer.setState('signal_model_tick',e.tick)]] or '' end)
  source=source:gsub('PRODUCER_WORK',function() return index==1 and producer_work or '' end)
  source=source:gsub('VIEWS',function() return views end)
  source=source:gsub('LOGIC',string.format('%q',x.logic)):gsub('DATABASE',string.format('%q',x.kv))
  source=source:gsub('CONFIGURATOR',string.format('%q',x.configurator)):gsub('INDEX',tostring(index))
  return source
end
local function ready()
  local s=registry.get().monitors; local p=s.presentation
  if s.job or not p or #p.jobs>0 or #p.orphans>0 or p.staging_cells>0 or p.retired_cells>0 or p.pending_cells>0 then return false end
  for _,id in ipairs(s.order) do local g=s.groups[id]; if not g.render or g.render.presented_revision~=g.model.revision then return false end end
  return true
end
local function observe(tick)
  local x=f(); local root=registry.get(); local p=root.monitors.presentation
  assert(root.scheduler.maintenance_spent<=200000 and root.ledger.total<=4800000)
  local o=observer.sample
  assert(o.prepared+o.cleaned<=1024,'shared preparation/cleanup ceiling')
  for k,v in pairs(o) do x.peaks[k]=math.max(x.peaks[k] or 0,v) end
  x.peaks.prepare_cleanup=math.max(x.peaks.prepare_cleanup or 0,o.prepared+o.cleaned)
  x.peaks.maintenance=math.max(x.peaks.maintenance or 0,root.scheduler.maintenance_spent)
  x.peaks.guest=math.max(x.peaks.guest or 0,root.ledger.total)
  for _,machine in pairs(root.ledger.machines) do
    for kind,limit in pairs({work=500000,allocations=81920,compile=1250000}) do
      assert(machine[kind]<=limit,kind..' ceiling')
      local key='machine_'..kind; x.peaks[key]=math.max(x.peaks[key] or 0,machine[kind])
    end
  end
  local reserved=root.scheduler.render_reserved_work
  x.reservations=x.reservations or {baseline=0,boost=0}
  if reserved==60000 then x.reservations.baseline=x.reservations.baseline+1
  else
    assert(reserved<=160000 and not x.previous_boost,'missing baseline service opportunity')
    x.reservations.boost=x.reservations.boost+1
  end
  x.previous_boost=reserved>60000
  if not p then return end
  local L=model.limits
  for name,limit in pairs({front_cells=L.aggregate_cells,pending_cells=L.render_snapshot_cells,staging_cells=L.render_staging_cells,
    retired_cells=L.render_retired_cells,front_frames=L.tiles,staging_frames=L.render_staging_frames,retired_frames=L.render_retired_frames}) do
    assert(p[name]<=limit,name); x.peaks[name]=math.max(x.peaks[name] or 0,p[name])
  end
  local retained=0
  for _,id in ipairs(root.monitors.order) do local g=root.monitors.groups[id]; retained=retained+g.model.width*g.model.height end
  retained=retained+p.front_cells+p.pending_cells+p.staging_cells+p.retired_cells
  assert(retained<=L.render_retained_cells,'retained cell bound')
  x.peaks.retained_cells=math.max(x.peaks.retained_cells or 0,retained)
  -- Audit real object inventory after the timed scheduler, including device art.
  local objects=rendering.get_all_objects(); assert(#objects<=L.render_object_limit)
  x.peaks.native_objects=math.max(x.peaks.native_objects or 0,#objects)
  local owned={}
  local function object(o) if o and o.valid then owned[o.id]=true end end
  local function frame(r)
    if not r then return end
    object(r.panel); object(r.cursor)
    for _,cell in ipairs(r.cells) do if cell then object(cell.background); object(cell.glyph) end end
  end
  for _,g in pairs(root.monitors.groups) do frame(g.render) end
  for _,job in ipairs(p.jobs) do for _,r in ipairs(job.frames) do frame(r) end end
  for _,r in ipairs(p.retired) do frame(r) end
  for _,r in ipairs(p.orphans) do frame(r) end
  for _,id in ipairs(root.order) do local r=registry.record(id); if r.status_art then object(r.status_art.object) end end
  local owned_count=0; for _ in pairs(owned) do owned_count=owned_count+1 end
  assert(owned_count==#objects,'unowned native render object')
  local c=registry.computer(x.computers[1]); local lane=c.monitor_sync and p.lanes[c.monitor_sync.key]
  if lane and lane.presented_sequence>0 and lane.presented_tick~=x.last_publication then
    local char
    for _,ref in ipairs(lane.members) do local r=root.monitors.groups[ref.name].render
      assert(r.presented_tick==lane.presented_tick and r.presented_sequence==lane.presented_sequence)
      local value=r.snapshot.cells[1][1]
      if char then assert(value==char,'incoherent selected publication') end; char=value
      assert(r.cells[1].background.visible)
      if value~=32 then assert(r.cells[1].glyph.valid and r.cells[1].glyph.visible) end
      x.peaks.seal_to_publication=math.max(x.peaks.seal_to_publication or 0,tick-r.snapshot.sealed_tick)
    end
    x.last_publication=lane.presented_tick; x.publications=x.publications+1
    if x.expected then
      local complete=true
      for _,ref in ipairs(lane.members) do local r=root.monitors.groups[ref.name].render
        if r.snapshot.cells[r.width*2+1][1]~=64+x.expected then complete=false end
      end
      if complete and x.signal_visible~=x.expected then
        x.signal_visible=x.expected
        x.visible_latencies=x.visible_latencies or {}
        x.visible_latencies[#x.visible_latencies+1]={change=x.changes,input_tick=x.changed,
          model_tick=c.state.signal_model_tick,publication_tick=lane.presented_tick}
      end
    end
  end
end
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  if x.phase=='frozen' then
    if not loaded then return end
    unchanged(); report('COLD_UNCHANGED',{}); log('TC_ENVELOPE_COLD_UNCHANGED')
    loaded=false; x.phase='sustained'; x.window=event.tick; x.resumed=true; x.change_at=event.tick+24
  else loaded=false end
  local root=registry.get()
  for _,id in ipairs(root.order) do local r=registry.record(id); if r and r.body.valid then lifecycle.power_entity(r).energy=100000 end end
  if config.native then
    for _,player in pairs(game.players) do
      if not x.player_ready then
        player.set_controller{type=defines.controllers.god}; player.teleport({3.5,5.5},game.surfaces[1]); player.zoom=4
        player.game_view_settings.show_quickbar=false; player.game_view_settings.show_shortcut_bar=false
        x.player_ready=true
      end
    end
  end
  if x.phase=='sustained' and event.tick>=x.change_at and not config.native and not (x.resumed and event.tick-x.window>=384) then
    if x.expected then
      for _,id in ipairs(x.computers) do assert(registry.computer(id).state.signal==x.expected,'missed real input change') end
      assert(x.signal_visible==x.expected,'missed signal publication')
    end
    x.expected=(x.expected or 1)+1; x.changed=event.tick; x.changes=x.changes+1; x.delivered={}
    x.input.get_control_behavior().get_section(1).filters={{index=1,value={type='virtual',name='signal-A',quality='normal'},min=x.expected}}
    x.change_at=event.tick+24
  end
  observer.reset()
  local profiler=game.create_profiler(); scheduler.tick(event.tick); profiler.stop()
  x.steps=x.steps+1
  log({'','TC_ENVELOPE_CPU tick=',event.tick,' phase=',x.phase,' ',profiler})
  observe(event.tick)
  for i,id in ipairs(x.computers) do local c=registry.computer(id)
    assert(c.status~='faulted',serpent.line(c.diagnostic))
    if x.phase=='sustained' then
      if i==1 then x.sustained_ticks=(x.sustained_ticks or 0)+1 end
      assert(c.status=='running' and count(c.subscriptions)==1)
      assert(c.state.work_tick and event.tick-c.state.work_tick<=24,'useful-work tail starvation')
      if c.state.work_tick and x.last_work[i]~=c.state.work_tick then
        x.max_work_gap[i]=math.max(x.max_work_gap[i] or 0,x.last_work[i] and c.state.work_tick-x.last_work[i] or 0)
        x.last_work[i]=c.state.work_tick
      end
      if x.expected and c.state.signal==x.expected and not x.delivered[i] then
        assert(c.state.sample_tick>=x.changed)
        x.delivered[i]=true; x.latencies[#x.latencies+1]={computer=i,change=x.changes,input_tick=x.changed,sample_tick=c.state.sample_tick,delivery_tick=c.state.delivery_tick}
      end
    end
  end
  if not x.first_ready and x.phase=='warm' then
    local all=true
    for _,id in ipairs(x.computers) do local c=registry.computer(id)
      if c.state.sum~=8256 or count(c.subscriptions)~=1 or c.state.signal~=1 then all=false end
    end
    if all and registry.computer(x.computers[1]).state.targets==2 then x.first_ready=event.tick end
  end
  if x.phase=='boot' and not root.monitors.job and #root.monitors.order==2 then
    for _,id in ipairs(root.monitors.order) do local g=root.monitors.groups[id]; model.scale(g.model,g.width_tiles,g.height_tiles,nop,0.5) end
    x.phase='activate'; x.next=1; x.ready_start=event.tick
  elseif x.phase=='activate' then
    local id=x.computers[x.next]
    if id then
      local c=registry.computer(id); local source=program(x.next)
      helpers.write_file('envelope-source-'..x.next..'.lua',source,false)
      local profiler=game.create_profiler(); local ok,err=runtime.save(id,source,c.saved_revision); assert(ok,serpent.line(err))
      local active,why=runtime.activate(id,event.tick); profiler.stop(); assert(active,serpent.line(why))
      log({'','TC_COMBINED_COLD_ACTIVATION computer=',x.next,' bytes=',#source,' ',profiler}); x.next=x.next+1
    else x.phase='warm'; x.window=event.tick end
  elseif x.phase=='warm' and event.tick-x.window>=48 then
    local subs=0
    for _,id in ipairs(x.computers) do local c=registry.computer(id); assert(c.state.sum==8256); subs=subs+count(c.subscriptions) end
    report('WARM',{subscriptions=subs,state=registry.computer(x.computers[1]).state})
    assert(subs==4 and registry.computer(x.computers[1]).state.targets==2,'combined warm target/subscription inventory')
    assert(x.first_ready)
    gate('combined-active-subscriptions',true,{running=4,subscriptions=subs,cold_start_ticks=x.first_ready-x.start,warmup_ticks=event.tick-x.start,publications=x.publications})
    x.phase='sustained'; x.window=event.tick; x.change_at=event.tick+24
  elseif x.phase=='sustained' then
    if config.native then
      local c=registry.computer(x.computers[1])
      if c.state.touch and c.state.touch~=(x.last_touch or 0) then
        x.last_touch=c.state.touch; report('NATIVE_TOUCH',{input_tick=c.state.touch_tick,observed_tick=event.tick,count=x.last_touch})
      end
      local g=monitor.resolve(registry.record(x.walls[2][1])); local r=g.render
      local matches=r and x.last_touch and r.presented_tick>=c.state.touch_tick
      if matches then
        local text='TOUCH '..x.last_touch
        for i=1,#text do if r.snapshot.cells[g.model.width+i][1]~=text:byte(i) then matches=false end end
      end
      if matches and x.visible_touch~=x.last_touch then
        x.visible_touch=x.last_touch; report('NATIVE_PUBLICATION',{input_tick=c.state.touch_tick,published_tick=r.presented_tick,count=x.last_touch})
      end
      if event.tick%30==0 then helpers.write_file('envelope-state.json',helpers.table_to_json{tick=event.tick,phase=x.phase,touch=c.state.touch,touch_tick=c.state.touch_tick,visible=x.visible_touch},false) end
    elseif not x.resumed and event.tick-x.window>=192 then
      x.saved=snapshot(); x.phase='frozen'; loaded=false; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
    elseif x.resumed and event.tick-x.window>=384 then
      assert(#x.latencies==x.changes*4,'all changes must reach every subscriber')
      assert(#x.visible_latencies==x.changes,'all signal changes must be published')
      for _,gap in ipairs(x.max_work_gap) do assert(gap<=24,'unfair useful service') end
      assert(x.publications>=64,'render starvation')
      local workers={}
      for _,id in ipairs(x.computers) do local c=registry.computer(id)
        workers[#workers+1]={work=c.state.work,last_work_tick=c.state.work_tick,sum=c.state.sum,discovered=c.state.discovered}
      end
      report('SIMULTANEOUS',{ticks=x.sustained_ticks,changes=x.changes,deliveries=#x.latencies,publications=x.publications,latencies=x.latencies,visible_latencies=x.visible_latencies,peaks=x.peaks,max_work_gap=x.max_work_gap,reservations=x.reservations,workers=workers})
      gate('simultaneous-service',true,{changes=x.changes,deliveries=#x.latencies,publications=x.publications,max_work_gap=x.max_work_gap,peaks=x.peaks})
      -- A final real input asks each guest to cancel its own timer. The selected
      -- owner stays live until its final participation is published and retired.
      x.input.get_control_behavior().get_section(1).filters={{index=1,value={type='virtual',name='signal-A',quality='normal'},min=100}}
      x.phase='stopping'; x.changed=event.tick
    end
  elseif x.phase=='stopping' then
    local stopped=true
    for _,id in ipairs(x.computers) do local c=registry.computer(id)
      if next(c.timers) or #c.queue>0 or c.state.signal~=100 then stopped=false end
    end
    assert(event.tick-x.changed<24,'guest timer cancellation starved')
    if stopped then report('STOP',{ticks=event.tick-x.changed}); x.phase='quiescence'; x.changed=event.tick end
  elseif x.phase=='quiescence' and (ready() or event.tick-x.changed>=256) then
    gate('continuous-final-256',ready(),{ticks=event.tick-x.changed,peaks=x.peaks})
    x.phase='done'; log('TC_COLD_OK envelope-diagnostic-complete')
  end
  if not config.native then assert(x.steps<1100,'combined fixture deadline '..x.phase) end
end
return M
