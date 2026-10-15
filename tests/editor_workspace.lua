-- Exact packaged source, real runtime/wires; GUI/player objects are table mocks.
-- No native rendering, keyboard/clipboard/focus or multiplayer client acceptance.
local contracts=require('tests.editor_contract')
local registry=require('scripts.registry')
local model=require('scripts.ui.editor-model')
local editor=require('scripts.ui.editor')
local layout=require('scripts.ui.editor-layout')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local lifecycle=require('scripts.lifecycle')
local help=require('scripts.ui.help')
local defs=require('scripts.device-definitions')
local compiler=require('scripts.runtime.compiler')
editor.register_inspector(require('scripts.ui.network-inspector'))
local M={}
function M.run()
  local original_storage=storage.tweaked_computers
  storage.tweaked_computers=nil; registry.initialize()
  local original_game=game; local surface=game.surfaces[1]; local groups=0; local tick=200
  local function group(name,fn) tick=tick+1; fn(); groups=groups+1; log('TC_CONTRACT '..name) end
  local function build(kind,x,y)
    local body=assert(surface.create_entity{name=defs.devices[kind].name,position={x,y},force='player'})
    local rec=assert(lifecycle.build(body)); rec.powered=true; return rec
  end
  local rec=build('computer',0,120); local db=build('kv',3,120); local mon=build('monitor',0,123)
  local function connector(r,wire) return assert(lifecycle.connector(r,'network',wire)) end
  assert(connector(rec,'red').connect_to(connector(db,'red')))
  assert(connector(rec,'green').connect_to(connector(mon,'green')))
  local a=contracts.player(2001,rec.body); local b=contracts.player(2002,rec.body)
  a.display_resolution={width=1280,height=720}
  game={get_player=function(i) if i==a.index then return a elseif i==b.index then return b end end,
    connected_players={a,b},tick=original_game.tick}
  local ok,err=pcall(function()
    local function click(element,p) editor.on_click{player_index=(p or a).index,element=assert(element),tick=tick} end
    local function tab(f,i,p)
      f.content.selected_tab_index=i
      editor.on_tab{player_index=(p or a).index,element=f.content,tick=tick}
    end
    local function select(element,i,p)
      element.selected_index=i
      editor.on_selection{player_index=(p or a).index,element=element,tick=tick}
    end
    local function edit(f,text,p)
      f.content.editor.source.text=text
      editor.on_text{player_index=(p or a).index,element=f.content.editor.source,tick=tick}
    end
    local f,c,source_widget
    group('workspace-computer-click-and-native-open-event-routes',function()
      a.selected=rec.body
      editor.on_input{player_index=a.index,input_name='tc-open-selected-computer',tick=tick}
      local opened=a.gui.screen[editor.frame_name]
      assert(opened and a.opened==opened and #opened.content.tabs==5)
      editor.on_closed{player_index=a.index,element=opened}; a.opened=nil
      assert(not opened.valid)
      editor.on_opened{player_index=a.index,entity=rec.body,tick=tick}
      opened=a.gui.screen[editor.frame_name]
      assert(opened and a.opened==opened and #opened.content.tabs==5)
      editor.on_closed{player_index=a.index,element=opened}; a.opened=nil
      assert(not opened.valid)
    end)
    group('workspace-five-native-tabs-compact-actions-draggable-source',function()
      assert(editor.open(a,rec.id)); f=a.gui.screen[editor.frame_name]; c=f.content.editor; source_widget=c.source
      assert(f.content.type=='tabbed-pane' and #f.content.tabs==5 and f.content.selected_tab_index==1)
      for i,name in ipairs({'editor','console','peripherals','reference','maintenance'}) do
        assert(f.content.tabs[i].tab==f.content[name..'_tab'] and f.content.tabs[i].content==f.content[name])
      end
      assert(f.title.drag.drag_target==f and f.title.heading.drag_target==f)
      assert(f.title.style.horizontal_spacing==4 and c.style.vertical_spacing==4)
      assert(c.actions.style.horizontal_spacing==4)
      assert(#c.actions.children==4 and c.actions.activate and not c.actions.run and not c.actions.apply)
      assert(c.source.read_only==false and c.source.style.rich_text_setting==defines.rich_text_setting.disabled)
      assert(not c.output and not c.help_panel and not c.recovery and not c.review_panel)
    end)
    group('workspace-starter-validate-save-activation-separate',function()
      click(c.message.template); assert(c.source.text==help.template and rec.saved_source=='' and not rec.active)
      assert(c.source.style.minimal_height==layout.measure(a.display_resolution,a.display_scale,false).source_height)
      edit(f,help.template..'\n-- edited through actual source handler')
      click(c.actions.validate); assert(rec.saved_revision==0 and not rec.active and next(rec.state)==nil)
      click(c.actions.activate); assert(not rec.active and c.actions.activate.enabled==false)
      click(c.actions.save); assert(rec.saved_revision==1 and not rec.active)
      click(c.actions.activate); assert(rec.active.source==c.source.text and rec.status=='running')
      rec.power_checked_tick=tick+1 -- Explicit fixture dispatch, not an actual on_tick power sample.
      assert(scheduler.dispatch(rec,tick+1) and #rec.logs>=1 and rec.logs[#rec.logs].text=='Controller started')
    end)
    local exact=help.template..'\n-- unsaved [font=bad] é\n'
    group('workspace-tab-focus-status-identity-exact-dirty-draft',function()
      edit(f,exact); local writes=source_widget.text_writes; local run=rec.run_id; local active=rec.active; local saved=rec.saved_source
      for i=2,5 do tab(f,i); editor.refresh(a); assert(c.source==source_widget and c.source.text==exact) end
      click(f.title.toggle_focus)
      assert(model.session(a.index).focus and f.content.selected_tab_index==1 and not f.content.editor_tab.visible)
      assert(not c.status.visible and not c.message.visible and c.actions.visible)
      for _=1,3 do editor.refresh(a) end
      click(f.title.toggle_focus)
      assert(not model.session(a.index).focus and model.session(a.index).tab==5 and f.content.selected_tab_index==5)
      assert(f.content.editor_tab.visible and source_widget.text_writes==writes)
      assert(rec.run_id==run and rec.active==active and rec.saved_source==saved)
      tab(f,1); source_widget.focused=false; runtime.log(rec,'new live output',tick)
      editor.tick(15,function() end)
      assert(not source_widget.focused and source_widget.text_writes==writes and c.source==source_widget and c.source.text==exact)
    end)
    group('workspace-layout-four-resolution-scale-cases-and-clamping',function()
      for _,resolution in ipairs({{width=1280,height=720},{width=1920,height=1080}}) do
        for _,scale in ipairs({1,1.5}) do
          a.display_resolution=resolution; a.display_scale=scale; local old=a.opened
          f.location={x=99999,y=-50}; editor.resize(a)
          local normal=layout.measure(resolution,scale,false)
          assert(normal.supported and f.style.minimal_width==normal.width and f.style.minimal_height==normal.height)
          assert(f.location.x>=0 and f.location.y==0 and f.location.x+f.style.minimal_width*scale<=resolution.width)
          assert(f.style.minimal_height*scale<=resolution.height and c.source.style.minimal_height/normal.content_height>=0.7)
          assert(c.source.style.minimal_width==normal.content_width and a.opened==old and c.source==source_widget and c.source.text==exact)
          f.location={x=17,y=19}; editor.resize(a); assert(f.location.x==17 and f.location.y==19)
          click(f.title.toggle_focus)
          local focus=layout.measure(resolution,scale,true)
          assert(c.source.style.minimal_height/focus.content_height>=0.85 and c.actions.visible and c.actions.children[4].name=='stop')
          click(f.title.toggle_focus)
          log('TC_WORKSPACE_LAYOUT '..resolution.width..'x'..resolution.height..' scale '..scale..' window '..normal.width..'x'..normal.height..' source '..normal.source_height..' focus '..focus.source_height)
        end
      end
      assert(not layout.measure({width=1000,height=600},1.5,false).supported)
    end)
    group('workspace-console-follow-off-no-text-or-scroll-churn',function()
      tab(f,2); local output=f.content.console.output; local text=output.text; local writes=output.text_writes; local scrolls=output.scrolls
      local follow=f.content.console.follow; follow.state=false
      editor.on_checked{player_index=a.index,element=follow,tick=tick}
      for i=1,limits.console_entries+3 do runtime.log(rec,'[font=bad]'..i,tick) end
      for _=1,3 do editor.refresh(a) end
      tab(f,1); tab(f,2)
      assert(output.text==text and output.text_writes==writes and output.scrolls==scrolls)
      click(f.content.console.actions['refresh-console']); assert(output.text~=text and output.scrolls==scrolls)
      follow.state=true; editor.on_checked{player_index=a.index,element=follow,tick=tick}
      runtime.log(rec,'last bounded output',tick); editor.refresh(a)
      assert(#rec.logs==limits.console_entries and output.text:find('older output discarded',1,true) and output.scrolls>scrolls)
      assert(c.source.text==exact and f.content.selected_tab_index==2)
    end)
    group('workspace-real-wire-color-inventory-powered-and-disconnected-rows',function()
      db.powered=false; tab(f,3)
      local s=model.session(a.index); local p=f.content.peripherals
      assert(s.inventory.wire=='red' and #s.inventory.items==1 and s.inventory.items[1].name==db.id and not s.inventory.items[1].powered)
      assert(p.rows.device_1.icon.sprite=='item/tc-kv')
      click(p.rows.device_1.peripheral_1); assert(p.details.text:find(db.id,1,true) and p.details.text:find('Unpowered',1,true))
      select(p.filter.wire,2)
      assert(s.inventory.wire=='green' and #s.inventory.items==1 and s.inventory.items[1].name==mon.id)
      assert(p.rows.device_1.icon.sprite=='item/tc-monitor')
      click(p.rows.device_1.peripheral_1); assert(s.peripheral==mon.id)
      assert(connector(rec,'green').disconnect_from(connector(mon,'green')))
      click(p.filter.inspect)
      assert(#s.inventory.items==0 and p.rows.empty and p.details.text:find('Disconnected',1,true))
      assert(c.source.text==exact)
    end)
    group('workspace-real-discovery-deferred-not-successful-empty-inventory',function()
      tab(f,3); select(f.content.peripherals.filter.wire,1)
      local context=runtime.context(rec,tick)
      assert(admission.reserve(context,'work',limits.callback_work-context.machine.work))
      click(f.content.peripherals.filter.inspect)
      local s=model.session(a.index)
      assert(s.inventory.error and s.inventory.error.code=='E_BUSY' and not s.inventory.items and not f.content.peripherals.rows.empty)
      assert(f.content.peripherals.details.text:find('presence is not claimed',1,true))
      tick=tick+1; click(f.content.peripherals.filter.inspect)
      assert(s.inventory.items and #s.inventory.items==1 and s.inventory.items[1].name==db.id)
    end)
    group('workspace-reference-complete-categories-search-select-no-overwrite',function()
      tab(f,4); local r=f.content.reference; local s=model.session(a.index)
      assert(#s.reference_entries==#help.topics and #r.topics.items==#help.topics)
      local combined=''; for i=1,#help.topics-1 do combined=combined..help.topics[i].text end
      assert(combined==help.text..'\n','categorized reference dropped or duplicated text')
      select(r.filters.category,5); assert(#s.reference_entries==5)
      r.filters.search.text='KV DATABASE'; editor.on_text{player_index=a.index,element=r.filters.search,tick=tick}
      assert(#s.reference_entries==1 and r.reference_text.text:find('hgetall',1,true))
      click(r.actions['select-reference']); assert(r.reference_text.selection and r.reference_text.focused)
      r.filters.search.text=string.rep('s',129); editor.on_text{player_index=a.index,element=r.filters.search,tick=tick}
      assert(r.filters.search.text=='KV DATABASE' and s.search=='KV DATABASE')
      select(r.filters.category,6); r.filters.search.text='Starter controller'
      editor.on_text{player_index=a.index,element=r.filters.search,tick=tick}
      assert(#s.reference_entries==1 and r.actions.template.enabled)
      click(r.actions.template); assert(c.source.text==exact and rec.active.source~=exact)
      r.filters.search.text='no-topic-here'; editor.on_text{player_index=a.index,element=r.filters.search,tick=tick}
      assert(#s.reference_entries==0 and r.reference_text.text:find('No matching topic',1,true))
    end)
    group('workspace-conflict-explicit-navigation-recheck-rebase-reload',function()
      assert(editor.open(b,rec.id)); local other=b.gui.screen[editor.frame_name]
      edit(other,contracts.source(71),b); click(other.content.editor.actions.save,b)
      tab(f,2); local old=c.source.text; editor.refresh(a)
      assert(f.content.selected_tab_index==2 and c.source.text==old and not c.actions.save.enabled)
      tab(f,1); click(c.message.review)
      local m=f.content.maintenance; assert(f.content.selected_tab_index==5 and m.review_panel.visible)
      edit(other,contracts.source(73),b); click(other.content.editor.actions.save,b)
      click(m.review_panel.actions.rebase); assert(c.source.text==old and model.session(a.index).review.revision~=rec.saved_revision)
      click(m.review_actions.review); click(m.review_panel.actions.rebase)
      assert(c.source.text==old and c.actions.save.enabled and rec.saved_source==contracts.source(73))
      click(m.review_actions.review); click(m.review_panel.actions.reload)
      assert(c.source==source_widget and c.source.text==contracts.source(73) and rec.active.source~=c.source.text)
    end)
    group('workspace-maintenance-active-recovery-and-stopped-only-reset',function()
      local m=f.content.maintenance; local active=rec.active.source
      click(m.review_actions['review-active']); assert(m.active_panel.review.text==active)
      click(m.active_panel.actions['copy-active']); assert(c.source.text==active and rec.saved_source==contracts.source(73))
      rec.state.kept=true; click(m.danger.reset); assert(not model.session(a.index).reset and rec.state.kept)
      tab(f,1); click(c.actions.stop); assert(rec.status=='stopped' and rec.state.kept)
      tab(f,5); click(m.danger.reset); assert(m.confirm_reset.visible and m.confirm_reset.identity.caption:find(rec.id,1,true))
      click(m.confirm_reset.buttons['cancel-reset']); assert(rec.state.kept and not m.confirm_reset.visible)
      click(m.danger.reset); click(m.confirm_reset.buttons['confirm-reset'])
      assert(next(rec.state)==nil and rec.saved_source==contracts.source(73) and c.source.text==active)
    end)
    group('workspace-retained-draft-reviewed-copy-and-identity-confirmation',function()
      local removed=build('computer',6,120)
      local session=model.open(a,removed.id); model.edit(a,session.token,'-- removed draft')
      registry.remove(removed.id); assert(editor.open(a,rec.id)); f=a.gui.screen[editor.frame_name]; c=f.content.editor
      tab(f,5); local m=f.content.maintenance; local s,bag=model.session(a.index); local index
      for i,id in ipairs(s.recovery_names) do if id==removed.id then index=i end end
      select(m.recovery,index); click(m.recovery_panel.actions.recover) -- hidden: cannot copy without review
      assert(c.source.text~='-- removed draft')
      click(m.recovery_actions['review-recovery']); assert(m.recovery_panel.review.text=='-- removed draft')
      click(m.recovery_panel.actions.recover); assert(c.source.text=='-- removed draft' and rec.saved_source==contracts.source(73))
      click(m.recovery_actions.forget); assert(m.confirm_forget.visible and m.confirm_forget.identity.caption:find(removed.id,1,true))
      click(m.confirm_forget.buttons['cancel-forget']); assert(bag.documents[removed.id])
      click(m.recovery_actions.forget); bag.documents[removed.id].source='-- changed since review'
      click(m.confirm_forget.buttons['confirm-forget']); assert(bag.documents[removed.id])
      click(m.recovery_actions['review-recovery']); click(m.recovery_actions.forget); click(m.confirm_forget.buttons['confirm-forget'])
      assert(not bag.documents[removed.id] and bag.documents[rec.id])
      local current_index; for i,id in ipairs(s.recovery_names) do if id==rec.id then current_index=i end end
      select(m.recovery,current_index); click(m.recovery_actions['review-recovery']); click(m.recovery_actions.forget)
      assert(not s.forget and bag.documents[rec.id])
    end)
    group('workspace-strict-hidden-inactive-forged-generation-session-events',function()
      local s,bag=model.session(a.index); local d=bag.documents[rec.id]; local exact=d.source; local saved=rec.saved_source
      local m=f.content.maintenance
      click(c.actions.save); assert(rec.saved_source==saved,'hidden Editor action accepted from Maintenance')
      local forged=m.add{type='button',name='save'}; click(forged); assert(rec.saved_source==saved)
      a.opened={other=true}; click(m.review_actions.review)
      local previous=s.review; select(m.recovery,1); assert(s.review==previous)
      a.opened=f
      local generation=f.tags.generation; f.tags.generation=generation+1; click(m.review_actions.review); assert(s.review==previous); f.tags.generation=generation
      local token=f.tags.token; f.tags.token=token+1; click(m.review_actions.review); assert(s.review==previous); f.tags.token=token
      a.permission_group={allows_action=function() return false end}; click(m.review_actions.review); assert(s.review==previous); a.permission_group=nil
      click(m.review_actions.review,b); assert(s.review==previous)
      local unit=rec.body.unit_number; local binding=registry.get().entities[unit]
      registry.get().entities[unit]={id='missing',role='body'}; click(m.review_actions.review); assert(s.review==previous)
      registry.get().entities[unit]=binding
      assert(d.source==exact and rec.saved_source==saved)
      local old_button=f.content.editor.actions.save; assert(editor.open(a,rec.id)); f=a.gui.screen[editor.frame_name]; c=f.content.editor
      click(old_button); assert(rec.saved_source==saved and c.source.text==exact)
    end)
    group('workspace-runtime-fault-badge-and-wrong-source-navigation-refusal',function()
      tab(f,1)
      edit(f,'return {api_version=1,handlers={start=function(e) error("intentional [font=bad] failure") end}}')
      click(c.actions.save); click(c.actions.activate); rec.power_checked_tick=tick+1
      assert(scheduler.dispatch(rec,tick+1) and rec.status=='faulted' and rec.diagnostic.line)
      tick=tick+1 -- Subsequent UI validation must not go backwards from the dispatch ledger.
      c.source.focused=false; editor.refresh(a)
      assert(not c.source.focused and f.content.selected_tab_index==1 and c.message.feedback.caption:find('Active run faulted',1,true))
      assert(not c.message.feedback.tooltip:find('[font=',1,true) and f.content.console_tab.caption[1]=='tc-editor.console-error')
      edit(f,contracts.source(99)); click(c.actions.validate)
      assert(model.session(a.index).validation and not model.session(a.index).validation.diagnostic)
      tab(f,2); click(f.content.console.actions['show-location'])
      assert(f.content.selected_tab_index==2 and c.source.text==contracts.source(99),'active diagnostic navigated into unrelated valid draft')
    end)
    group('workspace-explicit-diagnostic-line-selection-no-auto-tab-theft',function()
      tab(f,1); edit(f,'return {\n  invalid !\n}')
      click(c.actions.validate); local s=model.session(a.index)
      assert(s.validation and s.validation.diagnostic and s.validation.diagnostic.line)
      tab(f,2); local before=c.source.text; c.source.focused=false
      editor.refresh(a); assert(not c.source.focused and f.content.selected_tab_index==2)
      click(f.content.console.actions['show-location'])
      assert(f.content.selected_tab_index==1 and c.source.focused and c.source.selection and c.source.text==before)
    end)
    group('workspace-new-presentation-routes-reject-inactive-and-foreign-events',function()
      local s=model.session(a.index); local before=s.tab; local search=s.search; local category=s.category; local follow=s.follow; local wire=s.wire
      local _,bag=model.session(a.index); local draft=bag.documents[rec.id].source
      a.opened={another_gui=true}; f.content.selected_tab_index=4
      editor.on_tab{player_index=a.index,element=f.content,tick=tick}
      f.content.reference.filters.search.text='forged'
      editor.on_text{player_index=a.index,element=f.content.reference.filters.search,tick=tick}
      select(f.content.reference.filters.category,5)
      f.content.console.follow.state=false; editor.on_checked{player_index=a.index,element=f.content.console.follow,tick=tick}
      select(f.content.peripherals.filter.wire,2)
      assert(s.tab==before and s.search==search and s.category==category and s.follow==follow and s.wire==wire)
      a.opened=f; f.content.selected_tab_index=before
      editor.on_checked{player_index=b.index,element=f.content.console.follow,tick=tick}
      assert(s.follow==follow and bag.documents[rec.id].source==draft)
    end)
    group('workspace-old-saved-gui-retires-session-without-losing-draft',function()
      local _,bag=model.session(a.index); local draft=bag.documents[rec.id].source; local saved=rec.saved_source
      f.tags.ui_version=nil; editor.resize(a)
      assert(not f.valid and not model.session(a.index) and bag.documents[rec.id].source==draft and rec.saved_source==saved)
      assert(editor.open(a,rec.id)); f=a.gui.screen[editor.frame_name]; c=f.content.editor
      assert(c.source.text==draft and f.content.selected_tab_index==1)
    end)
    group('workspace-standalone-recovery-unavailable-body-review-copy-forget',function()
      local old=c.source.text; local saved=rec.saved_source; registry.remove(rec.id)
      local removed_status=rec.status
      click(f.title.close); assert(not f.valid and rec.saved_source==saved)
      editor.open_recovery(a); f=a.gui.screen[editor.frame_name]; local r=f.recovery_content; local s,bag=model.session(a.index)
      assert(s.mode=='recovery' and not f.title.toggle_focus.visible)
      local index; for i,id in ipairs(s.recovery_names) do if id==rec.id then index=i end end
      select(r.recovery,index); click(r.actions.review); assert(r.review.text==old and r.review.read_only)
      click(r['select-recovery']); assert(r.review.selection and r.review.focused)
      click(r.actions.forget); assert(r.confirm_forget.identity.caption:find(rec.id,1,true))
      click(r.confirm_forget.buttons['cancel-forget']); assert(bag.documents[rec.id])
      click(r.actions.forget); click(r.confirm_forget.buttons['confirm-forget']); assert(not bag.documents[rec.id])
      assert(rec.saved_source==saved and rec.status==removed_status)
      click(f.title.close); assert(not f.valid)
    end)
    group('workspace-reference-starter-compiles-supported-api',function()
      local context=admission.context(admission.new(),'help-example',0)
      local plan,e=compiler.compile(help.template,context); assert(plan,e and e.message)
      assert(#help.topics==12 and #help.categories==7)
      if #original_game.players==0 then log('TC_WORKSPACE_CLIENT_SKIPPED no client-created player; all GUI checks are mocks') end
    end)
  end)
  game=original_game; storage.tweaked_computers=original_storage
  if not ok then error(err,0) end
  log('TC_CONTRACT_TOTAL '..groups)
end
return M
