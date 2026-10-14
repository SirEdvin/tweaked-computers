-- Packaged-engine contract checks. GUI/player tables are mocks, never client evidence.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local model=require('scripts.ui.editor-model')
local editor=require('scripts.ui.editor')
local limits=require('scripts.runtime.limits')
local M={}
local function source(value)
  return 'return {api_version=1,handlers={start=function(e) computer.setState("value",'..value..'); computer.log("started") end}}'
end
local function refused(fn,code)
  local ok,e=pcall(fn); assert(not ok and type(e)=='table' and e.code==code,'expected '..code)
end
local function gui(parent,spec)
  local e={valid=true,parent=parent,children={},type=spec.type,name=spec.name or '',style={},tags=spec.tags or {},
    text=spec.text or '',caption=spec.caption,visible=spec.visible~=false,items=spec.items or {},selected_index=0}
  function e.add(child)
    assert(not (child.type=='scroll-pane' and child.direction),'invalid scroll-pane direction')
    local c=gui(e,child)
    table.insert(e.children,child.index or (#e.children+1),c); e[c.name]=c; return c
  end
  function e.destroy()
    for i=#e.children,1,-1 do e.children[i].destroy() end
    e.valid=false
    if e.parent then
      if e.parent[e.name]==e then e.parent[e.name]=nil end
      for i,c in ipairs(e.parent.children) do if c==e then table.remove(e.parent.children,i); break end end
    end
  end
  function e.get_index_in_parent() for i,c in ipairs(e.parent.children) do if c==e then return i end end end
  function e.force_auto_center() e.centered=true end
  function e.focus() e.focused=true end
  return e
end
function M.player(index,body)
  return {index=index,valid=true,force=body.force,surface=body.surface,can_reach_entity=function() return true end,
    display_resolution={width=1280,height=900},display_scale=1,gui={screen=gui(nil,{type='flow'})},print=function() end}
end
function M.run()
  local host_storage=storage.tweaked_computers
  storage.tweaked_computers=nil; registry.initialize()
  local groups=0; local tick=100
  local function group(name,fn) tick=tick+1; fn(); groups=groups+1; log('TC_CONTRACT '..name) end
  local function make(x)
    return registry.register('computer',assert(game.surfaces[1].create_entity{name='constant-combinator',position={x,80},force='player'}))
  end
  local rec=make(0); local a=M.player(1001,rec.body); local b=M.player(1002,rec.body)
  local sa,da=model.open(a,rec.id); local sb,db=model.open(b,rec.id)
  group('editor-native-model-draft-save-active-consumption',function()
    model.edit(a,sa.token,source(7)); assert(rec.saved_revision==0 and not rec.active)
    assert(model.action(a,sa.token,'validate',tick)); assert(rec.saved_revision==0 and not rec.active and next(rec.state)==nil)
    model.action(a,sa.token,'save',tick); assert(rec.saved_source==da.source and rec.status=='stopped')
    assert(model.action(a,sa.token,'run',tick)); assert(rec.active.source==da.source and rec.active.revision==1)
    assert(scheduler.dispatch(rec,tick+1)); assert(rec.state.value==7 and rec.status=='running')
    model.edit(a,sa.token,source(9)); model.action(a,sa.token,'save',tick+2)
    assert(rec.active.revision==1 and rec.active.source==source(7) and rec.saved_revision==2)
  end)
  group('editor-two-player-conflict-reviewed-rebase-and-recheck',function()
    model.edit(b,sb.token,source(11))
    refused(function() model.action(b,sb.token,'save',tick) end,'E_BUSY')
    assert(db.source==source(11) and rec.saved_source==source(9))
    model.action(b,sb.token,'review',tick)
    runtime.save(rec.id,source(13),rec.saved_revision)
    refused(function() model.action(b,sb.token,'rebase',tick) end,'E_BUSY')
    assert(db.base_revision==0 and db.source==source(11))
    model.action(b,sb.token,'review',tick); model.action(b,sb.token,'rebase',tick)
    assert(db.base_revision==rec.saved_revision and db.source==source(11))
    model.action(b,sb.token,'save',tick); assert(rec.saved_source==source(11) and rec.active.revision==1)
    model.action(a,sa.token,'review',tick); model.action(a,sa.token,'reload',tick)
    assert(da.source==rec.saved_source and da.base_revision==rec.saved_revision)
  end)
  group('editor-invalid-replacement-preserves-generation-state',function()
    local run=rec.run_id; local active=rec.active
    for _,candidate in ipairs({'return {','return {api_version=1,handlers={start=function(e) game.print("escape") end}}'}) do
      tick=tick+1; model.edit(a,sa.token,candidate); model.action(a,sa.token,'save',tick)
      local value,e=model.action(a,sa.token,'apply',tick)
      assert(not value and type(e)=='table' and rec.active==active and rec.run_id==run and rec.status=='running' and rec.state.value==7)
    end
    model.edit(a,sa.token,source(17))
    refused(function() model.action(a,sa.token,'run',tick) end,'E_BUSY')
    model.action(a,sa.token,'save',tick+1); assert(model.action(a,sa.token,'apply',tick+1))
    assert(rec.state.value==7 and rec.active.source==source(17))
    assert(scheduler.dispatch(rec,tick+2) and rec.state.value==17)
  end)
  group('editor-reset-explicit-stopped-confirmation',function()
    refused(function() model.action(a,sa.token,'reset',tick) end,'E_BUSY')
    model.action(a,sa.token,'stop',tick); assert(rec.state.value==17)
    refused(function() model.action(a,sa.token,'confirm-reset',tick) end,'E_BUSY')
    model.action(a,sa.token,'reset',tick); model.action(a,sa.token,'cancel-reset',tick)
    assert(rec.state.value==17)
    model.action(a,sa.token,'reset',tick); assert(model.action(a,sa.token,'run',tick+1))
    refused(function() model.action(a,sa.token,'confirm-reset',tick) end,'E_BUSY')
    model.action(a,sa.token,'stop',tick); model.action(a,sa.token,'reset',tick)
    model.action(a,sa.token,'confirm-reset',tick); assert(next(rec.state)==nil and rec.saved_source==source(17))
  end)
  group('editor-authority-body-session-source-size',function()
    a.permission_group={allows_action=function() return false end}
    refused(function() model.action(a,sa.token,'save',tick) end,'E_UNREACHABLE'); a.permission_group=nil
    a.force={index=123456}; refused(function() model.edit(a,sa.token,'bad') end,'E_UNREACHABLE'); a.force=rec.body.force
    a.can_reach_entity=function() return false end
    refused(function() model.action(a,sa.token,'stop',tick) end,'E_UNREACHABLE'); a.can_reach_entity=function() return true end
    local previous=da.source
    refused(function() model.edit(a,sa.token,string.rep('x',limits.source_bytes+1)) end,'E_LIMIT')
    assert(da.source==previous)
    local fresh=model.open(a,rec.id)
    refused(function() model.edit(a,sa.token,'stale') end,'E_UNREACHABLE'); sa=fresh
    local unit=rec.body.unit_number; local binding=registry.get().entities[unit]
    registry.get().entities[unit]={id='missing',role='body'}
    refused(function() model.action(a,sa.token,'save',tick) end,'E_UNREACHABLE')
    registry.get().entities[unit]=binding; assert(rec.saved_source==previous)
  end)
  group('editor-eight-drafts-no-eviction-removed-recovery',function()
    local p=M.player(1003,rec.body); local ids={}
    for i=1,8 do local other=make(i*3); ids[i]=other.id; local s=model.open(p,other.id); model.edit(p,s.token,source(i)) end
    local extra=make(30)
    refused(function() model.open(p,extra.id) end,'E_CAPACITY')
    local s,bag=model.open_recovery(p.index)
    assert(model.recovery_action(p.index,s.token,'review',ids[1])); assert(bag.documents[ids[1]].source==source(1))
    assert(registry.remove(ids[1])); assert(bag.documents[ids[1]].source==source(1))
    model.recovery_action(p.index,s.token,'forget'); model.recovery_action(p.index,s.token,'cancel-forget')
    assert(bag.documents[ids[1]])
    model.recovery_action(p.index,s.token,'forget'); model.recovery_action(p.index,s.token,'confirm-forget')
    assert(not bag.documents[ids[1]]); assert(model.open(p,extra.id))
  end)
  group('editor-removed-body-replacement-never-retargets-draft',function()
    local old=make(36); local p=M.player(1004,old.body)
    local s,d=model.open(p,old.id); model.edit(p,s.token,source(37))
    assert(registry.remove(old.id)); local replacement=registry.register('computer',old.body)
    assert(replacement.id~=old.id)
    refused(function() model.action(p,s.token,'save',tick) end,'E_UNREACHABLE')
    assert(replacement.saved_revision==0 and replacement.saved_source=='' and d.source==source(37))
    local next_session=model.open(p,replacement.id)
    model.action(p,next_session.token,'recover',tick,old.id)
    assert(replacement.saved_source=='' and replacement.status=='stopped')
    assert(model.session(p.index).id==replacement.id)
  end)
  local real_game=game
  local ok,e=pcall(function()
    game={get_player=function(index) if index==a.index then return a elseif index==b.index then return b end end,
      connected_players={a,b},tick=real_game.tick}
    local function click(p,element) editor.on_click{player_index=p.index,element=element,tick=tick} end
    local function edit(p,f,text) f.content.source.text=text; editor.on_text{player_index=p.index,element=f.content.source,tick=tick} end
    group('editor-mocked-native-buttons-through-real-runtime',function()
      assert(editor.open(a,rec.id)); local f=a.gui.screen[editor.frame_name]
      edit(a,f,source(23)); click(a,f.content.actions.save)
      assert(rec.saved_source==source(23) and rec.status=='stopped')
      tick=tick+1; click(a,f.content.actions.run)
      assert(rec.active.source==source(23) and scheduler.dispatch(rec,tick+1) and rec.state.value==23)
      assert(f.content.source.focused and f.content.source.style.rich_text_setting==defines.rich_text_setting.disabled)
      assert(f.content.output.read_only and f.content.output.style.rich_text_setting==defines.rich_text_setting.disabled)
      assert(f.content.help_panel.help_text.read_only and f.content.help_panel.template_text.text:find('api_version',1,true))
      click(a,f.content.actions.help); assert(f.content.help_panel.visible)
    end)
    group('editor-mocked-inactive-forged-cross-player-events',function()
      local f=a.gui.screen[editor.frame_name]; local run=rec.run_id; local saved=rec.saved_revision
      a.opened={another_gui=true}; click(a,f.content.actions.stop); edit(a,f,'forged')
      assert(rec.run_id==run and rec.status=='running' and rec.saved_revision==saved)
      a.opened=f; click(b,f.content.actions.stop); assert(rec.status=='running')
      local fake=gui(nil,{type='button',name='stop'}); click(a,fake); assert(rec.status=='running')
      a.permission_group={allows_action=function() return false end}; click(a,f.content.actions.stop)
      assert(rec.status=='running'); a.permission_group=nil
    end)
    group('editor-mocked-dirty-close-reopen-bounds-and-layout',function()
      local f=a.gui.screen[editor.frame_name]
      edit(a,f,source(29)); local saved=rec.saved_source
      click(a,f.content.actions.close); assert(not f.valid and rec.saved_source==saved and rec.status=='running')
      assert(editor.open(a,rec.id)); f=a.gui.screen[editor.frame_name]; assert(f.content.source.text==source(29))
      edit(a,f,string.rep('x',limits.source_bytes+1)); assert(f.content.source.text==source(29))
      f.content.recovery.selected_index=1; editor.refresh(a); assert(f.content.recovery.selected_index==1)
      for i=1,limits.console_entries+4 do runtime.log(rec,'[font=anything]'..i,tick) end
      editor.refresh(a); assert(#rec.logs==limits.console_entries and f.content.output.text:find('older output discarded',1,true))
      a.display_resolution={width=480,height=420}; a.display_scale=1.5
      local before=a.opened; editor.on_size{player_index=a.index}
      assert(a.opened==before and f.style.width==300 and f.content.actions.children[1].name=='validate')
      editor.on_closed{player_index=a.index,element=f}; assert(not f.valid)
      local _,bag=model.session(a.index); assert(bag.documents[rec.id].source==source(29))
      assert(editor.open(a,rec.id)); editor.on_player_unavailable{player_index=a.index}
      local _,after=model.session(a.index); assert(after.documents[rec.id].source==source(29))
    end)
    group('editor-mocked-recovery-panel-never-executes',function()
      local oldrun=rec.run_id; editor.open_recovery(a)
      local f=a.gui.screen[editor.frame_name]; f.content.recovery.selected_index=1
      click(a,f.content.recovery_actions.review)
      assert(f.content.review.text==source(29) and f.content.review.read_only and rec.run_id==oldrun)
      click(a,f.content.recovery_actions.forget); assert(f.content.confirm_forget.visible)
      click(a,f.content.confirm_forget['cancel-forget']); assert(f.content.review.text==source(29))
      click(a,f.content.recovery_actions.close)
    end)
  end)
  game=real_game
  if not ok then error(e,0) end
  group('editor-malicious-active-source-faults-healthy-peer-continues',function()
    local bad=make(40); local good=make(45)
    runtime.save(bad.id,'return {api_version=1,handlers={start=function(e) pcall(function() while true do end end) end}}',0)
    runtime.save(good.id,source(31),0)
    assert(runtime.activate(bad.id,tick)); assert(runtime.activate(good.id,tick))
    assert(scheduler.dispatch(bad,tick+1)); assert(bad.status=='faulted' and bad.diagnostic.code=='E_BUDGET')
    assert(scheduler.dispatch(good,tick+1)); assert(good.state.value==31 and good.status=='running')
  end)
  storage.tweaked_computers=host_storage
  log('TC_CONTRACT_TOTAL '..groups)
end
M.source=source
return M
