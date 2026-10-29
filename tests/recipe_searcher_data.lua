-- Companion-mod data fixture: third-party catalogue plus exact production contracts.
local defs=require('__tweaked-computers__.scripts.device-definitions')
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
local def=defs.devices.recipe_searcher
assert(def.width==1 and def.watts==30000 and equal(def.roles,{'network'}))
local shell=data.raw['constant-combinator'][def.entity_name]
assert(shell.tile_width==1 and shell.tile_height==1 and shell.minable.result==def.name)
assert(equal(shell.circuit_wire_connection_points,defs.points('recipe_searcher','network',false)))
assert(not shell.inventory_size and not shell.fluid_boxes)
local power=data.raw['electric-energy-interface'][def.power_name]
assert(not power.selectable_in_game and not power.minable and power.energy_usage=='30000W')
local recipe=data.raw.recipe[def.name]
assert(recipe.energy_required==2 and recipe.enabled==false and equal(recipe.ingredients,{
  {type='item',name='steel-plate',amount=10},{type='item',name='advanced-circuit',amount=5},{type='item',name='processing-unit',amount=2}}))
assert(equal(recipe.results,{{type='item',name=def.name,amount=1}}))
local tech=data.raw.technology[def.technology]
assert(equal(tech.prerequisites,{'tc-circuit-computers','utility-science-pack'}))
assert(equal(tech.unit,{count=200,ingredients={{'automation-science-pack',1},{'logistic-science-pack',1},{'utility-science-pack',1}},time=60}))
assert(equal(tech.effects,{{type='unlock-recipe',recipe=def.name},{type='unlock-recipe',recipe='tc-factoriopedia-interface'}}))
local old=data.raw.technology['tc-circuit-computers']
assert(equal(old.prerequisites,{'circuit-network','advanced-circuit'}))
assert(equal(old.unit,{count=100,ingredients={{'automation-science-pack',1},{'logistic-science-pack',1}},time=30}))
local expected={}
for _,kind in ipairs({'computer','kv','monitor','logic','configurator'}) do
  local d=defs.devices[kind]; assert(d.technology==old.name)
  expected[#expected+1]={type='unlock-recipe',recipe=d.name}
end
assert(equal(old.effects,expected))
log('TC_RECIPE_DATA_OK geometry-power-crafting-independent-research')
local names={'tc-rs-overlap','tc-rs-empty','tc-rs-fifty','tc-rs-fiftyone','tc-rs-single51','tc-rs-complex','tc-rs-large'}
for _,name in ipairs(names) do
  data:extend{{type='item',name=name,icon='__base__/graphics/icons/iron-plate.png',icon_size=64,stack_size=100,auto_recycle=false}}
end
data:extend{{type='fluid',name='tc-rs-overlap',icon='__base__/graphics/icons/fluid/water.png',icon_size=64,
  default_temperature=15,max_temperature=500,auto_barrel=false,base_color={0,0,1},flow_color={0,0,1}},
  {type='recipe-category',name='tc-rs-primary'},{type='recipe-category',name='tc-rs-additional'},
  {type='recipe-category',name='tc-rs-refined'},{type='recipe-category',name='tc-rs-recycling'}}
local function producer(name,product,category)
  return {type='recipe',name=name,icon='__base__/graphics/icons/iron-plate.png',icon_size=64,
    categories={category or 'tc-rs-primary'},enabled=false,auto_recycle=false,
    ingredients={{type='item',name='iron-plate',amount=1}},results={{type='item',name=product,amount=1}}}
end
for i=1,50 do data:extend{producer(string.format('tc-rs-50-%02d',i),'tc-rs-fifty')} end
for i=1,51 do data:extend{producer(string.format('tc-rs-51-%02d',i),'tc-rs-fiftyone',i<=2 and 'tc-rs-refined' or 'tc-rs-primary')} end
for i=1,51 do data:extend{producer(string.format('tc-rs-single-%02d',i),'tc-rs-single51')} end
-- Unrelated producers make zero-match filtering exercise a larger mod catalogue.
for i=1,2048 do data:extend{producer(string.format('tc-rs-catalogue-%04d',i),'iron-plate')} end
local item=producer('tc-rs-item','tc-rs-overlap')
item.categories={'tc-rs-primary','tc-rs-additional'}
local fluid=producer('tc-rs-fluid','tc-rs-overlap'); fluid.results={{type='fluid',name='tc-rs-overlap',amount=5,temperature=80}}
local input=producer('tc-rs-input-only','iron-plate'); input.ingredients={{type='item',name='tc-rs-overlap',amount=1}}
local hidden=producer('tc-rs-hidden','tc-rs-overlap','tc-rs-recycling')
hidden.hidden=true; hidden.hide_from_player_crafting=true; hidden.hide_from_stats=true; hidden.hidden_in_factoriopedia=true
local complex=producer('tc-rs-metadata','tc-rs-complex')
complex.energy_required=7.5; complex.categories={'tc-rs-primary','tc-rs-additional','tc-rs-refined'}
complex.ingredients={{type='fluid',name='water',amount=10,minimum_temperature=20,maximum_temperature=90,ignored_by_stats=2,fluidbox_index=1,fluidbox_multiplier=2},
  {type='item',name='iron-plate',amount=3,ignored_by_stats=1}}
complex.results={{type='item',name='tc-rs-complex',amount_min=1,amount_max=3,independent_probability=.5,ignored_by_stats=1,ignored_by_productivity=1,extra_count_fraction=.25,percent_spoiled=.1},
  {type='fluid',name='tc-rs-overlap',amount_min=2,amount_max=6,independent_probability=.75,temperature=80,fluidbox_index=1,ignored_by_stats=1,ignored_by_productivity=1},
  {type='item',name='tc-rs-complex',amount=1,independent_probability=.5,shared_probability={min=.25,max=.75}}}
if mods['space-age'] then
  complex.surface_conditions={{property='pressure',min=10},{property='gravity',max=40},{property='magnetic-field'}}
end
local large=producer('tc-rs-large','tc-rs-large'); large.results={}
for i=1,600 do
  large.results[i]={type='item',name='tc-rs-large',amount_min=1,amount_max=i,independent_probability=i/1000,
    ignored_by_stats=1,ignored_by_productivity=1}
end
data:extend{item,fluid,input,hidden,complex,large}
