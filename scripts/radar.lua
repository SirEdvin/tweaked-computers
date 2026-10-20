-- Native carrier only: never writes the radar, its wires, settings or power.
local registry=require('scripts.registry')
local scheduler=require('scripts.scheduler')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local speaker=require('scripts.speaker')
local M={}
function M.supports(body)
  return body and body.valid and body.type=='radar'
    and (body.name=='radar' or body.name=='tc-interplanetary-radar' and script.active_mods['space-age']~=nil)
end
function M.available(rec)
  local b=rec.body
  return M.supports(b) and registry.by_entity(b)==rec and b.force.index==rec.force_index
    and b.surface.index==rec.surface_index and b.active and b.energy>0
end
function M.connector(rec,role,color)
  local b=rec.body
  if role~='network' or not M.supports(b) or registry.by_entity(b)~=rec
    or b.force.index~=rec.force_index or b.surface.index~=rec.surface_index then return nil end
  return b.get_wire_connector(defines.wire_connector_id['circuit_'..color],false)
end
function M.build(body)
  if not M.supports(body) then return nil end
  local existing=registry.by_entity(body); if existing then return existing end
  local ok,rec=pcall(registry.register,'radar',body)
  if not ok then return nil,rec end -- Refusal must never destroy/refund native material.
  rec.native_carrier='radar'; rec.physical_version=1
  rec.modem_tier=body.name=='radar' and 'surface' or 'interplanetary'
  rec.modem={version=1,channels={},count=0}
  rec.powered=M.available(rec)
  return rec
end
function M.state(rec,spend)
  local s=rec.modem
  if type(s)~='table' or getmetatable(s) or s.version~=1 or type(s.channels)~='table' or getmetatable(s.channels)
    or not errors.integer(s.count,0,128) then errors.raise('E_UNSUPPORTED','unsupported modem state; retained') end
  spend(129*4)
  local count=0
  for channel,value in pairs(s.channels) do
    count=count+1
    if count>128 or not errors.integer(channel,0,65535) or value~=true then
      errors.raise('E_UNSUPPORTED','invalid modem channels; retained')
    end
  end
  if count~=s.count then errors.raise('E_UNSUPPORTED','invalid modem count; retained') end
  return s
end
function M.pending(body)
  if not M.supports(body) or registry.by_entity(body) then return end
  local root=registry.get()
  if #root.order>=limits.registry_entries then errors.raise('E_CAPACITY','native radar identity capacity reached') end
  errors.raise('E_NETWORK_PENDING','connected native radar awaiting adoption')
end
function M.reconcile(rec,spend)
  spend(16)
  if not M.supports(rec.body) then return registry.remove(rec.id,'native_body_lost') end
  local b=rec.body
  if b.force.index~=rec.force_index or b.surface.index~=rec.surface_index then
    spend(16)
    local valid,diagnostic=pcall(M.state,rec,spend)
    if not valid then
      if type(diagnostic)~='table' or not diagnostic.code then error(diagnostic,0) end
      rec.modem_diagnostic=diagnostic; rec.powered=false; return
    end
    rec.force_index=b.force.index; rec.surface_index=b.surface.index
    rec.generation=rec.generation+1
    registry.get().entities[b.unit_number].generation=rec.generation
    rec.modem={version=1,channels={},count=0}
  end
  rec.powered=M.available(rec)
end
-- One paid connected frontier per tick, durable cursor. Newly adopted radars
-- enter the same order; no world enumeration or saved iterators are required.
function M.adopt(tick,spend)
  local root=registry.get(); local n=#root.order; if n==0 then return end
  if root.scheduler.radar_cursor~=nil and not errors.integer(root.scheduler.radar_cursor,1,limits.registry_entries) then
    errors.raise('E_UNSUPPORTED','invalid native adoption cursor; retained')
  end
  local cursor=math.min(root.scheduler.radar_cursor or 1,n)
  local rec=registry.record(root.order[cursor])
  local ok=scheduler.try_maintenance(function()
    spend(16)
    if not rec or not rec.physical_version or not rec.body.valid then return end
    local endpoint=rec.native_carrier and rec.body or rec.layout_version==2 and rec.body or rec.children.network
    if not endpoint or not endpoint.valid then return end
    local edges={}; local count=0
    for _,color in ipairs({'red','green'}) do
      local connector=endpoint.get_wire_connector(defines.wire_connector_id['circuit_'..color],false)
      if connector then
        local size=connector.real_connection_count; count=count+size
        if count>limits.network_edges then errors.raise('E_LIMIT','native adoption edge inventory exceeds limit') end
        spend(size*16+4)
        for _,edge in ipairs(connector.real_connections) do
          local b=edge.target.owner
          if edge.origin~=defines.wire_origin.radars and not edge.target.is_ghost and (M.supports(b) or speaker.supports(b))
            and b.force==endpoint.force and b.surface==endpoint.surface then edges[#edges+1]=b end
        end
      end
    end
    table.sort(edges,function(a,b) return a.unit_number<b.unit_number end)
    -- Precharge the entire bounded registration batch before its first mutation.
    spend(#edges*32)
    for _,b in ipairs(edges) do
      local adopted,e
      if speaker.supports(b) then adopted,e=speaker.build(b) else adopted,e=M.build(b) end
      if not adopted then error(e,0) end
    end
    rec.radar_adoption_diagnostic=nil
  end)
  if ok then root.scheduler.radar_cursor=cursor%#root.order+1 end
end
-- Keep ordinary lifecycle maintenance alive when a crowded native inventory is
-- outside the supported envelope. Discovery independently reports that limit.
function M.tick(tick,spend)
  local ok,e=pcall(M.adopt,tick,spend)
  if not ok then
    if type(e)~='table' or not e.code then error(e,0) end
    local root=registry.get(); local i=root.scheduler.radar_cursor or 1
    if not errors.integer(i,1,limits.registry_entries) then root.scheduler.radar_adoption_diagnostic=e; return end
    local rec=registry.record(root.order[i])
    if rec then rec.radar_adoption_diagnostic=e end
    if #root.order>0 then root.scheduler.radar_cursor=i%#root.order+1 end
  end
end
scheduler.register_phase('lifecycle','02-native-radar-adoption',M.tick)
return M
