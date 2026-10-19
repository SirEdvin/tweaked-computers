-- The pinned engine's core/locale/en/info.json declares the default-mono font
-- family, but core does not declare a FontPrototype for it. Declare our own.
local styles=data.raw['gui-style'].default
assert(data.raw.font.default,'missing core default font')
assert(styles.textbox,'missing core textbox style')
data:extend{{type='font',name='tc-editor-mono',from='default-mono',size=14}}
styles.tc_editor_text={type='textbox_style',parent='textbox',font='tc-editor-mono',rich_text_setting='disabled'}
styles.tc_editor_button={type='button_style',parent='button',font='default-semibold',
  height=28,minimal_width=72,padding=4}
styles.tc_editor_frame={type='frame_style',parent='frame',padding=12,
  vertical_flow_style={type='vertical_flow_style',vertical_spacing=4}}
styles.tc_editor_tabs={type='tabbed_pane_style',parent='tabbed_pane',
  top_margin=0,
  tab_content_frame={type='frame_style',parent='tabbed_pane_frame',padding=8}}
styles.tc_editor_tab={type='tab_style',parent='tab',font='default-semibold',
  height=32,top_padding=6,bottom_padding=6,increase_height_when_selected=false,
  minimal_width=88,horizontal_align='center'}
data:extend{
  -- Context guards run after delivery: never swallow native transfers or latch
  -- Ctrl until release, even when the world interaction is ignored by Lua.
  {type='custom-input',name='tc-interact',key_sequence='CONTROL + mouse-button-1',
    action='lua',consuming='none',block_modifiers=false,include_selected_prototype=false}
}
