-- Physical ownership only. No guest objects, runtime functions or callbacks stored.
local defs=require('scripts.device-definitions')
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local wires=require('scripts.physical-wires')
local radar=require('scripts.radar')
local speaker=require('scripts.speaker')
local M={}
-- Material transport is family-specific; computers own data on their entity.
local item_adapters={}
local initialize_computer
function M.register_computer_initializer(fn)
  assert(not initialize_computer and type(fn)=='function'); initialize_computer=fn
end
local blueprint_adapter,undo_adapter
function M.register_undo_adapter(adapter)
  assert(not undo_adapter); undo_adapter=adapter
end
function M.register_blueprint_adapter(adapter)
  assert(not blueprint_adapter and type(adapter.after_build)=='function' and type(adapter.on_ghost)=='function')
  blueprint_adapter=adapter
end
function M.register_item_adapter(kind,adapter)
  assert((kind=='kv' or kind=='monitor') and not item_adapters[kind])
  assert(type(adapter.initialize)=='function' and type(adapter.snapshot)=='function'
    and type(adapter.restore)=='function' and type(adapter.tag)=='string')
  item_adapters[kind]=adapter
end
local function position(rec,index,direction)
  local x,y=defs.offset(rec.kind,index,direction)
  return {x=rec.body.position.x+x,y=rec.body.position.y+y}
end
local function protect(port)
  port.minable_flag=false; port.destructible=false; port.operable=false; port.rotatable=false
end
local function create_port(body,role,pos,direction,token)
  local port
  if token then
    for _,ghost in ipairs(body.surface.find_entities_filtered{area={{pos.x-0.25,pos.y-0.25},{pos.x+0.25,pos.y+0.25}},type='entity-ghost',force=body.force}) do
      local tag=ghost.tags and ghost.tags.tc_port
      if ghost.ghost_name==(body.type=='constant-combinator' and defs.pad_name(defs.by_name[body.name],role) or 'tc-port-'..role) and type(tag)=='table' and tag.version==1 and tag.token==token
        and tag.role==role and tag.body==body.name and ghost.position.x==pos.x and ghost.position.y==pos.y then
        -- create_entity at the same spot would delete this ghost and its wires.
        local _; _,port=ghost.revive{raise_revive=false}; if port then break end
      end
    end
  end
  port=port or body.surface.create_entity{name=(body.type=='constant-combinator' and defs.pad_name(defs.by_name[body.name],role) or 'tc-port-'..role),position=pos,direction=direction,
    force=body.force,quality=body.quality,create_build_effect_smoke=false}
  if not port then errors.raise('E_ENGINE','could not create owned '..role..' port') end
  local ok,e=pcall(function()
    protect(port)
    local behavior=port.get_or_create_control_behavior()
    -- Passive endpoints have no section at all and are disabled permanently.
    for i=behavior.sections_count,1,-1 do behavior.remove_section(i) end
    behavior.enabled=false
    assert(port.get_wire_connector(defines.wire_connector_id.circuit_red,true),'red endpoint missing')
    assert(port.get_wire_connector(defines.wire_connector_id.circuit_green,true),'green endpoint missing')
  end)
  if not ok then port.destroy(); error(e,0) end
  return port
end
function M.endpoint(rec,role)
  if (rec.native_carrier=='radar' or rec.native_carrier=='speaker') and role=='network' then return rec.body end
  if rec.layout_version==2 and role=='network' then return rec.body end
  return rec.children[role]
end
function M.power_entity(rec)
  if rec.layout_version==2 then return rec.children.power end
  return rec.body
end
function M.has_power(rec)
  if not rec or not rec.body or not rec.body.valid then return false end
  if rec.native_carrier=='radar' then return radar.available(rec) end
  if rec.native_carrier=='speaker' then return speaker.available(rec) end
  local p=M.power_entity(rec)
  if not p or not p.valid or p.force.index~=rec.force_index or p.surface.index~=rec.surface_index then return false end
  local at=rec.body.position; local power_at=p==rec.body and at or p.position
  return power_at.x==at.x and power_at.y==at.y
    and registry.by_entity(p)==rec and p.energy>=defs.devices[rec.kind].watts/60
end
function M.normalize_power(rec)
  if rec.native_carrier then return end
  local watts=defs.devices[rec.kind].watts; local p=M.power_entity(rec)
  p.power_usage=watts/60; p.power_production=0; p.electric_buffer_size=watts/30
end
local function passive(body)
  body.operable=defs.by_name[body.name]~='computer'
  local cb=body.get_or_create_control_behavior(); cb.enabled=false
  for i=cb.sections_count,1,-1 do cb.remove_section(i) end
  for _,color in ipairs({'red','green'}) do
    assert(body.get_wire_connector(defines.wire_connector_id['circuit_'..color],true),'shell connector missing')
  end
end
function M.reset_network(rec)
  if rec.layout_version==2 and rec.body.valid then passive(rec.body) end
end
local function create_power(body,kind)
  local p=body.surface.create_entity{name=defs.devices[kind].power_name,position=body.position,
    direction=body.direction,force=body.force,quality=body.quality,create_build_effect_smoke=false}
  if not p then errors.raise('E_ENGINE','could not create private power carrier') end
  protect(p); return p
end
function M.clear_output(rec)
  local port=rec.children.output
  if port and port.valid then
    local cb=port.get_or_create_control_behavior()
    cb.enabled=false
    for i=cb.sections_count,1,-1 do cb.remove_section(i) end
  end
  rec.output_bank=nil; rec.output_owner=nil
end
-- Downstream logic owns generation-specific writer cleanup. Physical outages of
-- the peripheral itself always clear its bank; never clear unrelated devices here.
function M.sample_power(rec,tick,spend)
  if rec.native_carrier=='speaker' then spend(4); rec.powered=speaker.available(rec); rec.power_checked_tick=tick; return end
  if rec.native_carrier=='radar' then spend(4); rec.powered=radar.available(rec); rec.power_checked_tick=tick; return end
  local def=defs.devices[rec.kind]
  local powered=M.has_power(rec)
  if powered then
    for _,role in ipairs(def.roles) do
      -- The red proof checks the complete endpoint ownership/geometry. Nothing
      -- can move it before the adjacent native green-connector existence read.
      if not M.connector(rec,role,'red') or not M.endpoint(rec,role).get_wire_connector(defines.wire_connector_id.circuit_green,false) then powered=false end
    end
  end
  if rec.kind=='computer' then runtime.set_power(rec.id,powered,tick,spend)
  elseif rec.powered~=powered then
    spend(4)
    if not powered then M.clear_output(rec) end
    rec.powered=powered; rec.power_revision=(rec.power_revision or 0)+1
    if rec.kind=='monitor' then rec.monitor_art_dirty=true; registry.monitor_changed(rec,false) end
  end
  rec.power_checked_tick=tick
end
function M.build(body,token)
  if speaker.supports(body) then return speaker.build(body) end
  if radar.supports(body) then return radar.build(body) end
  if not body or not body.valid or not defs.by_name[body.name] then return nil end
  local existing=registry.by_entity(body)
  if existing then return existing end -- duplicate raised build is idempotent
  local kind=defs.by_name[body.name]
  if kind=='monitor' then
    local n=0; for _,rec in pairs(registry.get().devices) do if rec.kind=='monitor' then n=n+1 end end
    if n>=256 then return nil,errors.new('E_CAPACITY','monitor tile capacity reached') end
  end
  if not defs.cardinal(body.direction) then return nil,errors.new('E_ARGUMENT','cardinal device direction required') end
  local staged={}; local rec
  local ok,e=pcall(function()
    -- Allocate every physical part before publishing the new registry identity.
    for index,role in ipairs(defs.devices[kind].roles) do
      if body.type~='constant-combinator' or role~='network' then
        local x,y=defs.offset(kind,index,body.direction)
        local port=create_port(body,role,{x=body.position.x+x,y=body.position.y+y},body.direction,token)
        staged[#staged+1]={role=role,entity=port}
      end
    end
    if body.type=='constant-combinator' then
      passive(body); staged[#staged+1]={role='power',entity=create_power(body,kind)}
    end
    rec=registry.register(kind,body)
    for _,child in ipairs(staged) do registry.bind_child(rec.id,child.role,child.entity) end
    rec.physical_version=1; rec.layout_version=body.type=='constant-combinator' and 2 or nil; rec.direction=body.direction
    rec.position={x=body.position.x,y=body.position.y}
    rec.powered=M.has_power(rec)
    rec.power_checked_tick=game.tick
    M.normalize_power(rec)
    if kind=='computer' and initialize_computer then initialize_computer(rec)
    elseif item_adapters[kind] then item_adapters[kind].initialize(rec)
    elseif kind=='computer' or kind=='kv' then
      body.minable_flag=false; rec.mining_guard='awaiting-data-bearing-snapshots'
    end
  end)
  if ok then return rec end
  if rec and not registry.remove(rec.id,'placement_rollback') then
    rec.physical_error='placement cleanup failed; retained for recovery'
    -- Bind any unbound staged parts so none can become an untracked orphan.
    for _,child in ipairs(staged) do
      if not rec.children[child.role] then registry.bind_child(rec.id,child.role,child.entity) end
    end
    return nil,errors.new('E_ENGINE',rec.physical_error),true
  end
  for _,child in ipairs(staged) do if child.entity.valid then child.entity.destroy() end end
  return nil,type(e)=='table' and e or errors.new('E_ENGINE',tostring(e):sub(1,256))
end
function M.remove(id,reason,destroy_body)
  local rec=registry.record(id)
  if not rec or not rec.physical_version then return false end
  if not registry.remove(id,reason) then return false end
  -- Exact retained objects only; never find/destroy by position or unit number.
  for _,port in pairs(rec.children) do if port.valid then port.destroy() end end
  if destroy_body and rec.body.valid then rec.body.destroy() end
  return true
end
function M.connector(rec,role,color)
  if type(rec)=='string' then rec=registry.record(rec) end
  if not rec or rec.physical_version~=1 or rec.physical_error or not rec.body.valid then return nil end
  if rec.native_carrier=='radar' then
    if color~='red' and color~='green' then errors.raise('E_ARGUMENT','red or green connector required') end
    return radar.connector(rec,role,color)
  end
  if rec.native_carrier=='speaker' then
    if color~='red' and color~='green' then errors.raise('E_ARGUMENT','red or green connector required') end
    return speaker.connector(rec,role,color)
  end
  local body=rec.body; local direction=body.direction; local at=body.position
  if direction~=rec.direction or at.x~=rec.position.x or at.y~=rec.position.y then return nil end
  if color~='red' and color~='green' then errors.raise('E_ARGUMENT','red or green connector required') end
  local port=M.endpoint(rec,role)
  if not port or not port.valid then return nil end
  local index
  for i,r in ipairs(defs.devices[rec.kind].roles) do if r==role then index=i; break end end
  if not index then return nil end
  local expected=rec.position
  if rec.layout_version~=2 or role~='network' then
    local x,y=defs.offset(rec.kind,index,rec.direction); expected={x=at.x+x,y=at.y+y}
  end
  local port_at=port==body and at or port.position
  if port_at.x~=expected.x or port_at.y~=expected.y or (port==body and direction or port.direction)~=rec.direction then return nil end
  local owner,bound_role=registry.by_entity(port)
  local expected_role=rec.layout_version==2 and role=='network' and 'body' or role
  if owner~=rec or bound_role~=expected_role or body.force.index~=rec.force_index
    or body.surface.index~=rec.surface_index then return nil end
  if port~=body and (port.force.index~=rec.force_index or port.surface.index~=rec.surface_index) then return nil end
  return port.get_wire_connector(defines.wire_connector_id['circuit_'..color],false)
end
function M.rotate(rec,previous_direction)
  if rec and rec.native_carrier then return true end
  if not rec or rec.physical_version~=1 or not rec.body.valid then return false end
  local direction=rec.body.direction
  if not defs.cardinal(direction) then rec.body.direction=previous_direction; return false end
  local moved={}
  local ok,e=pcall(function()
    for index,role in ipairs(defs.devices[rec.kind].roles) do
      if rec.layout_version~=2 or role~='network' then
        local port=assert(rec.children[role]); assert(port.valid,'owned port missing')
        moved[#moved+1]={entity=port,position=port.position,direction=port.direction}
        assert(port.teleport(position(rec,index,direction),nil,false,false),'owned port teleport refused')
        port.direction=direction
      end
    end
    if rec.layout_version==2 then
      local p=assert(rec.children.power); assert(p.valid,'power carrier missing')
      moved[#moved+1]={entity=p,position=p.position,direction=p.direction}
      assert(p.teleport(rec.body.position,nil,false,false),'power teleport refused'); p.direction=direction
    end
  end)
  if not ok then
    rec.body.direction=previous_direction
    local restored=true
    for _,old in ipairs(moved) do
      if not old.entity.valid or not old.entity.teleport(old.position,nil,false,false) then restored=false
      else old.entity.direction=old.direction end
    end
    if not restored then
      rec.physical_error='rotation restoration failed; device retained inertly'
      registry.cleanup(rec,rec.run_id,'physical_failure'); rec.powered=false
      if rec.kind=='computer' then runtime.stop(rec.id) end
    end
    return false,e
  end
  rec.direction=direction; rec.position={x=rec.body.position.x,y=rec.body.position.y}
  if rec.kind=='monitor' then rec.monitor_art_dirty=true; registry.monitor_changed(rec,true) end
  return true
end
local function refund(event,body)
  local player=event.player_index and game.get_player(event.player_index)
  local inventory=event.robot and event.robot.valid and event.robot.get_inventory(defines.inventory.robot_cargo)
  local function give(stack)
    if not stack.valid_for_read or stack.name~=defs.devices[defs.by_name[body.name]].name then return false end
    -- A robot stack may contain more than the one item used for this placement.
    -- Clone exactly one, preserving tags/quality/labels without changing its cargo.
    local copy=game.create_inventory(1)
    copy[1].set_stack(stack); copy[1].count=1
    local inserted=player and player.insert(copy[1]) or inventory and inventory.insert(copy[1]) or 0
    if inserted==0 then
      body.surface.spill_item_stack{position=body.position,stack=copy[1],enable_looted=true,force=body.force}
    end
    copy.destroy()
    return true
  end
  if event.consumed_items then
    for i=1,#event.consumed_items do if give(event.consumed_items[i]) then return end end
  elseif event.stack then give(event.stack) end
end
local function consumed(event,body)
  if event.consumed_items then
    for i=1,#event.consumed_items do
      local stack=event.consumed_items[i]
      if stack.valid_for_read and stack.name==defs.devices[defs.by_name[body.name]].name then return stack end
    end
  elseif event.stack and event.stack.valid_for_read and event.stack.name==defs.devices[defs.by_name[body.name]].name then return event.stack end
end
-- A legacy body remains authoritative until every replacement and native wire
-- has been staged successfully. Never call runtime activation or snapshot import.
function M.upgrade(rec)
  if rec.native_carrier then return true end
  if rec.layout_version==2 then return true end
  local old=rec.body; local children=rec.children; local staged={}; local body
  local ok,e=pcall(function()
    assert(rec.physical_version==1 and not rec.physical_error and old.valid,'legacy physical record unavailable')
    assert(old.name==defs.devices[rec.kind].name and defs.cardinal(old.direction),'unsupported legacy body')
    assert(old.direction==rec.direction and old.position.x==rec.position.x and old.position.y==rec.position.y,'legacy body moved')
    local snapshots={}
    for _,role in ipairs(defs.devices[rec.kind].roles) do
      assert(M.connector(rec,role,'red') and M.connector(rec,role,'green'),'legacy role unavailable')
      snapshots[role]=wires.snapshot(children[role])
    end
    body=assert(old.surface.create_entity{name=defs.devices[rec.kind].entity_name,position=old.position,
      direction=old.direction,force=old.force,quality=old.quality,create_build_effect_smoke=false},'shell allocation refused')
    staged[#staged+1]=body; passive(body)
    assert(body.position.x==old.position.x and body.position.y==old.position.y,'shell placement moved')
    body.health=old.health; body.minable_flag=old.minable_flag; body.destructible=old.destructible; body.rotatable=old.rotatable
    local parts={power=create_power(body,rec.kind)}; staged[#staged+1]=parts.power
    parts.power.energy=old.energy
    local watts=defs.devices[rec.kind].watts
    parts.power.power_usage=watts/60; parts.power.power_production=0; parts.power.electric_buffer_size=watts/30
    local remap={}
    for i,role in ipairs(defs.devices[rec.kind].roles) do
      local endpoint=body
      if role~='network' then
        endpoint=create_port(body,role,position(rec,i,rec.direction),rec.direction)
        parts[role]=endpoint; staged[#staged+1]=endpoint
        if role=='output' then
          local from=children[role].get_or_create_control_behavior()
          local to=endpoint.get_or_create_control_behavior()
          assert(from.sections_count<=limits.network_edges,'legacy output section capacity exceeded')
          for section_index=1,from.sections_count do
            local section=from.get_section(section_index)
            assert(section.filters_count<=limits.network_edges,'legacy output filter capacity exceeded')
            local copy=assert(to.add_section(),'output section allocation refused')
            copy.filters=section.filters; copy.multiplier=section.multiplier; copy.active=section.active
          end
          to.enabled=from.enabled
        end
      end
      remap[children[role].unit_number]=endpoint
    end
    for _,role in ipairs(defs.devices[rec.kind].roles) do
      wires.apply(snapshots[role],role=='network' and body or parts[role],remap)
    end
    if old.to_be_deconstructed(old.force) then assert(body.order_deconstruction(old.force),'deconstruction handoff refused') end
    -- Atomic logical publication after all fallible physical preparation.
    registry.replace_physical(rec,body,parts)
  end)
  if not ok then
    for i=#staged,1,-1 do if staged[i].valid then staged[i].destroy() end end
    rec.migration_error=errors.new('E_ENGINE','physical conversion refused; legacy data/wires retained: '..tostring(e):sub(1,180))
    return false,rec.migration_error
  end
  rec.migration_error=nil
  if rec.status_art and rec.status_art.object.valid then rec.status_art.object.destroy() end
  rec.status_art=nil
  local monitors=registry.get().monitors
  if monitors and monitors.version==1 then
    for _,g in pairs(monitors.groups) do if g.anchor==rec.id then g.body=body end end
  end
  -- Sessions bind the previous exact unit and now fail closed; drafts survive.
  for _,p in pairs(registry.get().player_drafts) do
    if p.session and p.session.id==rec.id then p.session=nil end
  end
  for _,child in pairs(children) do if child.valid then child.destroy() end end
  old.destroy()
  return true
end
function M.upgrade_existing()
  local root=registry.get(); if not registry.supported(root) then return end
  root.monitor_topology_dirty=true
  for _,id in ipairs(root.order) do
    local rec=registry.record(id)
    if rec and not rec.native_carrier and rec.physical_version==1 and rec.layout_version~=2 then
      local ok,e=M.upgrade(rec)
      if not ok then log('TC physical upgrade '..rec.id..': '..e.message) end
    end
    if rec and rec.layout_version==2 and rec.body.valid then M.reset_network(rec) end
  end
end
function M.on_built(event)
  local body=event.entity
  -- Native bodies acquire identities only from a computer-rooted physical proof.
  if speaker.supports(body) or radar.supports(body) then return end
  if undo_adapter then undo_adapter.on_ghost(event) end
  if blueprint_adapter and blueprint_adapter.on_ghost(event) then return end
  if not body or not body.valid or not defs.by_name[body.name] then return end
  if registry.by_entity(body) then return end -- duplicate build must not replay item data
  local token=event.tags and event.tags.tc_body_token
  if type(token)~='string' or #token>128 then token=nil end
  local prepared,undo_payload=true,nil
  if undo_adapter and defs.by_name[body.name]=='computer' then prepared,undo_payload=pcall(undo_adapter.prepare,event) end
  local rec,e,retained
  if prepared then rec,e,retained=M.build(body,token) else e=undo_payload; undo_payload=nil end
  if rec and undo_payload then
    local ok,err=pcall(undo_adapter.apply,rec,undo_payload)
    if not ok then e=err; retained=not M.remove(rec.id,'undo_restore_refused',false); rec=nil end
  end
  local material_restored=undo_payload~=nil
  if rec and item_adapters[rec.kind] then
    local adapter=item_adapters[rec.kind]; local stack=consumed(event,body)
    -- Only a material item carries data. Blueprint/ghost/script tags must not
    -- duplicate a database, and cloning calls build() without a consumed item.
    local tags=stack and stack.tags
    if tags and tags[adapter.tag]~=nil then
      local ok,err=pcall(adapter.restore,rec,tags[adapter.tag])
      material_restored=ok
      if not ok then
        e=type(err)=='table' and err or errors.new('E_ENGINE','item restore failed')
        retained=not M.remove(rec.id,'item_restore_refused',false); rec=nil
      end
    end
  end
  if rec and blueprint_adapter then
    local ok,err=pcall(blueprint_adapter.after_build,rec,event,material_restored)
    if not ok then
      rec.physical_error='blueprint settings refused; source/item data retained'
      if rec.kind=='computer' then runtime.retire(rec,'faulted','invalid_blueprint') end
      rec.powered=false; e=err
    end
  end
  if rec and rec.layout_version~=2 then M.upgrade(rec) end
  if not rec then
    if not retained then
      local recovery=undo_adapter and undo_adapter.recovery(event,body)
      if recovery~=false then refund(event,body); body.destroy() end
    elseif undo_payload then body.minable_flag=false end
    log('TC placement refused: '..(e and e.message or 'unknown failure'))
    local player=event.player_index and game.get_player(event.player_index)
    if player then player.print('Placement refused: '..(e and e.message or 'unknown failure')) end
  end
end
function M.on_removed(event)
  if undo_adapter then undo_adapter.on_removed(event) end
  local rec,role=registry.by_entity(event.entity)
  if rec and rec.physical_version and role=='body' then
    if undo_adapter then undo_adapter.capture(rec,event) end
    local adapter=item_adapters[rec.kind]
    if event.buffer and adapter then
      -- The engine still owns the body and its temporary mining buffer here.
      -- Serialize before unregistering its exact identity/ports. No guest code.
      local snapshot=adapter.snapshot(rec,event.tick or game.tick)
      local target
      for i=1,#event.buffer do
        local stack=event.buffer[i]
        if stack.valid_for_read and stack.name==defs.devices[rec.kind].name then target=stack; break end
      end
      assert(target,'data-bearing mining result missing; database retained')
      local tags=target.tags or {}; tags[adapter.tag]=snapshot; target.tags=tags
    end
    M.remove(rec.id,'entity_removed',false)
  end
end
function M.on_cloned(event)
  local body=event.destination
  if not body or not body.valid then return end
  if speaker.supports(body) or radar.supports(body) then return end
  if defs.by_name[body.name] then
    local source,role=registry.by_entity(event.source)
    local rec=M.build(body)
    if rec and source and role=='body' and blueprint_adapter then blueprint_adapter.clone(rec,source) end
  elseif defs.power_kind(body.name) then
    if not registry.by_entity(body) then body.destroy() end
  elseif defs.port_role(body.name) and blueprint_adapter then
    blueprint_adapter.clone_port(event)
  end
end
function M.on_surface_removed(event)
  local root=registry.get(); if not registry.supported(root) then return end
  local ids={}; for _,id in ipairs(root.order) do ids[#ids+1]=id end
  for id,rec in pairs(root.devices) do if rec.kind=='radar' then ids[#ids+1]=id end end
  table.sort(ids)
  for _,id in ipairs(ids) do local rec=registry.record(id)
    if rec and rec.surface_index==event.surface_index then M.remove(id,'surface_deleted',false) end
  end
end
function M.on_forces_merging(event)
  local root=registry.get(); if not registry.supported(root) then return end
  for _,id in ipairs(root.order) do local rec=registry.record(id)
    if rec and (rec.force_index==event.source.index or rec.force_index==event.destination.index) then
      if rec.kind=='computer' then runtime.retire(rec,'stopped','force_merge') else registry.cleanup(rec,rec.run_id,'force_merge'); M.clear_output(rec) end
    end
  end
  for _,rec in pairs(root.devices) do
    if rec.kind=='radar' and (rec.force_index==event.source.index or rec.force_index==event.destination.index) then
      registry.cleanup(rec,rec.run_id,'force_merge'); M.clear_output(rec)
    end
  end
end
function M.on_object_destroyed(event)
  local root=registry.get(); if not registry.supported(root) then return end
  local id=root.radar_destructions[event.registration_number]
  local rec=id and registry.record(id)
  if rec and rec.kind=='radar' and rec.destruction_registration==event.registration_number and not rec.body.valid then
    M.remove(id,'native_body_lost',false)
  end
end
function M.on_rotated(event)
  local rec,role=registry.by_entity(event.entity)
  if rec and role=='body' then M.rotate(rec,event.previous_direction) end
end
function M.unlocks()
  for _,force in pairs(game.forces) do
    local advanced=force.technologies['tc-interplanetary-radar']
    if advanced and advanced.researched and force.recipes['tc-interplanetary-radar'] then force.recipes['tc-interplanetary-radar'].enabled=true end
    for _,kind in ipairs(defs.order) do
      local def=defs.devices[kind]; local technology=force.technologies[def.technology]
      if technology and technology.researched then force.recipes[def.name].enabled=true end
    end
  end
end
function M.reconcile(tick,spend)
  local root=registry.get(); local n=#root.order
  if n==0 then return end
  local cursor=math.min(root.scheduler.physical_cursor or 1,n)
  -- One bounded fair pass; individual transitions reserve before mutation.
  for _=1,n do
    local id=root.order[cursor]; local rec=registry.record(id)
    local removed=false
    local ok=scheduler.try_maintenance(function()
      spend(16)
      if rec and rec.kind=='logic' then rec.logic_sample=nil; rec.output_bank=nil end
      if rec and rec.native_carrier=='speaker' then
        removed=speaker.reconcile(rec,spend)
      elseif rec and rec.kind=='monitor' and rec.layout_version==2 and not rec.monitor_repair then
        if rec.monitor_available and not rec.powered then
          spend(4); rec.powered=true; rec.power_revision=(rec.power_revision or 0)+1
          rec.monitor_art_dirty=true; registry.monitor_changed(rec,false)
        end
        rec.power_checked_tick=tick
      elseif rec and rec.physical_version==1 then
        if not rec.body.valid then
          spend(limits.registry_entries*6)
          removed=M.remove(id,'body_lost',false)
        elseif not rec.physical_error then
          if rec.body.force.index~=rec.force_index or rec.body.surface.index~=rec.surface_index then
            spend(16)
            if not registry.cleanup(rec,rec.run_id,'authority_changed') then
              rec.physical_error='authority cleanup failed'; rec.powered=false; return
            end
            rec.force_index=rec.body.force.index; rec.surface_index=rec.body.surface.index
            if rec.kind=='computer' then runtime.retire(rec,'stopped','authority_changed') end
            for _,port in pairs(rec.children) do if port.valid then port.force=rec.body.force end end
            M.rotate(rec,rec.direction)
          end
          for _,role in ipairs(defs.devices[rec.kind].roles) do
            local port=M.endpoint(rec,role)
            if not port or not port.valid then
              rec.physical_error='owned port missing; device retained for recovery'
              registry.cleanup(rec,rec.run_id,'physical_failure'); rec.powered=false
              if rec.kind=='computer' then runtime.stop(id) end
              return
            end
          end
          local at=rec.body.position
          if rec.body.direction~=rec.direction or at.x~=rec.position.x or at.y~=rec.position.y then
            M.rotate(rec,rec.direction)
          end
          if not rec.physical_error then M.sample_power(rec,tick,spend) end
          if rec.kind=='monitor' then rec.monitor_repair=nil; registry.monitor_changed(rec,true) end
        end
      end
    end)
    if not ok then root.scheduler.physical_cursor=cursor; return end
    local size=#root.order
    if size==0 then root.scheduler.physical_cursor=1; return end
    if not removed then cursor=cursor%size+1 elseif cursor>size then cursor=1 end
    root.scheduler.physical_cursor=cursor
  end
end
-- Change detection only: later calls and publication still prove live authority.
function M.observe_monitor(rec,tick)
  local body=rec.body; local available=body and body.valid and not rec.physical_error
  local repair=not body or not body.valid
  if available then
    local at=body.position; local direction=body.direction
    repair=direction~=rec.direction or at.x~=rec.position.x or at.y~=rec.position.y
      or body.force.index~=rec.force_index or body.surface.index~=rec.surface_index
    local owner,role=registry.by_entity(body)
    local power=rec.children.power
    available=not repair and owner==rec and role=='body' and power and power.valid
    if available then
      local pos=power.position; local power_owner,power_role=registry.by_entity(power)
      available=power_owner==rec and power_role=='power'
        and power.force.index==rec.force_index and power.surface.index==rec.surface_index
        and pos.x==at.x and pos.y==at.y and power.energy>=defs.devices.monitor.watts/60
        and body.get_wire_connector(defines.wire_connector_id.circuit_red,false)~=nil
        and body.get_wire_connector(defines.wire_connector_id.circuit_green,false)~=nil
    end
  end
  available=not not available
  if repair and not rec.monitor_repair then
    rec.monitor_repair=true; registry.monitor_changed(rec,true)
  end
  if rec.monitor_available~=available then
    rec.monitor_available=available; rec.monitor_art_dirty=true; registry.monitor_changed(rec,false)
  end
  if not available and rec.powered then
    M.clear_output(rec); rec.powered=false; rec.power_revision=(rec.power_revision or 0)+1
    rec.monitor_art_dirty=true; registry.monitor_changed(rec,false)
  end
  if available==rec.powered then rec.power_checked_tick=tick end
end
function M.power_losses(tick,spend)
  local root=registry.get()
  -- Pay the whole critical walk before restoration notifications or ordinary
  -- lifecycle work can defer. A stale positive observation must never leave
  -- callbacks/services/output live during a real outage.
  spend(#root.order*16)
  for _,id in ipairs(root.order) do
    local rec=registry.record(id)
    if rec and rec.native_carrier=='speaker' then
      rec.powered=speaker.available(rec); rec.power_checked_tick=tick
    elseif rec and rec.kind=='monitor' and rec.layout_version==2 then
      M.observe_monitor(rec,tick)
    elseif rec and rec.physical_version==1 then
      local available=rec.body.valid and not rec.physical_error
      if available then
        for _,role in ipairs(defs.devices[rec.kind].roles) do
          -- This proof includes live body/port validity, force, surface,
          -- position, direction and registry ownership; do not repeat it.
          if not M.connector(rec,role,'red') then available=false end
        end
        if available then available=M.has_power(rec) end
      end
      if not available and rec.powered then
        if rec.kind=='computer' then runtime.set_power(id,false,tick,spend)
        else M.clear_output(rec); rec.powered=false; rec.power_revision=(rec.power_revision or 0)+1 end
      end
      if available==rec.powered then rec.power_checked_tick=tick end
    end
  end
end
scheduler.register_phase('lifecycle','00-physical-power-loss',M.power_losses)
scheduler.register_phase('lifecycle','physical-devices',M.reconcile)
return M
