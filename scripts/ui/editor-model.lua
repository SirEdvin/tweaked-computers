-- Host-only authoring state. Sessions/drafts are plain, bounded, and never guest APIs.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local compiler=require('scripts.runtime.compiler')
local limits=require('scripts.runtime.limits')
local errors=require('scripts.runtime.errors')
local shell=require('scripts.runtime.shell')
local M={}
-- Account UTF-8 bytes, not characters; fixed metadata is deterministic, not heap size.
local function usage(b,id,candidate,session)
  local used=0; local strings={}
  local function text(value)
    if value and not strings[value] then strings[value]=true; used=used+#value end
  end
  local function document(key,d)
    used=used+128+#key
    text(d.source); text(d.base_source); text(d.shell_draft)
  end
  for key,d in pairs(b.documents) do document(key,key==id and candidate or d) end
  if id and not b.documents[id] then document(id,candidate) end
  local s=session or b.session; local d=s and (s.id==id and candidate or b.documents[s.id])
  if d and d.shell_draft==nil then text(s.shell_draft) end
  if s then
    for _,key in ipairs({'review','active_review','recovery_review'}) do
      local review=s[key]; if review then text(review.source) end
    end
    text(s.selected_source); text(s.forget_source)
  end
  return used
end
local function merged(value,patch)
  local candidate={}; for k,v in pairs(value or {}) do candidate[k]=v end
  for k,v in pairs(patch) do candidate[k]=v end
  return candidate
end
local function admit(b,id,patch,session_patch)
  local candidate=id and merged(b.documents[id],patch or {})
  local session=session_patch and merged(b.session,session_patch)
  local before=usage(b); local after=usage(b,id,candidate,session)
  local limit=limits.draft_storage_bytes
  if after>before and (not limit or after>limit) then
    error({code='E_CAPACITY',message='Draft storage growth refused; accepted drafts and current editable input retained. Reduce text, explicitly forget a reviewed draft, or raise tc-draft-storage-bytes.',
      resource='draft_storage',setting='tc-draft-storage-bytes',used=before,requested=math.max(0,after-before),limit=limit,recoverable=true},0)
  end
  return candidate
end
local function retain_command(b)
  local s=b.session; local d=s and b.documents[s.id]
  if d and d.shell_draft==nil then d.shell_draft=s.shell_draft or '' end
end

function M.retention(index)
  local root=registry.get(); local b=root and root.player_drafts[index]
  local used=b and usage(b) or 0
  local limit=limits.draft_storage_bytes
  if not limit then return nil end
  return {used=used,limit=limit,over_limit=used>limit,unit='bytes',setting='tc-draft-storage-bytes'}
end

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
    d=admit(b,id,{source=rec.saved_source,base_source=rec.saved_source,base_revision=rec.saved_revision,shell_draft=''})
    b.documents[id]=d
  end
  retain_command(b)
  local session={id=id,unit=rec.body.unit_number,generation=rec.generation,token=registry.sequence(),shell_draft=d.shell_draft or ''}
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
  local _,d,s,b=M.current(player,token)
  if type(source)~='string' then errors.raise('E_ARGUMENT','source string required; previous draft retained') end
  admit(b,s.id,{source=source})
  d.source=source; s.validation=nil; s.reset=nil
end
function M.shell_edit(player,token,text)
  local _,d,s,b=M.current(player,token)
  if type(text)~='string' or text:find('[\r\n]') then errors.raise('E_ARGUMENT','one line required; draft retained') end
  admit(b,s.id,{shell_draft=text})
  d.shell_draft=text; s.shell_draft=text
end
function M.shell_submit(player,token,tick)
  local rec,d,s=M.current(player,token)
  if s.tab~=2 then errors.raise('E_UNREACHABLE','active Console required') end
  local id=shell.submit(rec,s.shell_draft or '',player.index,token,tick,s.shell_generation or false)
  if id then d.shell_draft=''; s.shell_draft=''; s.shell_generation=rec.shell.id end
  return id
end
function M.shell_reset(player,token,confirm)
  local rec,_,s=M.current(player,token)
  if s.tab~=2 then errors.raise('E_UNREACHABLE','active Console required') end
  local current=shell.session(rec); local generation=current and current.id or false
  if confirm==nil then s.shell_reset=generation; return end
  if not confirm then s.shell_reset=nil; return end
  if s.shell_reset==nil or s.shell_reset~=generation then errors.raise('E_BUSY','shell reset confirmation expired') end
  if not shell.reset(rec,'reset') then errors.raise('E_ENGINE','shell cleanup failed; session retained') end
  s.shell_reset=nil; s.shell_generation=false
end
function M.action(player,token,action,tick,arg)
  local rec,d,s,b=M.current(player,token)
  if action=='validate' then
    local plan,e=compiler.prepare(d.source,runtime.context(rec,tick))
    s.validation={revision=d.base_revision,kind='draft',diagnostic=e}
    if not plan then return nil,e end
    return 'Draft valid; Save before Run/Apply.'
  elseif action=='save' then
    admit(b,s.id,{base_source=d.source})
    local revision=runtime.save(rec.id,d.source,d.base_revision)
    d.base_revision=revision; d.base_source=d.source; s.review=nil
    return 'Source saved; active run unchanged.'
  elseif action=='run' or action=='apply' then
    -- Never activate unseen newer text, nor pretend unsaved edits were consumed.
    if d.base_revision~=rec.saved_revision or d.source~=rec.saved_source then
      errors.raise('E_BUSY','Save your draft, or review the current saved revision before Run/Apply')
    end
    local run,e=runtime.activate(rec.id,tick,d.base_revision)
    if not run then s.validation={kind='saved',revision=d.base_revision,diagnostic=e}; return nil,e end
    s.validation=nil; s.reset=nil; return 'Saved source activated.'
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
    admit(b,nil,nil,{review={revision=rec.saved_revision,source=rec.saved_source}})
    s.review={revision=rec.saved_revision,source=rec.saved_source}
    return 'Review current saved source below. Rebase retains your draft; Reload discards it.'
  elseif action=='rebase' or action=='reload' then
    local review=s.review
    if not review or review.revision~=rec.saved_revision or review.source~=rec.saved_source then
      errors.raise('E_BUSY','saved source changed since review; review again')
    end
    admit(b,s.id,{base_source=review.source,source=action=='reload' and review.source or d.source})
    d.base_revision=review.revision; d.base_source=review.source
    if action=='reload' then d.source=review.source end
    s.review=nil; s.validation=nil; s.reset=nil
    return action=='rebase' and 'Draft retained and rebased; Save is still required.' or 'Loaded reviewed saved source.'
  elseif action=='review-active' then
    if not rec.active then errors.raise('E_NOT_FOUND','no formerly active source snapshot retained') end
    admit(b,nil,nil,{active_review={source=rec.active.source,revision=rec.active.revision}})
    s.active_review={source=rec.active.source,revision=rec.active.revision}
    return 'Formerly active source below is recovery text, not a running program. Copy to Draft does not Save or Run.'
  elseif action=='copy-active' then
    local review=s.active_review
    if not review or not rec.active or review.source~=rec.active.source or review.revision~=rec.active.revision then
      errors.raise('E_BUSY','active source changed; review its snapshot again')
    end
    M.edit(player,token,review.source)
    return 'Formerly active source copied into the draft; Save and Run are still separate.'
  elseif action=='review-recovery' then
    local recovered=b.documents[arg]
    if not recovered then errors.raise('E_NOT_FOUND','recovery draft not found') end
    s.recovery_review={id=arg,source=recovered.source}; s.forget=nil
    return 'Review retained source before copying it into this draft or forgetting it.'
  elseif action=='recover' then
    local recovered=b.documents[arg]; local review=s.recovery_review
    if not recovered then errors.raise('E_NOT_FOUND','recovery draft not found') end
    if not review or review.id~=arg or review.source~=recovered.source then
      errors.raise('E_BUSY','review the selected recovery source before replacing this draft')
    end
    M.edit(player,token,review.source)
    return 'Recovery text copied into this draft; Save and Run remain separate.'
  elseif action=='forget' then
    if arg==s.id then errors.raise('E_ARGUMENT','cannot forget the open document; use reviewed Reload instead') end
    if not b.documents[arg] then errors.raise('E_NOT_FOUND','recovery draft not found') end
    local review=s.recovery_review
    if not review or review.id~=arg or review.source~=b.documents[arg].source then
      errors.raise('E_BUSY','review the selected recovery draft before forgetting it')
    end
    -- Identity and reviewed bytes are checked again at the destructive boundary.
    s.forget=arg; s.forget_source=review.source
    return 'Confirm Forget to permanently delete the reviewed recovery draft.'
  elseif action=='confirm-forget' then
    if not s.forget or s.forget==s.id or not b.documents[s.forget]
      or b.documents[s.forget].source~=s.forget_source then errors.raise('E_BUSY','forget confirmation expired; review again') end
    b.documents[s.forget]=nil; s.forget=nil; s.forget_source=nil; s.recovery_review=nil
    return 'Selected recovery draft forgotten.'
  elseif action=='cancel-forget' then s.forget=nil; s.forget_source=nil; return 'Forget cancelled.'
  end
  errors.raise('E_ARGUMENT','unknown editor action')
end
function M.open_recovery(index)
  local b=bucket(index)
  retain_command(b)
  local s={mode='recovery',token=registry.sequence()}; b.session=s
  return s,b
end
function M.recovery_action(index,token,action,id)
  local s,b=M.session(index)
  if not s or s.token~=token or s.mode~='recovery' then errors.raise('E_UNREACHABLE','recovery session changed') end
  if action=='review' then
    if not b.documents[id] then errors.raise('E_NOT_FOUND','draft not found') end
    s.selected=id; s.selected_source=b.documents[id].source; s.forget=nil
    return 'Recovery text below can be copied; it is never activated here.'
  elseif action=='forget' then
    if not s.selected or not b.documents[s.selected] then errors.raise('E_NOT_FOUND','review a draft first') end
    if b.documents[s.selected].source~=s.selected_source then errors.raise('E_BUSY','draft changed; review again') end
    s.forget=s.selected; s.forget_source=s.selected_source
    return 'Confirm Forget to permanently delete this draft.'
  elseif action=='confirm-forget' then
    if not s.forget or s.forget~=s.selected or not b.documents[s.forget]
      or b.documents[s.forget].source~=s.forget_source then errors.raise('E_BUSY','review and select Forget first') end
    b.documents[s.forget]=nil; s.selected=nil; s.selected_source=nil; s.forget=nil; s.forget_source=nil
    return 'Draft forgotten.'
  elseif action=='cancel-forget' then s.forget=nil; s.forget_source=nil; return 'Forget cancelled.' end
  errors.raise('E_ARGUMENT','unknown recovery action')
end
function M.close(index,token)
  local s,b=M.session(index)
  if not s or s.token~=token then return false end
  retain_command(b)
  b.session=nil -- Documents remain even after destruction, disconnect or force changes.
  return true
end
return M
