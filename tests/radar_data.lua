-- Runs after production data in the isolated companion, from the tested ZIP.
local native=data.raw.radar.radar
assert(native.energy_usage=='300kW' and native.selection_box[2][1]==1.5)
assert(native.pictures.layers[1].scale==0.5 and native.minable.result=='radar')
assert(native.max_distance_of_sector_revealed==14 and native.max_distance_of_nearby_sector_revealed==3)
local name='tc-interplanetary-radar'
if not mods['space-age'] then
  for _,kind in ipairs({'radar','item','recipe','technology'}) do assert(not data.raw[kind][name]) end
else
  local r=assert(data.raw.radar[name]); local item=assert(data.raw.item[name])
  local recipe=assert(data.raw.recipe[name]); local tech=assert(data.raw.technology[name])
  assert(r.energy_usage=='1MW' and r.selection_box[2][1]==2.5 and r.collision_box[2][1]==2.2)
  assert(r.heating_energy=='300kW')
  assert(r.pictures.layers[1].scale==0.75 and r.pictures.layers[2].scale==0.75)
  assert(r.integration_patch.scale==0.75 and r.water_reflection.pictures.scale==7.5)
  assert(r.max_distance_of_sector_revealed==native.max_distance_of_sector_revealed)
  assert(r.max_distance_of_nearby_sector_revealed==native.max_distance_of_nearby_sector_revealed)
  assert(item.place_result==name and r.minable.result==name and not recipe.enabled and recipe.energy_required==10)
  local ingredients={radar=1,['steel-plate']=20,['processing-unit']=20,['low-density-structure']=10}
  assert(#recipe.ingredients==4)
  for _,entry in ipairs(recipe.ingredients) do assert(entry.type=='item' and ingredients[entry.name]==entry.amount); ingredients[entry.name]=nil end
  assert(next(ingredients)==nil and recipe.results[1].name==name and recipe.results[1].amount==1)
  local expected={['automation-science-pack']=true,['logistic-science-pack']=true,['chemical-science-pack']=true,
    ['production-science-pack']=true,['utility-science-pack']=true,['space-science-pack']=true}
  assert(#tech.unit.ingredients==6 and tech.unit.count==500 and tech.unit.time==30)
  for _,pack in ipairs(tech.unit.ingredients) do assert(expected[pack[1]] and pack[2]==1); expected[pack[1]]=nil end
  assert(next(expected)==nil and tech.effects[1].recipe==name)
  local prerequisites={['tc-circuit-computers']=true,['production-science-pack']=true,['utility-science-pack']=true,['space-science-pack']=true}
  assert(#tech.prerequisites==4)
  for _,prerequisite in ipairs(tech.prerequisites) do assert(prerequisites[prerequisite] and data.raw.technology[prerequisite]); prerequisites[prerequisite]=nil end
  assert(next(prerequisites)==nil)
  local function assets(t)
    if type(t)~='table' then return end
    for key,v in pairs(t) do
      if key=='filename' or key=='icon' then assert(v:match('^__base__/') or v:match('^__core__/') or v:match('^__space%-age__/'))
      elseif type(v)=='table' then assets(v) end
    end
  end
  assets(r); assets(item); assets(tech)
end
log('TC_RADAR_DATA_OK')
-- An actual native radar type with an unsupported name must not be enrolled.
local third_party=table.deepcopy(native)
third_party.name='tc-fixture-unsupported-radar'
data:extend{third_party}
