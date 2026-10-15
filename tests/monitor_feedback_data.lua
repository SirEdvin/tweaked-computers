-- Narrow RD4 prototype contract; the actual engine loads the authored PNG.
local defs=require('__tweaked-computers__.scripts.device-definitions')
local fill=assert(data.raw.sprite['tc-monitor-fill'])
assert(fill.filename=='__tweaked-computers__/assets/glyphs/pixel.png' and fill.width==1 and fill.height==1)
local body=assert(data.raw['constant-combinator'][defs.devices.monitor.entity_name])
assert(body.tile_width==1 and body.tile_height==1 and body.selection_priority==40)
for _,direction in ipairs({'north','east','south','west'}) do
  assert(body.sprites[direction].layers[2].filename:find('monitor-'..direction..'-body.png',1,true))
end
log('TC_RD4_FILL_AND_MONITOR_DATA_OK')
