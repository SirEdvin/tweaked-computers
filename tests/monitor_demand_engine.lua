-- Structural counters use real scheduler ticks; no wall-time acceptance threshold.
local observer=require('tests.monitor_demand_observer')
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local monitor=require('scripts.services.monitor')
local editor=require('scripts.ui.editor-model')
local runtime=require('scripts.runtime.computer')
local defs=require('scripts.device-definitions')
local M={}; local resumed=false
local function fixture() return storage.tc_monitor_demand end
local function build(kind,x,y,d)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,y},direction=d or 0,force='player'})
  local r=assert(lifecycle.build(body)); assert(not r.children.power and lifecycle.available(r)); return r
end
local function wire(a,b)
  assert(lifecycle.connector(a,'network','red').connect_to(lifecycle.connector(b,'network','red')))
end
local function start(mode)
  local x=fixture(); local c=registry.computer(x.computer)
  local source=[[function start()
    local names={}
    for _,name in ipairs(peripheral.getNames('red')) do
      if peripheral.getType(name,'red')=='monitor' then names[#names+1]=name end
    end
    table.sort(names)
    computer.setState('names',names)
    for _,name in ipairs(names) do
      local m=peripheral.wrap(name,'red'); m.setTextScale(2); m.setCursorBlink(true); m.write('SETTLED')
    end
    computer.setState('started',(computer.getState('started') or 0)+1)
    MODE
  end
  function paint()
    local names=computer.getState('names')
    for i=1,COUNT do
      local m=peripheral.wrap(names[i],'red')
      m.setCursorPos(1,2); m.write(tostring(computer.getTick()%10))
    end
    computer.setState('painted',(computer.getState('painted') or 0)+1)
  end]]
  source=source:gsub('MODE',mode=='idle' and '' or "computer.every(2,'paint')")
  source=source:gsub('COUNT',mode=='all' and '4' or '1')
  local player={valid=true,index=1,force=c.body.force,surface=c.body.surface,can_reach_entity=function(body) return body==c.body end}
  local session=editor.open(player,c.id); editor.edit(player,session.token,source)
  local valid,why=editor.action(player,session.token,'validate',game.tick); assert(valid,serpent.line(why))
  assert(editor.action(player,session.token,'save',game.tick))
  local ok,problem=editor.action(player,session.token,'run',game.tick); assert(ok,serpent.line(problem))
end
function M.run()
  log('TC_DEMAND_VISIBILITY_INSTRUMENTED '..tostring(observer.instrumented==true))
  local x={phase='idle',steps=0,measured=0,tiles={},fronts={}}; storage.tc_monitor_demand=x
  local c=build('computer',-3,0); x.computer=c.id
  local previous=c
  for n=1,4 do
    local first,last
    for y=0,5 do for col=0,5 do
      local r=build('monitor',(n-1)*10+col,y,(n-1)*4); x.tiles[#x.tiles+1]=r.id
      if y==0 and col==0 then first=r end
      if y==0 and col==5 then last=r end
    end end
    wire(previous,first); wire(first,last); previous=last
    if n==2 or n==3 then local bridge=build('computer',n*10-4,0); wire(previous,bridge); previous=bridge end
  end
  for _=1,200 do monitor.reconcile(game.tick,function() end); if not registry.get().monitors.job then break end end
  assert(#registry.get().monitors.order==4 and not registry.get().monitors.job)
  start('idle')
end
function M.on_load()
  local x=fixture()
  if x.phase=='frozen' then
    local r=registry.get()
    assert(r.monitors.presentation==x.saved.presentation and r.scheduler.maintenance_spent==x.saved.spent)
    for id,front in pairs(x.fronts) do assert(r.monitors.groups[id].render==front) end
    resumed=true
  end
end
function M.on_configuration_changed() error('unexpected configuration change') end
local function physical_tick(event)
  local x=fixture(); local root=registry.get(); local test=x.physical
  for _,id in ipairs(root.order) do assert(not registry.record(id).children.power) end
  scheduler.tick(event.tick)
  assert(event.tick-test.changed<256,'silent physical reconciliation deadline')
  local s=root.monitors; local p=s.presentation
  if s.job or #p.jobs>0 or #p.orphans>0 or #p.retired>0 or p.pending_cells>0 then return end
  if test.stage=='initial' then
    for _,g in pairs(s.groups) do if not g.render or g.render.presented_revision~=g.model.revision then return end end
    local rec=registry.record(x.tiles[36]); test.tile=rec.id
    test.position={x=rec.body.position.x,y=rec.body.position.y}; test.direction=rec.body.direction
    test.force=rec.body.force; test.surface=rec.body.surface; test.index=1
    test.untouched={}
    local affected=s.membership[rec.id]
    for id,g in pairs(s.groups) do if id~=affected then test.untouched[id]={group=g,model=g.model,front=g.render} end end
    test.stage='next'
  end
  for id,old in pairs(test.untouched) do
    local g=s.groups[id]; assert(g==old.group and g.model==old.model and g.render==old.front,'silent change rebuilt an unrelated display')
  end
  local rec=registry.record(test.tile)
  local cases={'move','rotate','force','surface-clone','ownership'}
  local name=cases[test.index]
  if test.stage=='next' then
    local old=assert(monitor.resolve(rec)); assert(monitor.available(old,function() end))
    if name=='move' then assert(rec.body.teleport({test.position.x+2,test.position.y+2}))
    elseif name=='rotate' then rec.body.direction=4
    elseif name=='force' then rec.body.force=game.forces['demand-foreign'] or game.create_force('demand-foreign')
    elseif name=='surface-clone' then
      local surface=game.surfaces['demand-foreign'] or game.create_surface('demand-foreign',{width=32,height=32})
      local body=assert(rec.body.clone{position=test.position,surface=surface,force=test.force})
      local clone=assert(registry.by_entity(body)); assert(clone.id~=rec.id)
      test.retired=rec.id; test.tile=clone.id; x.tiles[36]=clone.id
      rec.body.destroy()
    else
      test.binding=root.entities[rec.body.unit_number]; root.entities[rec.body.unit_number]=nil
    end
    assert(not monitor.available(old,function() end),'same-event physical mutation reused authority: '..name)
    test.stage='changed'; test.changed=event.tick; return
  elseif test.stage=='changed' then
    if rec.monitor_repair then return end
    assert(rec.direction==rec.body.direction and rec.force_index==rec.body.force.index and rec.surface_index==rec.body.surface.index)
    assert(rec.position.x==rec.body.position.x and rec.position.y==rec.body.position.y)
    if name=='surface-clone' then
      assert(not registry.record(test.retired),'surface clone retargeted the old identity')
      local body=assert(rec.body.clone{position=test.position,surface=test.surface,force=test.force})
      local clone=assert(registry.by_entity(body)); assert(clone.id~=rec.id)
      test.retired=rec.id; test.tile=clone.id; x.tiles[36]=clone.id
      rec.body.destroy()
    elseif name=='ownership' then
      assert(not lifecycle.available(rec) and monitor.resolve(rec).render.hidden,'lost ownership kept presentation live')
      root.entities[rec.body.unit_number]=test.binding; test.binding=nil
    else
      rec.body.force=test.force; rec.body.direction=test.direction
      assert(rec.body.surface==test.surface and rec.body.teleport(test.position))
    end
    test.stage='restored'; test.changed=event.tick; return
  elseif test.stage=='restored' then
    if not lifecycle.available(rec) then return end
    if name=='surface-clone' then assert(not registry.record(test.retired),'restored clone retargeted the old identity') end
    for _,id in ipairs(x.tiles) do assert(lifecycle.available(registry.record(id)),'restoration lost live tile availability') end
    assert(monitor.available(monitor.resolve(rec),function() end))
    log('TC_DEMAND_PHYSICAL_PASS case='..name)
    test.index=test.index+1; test.stage='next'; test.changed=event.tick
    if test.index>#cases then x.phase='done'; log('TC_COLD_OK demand-driven-monitor-maintenance') end
  end
end
function M.on_tick(event)
  local x=fixture(); if x.phase=='done' then return end
  if x.phase=='physical' then return physical_tick(event) end
  if x.phase=='frozen' then
    if not resumed then return end
    resumed=false; x.phase='cold-idle'; x.steps=180; x.measured=0
  end
  local root=registry.get(); local c=registry.computer(x.computer)
  for _,id in ipairs(root.order) do local rec=registry.record(id)
    assert(not rec.children.power)
    if rec.id==x.outage then rec.physical_error='fixture physical failure'
    elseif rec.physical_error=='fixture physical failure' then rec.physical_error=nil end
  end
  assert(#x.tiles==144)
  for _,id in ipairs(x.tiles) do local rec=registry.record(id)
    assert(rec and rec.body.valid and lifecycle.available(rec)==(id~=x.outage))
  end
  observer.begin(); scheduler.tick(event.tick); local counts=observer.finish()
  x.steps=x.steps+1
  assert(x.steps<600,'structural fixture deadline')
  if x.phase=='idle' and x.steps==120 then
    assert(c.status=='running' and #c.state.names==4,'structural producer setup failed')
    runtime.stop(c.id)
  end
  if x.steps==180 and x.phase=='one' then
    for id,g in pairs(root.monitors.groups) do x.fronts[id]=g.render end
  end
  if x.steps==180 then x.paint_start=c.state.painted or 0 end
  if x.steps<=180 then return end
  local passive=x.phase=='idle' or x.phase=='cold-idle' or x.phase=='outage' or x.phase=='restored'
  assert(c.status==(passive and 'stopped' or 'running'),serpent.line(c.diagnostic))
  log('TC_DEMAND_COUNTS phase='..x.phase..' '..serpent.line(counts))
  if observer.instrumented then assert((counts.topology or 0)==0,'unchanged tick rebuilt topology signature') end
  assert(counts.observation==144,'live observation missed or duplicated physical tiles')
  if passive then
    if observer.instrumented then assert((counts.full_proofs or 0)==0,'idle tick repeated full display proof') end
    for _,key in ipairs({'capture','frame','cell','cursor','native_create','native_retire','visibility','clear_cell'}) do assert((counts[key] or 0)==0,'idle presentation work: '..key) end
    local p=root.monitors.presentation
    assert(#p.jobs==0 and #p.retired==0 and #p.orphans==0,'idle work did not settle')
    for id,g in pairs(root.monitors.groups) do
      local hidden=x.outage and root.monitors.membership[x.outage]==id
      assert(g.render and (not not g.render.hidden)==(not not hidden)
        and g.render.cursor and g.render.cursor.valid,'missing complete blinking front or wrong power visibility')
      if x.fronts[id] then assert(g.render==x.fronts[id],'idle front replaced') else x.fronts[id]=g.render end
    end
  elseif x.phase=='one' then
    assert((counts.capture or 0)<=1,'one writer woke unrelated displays')
    local names=c.state.names
    for i=2,4 do assert(root.monitors.groups[names[i]].render==x.fronts[names[i]],'unchanged peer front replaced') end
  end
  x.measured=x.measured+1
  if x.measured<8 then return end
  if x.phase=='one' or x.phase=='all' then assert(c.state.painted>x.paint_start,'scheduled producer did not update') end
  log('TC_DEMAND_PASS phase='..x.phase..' samples='..x.measured..' tiles=144')
  if x.phase=='idle' then
    x.saved={presentation=root.monitors.presentation,spent=root.scheduler.maintenance_spent}
    x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif x.phase=='cold-idle' then
    x.outage=x.tiles[1]; x.phase='outage'; x.steps=0; x.measured=0
  elseif x.phase=='outage' then
    x.outage=nil; x.phase='restored'; x.steps=0; x.measured=0
  elseif x.phase=='restored' then
    start('one'); x.phase='one'; x.steps=0; x.measured=0
  elseif x.phase=='one' then
    start('all'); x.phase='all'; x.steps=0; x.measured=0
  else
    runtime.stop(c.id); x.phase='physical'; x.physical={stage='initial',changed=event.tick}
  end
end
return M
