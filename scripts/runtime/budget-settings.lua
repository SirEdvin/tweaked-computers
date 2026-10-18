-- Shared settings-stage definitions and control-stage refresh. Effective limits
-- remain a plain table so computer.getLimits() can return a defensive Data copy.
local limits=require('scripts.runtime.limits')
local M={definitions={
  {key='compile_work',name='tc-compile-work',minimum_value=1,maximum_value=100000000},
  {key='callback_work',name='tc-callback-work',minimum_value=1,maximum_value=100000000},
  {key='callback_allocations',name='tc-callback-allocations',minimum_value=1,maximum_value=100000000},
  {key='host_work_per_tick',name='tc-host-work-per-tick',minimum_value=limits.maintenance_work_per_tick+1,maximum_value=1000000000},
}}
for _,definition in ipairs(M.definitions) do definition.default_value=limits[definition.key] end
function M.refresh()
  for _,definition in ipairs(M.definitions) do
    limits[definition.key]=settings.global[definition.name].value
  end
end
return M
