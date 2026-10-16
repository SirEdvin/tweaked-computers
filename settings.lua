local budgets=require('scripts.runtime.budget-settings')
for index,definition in ipairs(budgets.definitions) do
  data:extend{{type='int-setting',name=definition.name,setting_type='runtime-global',
    default_value=definition.default_value,minimum_value=definition.minimum_value,
    maximum_value=definition.maximum_value,order='tc-budget-'..index}}
end
