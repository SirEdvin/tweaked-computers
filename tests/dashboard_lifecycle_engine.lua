-- Real robot transfer, maximum state, cold credits and optional-library changes.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local snapshots=require('scripts.lifecycle-data')
local blueprints=require('scripts.blueprints')
local model=require('scripts.dashboard-model')
local presentation=require('scripts.ui.dashboard-charts')
local runtime=require('scripts.runtime.computer')
local shell=require('scripts.runtime.shell')
local scheduler=require('scripts.scheduler')
local limits=require('scripts.runtime.limits')
local data=require('scripts.runtime.data')
local M={}; local resumed=false
local function f() return storage.tc_dashboard_lifecycle end
local function build(kind,position,surface,force)
  local body=assert((surface or game.surfaces[1]).create_entity{name=kind=='computer' and 'tc-computer-shell' or 'tc-dashboard-shell',position=position,force=force or 'tc-dashboard-owner'})
  lifecycle.on_built{entity=body}; return assert(registry.by_entity(body))
end
local function evaluate(c,source)
  local ok,e=shell.evaluate(c,source,game.tick,1); assert(ok,serpent.line(e))
end
local function draw(panel)
  local tab=panel.dashboard.tabs['1']; local node=model.widget(tab,'line')
  presentation.begin(); local key=presentation.show(panel,1,node,tab)
  presentation.view(key,{valid=true,style={minimal_width=450,minimal_height=350}},{},1)
  presentation.finish(scheduler.maintenance(registry.get(),game.tick,true))
  return assert(registry.get().dashboard_presentation.states[key])
end
local function maximum(panel)
  model.set_tab(panel,1,{title='Retained charts',content={type='column',id='root',children={
    {type='label',id='status',text='Retained'}, {type='button',id='button',text='Go'},
    {type='line',id='line',series={'a','b'},capacity=3},
    {type='stacked_bars',id='bars',phases={'work','wait'}}}}},function() end)
  for i=1,5 do model.append(panel,1,'line',{a=i,b=2*i},function() end) end
  model.bars(panel,1,'bars',{{work=1,wait=2},{work=3,wait=1}},function() end)
  for slot=2,6 do
    model.set_tab(panel,slot,{title='Retained '..slot,content={type='label',id='text',text=''}},function() end)
    local remaining=limits.state_bytes-model.usage(panel.dashboard,function() end)
    model.set_leaf(panel,slot,'text',string.rep('x',math.min(remaining,limits.string_bytes)),false,function() end)
    if model.usage(panel.dashboard,function() end)==limits.state_bytes then break end
  end
  assert(model.usage(panel.dashboard,function() end)==limits.state_bytes)
  panel.label=string.rep('L',limits.identifier_bytes)
end
local function checkpoint(name,marker)
  game.server_save(name); log(marker)
end
function M.run()
  assert(model.charts,'initial lifecycle phase requires the exact chart archive')
  local surface=game.surfaces[1]; surface.request_to_generate_chunks({0,0},2); surface.force_generate_chunk_requests()
  for _,e in ipairs(surface.find_entities_filtered{area={{-12,-12},{28,28}},type={'tree','simple-entity','cliff'}}) do e.destroy() end
  local tiles={}; for y=-12,28 do for x=-12,28 do tiles[#tiles+1]={name='landfill',position={x,y}} end end; surface.set_tiles(tiles)
  local force=game.create_force('tc-dashboard-owner')
  local c=build('computer',{0,0}); local panel=build('dashboard',{3,0})
  for _,wire in ipairs({'red','green'}) do assert(lifecycle.connector(c,'network',wire).connect_to(lifecycle.connector(panel,'network',wire))) end
  local generator=assert(surface.create_entity{name='electric-energy-interface',position={12,7},force=force})
  generator.power_production=100000000; generator.power_usage=0
  for _,pos in ipairs({{5,5},{8,15}}) do assert(surface.create_entity{name='substation',position=pos,force=force}) end
  local roboport=assert(surface.create_entity{name='roboport',position={8,19},force=force})
  roboport.energy=100000000; assert(roboport.get_inventory(defines.inventory.roboport_robot).insert{name='construction-robot',count=1}==1)
  local chest=assert(surface.create_entity{name='storage-chest',position={13,19},force=force})
  local source=[[function start()
  peripheral.find('dashboard','red').subscribe('clicked')
  computer.setState('boots',(computer.getState('boots') or 0)+1)
end

function clicked() computer.setState('effects',(computer.getState('effects') or 0)+1) end]]
  assert(runtime.save(c.id,source,0)); assert(runtime.activate(c.id,game.tick))
  storage.tc_dashboard_lifecycle={phase='power',origin=game.tick,c=c.id,panel=panel.id,original=panel.id,generator=generator,chest=chest}
end
script.on_event(defines.events.on_robot_mined_entity,function(event)
  local rec=registry.by_entity(event.entity); local id=rec and rec.id
  lifecycle.on_removed(event)
  if f() and id==f().original then f().robot_mined=true; log('TC_DASHBOARD_LIFECYCLE native-robot-max-state-mined') end
end)
script.on_event(defines.events.on_robot_built_entity,function(event)
  lifecycle.on_built(event)
  local rec=registry.by_entity(event.entity)
  if f() and f().phase=='robot' and rec and rec.kind=='dashboard' then
    assert(rec.id~=f().original and model.equal(rec.dashboard,f().expected.model))
    assert(rec.label==f().expected.label and not rec.subscriptions)
    f().panel=rec.id; f().robot_built=true; log('TC_DASHBOARD_LIFECYCLE native-robot-max-state-replaced-new-identity')
  end
end)
function M.on_load() resumed=f().phase=='frozen' end
function M.on_configuration_changed()
  local x=f()
  if x.phase=='waiting-absent' then assert(not model.charts); x.phase='absent-cleanup'
  elseif x.phase=='waiting-present' then assert(model.charts); x.phase='present'
  else error('unexpected dashboard lifecycle configuration phase '..x.phase) end
end
function M.on_tick(event)
  local x=f(); local c=registry.record(x.c); local panel=registry.record(x.panel); local root=registry.get()
  if x.phase=='waiting-absent' or x.phase=='waiting-present' or x.phase=='done' then return end
  if x.phase=='frozen' then
    if not resumed then return end
    assert(panel.dashboard==x.retained and c.state.boots==1 and not c.state.effects)
    assert(root.ledger.tick==x.credits.tick and root.ledger.total==x.credits.total
      and root.scheduler.maintenance_tick==x.credits.maintenance_tick and root.scheduler.maintenance_spent==x.credits.maintenance_spent)
    evaluate(c,'assert(append==p.appendSample and base==p.getLimits)')
    local owned=draw(panel); x.surface=root.dashboard_presentation.surface.surface; x.objects=owned.objects
    x.world=rendering.draw_text{surface=game.surfaces[1],target={0,0},text='Unrelated rendering',color={1,1,1}}
    x.phase='waiting-absent'; checkpoint('tc-dashboard-dependency','TC_COLD_OK'); return
  end
  assert(event.tick-x.origin<1800,'dashboard lifecycle deadline '..x.phase)
  scheduler.tick(event.tick)
  if x.phase=='power' then
    if c.state.boots~=1 or not panel.powered then return end
    maximum(panel); x.expected=snapshots.dashboard_snapshot(panel)
    local copied=assert(panel.body.clone{position={18,0},surface=panel.body.surface,force=panel.body.force})
    local clone=assert(registry.by_entity(copied))
    assert(#clone.dashboard.tabs['1'].charts.line.data==0 and #clone.dashboard.tabs['1'].charts.bars==0)
    assert(model.equal(clone.dashboard.tabs['1'].definition,panel.dashboard.tabs['1'].definition))
    for i=101,103 do model.append(clone,1,'line',{a=i,b=i},function() end) end
    snapshots.apply_settings(clone,snapshots.settings(panel))
    assert(clone.dashboard.tabs['1'].charts.line.sum.a==306,'settings copy imported source history')
    local changed=snapshots.settings(panel); changed.dashboard.tabs['1'].content.children[3].capacity=2
    snapshots.apply_settings(clone,changed)
    assert(#clone.dashboard.tabs['1'].charts.line.data==0 and panel.dashboard.tabs['1'].charts.line.sum.a==12)
    lifecycle.remove(clone.id,'fixture-clone-cleanup',true)
    local inv=game.create_inventory(1); inv[1].set_stack{name='blueprint'}
    local mapping=inv[1].create_blueprint{surface=panel.body.surface,force=panel.body.force,area={{2,-1},{4,1}},always_include_tiles=false}
    assert(blueprints.prepare(inv[1],mapping))
    local entries=inv[1].get_blueprint_entities(); local definition
    for _,entry in ipairs(entries) do if entry.name=='tc-dashboard-shell' then definition=entry.tags.tc_settings.dashboard end end
    assert(definition and definition.tabs['1'].content.children[3].type=='line' and not definition.tabs['1'].charts)
    local target=build('dashboard',{21,0}); snapshots.apply_settings(target,{version=1,kind='dashboard',dashboard=definition})
    assert(#target.dashboard.tabs['1'].charts.line.data==0); lifecycle.remove(target.id,'fixture-blueprint-cleanup',true); inv.destroy()
    assert(panel.body.order_deconstruction(panel.body.force))
    assert(panel.body.surface.create_entity{name='entity-ghost',inner_name='tc-dashboard-shell',position={6,0},force=panel.body.force})
    x.phase='robot'
  elseif x.phase=='robot' then
    if not x.robot_mined or not x.robot_built then return end
    assert(model.equal(panel.dashboard,x.expected.model) and model.usage(panel.dashboard,function() end)==limits.state_bytes)
    for _,wire in ipairs({'red','green'}) do assert(lifecycle.connector(c,'network',wire).connect_to(lifecycle.connector(panel,'network',wire))) end
    x.item=game.create_inventory(1); x.item[1].set_stack{name='tc-dashboard',count=1}; x.item[1].tags={tc_dashboard=snapshots.dashboard_snapshot(panel)}
    assert(model.equal(x.item[1].tags.tc_dashboard,x.expected))
    c.shell={version=1,id=c.id..'/dashboard-fixture-shell',pending={},pending_bytes=0}
    x.phase='capture'
  elseif x.phase=='capture' then
    if not panel.powered then return end
    evaluate(c,"p=peripheral.find('dashboard','red'); append=p.appendSample; base=p.getLimits; assert(type(append)=='function')")
    x.retained=panel.dashboard
    x.credits={tick=root.ledger.tick,total=root.ledger.total,maintenance_tick=root.scheduler.maintenance_tick,maintenance_spent=root.scheduler.maintenance_spent}
    x.phase='frozen'; checkpoint('tc03-snapshot','TC_COLD_SNAPSHOT_REQUESTED')
  elseif x.phase=='absent-cleanup' then
    if x.surface.valid then return end
    for _,object in ipairs(x.objects) do assert(not object.valid) end
    assert(x.world.valid and panel.dashboard==x.retained and model.equal(panel.dashboard,x.expected.model))
    x.phase='absent'
  elseif x.phase=='absent' then
    if not panel.powered or not c.powered then return end
    -- The captured method alone is unavailable; authentic base bindings survive.
    evaluate(c,"assert(p.appendSample==nil and type(append)=='function'); local ok,e=pcall(append,1,'line',{a=6,b=12}); assert(not ok and e.code=='E_ARGUMENT'); assert(base().dashboard_tabs==6 and p.getTab(1).title=='Retained charts')")
    local body=assert(game.surfaces[1].create_entity{name='tc-dashboard-shell',position={10,0},force=c.body.force})
    lifecycle.on_built{entity=body,consumed_items=x.item}
    local restored=assert(registry.by_entity(body))
    assert(restored.id~=panel.id and model.equal(restored.dashboard,x.expected.model) and restored.label==x.expected.label)
    local bad=snapshots.dashboard_snapshot(restored); bad.version=99; local prior=restored.dashboard
    local ok=pcall(snapshots.restore_dashboard,restored,bad); assert(not ok and restored.dashboard==prior)
    lifecycle.remove(restored.id,'fixture-absent-item-cleanup',true)
    assert(model.equal(panel.dashboard,x.expected.model) and c.state.boots==1 and not c.state.effects)
    x.phase='waiting-present'; checkpoint('tc-dashboard-reinstall','TC_DASHBOARD_DEPENDENCY_ABSENT_OK')
  elseif x.phase=='present' then
    if not panel.powered or not c.powered then return end
    evaluate(c,'assert(append==p.appendSample and base==p.getLimits)')
    assert(model.equal(panel.dashboard,x.expected.model) and c.state.boots==1 and not c.state.effects)
    local owned=draw(panel); assert(owned.objects[1].valid and x.world.valid)
    x.phase='outage'; x.generation=panel.dashboard
    x.generator.power_production=0; x.generator.energy=0
    lifecycle.power_entity(panel).energy=0; lifecycle.power_entity(c).energy=0
  elseif x.phase=='outage' then
    if panel.powered or c.powered then return end
    assert(panel.dashboard==x.generation and c.state.boots==1 and not c.state.effects)
    assert(next(root.dashboard_presentation.states)==nil and x.world.valid)
    x.generator.power_production=100000000; x.phase='restore-power'
  elseif x.phase=='restore-power' then
    if not panel.powered or not c.powered then return end
    assert(panel.dashboard==x.generation and c.state.boots==1 and not c.state.effects)
    local force=game.create_force('tc-dashboard-moved-force'); game.merge_forces(panel.body.force,force)
    x.force_index=force.index; x.phase='force'
  elseif x.phase=='force' then
    if panel.force_index~=x.force_index or c.force_index~=x.force_index then return end
    assert(panel.dashboard==x.generation and c.status=='stopped' and c.state.boots==1)
    local force=game.forces[x.force_index]
    local surface=game.create_surface('tc-dashboard-removal',{width=32,height=32})
    local removed=build('dashboard',{0,0},surface,force)
    snapshots.restore_dashboard(removed,x.expected)
    x.removed=removed.id; x.removed_surface=surface; assert(game.delete_surface(surface)); x.phase='remove'
  elseif x.phase=='remove' then
    if x.removed_surface.valid then return end
    assert(not registry.record(x.removed) and panel.dashboard==x.generation and x.world.valid)
    assert(panel.body.die()); assert(not registry.record(x.panel))
    x.world.destroy(); x.item.destroy()
    helpers.write_file('dashboard-lifecycle.json',helpers.table_to_json{passed=true,boots=c.state.boots,effects=c.state.effects or 0,
      original=x.original,replacement=x.panel,model=x.expected.model,label=x.expected.label,bytes=model.usage(x.expected.model,function() end),
      robot_mined=x.robot_mined,robot_built=x.robot_built,cold_credits=x.credits},false)
    x.phase='done'; checkpoint('tc-dashboard-final','TC_DASHBOARD_DEPENDENCY_PRESENT_OK')
  end
end
return M
