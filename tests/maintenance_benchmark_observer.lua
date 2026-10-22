-- Test-only forwarding observer, installed before production hook registration.
-- Profilers/functions remain ephemeral; only scalar workload state is saved.
local config=require('tests.maintenance_benchmark_config')
local scheduler=require('scripts.scheduler')
local registry=require('scripts.registry')
local M={}; local active=false; local profiles={}; local refusals=0
local phase_names={'scheduler','dispatch','advance_timers'}; local reported=false
function M.install()
  local attempt=scheduler.try_maintenance
  scheduler.try_maintenance=function(fn)
    local ok,result=attempt(fn)
    if active and not ok then refusals=refusals+1 end
    return ok,result
  end
  if not config.profile then return end
  local register=scheduler.register_phase
  scheduler.register_phase=function(phase,name,fn)
    phase_names[#phase_names+1]=phase..'/'..name
    register(phase,name,function(...)
      if not active then return fn(...) end
      local spent=registry.get().scheduler.maintenance_spent
      local p=game.create_profiler()
      local result=table.pack(pcall(fn,...))
      p.stop(); profiles[#profiles+1]={name=phase..'/'..name,profiler=p,work=registry.get().scheduler.maintenance_spent-spent}
      if not result[1] then error(result[2],0) end
      return table.unpack(result,2,result.n)
    end)
  end
  for _,name in ipairs({'dispatch','advance_timers'}) do
    local fn=scheduler[name]
    scheduler[name]=function(...)
      if not active then return fn(...) end
      local spent=registry.get().scheduler.maintenance_spent
      local p=game.create_profiler()
      local result=table.pack(pcall(fn,...))
      p.stop(); profiles[#profiles+1]={name=name,profiler=p,work=registry.get().scheduler.maintenance_spent-spent}
      if not result[1] then error(result[2],0) end
      return table.unpack(result,2,result.n)
    end
  end
end
function M.begin() profiles={}; refusals=0; active=true end
function M.finish(tick,total)
  active=false
  log({'','TC_MB_CPU tick=',tick,' phase=scheduler ',total})
  if config.profile then
    if not reported then log('TC_MB_PHASES '..helpers.table_to_json(phase_names)); reported=true end
    for _,entry in ipairs(profiles) do
      log({'','TC_MB_CPU tick=',tick,' phase=',entry.name,' ',entry.profiler})
      log('TC_MB_WORK tick='..tick..' phase='..entry.name..' units='..entry.work)
    end
  end
  return refusals
end
return M
