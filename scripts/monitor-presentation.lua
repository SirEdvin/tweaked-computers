-- Bounded plain-data presentation coordinator. No guest functions are retained.
local registry=require('scripts.registry')
local scheduler=require('scripts.scheduler')
local model=require('scripts.monitor-model')
local network=require('scripts.network')
local lifecycle=require('scripts.lifecycle')
local errors=require('scripts.runtime.errors')
local data=require('scripts.runtime.data')
local M={}; local backend; local authority
local L=model.limits
function M.install(b) assert(not backend); backend=b end
function M.bind(a) assert(not authority); authority=a end
local function slots(r) return r.slots or r.width*r.height end
local function state(s)
  if s.presentation then return s.presentation.version==1 and s.presentation or nil end
  local p={version=1,lanes={},jobs={},orphans={},retired={},front_cells=0,front_frames=0,
    staging_cells=0,staging_frames=0,retired_cells=0,retired_frames=0,pending_cells=0,cursor=1}
  s.presentation=p
  local function account(r)
    if r and not r.accounted then
      r.slots=r.slots or r.width and r.height and r.width*r.height or #r.cells
      r.accounted='front'; p.front_cells=p.front_cells+r.slots; p.front_frames=p.front_frames+1
    end
  end
  for _,g in pairs(s.groups) do account(g.render) end
  for _,r in ipairs(s.retired or {}) do account(r); p.orphans[#p.orphans+1]=r end
  s.retired=nil; return p
end
function M.matches(g,r)
  local c=r and r.context
  return c and not r.broken and r.version==1 and c.group==g and r.width==g.model.width and r.height==g.model.height
    and r.scale==g.model.scale and c.direction==g.direction and c.left==g.left and c.top==g.top
    and c.world_width==g.world_width and c.world_height==g.world_height
end
function M.retire(s,r)
  if not r then return end
  local p=state(s); if not p then return end
  if r.orphaned then return end
  r.slots=r.slots or r.width and r.height and r.width*r.height or #r.cells
  if not r.accounted then r.accounted='front'; p.front_cells=p.front_cells+r.slots; p.front_frames=p.front_frames+1 end
  r.orphaned=true; p.orphans[#p.orphans+1]=r
  if r.context then r.context.group=nil end -- Do not retain a removed group's live model through its old front.
end
local function cancel(p,lane)
  if lane.pending then p.pending_cells=p.pending_cells-lane.pending.slots; lane.pending=nil end
  if lane.job then
    lane.job.cancelled=true
    for _,c in ipairs(lane.job.captures) do if c then c.group=nil end end
    lane.job=nil
  end
end
local function release(c,reason)
  local r=registry.get(); local s=r and r.monitors; local p=s and s.presentation
  local selection=c.monitor_sync
  if selection and p and p.version==1 then
    local lane=p.lanes[selection.key]; if lane then cancel(p,lane); p.lanes[selection.key]=nil end
  end
  c.monitor_sync=nil; c.monitor_sync_diagnostic=reason
end
M.release=release
local function owner_of(p,id)
  for _,lane in pairs(p.lanes) do if lane.owner then
    for _,ref in ipairs(lane.members) do if ref.name==id then return lane end end
  end end
end
function M.select(c,tick,spend,input)
  if type(input)~='table' or getmetatable(input) then errors.raise('E_ARGUMENT','dense monitor references required') end
  local n=0
  for k in pairs(input) do
    n=n+1
    if not errors.integer(k,1,1024) then errors.raise('E_ARGUMENT','dense bounded monitor references required') end
    if n>L.sync_group_refs then errors.raise('E_LIMIT','too many supplied references') end
  end
  for i=1,n do if input[i]==nil then errors.raise('E_ARGUMENT','sparse monitor references') end end
  if n==0 then spend(L.tiles*8+128); release(c,nil); return end
  local s=registry.get().monitors
  if not s or s.version~=1 or s.job then errors.raise('E_NETWORK_PENDING','monitor topology pending') end
  if s.presentation and s.presentation.version~=1 then errors.raise('E_UNSUPPORTED','unknown presentation version retained') end
  local refs={}; local count,total=0,0
  for i=1,n do
    local ref=input[i]
    if type(ref)~='table' or getmetatable(ref) then errors.raise('E_ARGUMENT','plain monitor reference required') end
    local fields=0
    for k in pairs(ref) do fields=fields+1; if k~='name' and k~='wire' then errors.raise('E_ARGUMENT','unknown monitor reference key') end end
    if fields~=2 or type(ref.name)~='string' or #ref.name==0 or #ref.name>64 then errors.raise('E_ARGUMENT','exact monitor name and wire required') end
    network.wire(ref.wire)
    local g,path=authority.lookup(c,ref.name,ref.wire,spend)
    if not g then errors.raise('E_UNREACHABLE','monitor reference unreachable') end
    if g.kind~='monitor' then errors.raise('E_WRONGTYPE','monitor required') end
    if not authority.available(g,spend) then errors.raise('E_UNPOWERED','selected monitor is unpowered') end
    if not refs[g.id] then count=count+1; total=total+g.model.width*g.model.height end
    if not refs[g.id] or ref.wire=='red' then refs[g.id]={name=g.id,wire=ref.wire,generation=g.generation,path=path} end
  end
  if count>L.sync_group_members or total>L.sync_group_cells then errors.raise('E_CAPACITY','monitor synchronization capacity') end
  local members={}; for _,ref in pairs(refs) do members[#members+1]=ref end
  table.sort(members,function(a,b) return a.name<b.name end)
  local p=s.presentation
  for _,ref in ipairs(members) do
    local other=p and owner_of(p,ref.name)
    if other and (other.owner~=c.id or other.run_id~=c.run_id) then errors.raise('E_BUSY','monitor already selected by another run') end
  end
  local old=c.monitor_sync; local identical=old and old.run_id==c.run_id and #old.members==#members
  if identical then for i,ref in ipairs(members) do
    if old.members[i].name~=ref.name or old.members[i].wire~=ref.wire then identical=false; break end
  end end
  spend(L.tiles*8+128+#members*16)
  if identical then return end
  p=state(s); release(c,nil)
  if #members==0 then return end
  local key='group/'..c.id..'/'..c.run_id
  local lane={key=key,members=members,owner=c.id,run_id=c.run_id,participation={},sequence=0,presented_sequence=0,status='waiting'}
  -- Selecting a display cancels its unpublished singleton epoch, not its front.
  for _,ref in ipairs(members) do
    local single=p.lanes[ref.name]; if single then cancel(p,single); p.lanes[ref.name]=nil end
  end
  p.lanes[key]=lane; c.monitor_sync={key=key,run_id=c.run_id,members=members}
end
function M.status(c,spend)
  local s=registry.get().monitors; local p=s and s.presentation
  local selected=c.monitor_sync
  local lane=selected and p and p.version==1 and p.lanes[selected.key]
  local result={members={},status='none',presented_sequence=0,diagnostic=c.monitor_sync_diagnostic}
  if lane then
    result.status=lane.diagnostic and 'blocked' or (lane.job or lane.pending) and 'preparing' or 'waiting'
    result.presented_sequence=lane.presented_sequence; result.presented_tick=lane.presented_tick; result.diagnostic=lane.diagnostic
    for _,ref in ipairs(lane.members) do result.members[#result.members+1]={name=ref.name,wire=ref.wire} end
  end
  return (data.copy(result,spend))
end
function M.participate(g)
  g.write_epoch=(g.write_epoch or 0)+1
  local s=registry.get().monitors; local p=s and s.presentation
  if p and p.version==1 then
    local lane=owner_of(p,g.id)
    if lane then lane.participation[g.id]=true end
  end
end
function M.changed(g)
  local s=registry.get().monitors; local p=s and s.presentation
  if not p or p.version~=1 then return end
  local lane=owner_of(p,g.id) or p.lanes[g.id]
  if lane then cancel(p,lane); lane.participation={}; lane.last=nil; lane.last_epoch=nil end
end
function M.regroup(s,groups)
  local p=s.presentation; if not p or p.version~=1 then return end
  for id,g in pairs(s.groups) do if groups[id]~=g then M.changed(g) end end
end
local function objects(r,fn)
  if r.panel then fn(r.panel) end
  if r.cursor then fn(r.cursor) end
  for _,c in ipairs(r.cells) do if c then
    if c.background then fn(c.background) end; if c.glyph then fn(c.glyph) end
  end end
end
local function visible(r,value,spend)
  local count=2*#r.cells+2
  spend(count*3+8)
  objects(r,function(o) if o.valid then o.visible=value end end)
  r.hidden=not value
end
local function enqueue(p,r,kind)
  local n=slots(r)
  if p.retired_cells+n>L.render_retired_cells or p.retired_frames>=L.render_retired_frames then return false end
  p[kind..'_cells']=p[kind..'_cells']-n; p[kind..'_frames']=p[kind..'_frames']-1
  r.accounted='retired'; p.retired_cells=p.retired_cells+n; p.retired_frames=p.retired_frames+1
  if r.context then r.context.group=nil end
  p.retired[#p.retired+1]=r; return true
end
local function cleanup(p,spend,remaining)
  while remaining>0 and #p.retired>0 do
    local r=p.retired[1]; local i=r.cleanup_cursor or 1
    local count=r.cleanup_indices and #r.cleanup_indices or #r.cells
    while i<=count and remaining>0 do
      local index=r.cleanup_indices and r.cleanup_indices[i] or i
      spend(8)
      if r.is_front or not r.reused or not r.reused[index] then backend.clear_cell(r.cells[index],not r.is_front) end
      r.cells[index]=false; i=i+1; r.cleanup_cursor=i; remaining=remaining-1
    end
    if i>count then
      spend(#p.retired+12)
      if r.is_front or not r.shared_panel then backend.destroy(r.panel) end
      if r.is_front or not r.shared_cursor then backend.destroy(r.cursor) end
      p.retired_cells=p.retired_cells-slots(r); p.retired_frames=p.retired_frames-1
      table.remove(p.retired,1)
    else break end
  end
  return remaining
end
local function invalidate(p,spend)
  local index=1
  while index<=#p.orphans do
    local r=p.orphans[index]
    if not r.hidden then visible(r,false,spend) end
    spend(#p.orphans+8)
    if enqueue(p,r,'front') then table.remove(p.orphans,index) else index=index+1 end
  end
  for index=#p.jobs,1,-1 do local job=p.jobs[index]; if job.cancelled then
    for i,r in ipairs(job.frames) do if r then
      if enqueue(p,r,'staging') then job.frames[i]=false; job.captures[i]=false; job.slots=job.slots-slots(r) end
    end end
    if job.slots==0 then spend(#p.jobs+8); table.remove(p.jobs,index) end
  end end
end
local function context(g,snapshot)
  return {group=g,model=snapshot,direction=g.direction,left=g.left,top=g.top,world_width=g.world_width,
    world_height=g.world_height,width_tiles=g.width_tiles,height_tiles=g.height_tiles,surface_index=g.surface_index}
end
local function blocked(lane,code,message) lane.status='blocked'; lane.diagnostic=errors.new(code,message) end
local function qualify(s,lane,spend,proofs)
  if s.job then blocked(lane,'E_NETWORK_PENDING','monitor topology pending'); return false end
  if lane.owner then
    local c=registry.record(lane.owner)
    if not c or c.run_id~=lane.run_id or c.status~='running' then
      if c then release(c,errors.new('E_NOT_FOUND','selecting run retired')) else cancel(s.presentation,lane); s.presentation.lanes[lane.key]=nil end
      return false
    end
    if not c.powered or not lifecycle.has_power(c) then blocked(lane,'E_UNPOWERED','selecting computer unpowered'); return false end
  end
  local total=0
  for _,ref in ipairs(lane.members) do
    local g=s.groups[ref.name]
    if not g or ref.generation~=g.generation then
      if lane.owner then release(registry.record(lane.owner),errors.new('E_UNREACHABLE','monitor identity removed')) end
      return false
    end
    total=total+g.model.width*g.model.height
    if not authority.available(g,spend,proofs) then blocked(lane,'E_UNPOWERED','monitor unpowered'); return false end
  end
  if total>L.sync_group_cells then blocked(lane,'E_CAPACITY','selected grids exceed combined capacity'); return false end
  lane.diagnostic=nil; return true,total
end
local function seal(s,p,lane,spend,total)
  local eligible=true; local changed=false
  for _,ref in ipairs(lane.members) do
    local g=s.groups[ref.name]
    if lane.owner and not lane.participation[g.id] then eligible=false end
    if not lane.last or lane.last[g.id]~=g.model.revision or lane.last_epoch and lane.last_epoch[g.id]~=(g.write_epoch or 0)
      or not g.render and not lane.job and not lane.pending then changed=true end
  end
  if not eligible or not lane.owner and not changed then return end
  local previous=lane.pending and lane.pending.slots or 0
  if p.pending_cells-previous+total>L.render_snapshot_cells then blocked(lane,'E_CAPACITY','pending snapshot backpressure'); return end
  local work=#lane.members*84+8
  for _,ref in ipairs(lane.members) do work=work+(s.groups[ref.name].model.damage_count or 0)*2 end
  spend(work)
  local captures={}; local last={}; local epochs={}
  for _,ref in ipairs(lane.members) do
    local g=s.groups[ref.name]; local snapshot=model.capture(g.model,function() end); snapshot.sealed_tick=p.tick
    captures[#captures+1]=context(g,snapshot)
    last[g.id]=g.model.revision; epochs[g.id]=g.write_epoch or 0
  end
  lane.sequence=lane.sequence+1; lane.pending={captures=captures,slots=total,sequence=lane.sequence}
  p.pending_cells=p.pending_cells-previous+total; lane.last=last; lane.last_epoch=epochs; lane.participation={}
end
local function admit(s,p,lane,spend)
  local q=lane.pending; if not q or lane.job then return end
  local n=#q.captures
  if p.staging_cells+q.slots>L.render_staging_cells or p.staging_frames+n>L.render_staging_frames then return end
  local old,oldframes=0,0
  for _,c in ipairs(q.captures) do if c.group.render then old=old+slots(c.group.render); oldframes=oldframes+1 end end
  if p.front_cells-old+q.slots>L.aggregate_cells or p.front_frames-oldframes+n>L.tiles then return end
  local work=n*32+8
  for _,c in ipairs(q.captures) do
    work=work+backend.frame_cost(c,M.matches(c.group,c.group.render) and c.group.render or nil)
  end
  spend(work)
  local job={lane=lane,captures=q.captures,slots=q.slots,sequence=q.sequence,frames={},member=1,cell=1}
  for _,c in ipairs(q.captures) do job.frames[#job.frames+1]=backend.frame(c,M.matches(c.group,c.group.render) and c.group.render or nil) end
  p.staging_cells=p.staging_cells+q.slots; p.staging_frames=p.staging_frames+n
  p.pending_cells=p.pending_cells-q.slots; lane.pending=nil; lane.job=job; p.jobs[#p.jobs+1]=job
end
local function prepare(job,spend,remaining)
  while job.member<=#job.frames and remaining>0 do
    local r=job.frames[job.member]; local c=job.captures[job.member]
    local count=r.indices and #r.indices or r.slots
    while job.cell<=count and remaining>0 do
      local index=r.indices and r.indices[job.cell] or job.cell
      spend(48); backend.cell(c,r,index); job.cell=job.cell+1; remaining=remaining-1
    end
    if job.cell>count then
      spend(16); backend.cursor(c,r); job.member=job.member+1; job.cell=1
    end
  end
  job.ready=job.member>#job.frames; return remaining
end
local function commit(s,p,job,tick,spend,proofs)
  local lane=job.lane
  if not qualify(s,lane,spend,proofs) then return false end
  local function proof_failure(problem)
    if type(problem)~='table' or not problem.code then error(problem,0) end -- Preserve private quota refusal.
    blocked(lane,problem.code,problem.message)
    return false
  end
  if lane.owner then
    local c=registry.record(lane.owner)
    for _,ref in ipairs(lane.members) do
      local ok,valid=pcall(network.validate_witness,c,ref.wire,ref.path,spend)
      if not ok then return proof_failure(valid) end
      if not valid then
        local checked,g,path=pcall(authority.lookup,c,ref.name,ref.wire,spend)
        if not checked then return proof_failure(g) end
        if not g then release(c,errors.new('E_UNREACHABLE','selected network path removed')); return false end
        spend(#path+4); ref.path=path; return false -- Refresh one stale proof, then retry the whole barrier.
      end
      if s.membership[ref.path[#ref.path]]~=ref.name then release(c,errors.new('E_UNREACHABLE','selected endpoint regrouped')); return false end
    end
  end
  local oldcells,oldframes=0,0
  for _,c in ipairs(job.captures) do local old=c.group.render
    if old then oldcells=oldcells+slots(old); oldframes=oldframes+1 end
  end
  if p.retired_cells+oldcells>L.render_retired_cells or p.retired_frames+oldframes>L.render_retired_frames then return false end
  if p.front_cells-oldcells+job.slots>L.aggregate_cells or p.front_frames-oldframes+#job.frames>L.tiles then return false end
  -- Prepay the complete bounded native inventory, validity reads and writes before
  -- any visibility or ownership change. No fallible admission inside the swap.
  local cells,damage=0,0
  for _,r in ipairs(job.frames) do
    cells=cells+(r.indices and #r.indices or r.slots)
    damage=damage+model.acknowledge_cost(r.context.group.model,r.snapshot)
    if r.indices and (r.front~=r.context.group.render or r.front.hidden) then job.invalid=true; return false end
  end
  local maximum=4*cells+4*#job.frames
  local work=maximum*3+damage+#job.frames*16+#p.jobs+8
  if work>L.render_commit_work then blocked(lane,'E_CAPACITY','publication work limit'); return false end
  spend(work)
  local operations={}; local values={}
  local function add(o,value)
    if o then if not o.valid then job.invalid=true; return false end; operations[#operations+1]=o; values[#values+1]=value end
    return true
  end
  for j,r in ipairs(job.frames) do
    local old=job.captures[j].group.render
    if old then
      for index=1,(r.indices and #r.indices or old.slots) do
        local i=r.indices and r.indices[index] or index; local cell=old.cells[i]
        if cell and cell~=r.cells[i] then
        local next_cell=r.cells[i]
        if (not next_cell or cell.background~=next_cell.background) and not add(cell.background,false) then return false end
        if (not next_cell or cell.glyph~=next_cell.glyph) and not add(cell.glyph,false) then return false end
      end end
      if old.panel~=r.panel and not add(old.panel,false) then return false end
      if old.cursor~=r.cursor and not add(old.cursor,false) then return false end
    end
    for index=1,(r.indices and #r.indices or r.slots) do
      local i=r.indices and r.indices[index] or index; local cell=r.cells[i]
      if not cell.background.valid or cell.glyph and not cell.glyph.valid then job.invalid=true; return false end
      local previous=old and old.cells[i]
      if (not previous or previous.background~=cell.background or old.hidden) and not add(cell.background,true) then return false end
      if (not previous or previous.glyph~=cell.glyph or old.hidden) and not add(cell.glyph,true) then return false end
    end
    if r.panel and not r.panel.valid or r.cursor and not r.cursor.valid then job.invalid=true; return false end
    if not old or old.panel~=r.panel or old.hidden then if not add(r.panel,true) then return false end end
    if not old or old.cursor~=r.cursor or old.hidden then if not add(r.cursor,true) then return false end end
  end
  if #operations>L.render_commit_objects then return false end
  for i,o in ipairs(operations) do o.visible=values[i] end
  for i,r in ipairs(job.frames) do
    local g=job.captures[i].group; local old=g.render
    if old then
      for index=1,(r.indices and #r.indices or r.slots) do
        local i=r.indices and r.indices[index] or index
        local previous,next_cell=old.cells[i],r.cells[i]
        if previous==next_cell then old.cells[i]=false
        elseif previous and next_cell then
          if previous.background==next_cell.background then previous.background=nil end
          if previous.glyph==next_cell.glyph then previous.glyph=nil end
        end
      end
      old.cleanup_indices=r.indices -- Unchanged native cells transfer ownership without a retirement scan.
      if old.panel==r.panel then old.panel=nil end
      if old.cursor==r.cursor then old.cursor=nil end
      enqueue(p,old,'front')
    end
    r.is_front=true; r.front=nil; r.reused=nil; r.hidden=nil; r.cleanup_indices=nil
    r.presented_revision=r.snapshot.revision; r.presented_tick=tick; r.presented_sequence=job.sequence
    model.acknowledge(g.model,r.snapshot)
    r.accounted='front'; g.render=r
    p.front_cells=p.front_cells+r.slots; p.front_frames=p.front_frames+1
  end
  p.staging_cells=p.staging_cells-job.slots; p.staging_frames=p.staging_frames-#job.frames
  lane.presented_sequence=job.sequence; lane.presented_tick=tick; lane.job=nil; job.complete=true
  for index,active in ipairs(p.jobs) do if active==job then table.remove(p.jobs,index); break end end
  return true
end
function M.tick(tick,spend)
  local s=registry.get().monitors; if not s or s.version~=1 then return end
  if s.presentation and s.presentation.version~=1 then return end
  if s.presentation and s.presentation.tick==tick and registry.get().scheduler.last_tick==tick then return end
  spend(L.tiles*16+16)
  local p=state(s)
  p.tick=tick
  -- This non-yielding render pass cannot change physical members. Share only
  -- positive all-member proofs inside it; never cache them by simulation tick.
  local proofs={}
  -- Demand requests are host bookkeeping, not a second work ledger.
  local demand=0
  for _,job in ipairs(p.jobs) do if not job.cancelled and job.ready then demand=160000 end end
  if #p.orphans>0 then demand=160000 end
  scheduler.request_render_work(registry.get(),tick,demand,spend)
  local remaining=L.render_cells_per_tick
  invalidate(p,spend)
  remaining=cleanup(p,spend,math.floor(remaining/2)) + math.ceil(L.render_cells_per_tick/2)
  local selected={}
  for _,lane in pairs(p.lanes) do if lane.owner then for _,ref in ipairs(lane.members) do selected[ref.name]=lane end end end
  local order={}
  for _,id in ipairs(s.order) do
    local g=s.groups[id]; local front=g.render
    -- Paid adoption of a proven complete legacy frame preserves unaffected
    -- images. Partial/unknown sweeps instead take the hide/retire path below.
    if front and not front.version and front.layer_version==2 and front.presented_revision==g.model.revision
      and front.cursor_revision==g.model.revision and not front.sweep_cursor
      and front.width==g.model.width and front.height==g.model.height and front.scale==g.model.scale
      and front.panel and front.panel.valid then
      spend(100)
      local snap=model.capture(g.model,function() end)
      front.version=1; front.layer_version=3; front.snapshot=snap; front.context=context(g,snap); front.is_front=true
    end
    if front and (not M.matches(g,front) or not authority.available(g,spend,proofs)) then
      if not front.hidden then scheduler.request_render_work(registry.get(),tick,160000,spend); visible(front,false,spend) end
      if not M.matches(g,front) then M.retire(s,front); g.render=nil end
    elseif front and front.hidden then scheduler.request_render_work(registry.get(),tick,160000,spend); visible(front,true,spend) end
    if not selected[id] and not p.lanes[id] then p.lanes[id]={key=id,members={{name=id,generation=g.generation}},participation={},sequence=0,presented_sequence=0,status='waiting'} end
    local lane=selected[id] or p.lanes[id]
    if lane and not lane.visited then lane.visited=true; order[#order+1]=lane end
  end
  for key,lane in pairs(p.lanes) do
    if not lane.visited then cancel(p,lane); p.lanes[key]=nil else lane.visited=nil end
  end
  local start=math.min(p.cursor,math.max(1,#order))
  for offset=0,#order-1 do
    local index=(start+offset-1)%#order+1; local lane=order[index]
    p.cursor=index%#order+1 -- A deferred lane cannot monopolize the next tick's prefix.
    local ok,total=qualify(s,lane,spend,proofs)
    if ok then
      local invalid=false
      if lane.job then for _,c in ipairs(lane.job.captures) do if not M.matches(c.group,{version=1,context=c,width=c.model.width,height=c.model.height,scale=c.model.scale}) or s.groups[c.group.id]~=c.group then invalid=true end end end
      if invalid then cancel(p,lane); lane.participation={}; lane.last=nil; lane.last_epoch=nil end
      seal(s,p,lane,spend,total); admit(s,p,lane,spend)
      if lane.job then
        remaining=prepare(lane.job,spend,remaining)
        if lane.job.ready then
          local job=lane.job
          scheduler.request_render_work(registry.get(),tick,160000,spend); commit(s,p,job,tick,spend,proofs)
          if job.invalid then
            for _,c in ipairs(job.captures) do if c.group.render then c.group.render.broken=true end end
            cancel(p,lane); lane.last=nil; lane.last_epoch=nil; lane.participation={}
          end
        end
      end
      if p.lanes[lane.key] then lane.status=(lane.job or lane.pending) and 'preparing' or 'waiting' end
    end
  end
  if #order>0 then p.cursor=start%#order+1 end
  local kept={}; local demand=0
  for _,job in ipairs(p.jobs) do
    if not job.complete and (not job.cancelled or job.slots>0) then kept[#kept+1]=job end
    if not job.cancelled and job.ready then demand=160000 end
  end
  p.jobs=kept
  if #p.orphans>0 then demand=160000 end
  cleanup(p,spend,remaining)
  scheduler.request_render_work(registry.get(),tick,demand,spend)
end
registry.register_cleanup('monitor-sync',function(c,run,reason)
  if c.kind=='computer' and c.monitor_sync and c.monitor_sync.run_id==run and reason~='power_loss' then
    release(c,errors.new('E_NOT_FOUND','monitor selection released: '..reason))
  end
end)
return M
