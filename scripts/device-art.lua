-- Bounded host-only status presentation. Native prototypes own body/shadow art.
local registry=require('scripts.registry')
local scheduler=require('scripts.scheduler')
local lifecycle=require('scripts.lifecycle')
local M={}
local directions={[0]='north',[4]='east',[8]='south',[12]='west'}
local function clear(rec)
  if rec.status_art and rec.status_art.object.valid then rec.status_art.object.destroy() end
  rec.status_art=nil
end
local function refresh(rec,tick,spend)
  if rec.native_carrier or rec.physical_version~=1 or not rec.body.valid then return end
  local state='powered'
  if rec.physical_error or rec.status=='faulted' or rec.mining_guard=='unsupported-database' then state='fault'
  elseif not lifecycle.available(rec) then state='fault'
  elseif rec.kind=='computer' then state=rec.status=='running' and 'blinking' or 'off' end
  local direction=directions[rec.kind=='monitor' and rec.direction or rec.body.direction]
  if direction then
    local frame=state=='blinking' and math.floor(tick/10)%4 or 0
    local name='tc-status-'..rec.kind..'-'..direction..'-'..state..'-'..frame
    local old=rec.status_art
    if not old or not old.object.valid or old.name~=name then
      spend(32)
      -- Allocate before retiring the previous object; no empty stale handle.
      local object=rendering.draw_sprite{sprite=name,surface=rec.body.surface,
        target=rec.body,render_layer='higher-object-above'}
      clear(rec); rec.status_art={name=name,object=object}
    end
    rec.monitor_art_dirty=nil
    if state=='blinking' then return tick-tick%10+10 end
  end
end
function M.tick(tick,spend)
  local root=registry.get(); local valid,item=pcall(registry.maintenance_next,'art')
  if not valid then root.scheduling_diagnostic=item; return end
  local clock=registry.maintenance_clock('art')
  if clock.initialized~=1 or not item or item.tick>tick then return end
  local retry={}
  for _=1,128 do
    item=registry.maintenance_next('art'); if not item or item.tick>tick then break end
    local size,work=#clock.deadlines,16
    while size>0 do work=work+16; size=math.floor(size/2) end
    if not scheduler.try_maintenance(function() spend(work) end) then break end
    registry.maintenance_remove('art',item.id)
    local rec=registry.record(item.id)
    if rec==item.owner and rec.generation==item.generation then
      local ok,admitted,deadline=pcall(scheduler.try_maintenance,function() return refresh(rec,tick,spend) end)
      if not ok or not admitted then retry[#retry+1]=item end
      if not ok then
        for _,pending in ipairs(retry) do registry.maintenance_set('art',pending.id,pending.owner,pending.tick) end
        error(admitted,0)
      end
      if admitted and deadline then registry.maintenance_set('art',rec.id,rec,deadline) end
    end
  end
  for _,pending in ipairs(retry) do registry.maintenance_set('art',pending.id,pending.owner,pending.tick) end
end
registry.register_initializer('device-status-art',function(root)
  if not registry.supported(root) or not registry.scheduling_supported(root) then return end
  local valid,clock=pcall(registry.maintenance_clock,'art')
  if not valid then root.scheduling_diagnostic=clock; return end
  if clock.initialized~=nil then return end
  clock.initialized=1
  for _,id in ipairs(root.order) do registry.art_changed(registry.record(id)) end
end)
registry.register_cleanup('device-status-art',function(rec) clear(rec) end)
scheduler.register_phase('render','device-status-art',M.tick)
return M
