-- Bounded combined factory benchmark. Uses actual production ticks/services;
-- no graphical player, synthetic time, credit resets or per-tick energy refill.
local config=require('tests.maintenance_benchmark_config')
local observer=require('tests.maintenance_benchmark_observer')
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local runtime=require('scripts.runtime.computer')
local editor=require('scripts.ui.editor-model')
local monitor=require('scripts.services.monitor')
local model=require('scripts.monitor-model')
local limits=require('scripts.runtime.limits')
local defs=require('scripts.device-definitions')
local M={}; local loaded=false
local function f() return storage.tc_mb end
local function emit(kind,value) log('TC_MB_'..kind..' '..helpers.table_to_json(value)) end
local function build(kind,x,y)
  local e=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})
  return assert(lifecycle.build(e))
end
local function connect(a,b,color,ar,br)
  assert(lifecycle.connector(a,ar or 'network',color).connect_to(lifecycle.connector(b,br or 'network',color)))
end
local function source(c,name,index)
  if config.workload=='idle' then return [[return {api_version=1,handlers={
    start=function(e) computer.every(60,'work') end,
    work=function(e) computer.setState('beats',(computer.getState('beats') or 0)+1); computer.setState('last',e.tick) end}}]] end
  local period=config.workload=='mixed' and 6 or 2
  local input=config.workload=='heavy' and index%2==0 and 'green' or 'red'
  return string.format([[return {api_version=1,handlers={
    start=function(e)
      local io=peripheral.find('logic_handler','red')
      io.subscribe({input=%q,initial=true,signals={{type='virtual',name='signal-A',quality='normal'}}},'changed')
      computer.every(%d,'work')
    end,
    changed=function(e)
      local io=peripheral.find('logic_handler','red')
      local value=io.readSignal(%q,{type='virtual',name='signal-A',quality='normal'})
      computer.setState('input',value); computer.setState('input_tick',e.tick)
      computer.setState('changes',(computer.getState('changes') or 0)+1)
      %s
    end,
    work=function(e)
      local n=(computer.getState('beats') or 0)+1
      computer.setState('beats',n); computer.setState('last',e.tick)
      local db=peripheral.find('kv_database','red')
      db.set(%q,tostring(n))
      local m=peripheral.wrap(%q,'red')
      local w,h=m.getSize()
      %s
    end}}]],input,period,input,index==1 and [[io.setOutput({{signal={type='virtual',name='signal-B',quality='normal'},count=value}})]] or '',
    c.id,name,config.workload=='mixed' and [[m.setCursorPos(1,1); m.clearLine(); m.write('Stock '..tostring(computer.getState('input') or 0)..' / '..tostring(n))]] or [[
      local digit=tostring(n%10); local row=string.rep(digit,w)
      local fg=string.rep('0',w); local bg=string.rep(n%2==0 and 'f' or '7',w)
      for y=1,h do m.setCursorPos(1,y); m.blit(row,fg,bg) end]])
end
local function activate(c,text,index)
  local p={valid=true,index=index,force=c.body.force,surface=c.body.surface,can_reach_entity=function(e) return e==c.body end}
  local s=editor.open(p,c.id); editor.edit(p,s.token,text)
  assert(editor.action(p,s.token,'validate',game.tick))
  assert(editor.action(p,s.token,'save',game.tick))
  local ok,why=editor.action(p,s.token,'run',game.tick); assert(ok,serpent.line(why))
end
function M.run()
  settings.global['tc-maintenance-work-per-tick']={value=config.budget}
  script.get_event_handler(defines.events.on_runtime_mod_setting_changed){setting='tc-maintenance-work-per-tick'}
  assert(limits.maintenance_work_per_tick==config.budget and limits.host_work_per_tick==5000000)
  local x={phase='setup',start=game.tick,computers={},walls={},measured=0,publications={},pending={},last_input=1}
  storage.tc_mb=x
  local surface=game.surfaces[1]; local tiles={}
  for y=-12,14 do for col=-8,40 do tiles[#tiles+1]={name='landfill',position={col,y}} end end
  surface.set_tiles(tiles)
  for _,e in ipairs(surface.find_entities_filtered{area={{-8,-12},{40,14}},type={'tree','simple-entity','cliff'}}) do e.destroy() end
  local power=assert(surface.create_entity{name='electric-energy-interface',position={-4,9},force='player'})
  power.power_production=100000000; power.power_usage=0
  for _,pos in ipairs({{-4,-4},{12,-4},{28,-4},{0,8},{16,8},{32,8}}) do assert(surface.create_entity{name='substation',position=pos,force='player'}) end
  local count=config.workload=='idle' and 1 or config.workload=='mixed' and 2 or 4
  for i=1,count do
    local c=build('computer',(i-1)*8,0); x.computers[i]=c.id
    if i>1 then connect(registry.record(x.computers[i-1]),c,'red') end
    if config.workload~='idle' then
      local wall={}; x.walls[i]=wall
      local size=config.workload=='mixed' and (i==1 and 2 or 1) or 3
      for y=0,size-1 do for col=0,size-1 do wall[#wall+1]=build('monitor',(i-1)*8+col,3+y).id end end
      connect(c,registry.record(wall[1]),'red')
    end
  end
  if config.workload~='idle' then
    local io=build('logic',0,-3); local db=build('kv',3,-3); x.io=io.id; x.db=db.id
    connect(registry.record(x.computers[1]),io,'red'); connect(io,db,'red')
    local constant=assert(surface.create_entity{name='constant-combinator',position={0,-6},force='player'})
    x.constant=constant
    for _,color in ipairs({'red','green'}) do
      assert(constant.get_wire_connector(defines.wire_connector_id['circuit_'..color],true).connect_to(lifecycle.connector(io,'input',color)))
    end
    local section=constant.get_or_create_control_behavior().add_section()
    section.filters={{index=1,value={type='virtual',name='signal-A',quality='normal'},min=1}}
    local lamp=assert(surface.create_entity{name='small-lamp',position={3,-6},force='player'})
    assert(lamp.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(lifecycle.connector(io,'output','red')))
    local cb=lamp.get_or_create_control_behavior(); cb.use_colors=false
    cb.circuit_condition={first_signal={type='virtual',name='signal-B',quality='normal'},comparator='>',constant=1}
    x.lamp=lamp
  end
  game.speed=100
  emit('CONFIG',{budget=config.budget,host=limits.host_work_per_tick,guest=limits.host_work_per_tick-config.budget,
    render_baseline=60000,render_boost=160000,workload=config.workload,computers=count,profile=config.profile,
    universe=(#prototypes.item+#prototypes.fluid+#prototypes.virtual_signal+#prototypes.recipe)*#prototypes.quality,limits=limits})
end
local function snapshot()
  local root=registry.get(); local x=f(); local records={}
  for _,id in ipairs(x.computers) do local c=registry.computer(id)
    records[#records+1]={record=c,state=c.state,active=c.active,run=c.run_id,queue=c.queue,timers=c.timers,subscriptions=c.subscriptions,
      content=serpent.line({state=c.state,queue=c.queue,timers=c.timers,subscriptions=c.subscriptions},{sortkeys=true})}
  end
  return {root=root,ledger=root.ledger,total=root.ledger.total,spent=root.scheduler.maintenance_spent,
    tick=root.scheduler.maintenance_tick,presentation=root.monitors.presentation,records=records}
end
local function unchanged()
  local a,b=f().saved,snapshot()
  for _,key in ipairs({'root','ledger','total','spent','tick','presentation'}) do assert(a[key]==b[key],'cold changed '..key) end
  for i,r in ipairs(a.records) do for key,value in pairs(r) do assert(b.records[i][key]==value,'cold changed '..key) end end
  assert(limits.maintenance_work_per_tick==config.budget)
end
function M.on_load() loaded=true; if f().phase=='frozen' then unchanged(); log('TC_MB_COLD_UNCHANGED') end end
function M.on_configuration_changed() error('unexpected configuration change') end
local function audit()
  local root=registry.get(); local p=root.monitors.presentation
  if p then
    assert(p.staging_cells<=model.limits.render_staging_cells and p.retired_cells<=model.limits.render_retired_cells)
    assert(#rendering.get_all_objects()<=model.limits.render_object_limit)
    for _,g in pairs(root.monitors.groups) do if g.render then
      local r=g.render
      for i,cell in ipairs(r.cells) do local value=r.snapshot.cells[i]
        assert(cell.value[1]==value[1] and cell.value[2]==value[2] and cell.value[3]==value[3])
        assert(cell.background.valid and cell.background.visible)
        if value[1]~=32 then assert(cell.glyph and cell.glyph.valid and cell.glyph.visible) end
      end
    end end
  end
  for _,id in ipairs(f().computers) do local c=registry.computer(id)
    if c.status=='running' and config.workload~='idle' then
      assert(registry.record(f().db).database.entries[id].value==tostring(c.state.beats))
    end
  end
  if f().io then
    local c=registry.computer(f().computers[1])
    if c.status=='running' and c.state.input then
      local value=f().lamp.get_signal({type='virtual',name='signal-B',quality='normal'},defines.wire_connector_id.circuit_red)
      assert(value==c.state.input,'real output wire disagrees with guest observed stock')
    end
  end
end
local function drive_input(tick)
  local x=f()
  if x.constant and tick%30==0 then
    x.last_input=x.last_input+1
    x.constant.get_control_behavior().get_section(1).filters={{index=1,value={type='virtual',name='signal-A',quality='normal'},min=x.last_input}}
    for _,id in ipairs(x.computers) do x.pending[id]={value=x.last_input,tick=tick} end
  end
end
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  if x.phase=='frozen' then
    if not loaded then return end
    unchanged(); loaded=false; x.phase='rewarm'; x.since=event.tick
  else loaded=false end
  assert(event.tick-x.start<12000,'benchmark structural deadline '..x.phase)
  local root=registry.get()
  local measuring=x.phase=='measure'
  if measuring or x.phase=='rewarm' or x.phase=='warmup' then drive_input(event.tick) end
  observer.begin(); local profiler=helpers.create_profiler()
  scheduler.tick(event.tick); profiler.stop()
  local refused=observer.finish(event.tick,profiler)
  if refused>0 then emit('PRESSURE',{tick=event.tick,phase=x.phase,refused=refused,spent=root.scheduler.maintenance_spent}) end
  x.reported_faults=x.reported_faults or {}
  for _,id in ipairs(x.computers) do local c=registry.computer(id)
    if c.status=='faulted' and not x.reported_faults[id] then
      emit('FAULT',{tick=event.tick,phase=x.phase,id=id,diagnostic=c.diagnostic})
      x.reported_faults[id]=true
    end
  end
  assert(root.scheduler.maintenance_spent<=config.budget)
  assert(root.ledger.tick~=event.tick or root.ledger.total<=limits.host_work_per_tick-config.budget)
  if x.phase=='setup' and event.tick-x.start>=120 and not root.monitors.job then
    local cells,tiles=0,0
    for _,g in pairs(root.monitors.groups) do cells=cells+g.model.width*g.model.height; tiles=tiles+#g.members end
    emit('TOPOLOGY',{tick=event.tick,cells=cells,tiles=tiles})
    x.phase='activate'; x.next=1
  elseif x.phase=='activate' then
    local id=x.computers[x.next]
    if id then
      local c=registry.computer(id); local g=x.walls[x.next] and assert(monitor.resolve(registry.record(x.walls[x.next][1])))
      activate(c,source(c,g and g.id,x.next),8000+x.next); x.next=x.next+1
    else x.phase='warmup'; x.since=event.tick end
  elseif x.phase=='warmup' and event.tick-x.since>=120 then
    audit(); x.saved=snapshot(); x.phase='frozen'; loaded=false
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif x.phase=='rewarm' and event.tick-x.since>=120 then
    audit(); x.phase='measure'; x.publications={}
    for name,g in pairs(root.monitors.groups) do if g.render then x.publications[name]=g.render.presented_tick end end
    local beats,changes=0,0
    for _,id in ipairs(x.computers) do local c=registry.computer(id)
      beats=beats+(c.state.beats or 0); changes=changes+(c.state.changes or 0)
    end
    emit('BEGIN',{tick=event.tick,beats=beats,changes=changes})
  elseif measuring then
    x.measured=x.measured+1
    if x.lamp then
      local output=x.lamp.get_signal({type='virtual',name='signal-B',quality='normal'},defines.wire_connector_id.circuit_red)
      if output~=x.last_output then
        emit('OUTPUT',{tick=event.tick,value=output}); x.last_output=output
      end
    end
    local faults,beats,changes=0,0,0; local states={}
    for _,id in ipairs(x.computers) do local c=registry.computer(id)
      if c.status=='faulted' then faults=faults+1 end
      beats=beats+(c.state.beats or 0); changes=changes+(c.state.changes or 0)
      states[#states+1]={id=id,status=c.status,code=c.diagnostic and c.diagnostic.code,diagnostic=c.diagnostic,beats=c.state.beats or 0,last=c.state.last or 0,changes=c.state.changes or 0}
      local pending=x.pending[id]
      if pending and c.state.input==pending.value then
        emit('INPUT',{id=id,tick=event.tick,latency=event.tick-pending.tick,value=pending.value}); x.pending[id]=nil
      end
    end
    local published=0
    for name,g in pairs(root.monitors.groups) do local r=g.render
      if r and r.presented_tick~=x.publications[name] then
        local row={}
        for i=1,r.snapshot.width do local cell=r.snapshot.cells[i]; row[#row+1]=cell[1]..':'..cell[2]..':'..cell[3] end
        local signature=table.concat(row,','); x.images=x.images or {}
        emit('PUBLICATION',{name=name,tick=event.tick,gap=x.publications[name] and r.presented_tick-x.publications[name] or 0,
          latency=r.snapshot.sealed_tick and event.tick-r.snapshot.sealed_tick or -1,revision=r.presented_revision,
          first_row_changed=x.images[name]~=signature})
        x.images[name]=signature
        x.publications[name]=r.presented_tick; published=published+1
      end
    end
    local p=root.monitors.presentation
    emit('SAMPLE',{tick=event.tick,index=x.measured,maintenance=root.scheduler.maintenance_spent,
      reserved=root.scheduler.render_reserved_work,guest=root.ledger.tick==event.tick and root.ledger.total or 0,
      refused=refused,faults=faults,beats=beats,changes=changes,publications=published,
      retired=p and p.retired_cells or 0,staging=p and p.staging_cells or 0})
    if x.measured==config.ticks then
      audit(); emit('STATES',states); emit('DONE',{samples=x.measured,faults=faults})
      x.phase='cleanup'; x.since=event.tick
      for _,id in ipairs(x.computers) do runtime.stop(id) end
    end
  elseif x.phase=='cleanup' then
    local p=root.monitors.presentation
    if not p or #p.jobs==0 and #p.retired==0 and #p.orphans==0 then
      assert(not x.io or not registry.record(x.io).output_owner)
      emit('CLEANUP',{ticks=event.tick-x.since,retired=p and p.retired_cells or 0})
      x.phase='done'; log('TC_COLD_OK maintenance-benchmark')
    end
  end
end
return M
