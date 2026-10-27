-- Host-only physical graph policy. Native network IDs are never authority.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local radar=require('scripts.radar')
local speaker=require('scripts.speaker')
local scheduler=require('scripts.scheduler')
local M={}
function M.wire(wire)
  if wire~='red' and wire~='green' then errors.raise('E_ARGUMENT','explicit red or green wire required') end
  return wire
end
function M.same_scope(entity,origin)
  return entity and entity.valid and entity.type~='entity-ghost'
    and entity.force.index==origin.force_index and entity.surface.index==origin.surface_index
end
function M.discovery_vertex(connector,origin,wire)
  if not connector or not connector.valid or connector.is_ghost or not M.same_scope(connector.owner,origin) then return nil end
  local rec,role=registry.by_entity(connector.owner)
  radar.pending(connector.owner)
  if not rec then speaker.pending(connector.owner) end
  if not rec or (role~='network' and not (role=='body' and (rec.layout_version==2 or rec.native_carrier=='radar' or rec.native_carrier=='speaker')))
    or lifecycle.connector(rec,'network',wire)~=connector then return nil end
  return rec
end
-- Shared primitive for the separate configurator target policy. Count admission
-- precedes native array materialization and includes ignored external edges.
function M.real_edges(connector,spend,remaining)
  if not connector or not connector.valid or connector.is_ghost then return {} end
  local n=connector.real_connection_count
  if n>remaining then errors.raise('E_LIMIT','physical edge inventory exceeds network limit') end
  spend(n*4+4)
  return connector.real_connections
end
local function origin_connector(origin,wire)
  local c=lifecycle.connector(origin,'network',wire)
  if not c or not M.same_scope(c.owner,origin) then errors.raise('E_UNREACHABLE','computer network endpoint unavailable') end
  return c
end
local function vertex(connector,origin,wire,adopting)
  if adopting and connector and connector.valid and not connector.is_ghost and M.same_scope(connector.owner,origin) then
    local b=connector.owner
    if (radar.supports(b) or speaker.supports(b))
      and b.get_wire_connector(defines.wire_connector_id['circuit_'..wire],false)==connector then
      return registry.by_entity(b),true
    end
  end
  local rec=M.discovery_vertex(connector,origin,wire)
  return rec,rec~=nil
end
-- Discovery and admission share one color-preserving, complete physical proof.
local function walk(origin,wire,spend,adopting)
  M.wire(wire); spend=spend or function() end
  spend(16); local first=origin_connector(origin,wire)
  local queue={first}; local seen={[first.owner.unit_number]=true}; local parents={}; local members={}; local native={}
  local cursor,edges=1,0
  while cursor<=#queue do
    spend(8)
    local connector=queue[cursor]; cursor=cursor+1
    local rec,valid=vertex(connector,origin,wire,adopting)
    if not valid then errors.raise('E_NETWORK_PENDING','physical topology changed during traversal') end
    if adopting then
      if not rec or rec.force_index~=origin.force_index or rec.surface_index~=origin.surface_index then
        native[#native+1]=connector.owner
      end
    elseif rec.kind~='computer' then members[#members+1]=rec end
    local connections=M.real_edges(connector,spend,limits.network_edges-edges)
    edges=edges+#connections
    for _,connection in ipairs(connections) do
      if connection.origin~=defines.wire_origin.radars then
        local next_rec,accepted=vertex(connection.target,origin,wire,adopting)
        if accepted then
          local unit=connection.target.owner.unit_number
          if not seen[unit] then
            if #queue>=limits.network_nodes then errors.raise('E_LIMIT','physical node inventory exceeds network limit') end
            seen[unit]=true; queue[#queue+1]=connection.target
            if not adopting then parents[next_rec.id]=rec.id end
          end
        end
      end
    end
  end
  return members,parents,native
end
function M.discover(origin,wire,spend)
  local members,parents=walk(origin,wire,spend,false)
  return members,parents
end
local function prepaid() end
function M.adopt(origin,wire,spend)
  assert(origin.kind=='computer','native adoption requires a computer root')
  local _,_,native=walk(origin,wire,spend,true)
  local root=registry.get(); local added,changed=0,0
  for _,body in ipairs(native) do
    if registry.by_entity(body) then changed=changed+1 else added=added+1 end
  end
  if root.retained_count+added>limits.registry_entries then errors.raise('E_CAPACITY','native identity capacity reached') end
  spend(#native*32+changed*(32+129*4))
  table.sort(native,function(a,b) return a.unit_number<b.unit_number end)
  for _,body in ipairs(native) do
    local carrier=radar.supports(body) and radar or speaker
    local rec=registry.by_entity(body)
    if rec then carrier.reconcile(rec,prepaid)
    else
      local adopted,e=carrier.build(body)
      if not adopted then error(e,0) end
    end
  end
end
function M.adopt_tick(tick,spend)
  local root=registry.get(); spend(#root.order*4+1)
  local computers={}
  for id,rec in pairs(root.computers) do if rec.physical_version and rec.body.valid then computers[#computers+1]=id end end
  if #computers==0 then return end
  table.sort(computers)
  local size=#computers*2; local cursor=root.scheduler.native_cursor or 1
  if not errors.integer(cursor,1,limits.registry_entries*2) then errors.raise('E_UNSUPPORTED','invalid native adoption cursor; retained') end
  cursor=math.min(cursor,size)
  for _=1,math.min(3,size) do
    local rec=root.computers[computers[math.floor((cursor-1)/2)+1]]
    local wire=cursor%2==1 and 'red' or 'green'
    local ok,e=pcall(scheduler.try_maintenance,function() M.adopt(rec,wire,spend) end)
    if not ok and (type(e)~='table' or not e.code) then error(e,0) end
    rec.radar_adoption_diagnostic=not ok and e or nil
    cursor=cursor%size+1; root.scheduler.native_cursor=cursor
  end
end
function M.witness(origin,member,parents,spend)
  local reversed={}; local id=member.id
  while id do
    if spend then spend(4) end
    reversed[#reversed+1]=id
    if id==origin.id then break end
    id=parents[id]
  end
  assert(reversed[#reversed]==origin.id,'missing physical witness')
  local path={}; for i=#reversed,1,-1 do path[#path+1]=reversed[i] end
  return path
end
function M.validate_witness(origin,wire,path,spend)
  M.wire(wire)
  if type(path)~='table' or #path<1 or #path>limits.network_nodes or path[1]~=origin.id then return false end
  local previous; local edges=0
  for _,id in ipairs(path) do
    spend(8)
    local rec=registry.record(id); local connector=rec and lifecycle.connector(rec,'network',wire)
    if not M.discovery_vertex(connector,origin,wire) then return false end
    if previous then
      local found=false
      local connections=M.real_edges(previous,spend,limits.network_edges-edges); edges=edges+#connections
      for _,connection in ipairs(connections) do if connection.origin~=defines.wire_origin.radars and connection.target==connector then found=true; break end end
      if not found then return false end
    end
    previous=connector
  end
  return true
end
scheduler.register_phase('lifecycle','02-native-radar-adoption',M.adopt_tick)
return M
