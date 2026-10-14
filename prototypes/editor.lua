-- Standard core font, explicitly checked in the data stage (no guessed mono font).
local styles=data.raw['gui-style'].default
assert(data.raw.font.default,'missing core default font')
assert(styles.textbox,'missing core textbox style')
styles.tc_editor_text={type='textbox_style',parent='textbox',font='default',rich_text_setting='disabled'}
data:extend{
  {type='custom-input',name='tc-open-editor',key_sequence='CONTROL + SHIFT + E',consuming='none'},
  {type='custom-input',name='tc-open-selected-computer',key_sequence='',linked_game_control='open-gui',consuming='none'}
}
