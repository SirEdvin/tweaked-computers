-- Test-only contention observer. Player/GUI doubles are not client evidence;
-- provider reads, maintenance admission, programs and world rendering are real.
local config=require('tests.peripheral_inspector_contention_config')
local inspector=require('scripts.ui.peripheral-inspector')
local model=require('scripts.ui.peripheral-inspector-model')
local players=require('tests.editor_contract')
local registry=require('scripts.registry')
local limits=require('scripts.runtime.limits')
local M={}; local viewers; local real; local calls=0; local stopped
local read=model.read
model.read=function(...) calls=calls+1; return read(...) end
function M.begin(tick)
  real=game
  local scene=storage.tc_animation; local tile=registry.record(scene.walls[1][1])
  if not viewers then
    viewers={}
    for i=1,config.viewers do
      local p=players.player(9000+i,tile.body); viewers[i]=p
      inspector.open(p,tile.id)
    end
  end
  if scene.steps>=600 and not stopped then
    local minimum=math.huge
    for _,p in ipairs(viewers) do
      local s=model.session(p.index); assert(s and s.snapshot and not s.snapshot.details.name:find('pending'))
      minimum=math.min(minimum,s.snapshot.tick)
      inspector.close(p)
    end
    stopped=calls
    log('TC_INSPECTOR_CONTENTION viewers='..#viewers..' read_attempts='..calls..' minimum_snapshot_tick='..minimum..' bounded_requests=true')
  end
  game=setmetatable({connected_players=viewers,get_player=function(index) return viewers[index-9000] end},
    {__index=function(_,key) return real[key] end})
  if not stopped and tick%15==0 then
    for _,p in ipairs(viewers) do
      local f=p.gui.screen[inspector.frame_name]
      assert(not f.actions,'automatic inspector polling must not need Refresh controls')
    end
  end
end
function M.finish()
  local root=registry.get()
  assert(root.scheduler.maintenance_spent<=limits.maintenance_work_per_tick)
  assert(root.scheduler.maintenance_spent+root.ledger.total<=limits.host_work_per_tick)
  if stopped then assert(calls==stopped,'closed inspector polled a provider') end
  game=real
end
return M
