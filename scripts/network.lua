-- Host-only physical graph policy. Native network IDs are never authority.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
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
  if not rec or role~='network' or lifecycle.connector(rec,'network',wire)~=connector then return nil end
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
-- Complete bounded BFS. A result is published only after the entire reachable
-- physical component is proved. Group identities are deliberately not vertices.
function M.discover(origin,wire,spend)
  M.wire(wire); spend=spend or function() end
  spend(16); origin_connector(origin,wire)
  local queue={origin.id}; local seen={[origin.id]=true}; local parents={}; local members={}
  local cursor,edges=1,0
  while cursor<=#queue do
    spend(8)
    local rec=registry.record(queue[cursor]); cursor=cursor+1
    local connector=rec and lifecycle.connector(rec,'network',wire)
    if not connector or not M.discovery_vertex(connector,origin,wire) then errors.raise('E_NETWORK_PENDING','physical topology changed during traversal') end
    if rec.kind~='computer' then members[#members+1]=rec end
    local connections=M.real_edges(connector,spend,limits.network_edges-edges)
    edges=edges+#connections
    for _,connection in ipairs(connections) do
      local next_rec=M.discovery_vertex(connection.target,origin,wire)
      if next_rec and not seen[next_rec.id] then
        if #queue>=limits.network_nodes then errors.raise('E_LIMIT','physical node inventory exceeds network limit') end
        seen[next_rec.id]=true; parents[next_rec.id]=rec.id; queue[#queue+1]=next_rec.id
      end
    end
  end
  return members,parents
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
      for _,connection in ipairs(connections) do if connection.target==connector then found=true; break end end
      if not found then return false end
    end
    previous=connector
  end
  return true
end
return M
