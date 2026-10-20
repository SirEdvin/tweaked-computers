-- Observed vanilla body: no owned helpers, native settings or power writes.
local registry=require('scripts.registry')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local M={}
function M.supports(b)
  return b and b.valid and b.name=='programmable-speaker' and b.type=='programmable-speaker'
end
function M.available(rec)
  local b=rec.body
  return M.supports(b) and registry.by_entity(b)==rec and b.force.index==rec.force_index
    and b.surface.index==rec.surface_index and b.energy>0 and not b.disabled_by_script
    and not b.frozen and not b.to_be_deconstructed(b.force)
end
function M.connector(rec,role,color)
  local b=rec.body
  if role~='network' or not M.supports(b) or registry.by_entity(b)~=rec
    or b.force.index~=rec.force_index or b.surface.index~=rec.surface_index then return nil end
  return b.get_wire_connector(defines.wire_connector_id['circuit_'..color],false)
end
function M.build(b)
  if not M.supports(b) then return nil end
  local rec=registry.by_entity(b); if rec then return rec end
  local ok,e=pcall(registry.register,'speaker',b)
  if not ok then return nil,e end
  rec=e; rec.native_carrier='speaker'; rec.physical_version=1; rec.powered=M.available(rec)
  return rec
end
function M.pending(b)
  if not M.supports(b) or registry.by_entity(b) then return end
  if #registry.get().order>=limits.registry_entries then errors.raise('E_CAPACITY','native speaker identity capacity reached') end
  errors.raise('E_NETWORK_PENDING','connected native speaker awaiting adoption')
end
function M.reconcile(rec,spend)
  spend(16)
  if not M.supports(rec.body) then return registry.remove(rec.id,'native_body_lost') end
  local b=rec.body
  if b.force.index~=rec.force_index or b.surface.index~=rec.surface_index then
    spend(16)
    rec.force_index=b.force.index; rec.surface_index=b.surface.index
    rec.generation=rec.generation+1
    registry.get().entities[b.unit_number].generation=rec.generation
  end
  rec.powered=M.available(rec)
end
return M
