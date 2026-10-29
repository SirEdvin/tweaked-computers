-- Test-only observers installed before production captures phase/backend hooks.

local M=require('tests.monitor_demand_counters')
local count=M.count
local native=rendering
rendering=setmetatable({draw_sprite=function(options)
  count(type(options.sprite)=='string' and options.sprite:match('^tc%-status%-') and 'art_create' or 'native_create')
  return native.draw_sprite(options)
end},{__index=function(_,key) return native[key] end})

local lifecycle=require('scripts.lifecycle')
if lifecycle.observe_monitor then
  local observe=lifecycle.observe_monitor
  lifecycle.observe_monitor=function(...) count('observation'); return observe(...) end
end
for _,name in ipairs({'connector','has_power'}) do
  local original=lifecycle[name]
  lifecycle[name]=function(rec,...)
    if type(rec)=='table' and rec.kind=='monitor' then count(name) end
    return original(rec,...)
  end
end
local presentation=require('scripts.monitor-presentation')
local bind=presentation.bind
presentation.bind=function(authority)
  local original=authority.available
  authority.available=function(g,...)
    count('presentation_proof_requests'); return original(g,...)
  end
  return bind(authority)
end
local install=presentation.install
presentation.install=function(backend)
  for _,name in ipairs({'frame','cell','cursor'}) do
    local original=backend[name]
    backend[name]=function(...) count(name); return original(...) end
  end
  local destroy=backend.destroy
  backend.destroy=function(o)
    local valid=o and o.valid
    destroy(o)
    if valid and not o.valid then count('native_retire') end
  end
  local clear=backend.clear_cell
  backend.clear_cell=function(c,staged)
    count('clear_cell')
    local b,g=c and c.background,c and c.glyph
    local bv,gv=b and b.valid,g and g.valid
    clear(c,staged)
    if bv and not b.valid then count('native_retire') end
    if gv and not g.valid then count('native_retire') end
  end
  return install(backend)
end
local model=require('scripts.monitor-model'); local capture=model.capture
model.capture=function(...) count('capture'); return capture(...) end
return M
