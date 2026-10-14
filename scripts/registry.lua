-- Host-only identities and entity ownership. LuaEntities never cross guest APIs.
local limits = require('scripts.runtime.limits')
local errors = require('scripts.runtime.errors')
local admission = require('scripts.runtime.admission')
local M = {}
local cleanup = {} -- Ephemeral host hooks, registered during control parsing.
function M.initialize()
  local root=storage.tweaked_computers
  if root then
    -- Unsupported roots remain inert and readable; never reset an unknown schema.
    if root.schema_version~=limits.storage_version then return root end
    -- Upgrade the TC01 empty/bootstrap root only in synchronized initialization.
    root.order=root.order or {}; root.next_sequence=root.next_sequence or 1
    root.ledger=root.ledger or admission.new()
    root.scheduler=root.scheduler or {cursor=1,last_tick=-1}
    return root
  end
  root={schema_version=limits.storage_version,next_id=1,next_sequence=1,
    entities={},computers={},devices={},player_drafts={},order={},ledger=admission.new(),
    scheduler={cursor=1,last_tick=-1}}
  storage.tweaked_computers=root
  return root
end
function M.get() return storage.tweaked_computers end
function M.supported(root) return root and root.schema_version==limits.storage_version end
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
  if #root.order>=limits.registry_entries then errors.raise('E_CAPACITY','placed identity capacity reached') end
  if not errors.integer(root.next_id,1,9007199254740990) then errors.raise('E_CAPACITY','identity capacity exhausted') end
  local id='tc-'..string.format('%.0f',root.next_id); root.next_id=root.next_id+1
  local rec={schema_version=1,id=id,generation=1,kind=kind,body=body,children={},
    force_index=body.force.index,surface_index=body.surface.index,powered=true}
  if kind=='computer' then
    rec.saved_source=''; rec.saved_revision=0; rec.run_generation=0; rec.status='stopped'
    rec.state={}; rec.state_bytes=16; rec.state_entries=0; rec.state_sizes={}
    rec.state_nodes=1; rec.state_node_sizes={}
    rec.logs={}; rec.log_bytes=0; rec.queue={}; rec.queue_bytes=0
    rec.timers={}; rec.subscriptions={}
    root.computers[id]=rec
  else root.devices[id]=rec end
  root.entities[body.unit_number]={id=id,role='body',generation=rec.generation}
  root.order[#root.order+1]=id
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
  rec.status='removed'; rec.queue={}; rec.timers={}; rec.subscriptions={}
  for unit,binding in pairs(root.entities) do if binding.id==id then root.entities[unit]=nil end end
  root.computers[id]=nil; root.devices[id]=nil
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
