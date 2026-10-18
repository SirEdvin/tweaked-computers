-- Host-only execution identity. Never forge a running computer to borrow APIs.
local registry=require('scripts.registry')
local errors=require('scripts.runtime.errors')
local M={}
local cleanup={}
function M.program(c) return {kind='program',id=c.run_id} end
function M.shell(c) return {kind='shell',id=c.shell and c.shell.id} end
function M.live(c,p)
  if not c or registry.record(c.id)~=c or not c.body.valid then return false end
  if p.kind=='program' then return c.status=='running' and c.run_id==p.id end
  return p.kind=='shell' and c.shell and c.shell.version==1 and c.shell.id==p.id
end
function M.check(c,p)
  if not M.live(c,p) or not c.powered then errors.raise('E_NOT_FOUND','execution owner no longer active or powered') end
end
function M.owner(c,p,wire,path)
  return {computer_id=c.id,kind=p.kind,run_id=p.id,wire=wire,path=path}
end
function M.matches(owner,c,p)
  return type(owner)=='table' and owner.computer_id==c.id and (owner.kind or 'program')==p.kind and owner.run_id==p.id
end
function M.selection(c,p)
  if p.kind=='shell' then return c.shell end
  return c
end
function M.register_cleanup(name,fn) assert(not cleanup[name]); cleanup[name]=fn end
function M.cleanup(c,p,reason)
  local names={}; for name in pairs(cleanup) do names[#names+1]=name end; table.sort(names)
  local failed=false
  for _,name in ipairs(names) do if not pcall(cleanup[name],c,p,reason) then failed=true end end
  return not failed
end
return M
