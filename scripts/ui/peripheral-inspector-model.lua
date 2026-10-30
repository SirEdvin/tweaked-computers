-- Host-only, detached read models. No guest authority, writes or subscriptions.
local registry=require('scripts.registry')
local errors=require('scripts.runtime.errors')
local lifecycle=require('scripts.lifecycle')
local kv=require('scripts.services.kv')
local configurator=require('scripts.services.configurator')
local logic=require('scripts.services.logic')
local monitor=require('scripts.services.monitor')
local scheduler=require('scripts.scheduler')
local M={version=4}
local kinds={kv=true,monitor=true,logic=true,configurator=true,recipe_searcher=true,factoriopedia_interface=true,production_statistics=true}
function M.supports(kind) return kinds[kind]==true end
function M.authorized(player,rec)
  if not player or not player.valid or not rec or not kinds[rec.kind] or not rec.body.valid then return false end
  local bound,role=registry.by_entity(rec.body)
  if bound~=rec or role~='body' or rec.body.force.index~=rec.force_index
    or rec.body.surface.index~=rec.surface_index or player.force.index~=rec.force_index
    or player.surface.index~=rec.surface_index or not player.can_reach_entity(rec.body) then return false end
  local group=player.permission_group
  return not group or (group.allows_action(defines.input_action.open_gui)
    and group.allows_action(defines.input_action.gui_click)
    and group.allows_action(defines.input_action.gui_text_changed))
end
function M.session(index)
  local root=registry.get()
  local s=registry.supported(root) and type(root.peripheral_inspectors)=='table' and root.peripheral_inspectors[index]
  return type(s)=='table' and s or nil
end
function M.open(player,id)
  local root=registry.get(); local rec=registry.record(id)
  if not registry.supported(root) or not M.authorized(player,rec) then errors.raise('E_UNREACHABLE','peripheral is not accessible') end
  root.peripheral_inspectors=root.peripheral_inspectors or {}
  local s={version=M.version,id=id,unit=rec.body.unit_number,generation=rec.generation,
    token=registry.sequence(),pending=true,page=1,field_page=1,value_page=1}
  root.peripheral_inspectors[player.index]=s
  return s
end
function M.current(player,token)
  local s=M.session(player.index); local rec=s and registry.record(s.id)
  if not s or s.version~=M.version or s.token~=token or not M.authorized(player,rec)
    or rec.generation~=s.generation or rec.body.unit_number~=s.unit then
    errors.raise('E_UNREACHABLE','inspector identity or interaction authority changed')
  end
  return rec,s
end
function M.close(index,token)
  local s=M.session(index)
  if s and (not token or s.token==token) then registry.get().peripheral_inspectors[index]=nil end
end
-- ASCII-only reversible byte strings: quotes, escaped quotes/backslashes, and
-- exactly two uppercase hex digits after \x for every non-printable/high byte.
function M.escape(value,spend)
  if spend then spend(#value*5+2) end
  return '"'..value:gsub('[%z\1-\31\127-\255\\"%[%]]',function(c)
    if c=='\\' or c=='"' then return '\\'..c end
    return string.format('\\x%02X',string.byte(c))
  end)..'"'
end
function M.read(rec,tick,spend,session)
  spend(64)
  local powered=lifecycle.available(rec)
  local candidate={tick=tick,name=rec.id,kind=rec.kind,powered=powered}
  if rec.kind=='monitor' then
    candidate.details=monitor.inspect(rec,tick,spend); candidate.name=candidate.details.name
  elseif powered then
    if rec.kind=='kv' then candidate.details=kv.inspect(rec,tick,spend)
    elseif rec.kind=='logic' then
      if not session then candidate.details=logic.inspect(rec,tick,spend)
      else
        -- Native signal panels are independent observations. Never hold the
        -- output or one input hostage to an unaffordable query on another wire.
        local before=session.snapshot and session.snapshot.details or {}
        local d={tick=tick,connected={},errors={},output=logic.inspect_output(rec,spend),output_tick=tick}
        for _,wire in ipairs({'red','green'}) do
          d[wire]=before[wire]; d[wire..'_tick']=before[wire..'_tick']
          d.connected[wire]=before.connected and before.connected[wire]
          d.errors[wire]=before.errors and before.errors[wire]
        end
        local wire=session.logic_next=='green' and 'green' or 'red'
        session.logic_next=wire=='red' and 'green' or 'red'
        session.logic_partial=nil -- Retire the old unpublished pair on gameplay.
        local ok,admitted,sample=pcall(scheduler.try_maintenance,function()
          return logic.inspect_input(rec,wire,tick,spend)
        end)
        if ok and admitted then
          d[wire]=sample.values; d[wire..'_tick']=sample.tick
          d.connected[wire]=sample.connected; d.errors[wire]=nil
        else
          d.errors[wire]=ok and 'E_BUSY' or type(admitted)=='table' and admitted.code or 'E_ENGINE'
        end
        candidate.details=d
      end
    elseif rec.kind=='configurator' then candidate.details=configurator.inspect(rec,tick,spend) end
  end
  if session and not powered then session.logic_partial=nil; session.logic_next=nil end
  return candidate
end
return M
