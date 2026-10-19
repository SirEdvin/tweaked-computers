-- Negative authority/ingress checks with real bodies and explicit player doubles.
-- Positive R/Shift-R delivery requires the licensed client, not this contract.
local interaction=require('scripts.ui.interaction')
local registry=require('scripts.registry')
local M={}
function M.run(computer_id,logic_id,check_registration)
  if check_registration~=false then
    assert(script.get_event_handler('tc-rotate')==interaction.on_rotate)
    assert(script.get_event_handler('tc-reverse-rotate')==interaction.on_rotate)
  end
  local rec=assert(registry.record(computer_id)); local body=rec.body
  local before=body.direction; local real=game; local checks=0
  local function denied(change,extra)
    local p={valid=true,index=9001,selected=body,force=body.force,surface=body.surface,
      cursor_stack={valid_for_read=false},can_reach_entity=function() return true end}
    change(p)
    local event={player_index=p.index,input_name='tc-rotate',tick=real.tick}
    for k,v in pairs(extra or {}) do event[k]=v end
    game={get_player=function() return p end}
    local ok,result=pcall(interaction.on_rotate,event)
    game=real
    assert(ok and result==nil,'rotation refusal reached native mutation')
    assert(body.valid and not body.operable and body.direction==before and rec.direction==before)
    checks=checks+1
  end
  denied(function() end,{input_name='tc-interact'})
  denied(function() end,{in_gui=true})
  denied(function() end,{element={}})
  denied(function(p) p.valid=false end)
  denied(function(p) p.opened={} end)
  denied(function(p) p.cursor_stack.valid_for_read=true end)
  denied(function(p) p.cursor_ghost={} end)
  for _,blocked in ipairs({defines.input_action.custom_input,defines.input_action.rotate_entity}) do
    denied(function(p) p.permission_group={allows_action=function(action) return action~=blocked end} end)
  end
  denied(function(p) p.selected=nil end)
  denied(function(p) p.selected=registry.record(logic_id).children.input end)
  denied(function(p) p.force={} end)
  denied(function(p) p.surface={} end)
  denied(function(p) p.can_reach_entity=function() return false end end)
  local lookup=registry.by_entity
  local proxy={valid=true,rotatable=true,operable=false,force=body.force,surface=body.surface}
  local player={valid=true,index=9001,selected=proxy,force=body.force,surface=body.surface,
    cursor_stack={valid_for_read=false},can_reach_entity=function() return true end}
  local calls=0; local failure={fixture='native rotation failure'}
  local ok,problem=pcall(function()
    registry.by_entity=function(e) if e==proxy then return {body=proxy,layout_version=2},'body' end; return lookup(e) end
    game={get_player=function() return player end}
    for _,name in ipairs({'tc-rotate','tc-reverse-rotate'}) do
      proxy.rotate=function(args)
        assert(proxy.operable and args.by_player==player.index and args.reverse==(name=='tc-reverse-rotate'))
        calls=calls+1; return true
      end
      assert(interaction.on_rotate{player_index=player.index,input_name=name})
      assert(not proxy.operable)
    end
    proxy.rotate=function() assert(proxy.operable); error(failure,0) end
    local accepted,e=pcall(interaction.on_rotate,{player_index=player.index,input_name='tc-rotate'})
    assert(not accepted and e==failure and not proxy.operable,'failed native entry left an operable shell')
    proxy.operable=true; proxy.rotate=function() error('already-operable shell must use vanilla rotation') end
    assert(interaction.on_rotate{player_index=player.index,input_name='tc-rotate'}==nil)
  end)
  game=real; registry.by_entity=lookup
  assert(ok,problem); assert(calls==2)
  log('TC_ROTATION_REFUSALS_OK count='..checks..' real-bodies mocked-player-ingress')
  log('TC_ROTATION_ENTRY_RESTORATION_OK mocked-native-success-reverse-error-no-double')
end
return M
