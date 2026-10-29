-- Isolated real-tick workloads. No production budgets, clocks or power are reset.
local config=require('tests.scheduling_benchmark_config')
local observer=require('tests.scheduling_benchmark_observer')
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local runtime=require('scripts.runtime.computer')
local shell=require('scripts.runtime.shell')
local defs=require('scripts.device-definitions')
local kv=require('scripts.services.kv')
local monitor=require('scripts.services.monitor')
local monitor_model=require('scripts.monitor-model')
local presentation=require('scripts.monitor-presentation')
local logic=require('scripts.services.logic')
local dashboard=require('scripts.services.dashboard')
local editor=require('scripts.ui.editor')
local editor_model=require('scripts.ui.editor-model')
local inspector=require('scripts.ui.peripheral-inspector')
local dashboard_ui=require('scripts.ui.dashboard')
local limits=require('scripts.runtime.limits')
local M={}; local resumed=false
local group,variant=config.name:match('([^/]+)/(.+)')
local function f() return storage.tc_scheduling_benchmark end
local function rec(id) return assert(registry.record(id),id) end
local function nop() end
local function emit(tag,value) log('TC_SB_'..tag..' '..helpers.table_to_json(value)) end
local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
local function expect(ok,message)
  if not ok then
    local x=f(); x.valid=false
    if not x.failures[message] then x.failures[message]=true; emit('FAIL',{tick=game.tick,message=message}) end
  end
end
local function position(i)
  local row=math.floor((i-1)/8); local col=(i-1)%8
  return {x=(row%2==0 and col or 7-col)*4,y=row*4}
end
local function build(kind,pos)
  local x=f(); pos=pos or {x=((#x.ids)%32)*8,y=math.floor(#x.ids/32)*8}
  local name=defs.devices[kind] and defs.devices[kind].entity_name or (kind=='speaker' and 'programmable-speaker' or 'radar')
  local body=assert(x.surface.create_entity{name=name,position=pos,force='player',raise_built=true})
  -- Script-raised events are suppressed during on_init; use the same handler.
  if defs.devices[kind] then lifecycle.on_built{entity=body} end
  local r=assert(registry.by_entity(body),'build event did not register '..kind)
  x.ids[#x.ids+1]=r.id
  return r
end
local function wire(a,b,connected)
  local ac=lifecycle.connector(a,'network','red'); local bc=lifecycle.connector(b,'network','red')
  if connected==false then return ac.disconnect_from(bc) end
  return ac.connect_to(bc)
end
local function input(io,pos)
  local e=assert(f().surface.create_entity{name='constant-combinator',position=pos,force='player'})
  assert(e.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(lifecycle.connector(io,'input','red')))
  local behavior=e.get_or_create_control_behavior()
  local section=behavior.get_section(1) or behavior.add_section()
  f().inputs[#f().inputs+1]=e
  local filters={}
  for i=1,config.signals do filters[i]={index=i,value={type='item',name=f().signal_names[i],quality='normal'},min=1} end
  section.filters=filters
  return e
end
local function set_inputs(value)
  for _,e in ipairs(f().inputs) do
    local filters={}
    for i=1,config.signals do filters[i]={index=i,value={type='item',name=f().signal_names[i],quality='normal'},min=value} end
    e.get_control_behavior().get_section(1).filters=filters
  end
end
local function computer(pos,active)
  local c=build('computer',pos)
  if active then f().computers[#f().computers+1]=c.id end
  return c
end
local function connect_computers()
  for i=2,#f().computers do assert(wire(rec(f().computers[i-1]),rec(f().computers[i]))) end
end
local function panel_definition()
  local children={}
  for i=1,16 do children[i]={type='label',id='value'..i,text='Stable '..i} end
  if config.charts then children[#children+1]={type='line',id='trend',series={'value'},capacity=16,format='number'} end
  return {title='Benchmark',content={type='column',id='root',children=children}}
end
function M.run()
  local x={ids={},native={},computers={},inputs={},ios={},dbs={},screens={},failures={},valid=true,phase='setup',samples=0,
    start=game.tick,load_tick=game.tick,measure_tick=game.tick+120+config.count*3+config.warmup,
    publications=0,previous_frames={},latencies={},dispatches=0,changes=0,mutations=0,starts=0}
  storage.tc_scheduling_benchmark=x
  if remote.interfaces.freeplay then remote.call('freeplay','set_skip_intro',true); remote.call('freeplay','set_disable_crashsite',true) end
  x.surface=game.create_surface('scheduling-benchmark',{width=512,height=512,autoplace_settings={entity={treat_missing_as_default=false},decorative={treat_missing_as_default=false}}})
  x.surface.request_to_generate_chunks({120,120},6); x.surface.force_generate_chunk_requests()
  x.surface.always_day=true
  local tiles={}; for y=-8,260 do for xx=-8,260 do tiles[#tiles+1]={name='refined-concrete',position={xx,y}} end end
  x.surface.set_tiles(tiles)
  game.map_settings.pollution.enabled=false; game.map_settings.enemy_expansion.enabled=false
  local previous
  for y=0,256,16 do for xx=0,256,16 do
    local p=assert(x.surface.create_entity{name='substation',position={xx+3,y+3},force='player'})
    local connector=p.get_wire_connector(defines.wire_connector_id.pole_copper,true)
    if previous then previous.connect_to(connector) end
    previous=connector
  end end
  local supply=assert(x.surface.create_entity{name='electric-energy-interface',position={6,5},force='player'})
  supply.power_production=1000000000; supply.power_usage=0
  x.signal_names={}; for name in pairs(prototypes.item) do x.signal_names[#x.signal_names+1]=name end; table.sort(x.signal_names)
  assert(#x.signal_names>=config.signals)
  if group=='idle' then
    for i=1,config.count do
      if config.family=='radar' or config.family=='speaker' then
        local name=config.family=='radar' and 'radar' or 'programmable-speaker'
        x.native[i]=assert(x.surface.create_entity{name=name,position={x=((i-1)%32)*8,y=math.floor((i-1)/32)*8},force='player',raise_built=true})
      else build(config.family) end
    end
  elseif group=='computer' or group=='art' then
    local active=variant=='waiting' or variant=='running-animation'
    for i=1,config.count do computer(active and position(i) or nil,active) end
  elseif group=='dispatch' then
    local n=variant=='all' and config.count or 1
    for i=1,n do computer(position(i),true) end
    if variant=='one-plus-idle' then for i=1,config.count do build('computer',{x=((i-1)%32)*8,y=4+math.floor((i-1)/32)*8}) end end
  elseif group=='timer' then
    for i=1,config.count do computer(position(i),true) end
  elseif group=='signal' then
    if variant=='unwatched' then
      for i=1,config.count do local p=position(i); local io=build('logic',p); x.ios[#x.ios+1]=io.id; input(io,{x=p.x,y=p.y-2}) end
    else
      for i=1,config.count do
        local p=position(i); local c=computer(p,true)
        if variant=='distinct-inputs' or i==1 then
          local io=build('logic',{x=p.x,y=p.y+2}); x.ios[#x.ios+1]=io.id
          assert(wire(c,io)); input(io,{x=p.x+1,y=p.y+1})
        end
      end
      if variant~='distinct-inputs' then connect_computers() end
    end
  elseif group=='topology' then
    local c=computer({x=-4,y=0},true); local previous=c; local nodes={}
    for i=1,config.count do
      local p=position(i)
      if config.shape=='branch' then p.x=((i-1)%8)*4 end
      local r=build('kv',p); nodes[i]=r
      local parent=config.shape=='branch' and i>8 and nodes[i-8] or previous
      assert(wire(parent,r)); previous=r
    end
    x.edge={c.id,nodes[1].id}
    if variant=='adoption' then
      x.adopt_position={x=previous.body.position.x,y=previous.body.position.y+2}; x.adopt_parent=previous.id
    end
  elseif group=='output' then
    for i=1,config.count do
      local p=position(i); local c=computer(p,variant~='no-owner')
      local io=build('logic',{x=p.x,y=p.y+2}); x.ios[i]=io.id; assert(wire(c,io))
      x.output_pairs=x.output_pairs or {}; x.output_pairs[i]={c.id,io.id}
    end
  elseif group=='monitor' or group=='mixed' or group=='reload' then
    local n=group=='mixed' and variant=='sparse' and 1 or group=='reload' and 1 or config.count
    for i=1,n do
      local p={x=((i-1)%8)*8,y=math.floor((i-1)/8)*8}
      local c=computer(p,true)
      local tile=build('monitor',{x=p.x,y=p.y+2}); x.screens[#x.screens+1]=tile.id; assert(wire(c,tile))
      if group=='mixed' then
        local io=build('logic',{x=p.x+3,y=p.y}); x.ios[#x.ios+1]=io.id; assert(wire(c,io)); input(io,{x=p.x+3,y=p.y-2})
        local db=build('kv',{x=p.x+3,y=p.y+2}); x.dbs[#x.dbs+1]=db.id; assert(wire(io,db))
      end
    end
    if group=='mixed' and variant=='sparse' then for i=1,config.count do build('computer',{x=(i%32)*8,y=40+math.floor(i/32)*8}) end end
  elseif group=='kv' then
    for _=1,config.count do x.dbs[#x.dbs+1]=build('kv').id end
  elseif group=='ui' then
    local c=computer({x=0,y=0},false); x.ui_computer=c.id
    local db=build('kv',{x=4,y=0}); x.dbs[1]=db.id; assert(wire(c,db))
    local panel=build('dashboard',{x=0,y=4}); x.panel=panel.id; assert(wire(c,panel))
    dashboard.methods.setTab(nil,panel,nil,game.tick,nop,1,panel_definition())
    if config.charts then
      for i=1,16 do dashboard.methods.appendSample(nil,panel,nil,game.tick,nop,1,'trend',{value=i}) end
    end
  elseif group=='churn' then
    computer({x=0,y=0},true)
  elseif group~='empty' then error('unimplemented benchmark '..config.name) end
  for _,id in ipairs(x.dbs) do
    for i=1,16 do kv.methods.set(nil,rec(id),nil,game.tick,nop,'key'..i,'value'..i) end
  end
  x.expected_devices=#x.ids
  emit('SETUP',{case=config.name,devices=#x.ids,computers=#x.computers,limits=limits,signal_names=x.signal_names})
end
local function source(index)
  local x=f(); local start="computer.setState('boots',(computer.getState('boots') or 0)+1); "
  local work="computer.setState('beats',(computer.getState('beats') or 0)+1); computer.setState('latency',e.tick-(e.created_tick or e.scheduled_tick or e.tick)); "
  local changed="computer.setState('changes',(computer.getState('changes') or 0)+1); computer.setState('sample',e.sample_tick); computer.setState('value',#e.current>0 and e.current[1].count or 0); "
  if group=='timer' then
    for i=1,config.timers do
      local due=x.measure_tick+30+(variant=='staggered' and ((index-1)*3+i-1)%60 or 0)
      if variant=='future' or variant=='sparse' and (index~=1 or i~=1) then due=x.measure_tick+config.ticks+600 end
      start=start..string.format("computer.after(%d-computer.getTick(),'work'); ",due)
    end
    if variant~='future' then work=work.."computer.after(math.max(1,60-(e.tick-e.scheduled_tick)),'work'); " end
  elseif group=='signal' then
    local io=x.ios[variant=='distinct-inputs' and index or 1]
    start=start..string.format("peripheral.wrap(%q,'red').subscribe({input='red',initial=true},'changed'); ",io)
  elseif group=='topology' and variant~='no-interest' then
    start=start.."computer.on('peripheral_attach','work'); computer.on('peripheral_detach','work'); "
  elseif group=='output' then
    start=start..string.format("peripheral.wrap(%q,'red').setOutput({{signal={type='virtual',name='signal-A',quality='normal'},count=7}}); ",x.ios[index])
  elseif group=='monitor' or group=='mixed' or group=='reload' then
    local g=assert(monitor.resolve(rec(x.screens[index])))
    local draw=string.format("local m=peripheral.wrap(%q,'red'); m.setCursorPos(1,1); m.write(tostring(computer.getState('beats') or 0)); ",g.id)
    if variant:match('frame') then
      draw=string.format("local m=peripheral.wrap(%q,'red'); local w,h=m.getSize(); local row=string.rep(tostring((computer.getState('beats') or 0)%%10),w); for y=1,h do m.setCursorPos(1,y); m.blit(row,string.rep('0',w),string.rep('f',w)) end; ",g.id)
    end
    start=start..draw
    if variant~='static' and variant~='regroup' and group~='reload'
      and (not variant:match('one%-dirty') or index==1) then start=start.."computer.every(30,'work'); " end
    work=work..draw
    if group=='mixed' then
      start=start..string.format("peripheral.wrap(%q,'red').subscribe({input='red',initial=true},'changed'); ",x.ios[index])
      work=work..string.format("peripheral.wrap(%q,'red').set('counter',tostring(computer.getState('beats'))); ",x.dbs[index])
    elseif group=='reload' then start=start..string.format("computer.after(%d-computer.getTick(),'work'); ",x.measure_tick+30) end
  elseif group=='churn' and variant=='register-cancel' then
    work=work.."local t=computer.after(600,'work'); assert(computer.cancelTimer(t)); local s=computer.on('peripheral_attach','work'); assert(computer.off(s)); "
  end
  return 'return {api_version=1,handlers={start=function(e) '..start..' end,work=function(e) '..work..' end,changed=function(e) '..changed..' end}}'
end
local function activate(c,index)
  if c.saved_revision==0 then
    runtime.save(c.id,source(index),0); emit('SOURCE',{computer=c.id,source=c.saved_source})
  end
  local ok,err=runtime.activate(c.id,game.tick); assert(ok,serpent.line(err))
end
function M.on_load() resumed=f().phase=='frozen' end
function M.on_configuration_changed() error('benchmark configuration changed') end
function M.on_player_joined(event)
  local p=game.get_player(event.player_index)
  if p.controller_type==defines.controllers.cutscene then p.exit_cutscene() end
  p.set_controller{type=defines.controllers.god}; p.teleport({0,-2},f().surface); p.zoom=1
end
local function open_ui()
  local x=f(); local p=game.get_player(1)
  if not p or not p.connected then return false end
  if x.ui_open then return true end
  M.on_player_joined{player_index=p.index}
  if group=='dispatch' or variant:match('editor') then
    local c=rec(x.ui_computer or x.computers[1]); assert(editor.open(p,c.id))
    if group=='dispatch' or variant=='editor-changing' then
      local pane=p.gui.screen[editor.frame_name].content; pane.selected_tab_index=2
      editor.on_tab{player_index=p.index,element=pane}
    end
  elseif variant:match('inspector') then assert(inspector.open(p,x.dbs[1]))
  elseif variant:match('dashboard') then assert(dashboard_ui.open(p,x.panel)) end
  x.ui_open=true; return true
end
local function audit()
  local x=f()
  expect(count(registry.get().devices)+count(registry.get().computers)==#x.ids+(x.adopted and registry.by_entity(x.adopted) and 1 or 0),'registry population changed')
  for _,e in ipairs(x.native) do expect(e.valid,'native carrier disappeared'); expect(e.energy>0,'native carrier unpowered') end
  for _,id in ipairs(x.ids) do
    local r=registry.record(id)
    expect(r and r.body.valid,'missing fixture device '..id)
    if r and r.body.valid then expect(lifecycle.has_power(r),'unpowered fixture device '..id) end
  end
  for _,id in ipairs(x.computers) do
    local c=rec(id)
    expect(c.status=='running' or group=='churn' and variant=='activate-stop','faulted/stopped producer '..id..' '..serpent.line(c.diagnostic))
  end
  if config.client then
    local p=game.get_player(1); expect(p and p.connected,'native connected player absent')
    if p and variant~='closed' then expect(p.opened~=nil,'native window closed') end
  end
end
local function enqueue(c,tick)
  if c.status=='running' and #c.queue==0 then
    local ok=runtime.enqueue(c,'work',{name='benchmark',created_tick=tick},tick)
    expect(ok,'work enqueue refused'); if ok then f().offered=f().offered+1 end
  end
end
local function drive(tick,step)
  local x=f()
  if group=='dispatch' and variant~='console' then for _,id in ipairs(x.computers) do enqueue(rec(id),tick) end end
  if group=='dispatch' and (variant=='console' or variant=='arbitration') and step%4==0 then
    local c=rec(x.computers[1]); local s=editor_model.session(1)
    if not shell.waiting(c) then
      local session=shell.session(c)
      local ok,why=pcall(shell.submit,c,"computer.setState('shell_beats',(computer.getState('shell_beats') or 0)+1)",1,s.token,tick,session and session.id or false)
      expect(ok,'Console submit failed '..serpent.line(why))
    end
  end
  if group=='signal' and variant~='watched-static' or group=='mixed' then
    if variant=='pulse' then
      if step%30==0 then set_inputs(7); x.pulses=x.pulses+1 elseif step%30==1 then set_inputs(0) end
    elseif step%30==0 then set_inputs(1+math.floor(step/30)%2) end
  end
  if group=='topology' and variant=='rewire' and step%60==0 then
    x.disconnected=not x.disconnected
    assert(wire(rec(x.edge[1]),rec(x.edge[2]),not x.disconnected)); x.mutations=x.mutations+1
  elseif group=='topology' and variant=='adoption' and step==30 then
    local e=assert(x.surface.create_entity{name='radar',position=x.adopt_position,force='player'})
    local parent=rec(x.adopt_parent)
    assert(lifecycle.connector(parent,'network','red').connect_to(e.get_wire_connector(defines.wire_connector_id.circuit_red,true)))
    x.adopted=e; x.mutations=x.mutations+1
  elseif group=='output' and variant=='revoked-owner' and step==30 then
    assert(wire(rec(x.output_pairs[1][1]),rec(x.output_pairs[1][2]),false)); x.revoked=tick; x.mutations=x.mutations+1
  elseif group=='monitor' and variant=='regroup' and step==30 then
    local tile=rec(x.screens[1]); local p=tile.body.position
    x.joined=build('monitor',{x=p.x+1,y=p.y}).id; x.mutations=x.mutations+1
  elseif group=='churn' then
    local c=rec(x.computers[1])
    if variant=='register-cancel' then enqueue(c,tick)
    elseif step%30==0 then runtime.stop(c.id); x.mutations=x.mutations+1
    elseif step%30==1 then activate(c,1); x.mutations=x.mutations+1 end
  elseif group=='ui' and variant:match('changing') and step%30==0 then
    if variant=='editor-changing' then runtime.log(rec(x.ui_computer),'Benchmark output '..step,tick)
    elseif variant=='inspector-changing' then kv.methods.set(nil,rec(x.dbs[1]),nil,tick,nop,'key1','Changed '..step)
    else
      dashboard.methods.setText(nil,rec(x.panel),nil,tick,nop,1,'value1','Changed '..step)
      if config.charts then dashboard.methods.appendSample(nil,rec(x.panel),nil,tick,nop,1,'trend',{value=step%100}) end
    end
    x.mutations=x.mutations+1
  end
end
local function observe(tick)
  local x=f()
  for _,id in ipairs(x.computers) do
    local c=rec(id)
    if c.status=='faulted' then expect(false,'producer fault '..id..' '..serpent.line(c.diagnostic)) end
    local previous=x.beats[id] or 0; local beats=c.state.beats or 0
    if beats>previous then
      x.dispatches=x.dispatches+beats-previous; x.latencies[#x.latencies+1]=c.state.latency or 0
      x.max_latency[id]=math.max(x.max_latency[id] or 0,c.state.latency or 0)
    end
    x.beats[id]=beats
    local old=x.seen_changes[id] or 0; local changes=c.state.changes or 0
    if changes>old then
      x.changes=x.changes+changes-old
      x.signal_latencies[#x.signal_latencies+1]=tick-(c.state.sample or tick)
      if c.state.value==7 then x.pulse_seen[id]=(x.pulse_seen[id] or 0)+1 end
    end
    x.seen_changes[id]=changes
  end
  local monitors=registry.get().monitors
  -- Observe only producers; scanning idle screens would contaminate idle scaling.
  if monitors then for i=1,#x.computers do
    local name=monitors.membership[x.screens[i]]; local g=name and monitors.groups[name]
    local r=g and g.render
    if r and r.presented_tick~=x.previous_frames[name] then
      if x.previous_frames[name] then x.frame_gaps[#x.frame_gaps+1]=r.presented_tick-x.previous_frames[name] end
      x.previous_frames[name]=r.presented_tick; x.publications=x.publications+1
    end
  end end
  if x.revoked and not x.cleared and not rec(x.ios[1]).output_owner then x.cleared=tick-x.revoked end
end
local function begin(tick)
  local x=f(); x.phase='measure'; x.offered=0; x.beats={}; x.seen_changes={}; x.signal_latencies={}; x.frame_gaps={}; x.pulse_seen={}; x.pulses=0; x.max_latency={}
  for _,id in ipairs(x.computers) do local c=rec(id); x.beats[id]=c.state.beats or 0; x.seen_changes[id]=c.state.changes or 0 end
  local monitors=registry.get().monitors
  if monitors then for name,g in pairs(monitors.groups) do if g.render then x.previous_frames[name]=g.render.presented_tick end end end
  audit()
  for _,id in ipairs(x.ios) do
    if group=='signal' or group=='mixed' then
      expect(#logic.inspect_input(rec(id),'red',tick,nop).values==config.signals,'native signal inventory mismatch')
    end
    if group=='output' then expect((rec(id).output_owner~=nil)==(variant~='no-owner'),'initial output owner missing/unexpected') end
  end
  emit('BEGIN',{tick=tick,load_tick=x.load_tick,client=config.client or false,devices=#x.ids,computers=#x.computers,
    screens=count(monitors and monitors.groups),physical_tiles=#x.screens,maintenance_limit=limits.maintenance_work_per_tick})
end
local function finish(tick)
  local x=f(); audit()
  local states={}; local subscriptions,timers,queued=0,0,0
  for _,id in ipairs(x.computers) do
    local c=rec(id); subscriptions=subscriptions+count(c.subscriptions); timers=timers+count(c.timers); queued=queued+#c.queue
    states[#states+1]={id=id,status=c.status,boots=c.state.boots or 0,beats=c.state.beats or 0,changes=c.state.changes or 0,shell_beats=c.state.shell_beats or 0,pulses=x.pulse_seen[id] or 0,max_latency_ticks=x.max_latency[id] or 0}
    if group~='churn' then expect(c.state.boots==1,'startup replay/missing startup '..id) end
    if variant=='pulse' then expect((x.pulse_seen[id] or 0)==x.pulses,'pulse delivery mismatch '..id) end
    if group=='dispatch' and variant~='console' then expect((c.state.beats or 0)>0,'producer starved '..id) end
  end
  if group=='dispatch' and variant~='console' or group=='churn' and variant=='register-cancel' then expect(x.dispatches>0,'no useful callback work') end
  if variant=='console' or variant=='arbitration' then expect((rec(x.computers[1]).state.shell_beats or 0)>0,'no completed Console work') end
  if group=='timer' then expect(variant=='future' and x.dispatches==0 or variant~='future' and x.dispatches>0,'timer oracle') end
  if group=='computer' or group=='art' then expect(x.dispatches==0 and x.changes==0,'waiting program performed work') end
  if group=='signal' and variant~='unwatched' and variant~='watched-static' then expect(x.changes>0,'no input changes delivered') end
  if group=='signal' and variant=='watched-static' then expect(x.changes==0,'static input changed') end
  if group=='signal' then expect(subscriptions==#x.computers,'signal subscription inventory') end
  if group=='monitor' and variant:match('dirty') or group=='mixed' then expect(x.publications>0,'no monitor publications') end
  if group=='topology' and variant=='adoption' then expect(x.adopted and registry.by_entity(x.adopted)~=nil,'native adoption did not finish') end
  if group=='topology' and (variant=='rewire' or variant=='adoption') then expect(x.dispatches>0,'topology notification absent') end
  if group=='monitor' then
    for _,id in ipairs(x.screens) do
      local g=monitor.resolve(rec(id)); expect(g and g.render and g.render.presented_tick~=nil,'screen never published '..id)
      if variant=='static' and g and g.render then expect(g.render.presented_tick==x.previous_frames[g.id],'static screen republished '..id) end
    end
    if variant=='regroup' then expect(monitor.resolve(rec(x.screens[1]))==monitor.resolve(rec(x.joined)),'regroup did not finish') end
    if variant=='static' then expect(x.publications==0,'static screen republished') end
  end
  if x.revoked then expect(x.cleared~=nil and x.cleared<=limits.fail_safe_latency_ticks,'output cleanup missed deadline') end
  if group=='output' then
    for i,id in ipairs(x.ios) do
      local values=logic.inspect_output(rec(id),nop)
      local cleared=variant=='no-owner' or variant=='revoked-owner' and i==1
      expect(cleared and #values==0 or not cleared and #values==1 and values[1].count==7,'native output content mismatch '..id)
    end
  end
  if group=='ui' and variant:match('changing') then
    local found=false; local needle=variant=='editor-changing' and 'Benchmark output' or 'Changed'
    local function inspect(element)
      if element.type=='label' and type(element.caption)=='string' and element.caption:find(needle,1,true) then found=true end
      if (element.type=='text-box' or element.type=='textfield') and element.text:find(needle,1,true) then found=true end
      for _,child in pairs(element.children) do inspect(child) end
    end
    inspect(game.get_player(1).gui.screen)
    expect(found,'changed content never reached native GUI')
  end
  if group=='churn' and variant=='register-cancel' then expect(subscriptions==0 and timers==0,'canceled membership retained') end
  if group=='reload' then expect(resumed and x.dispatches==2 and x.publications>0,'cold pending work/timer did not resume exactly once') end
  if group=='kv' then
    for _,id in ipairs(x.dbs) do
      for i=1,16 do
        local value=kv.methods.get(nil,rec(id),nil,tick,nop,'key'..i)
        expect((variant=='persistent' or variant=='future') and value~=nil or (variant=='staggered' or variant=='burst') and value==nil,'KV expiry/read oracle')
      end
    end
  end
  emit('DONE',{tick=tick,samples=x.samples,valid=x.valid,devices=#x.ids,states=states,offered=x.offered,
    dispatches=x.dispatches,changes=x.changes,publications=x.publications,mutations=x.mutations,
    queue=queued,timers=timers,subscriptions=subscriptions,pulses=x.pulses,native_devices=#x.native,latency_ticks=x.latencies,signal_latency_ticks=x.signal_latencies,
    frame_gap_ticks=x.frame_gaps,output_clear_ticks=x.cleared,cold_resumed=resumed})
  observer.done(); x.phase='done'
end
function M.on_tick(event)
  local x=f(); if x.phase=='done' or x.phase=='frozen' and not resumed then return end
  if x.phase=='finish' then finish(event.tick-1); return end
  if x.phase=='frozen' then
    expect(rec(x.computers[1]).queue==x.saved_queue,'cold queue identity changed')
    expect(#x.saved_queue==1 and rec(x.computers[1]).timers==x.saved_timers and count(x.saved_timers)==1,'cold pending inventory changed')
    expect(monitor.resolve(rec(x.screens[1])).model==x.saved_model,'cold pending monitor changed')
    expect(rec(x.computers[1]).state.boots==1,'cold startup changed')
    x.load_tick=event.tick-1; x.measure_tick=event.tick; x.phase='setup'
  end
  local age=event.tick-x.start
  if x.phase=='setup' and not resumed then
    if age>=120 and age<120+#x.computers then activate(rec(x.computers[age-119]),age-119) end
    if config.client and age>=120+#x.computers+1 then open_ui() end
  end
  if group=='kv' and variant~='persistent' and event.tick<x.measure_tick then
    for _,id in ipairs(x.dbs) do for i=1,16 do
      local offset=variant=='staggered' and i*2 or 30
      if event.tick==x.measure_tick-60+offset then
        kv.methods.expire(nil,rec(id),nil,event.tick,nop,'key'..i,variant=='future' and math.ceil(config.ticks/60)+60 or 1)
      end
    end end
  end
  if event.tick==x.measure_tick and x.phase~='measure' then begin(event.tick) end
  local measuring=x.phase=='measure' and event.tick>=x.measure_tick
  if measuring then drive(event.tick,x.samples) end
  if measuring then observer.begin() end
  local p=measuring and config.lane=='profile' and helpers.create_profiler()
  scheduler.tick(event.tick)
  if p then p.stop() end
  if measuring then observer.finish(event.tick,p); x.samples=x.samples+1; observe(event.tick) end
  if group=='monitor' and (variant=='static' or variant:match('one%-dirty')) and not x.stopped and age>=120+#x.computers+30 then
    local keep={}
    for i,id in ipairs(x.computers) do if variant~='static' and i==1 then keep[1]=id else runtime.stop(id) end end
    x.computers=keep; x.stopped=true
  end
  if group=='reload' and not resumed and event.tick==x.measure_tick-1 then
    local c=rec(x.computers[1]); assert(runtime.enqueue(c,'work',{name='benchmark',created_tick=event.tick},event.tick))
    local g=assert(monitor.resolve(rec(x.screens[1])))
    -- Dirty model and ready callback survive together, before next presentation.
    monitor_model.calls.write(g.model,nop,'pending'); presentation.participate(g)
    x.saved_queue=c.queue; x.saved_timers=c.timers; x.saved_model=g.model
    x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif event.tick==x.measure_tick-1 then
    begin(x.measure_tick)
  end
  if config.capture and config.client and measuring and x.samples==math.floor(config.ticks/2) then
    game.take_screenshot{player=game.get_player(1),resolution={1280,720},path='benchmark-ui.png',show_gui=true,force_render=true}
    emit('CAPTURE',{tick=event.tick})
  end
  if measuring and x.samples==config.ticks then x.phase='finish' end
end
return M
