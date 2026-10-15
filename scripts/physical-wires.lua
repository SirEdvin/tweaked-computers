-- Native wire handoff only; no discovery permissions or guest values.
local limits=require('scripts.runtime.limits')
local M={}
function M.snapshot(entity)
  local out={}; local count=0
  for _,color in ipairs({'red','green'}) do
    local cid=defines.wire_connector_id['circuit_'..color]
    local c=entity.get_wire_connector(cid,false)
    if c then
      assert(c.connection_count<=limits.network_edges,'physical wire capacity exceeded')
      for _,connection in ipairs(c.connections) do
        count=count+1; assert(count<=limits.network_edges,'physical wire capacity exceeded')
        out[#out+1]={cid=cid,target=connection.target,origin=connection.origin}
      end
    end
  end
  return out
end
function M.apply(edges,entity,remap)
  local added={}
  local ok,e=pcall(function()
    for _,edge in ipairs(edges) do
      assert(edge.target.valid,'wire target disappeared')
      local target=edge.target
      local replacement=remap and remap[target.owner.unit_number]
      if replacement then target=replacement.get_wire_connector(target.wire_connector_id,true) end
      local from=assert(entity.get_wire_connector(edge.cid,true))
      local existing=false
      for _,connection in ipairs(from.connections) do
        if connection.target==target and connection.origin==edge.origin then existing=true; break end
      end
      if not existing then
        assert(from.connect_to(target,false,edge.origin),'native wire handoff refused')
        added[#added+1]={from=from,target=target,origin=edge.origin}
      end
    end
  end)
  if not ok then
    for _,edge in ipairs(added) do edge.from.disconnect_from(edge.target,edge.origin) end
    error(e,0)
  end
end
return M
