-- Data-stage contract for the actual connection points installed on prototypes.
local defs=require('__tweaked-computers__.scripts.device-definitions')
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
for _,kind in ipairs(defs.order) do
  local def=defs.devices[kind]; local shell=data.raw['constant-combinator'][def.entity_name]
  assert(def.watts==nil and shell.energy_source==nil,'custom shell consumes electricity')
  for _,name in ipairs({def.name,def.power_name}) do
    local legacy=data.raw['electric-energy-interface'][name]
    assert(legacy.energy_usage=='0W' and legacy.energy_production=='0W')
    assert(legacy.energy_source.input_flow_limit=='0W' and legacy.energy_source.drain=='0W')
    assert(legacy.energy_source.render_no_power_icon==false and legacy.energy_source.render_no_network_icon==false)
  end
  assert(equal(shell.circuit_wire_connection_points,defs.points(kind,'network',false)))
  for _,role in ipairs(def.roles) do if role~='network' then
    local pad=data.raw['constant-combinator'][defs.pad_name(kind,role)]
    assert(equal(pad.circuit_wire_connection_points,defs.points(kind,role,true)))
    assert(equal(pad.selection_box,defs.pad_box))
  end end
  for _,d in ipairs({0,4,8,12}) do for _,color in ipairs({'red','green'}) do
    local x,y=defs.contact(kind,'network',color,d)
    if kind=='monitor' then assert(math.max(math.abs(x),math.abs(y))==0.48,'monitor contact must be on its bezel') end
  end end
  assert(data.raw['electric-energy-interface'][def.name],'legacy prototype required for upgrade')
  assert(data.raw['item-with-tags'][def.name] and data.raw['item-with-tags'][def.name].place_result==def.entity_name
    or data.raw.item[def.name] and data.raw.item[def.name].place_result==def.entity_name)
end
