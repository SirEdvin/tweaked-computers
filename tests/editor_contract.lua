-- Packaged-engine contract checks. GUI/player tables are mocks, never client evidence.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local model=require('scripts.ui.editor-model')
local editor=require('scripts.ui.editor')
local limits=require('scripts.runtime.limits')
local help=require('scripts.ui.help')
local M={}
local function source(value)
  return 'return {api_version=1,handlers={start=function(e) computer.setState("value",'..value..'); computer.log("started") end}}'
end
local function refused(fn,code)
  local ok,e=pcall(fn); assert(not ok and type(e)=='table' and e.code==code,'expected '..code)
end
-- Fail-closed coverage of the GUI surface this mod uses, audited against
-- https://lua-api.factorio.com/2.0.77/runtime-api.json and core/prototypes/style.lua.
-- textfield and text-box both use TextBoxStyle. Extend deliberately for new APIs;
-- do not let a permissive table accept engine-incompatible GUI code again.
local function names(text)
  local out={}; for name in text:gmatch('%S+') do out[name]=true end; return out
end
local common_style=names('height width size minimal_height maximal_height minimal_width maximal_width horizontally_stretchable')
local text_style=names('label text-box textfield button tab checkbox')
local common_args=names('type name caption tooltip enabled visible style tags index')
local type_args={
  flow=names('direction'),frame=names('direction'),label={},button=names('mouse_button_filter'),
  ['text-box']=names('text'),textfield=names('text'),['empty-widget']={},
  ['tabbed-pane']={},tab={},['scroll-pane']=names('horizontal_scroll_policy vertical_scroll_policy'),
  ['drop-down']=names('items selected_index'),checkbox=names('state'),sprite=names('sprite'),
  ['table']=names('column_count'),['sprite-button']=names('sprite number quality')}
local style_types={tc_editor_text='text-box',tc_editor_button='button',tc_editor_frame='frame',
  tc_editor_tabs='tabbed-pane',tc_editor_tab='tab',draggable_space_header='empty-widget',
  deep_scroll_pane='scroll-pane',slot_table='table'}
for _,kind in ipairs({'heading','prose','signature','code'}) do style_types['tc_reference_'..kind]='text-box' end
for _,style in ipairs({'compact_slot','red_circuit_network_content_slot','green_circuit_network_content_slot'}) do style_types[style]='sprite-button' end
local reserved=names([[
  allow_decimal allow_negative allow_none_state anchor auto_center auto_toggle badge_text caption children children_names
  clicked_sprite column_count direction drag_target draw_horizontal_line_after_headers draw_horizontal_lines draw_vertical_lines
  elem_filters elem_tooltip elem_type elem_value enabled entity force game_controller_interaction gui horizontal_scroll_policy
  hovered_sprite icon_selector ignored_by_interaction index is_password items left_label_caption left_label_tooltip location locked
  lose_focus_on_confirm minimap_player_index mouse_button_filter name number numeric object_name parent player_index position quality
  raise_hover_events read_only resize_to_sprite right_label_caption right_label_tooltip selectable selected_index selected_tab_index
  show_percent_for_small_numbers slider_value sprite state style surface_index switch_state tabs tags text toggled tooltip type valid
  value vertical_centering vertical_scroll_policy visible word_wrap zoom add add_item add_tab bring_to_front clear clear_items
  close_dropdown destroy focus force_auto_center get_index_in_parent get_item get_mod get_slider_discrete_values get_slider_maximum
  get_slider_minimum get_slider_value_step remove_item remove_tab scroll_to_bottom scroll_to_element scroll_to_item scroll_to_left
  scroll_to_right scroll_to_top select select_all set_item set_slider_discrete_values set_slider_minimum_maximum set_slider_value_step swap_children
]])
local function style_supported(spec,key)
  if common_style[key] then return true end
  if key=='font' then return text_style[spec.type] end
  if key=='single_line' then return spec.type=='label' end
  if key=='rich_text_setting' then return spec.type=='label' or spec.type=='text-box' or spec.type=='textfield' end
  if key=='horizontal_spacing' then return spec.type=='table' or (spec.type=='flow' and spec.direction~='vertical') end
  if key=='vertical_spacing' then return spec.type=='table' or spec.type=='tabbed-pane' or (spec.type=='flow' and spec.direction=='vertical') end
  error('unaudited LuaStyle property '..key)
end
local function gui(parent,spec)
  local args=assert(type_args[spec.type],'unaudited GUI element type '..tostring(spec.type))
  for key in pairs(spec) do assert(common_args[key] or args[key],'invalid '..spec.type..' constructor field '..key) end
  assert(not spec.name or not reserved[spec.name],'GUI child shadows LuaGuiElement API: '..tostring(spec.name))
  assert(not parent or not spec.name or not parent[spec.name],'duplicate GUI child '..tostring(spec.name))
  assert(not spec.direction or spec.direction=='horizontal' or spec.direction=='vertical','invalid GUI direction')
  assert(not spec.style or style_types[spec.style]==spec.type,'unaudited or incompatible GUI style '..tostring(spec.style))
  if spec.type=='checkbox' then assert(type(spec.state)=='boolean','checkbox requires state') end
  if spec.type=='table' then assert(type(spec.column_count)=='number' and spec.column_count>0,'table requires columns') end
  -- Pinned LuaStyle height/width/size are write-only aliases. Catch accidental
  -- use of these as getters, and text-only rich-text settings on button styles.
  local style_values={}
  local style=setmetatable({},{__index=function(_,key)
    assert(key~='height' and key~='width' and key~='size','write-only LuaStyle getter '..key)
    style_supported(spec,key)
    return style_values[key]
  end,__newindex=function(_,key,value)
    assert(style_supported(spec,key),'unsupported '..key..' on '..spec.type..'/'..(spec.direction or 'horizontal'))
    if key=='height' then style_values.minimal_height=value; style_values.maximal_height=value
    elseif key=='width' then style_values.minimal_width=value; style_values.maximal_width=value
    elseif key=='size' then
      local w=type(value)=='table' and value[1] or value; local h=type(value)=='table' and value[2] or value
      style_values.minimal_height=h; style_values.maximal_height=h; style_values.minimal_width=w; style_values.maximal_width=w
    else style_values[key]=value end
  end})
  local e={valid=true,parent=parent,children={},type=spec.type,_name=spec.name or '',direction=spec.direction,style=style,tags=spec.tags or {},
    _text=spec.text or '',text_writes=0,caption=spec.caption,visible=spec.visible~=false,enabled=true,
    items=spec.items or {},selected_index=spec.selected_index or 0,state=spec.state,sprite=spec.sprite,tabs={}}
  setmetatable(e,{__index=function(t,k)
    if k=='text' then return rawget(t,'_text') elseif k=='name' then return rawget(t,'_name') end
  end,__newindex=function(t,k,v)
    if k=='text' then rawset(t,'_text',v); t.text_writes=t.text_writes+1
    elseif k=='name' then
      assert(type(v)=='string' and (not parent or not parent[v] or parent[v]==t),'duplicate GUI name')
      if parent and parent[t.name]==t then parent[t.name]=nil end
      rawset(t,'_name',v); if parent and v~='' then parent[v]=t end
    else rawset(t,k,v) end
  end})
  function e.add(child)
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
  function e.swap_children(a,b) e.children[a],e.children[b]=e.children[b],e.children[a] end
  function e.force_auto_center() e.centered=true end
  function e.focus() e.focused=true end
  function e.clear() for i=#e.children,1,-1 do e.children[i].destroy() end end
  function e.add_tab(tab,content) e.tabs[#e.tabs+1]={tab=tab,content=content} end
  function e.scroll_to_bottom() e.scrolls=(e.scrolls or 0)+1 end
  function e.scroll_to_top() e.top_scrolls=(e.top_scrolls or 0)+1 end
  function e.scroll_to_left() e.left_scrolls=(e.left_scrolls or 0)+1 end
  function e.select(first,last) e.selection={first,last} end
  function e.select_all() e.selection={1,#e.text} end
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
  group('editor-gui-api-guards-reject-invalid-spacing-style-and-construction',function()
    local function rejects(fn)
      local ok=pcall(fn); assert(not ok,'GUI API guard accepted an invalid operation')
    end
    for _,direction in ipairs({'horizontal','vertical'}) do
      local e=gui(nil,{type='flow',direction=direction})
      local valid=direction..'_spacing'; local invalid=direction=='horizontal' and 'vertical_spacing' or 'horizontal_spacing'
      e.style[valid]=4; assert(e.style[valid]==4)
      rejects(function() e.style[invalid]=4 end)
    end
    local default=gui(nil,{type='flow'}); default.style.horizontal_spacing=4
    rejects(function() default.style.vertical_spacing=4 end)
    for _,kind in ipairs({'label','button','frame','text-box','scroll-pane','tab','sprite','empty-widget','textfield'}) do
      local e=gui(nil,{type=kind})
      rejects(function() e.style.horizontal_spacing=4 end)
      rejects(function() e.style.vertical_spacing=4 end)
    end
    for _,kind in ipairs({'label','text-box','textfield'}) do
      local e=gui(nil,{type=kind}); e.style.rich_text_setting=defines.rich_text_setting.disabled
    end
    local b=gui(nil,{type='button'})
    rejects(function() b.style.rich_text_setting=defines.rich_text_setting.disabled end)
    rejects(function() b.style.single_line=true end)
    rejects(function() b.style.unknown_property=true end)
    b.style.size={24,28}; assert(b.style.minimal_width==24 and b.style.maximal_height==28)
    for _,key in ipairs({'height','width','size'}) do rejects(function() return b.style[key] end) end
    for key in pairs(reserved) do rejects(function() gui(nil,{type='label',name=key}) end) end
    rejects(function() gui(nil,{type='scroll-pane',direction='vertical'}) end)
    rejects(function() gui(nil,{type='label',text='not a textfield'}) end)
    rejects(function() gui(nil,{type='flow',direction='diagonal'}) end)
    rejects(function() gui(nil,{type='button',style='tc_editor_text'}) end)
    rejects(function() gui(nil,{type='checkbox'}) end)
    default.add{type='label',name='unique'}
    rejects(function() default.add{type='label',name='unique'} end)
  end)
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
    local allowance=limits.draft_storage_bytes; limits.draft_storage_bytes=model.retention(a.index).used
    refused(function() model.edit(a,sa.token,string.rep('x',#previous+1)) end,'E_CAPACITY')
    limits.draft_storage_bytes=allowance
    assert(da.source==previous)
    local fresh=model.open(a,rec.id)
    refused(function() model.edit(a,sa.token,'stale') end,'E_UNREACHABLE'); sa=fresh
    local unit=rec.body.unit_number; local binding=registry.get().entities[unit]
    registry.get().entities[unit]={id='missing',role='body'}
    refused(function() model.action(a,sa.token,'save',tick) end,'E_UNREACHABLE')
    registry.get().entities[unit]=binding; assert(rec.saved_source==previous)
  end)
  group('editor-more-than-eight-drafts-byte-admission-no-eviction-removed-recovery',function()
    local p=M.player(1003,rec.body); local ids={}
    for i=1,10 do local other=make(i*3); ids[i]=other.id; local s=model.open(p,other.id); model.edit(p,s.token,source(i)) end
    local extra=make(33)
    local allowance=limits.draft_storage_bytes; limits.draft_storage_bytes=model.retention(p.index).used
    refused(function() model.open(p,extra.id) end,'E_CAPACITY')
    local s,bag=model.open_recovery(p.index)
    assert(model.recovery_action(p.index,s.token,'review',ids[1])); assert(bag.documents[ids[1]].source==source(1))
    assert(registry.remove(ids[1])); assert(bag.documents[ids[1]].source==source(1))
    model.recovery_action(p.index,s.token,'forget'); model.recovery_action(p.index,s.token,'cancel-forget')
    assert(bag.documents[ids[1]])
    model.recovery_action(p.index,s.token,'forget'); model.recovery_action(p.index,s.token,'confirm-forget')
    assert(not bag.documents[ids[1]]); assert(model.open(p,extra.id))
    limits.draft_storage_bytes=allowance
  end)
  group('editor-removed-body-replacement-never-retargets-draft',function()
    local old=make(36); local p=M.player(1004,old.body)
    local s,d=model.open(p,old.id); model.edit(p,s.token,source(37))
    assert(registry.remove(old.id)); local replacement=registry.register('computer',old.body)
    assert(replacement.id~=old.id)
    refused(function() model.action(p,s.token,'save',tick) end,'E_UNREACHABLE')
    assert(replacement.saved_revision==0 and replacement.saved_source=='' and d.source==source(37))
    local next_session=model.open(p,replacement.id)
    model.action(p,next_session.token,'review-recovery',tick,old.id)
    model.action(p,next_session.token,'recover',tick,old.id)
    assert(replacement.saved_source=='' and replacement.status=='stopped')
    assert(model.session(p.index).id==replacement.id)
  end)
  local real_game=game
  local ok,e=pcall(function()
    game={get_player=function(index) if index==a.index then return a elseif index==b.index then return b end end,
      connected_players={a,b},tick=real_game.tick}
    local function click(p,element) editor.on_click{player_index=p.index,element=element,tick=tick} end
    local function edit(p,f,text) f.content.editor.source.text=text; editor.on_text{player_index=p.index,element=f.content.editor.source,tick=tick} end
    group('editor-mocked-native-buttons-through-real-runtime',function()
      assert(editor.open(a,rec.id)); local f=a.gui.screen[editor.frame_name]
      edit(a,f,source(23)); click(a,f.content.editor.actions.save)
      assert(rec.saved_source==source(23) and rec.status=='stopped')
      tick=tick+1; click(a,f.content.editor.actions.activate)
      assert(rec.active.source==source(23) and scheduler.dispatch(rec,tick+1) and rec.state.value==23)
      assert(f.content.editor.source.focused and f.content.editor.source.style.rich_text_setting==defines.rich_text_setting.disabled)
      assert(f.content.console.output.read_only and f.content.console.output.style.rich_text_setting==defines.rich_text_setting.disabled)
      assert(f.content.reference.reference_text.type=='scroll-pane' and #f.content.tabs==5)
      for _,part in ipairs(f.content.reference.reference_text.children) do assert(part.type=='text-box' and part.read_only) end
    end)
    group('editor-mocked-inactive-forged-cross-player-events',function()
      local f=a.gui.screen[editor.frame_name]; local run=rec.run_id; local saved=rec.saved_revision
      a.opened={another_gui=true}; click(a,f.content.editor.actions.stop); edit(a,f,'forged')
      assert(rec.run_id==run and rec.status=='running' and rec.saved_revision==saved)
      a.opened=f; click(b,f.content.editor.actions.stop); assert(rec.status=='running')
      local fake=gui(nil,{type='button',name='stop'}); click(a,fake); assert(rec.status=='running')
      a.permission_group={allows_action=function() return false end}; click(a,f.content.editor.actions.stop)
      assert(rec.status=='running'); a.permission_group=nil
    end)
    group('editor-mocked-dirty-close-reopen-bounds-and-layout',function()
      local f=a.gui.screen[editor.frame_name]
      edit(a,f,source(29)); local saved=rec.saved_source
      click(a,f.title.close); assert(not f.valid and rec.saved_source==saved and rec.status=='running')
      assert(editor.open(a,rec.id)); f=a.gui.screen[editor.frame_name]; assert(f.content.editor.source.text==source(29))
      local allowance=limits.draft_storage_bytes; limits.draft_storage_bytes=model.retention(a.index).used
      local rejected=string.rep('x',#source(29)+1)
      edit(a,f,rejected); assert(f.content.editor.source.text==rejected and model.session(a.index).unretained)
      click(a,f.content.editor.actions.save); assert(rec.saved_source==saved)
      click(a,f.title.close); assert(f.valid and f.content.editor.source.text==rejected)
      limits.draft_storage_bytes=allowance; edit(a,f,source(29))
      f.content.selected_tab_index=5; editor.on_tab{player_index=a.index,element=f.content,tick=tick}
      f.content.maintenance.recovery.selected_index=1; editor.refresh(a); assert(f.content.maintenance.recovery.selected_index==1)
      for i=1,limits.console_entries+4 do runtime.log(rec,'[font=anything]'..i,tick) end
      f.content.selected_tab_index=2; editor.on_tab{player_index=a.index,element=f.content,tick=tick}
      editor.refresh(a); assert(#rec.logs==limits.console_entries and f.content.console.output.tooltip[1]=='tc-editor.console-bounded')
      assert(not f.content.console.output.text:find('Rolling console:',1,true) and not f.content.reference['copy-note'])
      assert(rec.log_truncated and f.content.console.note.visible and f.content.console.note.caption[1]=='tc-editor.console-truncated')
      a.display_resolution={width=480,height=420}; a.display_scale=1.5
      local before=a.opened; editor.on_size{player_index=a.index}
      assert(a.opened==before and f.style.minimal_width==288 and f.content.editor.actions.children[1].name=='validate')
      editor.on_closed{player_index=a.index,element=f}; assert(not f.valid)
      local _,bag=model.session(a.index); assert(bag.documents[rec.id].source==source(29))
      assert(editor.open(a,rec.id)); editor.on_player_unavailable{player_index=a.index}
      local _,after=model.session(a.index); assert(after.documents[rec.id].source==source(29))
    end)
    group('editor-mocked-recovery-panel-never-executes',function()
      local oldrun=rec.run_id; editor.open_recovery(a)
      local f=a.gui.screen[editor.frame_name]; local c=f.recovery_content; c.recovery.selected_index=1
      click(a,c.actions.review)
      assert(c.review.text==source(29) and c.review.read_only and rec.run_id==oldrun)
      click(a,c.actions.forget); assert(c.confirm_forget.visible)
      click(a,c.confirm_forget.buttons['cancel-forget']); assert(c.review.text==source(29))
      click(a,f.title.close)
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
  group('editor-starter-validate-save-run-print-once-and-timer',function()
    local c=make(48); local p=M.player(1010,c.body)
    local s=model.open(p,c.id)
    model.edit(p,s.token,help.template)
    model.action(p,s.token,'validate',tick)
    assert(not c.active and #c.logs==0 and not c.state.samples)
    model.action(p,s.token,'save',tick)
    assert(c.saved_source==help.template and not c.active and #c.logs==0)
    model.action(p,s.token,'run',tick)
    assert(scheduler.dispatch(c,tick+1))
    assert(c.state.samples==1 and #c.logs==1 and c.logs[1].text=='Initial sample count:\t1')
    scheduler.tick(tick+61)
    assert(c.state.samples==2 and #c.logs==1)
  end)
  storage.tweaked_computers=host_storage
  log('TC_CONTRACT_TOTAL '..groups)
end
M.source=source
M.gui=gui
return M
