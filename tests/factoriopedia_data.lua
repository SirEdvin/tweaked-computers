-- Native companion catalogue; no production metadata is replaced.
local defs=require('__tweaked-computers__.scripts.device-definitions')
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local def=assert(defs.devices.factoriopedia_interface,'missing Factoriopedia Interface')
assert(def.width==1 and def.watts==30000 and equal(def.roles,{'network'}))
local body=data.raw['constant-combinator'][def.entity_name]
assert(body.tile_width==1 and body.tile_height==1 and body.minable.result==def.name)
assert(equal(body.circuit_wire_connection_points,defs.points('factoriopedia_interface','network',false)))
assert(not body.inventory_size and not body.fluid_boxes)
local power=data.raw['electric-energy-interface'][def.power_name]
assert(not power.selectable_in_game and not power.minable and power.energy_usage=='30000W')
local recipe=data.raw.recipe[def.name]
local ingredients={{type='item',name='steel-plate',amount=10},{type='item',name='advanced-circuit',amount=5},{type='item',name='processing-unit',amount=2}}
assert(recipe.energy_required==2 and recipe.enabled==false and equal(recipe.ingredients,ingredients))
assert(equal(recipe.results,{{type='item',name=def.name,amount=1}}))
local search=data.raw.recipe['tc-recipe-searcher']
assert(search.energy_required==2 and search.enabled==false and equal(search.ingredients,ingredients))
local technology=data.raw.technology[def.technology]
assert(def.technology=='tc-recipe-searcher')
assert(equal(technology.prerequisites,{'tc-circuit-computers','utility-science-pack'}))
assert(equal(technology.unit,{count=200,ingredients={{'automation-science-pack',1},{'logistic-science-pack',1},{'utility-science-pack',1}},time=60}))
assert(equal(technology.effects,{{type='unlock-recipe',recipe='tc-recipe-searcher'},{type='unlock-recipe',recipe=def.name},{type='unlock-recipe',recipe='tc-production-statistics'}}))
log('TC_FACT_DATA_OK geometry-power-crafting-shared-research')
local function item(name,fields)
  local p={type='item',name=name,localised_name=name,icon='__base__/graphics/icons/iron-plate.png',icon_size=64,stack_size=17,weight=3000,auto_recycle=false}
  for k,v in pairs(fields or {}) do p[k]=v end
  data:extend{p}
end
item('tc-fp-overlap',{hidden=true,hidden_in_factoriopedia=true,factoriopedia_alternative='iron-plate'})
item('tc-fp-fuel',{fuel_categories={'chemical','tc-fp-fuel'},fuel_value='2MJ',burnt_result='iron-plate'})
item('tc-fp-heavy',{weight=2000000,stack_size=7,send_to_orbit_mode='not-sendable'})
item('tc-fp-no-orbit',{send_to_orbit_mode='not-sendable'})
item('tc-fp-fractional',{weight=3001,stack_size=13})
item('tc-fp-zero',{weight=0,stack_size=1,flags={'only-in-cursor','spawnable'}})
if mods['space-age'] then
  item('tc-fp-spoil',{spoil_ticks=600,spoil_result='iron-plate'})
  item('tc-fp-trigger',{spoil_ticks=180,spoil_to_trigger_result={items_per_trigger=1,trigger={type='direct',action_delivery={type='instant',target_effects={{type='create-entity',entity_name='explosion'}}}}}})
end
data:extend{{type='fuel-category',name='tc-fp-fuel'}}
local function fluid(name,low,high)
  data:extend{{type='fluid',name=name,localised_name=name,icon='__base__/graphics/icons/fluid/water.png',icon_size=64,
    default_temperature=low,max_temperature=high,gas_temperature=123,heat_capacity='123J',fuel_value='0J',
    auto_barrel=false,base_color={0,0,1},flow_color={0,0,1}}}
end
fluid('tc-fp-overlap',-20,80)
fluid('tc-fp-equal',-5,-5)
