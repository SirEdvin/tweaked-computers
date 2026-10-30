-- Host-only identities and entity ownership. LuaEntities never cross guest APIs.
local limits = require('scripts.runtime.limits')
local errors = require('scripts.runtime.errors')
local admission = require('scripts.runtime.admission')
local M = {}
local cleanup = {} -- Ephemeral host hooks, registered during control parsing.
local initializers = {}
function M.register_initializer(name,fn)
  assert(type(name)=='string' and type(fn)=='function' and not initializers[name])
  initializers[name]=fn
end
local function initialize_services(root)
  local names={}; for name in pairs(initializers) do names[#names+1]=name end; table.sort(names)
  for _,name in ipairs(names) do initializers[name](root) end
end
function M.scheduling_supported(root)
  local s=root and root.scheduler
  return type(s)=='table' and s.work_version==1 and type(s.ready)=='table'
    and type(s.deadlines)=='table' and type(s.deadline_positions)=='table'
    and errors.integer(s.ready_count,0,limits.registry_entries)
    and (s.ready_head==nil and s.ready_count==0 or type(s.ready_head)=='string' and s.ready_count>0)
end
local function work_state()
  local root=M.get()
  local s=root and root.scheduler
  if not M.scheduling_supported(root) then errors.raise('E_UNSUPPORTED','unsupported scheduling membership; source/data retained') end
  return s
end
local function ready_remove(s,id)
  local item=s.ready[id]
  if not item then return end
  if item.next==id then s.ready_head=nil
  else
    s.ready[item.previous].next=item.next
    s.ready[item.next].previous=item.previous
    if s.ready_head==id then s.ready_head=item.next end
  end
  s.ready[id]=nil
  s.ready_count=s.ready_count-1
end
function M.retire_ready(item)
  local s=work_state()
  if s.ready[item.id]==item then ready_remove(s,item.id) end
end
function M.ready_changed(rec)
  local s=work_state()
  local shell=rec.shell
  local pending=shell and shell.version==1 and type(shell.pending)=='table' and #shell.pending>0
  local wanted=rec.kind=='computer' and rec.status~='removed'
    and (rec.status=='running' and #rec.queue>0 or pending)
  local old=s.ready[rec.id]
  if old and (old.generation~=rec.generation or old.run_id~=rec.run_id
    or old.shell_id~=(shell and shell.id)) then ready_remove(s,rec.id); old=nil end
  if not wanted then ready_remove(s,rec.id); return end
  if old then return end
  local id=rec.id
  local item={id=id,generation=rec.generation,run_id=rec.run_id,shell_id=shell and shell.id}
  if s.ready_head then
    local head=s.ready[s.ready_head]; local tail=s.ready[head.previous]
    item.previous=tail.id; item.next=head.id; tail.next=id; head.previous=id
  else s.ready_head=id; item.previous=id; item.next=id end
  s.ready[id]=item
  s.ready_count=s.ready_count+1
end
function M.ready_round(admit)
  local s=work_state(); local head=s.ready_head; local result={}
  if not head then return result end
  local id=head
  repeat
    if not admit(1) then s.ready_head=id; return result end
    local item=s.ready[id]
    if #result>=s.ready_count or type(item)~='table' or item.id~=id
      or type(item.next)~='string' or type(item.previous)~='string'
      or type(s.ready[item.next])~='table' or s.ready[item.next].previous~=id
      or type(s.ready[item.previous])~='table' or s.ready[item.previous].next~=id then
      errors.raise('E_UNSUPPORTED','invalid retained ready links; source/queues retained')
    end
    result[#result+1]=item; id=item.next
  until id==head
  if #result~=s.ready_count then errors.raise('E_UNSUPPORTED','incomplete retained ready rotation; source/queues retained') end
  -- Advance independently of walking the complete round, including refusals.
  s.ready_head=s.ready[head].next
  return result
end
local function deadline_before(a,b)
  if type(a)~='table' or type(b)~='table' or type(a.id)~='string' or type(b.id)~='string'
    or not errors.integer(a.tick,0,9007199254740991) or not errors.integer(b.tick,0,9007199254740991) then
    errors.raise('E_UNSUPPORTED','invalid retained deadline; source/timers retained')
  end
  return a.tick<b.tick or a.tick==b.tick and a.id<b.id
end
function M.next_timer()
  local s=work_state(); local item=s.deadlines[1]
  if item~=nil then
    deadline_before(item,item)
    if s.deadline_positions[item.id]~=1 then errors.raise('E_UNSUPPORTED','invalid retained deadline index; source/timers retained') end
  end
  return item
end
local function deadline_swap(s,a,b)
  local h=s.deadlines; h[a],h[b]=h[b],h[a]
  s.deadline_positions[h[a].id]=a; s.deadline_positions[h[b].id]=b
end
local function deadline_fix(s,i)
  local h=s.deadlines
  while i>1 do
    local parent=math.floor(i/2)
    if not deadline_before(h[i],h[parent]) then break end
    deadline_swap(s,i,parent); i=parent
  end
  while i*2<=#h do
    local child=i*2
    if child<#h and deadline_before(h[child+1],h[child]) then child=child+1 end
    if not deadline_before(h[child],h[i]) then break end
    deadline_swap(s,i,child); i=child
  end
end
function M.timer_remove(id)
  local s=work_state(); local i=s.deadline_positions[id]
  if not i then return end
  if not errors.integer(i,1,#s.deadlines) or type(s.deadlines[i])~='table' or s.deadlines[i].id~=id then
    errors.raise('E_UNSUPPORTED','invalid retained deadline position; source/timers retained')
  end
  local h=s.deadlines; local last=table.remove(h)
  s.deadline_positions[id]=nil
  if i<=#h then h[i]=last; s.deadline_positions[last.id]=i; deadline_fix(s,i) end
end
function M.timers_changed(rec)
  local s=work_state(); local tick
  if rec.status=='running' then
    for _,timer in pairs(rec.timers) do if not tick or timer.deadline<tick then tick=timer.deadline end end
  end
  if not tick then M.timer_remove(rec.id); return end
  local i=s.deadline_positions[rec.id]
  if not i then i=#s.deadlines+1; s.deadline_positions[rec.id]=i end
  s.deadlines[i]={id=rec.id,generation=rec.generation,run_id=rec.run_id,tick=tick}
  deadline_fix(s,i)
end

local function migrate_work(root)
  local s=root.scheduler
  if s.work_version~=nil then return end
  s.work_version=1; s.ready={}; s.ready_count=0; s.ready_head=nil
  s.deadlines={}; s.deadline_positions={}
  for _,id in ipairs(root.order) do
    local rec=root.computers[id]
    if rec and rec.schema_version==1 and type(rec.queue)=='table' and type(rec.timers)=='table' then
      M.ready_changed(rec); M.timers_changed(rec)
    end
  end
end
local function track_destruction(root,rec)
  if rec.kind=='radar' and rec.body.valid then
    local registration=script.register_on_object_destroyed(rec.body)
    rec.destruction_registration=registration
    root.radar_destructions[registration]=rec.id
  end
end
local function migrate_tracking(root)
  if root.tracking_version~=nil then return end
  if type(root.computers)~='table' or type(root.devices)~='table' or type(root.entities)~='table' then return end
  local order,count={},0
  for _,records in ipairs({root.computers,root.devices}) do
    for id,rec in pairs(records) do
      if type(rec)~='table' or rec.id~=id or type(rec.kind)~='string' or not rec.body then return end
      count=count+1
    end
  end
  for _,id in ipairs(root.order) do
    local rec=root.computers[id] or root.devices[id]
    if rec and rec.kind~='radar' then order[#order+1]=id end
  end
  root.order=order; root.retained_count=count; root.radar_destructions={}; root.tracking_version=1
  for _,key in ipairs({'cursor','maintenance_cursor','physical_cursor','art_cursor','kv_cursor'}) do
    if root.scheduler[key] then root.scheduler[key]=math.max(1,math.min(root.scheduler[key],#order)) end
  end
  root.scheduler.radar_cursor=nil
  local lost={}
  for id,rec in pairs(root.devices) do
    track_destruction(root,rec)
    if rec.kind=='radar' and not rec.body.valid then lost[#lost+1]=id end
  end
  table.sort(lost)
  for _,id in ipairs(lost) do M.remove(id,'native_body_lost') end
end
function M.initialize()
  local root=storage.tweaked_computers
  if root then
    -- Unsupported roots remain inert and readable; never reset an unknown schema.
    if root.schema_version~=limits.storage_version then return root end
    -- Upgrade the TC01 empty/bootstrap root only in synchronized initialization.
    root.order=root.order or {}; root.next_sequence=root.next_sequence or 1
    root.ledger=root.ledger or admission.new()
    root.scheduler=root.scheduler or {cursor=1,last_tick=-1}
    migrate_work(root)
    migrate_tracking(root)
    initialize_services(root)
    return root
  end
  root={schema_version=limits.storage_version,next_id=1,next_sequence=1,
    entities={},computers={},devices={},player_drafts={},order={},ledger=admission.new(),
    scheduler={cursor=1,last_tick=-1},tracking_version=1,retained_count=0,radar_destructions={}}
  storage.tweaked_computers=root
  migrate_work(root)
  initialize_services(root)
  return root
end
function M.get() return storage.tweaked_computers end
function M.monitor_changed(rec,topology)
  local root=M.get()
  if topology then root.monitor_topology_dirty=true end
  local s=root.monitors
  local g=s and s.version==1 and s.groups[s.membership[rec.id]]
  if not g then return end
  g.observation_dirty=true
  s.availability_dirty=true
  local p=s.presentation
  if type(p)=='table' and p.version==1 and p.demand_version==1 and type(p.lanes)=='table'
    and type(p.members)=='table' and type(p.work)=='table' then
    local lane=p.members[g.id] or p.lanes[g.id]
    if type(lane)=='table' and p.lanes[lane.key]==lane then p.work[lane.key]=lane end
  end
end
function M.supported(root)
  return root and root.schema_version==limits.storage_version and root.tracking_version==1
    and errors.integer(root.retained_count,0,9007199254740991) and type(root.radar_destructions)=='table'
end
local function writable()
  local root=M.get()
  if not M.supported(root) then errors.raise('E_UNSUPPORTED','unsupported storage schema; source/data retained') end
  return root
end
function M.sequence()
  local root=writable(); local n=root.next_sequence
  if not errors.integer(n,1,9007199254740990) then errors.raise('E_CAPACITY','identity sequence exhausted') end
  root.next_sequence=n+1; return n
end
function M.record(id)
  local root=M.get()
  if not root then return nil end
  return root.computers and root.computers[id] or root.devices and root.devices[id]
end
function M.computer(id)
  local record=M.record(id)
  if not record or record.kind~='computer' then errors.raise('E_NOT_FOUND','computer identity not found') end
  return record
end
function M.by_entity(entity)
  local root=M.get()
  if not root or not entity or not entity.valid then return nil end
  local binding=root.entities[entity.unit_number]
  if not binding then return nil end
  local rec=M.record(binding.id)
  if not rec then return nil end
  local bound=binding.role=='body' and rec.body or rec.children[binding.role]
  if bound~=entity then return nil end -- Native number reuse must never retarget an ID.
  return rec,binding.role
end
function M.register(kind,body)
  local root=writable()
  if type(kind)~='string' or #kind==0 or #kind>limits.identifier_bytes then errors.raise('E_ARGUMENT','invalid device kind') end
  if not body or not body.valid or not body.unit_number then errors.raise('E_ARGUMENT','valid numbered entity required') end
  if root.entities[body.unit_number] then errors.raise('E_ARGUMENT','entity already bound') end
  if root.retained_count>=limits.registry_entries then errors.raise('E_CAPACITY','placed identity capacity reached') end
  if not errors.integer(root.next_id,1,9007199254740990) then errors.raise('E_CAPACITY','identity capacity exhausted') end
  local id='tc-'..string.format('%.0f',root.next_id); root.next_id=root.next_id+1
  local rec={schema_version=1,id=id,generation=1,kind=kind,body=body,children={},
    force_index=body.force.index,surface_index=body.surface.index,powered=true}
  track_destruction(root,rec)
  if kind=='computer' then
    rec.saved_source=''; rec.saved_revision=0; rec.run_generation=0; rec.status='stopped'
    rec.state={}; rec.state_bytes=16; rec.state_entries=0; rec.state_sizes={}
    rec.state_nodes=1; rec.state_node_sizes={}
    rec.logs={}; rec.log_bytes=0; rec.queue={}; rec.queue_bytes=0
    rec.timers={}; rec.subscriptions={}
    root.computers[id]=rec
  else root.devices[id]=rec end
  root.entities[body.unit_number]={id=id,role='body',generation=rec.generation}
  root.retained_count=root.retained_count+1
  if kind~='radar' then root.order[#root.order+1]=id end
  if kind=='monitor' then M.monitor_changed(rec,true) end
  return rec
end
function M.bind_child(id,role,entity)
  local root=writable(); local rec=M.record(id)
  if not rec then errors.raise('E_NOT_FOUND','owner not found') end
  if type(role)~='string' or #role==0 or #role>limits.identifier_bytes or role=='body' then errors.raise('E_ARGUMENT','invalid child role') end
  if not entity or not entity.valid or not entity.unit_number then errors.raise('E_ARGUMENT','valid numbered child required') end
  if rec.children[role] or root.entities[entity.unit_number] then errors.raise('E_ARGUMENT','role/entity already owned') end
  local count=0; for _ in pairs(rec.children) do count=count+1 end
  if count>=limits.owned_children then errors.raise('E_CAPACITY','owned component capacity reached') end
  if entity.force.index~=rec.force_index or entity.surface.index~=rec.surface_index then errors.raise('E_ARGUMENT','child force/surface mismatch') end
  rec.children[role]=entity; root.entities[entity.unit_number]={id=id,role=role,generation=rec.generation}
end
function M.unbind_child(id,role)
  local root=writable(); local rec=M.record(id)
  if not rec or not rec.children[role] then return nil end
  local entity=rec.children[role]; rec.children[role]=nil
  if entity.valid then
    local binding=root.entities[entity.unit_number]
    if binding and binding.id==id and binding.role==role then root.entities[entity.unit_number]=nil end
  else
    -- Invalid LuaEntities cannot be queried. Remove only this precise owner/role.
    for unit,binding in pairs(root.entities) do
      if binding.id==id and binding.role==role then root.entities[unit]=nil end
    end
  end
  return entity
end
-- Publish a fully staged physical replacement without replacing logical data,
-- generations, aliases, queues or active runs. All native work precedes this call.
function M.replace_physical(rec,body,children)
  local root=writable()
  assert(M.record(rec.id)==rec and body.valid and not root.entities[body.unit_number])
  for _,child in pairs(children) do assert(child.valid and not root.entities[child.unit_number]) end
  for unit,binding in pairs(root.entities) do if binding.id==rec.id then root.entities[unit]=nil end end
  rec.body=body; rec.children=children; rec.layout_version=2
  if rec.kind=='monitor' then M.monitor_changed(rec,true) end
  root.entities[body.unit_number]={id=rec.id,role='body',generation=rec.generation}
  for role,child in pairs(children) do root.entities[child.unit_number]={id=rec.id,role=role,generation=rec.generation} end
end
function M.register_cleanup(name,fn)
  assert(type(name)=='string' and type(fn)=='function' and not cleanup[name],'invalid/duplicate host cleanup')
  local n=0; for _ in pairs(cleanup) do n=n+1 end; assert(n<limits.host_hooks,'host cleanup capacity')
  cleanup[name]=fn
end
function M.cleanup(rec,run_id,reason)
  -- Hooks cannot depend on compiling user code. Invoke every registered hook even
  -- when one adapter fails, and retain its recovery diagnostic for the host.
  local names={}; for name in pairs(cleanup) do names[#names+1]=name end; table.sort(names)
  local failures={}
  for _,name in ipairs(names) do
    local ok,e=pcall(cleanup[name],rec,run_id,reason)
    if not ok then failures[#failures+1]={adapter=name,message=type(e)=='string' and e:sub(1,256) or 'host cleanup failed'} end
  end
  if #failures>0 then rec.cleanup_failures=failures else rec.cleanup_failures=nil end
  return #failures==0
end
function M.remove(id,reason)
  local root=writable(); local rec=M.record(id)
  if not rec then return false end
  if not M.cleanup(rec,rec.run_id,reason or 'removed') then
    rec.status='faulted'; rec.diagnostic=errors.new('E_ENGINE','cleanup failed; entity/data retained for recovery')
    return false
  end
  if rec.kind=='monitor' then M.monitor_changed(rec,true) end
  rec.status='removed'; rec.queue={}; rec.timers={}; rec.subscriptions={}
  M.ready_changed(rec); M.timer_remove(rec.id)
  for unit,binding in pairs(root.entities) do if binding.id==id then root.entities[unit]=nil end end
  root.computers[id]=nil; root.devices[id]=nil
  root.retained_count=root.retained_count-1
  if rec.destruction_registration then root.radar_destructions[rec.destruction_registration]=nil end
  for i,x in ipairs(root.order) do
    if x==id then
      table.remove(root.order,i)
      if i<root.scheduler.cursor then root.scheduler.cursor=root.scheduler.cursor-1 end
      break
    end
  end
  -- Ledger identities remain until real clock advancement: removal never renews credits.
  return true
end
return M
