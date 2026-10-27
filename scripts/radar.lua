-- Native carrier only: never writes the radar, its wires, settings or power.
local registry=require('scripts.registry')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
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
  if not M.supports(body) then return end
  local rec=registry.by_entity(body)
  if rec then
    if body.force.index==rec.force_index and body.surface.index==rec.surface_index then return end
    errors.raise('E_NETWORK_PENDING','connected radar scope awaiting reconciliation')
  end
  local root=registry.get()
  if root.retained_count>=limits.registry_entries then errors.raise('E_CAPACITY','native radar identity capacity reached') end
  errors.raise('E_NETWORK_PENDING','connected native radar awaiting adoption')
end
function M.reconcile(rec,spend)
  spend(16)
  if not M.supports(rec.body) then
    spend(limits.registry_entries*6)
    return registry.remove(rec.id,'native_body_lost')
  end
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
return M
