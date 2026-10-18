-- Explicit-clock unit contracts, not production tick/latency measurements.
local registry=require('scripts.registry')
local scheduler=require('scripts.scheduler')
local monitor=require('scripts.services.monitor')
local limits=require('scripts.runtime.limits')
local M={}
local function nop() end
function M.run()
  local root=registry.initialize(); local t=game.tick
  local first=scheduler.maintenance(root,t)
  scheduler.request_render_work(root,t,160000,nop)
  assert(root.scheduler.render_reserved_work==60000,'same-tick demand changed frozen reservation')
  first(140000)
  assert(not scheduler.try_maintenance(function() first(1) end))
  assert(root.scheduler.maintenance_spent==140000)
  local boosted=scheduler.maintenance(root,t+1)
  assert(root.scheduler.render_reserved_work==160000)
  boosted(40000)
  assert(not scheduler.try_maintenance(function() boosted(1) end))
  scheduler.request_render_work(root,t+1,0,nop)
  assert(root.scheduler.render_reserved_work==160000 and root.scheduler.maintenance_spent==40000)
  scheduler.request_render_work(root,t+1,160000,nop)
  local normal=scheduler.maintenance(root,t+2)
  assert(root.scheduler.render_reserved_work==60000,'continuous demand eliminated baseline service')
  normal(140000)
  scheduler.maintenance(root,t+3)
  assert(root.scheduler.render_reserved_work==160000)
  local old=scheduler.maintenance(root,t+3,true); old(200000)
  local tick,spent,reserved=root.scheduler.maintenance_tick,root.scheduler.maintenance_spent,root.scheduler.render_reserved_work
  local ok=pcall(scheduler.request_render_work,root,t+3,160001,nop)
  assert(not ok and root.scheduler.maintenance_tick==tick and root.scheduler.maintenance_spent==spent and root.scheduler.render_reserved_work==reserved)
  assert(not scheduler.try_maintenance(function() scheduler.maintenance(root,t+3,true)(1) end))
  root.scheduler.render_demand_work=160001
  scheduler.tick(t+4)
  assert(root.scheduler.maintenance_tick==tick and root.scheduler.maintenance_spent==spent,'malformed demand was repaired or renewed')
  root.scheduler.render_demand_work=160000
  local fake={}; for y=1,3 do for x=1,3 do if x~=2 or y~=2 then
    fake[#fake+1]={id=x..'-'..y,position={x=x,y=y},direction=0,force_index=1,surface_index=1}
  end end end
  local result=monitor.partition(fake); local count=0; for _,g in ipairs(result) do count=count+#g.members end
  assert(count==8 and #result==4)
  log('TC_MONITOR_BUDGET_CONTRACT_OK')
end
return M
