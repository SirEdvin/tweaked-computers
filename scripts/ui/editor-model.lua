-- Host-only authoring state. Sessions/drafts are plain, bounded, and never guest APIs.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local compiler=require('scripts.runtime.compiler')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local M={draft_slots=8}
local function bucket(index)
  local root=registry.get()
  if not registry.supported(root) then errors.raise('E_UNSUPPORTED','unsupported storage; drafts retained') end
  local b=root.player_drafts[index]
  if not b then b={documents={}}; root.player_drafts[index]=b end
  return b
end
function M.authorized(player,rec)
  if not player or not player.valid or not rec or rec.kind~='computer' or not rec.body.valid then return false end
  local bound,role=registry.by_entity(rec.body)
  if bound~=rec or role~='body' or rec.body.force.index~=rec.force_index
    or rec.body.surface.index~=rec.surface_index or player.force.index~=rec.force_index
    or player.surface.index~=rec.surface_index or not player.can_reach_entity(rec.body) then return false end
  local group=player.permission_group
  return not group or (group.allows_action(defines.input_action.open_gui)
    and group.allows_action(defines.input_action.gui_click)
    and group.allows_action(defines.input_action.gui_text_changed))
end
function M.open(player,id)
  local rec=registry.record(id)
  if not M.authorized(player,rec) then errors.raise('E_UNREACHABLE','computer is not accessible') end
  local b=bucket(player.index); local d=b.documents[id]
  if not d then
    local n=0; for _ in pairs(b.documents) do n=n+1 end
    if n>=M.draft_slots then errors.raise('E_CAPACITY','eight recovery drafts retained; explicitly forget one before opening another computer') end
    d={source=rec.saved_source,base_source=rec.saved_source,base_revision=rec.saved_revision}
    b.documents[id]=d
  end
  local session={id=id,unit=rec.body.unit_number,generation=rec.generation,token=registry.sequence()}
  b.session=session
  return session,d
end
function M.session(index)
  local root=registry.get(); local b=root and root.player_drafts[index]
  return b and b.session,b
end
function M.current(player,token)
  local s,b=M.session(player.index)
  local rec=s and registry.record(s.id)
  if not s or s.token~=token or not M.authorized(player,rec)
    or rec.generation~=s.generation or rec.body.unit_number~=s.unit then
    errors.raise('E_UNREACHABLE','editor identity or interaction authority changed; draft retained')
  end
  return rec,b.documents[s.id],s,b
end
function M.edit(player,token,source)
  local _,d,s=M.current(player,token)
  if type(source)~='string' or #source>limits.source_bytes then errors.raise('E_LIMIT','source exceeds '..limits.source_bytes..' bytes; previous draft retained') end
  d.source=source; s.validation=nil; s.reset=nil
end
function M.action(player,token,action,tick,arg)
  local rec,d,s,b=M.current(player,token)
  if action=='validate' then
    local plan,e=compiler.compile(d.source,runtime.context(rec,tick))
    s.validation={revision=d.base_revision,kind='draft',diagnostic=e}
    if not plan then return nil,e end
    return 'Draft valid; Save before Run/Apply.'
  elseif action=='save' then
    local revision=runtime.save(rec.id,d.source,d.base_revision)
    d.base_revision=revision; d.base_source=d.source; s.review=nil
    return 'Saved revision '..revision..'; active run unchanged.'
  elseif action=='run' or action=='apply' then
    -- Never activate unseen newer text, nor pretend unsaved edits were consumed.
    if d.base_revision~=rec.saved_revision or d.source~=rec.saved_source then
      errors.raise('E_BUSY','Save your draft, or review the current saved revision before Run/Apply')
    end
    local run,e=runtime.activate(rec.id,tick,d.base_revision)
    if not run then s.validation={kind='saved',revision=d.base_revision,diagnostic=e}; return nil,e end
    s.validation=nil; s.reset=nil; return 'Activated saved revision '..rec.saved_revision..'.'
  elseif action=='stop' then
    s.reset=nil
    if not runtime.stop(rec.id) then return nil,rec.diagnostic end
    return 'Stopped; source, state and peripheral data retained.'
  elseif action=='reset' then
    if rec.status~='stopped' then errors.raise('E_BUSY','Stop the computer before Reset State') end
    s.reset={generation=rec.run_generation}; return 'Confirm Reset State to delete only this computer state.'
  elseif action=='confirm-reset' then
    if not s.reset or s.reset.generation~=rec.run_generation or rec.status~='stopped' then errors.raise('E_BUSY','reset confirmation expired; stop and review again') end
    runtime.reset_state(rec.id); s.reset=nil; return 'Computer state cleared; KV data unchanged.'
  elseif action=='cancel-reset' then s.reset=nil; return 'Reset cancelled.'
  elseif action=='review' then
    s.review={revision=rec.saved_revision,source=rec.saved_source}
    return 'Review current saved source below. Rebase retains your draft; Reload discards it.'
  elseif action=='rebase' or action=='reload' then
    local review=s.review
    if not review or review.revision~=rec.saved_revision or review.source~=rec.saved_source then
      errors.raise('E_BUSY','saved source changed since review; review again')
    end
    d.base_revision=review.revision; d.base_source=review.source
    if action=='reload' then d.source=review.source end
    s.review=nil; s.validation=nil; s.reset=nil
    return action=='rebase' and 'Draft retained and rebased; Save is still required.' or 'Loaded reviewed saved source.'
  elseif action=='recover' then
    local recovered=b.documents[arg]
    if not recovered then errors.raise('E_NOT_FOUND','recovery draft not found') end
    d.source=recovered.source; s.validation=nil; s.reset=nil
    return 'Recovery text copied into this draft; Save and Run remain separate.'
  elseif action=='forget' then
    if arg==s.id then errors.raise('E_ARGUMENT','cannot forget the open document; use reviewed Reload instead') end
    if not b.documents[arg] then errors.raise('E_NOT_FOUND','recovery draft not found') end
    -- Separate native confirmation; never silently evict a dirty or removed draft.
    s.forget=arg; return 'Confirm Forget to permanently delete the selected recovery draft.'
  elseif action=='confirm-forget' then
    if not s.forget or s.forget==s.id then errors.raise('E_BUSY','choose a recovery draft first') end
    b.documents[s.forget]=nil; s.forget=nil; return 'Selected recovery draft forgotten.'
  elseif action=='cancel-forget' then s.forget=nil; return 'Forget cancelled.'
  end
  errors.raise('E_ARGUMENT','unknown editor action')
end
function M.open_recovery(index)
  local b=bucket(index)
  local s={mode='recovery',token=registry.sequence()}; b.session=s
  return s,b
end
function M.recovery_action(index,token,action,id)
  local s,b=M.session(index)
  if not s or s.token~=token or s.mode~='recovery' then errors.raise('E_UNREACHABLE','recovery session changed') end
  if action=='review' then
    if not b.documents[id] then errors.raise('E_NOT_FOUND','draft not found') end
    s.selected=id; s.forget=nil; return 'Recovery text below can be copied; it is never activated here.'
  elseif action=='forget' then
    if not s.selected or not b.documents[s.selected] then errors.raise('E_NOT_FOUND','review a draft first') end
    s.forget=s.selected; return 'Confirm Forget to permanently delete this draft.'
  elseif action=='confirm-forget' then
    if not s.forget or s.forget~=s.selected then errors.raise('E_BUSY','review and select Forget first') end
    b.documents[s.forget]=nil; s.selected=nil; s.forget=nil; return 'Draft forgotten.'
  elseif action=='cancel-forget' then s.forget=nil; return 'Forget cancelled.' end
  errors.raise('E_ARGUMENT','unknown recovery action')
end
function M.close(index,token)
  local s,b=M.session(index)
  if not s or s.token~=token then return false end
  b.session=nil -- Documents remain even after destruction, disconnect or force changes.
  return true
end
return M
