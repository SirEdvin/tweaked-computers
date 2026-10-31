-- Test-only diagnostics. Timing lane installs no forwarding wrappers.
local config=require('tests.scheduling_benchmark_config')
local M={active=false,values={},samples=0}
local phase='outside'
local timers={}
function M.count(key,n)
  if M.active then
    key=phase..'/'..key; M.values[key]=(M.values[key] or 0)+(n or 1)
  end
end
function M.install()
  if config.lane=='timing' then return end
  local scheduler=require('scripts.scheduler')
  local register=scheduler.register_phase
  scheduler.register_phase=function(group,name,fn)
    local key=group..'/'..name
    register(group,name,function(...)
      if not M.active then return fn(...) end
      local previous=phase; phase=key
      local p=config.lane=='profile' and helpers.create_profiler()
      local result=table.pack(pcall(fn,...))
      if p then p.stop(); timers[key]=p end
      M.count('hook'); phase=previous
      if not result[1] then error(result[2],0) end
      return table.unpack(result,2,result.n)
    end)
  end
  if config.lane=='profile' then
    for _,name in ipairs({'dispatch','advance_timers'}) do
      local fn=scheduler[name]
      scheduler[name]=function(...)
        if not M.active then return fn(...) end
        local p=helpers.create_profiler(); local result=table.pack(pcall(fn,...)); p.stop()
        timers['scheduler/'..name].add(p)
        if not result[1] then error(result[2],0) end
        return table.unpack(result,2,result.n)
      end
    end
  end
  if config.lane=='structure' then
    -- Install before dependent modules capture these functions.
    for _,entry in ipairs({
      {'scripts.scheduler',{'dispatch','advance_timers'}},
      {'scripts.registry',{'record'}},
      {'scripts.lifecycle',{'has_power','observe_monitor','connector'}},
      {'scripts.network',{'discover','real_edges','validate_witness'}},
      {'scripts.services.peripheral',{'reconcile_one','check_outputs','authority'}},
      {'scripts.services.kv',{'reclaim'}},
      {'scripts.monitor-model',{'capture'}},
    }) do
      local module=require(entry[1])
      for _,name in ipairs(entry[2]) do
        local fn=assert(module[name],entry[1]..'.'..name)
        module[name]=function(...) M.count(entry[1]..':'..name); return fn(...) end
      end
    end
    local lifecycle=require('scripts.lifecycle')
    if lifecycle.sample_power then
      local sample=lifecycle.sample_power
      lifecycle.sample_power=function(...) M.count('scripts.lifecycle:sample_power'); return sample(...) end
    else assert(type(lifecycle.available)=='function','unsupported lifecycle observer layout') end
    local native=rendering
    rendering=setmetatable({draw_sprite=function(options)
      M.count(options.sprite:match('^tc%-status%-') and 'art:create' or 'render:create')
      return native.draw_sprite(options)
    end},{__index=function(_,key) return native[key] end})
  end
end
function M.begin()
  M.active=true; timers={}; phase='scheduler'
  if config.lane=='profile' then
    timers['scheduler/dispatch']=helpers.create_profiler(true)
    timers['scheduler/advance_timers']=helpers.create_profiler(true)
  end
end
function M.finish(tick,total)
  M.active=false; M.samples=M.samples+1
  if config.lane=='profile' then
    log({'','TC_SB_CPU tick=',tick,' phase=scheduler ',total})
    local names={}; for name in pairs(timers) do names[#names+1]=name end; table.sort(names)
    for _,name in ipairs(names) do log({'','TC_SB_CPU tick=',tick,' phase=',name,' ',timers[name]}) end
  end
end
function M.done()
  if config.lane=='structure' then log('TC_SB_COUNTERS '..helpers.table_to_json{samples=M.samples,values=M.values}) end
end
return M
