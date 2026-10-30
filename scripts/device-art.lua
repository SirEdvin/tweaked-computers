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
function M.tick(tick,spend)
  local root=registry.get(); local n=#root.order
  if n==0 then return end
  local index=math.min(root.scheduler.art_cursor or 1,n)
  for _=1,math.min(n,128) do
    spend(16)
    local rec=registry.record(root.order[index])
    local refresh=rec and (rec.kind~='monitor' or rec.monitor_art_dirty or not rec.status_art or not rec.status_art.object.valid)
    if refresh and not rec.native_carrier and rec.physical_version==1 and rec.body.valid then
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
        if rec.kind=='monitor' then rec.monitor_art_dirty=nil end
      end
    end
    index=index%n+1; root.scheduler.art_cursor=index
  end
end
registry.register_cleanup('device-status-art',function(rec) clear(rec) end)
scheduler.register_phase('render','device-status-art',M.tick)
return M
