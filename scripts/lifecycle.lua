-- Physical ownership only. No guest objects, runtime functions or callbacks stored.
local defs=require('scripts.device-definitions')
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local M={}
local function position(rec,index,direction)
  local x,y=defs.offset(rec.kind,index,direction)
  return {x=rec.body.position.x+x,y=rec.body.position.y+y}
end
local function protect(port)
  port.minable=false; port.destructible=false; port.operable=false; port.rotatable=false
end
local function create_port(body,role,pos,direction)
  local port=body.surface.create_entity{name='tc-port-'..role,position=pos,direction=direction,
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
  local def=defs.devices[rec.kind]
  local powered=rec.body.energy>=def.watts/60
  if powered then
    for _,role in ipairs(def.roles) do
      if not M.connector(rec,role,'red') or not M.connector(rec,role,'green') then powered=false end
    end
  end
  if rec.kind=='computer' then runtime.set_power(rec.id,powered,tick,spend)
  elseif rec.powered~=powered then
    spend(4)
    if not powered then M.clear_output(rec) end
    rec.powered=powered; rec.power_revision=(rec.power_revision or 0)+1
  end
  rec.power_checked_tick=tick
end
function M.build(body)
  if not body or not body.valid or not defs.by_name[body.name] then return nil end
  local existing=registry.by_entity(body)
  if existing then return existing end -- duplicate raised build is idempotent
  local kind=defs.by_name[body.name]
  if not defs.cardinal(body.direction) then return nil,errors.new('E_ARGUMENT','cardinal device direction required') end
  local staged={}; local rec
  local ok,e=pcall(function()
    -- Allocate every physical part before publishing the new registry identity.
    for index,role in ipairs(defs.devices[kind].roles) do
      local x,y=defs.offset(kind,index,body.direction)
      local port=create_port(body,role,{x=body.position.x+x,y=body.position.y+y},body.direction)
      staged[#staged+1]={role=role,entity=port}
    end
    rec=registry.register(kind,body)
    for _,child in ipairs(staged) do registry.bind_child(rec.id,child.role,child.entity) end
    rec.physical_version=1; rec.direction=body.direction
    rec.position={x=body.position.x,y=body.position.y}
    rec.powered=body.energy>=defs.devices[kind].watts/60
    rec.power_checked_tick=game.tick
    -- The later data-bearing lifecycle milestone owns mined snapshots. Until
    -- then, do not expose a mining path which could discard committed source,
    -- application state or future KV data. Destruction remains explicit loss.
    if kind=='computer' or kind=='kv' then
      body.minable=false; rec.mining_guard='awaiting-data-bearing-snapshots'
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
  if rec.body.direction~=rec.direction or rec.body.position.x~=rec.position.x or rec.body.position.y~=rec.position.y then return nil end
  if color~='red' and color~='green' then errors.raise('E_ARGUMENT','red or green connector required') end
  local port=rec.children[role]
  if not port or not port.valid then return nil end
  local index
  for i,r in ipairs(defs.devices[rec.kind].roles) do if r==role then index=i; break end end
  if not index then return nil end
  local expected=position(rec,index,rec.direction)
  if port.position.x~=expected.x or port.position.y~=expected.y or port.direction~=rec.direction then return nil end
  local owner,bound_role=registry.by_entity(port)
  if owner~=rec or bound_role~=role or rec.body.force.index~=rec.force_index
    or rec.body.surface.index~=rec.surface_index or port.force.index~=rec.force_index
    or port.surface.index~=rec.surface_index then return nil end
  return port.get_wire_connector(defines.wire_connector_id['circuit_'..color],false)
end
function M.rotate(rec,previous_direction)
  if not rec or rec.physical_version~=1 or not rec.body.valid then return false end
  local direction=rec.body.direction
  if not defs.cardinal(direction) then rec.body.direction=previous_direction; return false end
  local moved={}
  local ok,e=pcall(function()
    for index,role in ipairs(defs.devices[rec.kind].roles) do
      local port=assert(rec.children[role]); assert(port.valid,'owned port missing')
      moved[#moved+1]={entity=port,position=port.position,direction=port.direction}
      assert(port.teleport(position(rec,index,direction),nil,false,false),'owned port teleport refused')
      port.direction=direction
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
  return true
end
local function refund(event,body)
  local player=event.player_index and game.get_player(event.player_index)
  local inventory=event.robot and event.robot.valid and event.robot.get_inventory(defines.inventory.robot_cargo)
  local function give(stack)
    if not stack.valid_for_read or stack.name~=body.name then return false end
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
function M.on_built(event)
  local body=event.entity
  if not body or not body.valid or not defs.by_name[body.name] then return end
  local rec,e,retained=M.build(body)
  if not rec then
    if not retained then refund(event,body); body.destroy() end
    log('TC placement refused: '..(e and e.message or 'unknown failure'))
  end
end
function M.on_removed(event)
  local rec,role=registry.by_entity(event.entity)
  if rec and rec.physical_version and role=='body' then M.remove(rec.id,'entity_removed',false) end
end
function M.on_rotated(event)
  local rec,role=registry.by_entity(event.entity)
  if rec and role=='body' then M.rotate(rec,event.previous_direction) end
end
function M.unlocks()
  for _,force in pairs(game.forces) do
    local technology=force.technologies['tc-circuit-computers']
    if technology and technology.researched then
      for _,kind in ipairs(defs.order) do force.recipes[defs.devices[kind].name].enabled=true end
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
      if rec and rec.physical_version==1 then
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
            for _,port in pairs(rec.children) do if port.valid then port.force=rec.body.force end end
          end
          for _,role in ipairs(defs.devices[rec.kind].roles) do
            local port=rec.children[role]
            if not port or not port.valid then
              rec.physical_error='owned port missing; device retained for recovery'
              registry.cleanup(rec,rec.run_id,'physical_failure'); rec.powered=false
              if rec.kind=='computer' then runtime.stop(id) end
              return
            end
          end
          if rec.body.direction~=rec.direction or rec.body.position.x~=rec.position.x or rec.body.position.y~=rec.position.y then
            M.rotate(rec,rec.direction)
          end
          if not rec.physical_error then M.sample_power(rec,tick,spend) end
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
function M.power_losses(tick,spend)
  local root=registry.get()
  -- Pay the whole critical walk before restoration notifications or ordinary
  -- lifecycle work can defer. A stale positive observation must never leave
  -- callbacks/services/output live during a real outage.
  spend(limits.registry_entries*16)
  for _,id in ipairs(root.order) do
    local rec=registry.record(id)
    if rec and rec.physical_version==1 then
      local available=rec.body.valid and not rec.physical_error
      if available then
        available=rec.body.force.index==rec.force_index and rec.body.surface.index==rec.surface_index
        for _,role in ipairs(defs.devices[rec.kind].roles) do
          local port=rec.children[role]
          if not port or not port.valid or port.force.index~=rec.force_index or port.surface.index~=rec.surface_index
            or not M.connector(rec,role,'red') then available=false end
        end
        if available then available=rec.body.energy>=defs.devices[rec.kind].watts/60 end
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
