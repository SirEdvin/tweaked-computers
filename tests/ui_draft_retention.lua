-- Engine persistence plus table-backed GUI contracts; not native focus evidence.
local registry=require('scripts.registry')
local model=require('scripts.ui.editor-model')
local editor=require('scripts.ui.editor')
local limits=require('scripts.runtime.limits')
local contracts=require('tests.editor_contract')
local M={}
local loaded=false
local function refused(fn)
  local ok,e=pcall(fn)
  assert(not ok and e.code=='E_CAPACITY' and e.recoverable and e.setting=='tc-draft-storage-bytes')
  return e
end
function M.run()
  local root=storage.tweaked_computers; storage.tweaked_computers=nil; registry.initialize()
  local original=limits.draft_storage_bytes
  local body=assert(game.surfaces[1].create_entity{name='constant-combinator',position={0,100},force='player'})
  local rec=registry.register('computer',body); local p=contracts.player(1901,body)
  local s,d=model.open(p,rec.id)
  local large=string.rep('é',10000); local command=string.rep('q',5000)
  model.edit(p,s.token,large); model.shell_edit(p,s.token,command)
  assert(model.retention(p.index).used==128+#rec.id+#large+#command)
  model.action(p,s.token,'review-recovery',game.tick,rec.id)
  assert(model.retention(p.index).used==128+#rec.id+#large+#command,'aliased review must not double charge')
  local before=model.retention(p.index).used; limits.draft_storage_bytes=before
  local e=refused(function() model.edit(p,s.token,large..'!') end)
  assert(e.used==before and e.requested==#large+1 and d.source==large,'review retains original bytes')
  model.close(p.index,s.token); s=model.open(p,rec.id)
  assert(s.shell_draft==command and d.shell_draft==command)
  limits.draft_storage_bytes=1
  model.edit(p,s.token,'short'); model.shell_edit(p,s.token,'q')
  assert(model.retention(p.index).over_limit)
  refused(function() model.edit(p,s.token,'longer') end)
  limits.draft_storage_bytes=original
  local real_game=game
  game={tick=real_game.tick,get_player=function() return p end}
  local ok,problem=pcall(function()
    assert(editor.open(p,rec.id)); local f=p.gui.screen[editor.frame_name]
    local source=f.content.editor.source; local input=f.content.console.prompt.command
    local function event(element) return {player_index=p.index,element=element,tick=real_game.tick} end
    local function tab(n) f.content.selected_tab_index=n; editor.on_tab(event(f.content)) end
    limits.draft_storage_bytes=model.retention(p.index).used
    source.text='refused editable source'; local writes=source.text_writes
    editor.on_text(event(source)); assert(source.text_writes==writes and d.source=='short')
    editor.on_click(event(f.content.editor.actions.save)); assert(rec.saved_source=='')
    editor.on_closed(event(f)); assert(f.valid and not f.visible and source.text=='refused editable source')
    editor.on_player_unavailable{player_index=p.index}; assert(f.valid)
    assert(editor.open(p,rec.id) and p.gui.screen[editor.frame_name]==f and f.visible)
    tab(2); input.text='refused editable command'; writes=input.text_writes
    editor.on_text(event(input)); editor.on_confirmed(event(input))
    assert(input.text_writes==writes and input.text=='refused editable command' and d.shell_draft=='q' and not rec.shell)
    tab(5); editor.refresh(p); assert(source.text=='refused editable source')
    limits.draft_storage_bytes=original
    tab(1); editor.on_text(event(source)); assert(d.source==source.text and d.shell_draft==input.text)
    assert(not model.session(p.index).unretained)
    editor.on_closed(event(f)); assert(not f.valid)
  end)
  game=real_game; limits.draft_storage_bytes=original; if not ok then error(problem,0) end
  log('TC_CONTRACT ui-draft-byte-admission-refusal-editable-input-no-rewrite')
  -- Keep actual persisted documents, including more than eight and long command/source.
  for i=1,12 do
    local entity=assert(game.surfaces[1].create_entity{name='constant-combinator',position={i*3,100},force='player'})
    local other=registry.register('computer',entity); s=model.open(p,other.id)
    model.edit(p,s.token,large..i); model.shell_edit(p,s.token,command..i)
  end
  storage.tc_draft_policy={player=p.index,phase='armed',used=model.retention(p.index).used,id=s.id,source=large..12,command=command..12}
  assert(model.retention(p.index).used<original)
  log('TC_CONTRACT ui-thirteen-documents-long-source-command-no-eviction')
  log('TC_CONTRACT_TOTAL 2')
end
function M.on_load() loaded=storage.tc_draft_policy.phase=='frozen' end
function M.on_tick()
  local state=storage.tc_draft_policy
  if state.phase=='armed' then
    state.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif state.phase=='frozen' and loaded then
    loaded=false; local s,b=model.session(state.player); local n=0
    for _ in pairs(b.documents) do n=n+1 end
    assert(n==13 and model.retention(state.player).used==state.used)
    assert(b.documents[state.id].source==state.source and b.documents[state.id].shell_draft==state.command)
    assert(s.shell_draft==state.command)
    local p=contracts.player(state.player,registry.record(state.id).body)
    model.close(p.index,s.token); s=model.open(p,state.id); assert(s.shell_draft==state.command)
    state.phase='done'; log('TC_COLD_OK thirteen-drafts-full-command-source-byte-accounting')
  end
end
return M
