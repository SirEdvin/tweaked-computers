-- Blueprint source/settings plus native ghost wire graphs. Helpers are never items.
local defs=require('scripts.device-definitions')
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local snapshots=require('scripts.lifecycle-data')
local errors=require('scripts.runtime.errors')
local limits=require('scripts.runtime.limits')
local scheduler=require('scripts.scheduler')
local wires=require('scripts.physical-wires')
local M={}
local disclosure='Tweaked Computers: includes saved source code and labels (which may contain literals). Excludes application state, KV data, active runs, timers and outputs.'
M.disclosure=disclosure
local port_role=defs.port_role
-- Mapping is obtained from the real engine selection/create_blueprint call.
function M.prepare(blueprint,mapping)
  local entities=blueprint.get_blueprint_entities() or {}
  if #entities>limits.registry_entries then errors.raise('E_LIMIT','blueprint selection too large') end
  local byunit,max={},0; local endpoints={}; local output={}; local selected=0
  for _,e in ipairs(entities) do
    max=math.max(max,e.entity_number)
    local native=mapping[e.entity_number]
    if native and native.valid and native.name==e.name then byunit[native.unit_number]=e.entity_number end
  end
  for _,e in ipairs(entities) do
    local native=mapping[e.entity_number]; local rec,role=registry.by_entity(native)
    if rec and not rec.native_carrier and role=='body' then
      selected=selected+1
      local token='tc-blueprint-'..string.format('%.0f',registry.sequence())
      e.name=defs.devices[rec.kind].entity_name
      e.tags=e.tags or {}; e.tags.tc_settings=snapshots.settings(rec); e.tags.tc_body_token=token
      if rec.kind=='computer' then e.tags.tc_computer=nil; e.tags.tc_computer_undo=nil; e.tags.tc_computer_ghost=nil; e.tags.tc_computer_seen=nil end
      e.power_usage=nil; e.power_production=nil; e.buffer_size=nil; e.wires={}
      local network=lifecycle.endpoint(rec,'network')
      byunit[network.unit_number]=e.entity_number
      endpoints[#endpoints+1]={entry=e,port=network}; output[#output+1]=e
      for i,r in ipairs(defs.devices[rec.kind].roles) do if r~='network' then
        local port=lifecycle.endpoint(rec,r); local x,y=defs.offset(rec.kind,i,rec.direction)
        local number=byunit[port.unit_number]
        if not number then max=max+1; number=max end
        local entry={entity_number=number,name=defs.pad_name(rec.kind,r),position={x=e.position.x+x,y=e.position.y+y},
          direction=rec.direction,quality=rec.body.quality.name,tags={tc_port={version=1,token=token,role=r,body=e.name}},wires={}}
        endpoints[#endpoints+1]={entry=entry,port=port}; output[#output+1]=entry; byunit[port.unit_number]=number
      end end
    elseif (not rec or rec.native_carrier) and not port_role(e.name) and not defs.power_kind(e.name) then
      if native and native.valid and native.type=='entity-ghost' and defs.by_name[native.ghost_name]=='computer' then
        local tags=e.tags or {}; local undo=tags.tc_computer_undo
        local s=type(undo)=='table' and type(undo.snapshot)=='table' and undo.snapshot
          or type(tags.tc_settings)=='table' and tags.tc_settings.computer
        tags.tc_computer=nil; tags.tc_computer_undo=nil; tags.tc_computer_ghost=nil; tags.tc_computer_seen=nil; tags.tc_settings=nil
        if undo~=nil or s~=nil then
          local ok,c=pcall(snapshots.computer_settings,s)
          if not ok then
            blueprint.set_blueprint_entities({})
            errors.raise('E_ARGUMENT','computer ghost source refused; undo data excluded from copy')
          end
          tags.tc_settings={version=1,kind='computer',computer=c}
        end
        e.tags=tags; selected=selected+1
      end
      output[#output+1]=e
    end
  end
  if selected==0 then return false end
  local wire_count=0
  for _,a in ipairs(endpoints) do
    for _,edge in ipairs(wires.snapshot(a.port)) do
      wire_count=wire_count+1
      if wire_count>limits.network_edges*8 then errors.raise('E_LIMIT','blueprint role-wire capacity exceeded') end
      local target=edge.target; local number=byunit[target.owner.unit_number]
      if number and target.owner.valid then
        a.entry.wires[#a.entry.wires+1]={a.entry.entity_number,edge.cid,number,target.wire_connector_id}
      end
    end
  end
  blueprint.set_blueprint_entities(output)
  local old=blueprint.blueprint_description or ''
  if not old:find(disclosure,1,true) then blueprint.blueprint_description=old..(old=='' and '' or '\n\n')..disclosure end
  return true
end
function M.on_setup(event)
  local blueprint=event.record or event.stack
  if not blueprint then return end
  local ok,e=pcall(M.prepare,blueprint,event.mapping.get())
  if not ok then
    local player=game.get_player(event.player_index)
    if player then player.print('Blueprint source/settings capture refused; recreate the blueprint: '..(type(e)=='table' and e.message or 'engine failure')) end
  end
end
local function matches(rec,ghost,role,tags)
  if not rec or not rec.body.valid or rec.blueprint_token~=tags.token or defs.by_name[rec.body.name]~=defs.by_name[tags.body]
    or rec.body.surface~=ghost.surface or rec.body.force~=ghost.force then return false end
  local i
  for index,r in ipairs(defs.devices[rec.kind].roles) do if r==role then i=index end end
  if not i then return false end
  local x,y=defs.offset(rec.kind,i,rec.body.direction)
  return ghost.position.x==rec.body.position.x+x and ghost.position.y==rec.body.position.y+y
end
local function adopt_port(rec,role,port)
  local endpoint=lifecycle.endpoint(rec,role)
  assert(endpoint and endpoint.valid,'owned endpoint unavailable')
  -- Transfer real rotated/mirrored ghost/clone wires onto the already-owned
  -- endpoint. Legacy generic ports must never become selectable new-layout parts.
  wires.apply(wires.snapshot(port),endpoint,{[port.unit_number]=endpoint})
  port.destroy()
end
function M.adopt_ghost(ghost,rec)
  if not ghost.valid or ghost.name~='entity-ghost' then return false end
  local role=port_role(ghost.ghost_name); local tags=ghost.tags and ghost.tags.tc_port
  if not role or type(tags)~='table' or tags.version~=1 or tags.role~=role or type(tags.token)~='string' or #tags.token>128 then return false end
  if not rec then
    local root=registry.get(); if not registry.supported(root) then return false end
    for _,id in ipairs(root.order) do local candidate=registry.record(id); if matches(candidate,ghost,role,tags) then rec=candidate; break end end
  end
  if not matches(rec,ghost,role,tags) then return false end
  local _,port=ghost.revive{raise_revive=false}
  if not port then return false end
  -- Engine transfers the actual rotated/mirrored ghost wires to this exact port.
  adopt_port(rec,role,port)
  return true
end
function M.after_build(rec,event,material_restored)
  if not material_restored and event.tags and event.tags.tc_settings then snapshots.apply_settings(rec,event.tags.tc_settings) end
  local token=event.tags and event.tags.tc_body_token
  if type(token)=='string' and #token<=128 then
    rec.blueprint_token=token
    local ghosts=rec.body.surface.find_entities_filtered{type='entity-ghost',area=rec.body.bounding_box,force=rec.body.force}
    for _,ghost in ipairs(ghosts) do M.adopt_ghost(ghost,rec) end
  end
end
function M.on_ghost(event)
  local entity=event.entity
  if entity and entity.valid and entity.name=='entity-ghost' and port_role(entity.ghost_name) then M.adopt_ghost(entity); return true end
  if entity and entity.valid and port_role(entity.name) then
    if not registry.by_entity(entity) then entity.destroy() end
    return true -- externally revived/placed helper must never become an orphan
  end
  return false
end
function M.on_pasted(event)
  local source,source_role=registry.by_entity(event.source); local target,target_role=registry.by_entity(event.destination)
  if source and source.native_carrier or target and target.native_carrier then return end
  -- Native settings paste must never turn the Network shell into a signal source,
  -- even when the pasted-from entity is vanilla or otherwise not our authority.
  if target and target_role=='body' then lifecycle.reset_network(target) end
  if not source or not target or source_role~='body' or target_role~='body' or source.kind~=target.kind then return end
  local player=game.get_player(event.player_index)
  if not player or player.force.index~=source.force_index or player.force.index~=target.force_index
    or player.surface.index~=target.surface_index or not player.can_reach_entity(source.body) or not player.can_reach_entity(target.body) then return end
  local ok,e=pcall(function() snapshots.apply_settings(target,snapshots.settings(source)) end)
  if not ok then player.print('Settings copy refused; source/data retained: '..(type(e)=='table' and e.message or 'engine failure')) end
end
function M.clone(rec,source)
  local ok,e=pcall(function() snapshots.apply_settings(rec,snapshots.settings(source)) end)
  if not ok then
    rec.physical_error='clone settings refused; stopped for recovery'; rec.powered=false
    rec.diagnostic=type(e)=='table' and e or errors.new('E_ENGINE','clone settings refused')
  end
  rec.clone_source_id=source.id
end
function M.clone_port(event)
  local port=event.destination; local source,role=registry.by_entity(event.source)
  if not source or role=='body' then port.destroy(); return end
  port.minable_flag=false; port.destructible=false; port.operable=false; port.rotatable=false
  local cb=port.get_or_create_control_behavior(); cb.enabled=false
  for i=cb.sections_count,1,-1 do cb.remove_section(i) end
  local root=registry.get(); local pending=root.pending_clone_ports or {}; root.pending_clone_ports=pending
  if #pending>=limits.registry_entries*3 then port.destroy(); return end
  pending[#pending+1]={source=source.id,role=role,port=port}
end
function M.reconcile_clones(tick,spend)
  local root=registry.get(); local pending=root.pending_clone_ports
  if not pending or #pending==0 then return end
  local done=0
  while #pending>0 and done<16 do
    local p=pending[#pending]
    spend(limits.registry_entries*8+limits.network_edges*8+1)
    if p.port.valid then
      local owner
      for _,id in ipairs(root.order) do
        local rec=registry.record(id)
        if rec and rec.clone_source_id==p.source and rec.body.valid and rec.body.force==p.port.force and rec.body.surface==p.port.surface then
          for i,role in ipairs(defs.devices[rec.kind].roles) do if role==p.role then
            local x,y=defs.offset(rec.kind,i,rec.direction)
            if p.port.position.x==rec.body.position.x+x and p.port.position.y==rec.body.position.y+y then owner=rec end
          end end
        end
      end
      if owner then adopt_port(owner,p.role,p.port) else p.port.destroy() end
    end
    pending[#pending]=nil; done=done+1
  end
end
scheduler.register_phase('lifecycle','01-clone-components',M.reconcile_clones)
lifecycle.register_blueprint_adapter{after_build=M.after_build,on_ghost=M.on_ghost,clone=M.clone,clone_port=M.clone_port}
return M
