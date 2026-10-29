require('__tweaked-computers__.tests.production_statistics_data')
for i=1,1030 do
  data:extend{{type='item',name='tc-stat-pressure-'..i,icon='__base__/graphics/icons/iron-plate.png',icon_size=64,
    stack_size=50,auto_recycle=false}}
end
