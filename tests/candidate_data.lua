-- Data-stage package/prototype contracts; not graphical resource-loading evidence.
local art=require('assets.sprites')
local defs=require('scripts.device-definitions')
local count=0
for _,kind in ipairs(defs.order) do
  local def=defs.devices[kind]; local entity=data.raw['electric-energy-interface'][def.name]
  local item=data.raw['item-with-tags'][def.name] or data.raw.item[def.name]
  assert(entity.icon==art.devices[kind].icon and item.icon==entity.icon)
  for _,direction in ipairs({'north','east','south','west'}) do
    local images=art.devices[kind][direction]; local layers=entity.pictures[direction].layers
    assert(#layers==2 and layers[1].filename==images.shadow.filename and layers[1].draw_as_shadow)
    assert(layers[2].filename==images.body.filename and layers[2].scale==0.5)
    for _,state in ipairs({'off','unpowered','powered','fault','blinking'}) do
      local source=images.states[state]
      for frame=0,(source.frame_count or 1)-1 do
        local sprite=assert(data.raw.sprite['tc-status-'..kind..'-'..direction..'-'..state..'-'..frame])
        assert(sprite.filename==source.filename and sprite.x==frame*source.width and sprite.width==source.width)
        assert(not sprite.frame_count and not sprite.animation_speed); count=count+1
      end
    end
  end
end
assert(count==160)
for name,style in pairs(data.raw['gui-style'].default) do
  if type(name)=='string' and name:sub(1,3)=='tc_' and type(style)=='table' and style.font then assert(data.raw.font[style.font],'undeclared font '..style.font) end
end
for byte=0,255 do assert(data.raw.sprite['tc-glyph-'..byte].filename==art.glyphs[byte].filename) end
log('TC_CANDIDATE_DATA_OK 160 status frames; 256 independent glyphs; 5 actual body/item families; declared fonts')
