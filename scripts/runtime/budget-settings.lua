-- Shared settings-stage definitions and control-stage refresh. Effective limits
-- remain a plain table so computer.getLimits() can return a defensive Data copy.
local limits=require('scripts.runtime.limits')
local maintenance_max=100000000
local M={maintenance_max=maintenance_max,definitions={
  {key='compile_work',name='tc-compile-work',minimum_value=1,maximum_value=100000000},
  {key='callback_work',name='tc-callback-work',minimum_value=1,maximum_value=100000000},
  {key='callback_allocations',name='tc-callback-allocations',minimum_value=1,maximum_value=100000000},
  {key='host_work_per_tick',name='tc-host-work-per-tick',minimum_value=limits.maintenance_work_per_tick+1,maximum_value=1000000000},
  {key='maintenance_work_per_tick',name='tc-maintenance-work-per-tick',minimum_value=limits.maintenance_work_per_tick,maximum_value=maintenance_max},
}}
for _,definition in ipairs(M.definitions) do definition.default_value=limits[definition.key] end
function M.refresh()
  for _,definition in ipairs(M.definitions) do
    limits[definition.key]=settings.global[definition.name].value
  end
  -- Do not raise the shared ceiling to honor a larger maintenance request.
  -- Keep at least one guest unit even at the smallest supported host setting.
  limits.maintenance_work_per_tick=math.min(limits.maintenance_work_per_tick,limits.host_work_per_tick-1)
end
return M
