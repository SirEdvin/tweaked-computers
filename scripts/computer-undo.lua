-- Native history owns snapshots; only unsettled actions and exact ghosts live here.
local registry=require('scripts.registry')
local snapshots=require('scripts.lifecycle-data')
local defs=require('scripts.device-definitions')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local lifecycle=require('scripts.lifecycle')
local scheduler=require('scripts.scheduler')
local M={tag='tc_computer_undo'}
local function state()
  local root=registry.get()
  if not registry.supported(root) then return nil end
  root.computer_undo=root.computer_undo or {pending={},ghosts={},destroyed={}}
  return root.computer_undo
end
local function position(a,b) return a and b and a.x==b.x and a.y==b.y end
local function matches(a,p)
  return a.type=='removed-entity' and a.surface_index==p.surface and a.target
    and a.target.name==p.name and position(a.target.position,p.position)
    and (a.target.quality or 'normal')==p.quality
end
local fields={version=true,tick=true,operation=true,player=true,force=true,surface=true,name=true,quality=true,position=true,snapshot=true}
local function metadata(p)
  if type(p)~='table' or getmetatable(p)~=nil or p.version~=1
    or type(p.operation)~='string' or #p.operation==0 or #p.operation>limits.identifier_bytes
    or not errors.integer(p.tick,0,9007199254740991)
    or not errors.integer(p.player,1,4294967295) or not errors.integer(p.force,1,4294967295)
    or not errors.integer(p.surface,1,4294967295) or defs.by_name[p.name]~='computer'
    or type(p.quality)~='string' or #p.quality>limits.identifier_bytes
    or type(p.position)~='table' or getmetatable(p.position)~=nil
    or not errors.finite(p.position.x) or not errors.finite(p.position.y) then return false end
  for key in pairs(p) do if not fields[key] then return false end end
  for key in pairs(p.position) do if key~='x' and key~='y' then return false end end
  return true
end
local function scope(p,entity)
  if not metadata(p) then return false end
  local player=game.get_player(p.player)
  return player and player.force.index==p.force and entity.force.index==p.force
    and entity.surface.index==p.surface and position(entity.position,p.position)
    and (entity.type=='entity-ghost' and entity.ghost_name or entity.name)==p.name
    and entity.quality.name==p.quality
end
local function notice(player,message)
  log('TC computer undo refused: '..message)
  local p=player and game.get_player(player)
  if p then p.print('Computer undo refused: '..message) end
end
local function visit(player,fn)
  local s=player.undo_redo_stack
  for _,side in ipairs({'undo','redo'}) do
    for i=1,s['get_'..side..'_item_count']() do
      for j,a in ipairs(s['get_'..side..'_item'](i)) do fn(s,side,i,j,a) end
    end
  end
end
-- In 2.1.23 mining/mark callbacks precede insertion; settle at the next event/tick.
-- Exclude already-existing matching actions, never trust a retained stack index.
function M.settle()
  local s=state(); if not s then return end
  local pending={}
  for _,p in ipairs(s.pending) do
    local player=game.get_player(p.player); local found; local count=0
    if player then visit(player,function(stack,side,i,j,a)
      if side=='undo' and matches(a,p) and not (a.tags and a.tags.tc_computer_seen==p.operation) then
        count=count+1; found={stack=stack,i=i,j=j}
      end
    end) end
    if count==1 then found.stack.set_undo_tag(found.i,found.j,M.tag,p)
    elseif p.tick==game.tick then pending[#pending+1]=p
    elseif p.snapshot then notice(p.player,'matching removal action is no longer available') end
  end
  s.pending=pending
end
local function begin(rec,player_index,snapshot)
  M.settle()
  local player=player_index and game.get_player(player_index)
  if not player or player.force.index~=rec.force_index then return end
  local p={version=1,tick=game.tick,operation='tc-undo-'..string.format('%d',registry.sequence()),player=player_index,
    force=rec.force_index,surface=rec.surface_index,name=rec.body.name,quality=rec.body.quality.name,
    position={x=rec.body.position.x,y=rec.body.position.y},snapshot=snapshot}
  visit(player,function(stack,side,i,j,a)
    if side=='undo' and matches(a,p) then stack.set_undo_tag(i,j,'tc_computer_seen',p.operation) end
  end)
  local s=state(); s.pending[#s.pending+1]=p
  return p
end
function M.on_marked(event)
  local rec,role=registry.by_entity(event.entity)
  if rec and rec.kind=='computer' and role=='body' then rec.undo_action=begin(rec,event.player_index) end
end
function M.on_cancelled(event)
  local rec,role=registry.by_entity(event.entity)
  if rec and rec.kind=='computer' and role=='body' then rec.undo_action=nil end
end
function M.capture(rec,event)
  if rec.kind~='computer' then return end
  if event.name==defines.events.on_player_mined_entity and event.player_index then
    begin(rec,event.player_index,snapshots.computer_snapshot(rec,false))
  elseif event.name==defines.events.on_robot_mined_entity and rec.undo_action then
    M.settle()
    local p=rec.undo_action; local player=game.get_player(p.player)
    if not scope(p,rec.body) then return end
    local snapshot=snapshots.computer_snapshot(rec,false)
    visit(player,function(stack,side,i,j,a)
      local tag=a.tags and a.tags[M.tag]
      if type(tag)=='table' and tag.operation==p.operation and matches(a,p) then
        p.snapshot=snapshot; stack['set_'..side..'_tag'](i,j,M.tag,p)
      end
    end)
  end
end
local function bind(ghost,p,previous)
  local s=state()
  if previous then s.destroyed[previous.registration]=nil; s.ghosts[previous.unit]=nil end
  local registration=script.register_on_object_destroyed(ghost)
  s.ghosts[ghost.unit_number]={entity=ghost,unit=ghost.unit_number,registration=registration,
    operation=previous and previous.operation or p.operation,player=previous and previous.player or p.player,
    force=previous and previous.force or p.force,force_object=previous and previous.force_object or ghost.force,
    surface=ghost.surface.index,surface_object=previous and previous.surface_object or ghost.surface,name=ghost.ghost_name,
    quality=previous and previous.quality or p.quality,x=ghost.position.x,y=ghost.position.y}
  s.destroyed[registration]=ghost.unit_number
  local tags=ghost.tags or {}; tags[M.tag]=p; tags.tc_computer_ghost=ghost.unit_number
  local ok,c=pcall(snapshots.computer_settings,type(p)=='table' and p.snapshot or nil)
  if ok then tags.tc_settings={version=1,kind='computer',computer=c} end
  ghost.tags=tags
end
function M.on_ghost(event)
  local e=event.entity
  if not e or not e.valid or e.type~='entity-ghost' or defs.by_name[e.ghost_name]~='computer' then return end
  local p=e.tags and e.tags[M.tag]; local s=state()
  if not s then return end
  local interested=metadata(p) and scope(p,e)
  for _,pending in ipairs(s.pending) do
    if pending.player==event.player_index and scope(pending,e) then interested=true end
  end
  if not interested then return end
  -- The on_built notification precedes on_undo_applied. Confirm the exact object
  -- against that event's tagged action before granting restoration authority.
  s.candidates=s.candidates or {}
  s.candidates[#s.candidates+1]={entity=e,player=event.player_index,tick=event.tick}
end
local function inverse_tag(player,side,p,ghost)
  local stack=player.undo_redo_stack
  if stack['get_'..side..'_item_count']()==0 then return end
  local found,count=nil,0
  for index,a in ipairs(stack['get_'..side..'_item'](1)) do
    if a.surface_index==p.surface and a.target and position(a.target.position,p.position)
      and (ghost and a.type=='built-entity' and a.target.name=='entity-ghost' or not ghost and matches(a,p)) then
      found=index; count=count+1
    end
  end
  if count==1 then stack['set_'..side..'_tag'](1,found,M.tag,p) end
end
function M.on_applied(event)
  local s=state(); if not s then return end
  for _,a in ipairs(event.actions) do
    local p=a.tags and a.tags[M.tag]; local pending_index
    if not metadata(p) and a.type=='removed-entity' then
      local count=0
      for index,pending in ipairs(s.pending) do
        if pending.player==event.player_index and matches(a,pending)
          and not (a.tags and a.tags.tc_computer_seen==pending.operation) then
          count=count+1; p=pending; pending_index=index
        end
      end
      if count~=1 then p=nil; pending_index=nil end
    end
    if metadata(p) and p.player==event.player_index then
      if p.snapshot and matches(a,p) then
        for _,c in ipairs(s.candidates or {}) do
          local e=c.entity; local tag=e.valid and e.tags and e.tags[M.tag]
          if c.player==event.player_index and c.tick==event.tick and e.valid and scope(p,e)
            and (pending_index or type(tag)=='table' and tag.operation==p.operation) then bind(e,p) end
        end
        if pending_index then
          -- Undo can arrive before the deferred tag is written. Its verified
          -- native inverse owns the payload until redo returns the original action.
          table.remove(s.pending,pending_index)
          inverse_tag(game.get_player(event.player_index),'redo',p,true)
        end
      elseif a.type=='built-entity' and a.target and a.target.name=='entity-ghost' then
        inverse_tag(game.get_player(event.player_index),'undo',p,false)
      end
    end
  end
  s.candidates=nil
end
local function construction(binding,event)
  local e=event.entity
  return binding and (binding.retained and binding.entity==e or not binding.retained and not binding.entity.valid and event.tags and event.tags.tc_computer_ghost==binding.unit)
    and e.surface==binding.surface_object and e.surface.index==binding.surface and e.name==binding.name
    and e.position.x==binding.x and e.position.y==binding.y
end
local function hold(binding,p,body)
  local s=state(); s.destroyed[binding.registration]=nil; s.ghosts[binding.unit]=nil
  binding.entity=body; binding.unit=body.unit_number; binding.retained=true; binding.payload=p
  binding.registration=script.register_on_object_destroyed(body)
  s.ghosts[binding.unit]=binding; s.destroyed[binding.registration]=binding.unit
  body.minable_flag=false
end
function M.prepare(event)
  local s=state(); local b=s and s.ghosts[event.entity.unit_number]
  local p=event.tags and event.tags[M.tag]
  if b and b.retained and b.entity==event.entity then p=b.payload
  elseif p==nil and not (event.tags and event.tags.tc_computer_ghost) then return nil
  else b=s and s.ghosts[event.tags.tc_computer_ghost] end
  if construction(b,event) and not b.retained then hold(b,p,event.entity) end
  if not construction(b,event) or not scope(p,event.entity) or p.operation~=b.operation
    or p.player~=b.player or p.force~=b.force or event.entity.force~=b.force_object
    or p.quality~=b.quality then errors.raise('E_AUTHORITY','undo payload does not belong to this construction') end
  snapshots.import_computer(p.snapshot,false)
  return p
end
function M.apply(rec,p)
  if not p then return end
  snapshots.restore_computer(rec,p.snapshot,false)
  local s=state(); local b=s.ghosts[rec.body.unit_number]
  s.destroyed[b.registration]=nil; s.ghosts[b.unit]=nil
end
function M.recovery(event,body)
  local s=state(); local b=s and s.ghosts[body.unit_number]
  if not construction(b,event) or not b.retained then return nil end
  -- Stage recovery before destroying/refunding its exact failed body.
  local surface=game.surfaces[b.surface]
  local ok,ghost=pcall(function() return surface and surface.create_entity{name='entity-ghost',inner_name=b.name,position={x=b.x,y=b.y},direction=body.direction,
    force=body.force,quality=body.quality,create_build_effect_smoke=false} end)
  if not ok or not ghost then
    notice(b.player,'rollback allocation failed; exact inert body and payload retained for host repair')
    return false
  end
  bind(ghost,b.payload,b)
  return true
end
function M.on_removed(event)
  local e=event.entity; local s=state()
  if not s or not e or not e.valid or e.type~='entity-ghost' then return end
  local b=s.ghosts[e.unit_number]
  if b and b.entity==e then s.ghosts[b.unit]=nil; s.destroyed[b.registration]=nil end
end
function M.on_destroyed(event)
  local s=state(); if not s then return end
  local unit=s.destroyed[event.registration_number]
  if unit then s.ghosts[unit]=nil; s.destroyed[event.registration_number]=nil end
end
function M.maintain(tick)
  local root=registry.get(); local s=root and root.computer_undo
  if not s then return end
  if #s.pending>0 then M.settle() end
  s.candidates=nil
end
scheduler.register_phase('lifecycle','02-computer-undo',M.maintain)
lifecycle.register_undo_adapter(M)
return M
