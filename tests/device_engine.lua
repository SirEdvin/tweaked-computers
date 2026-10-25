-- Exact-engine compact physical checks. Host modules run in the fixture's
-- isolated storage, through the shipped build/remove and scheduler paths.
local defs=require('scripts.device-definitions')
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local runtime=require('scripts.runtime.computer')
local geometry=require('tests.device_contract')
local M={}
local loaded=false
registry.register_cleanup('fixture-refusal',function(rec)
  local fixture=storage.tc04_fixture
  if fixture and fixture.cleanup_refusal==rec.id then error('intentional cleanup refusal',0) end
end)
local function group(name)
  local f=storage.tc04_fixture; f.groups=f.groups+1; log('TC_CONTRACT '..name)
end
local function body(surface,kind,pos,direction)
  local entity=assert(surface.create_entity{name=defs.devices[kind].name,position=pos,direction=direction,force='player'})
  lifecycle.on_built{entity=entity}
  local rec=assert(registry.by_entity(entity),'public build path did not bind body')
  assert(lifecycle.build(entity)==rec,'duplicate build created a new identity')
  return rec
end
local function power(surface,pos)
  local pole=assert(surface.create_entity{name='substation',position={pos.x,pos.y+4},force='player'})
  local source=assert(surface.create_entity{name='electric-energy-interface',position={pos.x+3,pos.y+4},force='player'})
  source.power_production=1000000; source.power_usage=0
  return {pole=pole,source=source}
end
local function signal(port,name,count)
  local cb=port.get_or_create_control_behavior()
  for i=cb.sections_count,1,-1 do cb.remove_section(i) end
  local section=assert(cb.add_section())
  section.set_slot(1,{value={type='virtual',name=name,quality='normal'},min=count})
  cb.enabled=true
end
local function wire(a,b,color)
  local id=defines.wire_connector_id['circuit_'..color]
  assert(a.get_wire_connector(id,true).connect_to(b.get_wire_connector(id,true)))
end
local function value(port,color,name)
  local network=port.get_circuit_network(defines.wire_connector_id['circuit_'..color])
  return network and network.get_signal{type='virtual',name=name,quality='normal'} or 0
end
local function check_geometry(rec)
  local def=defs.devices[rec.kind]; local b=rec.body
  assert(b.direction==rec.direction and defs.cardinal(b.direction) and b.rotatable,'native body is not cardinal-rotatable')
  local box=b.selection_box; local w=box.right_bottom.x-box.left_top.x; local h=box.right_bottom.y-box.left_top.y
  local horizontal=b.direction==0 or b.direction==8
  assert(w==(horizontal and def.width or 1) and h==(horizontal and 1 or def.width),'selection footprint mismatch')
  local collision=b.bounding_box
  local cw=collision.right_bottom.x-collision.left_top.x; local ch=collision.right_bottom.y-collision.left_top.y
  assert(math.abs(cw-(horizontal and def.width-0.2 or 0.8))<0.02 and math.abs(ch-(horizontal and 0.8 or def.width-0.2))<0.02,'collision rotation mismatch')
  for i,role in ipairs(def.roles) do
    local p=assert(rec.children[role]); local x,y=defs.offset(rec.kind,i,b.direction)
    assert(p.position.x==b.position.x+x and p.position.y==b.position.y+y,'role position mismatch')
    assert(not p.minable and not p.destructible and not p.operable and not p.rotatable)
    assert(p.prototype.selection_priority>b.prototype.selection_priority)
    assert(p.force==b.force and p.surface==b.surface)
    local owner,bound=registry.by_entity(p); assert(owner==rec and bound==role)
    for _,color in ipairs({'red','green'}) do assert(lifecycle.connector(rec,role,color)) end
    if role~='output' then assert(p.get_control_behavior().sections_count==0 and not p.get_control_behavior().enabled) end
  end
end
local function check_wires()
  local f=storage.tc04_fixture
  for _,id in ipairs(f.logic_ids) do
    local rec=registry.record(id)
    assert(value(rec.children.input,'red','signal-A')==7)
    assert(value(rec.children.input,'red','signal-B')==0 and value(rec.children.input,'red','signal-C')==0)
    assert(value(rec.children.network,'red','signal-B')==11)
    assert(value(rec.children.network,'red','signal-A')==0 and value(rec.children.network,'red','signal-C')==0)
    assert(value(rec.children.output,'red','signal-C')==13 and value(rec.children.output,'green','signal-C')==13)
    assert(value(rec.children.output,'red','signal-A')==0 and value(rec.children.output,'red','signal-B')==0)
    local input=lifecycle.connector(rec,'input','red'); local network=lifecycle.connector(rec,'network','red'); local output=lifecycle.connector(rec,'output','red')
    assert(input.network_id~=network.network_id and output.network_id~=network.network_id and input.network_id~=output.network_id)
  end
  for _,id in ipairs(f.config_ids) do
    local rec=registry.record(id)
    assert(value(rec.children.network,'red','signal-A')==3 and value(rec.children.network,'red','signal-B')==0)
    assert(value(rec.children.targets,'red','signal-B')==5 and value(rec.children.targets,'red','signal-A')==0)
    assert(lifecycle.connector(rec,'network','red').network_id~=lifecycle.connector(rec,'targets','red').network_id)
  end
end
local source=[[return {api_version=1,handlers={
start=function(e) computer.setState('boots',(computer.getState('boots') or 0)+1); computer.setState('restores',0); computer.on('power_restored','restore'); computer.every(100,'timer') end,
restore=function(e) computer.setState('restores',computer.getState('restores')+1) end,
timer=function(e) computer.setState('timers',(computer.getState('timers') or 0)+1) end
}}]]
function M.run()
  registry.initialize()
  storage.tc04_fixture={phase='warming',groups=0,logic_ids={},config_ids={},ids={},grids={}}
  local f=storage.tc04_fixture; f.groups=geometry.run()
  local surface=game.surfaces[1]
  for row,direction in ipairs({0,4,8,12}) do
    for col,kind in ipairs(defs.order) do
      local rec=body(surface,kind,{x=col*16,y=row*16},direction)
      check_geometry(rec)
      f.ids[#f.ids+1]=rec.id
      f.grids[#f.grids+1]=power(surface,rec.body.position)
      if kind=='logic' then
        f.logic_ids[#f.logic_ids+1]=rec.id
        local pos=rec.body.position
        local input=assert(surface.create_entity{name='constant-combinator',position={pos.x-3,pos.y-3},force='player'})
        local network=assert(surface.create_entity{name='constant-combinator',position={pos.x+3,pos.y-3},force='player'})
        local red=assert(surface.create_entity{name='constant-combinator',position={pos.x-3,pos.y+2},force='player'})
        local green=assert(surface.create_entity{name='constant-combinator',position={pos.x+3,pos.y+2},force='player'})
        signal(input,'signal-A',7); signal(network,'signal-B',11)
        wire(input,rec.children.input,'red'); wire(network,rec.children.network,'red')
        wire(rec.children.output,red,'red'); wire(rec.children.output,green,'green')
      elseif kind=='configurator' then
        f.config_ids[#f.config_ids+1]=rec.id
        local pos=rec.body.position
        local network=assert(surface.create_entity{name='constant-combinator',position={pos.x-3,pos.y-3},force='player'})
        local targets=assert(surface.create_entity{name='constant-combinator',position={pos.x+3,pos.y-3},force='player'})
        signal(network,'signal-A',3); signal(targets,'signal-B',5)
        wire(network,rec.children.network,'red'); wire(targets,rec.children.targets,'red')
      end
    end
  end
  group('native_all_six_footprints_cardinal_owned_connectors')
  -- Real rotation retains exact native children (not rebuilding them or wires).
  for _,kind in ipairs({'logic','configurator','recipe_searcher'}) do
    local rec=body(surface,kind,{x=16,y=100+(kind=='logic' and 0 or 12)},0)
    local child=rec.children.network; local unit=child.unit_number
    local external=assert(surface.create_entity{name='constant-combinator',position={x=16,y=rec.body.position.y-3},force='player'})
    wire(child,external,'red')
    assert(lifecycle.connector(rec,'network','red').connection_count==1)
    for _,direction in ipairs({4,8,12,0}) do
      local previous=rec.body.direction; rec.body.direction=direction
      lifecycle.on_rotated{entity=rec.body,previous_direction=previous}
      assert(rec.body.direction==direction and rec.children.network==child and child.unit_number==unit)
      assert(lifecycle.connector(rec,'network','red').connection_count==1,'rotation lost native wire')
      check_geometry(rec)
    end
    local children={}; for _,p in pairs(rec.children) do children[#children+1]=p end
    lifecycle.on_removed{entity=rec.body}
    local inventory=game.create_inventory(1)
    assert(rec.body.mine{inventory=inventory,raise_destroyed=false})
    assert(inventory.get_item_count(defs.devices[kind].name)==1)
    for _,p in ipairs(children) do assert(not p.valid) end
    inventory.destroy()
    local replacement=body(surface,kind,{x=16,y=100+(kind=='logic' and 0 or 12)},0)
    assert(replacement.id~=rec.id and not lifecycle.remove(rec.id,'stale',true) and replacement.body.valid)
    assert(lifecycle.remove(replacement.id,'fixture',true))
  end
  group('native_rotation_identity_one_drop_and_exact_removal')
  -- Host-only failure injection: first child is real, second allocation refuses.
  local failed=assert(surface.create_entity{name='tc-logic',position={32,100},force='player'})
  local created={}; local calls=0
  local proxy={name=failed.name,valid=true,direction=failed.direction,position=failed.position,force=failed.force,quality=failed.quality,
    surface={create_entity=function(args) calls=calls+1; if calls==2 then return nil end; local p=surface.create_entity(args); created[#created+1]=p; return p end}}
  local rec,e=lifecycle.build(proxy)
  assert(not rec and e.code=='E_ENGINE' and #created==1 and not created[1].valid and failed.valid)
  assert(not registry.by_entity(failed))
  -- Same real failure through the event handler returns the consumed robot item.
  calls=0; proxy.destroy=failed.destroy
  local robot=assert(surface.create_entity{name='construction-robot',position={32,104},force='player'})
  local consumed=game.create_inventory(1); consumed[1].set_stack{name='tc-logic',count=3}
  lifecycle.on_built{entity=proxy,robot=robot,stack=consumed[1]}
  assert(not failed.valid and robot.get_inventory(defines.inventory.robot_cargo).get_item_count('tc-logic')==1)
  assert(consumed[1].count==3,'refund changed the source stack')
  assert(#created==2 and not created[2].valid)
  consumed.destroy(); robot.destroy()
  group('real_partial_allocation_rollback_no_orphan_robot_refund')
  local mine=body(surface,'kv',{x=32,y=112},0)
  local child=mine.children.network
  f.cleanup_refusal=mine.id
  assert(not lifecycle.remove(mine.id,'refusal',true) and mine.body.valid and child.valid and registry.record(mine.id)==mine)
  f.cleanup_refusal=nil; assert(lifecycle.remove(mine.id,'retry',true)); assert(not child.valid)
  group('cleanup_refusal_retains_exact_composite')
  local tech=game.forces.player.technologies['tc-circuit-computers']
  assert(not tech.researched)
  for _,kind in ipairs(defs.order) do
    local recipe=game.forces.player.recipes[defs.devices[kind].name]
    assert(not recipe.enabled)
    for _,ingredient in ipairs(recipe.ingredients) do assert(prototypes.item[ingredient.name]) end
  end
  tech.researched=true
  for _,kind in ipairs(defs.order) do
    local def=defs.devices[kind]
    assert(game.forces.player.recipes[def.name].enabled==(def.technology==tech.name))
  end
  lifecycle.unlocks(); assert(not game.forces.player.recipes['tc-recipe-searcher'].enabled)
  game.forces.player.technologies['tc-recipe-searcher'].researched=true
  lifecycle.unlocks(); assert(game.forces.player.recipes['tc-recipe-searcher'].enabled)
  local fresh=game.create_force('tc04-fresh'); assert(not fresh.technologies['tc-circuit-computers'].researched)
  for _,kind in ipairs(defs.order) do assert(not fresh.recipes[defs.devices[kind].name].enabled) end
  group('native_research_unlocks_base_materials_fresh_force')
  f.crafts={}
  local craft_surface=game.create_surface('tc04-crafting',{width=64,height=32})
  for index,kind in ipairs(defs.order) do
    local def=defs.devices[kind]
    local assembler=assert(craft_surface.create_entity{name='assembling-machine-3',position={x=index*8-24,y=0},force='player'})
    assembler.set_recipe(def.name)
    local inventory=assembler.get_inventory(defines.inventory.crafter_input)
    for _,ingredient in ipairs(def.ingredients) do assert(inventory.insert{name=ingredient[1],count=ingredient[2]}==ingredient[2]) end
    f.crafts[#f.crafts+1]={entity=assembler,name=def.name}
    f.grids[#f.grids+1]=power(craft_surface,assembler.position)
  end
  local p=game.create_surface('tc04-power',{width=32,height=32})
  local good=body(p,'computer',{x=0,y=0},0)
  local bad=body(p,'computer',{x=-4,y=0},0)
  local logic=body(p,'logic',{x=4,y=0},0)
  local kv=body(p,'kv',{x=-4,y=-4},0)
  local monitor=body(p,'monitor',{x=0,y=-4},0)
  local config=body(p,'configurator',{x=4,y=-4},0)
  f.power_ids={good.id,bad.id,logic.id,kv.id,monitor.id,config.id}; f.power_grid=power(p,{x=0,y=0})
  f.good=good.id; f.bad=bad.id; f.power_logic=logic.id
  f.power_sensor=assert(p.create_entity{name='constant-combinator',position={7,2},force='player'})
  wire(logic.children.output,f.power_sensor,'red'); wire(logic.children.output,f.power_sensor,'green')
  runtime.save(good.id,source,0); assert(runtime.activate(good.id,game.tick))
  runtime.save(bad.id,'return {api_version=1,handlers={start=function(e) pcall(function() while true do end end) end}}',0)
  assert(runtime.activate(bad.id,game.tick))
  local protected_inventory=game.create_inventory(1)
  assert(not good.body.mine{inventory=protected_inventory,raise_destroyed=false})
  assert(not kv.body.mine{inventory=protected_inventory,raise_destroyed=false})
  assert(good.body.valid and kv.body.valid and good.saved_source==source and registry.record(good.id)==good)
  assert(protected_inventory.is_empty()); protected_inventory.destroy()
  group('interim_snapshot_guard_refuses_destructive_plain_mining')
  f.start_tick=game.tick
  log('TC_CONTRACT_TOTAL '..f.groups)
end
local function frozen_check()
  local f=storage.tc04_fixture; local saved=f.snapshot; local rec=registry.record(f.good)
  assert(rec.id==saved.id and rec.body.unit_number==saved.unit and rec.children.network.unit_number==saved.port)
  assert(rec.run_id==saved.run_id and rec.active.source==source and rec.state.boots==1 and rec.state.restores==1)
  assert(rec.powered==saved.powered and rec.body.energy==saved.energy)
  local root=registry.get()
  assert(root.ledger.tick==saved.tick and root.ledger.total==saved.total and root.scheduler.last_tick==saved.scheduler_tick)
  for _,id in ipairs(f.ids) do check_geometry(registry.record(id)) end
end
function M.on_load()
  loaded=true
  if storage.tc04_fixture.phase=='frozen' then frozen_check(); log('TC_COLD_ON_LOAD_UNCHANGED') end
end
function M.on_configuration_changed()
  local f=storage.tc04_fixture
  assert(f.phase=='frozen')
  -- Production on_configuration_changed has already reapplied researched unlocks.
  for _,kind in ipairs(defs.order) do assert(game.forces.player.recipes[defs.devices[kind].name].enabled,'researched unlock not restored') end
  f.upgraded=true
  log('TC_UPGRADE_UNLOCKS_OK')
end
function M.on_tick(event)
  local f=storage.tc04_fixture
  if f.phase=='done' then return end
  if f.phase=='frozen' then
    if not loaded then return end
    frozen_check(); check_wires(); loaded=false
    if f.upgraded then log('TC_UPGRADE_OK exact-body-port-retention researched-unlocks')
    else
      for _,kind in ipairs(defs.order) do assert(not game.forces.player.recipes[defs.devices[kind].name].enabled,'ordinary load unexpectedly migrated unlocks') end
      log('TC_COLD_OK exact-owned-ports power-state native-source no-on-load-mutation')
    end
    f.phase='done'; return
  end
  loaded=false
  scheduler.tick(event.tick)
  assert(event.tick<f.start_tick+240,'physical/crafting smoke deadline exceeded')
  local good=registry.record(f.good); local bad=registry.record(f.bad)
  if f.phase=='warming' then
    if not good.state.boots then return end
    if bad.status~='faulted' then
      log('TC_WARM_WAIT good='..good.status..' bad='..bad.status..' powered='..tostring(bad.powered)..' queue='..#bad.queue)
      return
    end
    assert(good.status=='running' and good.state.boots==1,good.diagnostic and good.diagnostic.message)
    for _,craft in ipairs(f.crafts) do
      if craft.entity.get_inventory(defines.inventory.crafter_output).get_item_count(craft.name)==0 then return end
      assert(craft.entity.products_finished==1 and craft.entity.get_inventory(defines.inventory.crafter_input).is_empty())
    end
    log('TC_NATIVE_CRAFTING_OK all-five exact-base-ingredients one-item unmodified-native-production')
    for _,id in ipairs(f.power_ids) do assert(registry.record(id).powered) end
    for _,id in ipairs(f.logic_ids) do local rec=registry.record(id); assert(rec.powered); signal(rec.children.output,'signal-C',13) end
    signal(registry.record(f.power_logic).children.output,'signal-C',17)
    f.phase='signals'; f.phase_tick=event.tick
  elseif f.phase=='signals' and event.tick>=f.phase_tick+3 then
    check_wires()
    assert(value(f.power_sensor,'red','signal-C')==17 and value(f.power_sensor,'green','signal-C')==17)
    log('TC_PHYSICAL_NATIVE_WIRES_OK all-cardinal role-isolation no-leaks mirrored-output')
    -- Check steady draw in joules/tick using the native power usage and buffer.
    for _,id in ipairs(f.power_ids) do
      local rec=registry.record(id); local watts=defs.devices[rec.kind].watts
      assert(math.abs(rec.body.power_usage-watts/60)<0.001 and math.abs(rec.body.electric_buffer_size-watts/30)<0.001)
    end
    f.draw_energy={}
    for _,id in ipairs(f.power_ids) do f.draw_energy[id]=registry.record(id).body.energy end
    f.power_grid.pole.destroy() -- Isolate real buffers for a one-tick consumption readback.
    f.power_grid.source.power_production=0; f.power_grid.source.energy=0
    f.phase='outage'; f.phase_tick=event.tick
  elseif f.phase=='outage' and event.tick==f.phase_tick+1 then
    for _,id in ipairs(f.power_ids) do
      local rec=registry.record(id); local expected=defs.devices[rec.kind].watts/60
      local consumed=f.draw_energy[id]-rec.body.energy
      assert(math.abs(consumed-expected)<0.02,'native per-tick consumption mismatch '..rec.kind..': '..consumed..' vs '..expected)
    end
    log('TC_NATIVE_CONSUMPTION_OK computer=1000J kv=500J monitor=250J logic=250J configurator=500J per-tick')
  elseif f.phase=='outage' and event.tick>=f.phase_tick+8 then
    for _,id in ipairs(f.power_ids) do assert(not registry.record(id).powered,'native outage not sampled') end
    local logic=registry.record(f.power_logic)
    assert(not logic.children.output.get_control_behavior().enabled and logic.children.output.get_control_behavior().sections_count==0)
    assert(value(f.power_sensor,'red','signal-C')==0 and value(f.power_sensor,'green','signal-C')==0,'outage signal contribution survived')
    assert(good.status=='running' and good.state.boots==1 and good.state.restores==0 and next(good.timers))
    assert(lifecycle.connector(good,'network','red'),'outage removed passive connector')
    f.power_grid.pole=assert(good.body.surface.create_entity{name='substation',position={0,4},force='player'})
    f.power_grid.source.power_production=1000000
    f.phase='restore'; f.phase_tick=event.tick
  elseif f.phase=='restore' and good.state.restores==1 then
    assert(good.state.boots==1 and good.powered and good.needs_input_resync)
    for _,id in ipairs(f.power_ids) do assert(registry.record(id).powered) end
    log('TC_PHYSICAL_NATIVE_POWER_OK pause durable-state fail-safe restoration neighbour-safe malicious-source')
    -- No electrical participant can consume/refill a body after expected capture.
    for _,grid in ipairs(f.grids) do grid.source.power_production=0; grid.source.energy=0; grid.pole.destroy() end
    f.power_grid.source.power_production=0; f.power_grid.source.energy=0; f.power_grid.pole.destroy()
    for _,rec in pairs(registry.get().computers) do if rec.physical_version then rec.body.power_usage=0 end end
    for _,rec in pairs(registry.get().devices) do if rec.physical_version then rec.body.power_usage=0 end end
    -- Deliberately stale unlocks separate ordinary reload from config migration.
    for _,kind in ipairs(defs.order) do game.forces.player.recipes[defs.devices[kind].name].enabled=false end
    local root=registry.get()
    f.snapshot={id=good.id,unit=good.body.unit_number,port=good.children.network.unit_number,run_id=good.run_id,
      powered=good.powered,energy=good.body.energy,tick=root.ledger.tick,total=root.ledger.total,scheduler_tick=root.scheduler.last_tick}
    f.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  end
end
return M
