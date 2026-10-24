-- Reuse the production renderer's cold preparing-state assertions, but resume
-- only after a real second peer joins, identically on every machine.
local base=require('tests.monitor_state_engine').new('preparing')
local registry=require('scripts.registry')
local M={}
local function state() return storage.tc_monitor_state end
local function publish()
  local x=state(); local root=registry.get(); local c=registry.record(x.computer); local peers={}
  for _,p in pairs(game.connected_players) do peers[#peers+1]=p.index end
  local groups={}
  for _,id in ipairs(root.monitors.order) do local g=root.monitors.groups[id]
    groups[#groups+1]={id=id,model=g.model,presented_revision=g.render and g.render.presented_revision}
  end
  local text=helpers.table_to_json({phase=x.phase,peers=peers,
    freeze_tick=x.tick,join_tick=x.join_tick,run=c.run_id,state=c.state,groups=groups})
  helpers.write_file('resource-policy-peer.json',text,false,0)
  for _,p in pairs(game.connected_players) do helpers.write_file('resource-policy-peer.json',text,false,p.index) end
end
function M.run() base.run() end
function M.on_load() base.on_load() end
function M.on_configuration_changed() error('not an upgrade fixture') end
function M.on_player_joined(e)
  if e.name~=defines.events.on_player_joined_game then return end
  local x=state(); local p=game.get_player(e.player_index); p.teleport({0,-2},game.surfaces[1]); p.zoom=0.7
  if #game.connected_players==1 then x.first=true; log('TC_MP_FIRST_JOINED') end
  if #game.connected_players==2 and x.phase=='frozen' then
    x.join_tick=game.tick; x.resume=true
    base.on_load() -- synchronized event, never a process-local resume decision
    log('TC_MP_SECOND_JOINED_AT_BOUNDARY render-preparing')
  end
end
function M.on_tick(e)
  local x=state()
  if not x.first then return end
  if x.phase=='frozen' and not x.resume then if e.tick%60==0 then publish() end; return end
  if x.phase=='done' then if e.tick%60==0 then publish() end; return end
  base.on_tick(e)
  if x.phase=='frozen' and not x.announced then
    x.announced=true; publish(); log('TC_MP_BOUNDARY_READY render-preparing')
  elseif x.phase=='done' then publish(); log('TC_MP_OK render-preparing') end
end
return M
