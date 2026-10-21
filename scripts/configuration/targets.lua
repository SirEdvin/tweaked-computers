-- Separate same-colour connector graph. There are NO implicit intra-entity edges.
local network=require('scripts.network')
local lifecycle=require('scripts.lifecycle')
local registry=require('scripts.registry')
local errors=require('scripts.runtime.errors')
local limits=require('scripts.runtime.limits')
local M={}
function M.identity(entity)
  -- Engine registration is stable, saveable and never uses position as identity.
  local registration=script.register_on_object_destroyed(entity)
  if not errors.integer(registration,1,9007199254740991) then errors.raise('E_CAPACITY','device identity range exhausted') end
  return 'device-'..string.format('%.0f',registration)
end
function M.inventory(origin,wire,spend)
  network.wire(wire); spend(16)
  local start=lifecycle.connector(origin,'targets',wire)
  if not start or not start.valid or not network.same_scope(start.owner,origin) then errors.raise('E_UNREACHABLE','target port unavailable') end
  local function vertex(c) return M.identity(c.owner)..'/'..c.wire_connector_id end
  local queue={start}; local seen={[vertex(start)]=true}; local inventory={}; local cursor,edges=1,0
  while cursor<=#queue do
    spend(12)
    local connector=queue[cursor]; cursor=cursor+1
    if not connector.valid or connector.is_ghost or not network.same_scope(connector.owner,origin) then errors.raise('E_NETWORK_PENDING','target topology changed') end
    local entity=connector.owner; local rec=registry.by_entity(entity)
    local described=rec and rec.body or entity
    if not network.same_scope(described,origin) then errors.raise('E_NETWORK_PENDING','owned target body scope changed') end
    if not rec or rec.id~=origin.id then
      local id=M.identity(described); local item=inventory[id]
      if not item then item={id=id,entity=described,protected=rec~=nil and not rec.native_carrier,connectors={}}; inventory[id]=item end
      for name,value in pairs(defines.wire_connector_id) do
        if value==connector.wire_connector_id then item.connectors[name]=true; break end
      end
    end
    local connections=network.real_edges(connector,spend,limits.network_edges-edges); edges=edges+#connections
    for _,edge in ipairs(connections) do
      local target=edge.target
      if target and target.valid and not target.is_ghost and target.wire_type==defines.wire_type[wire]
        and network.same_scope(target.owner,origin) and not seen[vertex(target)] then
        if #queue>=limits.network_nodes then errors.raise('E_LIMIT','target connector inventory exceeds limit') end
        seen[vertex(target)]=true; queue[#queue+1]=target
      end
    end
  end
  return inventory
end
function M.lookup(origin,id,wire,spend,optional)
  if type(id)~='string' or #id==0 or #id>limits.identifier_bytes then errors.raise('E_ARGUMENT','bounded device identity required') end
  local item=M.inventory(origin,wire,spend)[id]
  if not item and not optional then errors.raise('E_UNREACHABLE','device identity absent from current target network') end
  return item
end
return M
