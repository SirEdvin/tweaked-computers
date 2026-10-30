local defs=require('__tweaked-computers__.scripts.device-definitions')
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local def=assert(defs.devices.production_statistics,'missing Production Statistics device')
assert(def.width==1 and def.watts==nil and equal(def.roles,{'network'}))
local body=data.raw['constant-combinator'][def.entity_name]
assert(body.tile_width==1 and body.tile_height==1 and body.minable.result==def.name)
assert(equal(body.circuit_wire_connection_points,defs.points('production_statistics','network',false)))
assert(not body.inventory_size and not body.fluid_boxes)
local power=data.raw['electric-energy-interface'][def.power_name]
assert(not power.selectable_in_game and not power.minable and power.energy_usage=='0W')
assert(data.raw.item[def.name].stack_size==50)
local recipe=data.raw.recipe[def.name]
assert(recipe.energy_required==2 and recipe.enabled==false)
assert(equal(recipe.ingredients,{{type='item',name='iron-plate',amount=8},{type='item',name='electronic-circuit',amount=5},{type='item',name='advanced-circuit',amount=2}}))
assert(equal(recipe.results,{{type='item',name=def.name,amount=1}}))
assert(def.technology=='tc-recipe-searcher')
local technology=data.raw.technology[def.technology]
assert(equal(technology.prerequisites,{'tc-circuit-computers','utility-science-pack'}))
assert(equal(technology.unit,{count=200,ingredients={{'automation-science-pack',1},{'logistic-science-pack',1},{'utility-science-pack',1}},time=60}))
local unlocked={}; for _,effect in ipairs(technology.effects) do assert(effect.type=='unlock-recipe'); unlocked[effect.recipe]=true end
assert(unlocked['tc-recipe-searcher'] and unlocked['tc-factoriopedia-interface'] and unlocked[def.name])
log('TC_STAT_DATA_OK geometry-contacts-power-recipe-shared-research')
-- Real extra identities, deliberately sharing a name across item/fluid namespaces.
data:extend{{type='item',name='tc-stat-overlap',icon='__base__/graphics/icons/iron-plate.png',icon_size=64,stack_size=50,auto_recycle=false},
  {type='fluid',name='tc-stat-overlap',icon='__base__/graphics/icons/fluid/water.png',icon_size=64,default_temperature=15,base_color={0,0,1},flow_color={0,0,1},auto_barrel=false}}
