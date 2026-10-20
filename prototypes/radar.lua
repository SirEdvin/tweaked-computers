-- Native references only; no extracted Factorio graphics are distributed.
if not mods['space-age'] then return end
local name='tc-interplanetary-radar'
local radar=table.deepcopy(data.raw.radar.radar)
radar.name=name
radar.minable={mining_time=0.5,result=name}
radar.fast_replaceable_group=nil
radar.next_upgrade=nil
radar.energy_usage='1MW'
-- Space Age adds this to vanilla radar later in base-data-updates.lua. Keep
-- the pinned native freezing/heating constraint on this separately named copy.
radar.heating_energy='300kW'
radar.collision_box={{-2.2,-2.2},{2.2,2.2}}
radar.selection_box={{-2.5,-2.5},{2.5,2.5}}
local function vector(v)
  if v.x then v.x=v.x*1.5; v.y=v.y*1.5
  else v[1]=v[1]*1.5; v[2]=v[2]*1.5 end
end
local function graphics(t)
  if type(t)~='table' then return end
  if t.filename or t.filenames or t.stripes then t.scale=(t.scale or 1)*1.5 end
  if t.shift then vector(t.shift) end
  for k,v in pairs(t) do if k~='shift' and type(v)=='table' then graphics(v) end end
end
for _,key in ipairs({'pictures','integration_patch','water_reflection','frozen_patch'}) do graphics(radar[key]) end
-- Connector sprites and every native wire/shadow contact use the same transform.
graphics(radar.circuit_connector)
local function contacts(t)
  if type(t)~='table' then return end
  for key,value in pairs(t) do
    if type(value)=='table' then
      if (key=='red' or key=='green' or key=='copper') and (value.x or type(value[1])=='number') then vector(value)
      else contacts(value) end
    end
  end
end
contacts(radar.circuit_connector)
local icons={{icon='__base__/graphics/icons/radar.png',icon_size=64},
  {icon='__base__/graphics/icons/space-science-pack.png',icon_size=64,scale=0.25,shift={8,8}}}
radar.icon=nil; radar.icons=table.deepcopy(icons)
local item=table.deepcopy(data.raw.item.radar)
item.name=name; item.icon=nil; item.icons=table.deepcopy(icons); item.place_result=name; item.order='d[radar]-b[interplanetary]'
data:extend{radar,item,
  {type='recipe',name=name,enabled=false,energy_required=10,
    ingredients={{type='item',name='radar',amount=1},{type='item',name='steel-plate',amount=20},
      {type='item',name='processing-unit',amount=20},{type='item',name='low-density-structure',amount=10}},
    results={{type='item',name=name,amount=1}}},
  {type='technology',name=name,icons=table.deepcopy(icons),
    prerequisites={'tc-circuit-computers','production-science-pack','utility-science-pack','space-science-pack'},
    effects={{type='unlock-recipe',recipe=name}},
    unit={count=500,time=30,ingredients={{'automation-science-pack',1},{'logistic-science-pack',1},
      {'chemical-science-pack',1},{'production-science-pack',1},{'utility-science-pack',1},{'space-science-pack',1}}}}}
