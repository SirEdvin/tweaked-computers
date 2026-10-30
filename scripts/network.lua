-- Host-only physical graph policy. Native network IDs are never authority.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local radar=require('scripts.radar')
local speaker=require('scripts.speaker')
local scheduler=require('scripts.scheduler')
local M={}
local function adoption_state()
  local s=registry.get().native_adoption
  if type(s)~='table' or s.version~=1 or type(s.order)~='table' or type(s.entries)~='table'
    or not errors.integer(s.cursor,1,math.max(1,#s.order)) then
    errors.raise('E_UNSUPPORTED','unsupported native discovery membership; identities retained')
  end
  return s
end
local function retire_adoption(s,key)
  local item=s.entries[key]; if not item then return end
  s.entries[key]=nil
  for i,entry in ipairs(s.order) do
    if entry==item then
      table.remove(s.order,i)
      if i<s.cursor then s.cursor=s.cursor-1 end
      if s.cursor>#s.order then s.cursor=1 end
      break
    end
  end
end
local function request_adoption(origin,wire,spend)
  local s=adoption_state(); local key=origin.id..'/'..wire
  if s.entries[key] then return end
  if spend then spend(#s.order*2+4) end
  local item={key=key,computer=origin,generation=origin.generation,wire=wire}
  s.entries[key]=item
  local i=#s.order+1
  while i>1 and s.order[i-1].key>key do i=i-1 end
  if #s.order>0 and i<=s.cursor then s.cursor=s.cursor+1 end
  table.insert(s.order,i,item)
end
registry.register_initializer('native-adoption',function(root)
  if not registry.supported(root) or root.native_adoption~=nil then return end
  root.native_adoption={version=1,order={},entries={},cursor=1}
  for _,id in ipairs(root.order) do
    local c=root.computers[id]
    if c and c.physical_version then
      for _,wire in ipairs({'red','green'}) do
        local view=type(c.network_views)=='table' and c.network_views[wire]
        if c.radar_adoption_diagnostic or type(view)=='table' and type(view.diagnostic)=='table' and view.diagnostic.code=='E_NETWORK_PENDING' then request_adoption(c,wire) end
      end
    end
  end
end)
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
  local ok,members,parents=pcall(walk,origin,wire,spend,false)
  if not ok then
    if type(members)=='table' and members.code=='E_NETWORK_PENDING' then request_adoption(origin,wire,spend) end
    error(members,0)
  end
  return members,parents
end
local function prepaid() end
function M.adopt(origin,wire,spend)
  assert(origin.kind=='computer','native adoption requires a computer root')
  local pending=adoption_state(); local key=origin.id..'/'..wire
  if pending.entries[key] then spend(#pending.order+1) end
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
  retire_adoption(pending,key)
end
function M.adopt_tick(tick,spend)
  local root=registry.get(); local valid,s=pcall(adoption_state)
  if not valid then root.scheduling_diagnostic=s; return end
  if #s.order==0 then return end
  for _=1,math.min(3,#s.order) do
    local item=s.order[s.cursor]; if not item then break end
    local rec=item.computer
    if root.computers[rec.id]~=rec or not rec.body.valid or rec.generation~=item.generation then
      spend(#s.order+1); retire_adoption(s,item.key)
    else
      local ok,admitted=pcall(scheduler.try_maintenance,function() M.adopt(rec,item.wire,spend) end)
      if not ok and (type(admitted)~='table' or not admitted.code) then error(admitted,0) end
      rec.radar_adoption_diagnostic=not ok and admitted or nil
      if not ok and admitted.code~='E_NETWORK_PENDING' and admitted.code~='E_BUSY' then retire_adoption(s,item.key) end
      if s.entries[item.key]==item and #s.order>0 then s.cursor=s.cursor%#s.order+1 end
    end
  end
end
registry.register_cleanup('native-discovery',function(rec)
  if rec.kind~='computer' then return end
  local s=adoption_state()
  retire_adoption(s,rec.id..'/red'); retire_adoption(s,rec.id..'/green')
end)
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
