-- Native GUI adapter; all backend actions revalidate exact player/body/session.
local model=require('scripts.ui.editor-model')
local registry=require('scripts.registry')
local limits=require('scripts.runtime.limits')
local help=require('scripts.ui.help')
local scheduler=require('scripts.scheduler')
local M={frame_name='tc_program_editor'}
local inspector -- Fixed host callback only, never stored in storage or exposed to guests.
function M.register_inspector(fn) assert(type(fn)=='function' and not inspector); inspector=fn end
local function diagnostic(e)
  if type(e)~='table' then return 'Action refused; draft retained.' end
  local function text(v) return type(v)=='string' and v:sub(1,512) or '' end
  return text(e.code)..': '..text(e.message)..(e.handler and (' | handler '..text(e.handler)) or '')
    ..(type(e.line)=='number' and (' | line '..e.line..':'..(e.column or 1)) or '')
    ..(type(e.source_revision)=='number' and (' | revision '..e.source_revision) or '')
end
local function plain(element) element.style.rich_text_setting=defines.rich_text_setting.disabled; return element end
local function label(parent,name,text)
  local e=plain(parent.add{type='label',name=name,caption=text}); e.style.single_line=false; return e
end
local function box(parent,name,text,height,readonly,width)
  local e=plain(parent.add{type='text-box',name=name,text=text,style='tc_editor_text'})
  e.read_only=readonly; e.word_wrap=false; e.style.width=width; e.style.height=height
  return e
end
local function button(parent,name,caption)
  return parent.add{type='button',name=name,caption=caption,mouse_button_filter={'left'}}
end
local action_buttons={{'validate','Validate'},{'save','Save'},{'run','Run'},{'apply','Apply'},
  {'stop','Stop'},{'reset','Reset State'},{'help','API Help'},{'close','Close'},
  {'review','Review Current'},{'template','Template'},{'inspect','Refresh Peripherals'}}
local function add_actions(c,width,index)
  local actions=c.add{type='table',name='actions',column_count=width>=700 and 4 or width>=420 and 2 or 1,index=index}
  for _,item in ipairs(action_buttons) do button(actions,item[1],item[2]) end
end
local function frame(player) return player.gui.screen[M.frame_name] end
local function dimensions(player)
  local resolution=player.display_resolution; local scale=player.display_scale
  return math.max(300,math.min(800,math.floor(resolution.width/scale)-64)),
    math.max(240,math.min(850,math.floor(resolution.height/scale)-80))
end
local function recovery_list(b)
  local names={}; for id in pairs(b.documents) do names[#names+1]=id end; table.sort(names)
  return names
end
local function update_recovery(content,s,b)
  local names=recovery_list(b); local old=s.recovery_names or {}
  local changed=#old~=#names
  for i,id in ipairs(names) do if old[i]~=id then changed=true end end
  if changed then
    local selected=old[content.recovery.selected_index]
    content.recovery.items=names; content.recovery.selected_index=0
    for i,id in ipairs(names) do if id==selected then content.recovery.selected_index=i end end
  end
  s.recovery_names=names
end
local function console(rec)
  local lines={'Rolling console: newest '..limits.console_entries..' entries / '..limits.console_bytes..' bytes; older output discarded.'}
  if rec.diagnostic then lines[#lines+1]='Active: '..diagnostic(rec.diagnostic) end
  for _,entry in ipairs(rec.logs) do lines[#lines+1]='['..entry.tick..'] '..entry.text end
  return table.concat(lines,'\n')
end
function M.refresh(player,message)
  local s,b=model.session(player.index); local f=frame(player)
  if not s or not f or not f.valid or f.tags.token~=s.token then return end
  local content=f.content
  if message then content.message.caption=message end
  if s.mode=='recovery' then
    update_recovery(content,s,b)
    local d=s.selected and b.documents[s.selected]
    content.review.text=d and d.source or ''
    content.confirm_forget.visible=s.forget~=nil
    return
  end
  local rec=registry.record(s.id); local d=b.documents[s.id]
  if not model.authorized(player,rec) then content.message.caption='Computer unavailable; draft retained. Close and reopen when accessible.'; return end
  content.status.caption=rec.id..' | '..rec.status..(rec.powered and ' | powered' or ' | unpowered / paused')
    ..' | draft base '..d.base_revision..(d.source~=d.base_source and ' (unsaved)' or '')
    ..(d.base_revision~=rec.saved_revision and ' (conflict: Review Current)' or '')
    ..' | saved '..rec.saved_revision..' | active '..(rec.active and rec.active.revision or 'none')
  content.output.text=console(rec)
  if s.validation then
    content.validation.caption=s.validation.kind..' (base revision '..s.validation.revision..'): '
      ..(s.validation.diagnostic and diagnostic(s.validation.diagnostic) or 'valid')
  else content.validation.caption='' end
  content.review_panel.visible=s.review~=nil
  if s.review then content.review_panel.review.text=s.review.source; content.review_panel.caption_label.caption='Current saved revision '..s.review.revision end
  content.confirm_reset.visible=s.reset~=nil
  content.confirm_forget.visible=s.forget~=nil
  update_recovery(content,s,b)
end
local function shell(player,s,title)
  local old=frame(player); if old then old.destroy() end
  local width,height=dimensions(player)
  local f=player.gui.screen.add{type='frame',name=M.frame_name,direction='vertical',caption=title,
    tags={player=player.index,token=s.token,id=s.id or ''}}
  f.style.width=width; f.style.maximal_height=height
  local content=f.add{type='scroll-pane',name='content',horizontal_scroll_policy='never',vertical_scroll_policy='auto'}
  content.style.width=width-28; content.style.maximal_height=height-48
  f.force_auto_center(); player.opened=f
  return f,content,width-56
end
function M.open_recovery(player,message)
  local s=model.open_recovery(player.index)
  local _,c,width=shell(player,s,'Computer recovery drafts')
  label(c,'message',message or 'Select a retained draft to review/copy. No computer executes here.')
  c.add{type='drop-down',name='recovery',items={}}
  local actions=c.add{type='flow',name='recovery_actions',direction='vertical'}
  button(actions,'review','Review selected'); button(actions,'forget','Forget reviewed'); button(actions,'close','Close')
  local confirm=c.add{type='flow',name='confirm_forget',direction='vertical'}
  button(confirm,'confirm-forget','Confirm Forget'); button(confirm,'cancel-forget','Cancel')
  box(c,'review','',300,true,width)
  M.refresh(player); M.resize(player)
end
function M.open(player,id)
  local ok,s,d=pcall(model.open,player,id)
  if not ok then
    if type(s)=='table' and s.code=='E_CAPACITY' then M.open_recovery(player,diagnostic(s))
    else player.print('Computer cannot be opened; check force, distance and permissions.') end
    return false
  end
  local _,c,width=shell(player,s,'Tweaked Computers — program')
  label(c,'status',''); label(c,'message','Close/Escape retains this draft. Save does not activate.')
  box(c,'source',d.source,math.min(300,math.max(120,select(2,dimensions(player))-300)),false,width)
  add_actions(c,width)
  local reset=c.add{type='flow',name='confirm_reset',direction='vertical'}
  button(reset,'confirm-reset','Confirm Reset State'); button(reset,'cancel-reset','Cancel')
  label(c,'validation','')
  local review=c.add{type='flow',name='review_panel',direction='vertical'}
  label(review,'caption_label','')
  box(review,'review','',160,true,width)
  local review_actions=review.add{type='flow',name='review_actions',direction='vertical'}
  button(review_actions,'rebase','Rebase — keep draft'); button(review_actions,'reload','Reload — discard draft')
  box(c,'output','',120,true,width)
  local panel=c.add{type='flow',name='help_panel',direction='vertical'}; panel.visible=false
  box(panel,'help_text',help.text,300,true,width)
  box(panel,'template_text',help.template,150,true,width)
  box(c,'peripherals','Press Refresh Peripherals for current red/green discovery.',100,true,width)
  label(c,'recovery_label','Recovery drafts: select an identity to copy its text or explicitly forget it.')
  c.add{type='drop-down',name='recovery',items={}}
  local recovery=c.add{type='flow',name='recovery_actions',direction='vertical'}
  button(recovery,'recover','Copy selected draft'); button(recovery,'forget','Forget selected draft')
  local forget=c.add{type='flow',name='confirm_forget',direction='vertical'}
  button(forget,'confirm-forget','Confirm Forget'); button(forget,'cancel-forget','Cancel')
  M.refresh(player); M.resize(player); c.source.focus()
  return true
end
local function owned(event,closing)
  local player=game.get_player(event.player_index)
  if not player or not player.valid then return end
  local f=frame(player); local s=model.session(player.index); local e=event.element
  if not f or not f.valid or not s or f.tags.token~=s.token or f.tags.player~=player.index then return end
  if not closing and player.opened~=f then return end
  if not e or not e.valid then return end
  local ancestor=e
  for _=1,8 do
    if ancestor==f then return player,f,s end
    ancestor=ancestor.parent; if not ancestor then return end
  end
end
function M.on_text(event)
  local player,f,s=owned(event)
  if not player or s.mode=='recovery' or event.element~=f.content.source then return end
  local ok,e=pcall(model.edit,player,s.token,event.element.text)
  if not ok then
    local _,b=model.session(player.index); event.element.text=b.documents[s.id].source
    M.refresh(player,diagnostic(e)); return
  end
  M.refresh(player)
end
local function inspect(rec,tick)
  if not inspector then return 'Discovery service not installed in this build; no inventory is claimed.' end
  local lines={}
  for _,wire in ipairs({'red','green'}) do
    local ok,items,e=pcall(inspector,rec,wire,tick)
    if not ok then lines[#lines+1]=wire..': '..diagnostic(items)
    elseif not items then lines[#lines+1]=wire..': '..diagnostic(e)
    else
      assert(type(items)=='table' and #items<=limits.network_nodes,'invalid host discovery inventory')
      lines[#lines+1]=wire..': '..(#items==0 and 'no connected peripherals' or 'complete inventory')
      for _,item in ipairs(items) do
        assert(type(item.name)=='string' and #item.name<=128 and type(item.type)=='string' and #item.type<=64 and type(item.powered)=='boolean','invalid host descriptor')
        lines[#lines+1]=item.name..' / '..item.type..(item.powered and ' / powered' or ' / unpowered')
      end
    end
  end
  return table.concat(lines,'\n')
end
function M.on_click(event)
  local player,f,s=owned(event)
  if not player then return end
  local action=event.element.name
  if action=='close' then model.close(player.index,s.token); if player.opened==f then player.opened=nil end; f.destroy(); return end
  local ok,message,e=pcall(function()
    local selection=f.content.recovery.selected_index
    local id=s.recovery_names and s.recovery_names[selection]
    if s.mode=='recovery' then return model.recovery_action(player.index,s.token,action,id) end
    local rec,d=model.current(player,s.token)
    if action=='help' then f.content.help_panel.visible=not f.content.help_panel.visible; return 'API v1 help; source and run unchanged.'
    elseif action=='inspect' then f.content.peripherals.text=inspect(rec,event.tick); return 'Red/green discovery refreshed separately.'
    elseif action=='template' then
      if d.source~='' then return nil,{code='E_BUSY',message='template only replaces an empty draft; copy from API Help instead'} end
      model.edit(player,s.token,help.template); f.content.source.text=d.source; return 'Template inserted into draft only.'
    end
    local result,err=model.action(player,s.token,action,event.tick,id)
    if action=='reload' or action=='recover' then f.content.source.text=d.source end
    return result,err
  end)
  M.refresh(player,not ok and diagnostic(message) or message or diagnostic(e))
end
function M.on_closed(event)
  local player,f,s=owned(event,true)
  if not player or event.element~=f then return end
  model.close(player.index,s.token); f.destroy() -- Do not reopen over the next GUI.
end
function M.on_opened(event)
  if not event.entity then return end
  local rec=registry.by_entity(event.entity)
  if rec and rec.kind=='computer' then M.open(game.get_player(event.player_index),rec.id) end
end
function M.on_input(event)
  local player=game.get_player(event.player_index)
  if not player or not player.valid then return end
  -- Do not hijack another GUI or native typing. This shortcut is only an entry.
  if player.opened then return end
  local group=player.permission_group
  if group and not group.allows_action(defines.input_action.custom_input) then return end
  local rec=registry.by_entity(player.selected)
  if rec and rec.kind=='computer' then M.open(player,rec.id)
  elseif event.input_name=='tc-open-editor' then M.open_recovery(player) end
end
function M.on_player_unavailable(event)
  local player=game.get_player(event.player_index)
  local s=model.session(event.player_index)
  if s then model.close(event.player_index,s.token) end
  if player and player.valid then local f=frame(player); if f then f.destroy() end end
end
function M.resize(player)
  local f=player and frame(player)
  if not f or not f.valid then return end
  local width,height=dimensions(player); f.style.width=width; f.style.maximal_height=height
  f.content.style.width=width-28; f.content.style.maximal_height=height-48
  if f.content.actions then
    local index=f.content.actions.get_index_in_parent(); f.content.actions.destroy()
    add_actions(f.content,width-56,index)
  end
  local function resize(parent)
    for _,child in pairs(parent.children) do
      if child.type=='label' then child.style.maximal_width=width-56 end
      if child.type=='text-box' then child.style.width=width-56 end
      if #child.children>0 then resize(child) end
    end
  end
  resize(f.content); f.force_auto_center() -- Never changes player.opened or focus.
end
function M.on_size(event) M.resize(game.get_player(event.player_index)) end
-- Live status/output only for active frames, charged and refreshed at 4Hz.
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
