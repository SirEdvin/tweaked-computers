local art=require('assets.sprites')
local names={'north','east','south','west'}
local entity=data.raw['electric-energy-interface']['tc-monitor']
entity.pictures={}
for _,direction in ipairs(names) do
  local a=art.devices.monitor[direction]
  entity.pictures[direction]={layers={table.deepcopy(a.shadow),table.deepcopy(a.body)}}
end
entity.icon=art.devices.monitor.icon; entity.icon_size=64
entity.localised_description={'entity-description.tc-monitor'}
local item=data.raw['item-with-tags']['tc-monitor']; item.icon=entity.icon; item.icon_size=64
local sprites={{type='sprite',name='tc-monitor-fill',
  filename='__tweaked-computers__/assets/glyphs/pixel.png',width=1,height=1}}
for byte=0,255 do
  local sprite=table.deepcopy(art.glyphs[byte]); sprite.type='sprite'; sprite.name='tc-glyph-'..byte
  sprites[#sprites+1]=sprite
end
data:extend(sprites)
data:extend{{type='custom-input',name='tc-monitor-activate',key_sequence='CONTROL + mouse-button-1',
  action='lua',consuming='game-only',block_modifiers=true,include_selected_prototype=false}}
