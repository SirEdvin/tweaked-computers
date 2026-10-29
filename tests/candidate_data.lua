-- Data-stage package/prototype contracts; not graphical resource-loading evidence.
local art=require('assets.sprites')
local defs=require('scripts.device-definitions')
local count=0
for _,kind in ipairs(defs.order) do
  local def=defs.devices[kind]; local entity=data.raw['electric-energy-interface'][def.name]
  local item=data.raw['item-with-tags'][def.name] or data.raw.item[def.name]
  assert(item.stack_size==((kind=='computer' or kind=='kv') and 1 or 50),'public device stack size '..kind)
  assert(item.type==((kind=='computer' or kind=='kv' or kind=='monitor') and 'item-with-tags' or 'item'))
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
assert(count==224)
local styles=data.raw['gui-style'].default
local inputs=data.raw['custom-input']
local interact=assert(inputs['tc-interact'])
assert(interact.key_sequence=='CONTROL + mouse-button-1' and not interact.alternative_key_sequence)
assert(not interact.linked_game_control or interact.linked_game_control=='')
assert(interact.action=='lua')
assert(interact.consuming=='none','world interaction must pass native Ctrl-click actions through')
assert(interact.block_modifiers==false,'world interaction must leave held Ctrl usable for subsequent shortcuts')
assert(not inputs['tc-open-editor'] and not inputs['tc-open-selected-computer'] and not inputs['tc-monitor-activate'])
for name in pairs(inputs) do
  if name:sub(1,3)=='tc-' then assert(name=='tc-interact' or name=='tc-rotate' or name=='tc-reverse-rotate','unexpected mod input '..name) end
end
for name,control in pairs({['tc-rotate']='rotate',['tc-reverse-rotate']='reverse-rotate'}) do
  local input=assert(inputs[name])
  assert(input.key_sequence=='' and input.linked_game_control==control)
  assert(input.action=='lua' and input.consuming=='none' and input.block_modifiers==false)
end
for name,kind in pairs({tc_editor_text='textbox_style',tc_editor_button='button_style',tc_editor_frame='frame_style',
  tc_editor_tabs='tabbed_pane_style',tc_editor_tab='tab_style',draggable_space_header='empty_widget_style'}) do
  assert(styles[name] and styles[name].type==kind,'incompatible editor style '..name)
end
-- Includes the font set dynamically on the runtime title label, not just styles.
for _,font in ipairs({'tc-editor-mono','default-semibold','default-large-semibold'}) do
  assert(data.raw.font[font],'undeclared runtime/editor font '..font)
end
local function check_style(style)
  if style.font then assert(data.raw.font[style.font],'undeclared font '..style.font) end
  if style.parent then assert(styles[style.parent],'undeclared parent style '..style.parent) end
  for _,value in pairs(style) do if type(value)=='table' then check_style(value) end end
end
for name,style in pairs(data.raw['gui-style'].default) do
  if type(name)=='string' and name:sub(1,3)=='tc_' and type(style)=='table' then check_style(style) end
end
for byte=0,255 do assert(data.raw.sprite['tc-glyph-'..byte].filename==art.glyphs[byte].filename) end
log('TC_CANDIDATE_DATA_OK 224 status frames; 256 independent glyphs; 7 actual body/item families; declared fonts')
