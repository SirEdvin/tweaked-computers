-- One explicit world gesture; never hook normal open to create a workspace.
local registry=require('scripts.registry')
local defs=require('scripts.device-definitions')
local editor=require('scripts.ui.editor')
local monitor=require('scripts.services.monitor')
local M={}
function M.on_input(event)
  if event.input_name~='tc-interact' or event.in_gui or event.element then return end
  local player=game.get_player(event.player_index)
  if not player or not player.valid or player.opened then return end
  local cursor=player.cursor_stack
  if (cursor and cursor.valid_for_read) or player.cursor_ghost then return end
  local group=player.permission_group
  if group and not group.allows_action(defines.input_action.custom_input) then return end
  local rec=registry.by_entity(player.selected)
  if rec and rec.kind=='computer' then return editor.open(player,rec.id) end
  -- Position-based monitor hit testing takes precedence over empty-ground
  -- recovery, even when selection priority does not identify a monitor tile.
  if monitor.activate(event) then return true end
  if not player.selected then editor.open_recovery(player); return true end
end
function M.on_opened(event)
  local entity=event.entity
  if not entity or not entity.valid then return end
  -- Native combinator shells and role pads are implementation details, not
  -- alternate configuration UIs. Never replace a different already-open GUI.
  if not defs.by_name[entity.name] and not defs.port_role(entity.name) and not defs.power_kind(entity.name) then return end
  local player=game.get_player(event.player_index)
  if player and player.valid and player.opened==entity then player.opened=nil end
end
return M
