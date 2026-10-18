local registry=require('scripts.registry')
local scheduler=require('scripts.scheduler')
local peripheral=require('scripts.services.peripheral')
local runtime=require('scripts.runtime.computer')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local data=require('scripts.runtime.data')
local model=require('scripts.monitor-model')
local presentation=require('scripts.rendering')
local M={}
local function root() local r=registry.get(); return r and r.monitors end
local function key(x,y) return string.format('%.17g,%.17g',x,y) end
local function scope(r) return r.surface_index..'/'..r.force_index..'/'..r.direction end

local recipient_cost=limits.registry_entries+limits.active_computers^2+limits.active_computers*32+1
local function recipients()
  local result={}
  for _,id in ipairs(registry.get().order) do
    local c=registry.get().computers[id]
    if c and c.status=='running' then result[#result+1]={id=id,run_id=c.run_id} end
  end
  return result
end
function M.resolve(tile)
  local state=root()
  if state and state.version~=1 then errors.raise('E_UNSUPPORTED','unsupported retained monitor state; data preserved') end
  if state and state.presentation and state.presentation.version~=1 then errors.raise('E_UNSUPPORTED','unsupported retained presentation; data preserved') end
  if state and state.job then errors.raise('E_NETWORK_PENDING','monitor regrouping is not yet committed') end
  return state and state.groups[state.membership[tile.id]] or nil
end
function M.available(g,spend)
  spend(#g.members*16+1)
  for _,id in ipairs(g.members) do
    local r=registry.record(id)
    if not r or not r.body.valid or not r.powered or not lifecycle.has_power(r)
      or r.force_index~=g.force_index or r.surface_index~=g.surface_index or r.direction~=g.direction
      or r.body.direction~=g.direction or r.body.force.index~=g.force_index or r.body.surface.index~=g.surface_index
      or r.body.position.x<g.left or r.body.position.x>=g.left+g.world_width
      or r.body.position.y<g.top or r.body.position.y>=g.top+g.world_height
      or not lifecycle.connector(r,'network','red') then return false end
  end
  return true
end
local function signature(tiles)
  local s={}; for _,r in ipairs(tiles) do
    s[#s+1]=r.id..'/'..scope(r)..'/'..key(r.position.x,r.position.y)
  end
  return 'partition-v2/'..model.limits.width_tiles..'x'..model.limits.height_tiles..';'..table.concat(s,';')
end
local function before(a,b)
  if a.position.y~=b.position.y then return a.position.y<b.position.y end
  if a.position.x~=b.position.x then return a.position.x<b.position.x end
  return a.id<b.id
end
local function partition_job(tiles)
  return {input=tiles,buckets={},ordered={},used={},rectangles={},stage='index',cursor=1,sort_index=2}
end
-- A shifted insertion-sort item is rooted separately while ordering is deferred.
local function partition_step(p,spend)
  for _=1,1024 do
    if p.stage=='index' then
      spend(16)
      local r=p.input[p.cursor]
      if not r then p.stage='sort'
      else
        local k=scope(r); p.buckets[k]=p.buckets[k] or {}
        p.buckets[k][key(r.position.x,r.position.y)]=r
        p.ordered[#p.ordered+1]=r; p.cursor=p.cursor+1
      end
    elseif p.stage=='sort' then
      if p.sort_index>#p.ordered then
        spend(4); p.stage='rectangles'; p.cursor=1
      elseif not p.item then
        spend(4); p.item=p.ordered[p.sort_index]; p.sort_cursor=p.sort_index-1
      else
        local previous=p.ordered[p.sort_cursor]
        spend(8+#p.item.id+(previous and #previous.id or 0))
        if previous and before(p.item,previous) then
          p.ordered[p.sort_cursor+1]=previous; p.sort_cursor=p.sort_cursor-1
        else
          p.ordered[p.sort_cursor+1]=p.item; p.sort_index=p.sort_index+1; p.item=nil
        end
      end
    elseif p.stage=='rectangles' then
      spend(8)
      local r=p.ordered[p.cursor]
      if not r then
        p.input=nil; p.buckets=nil; p.ordered=nil; p.used=nil; p.stage='done'; return true
      end
      if not p.used[r.id] then
        spend(model.limits.width_tiles*model.limits.height_tiles*8+8)
        local bucket=p.buckets[scope(r)]; local x,y=r.position.x,r.position.y
        local bw,bh,area=1,1,1; local maxwidth=model.limits.width_tiles
        for h=1,model.limits.height_tiles do
          local width=0
          for w=1,maxwidth do
            local t=bucket[key(x+w-1,y+h-1)]
            if not t or p.used[t.id] then break end; width=w
          end
          maxwidth=math.min(maxwidth,width)
          if maxwidth==0 then break end
          if maxwidth*h>area or (maxwidth*h==area and (maxwidth>bw or (maxwidth==bw and h>bh))) then
            bw,bh,area=maxwidth,h,maxwidth*h
          end
        end
        spend(bw*bh*16+8)
        local members={}; local bytes=0
        for dy=0,bh-1 do for dx=0,bw-1 do
          local t=bucket[key(x+dx,y+dy)]; members[#members+1]=t.id; bytes=math.max(bytes,#t.id)
        end end
        spend(#members*#members*bytes); table.sort(members)
        for _,id in ipairs(members) do p.used[id]=true end
        p.rectangles[#p.rectangles+1]={left=x-0.5,top=y-0.5,world_width=bw,world_height=bh,
          width_tiles=(r.direction==4 or r.direction==12) and bh or bw,
          height_tiles=(r.direction==4 or r.direction==12) and bw or bh,
          direction=r.direction,force_index=r.force_index,surface_index=r.surface_index,members=members}
      end
      p.cursor=p.cursor+1
    else assert(p.stage=='done'); return true end
  end
  return false
end
function M.partition(tiles)
  local p=partition_job(tiles)
  while not partition_step(p,function() end) do end
  return p.rectangles
end
local function same_members(a,b)
  if #a~=#b then return false end
  for i=1,#a do if a[i]~=b[i] then return false end end; return true
end
local function resize_payload(g,w,h,reason)
  return {peripheral=g.id,old_width=w,old_height=h,width=g.model.width,height=g.model.height,reason=reason}
end
local function queue_resize(g,w,h,reason,receivers)
  local state=root(); local pending=state.resizes[g.id]
  if pending then
    pending.payload.width=g.model.width; pending.payload.height=g.model.height; pending.payload.reason=reason
    -- Restart only recipient iteration; already queued callbacks observe latest
    -- state, while bounded notification publication preserves the new revision.
    pending.cursor=1
    pending.recipients=receivers
  else state.resizes[g.id]={payload=resize_payload(g,w,h,reason),cursor=1,recipients=receivers} end
end
function M.reconcile(tick,spend)
  local r=registry.get(); spend(limits.registry_entries*4+1)
  local tiles={}
  for _,id in ipairs(r.order) do
    local rec=r.devices[id]
    if rec and rec.kind=='monitor' and rec.physical_version and rec.body.valid then tiles[#tiles+1]=rec end
  end
  if #tiles>model.limits.tiles then return end -- incompatible saved growth stays retained/inert
  spend(#tiles*128+1)
  local sig=signature(tiles); local state=r.monitors
  if state and state.version~=1 then return end
  if state and state.presentation and state.presentation.version~=1 then return end
  if not state then state={version=1,groups={},membership={},resizes={},touches={},signature='',order={}}; r.monitors=state end
  if state.job and state.job.signature~=sig then state.job=nil end
  if sig~=state.signature then
    -- Bound teardown generations before staging another replacement. Both old
    -- authoritative models and the plain staged job survive save/load.
    if not state.retired or #state.retired==0 then
      if not state.job then
        spend(16)
        state.job={signature=sig,partition=partition_job(tiles),cursor=1,groups={},membership={},resizes={},order={}}
      end
      local job=state.job; local processed=0
      if job.partition then
        if not partition_step(job.partition,spend) then return end
        job.rectangles=job.partition.rectangles; job.partition=nil
      end
      while job.cursor<=#job.rectangles and processed<4 do
        local g=job.rectangles[job.cursor]; local survivor,predecessor
        for _,id in ipairs(g.members) do
          local previous=state.groups[state.membership[id]]
          if previous then
            if not predecessor or previous.anchor<predecessor.anchor then predecessor=previous end
            if previous.anchor==id and (not survivor or previous.anchor<survivor.anchor) then survivor=previous end
          end
        end
        local previous=survivor or predecessor
        local settings=previous and previous.model or registry.record(g.members[1]).monitor_settings
        local changed=not survivor or not same_members(g.members,survivor.members) or g.direction~=survivor.direction
          or g.left~=survivor.left or g.top~=survivor.top
        local w,h=model.size(g.width_tiles,g.height_tiles,settings and settings.scale or 1)
        spend(w*h*3+#g.members*16+128)
        if not changed then g=survivor else
          g.anchor=survivor and survivor.anchor or g.members[1]
          g.id=survivor and survivor.id or 'tc-monitor-'..string.format('%.0f',registry.sequence())
          g.generation=1; g.kind='monitor'; g.body=registry.record(g.anchor).body
          g.model=model.new(g.width_tiles,g.height_tiles,settings)
          if survivor then
            g.model.revision=survivor.model.revision+1
            if w~=survivor.model.width or h~=survivor.model.height then
              job.resizes[g.id]={old_width=survivor.model.width,old_height=survivor.model.height}
            end
          end
        end
        job.groups[g.id]=g
        job.order[#job.order+1]=g.id
        for _,id in ipairs(g.members) do job.membership[id]=g.id end
        job.cursor=job.cursor+1; processed=processed+1
      end
      if job.cursor>#job.rectangles then
        spend(model.limits.tiles*32+recipient_cost)
        local receivers=recipients()
        presentation.regroup(state,job.groups)
        for id,g in pairs(state.groups) do
          if job.groups[id]~=g then presentation.retire(state,g.render) end
        end
        state.groups=job.groups; state.membership=job.membership; state.signature=job.signature
        state.order=job.order; state.job=nil
        for id in pairs(state.resizes) do if not state.groups[id] then state.resizes[id]=nil end end
        for id,old in pairs(job.resizes) do queue_resize(state.groups[id],old.old_width,old.old_height,'tiles',receivers) end
      end
    end
  end
  spend(#tiles*16+1)
  for _,g in pairs(state.groups) do g.powered=M.available(g,function() end) end
end
local methods={}
for name,fn in pairs(model.calls) do
  local call=fn
  local mutation=name:sub(1,3)~='get' and name:sub(1,2)~='is'
  methods[name]=function(c,g,wire,tick,spend,...)
    if not mutation then return call(g.model,spend,...) end
    call(g.model,spend,...); presentation.participate(g)
  end
end
methods.setTextScale=function(c,g,wire,tick,spend,...)
  if select('#',...)~=1 then errors.raise('E_ARGUMENT','setTextScale expects one argument') end
  spend(recipient_cost)
  local scale=g.model.scale
  local changed,w,h=model.scale(g.model,g.width_tiles,g.height_tiles,spend,...)
  if g.model.scale~=scale then presentation.changed(g) end
  if changed then queue_resize(g,w,h,'scale',recipients()) end
  presentation.participate(g)
end
methods.getLimits=function(c,g,wire,tick,spend,...) return (data.copy(model.limits,spend)) end
peripheral.register_type('monitor',{methods=methods,resolve=M.resolve,available=M.available,
  describe=function(g,wire,info)
    info.powered=M.available(g,function() end); info.footprint={width=g.world_width,height=g.world_height}
    info.position={x=g.left+g.world_width/2,y=g.top+g.world_height/2}; return info
  end})
presentation.bind{lookup=peripheral.authority,available=M.available}
peripheral.register_monitor_sync{set=presentation.select,get=presentation.status}
peripheral.register_revocation('monitor-sync',function(c,name,wire,reason)
  if reason=='unavailable' then return end -- Temporary incomplete proof is not detach.
  local selection=c.monitor_sync
  if selection then for _,ref in ipairs(selection.members) do
    if ref.name==name and ref.wire==wire then
      presentation.release(c,errors.new('E_UNREACHABLE','selected monitor path revoked')); return
    end
  end end
end)
-- One computer/subscription delivery regardless of paths, tiles or colors.
function M.deliver(job,g,computer,tick,spend,player)
  local name=job.payload.name or 'monitor_resize'; local interested=false
  if computer.status~='running' or not computer.powered then return true end
  for _,sub in pairs(computer.subscriptions) do if sub.event_name==name then interested=true; break end end
  if not interested or (player and (computer.force_index~=player.force.index or computer.surface_index~=player.surface.index)) then return true end
  local wires={}
  for _,wire in ipairs({'red','green'}) do
    local ok,target=pcall(peripheral.authority,computer,g.id,wire,spend)
    if not ok then
      if type(target)=='table' and target.code then
        if target.code~='E_UNREACHABLE' then computer.monitor_diagnostic=target end
        if target.code=='E_NETWORK_PENDING' or target.code=='E_BUSY' then return false end
      else error(target,0) end
    elseif target then wires[#wires+1]=wire end
  end
  if #wires==0 then return true end
  local payload={}; for k,v in pairs(job.payload) do if k~='name' then payload[k]=v end end
  payload.wire=wires[1]; payload.wires=wires
  if name=='monitor_resize' then
    -- A later geometry commit may precede callback dispatch. Coalesce already
    -- queued resize snapshots so getSize agrees with the delivered dimensions.
    spend(#computer.queue*4+1)
    local staged={}; local difference=0
    for _,item in ipairs(computer.queue) do
      if item.event.name==name and item.event.peripheral==g.id then
        local next_payload={}; for k,v in pairs(payload) do next_payload[k]=v end
        next_payload.name=name; next_payload.old_width=item.event.old_width; next_payload.old_height=item.event.old_height
        local event,stats=data.copy(next_payload,spend,limits.event_queue_bytes)
        local bytes=stats.bytes+128+#computer.id+#computer.run_id
        difference=difference+bytes-item.bytes
        event.tick=item.event.tick; event.sequence=item.event.sequence
        event.computer_id=computer.id; event.run_id=computer.run_id
        staged[#staged+1]={item=item,event=event,bytes=bytes}
      end
    end
    if #staged>0 then
      if computer.queue_bytes+difference>limits.event_queue_bytes then
        runtime.fault(computer,errors.new('E_CAPACITY','resize queue overflow; run stopped'),tick); return true
      end
      spend(#staged*4+1)
      for _,entry in ipairs(staged) do entry.item.event=entry.event; entry.item.bytes=entry.bytes end
      computer.queue_bytes=computer.queue_bytes+difference; return true
    end
  end
  runtime.emit(computer.id,name,payload,tick,spend)
  return true
end
function M.notifications(tick,spend)
  local state=root(); if not state or state.version~=1 then return end
  spend(limits.registry_entries+model.limits.tiles*2+1)
  local completed=0
  local function process(job,g,player)
    local ids=job.recipients
    while job.cursor<=#ids and completed<3 do
      local receiver=ids[job.cursor]; local c=registry.record(receiver.id)
      if c and c.run_id==receiver.run_id then
        local ok,delivered=scheduler.try_maintenance(function() return M.deliver(job,g,c,tick,spend,player) end)
        if not ok or not delivered then return false end
      end
      job.cursor=job.cursor+1; completed=completed+1
    end
    return job.cursor>#ids
  end
  -- Touch is transient and prioritized. Revalidate player and current display.
  local retained={}
  for _,job in ipairs(state.touches) do
    local g=state.groups[job.payload.peripheral]; local player=game.get_player(job.payload.player_index)
    if g and g.powered and player and player.valid and player.force.index==g.force_index and player.surface.index==g.surface_index then
      if not process(job,g,player) then retained[#retained+1]=job end
    end
  end
  state.touches=retained
  for _,id in ipairs(state.order) do
    local job=state.resizes[id]; local g=state.groups[id]
    if job and (not g or g.powered and process(job,g)) then state.resizes[id]=nil end
  end
end
function M.activate_for_player(event,player)
  if event.input_name~='tc-interact' or event.in_gui or event.element then return false end
  if not player or not player.valid or player.opened or player.cursor_ghost then return false end
  local cursor=player.cursor_stack
  if cursor and cursor.valid_for_read then return false end
  local state=root(); if not state or state.version~=1 then return false end
  if state.job then return false end
  local pos=event.cursor_position
  if not pos or type(pos.x)~='number' or type(pos.y)~='number' or pos.x~=pos.x or pos.y~=pos.y then return false end
  -- The position, not selected entity priority, selects non-anchor world cells.
  local selected
  for _,id in ipairs(state.order) do
    local g=state.groups[id]
    if player.force.index==g.force_index and player.surface.index==g.surface_index
      and pos.x>=g.left and pos.x<g.left+g.world_width and pos.y>=g.top and pos.y<g.top+g.world_height then selected=g; break end
  end
  if not selected or not M.available(selected,function() end) then return false end
  if not presentation.matches(selected,selected.render) or selected.render.hidden then return false end
  local reachable=false
  for _,id in ipairs(selected.members) do
    local tile=registry.record(id)
    if math.abs(tile.body.position.x-pos.x)<=0.5 and math.abs(tile.body.position.y-pos.y)<=0.5
      and player.can_reach_entity(tile.body) then reachable=true; break end
  end
  if not reachable then return false end
  local x,y=model.touch(selected,pos.x,pos.y); if not x then return false end
  if #state.touches>=64 then player.print({'tc-monitor.touch-busy'}); return false end
  -- Engine custom input is one synchronized activation; no linked build/mining
  -- action and no per-path/tile fanout. Two players remain separate interactions.
  state.touches[#state.touches+1]={cursor=1,payload={name='monitor_touch',peripheral=selected.id,x=x,y=y,
    player_index=player.index,sample_tick=event.tick},recipients=recipients()}
  return true
end
function M.activate(event)
  if not registry.supported(registry.get()) then return false end
  local player=game.get_player(event.player_index)
  local ok,result=scheduler.try_maintenance(function()
    scheduler.maintenance(registry.get(),event.tick)(model.limits.tiles*32+recipient_cost+128)
    return M.activate_for_player(event,player)
  end)
  if not ok and player then player.print({'tc-monitor.touch-busy'}) end
  return ok and result
end
function M.refresh_resize(event)
  local state=root(); local g=state and state.version==1 and state.groups[event.peripheral]
  if g then event.width=g.model.width; event.height=g.model.height end
end
scheduler.register_monitor_refresh(M.refresh_resize)
scheduler.register_phase('lifecycle','02-monitor-groups',M.reconcile)
scheduler.register_phase('notifications','monitor-events',M.notifications)
return M
