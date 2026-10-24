require('__tweaked-computers__.tests.recipe_searcher_data')
for i=1,1100 do
  data:extend{{type='virtual-signal',name=string.format('tc-inventory-%04d',i),icon='__base__/graphics/icons/iron-plate.png',icon_size=64,subgroup='virtual-signal-special',order=string.format('z-%04d',i)}}
end
local long='tc-inventory-'..string.rep('long-name-',12)
data:extend{{type='virtual-signal',name=long,icon='__base__/graphics/icons/iron-plate.png',icon_size=64,subgroup='virtual-signal-special',order='zz'}}
