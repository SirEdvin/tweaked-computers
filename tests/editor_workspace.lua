-- Exact packaged source, real runtime/wires; GUI/player objects are table mocks.
-- No native rendering, keyboard/clipboard/focus or multiplayer client acceptance.
local contracts=require('tests.editor_contract')
local registry=require('scripts.registry')
local model=require('scripts.ui.editor-model')
local editor=require('scripts.ui.editor')
local interaction=require('scripts.ui.interaction')
local peripheral_inspector=require('scripts.ui.peripheral-inspector')
local monitor=require('scripts.services.monitor')
local layout=require('scripts.ui.editor-layout')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local lifecycle=require('scripts.lifecycle')
local help=require('scripts.ui.help')
local help_contract=require('tests.help_contract')
local defs=require('scripts.device-definitions')
local compiler=require('scripts.runtime.compiler')
local real_inspector=require('scripts.ui.network-inspector')
local inspection_override -- Explicit host-inventory doubles for otherwise unreachable error cases.
editor.register_inspector(function(...)
  if inspection_override then return inspection_override.items,inspection_override.error end
  return real_inspector(...)
end)
local M={}
function M.run()
  local original_storage=storage.tweaked_computers
  storage.tweaked_computers=nil; registry.initialize()
  local original_game=game; local surface=game.surfaces[1]; local groups=0; local tick=200
  local function group(name,fn) tick=tick+1; game.tick=tick; fn(); groups=groups+1; log('TC_CONTRACT '..name) end
  local function build(kind,x,y)
    local body=assert(surface.create_entity{name=defs.devices[kind].entity_name,position={x,y},force='player'})
    local rec=assert(lifecycle.build(body)); rec.powered=true; return rec
  end
  local rec=build('computer',0,120); local db=build('kv',3,120); local mon=build('monitor',0,123)
  -- The shared interaction path installs the real monitor provider. Initialize
  -- its logical group instead of relying on the old fixture's default binding.
  for _=1,200 do
    monitor.reconcile(tick,function() end)
    if not registry.get().monitors.job then break end
  end
  assert(monitor.resolve(mon) and not registry.get().monitors.job)
  local monitor_id=monitor.resolve(mon).id
  local function connector(r,wire)
    if r.native_carrier then return assert(r.body.get_wire_connector(defines.wire_connector_id['circuit_'..wire],true)) end
    return assert(lifecycle.connector(r,'network',wire))
  end
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
    local function reference_text(r)
      local text={}; for _,block in ipairs(r.reference_text.children) do text[#text+1]=block.text end
      return table.concat(text,'\n')
    end
    group('workspace-help-exact-inventory-spacing-signatures-aliases',help_contract.run)
    group('workspace-empty-ground-without-drafts-is-inert',function()
      a.selected=nil
      interaction.on_input{player_index=a.index,input_name='tc-interact',tick=tick,cursor_position={x=30,y=120}}
      assert(not a.opened and not a.gui.screen[editor.frame_name] and not model.session(a.index))
      assert(not registry.get().player_drafts[a.index],'empty ground must not even allocate a draft bucket')
    end)
    group('workspace-only-explicit-control-click-opens-editor',function()
      a.selected=rec.body
      a.opened=rec.body
      interaction.on_opened{player_index=a.index,entity=rec.body,tick=tick}
      assert(a.opened==nil and not a.gui.screen[editor.frame_name],'ordinary open must not create a workspace')
      interaction.on_input{player_index=a.index,input_name='tc-open-selected-computer',tick=tick}
      assert(not a.gui.screen[editor.frame_name],'legacy linked open must be inert')
      interaction.on_input{player_index=a.index,input_name='tc-open-editor',tick=tick}
      assert(not a.gui.screen[editor.frame_name],'legacy keyboard open must be inert')
      interaction.on_input{player_index=a.index,input_name='tc-interact',tick=tick}
      local opened=a.gui.screen[editor.frame_name]
      assert(opened and a.opened==opened and #opened.content.tabs==5)
      editor.on_closed{player_index=a.index,element=opened}; a.opened=nil
      assert(not opened.valid)
    end)
    group('workspace-world-gesture-refuses-held-wires-ghosts-gui-and-denied-input',function()
      local function input(extra)
        local event={player_index=a.index,input_name='tc-interact',tick=tick}
        for k,v in pairs(extra or {}) do event[k]=v end
        interaction.on_input(event)
        assert(not a.gui.screen[editor.frame_name] and not model.session(a.index))
      end
      a.selected=rec.body
      local cursor={valid_for_read=true,name='red-wire'}; a.cursor_stack=cursor
      input(); assert(a.cursor_stack==cursor and cursor.valid_for_read and cursor.name=='red-wire')
      cursor.name='green-wire'; input(); assert(cursor.name=='green-wire')
      a.cursor_stack={valid_for_read=false}; a.cursor_ghost='tc-computer'; input(); a.cursor_ghost=nil
      input{in_gui=true}; input{element={valid=true}}
      local other={other_gui=true}; a.opened=other; input(); assert(a.opened==other); a.opened=nil
      a.permission_group={allows_action=function() return false end}; input(); a.permission_group=nil
      a.can_reach_entity=function() return false end; input(); a.can_reach_entity=function() return true end
      local force,surface=a.force,a.surface
      a.force={index=-1}; input(); a.force=force
      a.surface={index=-1}; input(); a.surface=surface
      a.permission_group={allows_action=function(action) return action~=defines.input_action.open_gui end}
      input(); a.permission_group=nil
      assert(connector(rec,'red').is_connected_to(connector(db,'red')))
      assert(connector(rec,'green').is_connected_to(connector(mon,'green')))
      -- Real engine wiring is untouched by ordinary UI events on either end.
      for _,color in ipairs({'red','green'}) do
        local target=color=='red' and db or mon
        assert(connector(rec,color).disconnect_from(connector(target,color)))
        for _,r in ipairs({rec,target}) do
          a.opened=r.body; interaction.on_opened{player_index=a.index,entity=r.body,tick=tick}
          assert(not a.gui.screen[editor.frame_name])
          if r.kind~='computer' then assert(a.opened==a.gui.screen[peripheral_inspector.frame_name]); peripheral_inspector.close(a)
          else assert(a.opened==nil) end
        end
        assert(connector(rec,color).connect_to(connector(target,color)))
        assert(connector(rec,color).is_connected_to(connector(target,color)))
      end
    end)
    group('workspace-all-device-native-dialogs-suppressed-vanilla-untouched',function()
      local devices={rec,db,mon,build('logic',12,120),build('configurator',18,120)}
      for _,r in ipairs(devices) do
        assert(r.body.operable==(r.kind~='computer'),'only peripheral bodies are ordinarily openable')
        local parts={r.body}; for _,child in pairs(r.children) do parts[#parts+1]=child end
        for _,part in ipairs(parts) do
          a.selected=part; a.opened=part
          interaction.on_opened{player_index=a.index,entity=part,tick=tick}
          assert(not a.gui.screen[editor.frame_name])
          if part==r.body and r.kind~='computer' then
            assert(a.opened==a.gui.screen[peripheral_inspector.frame_name]); peripheral_inspector.close(a)
          else assert(not a.opened) end
        end
        if r.kind~='computer' then
          a.selected=r.body; interaction.on_input{player_index=a.index,input_name='tc-interact',tick=tick}
          assert(not a.gui.screen[editor.frame_name],'non-computers must not open native configuration or recovery')
        end
      end
      local vanilla=assert(surface.create_entity{name='constant-combinator',position={24,120},force='player'})
      a.opened=vanilla; interaction.on_opened{player_index=a.index,entity=vanilla,tick=tick}; assert(a.opened==vanilla)
      interaction.on_opened{player_index=a.index,entity=rec.body,tick=tick}; assert(a.opened==vanilla)
      a.opened=nil; a.selected=nil
      local _,bag=model.session(a.index); local documents=serpent.line(bag.documents)
      interaction.on_input{player_index=a.index,input_name='tc-interact',tick=tick}
      assert(not a.opened and not a.gui.screen[editor.frame_name] and not model.session(a.index),
        'control-click empty ground must not open recovery even with retained drafts')
      assert(serpent.line(bag.documents)==documents)
    end)
    group('workspace-only-exact-computer-body-not-helper-ghost-or-removed-target',function()
      local function refused(target)
        a.selected=target
        interaction.on_input{player_index=a.index,input_name='tc-interact',tick=tick}
        assert(not a.opened and not a.gui.screen[editor.frame_name] and not model.session(a.index))
      end
      local helpers=0
      for _,child in pairs(rec.children) do refused(child); helpers=helpers+1 end
      assert(helpers>0,'exercise a real owned computer helper')
      local ghost=assert(surface.create_entity{name='entity-ghost',inner_name=rec.body.name,position={30,120},force='player'})
      refused(ghost); ghost.destroy()
      local removed=build('computer',33,120); local body=removed.body
      registry.remove(removed.id); refused(body)
      body.destroy(); refused(body); refused({valid=false}); a.selected=nil
    end)
    group('workspace-vanilla-control-click-leaves-world-and-open-inventory-alone',function()
      for i,name in ipairs({'steel-chest','stone-furnace'}) do
        local body=assert(surface.create_entity{name=name,position={24+i*3,120},force='player'})
        a.selected=body; a.opened=nil
        for _=1,3 do
          interaction.on_input{player_index=a.index,input_name='tc-interact',tick=tick}
          assert(not a.opened and not model.session(a.index) and not a.gui.screen[editor.frame_name])
        end
        a.opened=body
        interaction.on_input{player_index=a.index,input_name='tc-interact',in_gui=true,tick=tick}
        assert(a.opened==body and not model.session(a.index))
        a.opened=nil; body.destroy()
      end
      a.selected=nil
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
      assert(not f.content.console.actions['refresh-console'] and not f.content.peripherals.filter.inspect)
      assert(not f.content.peripherals.snapshot and not f.content.maintenance.revisions)
      assert(not c.status.caption:find(' | base ',1,true),'revision trackers are presentation, not safety')
    end)
    group('workspace-foreign-close-during-shell-construction-is-ignored',function()
      local pane=f.content; f.content=nil
      local ok,e=pcall(editor.on_closed,{player_index=a.index,element={valid=true,parent=a.gui.screen}})
      f.content=pane
      assert(ok,e)
      assert(f.valid and a.opened==f and model.session(a.index))
    end)
    group('workspace-starter-validate-save-activation-separate',function()
      click(c.message.template); assert(c.source.text==help.template and rec.saved_source=='' and not rec.active)
      local _,bag=model.session(a.index)
      assert(bag.documents[rec.id].source==help.template and rec.saved_revision==0 and next(rec.state)==nil)
      assert(c.source.style.minimal_height==layout.measure(a.display_resolution,a.display_scale,false).source_height)
      click(c.actions.validate); assert(rec.saved_revision==0 and not rec.active and next(rec.state)==nil)
      click(c.actions.activate); assert(not rec.active and c.actions.activate.enabled==false)
      click(c.actions.save); assert(rec.saved_revision==1 and rec.saved_source==help.template and not rec.active)
      click(c.actions.activate); assert(rec.active.source==help.template and rec.status=='running')
      assert(rec.active.handlers.start and rec.active.handlers.sample and not rec.active.handlers.increment)
      local exports=0; for _ in pairs(rec.active.handlers) do exports=exports+1 end; assert(exports==2)
      rec.power_checked_tick=tick -- Explicit fixture dispatch, not an actual on_tick power sample.
      assert(scheduler.dispatch(rec,tick) and rec.status=='running',rec.diagnostic and rec.diagnostic.message)
      assert(rec.state.samples==1 and #rec.logs==1 and rec.logs[1].text=='Initial sample count:\t1')
      assert(rec.saved_source==help.template and rec.active.source==help.template and c.source.text==help.template)
      assert(bag.documents[rec.id].source==help.template and not scheduler.dispatch(rec,tick))
    end)
    group('workspace-exact-starter-first-timer-deadline',function()
      local timer=assert(next(rec.timers)); timer=rec.timers[timer]
      local deadline=timer.deadline; local run=rec.run_id
      assert(timer.handler=='sample' and timer.interval==60 and deadline==tick-1+60)
      tick=deadline-1
      scheduler.advance_timers(rec,tick,scheduler.maintenance(registry.get(),tick))
      assert(rec.state.samples==1 and #rec.queue==0 and not scheduler.dispatch(rec,tick))
      tick=deadline
      scheduler.advance_timers(rec,tick,scheduler.maintenance(registry.get(),tick))
      assert(#rec.queue==1 and rec.queue[1].handler=='sample')
      local event=rec.queue[1].event
      assert(event.name=='timer' and event.scheduled_tick==deadline and event.interval_ticks==60 and event.missed==0)
      rec.power_checked_tick=tick
      assert(scheduler.dispatch(rec,tick) and rec.status=='running',rec.diagnostic and rec.diagnostic.message)
      assert(rec.state.samples==2 and #rec.logs==1 and #rec.queue==0 and timer.deadline==deadline+60)
      assert(rec.run_id==run and rec.saved_source==help.template and rec.active.source==help.template)
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
    group('workspace-console-follow-off-live-without-scroll-or-unchanged-text-churn',function()
      tab(f,2); local output=f.content.console.output; local text=output.text; local writes=output.text_writes; local scrolls=output.scrolls
      local follow=f.content.console.follow; follow.state=false
      editor.on_checked{player_index=a.index,element=follow,tick=tick}
      for i=1,limits.console_entries+3 do runtime.log(rec,'[font=bad]'..i,tick) end
      for _=1,3 do editor.refresh(a) end
      tab(f,1); tab(f,2)
      assert(output.text~=text and output.text_writes==writes+1 and output.scrolls==scrolls)
      local live_writes=output.text_writes; editor.refresh(a); assert(output.text_writes==live_writes)
      follow.state=true; editor.on_checked{player_index=a.index,element=follow,tick=tick}
      runtime.log(rec,'last bounded output',tick); editor.refresh(a)
      assert(#rec.logs==limits.console_entries and output.tooltip[1]=='tc-editor.console-bounded' and output.scrolls>scrolls)
      assert(c.source.text==exact and f.content.selected_tab_index==2)
    end)
    group('workspace-real-wire-color-inventory-powered-and-disconnected-rows',function()
      db.powered=false; tab(f,3)
      local s=model.session(a.index); local p=f.content.peripherals
      assert(s.inventory.wire=='red' and #s.inventory.items==1 and s.inventory.items[1].name==db.id and not s.inventory.items[1].powered)
      assert(p.rows.device_1.icon.sprite=='item/tc-kv')
      click(p.rows.device_1.peripheral_1); assert(p.details.text:find(db.id,1,true) and p.details.text:find('Unpowered',1,true))
      local row=p.rows.device_1; local details_writes=p.details.text_writes
      tick=tick+15; game.tick=tick; editor.tick(tick-tick%15,function() end)
      assert(p.rows.device_1==row and p.details.text_writes==details_writes and s.peripheral==db.id)
      db.powered=true; editor.refresh(a,nil,tick)
      assert(p.rows.device_1==row and p.details.text:find('Powered',1,true))
      select(p.filter.wire,2)
      assert(s.inventory.wire=='green' and s.inventory.items and #s.inventory.items==1 and s.inventory.items[1].name==monitor_id,serpent.line(s.inventory))
      assert(p.rows.device_1.icon.sprite=='item/tc-monitor')
      click(p.rows.device_1.peripheral_1); assert(s.peripheral==monitor_id)
      assert(connector(rec,'green').disconnect_from(connector(mon,'green')))
      editor.refresh(a)
      assert(#s.inventory.items==0 and p.rows.empty and p.details.text:find('Disconnected',1,true))
      assert(c.source.text==exact)
    end)
    group('workspace-real-discovery-deferred-not-successful-empty-inventory',function()
      tab(f,3); select(f.content.peripherals.filter.wire,1)
      local context=runtime.context(rec,tick)
      assert(admission.reserve(context,'work',limits.callback_work-context.machine.work))
      editor.refresh(a)
      local s=model.session(a.index)
      assert(s.inventory.error and s.inventory.error.code=='E_BUSY' and not s.inventory.items and not f.content.peripherals.rows.empty)
      assert(f.content.peripherals.details.text:find('presence is not claimed',1,true))
      tick=tick+1; editor.refresh(a,nil,tick)
      assert(s.inventory.items and #s.inventory.items==1 and s.inventory.items[1].name==db.id)
    end)
    group('workspace-reference-complete-categories-search-select-no-overwrite',function()
      tab(f,4); local r=f.content.reference; local s=model.session(a.index)
      assert(#s.reference_entries==#help.topics and #r.topics.items==#help.topics)
      local combined=''; for _,topic in ipairs(help.topics) do if not (topic.id or ''):find('tutorial.',1,true) then combined=combined..topic.text end end
      assert(combined==help.text..'\n','categorized reference dropped or duplicated text')
      select(r.filters.category,5); assert(#s.reference_entries==11)
      local titles={['Discovery and identity']=true,['Logic handler']=true,['KV database']=true,
        Monitor=true,Dashboard=true,Configurator=true,['Recipe Searcher']=true,['Factoriopedia Interface']=true,['Production Statistics']=true,['Radar modem']=true,['Programmable speaker']=true}
      for _,index in ipairs(s.reference_entries) do
        local title=help.topics[index].title; assert(titles[title]); titles[title]=nil
      end
      assert(next(titles)==nil)
      r.filters.search.text='RADAR MODEM'; editor.on_text{player_index=a.index,element=r.filters.search,tick=tick}
      assert(#s.reference_entries==1 and reference_text(r):find('transmit',1,true)
        and reference_text(r):find('modem_message',1,true))
      r.filters.search.text='playNote'; editor.on_text{player_index=a.index,element=r.filters.search,tick=tick}
      assert(#s.reference_entries==1 and reference_text(r):find('getSounds',1,true))
      r.filters.search.text='RECIPE SEARCHER'; editor.on_text{player_index=a.index,element=r.filters.search,tick=tick}
      assert(#s.reference_entries==2 and reference_text(r):find('findRecipes',1,true))
      local recipe_matches={['Recipe Searcher']=true,['Production Statistics']=true}
      for _,index in ipairs(s.reference_entries) do
        local title=help.topics[index].title; assert(recipe_matches[title]); recipe_matches[title]=nil
      end
      assert(next(recipe_matches)==nil,'shared-unlock search must retain both families')
      r.filters.search.text='PRODUCTION STATISTICS'; editor.on_text{player_index=a.index,element=r.filters.search,tick=tick}
      assert(#s.reference_entries==1 and reference_text(r):find('getHistory',1,true) and reference_text(r):find('getTotals',1,true))
      r.filters.search.text='KV DATABASE'; editor.on_text{player_index=a.index,element=r.filters.search,tick=tick}
      assert(#s.reference_entries==1 and reference_text(r):find('hgetall',1,true))
      assert(not r.actions,'Reference has no action controls')
      local kept=r.reference_text.children[1]; kept.select_all(); tab(f,1); tab(f,4)
      assert(r.reference_text.children[1]==kept and kept.selection,'unchanged navigation must retain native widgets/selection')
      r.filters.search.text=string.rep('s',129); editor.on_text{player_index=a.index,element=r.filters.search,tick=tick}
      assert(r.filters.search.text=='KV DATABASE' and s.search=='KV DATABASE')
      select(r.filters.category,6); r.filters.search.text='Starter controller'
      editor.on_text{player_index=a.index,element=r.filters.search,tick=tick}
      assert(#s.reference_entries==1 and not r.actions)
      local code
      for _,part in ipairs(r.reference_text.children) do
        assert(part.type=='text-box' and part.read_only and part.style.rich_text_setting==defines.rich_text_setting.disabled)
        if part.tags.reference_kind=='code' then
          code=part; assert(not part.word_wrap and part.text==help.template and part.top_scrolls>0 and part.left_scrolls>0)
          assert(part.selection[1]==1 and part.selection[2]==0,'new code starts at its first character without selecting bytes')
        else assert(part.word_wrap) end
      end
      assert(code and c.source.text==exact and rec.active.source~=exact)
      r.filters.search.text='sample(event)'; editor.on_text{player_index=a.index,element=r.filters.search,tick=tick}
      assert(#s.reference_entries==1,'search includes literal tutorial code')
      r.filters.search.text='no-topic-here'; editor.on_text{player_index=a.index,element=r.filters.search,tick=tick}
      assert(#s.reference_entries==0 and reference_text(r):find('No matching topic',1,true))
    end)
    group('workspace-context-help-all-ten-live-families-filter-clear-delay-no-effects',function()
      tab(f,2); local input=f.content.console.prompt.command
      input.text='help_kept={value=42}; help_alias=help_kept'
      editor.on_text{player_index=a.index,element=input,tick=tick}
      editor.on_confirmed{player_index=a.index,element=input,tick=tick}
      rec.power_checked_tick=tick; assert(scheduler.dispatch(rec,tick))
      assert(rec.shell and not rec.shell.diagnostic and #rec.shell.pending==0)
      local devices={db,mon,build('logic',30,120),build('configurator',33,120),build('recipe_searcher',36,120),build('factoriopedia_interface',39,120),build('production_statistics',42,120),build('dashboard',45,120)}
      for _,name in ipairs({'radar','programmable-speaker'}) do
        local body=assert(surface.create_entity{name=name,position={40+#devices*4,120},force='player'})
        devices[#devices+1]=assert(lifecycle.build(body))
      end
      -- Keep the genuine physical graph within native wire reach via a same-color chain.
      local last=rec
      for _,device in ipairs(devices) do
        local from,to=connector(last,'red'),connector(device,'red')
        assert(from.is_connected_to(to) or from.connect_to(to,false))
        last=device
      end
      -- The engine validates shape/type exports elsewhere; navigation must not call any.
      local s,bag=model.session(a.index); local r=f.content.reference; local p=f.content.peripherals
      local before=serpent.line({saved=rec.saved_source,revision=rec.saved_revision,active=rec.active,
        run=rec.run_id,status=rec.status,state=rec.state,shell=rec.shell,kv=db.database,model=monitor.resolve(mon).model})
      local writes=c.source.text_writes; local source=c.source
      for _,device in ipairs(devices) do
        tab(f,4); select(r.filters.category,3)
        r.filters.search.text='no-match-context'; editor.on_text{player_index=a.index,element=r.filters.search,tick=tick}
        assert(#s.reference_entries==0)
        tab(f,3); select(p.filter.wire,1)
        local index,item
        for i,entry in ipairs(s.inventory.items) do
          if entry.name==(device==mon and monitor_id or device.id) then index=i; item=entry end
        end
        assert(index,device.kind)
        s.peripheral_wire=nil -- Each first click is deliberately unselected.
        click(p.rows['device_'..index]['peripheral_'..index])
        assert(s.tab==3 and s.peripheral==item.name and s.peripheral_wire=='red')
        assert(p.details.text:find('API name: '..item.name,1,true) and p.details.tooltip[1]=='tc-editor.peripheral-workflow')
        local row=p.rows['device_'..index]['peripheral_'..index]
        tick=tick+600; click(row)
        local topic=help.peripheral_topic(item.type)
        assert(s.tab==4 and s.topic==topic and r.reference_text.tags.reference_topic==help.topics[topic].title)
        assert(s.search=='' and r.filters.search.text=='' and s.category==5 and r.filters.category.selected_index==5)
        assert(s.reference_entries[r.topics.selected_index]==topic and r.reference_text.top_scrolls>0 and r.reference_text.left_scrolls>0)
        local selected=s.peripheral; click(row) -- hidden row cannot act after navigation.
        assert(s.tab==4 and s.peripheral==selected)
      end
      assert(c.source==source and c.source.text==exact and c.source.text_writes==writes and bag.documents[rec.id].source==exact)
      assert(before==serpent.line({saved=rec.saved_source,revision=rec.saved_revision,active=rec.active,
        run=rec.run_id,status=rec.status,state=rec.state,shell=rec.shell,kv=db.database,model=monitor.resolve(mon).model}))
    end)
    group('workspace-context-help-identity-refresh-wire-disappearance-errors-stale',function()
      local s=model.session(a.index); local p=f.content.peripherals
      local one={name=db.id,type='kv_database',powered=false}; local two={name='test-current-monitor',type='monitor',powered=false}
      local function inventory(items,problem)
        inspection_override={items=items,error=problem}; tick=tick+1
        if s.tab~=3 then tab(f,3) else editor.refresh(a,nil,tick) end
      end
      local function row(i) return p.rows['device_'..i]['peripheral_'..i] end
      inventory({one,two}); s.peripheral_wire=nil
      click(row(1)); assert(s.tab==3 and s.peripheral==one.name)
      click(row(2)); assert(s.tab==3 and s.peripheral==two.name)
      local stale=row(2); inventory({two,one}); assert(not stale.valid and s.peripheral_wire=='red')
      click(stale); assert(s.tab==3); click(row(1)); assert(s.tab==4 and s.topic==help.peripheral_topic('monitor'))
      inventory({one}); click(row(1)); assert(s.tab==3)
      select(p.filter.wire,2); assert(not s.peripheral_wire and s.inventory.wire=='green')
      click(row(1)); assert(s.tab==3 and s.peripheral_wire=='green'); click(row(1)); assert(s.tab==4)
      inventory({one}); inventory({}); assert(not s.peripheral_wire and p.details.text:find('Disconnected',1,true))
      inventory({one}); click(row(1)); assert(s.tab==3); click(row(1)); assert(s.tab==4)
      for _,code in ipairs({'E_BUSY','E_NETWORK_PENDING','E_LIMIT','E_ENGINE'}) do
        inventory({one}); inventory(nil,{code=code,message='explicit inventory failure'})
        assert(not s.peripheral_wire and s.inventory.error.code==code)
        inventory({one}); click(row(1)); assert(s.tab==3); click(row(1)); assert(s.tab==4)
      end
      inventory({{name='future-name',type='future-device',powered=false}})
      click(row(1)); local details=p.details.text; click(row(1))
      assert(s.tab==3 and p.details.text==details and s.message:find('Documentation unavailable',1,true))
      local selected=s.peripheral; local current=row(1)
      click(current,b); assert(s.peripheral==selected and s.tab==3)
      a.permission_group={allows_action=function() return false end}; click(current)
      assert(s.tab==3); a.permission_group=nil
      local replacement=p.rows.device_1.add{type='button',name='peripheral_999'}; click(replacement); assert(s.tab==3)
      a.opened={foreign=true}; click(current); assert(s.tab==3); a.opened=f
      local token=f.tags.token; f.tags.token=token+1; click(current); assert(s.tab==3); f.tags.token=token
      inspection_override=nil
      assert(editor.open(a,rec.id)); f=a.gui.screen[editor.frame_name]; c=f.content.editor; source_widget=c.source
      assert(not model.session(a.index).peripheral and not model.session(a.index).peripheral_wire)
      tab(f,3); local current_s=model.session(a.index)
      click(f.content.peripherals.rows.device_1.peripheral_1); assert(current_s.tab==3)
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
      assert(editor.open(a,removed.id)); f=a.gui.screen[editor.frame_name]
      local session=model.session(a.index); model.edit(a,session.token,'-- removed draft')
      registry.remove(removed.id); removed.body.destroy()
      click(f.title.close); a.opened=nil; a.selected=nil
      local _,retained=model.session(a.index); local documents=serpent.line(retained.documents)
      interaction.on_input{player_index=a.index,input_name='tc-interact',tick=tick}
      assert(not a.opened and not model.session(a.index) and serpent.line(retained.documents)==documents)
      a.selected=rec.body
      assert(interaction.on_input{player_index=a.index,input_name='tc-interact',tick=tick})
      f=a.gui.screen[editor.frame_name]; c=f.content.editor
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
      local failing,count=help.template:gsub('return value %+ 1','error("intentional [font=bad] failure")')
      assert(count==1,'starter private helper changed; review diagnostic witness')
      edit(f,failing)
      click(c.actions.save); click(c.actions.activate); rec.power_checked_tick=tick+1
      assert(scheduler.dispatch(rec,tick+1) and rec.status=='faulted' and rec.diagnostic.line)
      assert(rec.diagnostic.line==2 and rec.diagnostic.column>0 and rec.diagnostic.message:find('intentional',1,true))
      assert(rec.active.source==failing and rec.saved_source==failing and rec.state.samples==nil)
      tick=tick+1 -- Subsequent UI validation must not go backwards from the dispatch ledger.
      c.source.focused=false; editor.refresh(a)
      assert(not c.source.focused and f.content.selected_tab_index==1 and c.message.feedback.caption:find('Active run faulted',1,true))
      assert(not c.message.feedback.tooltip:find('[font=',1,true) and f.content.console_tab.caption[1]=='tc-editor.console-error')
      tab(f,2); click(f.content.console.actions['show-location'])
      assert(f.content.selected_tab_index==1 and c.source.focused and c.source.selection and c.source.text==failing)
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
    group('workspace-capacity-recovery-requires-an-accessible-computer-body',function()
      local _,bag=model.session(a.index)
      while true do
        local n=0; for _ in pairs(bag.documents) do n=n+1 end
        if n>=model.draft_slots then break end
        local target=build('computer',60+n*3,120)
        model.open(a,target.id)
      end
      assert(model.close(a.index,model.session(a.index).token))
      local target=build('computer',90,120); local documents=serpent.line(bag.documents)
      a.selected=nil
      interaction.on_input{player_index=a.index,input_name='tc-interact',tick=tick}
      assert(not a.opened and not model.session(a.index) and serpent.line(bag.documents)==documents)
      a.selected=target.body; a.can_reach_entity=function() return false end
      interaction.on_input{player_index=a.index,input_name='tc-interact',tick=tick}
      assert(not a.opened and not model.session(a.index))
      a.can_reach_entity=function() return true end
      interaction.on_input{player_index=a.index,input_name='tc-interact',tick=tick}
      f=a.gui.screen[editor.frame_name]
      assert(f and f.recovery_content and model.session(a.index).mode=='recovery')
      assert(serpent.line(bag.documents)==documents and not bag.documents[target.id])
      click(f.title.close); a.opened=nil
    end)
    group('workspace-reference-starter-compiles-supported-api',function()
      local context=admission.context(admission.new(),'help-example',0)
      local plan,e=compiler.compile(help.template,context); assert(plan,e and e.message)
      local seen={}; local tutorials=0
      for _,topic in ipairs(help.topics) do
        assert(not seen[topic.title]); seen[topic.title]=true
        if (topic.id or ''):find('tutorial.',1,true)==1 then tutorials=tutorials+1 end
      end
      local expected=0; for _ in pairs(help.tutorials) do expected=expected+1 end
      assert(tutorials==expected and #help.categories==7)
      if #original_game.players==0 then log('TC_WORKSPACE_CLIENT_SKIPPED no client-created player; all GUI checks are mocks') end
    end)
  end)
  game=original_game; storage.tweaked_computers=original_storage
  if not ok then error(err,0) end
  log('TC_CONTRACT_TOTAL '..groups)
end
return M
