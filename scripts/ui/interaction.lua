-- One explicit world gesture; never hook normal open to create a workspace.
local registry=require('scripts.registry')
local defs=require('scripts.device-definitions')
local editor=require('scripts.ui.editor')
local monitor=require('scripts.services.monitor')
local inspector=require('scripts.ui.peripheral-inspector')
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
  local kind=defs.by_name[entity.name]
  if kind and kind~='computer' and not inspector.supports(kind) then return end
  if not kind and not defs.port_role(entity.name) and not defs.power_kind(entity.name) then return end
  local player=game.get_player(event.player_index)
  if player and player.valid and player.opened==entity then
    player.opened=nil
    local rec,role=registry.by_entity(entity)
    if rec and role=='body' and rec.kind~='computer' then
      editor.on_player_unavailable(event) -- retires only the session, retains drafts
      inspector.open(player,rec.id)
    end
  end
end
function M.on_rotate(event)
  if (event.input_name~='tc-rotate' and event.input_name~='tc-reverse-rotate') or event.in_gui or event.element then return end
  local player=game.get_player(event.player_index)
  if not player or not player.valid or player.opened then return end
  local cursor=player.cursor_stack
  if (cursor and cursor.valid_for_read) or player.cursor_ghost then return end
  local group=player.permission_group
  if group and (not group.allows_action(defines.input_action.custom_input)
    or not group.allows_action(defines.input_action.rotate_entity)) then return end
  local rec,role=registry.by_entity(player.selected)
  if not rec or role~='body' or rec.layout_version~=2 or not rec.body.valid or not rec.body.rotatable or rec.body.operable
    or rec.body.force~=player.force or rec.body.surface~=player.surface or not player.can_reach_entity(rec.body) then return end
  -- The engine also refuses scripted rotate on an inoperable entity. Permit
  -- only this synchronous native call, then restore the closed shell even if a
  -- raised event fails. No input/save can interleave with this callback. The
  -- existing opened handler still refuses native shell GUIs. by_player raises
  -- the production lifecycle event exactly once; do not synthesize another.
  local body=rec.body; body.operable=true
  local ok,result=pcall(body.rotate,{by_player=player.index,reverse=event.input_name=='tc-reverse-rotate'})
  if body.valid then body.operable=false end
  if not ok then error(result,0) end
  return result
end
return M
