-- Native task-oriented workspace. The model remains the only mutation authority.
local model=require('scripts.ui.editor-model')
local registry=require('scripts.registry')
local limits=require('scripts.runtime.limits')
local help=require('scripts.ui.help')
local layout=require('scripts.ui.editor-layout')
local scheduler=require('scripts.scheduler')
local M={frame_name='tc_program_editor'}
local inspector -- Fixed parsing-time callback; never persisted or exposed to guests.
function M.register_inspector(fn) assert(type(fn)=='function' and not inspector); inspector=fn end
local tabs={'editor','console','peripherals','reference','maintenance'}
local function tr(key) return {'tc-editor.'..key} end
local function tooltip_text(text) return string.gsub(text,'%[','［') end
local function diagnostic(e)
  if type(e)~='table' then return 'Action refused; draft retained.' end
  local function text(v) return type(v)=='string' and v:sub(1,512) or '' end
  return text(e.code)..': '..text(e.message)..(e.handler and (' | handler '..text(e.handler)) or '')
    ..(type(e.line)=='number' and (' | line '..e.line..':'..(e.column or 1)) or '')
    ..(type(e.source_revision)=='number' and (' | revision '..e.source_revision) or '')
end
local function plain(e) e.style.rich_text_setting=defines.rich_text_setting.disabled; return e end
local function label(parent,name,text)
  local e=plain(parent.add{type='label',name=name,caption=text}); e.style.single_line=false; return e
end
local function line(parent,name,text)
  local e=label(parent,name,text); e.style.single_line=true; e.style.height=20; return e
end
local function box(parent,name,text,height,readonly)
  local e=plain(parent.add{type='text-box',name=name,text=text,style='tc_editor_text'})
  e.read_only=readonly; e.word_wrap=false; e.style.height=height; return e
end
local function flow(parent,name,direction)
  local e=parent.add{type='flow',name=name,direction=direction or 'vertical'}
  if direction=='horizontal' then e.style.horizontal_spacing=4
  else e.style.vertical_spacing=4 end
  return e
end
local function button(parent,name,caption)
  local e=parent.add{type='button',name=name,caption=caption,style='tc_editor_button',mouse_button_filter={'left'}}
  return e
end
local function frame(player) return player.gui.screen[M.frame_name] end
local function content(f,name) return f.content[name] end
local function set_text(e,text) if e.text~=text then e.text=text end end
local function enable(e,enabled,reason)
  e.enabled=enabled; e.tooltip=reason or ''
end
local function recovery_list(b)
  local names={}; for id in pairs(b.documents) do names[#names+1]=id end; table.sort(names); return names
end
local function update_recovery(c,s,b)
  local names=recovery_list(b); local old=s.recovery_names or {}; local changed=#old~=#names
  for i,id in ipairs(names) do if old[i]~=id then changed=true end end
  if changed then
    local selected=old[c.recovery.selected_index]
    c.recovery.items=names; c.recovery.selected_index=0
    for i,id in ipairs(names) do if id==selected then c.recovery.selected_index=i end end
  end
  s.recovery_names=names
end
local function console(rec)
  local lines={'Rolling console: newest '..limits.console_entries..' entries / '..limits.console_bytes..' bytes; older output discarded.'}
  if rec.diagnostic then lines[#lines+1]='Active: '..diagnostic(rec.diagnostic) end
  for _,entry in ipairs(rec.logs) do lines[#lines+1]='['..entry.tick..'] '..entry.text end
  return table.concat(lines,'\n')
end
local function refresh_console(c,s,rec,force)
  -- Follow off freezes this selectable snapshot: no reassignment can reset scroll.
  if force or s.follow~=false then
    local text=console(rec)
    if c.output.text~=text then c.output.text=text; if s.follow~=false then c.output.scroll_to_bottom() end end
  end
  c.follow.state=s.follow~=false
  c.note.caption=s.follow==false and tr('console-paused') or tr('console-bounded')
  local details={}
  if s.validation then details[#details+1]='Draft / saved validation: '..(s.validation.diagnostic and diagnostic(s.validation.diagnostic) or 'valid') end
  details[#details+1]=rec.diagnostic and ('Active run: '..diagnostic(rec.diagnostic)) or 'No active runtime diagnostic.'
  set_text(c.detail,table.concat(details,'\n'))
  enable(c.actions['show-location'],(s.validation and s.validation.diagnostic and s.validation.diagnostic.line~=nil)
    or (rec.diagnostic and rec.diagnostic.line~=nil) or false,'Select a diagnostic location explicitly. Active source must match the draft.')
end
local function refresh_maintenance(c,s,b,rec)
  c.revisions.caption='Saved '..rec.saved_revision..' | active '..(rec.active and rec.active.revision or 'none')..' | draft base '..b.documents[s.id].base_revision
  c.review_panel.visible=s.review~=nil
  if s.review then
    c.review_panel.caption_label.caption='Current saved revision '..s.review.revision..' — read before resolving'
    set_text(c.review_panel.review,s.review.source)
  end
  c.active_panel.visible=s.active_review~=nil
  if s.active_review then
    c.active_panel.caption_label.caption='Formerly active snapshot, revision '..s.active_review.revision..' — recovery only'
    set_text(c.active_panel.review,s.active_review.source)
  end
  update_recovery(c,s,b)
  c.recovery_panel.visible=s.recovery_review~=nil
  if s.recovery_review then
    c.recovery_panel.caption_label.caption='Retained draft '..s.recovery_review.id..' — review before replacement'
    set_text(c.recovery_panel.review,s.recovery_review.source)
  end
  c.confirm_reset.visible=s.reset~=nil
  c.confirm_reset.identity.caption='Reset state of '..s.id..'? Source, KV and monitor data are retained.'
  c.confirm_forget.visible=s.forget~=nil
  c.confirm_forget.identity.caption='Permanently forget draft '..(s.forget or '')..'?'
  enable(c.danger.reset,rec.status=='stopped','Stop the computer before resetting its state.')
end
local function refresh_reference(c,s)
  local category=s.category or 1; local query=s.search or ''; local entries={}; local names={}
  for i,topic in ipairs(help.topics) do
    if (category==1 or topic.category==help.categories[category])
      and (query=='' or string.find(string.lower(topic.title..'\n'..topic.text),string.lower(query),1,true)) then
      entries[#entries+1]=i; names[#names+1]=topic.title
    end
  end
  s.reference_entries=entries; c.topics.items=names; c.topics.selected_index=0
  for i,id in ipairs(entries) do if id==s.topic then c.topics.selected_index=i end end
  if c.topics.selected_index==0 and #entries>0 then s.topic=entries[1]; c.topics.selected_index=1 end
  local topic=#entries>0 and help.topics[s.topic] or nil
  set_text(c.reference_text,topic and topic.text or 'No matching topic. Clear Search or choose another category.')
  enable(c.actions['select-reference'],topic~=nil,'Select the reference text, then use your native Copy control.')
  enable(c.actions.template,topic and topic.example==true or false,'Insert is available for the starter example and an empty draft only.')
end
local icons={monitor='item/tc-monitor',kv_database='item/tc-kv',logic_handler='item/tc-logic',configurator='item/tc-configurator'}
local function peripheral_details(c,s)
  local inventory=s.inventory; local selected=s.peripheral; local found
  if inventory and inventory.items then
    for _,item in ipairs(inventory.items) do if item.name==selected then found=item; break end end
  end
  local text
  if found then
    text='API name: '..found.name..'\nType: '..found.type..'\nDiscovery wire: '..inventory.wire
      ..'\n'..(found.powered and 'Powered' or 'Unpowered / service paused')..'\nSnapshot tick: '..inventory.tick
      ..'\nUse peripheral.wrap(name, "'..inventory.wire..'"). Calls recheck live authority.'
  elseif inventory and inventory.error then
    text=(selected and ('Last selected name: '..selected..'\n') or '')..'Inventory unavailable; presence is not claimed.\n'..diagnostic(inventory.error)
  elseif selected then text=selected..'\nDisconnected / not present on this refreshed '..(inventory and inventory.wire or s.wire)..' path.'
  else text='Select a device to inspect its opaque API name and channel.' end
  set_text(c.details,text)
end
local function inspect(c,s,rec,tick)
  local wire=s.wire or 'red'; local ok,items,e
  if inspector then ok,items,e=pcall(inspector,rec,wire,tick)
  else ok=false; items={code='E_UNSUPPORTED',message='Discovery service not installed; no inventory is claimed.'} end
  c.rows.clear()
  if not ok or not items then
    local problem=ok and e or items
    s.inventory={wire=wire,tick=tick,error=type(problem)=='table' and problem or {code='E_ENGINE',message='Discovery inspection failed.'}}
    label(c.rows,'pending',diagnostic(s.inventory.error))
  else
    assert(type(items)=='table' and #items<=limits.network_nodes,'invalid host discovery inventory')
    s.inventory={wire=wire,tick=tick,items=items}
    if #items==0 then label(c.rows,'empty','No connected peripherals. Wire the computer Network socket to a device Network socket on '..wire..'. Other roles and vanilla relays do not discover devices.') end
    for i,item in ipairs(items) do
      assert(type(item.name)=='string' and #item.name<=128 and type(item.type)=='string' and #item.type<=64 and type(item.powered)=='boolean','invalid host descriptor')
      local row=flow(c.rows,'device_'..i,'horizontal')
      row.add{type='sprite',sprite=icons[item.type] or 'utility/questionmark',name='icon'}.style.size=24
      -- These are generated opaque IDs / fixed host type names, not guest labels.
      -- Button styles do not support rich_text_setting in the pinned engine.
      local b=button(row,'peripheral_'..i,item.name..' / '..item.type..(item.powered and ' / + powered' or ' / ! unpowered'))
      b.style.horizontally_stretchable=true; b.tooltip='Select exact '..wire..' identity '..item.name
    end
  end
  c.snapshot.caption=wire..' snapshot at tick '..tick..' — Refresh to recheck current wiring/power'
  peripheral_details(c,s)
end
function M.refresh(player,message)
  local s,b=model.session(player.index); local f=frame(player)
  if not s or not f or not f.valid or f.tags.token~=s.token then return end
  -- Old saved GUI trees are not the new hierarchy. Retire only their session at
  -- admitted synchronized work; the accepted document stays intact. Never on_load.
  if f.tags.ui_version~=2 then
    model.close(player.index,s.token); if player.opened==f then player.opened=nil end
    f.destroy(); player.print('Computer workspace updated; draft retained. Reopen the computer or recovery drafts.')
    return
  end
  if message then s.message=message end
  if s.mode=='recovery' then
    local c=f.recovery_content
    if message then c.message.caption=message end
    update_recovery(c,s,b)
    local d=s.selected and b.documents[s.selected]; set_text(c.review,d and d.source or '')
    c.confirm_forget.visible=s.forget~=nil
    c.confirm_forget.identity.caption='Permanently forget draft '..(s.forget or '')..'?'
    return
  end
  local ok,rec,d=pcall(model.current,player,s.token)
  if not ok then f.title.status.caption='Unavailable'; f.title.status.tooltip=diagnostic(rec); return end
  local c=content(f,'editor'); local dirty=d.source~=d.base_source; local conflict=d.base_revision~=rec.saved_revision
  local status=rec.status..(rec.powered and ' / powered' or ' / unpowered')
  f.title.status.caption=status
  c.status.caption=(dirty and 'Unsaved' or 'Saved')..' | base '..d.base_revision..' | saved '..rec.saved_revision..' | active '..(rec.active and rec.active.revision or 'none')
  c.status.tooltip=rec.id..' | '..status..(conflict and ' | conflict: review the current saved source' or '')
  local validation=s.validation and (s.validation.diagnostic and diagnostic(s.validation.diagnostic) or 'Draft valid; Save and Run remain separate.')
  local text=conflict and 'Saved source changed. Review before Save / Run.' or s.message or validation
    or (d.source=='' and 'One Lua document. Insert a starter, or type/paste your own source.') or ''
  if not conflict and not message and not s.validation and rec.status=='faulted' and rec.diagnostic then
    text='Active run faulted. Console: '..diagnostic(rec.diagnostic)
  end
  f.title.status.tooltip=tooltip_text(c.status.caption..'\n'..(text~='' and text or (rec.diagnostic and diagnostic(rec.diagnostic)) or 'Close/Escape retains the draft; execution is unchanged.'))
  c.message.feedback.caption=text; c.message.feedback.tooltip=tooltip_text(text); c.message.review.visible=conflict
  c.actions.activate.caption=rec.status=='running' and tr('apply') or tr('run')
  enable(c.actions.activate,not conflict and d.source==rec.saved_source,'Save this draft and resolve any conflict before Run / Apply.')
  enable(c.actions.save,not conflict,'Review the current saved revision and Rebase or Reload before saving.')
  enable(c.actions.stop,rec.status~='stopped','Already stopped; source and data are retained.')
  c.message.template.visible=d.source=='' and not s.focus and not conflict
  local size=layout.measure(player.display_resolution,player.display_scale,s.focus)
  local source_height=size.source_height
  if c.source.style.minimal_height~=source_height then c.source.style.height=source_height end
  f.content.console_tab.caption=rec.diagnostic and tr('console-error') or tr('console')
  -- Routine refresh never touches source or hidden supporting panels.
  if s.tab==2 then refresh_console(content(f,'console'),s,rec)
  elseif s.tab==5 then refresh_maintenance(content(f,'maintenance'),s,b,rec) end
end
local function shell(player,s,title)
  local old=frame(player); if old then old.destroy() end
  local f=player.gui.screen.add{type='frame',name=M.frame_name,direction='vertical',style='tc_editor_frame',
    tags={player=player.index,token=s.token,id=s.id or '',generation=s.generation or 0,ui_version=2}}
  local titlebar=flow(f,'title','horizontal')
  local heading=line(titlebar,'heading',title); heading.style.font='default-large-semibold'; heading.style.height=28; heading.drag_target=f
  local drag=titlebar.add{type='empty-widget',name='drag',style='draggable_space_header'}
  drag.style.horizontally_stretchable=true; drag.style.height=24; drag.drag_target=f
  local state=line(titlebar,'status',''); state.style.maximal_width=190
  button(titlebar,'toggle_focus',tr('focus')); button(titlebar,'close',tr('close'))
  player.opened=f; return f
end
local function confirm(parent,name,action,caption)
  local p=flow(parent,name); label(p,'identity','')
  local row=flow(p,'buttons','horizontal'); button(row,'confirm-'..action,caption); button(row,'cancel-'..action,tr('cancel'))
  p.visible=false; return p
end
local function review_panel(parent,name,action,caption)
  local p=flow(parent,name); label(p,'caption_label',''); box(p,'review','',140,true)
  local row=flow(p,'actions','horizontal'); button(row,action,caption); p.visible=false; return p
end
function M.open_recovery(player,message)
  local s=model.open_recovery(player.index); local f=shell(player,s,tr('recovery-title'))
  f.title.toggle_focus.visible=false
  local c=f.add{type='scroll-pane',name='recovery_content',horizontal_scroll_policy='never',vertical_scroll_policy='auto'}
  label(c,'message',message or 'Review retained text and use native Copy. Nothing executes here.')
  c.add{type='drop-down',name='recovery',items={}}
  local actions=flow(c,'actions','horizontal')
  button(actions,'review',tr('review-selected')); button(actions,'forget',tr('forget-reviewed'))
  confirm(c,'confirm_forget','forget',tr('confirm-forget'))
  box(c,'review','',240,true)
  button(c,'select-recovery',tr('select-text'))
  M.refresh(player); M.resize(player)
end
function M.open(player,id)
  local ok,s,d=pcall(model.open,player,id)
  if not ok then
    if type(s)=='table' and s.code=='E_CAPACITY' then M.open_recovery(player,diagnostic(s))
    else player.print('Computer cannot be opened; check force, distance and permissions.') end
    return false
  end
  s.tab=1; s.follow=true; s.wire='red'; s.category=1; s.search=''; s.topic=1
  local f=shell(player,s,tr('title')); local pane=f.add{type='tabbed-pane',name='content',style='tc_editor_tabs'}
  for _,name in ipairs(tabs) do
    local tab=pane.add{type='tab',name=name..'_tab',caption=tr(name),style='tc_editor_tab'}
    local c
    if name=='maintenance' then c=pane.add{type='scroll-pane',name=name,horizontal_scroll_policy='never',vertical_scroll_policy='auto'}
    else c=flow(pane,name) end
    pane.add_tab(tab,c)
  end
  pane.selected_tab_index=1
  local c=content(f,'editor')
  box(c,'source',d.source,300,false)
  local actions=flow(c,'actions','horizontal')
  for _,name in ipairs({'validate','save','activate','stop'}) do button(actions,name,tr(name=='activate' and 'run' or name)) end
  line(c,'status','')
  local message=flow(c,'message','horizontal'); line(message,'feedback',''); button(message,'review',tr('review-conflict'))
  button(message,'template',tr('starter'))
  c=content(f,'console')
  local tools=flow(c,'actions','horizontal')
  button(tools,'refresh-console',tr('refresh')); button(tools,'show-location',tr('show-location'))
  c.add{type='checkbox',name='follow',caption=tr('follow'),state=true}
  line(c,'note',''); box(c,'output','',200,true); box(c,'detail','',70,true)
  c=content(f,'peripherals')
  local filter=flow(c,'filter','horizontal'); line(filter,'label',tr('channel'))
  filter.add{type='drop-down',name='wire',items={tr('red'),tr('green')},selected_index=1}
  button(filter,'inspect',tr('refresh-peripherals'))
  line(c,'snapshot','Select a channel and Refresh to inspect actual discovery.')
  c.add{type='scroll-pane',name='rows',horizontal_scroll_policy='never',vertical_scroll_policy='auto'}
  box(c,'details','Select a device to inspect its opaque API name and channel.',100,true)
  c=content(f,'reference')
  local filters=flow(c,'filters','horizontal'); line(filters,'label',tr('search'))
  local search=plain(filters.add{type='textfield',name='search',text=''}); search.style.width=190
  filters.add{type='drop-down',name='category',items=help.categories,selected_index=1}
  c.add{type='drop-down',name='topics',items={}}
  box(c,'reference_text','',200,true)
  tools=flow(c,'actions','horizontal'); button(tools,'select-reference',tr('select-text')); button(tools,'template',tr('insert-starter'))
  line(c,'copy-note',tr('copy-note'))
  refresh_reference(c,s)
  c=content(f,'maintenance')
  label(c,'revisions','')
  tools=flow(c,'review_actions','horizontal'); button(tools,'review',tr('review-current')); button(tools,'review-active',tr('review-active'))
  local review=review_panel(c,'review_panel','rebase',tr('rebase'))
  button(review.actions,'reload',tr('reload'))
  review_panel(c,'active_panel','copy-active',tr('copy-active'))
  label(c,'recovery_label',tr('retained-drafts'))
  c.add{type='drop-down',name='recovery',items={}}
  tools=flow(c,'recovery_actions','horizontal'); button(tools,'review-recovery',tr('review-selected')); button(tools,'forget',tr('forget-reviewed'))
  review_panel(c,'recovery_panel','recover',tr('copy-draft'))
  confirm(c,'confirm_forget','forget',tr('confirm-forget'))
  label(c,'danger_label',tr('danger'))
  tools=flow(c,'danger','horizontal'); button(tools,'reset',tr('reset'))
  confirm(c,'confirm_reset','reset',tr('confirm-reset'))
  M.refresh(player); M.resize(player); content(f,'editor').source.focus()
  return true
end
-- Exact root identity + visible active subtree. The depth bound covers this fixed
-- hierarchy, not an open-ended walk, and never accepts a name-only forged action.
local function owned(event,closing)
  local player=game.get_player(event.player_index)
  if not player or not player.valid then return end
  local f=frame(player); local s=model.session(player.index); local e=event.element
  if not f or not f.valid or not s or f.tags.ui_version~=2 or f.tags.token~=s.token or f.tags.player~=player.index
    or f.tags.id~=(s.id or '') or f.tags.generation~=(s.generation or 0) then return end
  if not closing and player.opened~=f then return end
  if not e or not e.valid then return end
  local ancestor=e; local panel
  for _=1,16 do
    if ancestor==f then
      if s.mode~='recovery' then
        if panel and panel~=tabs[s.tab or 1] then return end
        if not closing and e~=f.title.close and not pcall(model.current,player,s.token) then return end
      else
        local group=player.permission_group
        if group and (not group.allows_action(defines.input_action.gui_click) or not group.allows_action(defines.input_action.open_gui)) then return end
      end
      return player,f,s
    end
    if not closing and (ancestor.visible==false or ancestor.enabled==false) then return end
    if ancestor.parent==f.content then
      for _,name in ipairs(tabs) do if ancestor==f.content[name] then panel=name; break end end
    end
    ancestor=ancestor.parent; if not ancestor then return end
  end
end
local function selection(c,s) return s.recovery_names and s.recovery_names[c.recovery.selected_index] end
function M.on_text(event)
  local player,f,s=owned(event); if not player or s.mode=='recovery' then return end
  if event.element==content(f,'reference').filters.search then
    local text=event.element.text
    if #text>128 then event.element.text=s.search or ''; return end
    s.search=text; refresh_reference(content(f,'reference'),s); return
  end
  if event.element~=content(f,'editor').source then return end
  local ok,e=pcall(model.edit,player,s.token,event.element.text)
  if not ok then
    local _,b=model.session(player.index); event.element.text=b.documents[s.id].source
    M.refresh(player,diagnostic(e)); return
  end
  s.message=nil; M.refresh(player)
end
local function activate_tab(player,f,s,index,tick)
  s.tab=index; f.content.selected_tab_index=index
  if index==2 then
    local rec=model.current(player,s.token); local c=content(f,'console')
    refresh_console(c,s,rec,c.output.text=='')
  elseif index==3 then local rec=model.current(player,s.token); inspect(content(f,'peripherals'),s,rec,tick)
  elseif index==4 then refresh_reference(content(f,'reference'),s) end
  M.refresh(player)
end
function M.on_tab(event)
  local player,f,s=owned(event)
  if not player or s.mode=='recovery' or event.element~=f.content or s.focus then return end
  local index=f.content.selected_tab_index
  if not index or index<1 or index>#tabs then return end
  activate_tab(player,f,s,index,event.tick)
end
function M.on_selection(event)
  local player,f,s=owned(event); if not player then return end
  if s.mode=='recovery' then
    if event.element==f.recovery_content.recovery then s.selected=nil; s.forget=nil; M.refresh(player) end
    return
  end
  local c=content(f,'reference')
  if event.element==c.filters.category then
    s.category=math.max(1,math.min(#help.categories,event.element.selected_index)); refresh_reference(c,s)
  elseif event.element==c.topics then
    s.topic=s.reference_entries[event.element.selected_index]; refresh_reference(c,s)
  elseif event.element==content(f,'peripherals').filter.wire then
    s.wire=event.element.selected_index==2 and 'green' or 'red'
    inspect(content(f,'peripherals'),s,model.current(player,s.token),event.tick)
  elseif event.element==content(f,'maintenance').recovery then
    s.recovery_review=nil; s.forget=nil; M.refresh(player)
  end
end
function M.on_checked(event)
  local player,f,s=owned(event)
  if not player or s.mode=='recovery' or event.element~=content(f,'console').follow then return end
  s.follow=event.element.state; refresh_console(content(f,'console'),s,model.current(player,s.token),s.follow)
end

local function source_location(player,f,s,rec,d)
  local candidate=s.validation and s.validation.diagnostic
  local e=candidate or rec.diagnostic
  if not e or not e.line then return nil,{code='E_NOT_FOUND',message='No diagnostic source location.'} end
  if not candidate and (not rec.active or rec.active.source~=d.source) then
    return nil,{code='E_BUSY',message='Diagnostic belongs to different active source. Review its snapshot in Maintenance first.'}
  end
  local start=1
  for _=2,math.min(e.line,limits.source_bytes+1) do
    local newline=string.find(d.source,'\n',start,true); if not newline then break end; start=newline+1
  end
  local finish=string.find(d.source,'\n',start,true) or (#d.source+1)
  -- Native selection uses characters, not UTF-8 bytes. Select the whole source line.
  local function chars(text) local _,n=string.gsub(text,'[^\128-\191]',''); return n end
  local first=chars(string.sub(d.source,1,start-1))+1
  local last=first+chars(string.sub(d.source,start,finish-1))-1
  activate_tab(player,f,s,1,game.tick); local source=content(f,'editor').source
  source.focus(); source.select(first,last)
  return 'Diagnostic line selected in the current draft.'
end
function M.on_click(event)
  local player,f,s=owned(event); if not player then return end
  local element=event.element; local action=element.name
  if element==f.title.close then
    model.close(player.index,s.token); if player.opened==f then player.opened=nil end; f.destroy(); return
  end
  local ok,message,e=pcall(function()
    if s.mode=='recovery' then
      local c=f.recovery_content
      if element==c['select-recovery'] then c.review.focus(); c.review.select_all(); return 'Use native Copy to copy the selected text.' end
      if element~=c.actions[action] and element~=c.confirm_forget.buttons[action] then return end
      return model.recovery_action(player.index,s.token,action,selection(c,s))
    end
    local rec,d=model.current(player,s.token)
    if element==f.title.toggle_focus then
      if not s.focus then s.before_focus=s.tab; s.focus=true; s.tab=1; f.content.selected_tab_index=1
      else s.focus=false; activate_tab(player,f,s,s.before_focus or 1,event.tick) end
      M.resize(player); return 'Focus layout changed; source and execution unchanged.'
    end
    local c=content(f,'editor'); local maintenance=content(f,'maintenance')
    if element==c.message.template or element==content(f,'reference').actions.template then
      if d.source~='' then return nil,{code='E_BUSY',message='Starter example only inserts into an empty draft. Select/copy reference text instead.'} end
      model.edit(player,s.token,help.template); c.source.text=d.source; return 'Starter inserted into draft only. Validate, Save and Run are separate.'
    elseif element==c.actions.activate then return model.action(player,s.token,rec.status=='running' and 'apply' or 'run',event.tick)
    elseif element==c.message.review then
      local result,err=model.action(player,s.token,'review',event.tick)
      activate_tab(player,f,s,5,event.tick); return result,err
    elseif element==content(f,'console').actions['refresh-console'] then
      refresh_console(content(f,'console'),s,rec,true); return 'Console snapshot refreshed.'
    elseif element==content(f,'console').actions['show-location'] then return source_location(player,f,s,rec,d)
    elseif element==content(f,'peripherals').filter.inspect then
      inspect(content(f,'peripherals'),s,rec,event.tick); return 'Selected discovery channel refreshed.'
    elseif element==content(f,'reference').actions['select-reference'] then
      local text=content(f,'reference').reference_text; text.focus(); text.select_all(); return 'Use native Copy to copy the selected text.'
    end
    local i=tonumber(string.match(action,'^peripheral_(%d+)$'))
    if i and s.inventory and s.inventory.items and s.inventory.items[i] then
      local rows=content(f,'peripherals').rows
      if rows['device_'..i] and element==rows['device_'..i][action] then
        s.peripheral=s.inventory.items[i].name; peripheral_details(content(f,'peripherals'),s); return 'Selected exact API identity.'
      end
    end
    local allowed=(s.tab==1 and element==c.actions[action] and (action=='validate' or action=='save' or action=='stop'))
      or (s.tab==5 and (element==maintenance.review_actions[action]
        or element==maintenance.review_panel.actions[action] or element==maintenance.active_panel.actions[action]
        or element==maintenance.recovery_actions[action] or element==maintenance.recovery_panel.actions[action]
        or element==maintenance.confirm_forget.buttons[action] or element==maintenance.confirm_reset.buttons[action]
        or element==maintenance.danger[action]))
    if not allowed then return end
    local result,err=model.action(player,s.token,action,event.tick,selection(maintenance,s))
    if result and (action=='reload' or action=='recover' or action=='copy-active') then c.source.text=d.source end
    return result,err
  end)
  if not ok then M.refresh(player,diagnostic(message))
  elseif message or e then M.refresh(player,message or diagnostic(e)) end
end
function M.on_closed(event)
  local player,f,s=owned(event,true)
  if not player or event.element~=f then return end
  model.close(player.index,s.token); f.destroy() -- Never reopen over the next GUI.
end
function M.on_player_unavailable(event)
  local player=game.get_player(event.player_index); local s=model.session(event.player_index)
  if s then model.close(event.player_index,s.token) end
  if player and player.valid then local f=frame(player); if f then f.destroy() end end
end
function M.resize(player)
  local f=player and frame(player); local s=player and model.session(player.index)
  if not f or not f.valid or not s then return end
  if f.tags.ui_version~=2 then M.refresh(player); return end
  local size=layout.measure(player.display_resolution,player.display_scale,s.focus)
  f.style.width=size.width; f.style.height=size.height
  f.title.style.width=size.width-24; f.title.toggle_focus.caption=s.focus and tr('exit-focus') or tr('focus')
  if not f.location then
    f.location={x=math.floor((player.display_resolution.width-size.width*player.display_scale)/2),
      y=math.floor((player.display_resolution.height-size.height*player.display_scale)/2)}
  end
  f.location=layout.clamp(f.location,player.display_resolution,player.display_scale,size)
  local root=s.mode=='recovery' and f.recovery_content or f.content
  root.style.width=size.width-24; root.style.height=size.height-56
  local function fit(parent)
    for _,child in pairs(parent.children) do
      if child.type=='label' then child.style.maximal_width=size.content_width end
      if child.type=='text-box' then child.style.width=size.content_width end
      if #child.children>0 then fit(child) end
    end
  end
  fit(root)
  if s.mode=='recovery' then f.recovery_content.review.style.height=math.max(40,size.height-240); return end
  for i,name in ipairs(tabs) do
    content(f,name).style.width=size.content_width
    content(f,name).style.height=size.content_height
    f.content[name..'_tab'].visible=not s.focus
  end
  local c=content(f,'editor'); c.source.style.height=size.source_height
  c.status.visible=not s.focus; c.message.visible=not s.focus

  c.message.feedback.style.maximal_width=size.content_width-160
  content(f,'console').output.style.height=math.max(40,size.content_height-164)
  content(f,'peripherals').rows.style.height=math.max(40,size.content_height-180)
  content(f,'peripherals').rows.style.width=size.content_width
  content(f,'reference').reference_text.style.height=math.max(40,size.content_height-144)
  if not size.supported then c.message.feedback.caption='Small display: use at least 760 × 480 effective GUI units, or reduce GUI scale.' end
end
function M.on_size(event) M.resize(game.get_player(event.player_index)) end
function M.tick(tick,spend)
  if tick%15~=0 then return end
  spend(#game.connected_players+1)
  for _,player in pairs(game.connected_players) do
    local f=frame(player)
    if f and f.valid and player.opened==f then
      scheduler.try_maintenance(function() spend(limits.console_bytes+limits.console_entries*64+1); M.refresh(player) end)
    end
  end
end
scheduler.register_phase('render','program-editor',M.tick)
return M
