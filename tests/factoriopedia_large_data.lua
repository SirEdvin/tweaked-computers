require('__tweaked-computers__.tests.factoriopedia_data')
-- Genuine native catalogues, independently beyond the existing shared Data limit.
for i=1,1100 do
  local name=string.format('tc-fp-large-%04d',i)
  data:extend{{type='item',name=name,icon='__base__/graphics/icons/iron-plate.png',icon_size=64,
      stack_size=100,weight=1000,auto_recycle=false},
    {type='fluid',name=name,icon='__base__/graphics/icons/fluid/water.png',icon_size=64,
      default_temperature=15,auto_barrel=false,base_color={0,0,1},flow_color={0,0,1}}}
end
