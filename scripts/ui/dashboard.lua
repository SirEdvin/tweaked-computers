-- Player-local native widgets over a shared physical Dashboard model.
local registry=require('scripts.registry')
local model=require('scripts.dashboard-model')
local lifecycle=require('scripts.lifecycle')
local service=require('scripts.services.dashboard')
local scheduler=require('scripts.scheduler')
local limits=require('scripts.runtime.limits')
local data=require('scripts.runtime.data')
local charts=require('scripts.ui.dashboard-charts')
local M={frame_name='tc_dashboard'}
local function sessions()
  local root=registry.get(); root.dashboard_sessions=root.dashboard_sessions or {}; return root.dashboard_sessions
end
local function frame(player) return player.gui.screen[M.frame_name] end
function M.authorized(player,rec)
  if not player or not player.valid or not player.connected or not rec or rec.kind~='dashboard' or not rec.body.valid
    or player.controller_type==defines.controllers.ghost or player.force.index~=rec.force_index or player.surface.index~=rec.surface_index
    or rec.body.force.index~=rec.force_index or rec.body.surface.index~=rec.surface_index or not player.can_reach_entity(rec.body) then return false end
  local bound,role=registry.by_entity(rec.body)
  if bound~=rec or role~='body' then return false end
  local group=player.permission_group
  return not group or group.allows_action(defines.input_action.open_gui) and group.allows_action(defines.input_action.gui_click)
end
function M.close(player)
  local all=sessions(); all[player.index]=nil
  local f=frame(player)
  if f and f.valid then if player.opened==f then player.opened=nil end; f.destroy() end
end
local function current(player,s)
  local rec=registry.record(s.id)
  return M.authorized(player,rec) and rec.generation==s.generation and rec.body.unit_number==s.unit and rec or nil
end
local function plain_text(parent,name,value)
  local e=parent.add{type='text-box',name=name,text=value}
  e.read_only=true; e.word_wrap=true; e.style.rich_text_setting=defines.rich_text_setting.disabled
  return e
end
function M.resize(player)
  local f=frame(player); if not f or not f.valid then return end
  local width=math.max(300,math.min(1000,math.floor(player.display_resolution.width/player.display_scale)-32))
  local height=math.max(300,math.min(1000,math.floor(player.display_resolution.height/player.display_scale)-32))
  f.style.width=width; f.style.height=height
  f.api_name.style.width=width-32; f.api_name.style.height=40
  f.content.style.width=width-32; f.content.style.height=height-160
  f.location={x=math.floor((player.display_resolution.width-width*player.display_scale)/2),
    y=math.floor((player.display_resolution.height-height*player.display_scale)/2)}
end
local function build(parent,node,elements)
  local element
  if node.type=='column' or node.type=='row' then
    element=parent.add{type='flow',direction=node.type=='row' and 'horizontal' or 'vertical'}
    for _,child in ipairs(node.children) do build(element,child,elements) end
  elseif node.type=='label' then
    element=parent.add{type='label',caption=node.text}
    element.style.single_line=false; element.style.maximal_width=600
    element.style.rich_text_setting=defines.rich_text_setting.disabled
  elseif node.type=='button' then
    element=parent.add{type='button',caption='',enabled=node.enabled,mouse_button_filter={'left'}}
    local caption=element.add{type='label',name='plain_caption',caption=node.text,ignored_by_interaction=true}
    caption.style.rich_text_setting=defines.rich_text_setting.disabled
    caption.style.font_color={0,0,0}
  else
    element=parent.add{type='flow',direction='vertical'}
    element.add{type='label',name='status',caption='Chart pending'}
    element.add{type='camera',name='chart',position={0,0},surface_index=1,zoom=1}.visible=false
  end
  elements[node.id]=element
end
local function refresh(player,f,s,rec,spend)
  local m=model.current(rec); local pane=f.content
  local selected=s.selected; local occupied={}
  for slot=1,6 do if m.tabs[tostring(slot)] then occupied[#occupied+1]=slot end end
  if selected and not m.tabs[tostring(selected)] then selected=nil end
  selected=selected or occupied[1]; s.selected=selected
  -- A changed tab is rebuilt independently; stable tabs/elements keep copy focus and scroll.
  for slot=1,6 do
    local key=tostring(slot); local tab=m.tabs[key]; local view=s.tabs[key]
    if view and (not tab or view.generation~=tab.generation) then
      pane.remove_tab(view.tab); view.tab.destroy(); view.body.destroy(); s.tabs[key]=nil; view=nil
    end
    if tab and not view then
      spend(128)
      local native_tab=pane.add{type='tab',caption=''}
      native_tab.add{type='label',name='plain_caption',caption=tab.definition.title,ignored_by_interaction=true,style='tc_dashboard_tab_caption'}
      local body=pane.add{type='scroll-pane',horizontal_scroll_policy='auto',vertical_scroll_policy='auto'}
      local elements={}; build(body,tab.definition.content,elements)
      pane.add_tab(native_tab,body)
      view={generation=tab.generation,tab=native_tab,body=body,elements=elements}; s.tabs[key]=view
    end
    if view then
      view.body.style.width=f.style.minimal_width-56
      view.body.style.height=math.max(120,f.style.minimal_height-220)
      view.tab.plain_caption.caption=tab.definition.title
      local function update(node)
        spend(8)
        local e=view.elements[node.id]
        if node.type=='label' then if e.caption~=node.text then e.caption=node.text end
        elseif node.type=='button' then
          if e.plain_caption.caption~=node.text then e.plain_caption.caption=node.text end
          e.enabled=node.enabled and lifecycle.has_power(rec)
        elseif (node.type=='line' or node.type=='stacked_bars') and slot==selected and lifecycle.has_power(rec) then
          local height=math.max(180,math.min(700,f.style.minimal_height-360))
          local width=math.min(math.max(240,f.style.minimal_width-80),math.floor(height*900/700))
          e.chart.style.width=width; e.chart.style.height=math.floor(width*700/900)
          local chart_key=charts.show(rec,slot,node,tab)
          charts.view(chart_key,e.chart,e.status,player.display_scale)
        end
        for _,child in ipairs(node.children or {}) do update(child) end
      end
      update(tab.definition.content)
    end
  end
  local ordered=true
  for i,slot in ipairs(occupied) do if pane.tabs[i].tab~=s.tabs[tostring(slot)].tab then ordered=false; break end end
  if not ordered then
    for _,entry in ipairs(pane.tabs) do pane.remove_tab(entry.tab) end
    for _,slot in ipairs(occupied) do local view=s.tabs[tostring(slot)]; pane.add_tab(view.tab,view.body) end
  end
  -- Native tab indices can change after insertion/removal; select the owned tab object.
  if selected then
    for i,entry in ipairs(pane.tabs) do if entry.tab==s.tabs[tostring(selected)].tab then pane.selected_tab_index=i; break end end
  end
  f.availability.caption=lifecycle.has_power(rec) and (#occupied>0 and '' or 'Unconfigured dashboard') or 'Unpowered — retained content'
end
function M.open(player,id)
  local rec=registry.record(id); if not M.authorized(player,rec) then return end
  M.close(player)
  local s={id=id,generation=rec.generation,unit=rec.body.unit_number,token=registry.sequence(),tabs={}}
  sessions()[player.index]=s
  local f=player.gui.screen.add{type='frame',name=M.frame_name,direction='vertical',tags={token=s.token,player=player.index}}
  local title=f.add{type='flow',direction='horizontal'}
  title.add{type='label',caption=rec.body.localised_name}
  local drag=title.add{type='empty-widget',style='draggable_space_header'}
  drag.style.horizontally_stretchable=true; drag.drag_target=f
  s.dismiss=title.add{type='button',caption='Close'}
  plain_text(f,'api_name',rec.id)
  f.add{type='label',name='availability',caption='Loading dashboard'}
  f.add{type='tabbed-pane',name='content'}
  player.opened=f; M.resize(player)
  return f
end
local function owned(event,closing)
  local player=game.get_player(event.player_index); local s=player and sessions()[player.index]
  if not s or not event.element or not event.element.valid then return end
  local f=frame(player); if not f or not f.valid or not closing and player.opened~=f
    or f.tags.token~=s.token or f.tags.player~=player.index then return end
  local e=event.element
  while e and e~=f do
    if not closing and (not e.visible or not e.enabled) then return end
    e=e.parent
  end
  if e~=f then return end
  local rec=current(player,s)
  if not rec then M.close(player); return end
  return player,f,s,rec
end
function M.on_click(event)
  local player,f,s,rec=owned(event); if not player then return end
  if event.element==s.dismiss then M.close(player); return end
  if event.button~=defines.mouse_button_type.left or not s.selected or not lifecycle.has_power(rec) then return end
  local tab=model.current(rec).tabs[tostring(s.selected)]; local view=s.tabs[tostring(s.selected)]
  if not tab or not view or view.generation~=tab.generation then return end
  for id,element in pairs(view.elements) do
    if element==event.element and model.widget(tab,id).type=='button' then
      if not service.click(rec,s.selected,id,player.index,s.token,game.tick) then f.availability.caption='Button not delivered: unavailable or maintenance busy' end
      return
    end
  end
end
function M.on_tab(event)
  local player,f,s=owned(event); if not player or event.element~=f.content then return end
  local selected=f.content.selected_tab_index; local entry=selected and f.content.tabs[selected]
  if entry then for key,view in pairs(s.tabs) do if view.tab==entry.tab then s.selected=tonumber(key); return end end end
end
function M.on_closed(event)
  local player=game.get_player(event.player_index)
  if player and event.element==frame(player) then M.close(player) end
end
function M.on_player_unavailable(event)
  local player=game.get_player(event.player_index); if player then M.close(player) end
end
function M.on_size(event)
  local player=game.get_player(event.player_index); if player then M.resize(player) end
end
function M.on_opened(event)
  local player=game.get_player(event.player_index)
  if player and sessions()[player.index] and player.opened~=frame(player) then M.close(player) end
end
function M.tick(tick,spend)
  charts.begin()
  local all=sessions(); local indices={}; for index in pairs(all) do indices[#indices+1]=index end; table.sort(indices)
  for _,index in ipairs(indices) do
    local s=all[index]; local player=game.get_player(index); local rec=player and current(player,s); local f=player and frame(player)
    if not rec or not f or not f.valid or player.opened~=f then if player then M.close(player) else all[index]=nil end
    else
      -- Prepay the complete native widget traversal/build before touching GUI state.
      local admitted=scheduler.try_maintenance(function()
        local bytes,nodes=0,0
        for _,tab in pairs(model.current(rec).tabs) do
          local stats=data.measure(tab.definition,spend,limits.peripheral_call_bytes)
          bytes=bytes+stats.bytes; nodes=nodes+stats.nodes
        end
        spend(nodes*8+bytes+128)
        refresh(player,f,s,rec,function() end)
      end)
      if not admitted then f.availability.caption='Dashboard update pending: maintenance allowance unavailable' end
    end
  end
  charts.finish(spend)
end
service.register_player_authority(function(index,rec,token,slot)
  local player=game.get_player(index); local s=sessions()[index]; local f=player and frame(player)
  return s and s.token==token and s.id==rec.id and s.selected==slot and current(player,s)==rec
    and f and f.valid and player.opened==f and lifecycle.has_power(rec) or false
end)
scheduler.register_phase('render','ui-dashboard',M.tick)
registry.register_cleanup('dashboard-viewers',function(rec)
  if rec.kind~='dashboard' then return end
  for index,s in pairs(sessions()) do if s.id==rec.id then local player=game.get_player(index); if player then M.close(player) end end end
end)
return M
