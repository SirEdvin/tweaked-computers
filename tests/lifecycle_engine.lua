-- One compact packaged native lifecycle fixture; GUI/player routes are labelled doubles.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local limits=require('scripts.runtime.limits')
local snapshots=require('scripts.lifecycle-data')
local blueprints=require('scripts.blueprints')
local kv=require('scripts.services.kv')
local monitor=require('scripts.services.monitor')
local model=require('scripts.monitor-model')
local logic=require('scripts.services.logic')
local defs=require('scripts.device-definitions')
local editor=require('scripts.ui.editor-model')
local M={}; local loaded=false
local function nop() end
local function f() return storage.tc12 end
local function group(name) f().groups=f().groups+1; log('TC_CONTRACT '..name) end
local function build(kind,x,y,surface)
  local b=assert((surface or game.surfaces[1]).create_entity{name=defs.devices[kind].name,position={x,y},force='player'})
  lifecycle.on_built{entity=b}; local r=assert(registry.by_entity(b)); b.energy=defs.devices[kind].watts/30; r.powered=true
  return r
end
local function mine(rec)
  local inv=game.create_inventory(1); inv[1].set_stack{name=rec.body.name,count=1,quality=rec.body.quality}
  lifecycle.on_removed{entity=rec.body,buffer=inv,tick=game.tick}; rec.body.destroy(); return inv
end
local function replace(inv,x,y)
  local body=assert(game.surfaces[1].create_entity{name=inv[1].name,position={x,y},force='player'})
  lifecycle.on_built{entity=body,consumed_items=inv}; return assert(registry.by_entity(body))
end
local source="return {api_version=1,handlers={start=function(e) computer.setState('boots',(computer.getState('boots') or 0)+1); computer.after(600,'wake') end,wake=function(e) computer.setState('wakes',1) end}}"
local saved='-- saved but not applied\n'..source
local function fixture_state(rec)
  -- Exactly the public state capacity, independently admitted by the importer.
  local state={}; for i=1,4 do state['k'..i]=string.rep(string.char(i),i==4 and 16264 or 16384) end
  -- 16 + four (key 2 + metadata 16 + string header 8) + content 65416 = 65536.
  local c=snapshots.import_computer{version=1,saved_source=rec.saved_source,saved_revision=rec.saved_revision,state=state}
  for _,k in ipairs({'state','state_bytes','state_nodes','state_entries','state_sizes','state_node_sizes'}) do rec[k]=c[k] end
  assert(rec.state_bytes==limits.state_bytes,'fixture must reach accepted state capacity')
end
script.on_event(defines.events.on_entity_cloned,lifecycle.on_cloned)
script.on_event(defines.events.script_raised_revive,lifecycle.on_built)
script.on_event(defines.events.script_raised_built,lifecycle.on_built)
script.on_event(defines.events.on_pre_surface_deleted,lifecycle.on_surface_removed)
script.on_event(defines.events.on_forces_merging,lifecycle.on_forces_merging)
script.on_event(defines.events.on_robot_mined_entity,function(event)
  local rec=registry.by_entity(event.entity)
  if rec then lifecycle.on_removed(event); if rec.id==f().robot_id then f().robot_mined=true; log('TC_NATIVE_COMPUTER_ROBOT_MINED') end end
end)
function M.run()
  registry.initialize(); storage.tc12={groups=0,phase='start'}
  local c=build('computer',0,0); runtime.save(c.id,source,0); assert(runtime.activate(c.id,game.tick))
  assert(scheduler.dispatch(c,game.tick)); assert(c.state.boots==1 and next(c.timers))
  runtime.save(c.id,saved,c.saved_revision); c.label='private literal label'
  fixture_state(c)
  local root=registry.get(); root.player_drafts[1]={documents={[c.id]={source='unsaved recoverable draft',base_source=saved,base_revision=c.saved_revision}},session={id=c.id,token=1}}
  local inv=mine(c); local s=inv[1].tags.tc_computer
  assert(s.saved_source==saved and s.active.source==source and s.label==c.label and s.state.k1==c.state.k1)
  assert(root.player_drafts[1].documents[c.id].source=='unsaved recoverable draft')
  local restored=replace(inv,0,0)
  assert(restored.id~=c.id and restored.status=='stopped' and not restored.run_id and next(restored.queue)==nil and next(restored.timers)==nil and next(restored.subscriptions)==nil)
  assert(restored.state_bytes==65536 and restored.active.source==source and restored.saved_source==saved)
  assert(not lifecycle.remove(c.id,'stale',true) and restored.body.valid)
  inv.destroy(); f().restored=restored.id
  group('maximum-state-distinct-source-material-item-new-identity-stopped-draft-recovery')
  local player={valid=true,index=7,force=restored.body.force,surface=restored.body.surface,can_reach_entity=function() return true end}
  local session,draft=editor.open(player,restored.id)
  editor.action(player,session.token,'review-active',game.tick)
  editor.action(player,session.token,'copy-active',game.tick)
  assert(draft.source==source and restored.saved_source==saved and restored.status=='stopped')
  editor.close(player.index,session.token)
  local before=restored.state
  for _,bad in ipairs({{version=99}, {version=1,saved_source='',saved_revision=0,state={bad=function() end}},
    {version=1,saved_source='',saved_revision=0,state={bad=0/0}}, {version=1,saved_source='',saved_revision=0,state={bad=setmetatable({},{})}}}) do
    assert(not pcall(snapshots.restore_computer,restored,bad,false)); assert(restored.state==before)
  end
  local cycle={}; cycle.self=cycle
  assert(not pcall(snapshots.import_computer,{version=1,saved_source='',saved_revision=0,state=cycle}))
  restored.schema_version=99; snapshots.initialize_computer(restored)
  assert(not restored.body.minable and restored.state==before and restored.saved_source==saved)
  restored.schema_version=1; snapshots.initialize_computer(restored); assert(restored.body.minable)
  group('malicious-and-unsupported-snapshots-inert-recoverable-without-data-replacement')
  for i,kind in ipairs(defs.order) do
    local r=build(kind,i*4,12)
    local child=r.children.network
    for _,dir in ipairs({4,8,12,0}) do local previous=r.body.direction; r.body.direction=dir; local rotated,rotation_error=lifecycle.rotate(r,previous); assert(rotated,type(rotation_error)=='table' and rotation_error.message or tostring(rotation_error)); assert(r.direction==dir and child==r.children.network and lifecycle.connector(r,'network','red'),kind..' direction '..dir..' body '..r.body.direction..' retained '..r.direction..' error '..tostring(r.physical_error)) end
    if kind=='computer' then runtime.save(r.id,source,0); r.state.keep='not copied'
    elseif kind=='kv' then kv.methods.set(nil,r,'red',game.tick,nop,'secret','not copied') end
    f()[kind]=r.id
  end
  group('every-family-cardinal-rotation-retains-exact-owned-port-roles')
  local m=registry.record(f().monitor); monitor.reconcile(game.tick,nop)
  local g=assert(monitor.resolve(m)); model.calls.write(g.model,nop,'private screen')
  model.scale(g.model,1,1,nop,2); model.calls.setPaletteColor(g.model,nop,1,0x123456)
  local mi=mine(m); local m2=replace(mi,m.position.x,m.position.y); mi.destroy(); f().monitor=m2.id
  monitor.reconcile(game.tick,nop); local fresh=assert(monitor.resolve(m2))
  assert(fresh.id~=g.id and fresh.model.scale==2 and fresh.model.cells[1][1]==32 and fresh.model.palette[1][1]==0x12/255)
  f().monitor_group=fresh.id; model.calls.write(fresh.model,nop,'COLD')
  group('monitor-mining-preserves-settings-not-obsolete-buffer-or-logical-identity')
  local db=registry.record(f().kv)
  kv.methods.expire(nil,db,'red',game.tick,nop,'secret',1000); f().deadline=db.database.entries.secret.deadline
  local intact=db.database; db.database={version=1,entries={lost={type='string',value='retained',bytes=8}},order={},bytes=0,fields=0,cursor=1}
  kv.initialize(db); assert(not db.body.minable and db.database.entries.lost.value=='retained')
  assert(not pcall(kv.methods.get,nil,db,'red',game.tick,nop,'lost'))
  kv.maintenance(game.tick,nop); assert(db.database.entries.lost.value=='retained')
  db.database=intact; kv.initialize(db)
  -- Source settings copy is deliberately not a state transfer or destructive reset.
  snapshots.apply_settings(restored,snapshots.settings(registry.record(f().computer)))
  assert(restored.state==before and restored.status=='stopped' and restored.saved_source==source)
  group('settings-copy-stops-old-run-preserves-destination-state-excludes-source-state')
  -- Real engine blueprint capture/build/revival. No player/GUI is fabricated.
  local inventory=game.create_inventory(1); inventory[1].set_stack{name='blueprint',count=1}
  local bp=inventory[1]; local surf=game.surfaces[1]
  local a=registry.record(f().computer); local l=registry.record(f().logic)
  assert(lifecycle.connector(a,'network','red').connect_to(lifecycle.connector(db,'network','red')))
  assert(lifecycle.connector(db,'network','red').connect_to(lifecycle.connector(l,'network','red')))
  local target=assert(surf.create_entity{name='constant-combinator',position={l.position.x+3,9},force='player'})
  assert(lifecycle.connector(l,'output','green').connect_to(target.get_wire_connector(defines.wire_connector_id.circuit_green,true)))
  local mapping=bp.create_blueprint{surface=surf,force='player',area={{2,8},{24,16}}}
  assert(blueprints.prepare(bp,mapping)); assert(bp.blueprint_description:find(blueprints.disclosure,1,true))
  local entities=bp.get_blueprint_entities(); local ports=0
  for _,e in ipairs(entities) do if e.name:match('^tc%-port%-') then ports=ports+1 end
    if e.tags and e.tags.tc_settings then assert(not e.tags.tc_settings.state and not e.tags.tc_settings.database) end
  end
  local expected_ports=0; for _,kind in ipairs(defs.order) do expected_ports=expected_ports+#defs.devices[kind].roles end
  assert(ports==expected_ports,'all owned blueprint roles must be represented: '..ports..' / '..expected_ports)
  f().blueprint_inventory=inventory
  group('native-blueprint-source-disclosure-no-state-kv-and-complete-role-wire-graph')
  -- Destruction and surface deletion never delete a replacement by location.
  local srf=game.create_surface('tc12-delete',{width=32,height=32}); local gone=build('computer',0,0,srf); local oldchild=gone.children.network
  local id=gone.id; lifecycle.on_surface_removed{surface_index=srf.index}; game.delete_surface(srf)
  assert(not registry.record(id) and not oldchild.valid)
  group('surface-delete-route-retires-exact-owned-objects-on-init-events-suppressed')
  f().start_tick=game.tick
  log('TC_CONTRACT_TOTAL '..f().groups)
end
local function cold_check()
  local x=f(); local r=registry.record(x.robot_id); local saved=x.snapshot; local root=registry.get()
  assert(r==x.alias and r.state==x.state_alias and r.active==x.active_alias)
  assert(r.saved_source==saved.saved_source and r.active.source==x.expected_active and r.state_bytes==65536 and r.body.unit_number==saved.unit)
  assert(root.ledger.tick==saved.tick and root.ledger.total==saved.total and root.scheduler.maintenance_spent==saved.maintenance)
  local db=registry.record(x.kv); assert(db.database==x.database_alias and db.database.entries.secret.deadline==x.deadline)
  local g=monitor.resolve(registry.record(x.monitor)); assert(g.id==x.monitor_group and g.model==x.monitor_alias and g.model.cells[1][1]==67)
  assert(root.player_drafts[1].documents[x.original_id].source=='unsaved recoverable draft')
end
function M.on_load() loaded=true; if f().phase=='frozen' then cold_check(); log('TC_COLD_ON_LOAD_UNCHANGED') end end
function M.on_configuration_changed()
  cold_check(); snapshots.initialize_existing(); kv.initialize_existing(); f().upgraded=true
  assert(registry.record(f().robot_id).state==f().state_alias)
  log('TC_CONFIGURATION_DATA_RETAINED')
end
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  if x.phase=='frozen' then
    if not loaded then return end
    cold_check(); loaded=false
    if x.upgraded then log('TC_UPGRADE_OK lifecycle-data-source-state-deadline-monitor-drafts')
    else log('TC_COLD_OK lifecycle-data-source-state-deadline-monitor-drafts') end
    x.phase='done'; return
  end
  loaded=false
  assert(event.tick<x.start_tick+1800,'compact lifecycle scenario deadline exceeded')
  if x.phase=='start' then
    -- Genuine on_tick clone events, all five families, including native area helper clones.
    x.clones={}
    for _,kind in ipairs(defs.order) do
      local r=registry.record(x[kind]); local b=assert(r.body.clone{position={r.body.position.x,32},surface=r.body.surface,force=r.body.force})
      local clone=assert(registry.by_entity(b),'real clone event must register every body family')
      assert(clone.id~=r.id and not clone.output_owner)
      if kind=='computer' then assert(clone.saved_source==source and clone.status=='stopped' and not clone.active and next(clone.state)==nil and next(clone.timers)==nil)
      elseif kind=='kv' then assert(next(clone.database.entries)==nil) end
      x.clones[#x.clones+1]=clone.id
    end
    local surf=game.surfaces[1]
    surf.clone_area{source_area={{2,8},{24,16}},destination_area={{2,48},{24,56}},clone_entities=true,clone_tiles=true,clone_decoratives=false,clear_destination_entities=false,expand_map=true}
    while registry.get().pending_clone_ports and #registry.get().pending_clone_ports>0 do blueprints.reconcile_clones(event.tick,nop) end
    local ports=surf.find_entities_filtered{area={{2,48},{24,56}},name={'tc-port-network','tc-port-input','tc-port-output','tc-port-targets'}}
    assert(#ports==8,'area clone left duplicate/orphan ports: '..#ports)
    for _,p in ipairs(ports) do assert(registry.by_entity(p),'area clone helper unowned') end
    log('TC_NATIVE_ALL_FAMILY_CLONES_OK area-helper-ownership')
    -- Blueprint ghosts are native; engine preserves endpoint wires through rotation.
    local bp=x.blueprint_inventory[1]
    local tiles={}; for y=16,48 do for xx=64,96 do tiles[#tiles+1]={name='landfill',position={xx,y}} end end
    game.surfaces[1].set_tiles(tiles)
    for _,entity in ipairs(game.surfaces[1].find_entities_filtered{area={{64,16},{96,48}},type={'tree','simple-entity'}}) do entity.destroy() end
    local ghosts=bp.build_blueprint{surface=game.surfaces[1],force='player',position={80,32},direction=defines.direction.east,raise_built=true,skip_fog_of_war=false,build_mode=defines.build_mode.forced}
    assert(#ghosts>0)

    x.revived={}
    for _,ghost in ipairs(ghosts) do
      if ghost.valid and defs.by_name[ghost.ghost_name] then
        local name=ghost.ghost_name; local _,b=ghost.revive{raise_revive=true}; assert(b,'native blueprint body revive refused '..name)
        local r=assert(registry.by_entity(b)); x.revived[r.kind]=r.id
        if r.kind=='computer' then assert(r.saved_source==source and r.status=='stopped' and next(r.state)==nil)
        elseif r.kind=='kv' then assert(next(r.database.entries)==nil) end
      elseif ghost.valid and not ghost.ghost_name:match('^tc%-port%-') then assert(select(2,ghost.revive{raise_revive=true})) end
    end
    local bc=registry.record(x.revived.computer); local bd=registry.record(x.revived.kv); local bl=registry.record(x.revived.logic)
    assert(bc and bd and bl)
    local red=lifecycle.connector(bc,'network','red')

    assert(red.connection_count==1 and lifecycle.connector(bd,'network','red').connection_count==2,'blueprint lost NETWORK wire roles')
    assert(lifecycle.connector(bl,'output','green').connection_count==1,'blueprint lost external OUTPUT wire')
    assert(lifecycle.connector(bl,'input','red').connection_count==0 and not bl.output_owner)
    log('TC_NATIVE_BLUEPRINT_ROTATED_REVIVAL_WIRES_OK')
    -- Native force/surface movement reconciles owned ports, retaining data but stopping authority.
    local moving=registry.record(x.restored); local srf=game.create_surface('tc12-move',{width=32,height=32})
    local crossbody=assert(moving.body.clone{position={0,0},surface=srf,force='player'})
    local cross=assert(registry.by_entity(crossbody)); assert(cross.saved_source==source and next(cross.state)==nil and cross.status=='stopped')
    local force=game.create_force('tc12-moved'); moving.body.force=force
    lifecycle.reconcile(event.tick,nop)
    assert(moving.body.surface==moving.children.network.surface and moving.children.network.force==force and moving.state_bytes==65536)
    assert(lifecycle.connector(moving,'network','red'))
    x.moving=moving.id; x.cross=cross.id; x.cross_surface=srf.index
    game.merge_forces(force,'player'); x.phase='force_wait'
  elseif x.phase=='force_wait' then
    lifecycle.reconcile(event.tick,nop)
    local moving=registry.record(x.moving)
    if moving.body.force.index~=game.forces.player.index then return end
    assert(moving.force_index==game.forces.player.index and moving.state_bytes==65536)
    local cross=registry.record(x.cross); x.cross_child=cross.children.network
    game.delete_surface(x.cross_surface); x.phase='surface_wait'
  elseif x.phase=='surface_wait' then
    if game.surfaces[x.cross_surface] then return end
    assert(not registry.record(x.cross) and not x.cross_child.valid)
    log('TC_NATIVE_FORCE_SURFACE_MERGE_OK')
    local writer=build('computer',40,0); local output=build('logic',44,0)
    assert(lifecycle.connector(writer,'network','red').connect_to(lifecycle.connector(output,'network','red')))
    lifecycle.sample_power(writer,event.tick,nop); lifecycle.sample_power(output,event.tick,nop)
    local program="return {api_version=1,handlers={start=function(e) local l=peripheral.find('logic_handler','red'); assert(l); l.setOutput({{signal={type='virtual',name='signal-A'},count=9}}) end}}"
    runtime.save(writer.id,program,0); assert(runtime.activate(writer.id,event.tick)); assert(scheduler.dispatch(writer,event.tick))
    assert(output.output_owner and output.output_owner.computer_id==writer.id,'native output writer missing')
    local child=writer.children.network; writer.active.compiler_version=99
    assert(writer.body.die()); assert(not registry.record(writer.id) and not child.valid and not output.output_owner and output.children.output.get_control_behavior().sections_count==0)
    log('TC_NATIVE_DESTRUCTION_OUTPUT_CLEANUP_OK malformed-source-independent')
    -- Maximum accepted source+state item, mined by an actual construction robot.
    local r=registry.record(x.computer)
    r.body.energy=defs.devices.computer.watts/30; lifecycle.sample_power(r,event.tick,nop)
    x.expected_active=source..string.rep(' ',limits.source_bytes-#source)
    runtime.save(r.id,x.expected_active,r.saved_revision); assert(runtime.activate(r.id,event.tick))
    assert(scheduler.dispatch(r,event.tick)); fixture_state(r)
    runtime.save(r.id,saved..string.rep(' ',limits.source_bytes-#saved),r.saved_revision)
    assert(#r.saved_source==limits.source_bytes)
    x.robot_id=r.id; x.original_id=x.original_id or next(registry.get().player_drafts[1].documents)
    local surf=r.body.surface
    x.roboport=assert(surf.create_entity{name='roboport',position={8,18},force='player'})
    x.roboport.energy=100000000; x.roboport.get_inventory(defines.inventory.roboport_robot).insert{name='construction-robot',count=1}
    x.chest=assert(surf.create_entity{name='storage-chest',position={13,18},force='player'})
    x.pole=assert(surf.create_entity{name='substation',position={8,23},force='player'})
    x.generator=assert(surf.create_entity{name='electric-energy-interface',position={12,23},force='player'})
    x.generator.power_production=100000000; x.generator.power_usage=0
    assert(r.body.order_deconstruction('player')); x.phase='mining'
  elseif x.phase=='mining' then
    if not x.robot_mined then return end
    local inventory=x.chest.get_inventory(defines.inventory.chest); local stack=inventory.find_item_stack('tc-computer')
    if not stack then return end
    assert(inventory.get_item_count('tc-computer')==1 and stack.tags.tc_computer.state.k1 and #stack.tags.tc_computer.saved_source==limits.source_bytes)
    local r=replace({[1]=stack},4,12)
    assert(r.state_bytes==65536 and r.status=='stopped' and r.active.source==x.expected_active and next(r.timers)==nil)
    x.robot_id=r.id; x.alias=r; x.state_alias=r.state; x.active_alias=r.active
    stack.clear(); x.generator.power_production=0
    for _,id in ipairs(registry.get().order) do local rec=registry.record(id); rec.body.power_usage=0 end
    x.database_alias=registry.record(x.kv).database
    local g=monitor.resolve(registry.record(x.monitor)); x.monitor_alias=g.model
    local root=registry.get(); root.scheduler.maintenance_spent=limits.maintenance_work_per_tick
    x.snapshot={saved_source=r.saved_source,unit=r.body.unit_number,tick=root.ledger.tick,total=root.ledger.total,maintenance=root.scheduler.maintenance_spent}
    x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  end
end
return M
