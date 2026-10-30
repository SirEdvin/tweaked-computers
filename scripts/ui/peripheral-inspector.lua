-- Native, player-scoped read-only inspectors. The scheduler owns all polling.
local registry=require('scripts.registry')
local scheduler=require('scripts.scheduler')
local model=require('scripts.ui.peripheral-inspector-model')
local lifecycle=require('scripts.lifecycle')
local monitor=require('scripts.services.monitor')
local M={frame_name='tc_peripheral_inspector'}
local draw_logic
local draw_pending
M.supports=model.supports
local function tr(key,...) return {'tc-inspector.'..key,...} end
local function frame(player) return player.gui.screen[M.frame_name] end
local function text(parent,name,value)
  local e=parent.add{type='text-box',name=name,text=value or ''}
  e.read_only=true; e.word_wrap=true; e.style.rich_text_setting=defines.rich_text_setting.disabled; return e
end
local function label(parent,caption,name)
  local e=parent.add{type='label',name=name,caption=caption}; e.style.single_line=false
  e.style.maximal_width=650; return e
end
function M.close(player)
  model.close(player.index)
  local f=frame(player)
  if f and f.valid then if player.opened==f then player.opened=nil end; f.destroy() end
end
local function owned(event,closing)
  local player=game.get_player(event.player_index)
  if not player or not player.valid or not event.element or not event.element.valid then return end
  local f=frame(player); local s=model.session(player.index)
  if not f or not f.valid or not s or (not closing and player.opened~=f) then return end
  local e=event.element
  while e and e~=f do
    if not closing and (e.visible==false or e.enabled==false) then return end
    e=e.parent
  end
  if e~=f or f.tags.player~=player.index or f.tags.token~=s.token or f.tags.ui_version~=model.version then return end
  local ok,rec=pcall(model.current,player,s.token)
  if not ok then M.close(player); return end
  return player,f,s,rec
end
function M.resize(player)
  local f=player and player.valid and frame(player)
  if not f or not f.valid then return end
  local width=math.max(300,math.min(720,math.floor(player.display_resolution.width/player.display_scale)-32))
  local height=math.max(300,math.min(660,math.floor(player.display_resolution.height/player.display_scale)-32))
  f.style.width=width; f.style.height=height
  local s=model.session(player.index)
  if s and s.narrow~=(width<640) then s.narrow=width<640; s.redraw=true; s.drawn=nil end
  f.identity.api_name.style.width=width-220
  f.details.style.width=width-24; f.details.style.height=height-220
  for _,e in pairs(f.details.children) do
    if e.type=='text-box' then e.style.width=width-48 end
  end
  f.force_auto_center()
end
function M.open(player,id)
  local ok,s=pcall(model.open,player,id); if not ok then return end
  local old=frame(player); if old and old.valid then old.destroy() end
  local rec=registry.record(id)
  local f=player.gui.screen.add{type='frame',name=M.frame_name,direction='vertical',
    tags={player=player.index,token=s.token,ui_version=model.version}}
  local title=f.add{type='flow',name='heading',direction='horizontal'}
  title.add{type='label',caption=rec.body.localised_name}
  local drag=title.add{type='empty-widget',style='draggable_space_header'}
  drag.style.horizontally_stretchable=true; drag.drag_target=f
  title.add{type='button',name='dismiss',caption=tr('close')}
  local identity=f.add{type='flow',name='identity',direction='horizontal'}
  text(identity,'api_name',rec.kind=='monitor' and '' or rec.id).style.height=40
  identity.api_name.tooltip=tr('copy-help')
  identity.add{type='button',name='select_name',caption=tr('select-name'),tooltip=tr('copy-help')}
  identity.select_name.enabled=rec.kind~='monitor'
  local types={kv='kv_database',logic='logic_handler',monitor='monitor',configurator='configurator',recipe_searcher='recipe_searcher',factoriopedia_interface='factoriopedia_interface',production_statistics='production_statistics'}
  label(f,tr('peripheral-type',types[rec.kind]))
  local powered=lifecycle.available(rec)
  f.add{type='label',name='availability',caption=tr(not powered and 'physical-unavailable' or (rec.kind=='recipe_searcher' or rec.kind=='factoriopedia_interface' or rec.kind=='production_statistics') and 'available' or 'pending')}

  f.add{type='scroll-pane',name='details',horizontal_scroll_policy='auto',vertical_scroll_policy='auto'}
  -- Structure and identity never wait for expensive data-query admission.
  -- Pending content is not a fabricated empty snapshot.
  player.opened=f; M.resize(player)
  draw_pending(f,s,rec,powered)
  return f
end
local function button(parent,name,caption) return parent.add{type='button',name=name,caption=caption} end
local function page(parent,name,current,total)
  local flow=parent.add{type='flow',name=name,direction='horizontal'}
  button(flow,'previous',tr('previous')).enabled=current>1
  label(flow,tr('page',current,math.max(1,total)),'page_label')
  button(flow,'next_page',tr('next')).enabled=current<total
end
local function find(entries,key,field)
  for i,e in ipairs(entries) do if e[field]==key then return e,i end end
end
-- Preparation is paid before native GUI mutation. Complete values are chunked
-- by original bytes, never silently shortened; list previews are not details.
local function prepare(s,spend)
  local snapshot=s.snapshot; local d=snapshot.details
  local view={signature='',kind=snapshot.kind}
  if not d then view.message=snapshot.powered and tr('identity-only') or tr('physical-unavailable'); return view end
  if snapshot.kind=='kv' then
    local entries=d.entries; view.keys={}; local pages=math.max(1,math.ceil(#entries/8))
    s.page=math.min(s.page,pages); view.pages=pages
    for i=(s.page-1)*8+1,math.min(s.page*8,#entries) do
      local e=entries[i]
      view.keys[#view.keys+1]={index=i,identity=model.escape(e.key,spend),caption=e.type..'  '..model.escape(e.key:sub(1,32),spend)..(#e.key>32 and '…' or '')}
    end
    local entry=s.key~=nil and find(entries,s.key,'key') or nil
    if not entry and s.key==nil and #entries>0 then entry=entries[1]; s.key=entry.key end
    view.entry=entry
    if entry then
      view.key=model.escape(entry.key,spend)
      local value=entry.value
      if entry.type=='hash' then
        local fields=entry.fields; view.fields={}; local n=math.max(1,math.ceil(#fields/8))
        s.field_page=math.min(s.field_page,n); view.field_pages=n
        for i=(s.field_page-1)*8+1,math.min(s.field_page*8,#fields) do
          local e=fields[i]; view.fields[#view.fields+1]={index=i,identity=model.escape(e.field,spend),caption=model.escape(e.field:sub(1,32),spend)..(#e.field>32 and '…' or '')}
        end
        local selected=s.field~=nil and find(fields,s.field,'field') or nil
        if not selected and s.field==nil then selected=fields[1]; s.field=selected and selected.field end
        if selected then view.field=model.escape(selected.field,spend); value=selected.value end
      end
      if value~=nil then
        view.value_pages=math.max(1,math.ceil(#value/512)); s.value_page=math.min(s.value_page,view.value_pages)
        view.value=model.escape(value:sub((s.value_page-1)*512+1,s.value_page*512),spend)
      end
    end
    local parts={tostring(s.page),tostring(s.field_page),tostring(s.value_page),view.key or '',view.field or '',view.value or '',tostring(view.pages),tostring(view.field_pages),tostring(view.value_pages)}
    for _,e in ipairs(view.keys) do parts[#parts+1]=e.identity; parts[#parts+1]=e.caption end
    for _,e in ipairs(view.fields or {}) do parts[#parts+1]=e.identity; parts[#parts+1]=e.caption end
    view.signature=table.concat(parts,'\0')
  elseif snapshot.kind=='configurator' then
    view.groups={}; view.pages=math.max(1,math.ceil(#d.groups/8)); s.page=math.min(s.page,view.pages)
    local parts={tostring(s.page),tostring(view.pages)}
    for i=(s.page-1)*8+1,math.min(s.page*8,#d.groups) do
      local g=d.groups[i]; view.groups[#view.groups+1]=g
      spend(#g.prototype+16); parts[#parts+1]=g.prototype..'/'..g.total..'/'..g.red..'/'..g.green
    end
    view.signature=table.concat(parts,'\0')
  elseif snapshot.kind=='monitor' then
    view.geometry=d; view.signature=d.name..'/'..d.width_tiles..'/'..d.height_tiles..'/'..d.tiles..'/'..d.columns..'/'..d.rows..'/'..d.scale
  elseif snapshot.kind=='logic' then
    view.signals=d; local parts={}
    for _,wire in ipairs({'red','green','output'}) do
      parts[#parts+1]=wire..tostring(d.connected[wire])..'/'..tostring(d.errors and d.errors[wire])..'/'..tostring(d[wire]~=nil)
      for _,e in ipairs(d[wire] or {}) do
        parts[#parts+1]=(e.signal.type or 'item')..'/'..(e.signal.name or '')..'/'..(e.signal.quality or 'normal')..'/'..e.count
      end
    end
    view.signature=table.concat(parts,'\0')
  end
  view.signature=view.kind..'\0'..tostring(s.narrow)..'\0'..view.signature
  return view
end
local function slots(parent,wire,entries,connected,tick,err)
  local tray=parent[wire..'_slots']
  if not tray then
    label(parent,tr(wire))
    label(parent,'',wire..'_status').style.maximal_width=260
    tray=parent.add{type='scroll-pane',name=wire..'_slots',style='deep_scroll_pane',
      horizontal_scroll_policy='never',vertical_scroll_policy='auto'}
    tray.add{type='table',name='signal_grid',column_count=6,style='slot_table'}
  end
  local status=parent[wire..'_status']
  status.visible=err~=nil or not entries or #entries==0
  status.caption=err and tr('signal-unavailable',err) or tr(not entries and 'pending' or connected==false and 'disconnected' or 'no-signals')
  tray.style.width=260; tray.style.height=math.max(40,math.min(148,math.ceil(#(entries or {})/6)*36+4))
  local grid=tray.signal_grid
  for i,e in ipairs(entries or {}) do
    local signal=e.signal
    local kind,quality=signal.type or 'item',signal.quality or 'normal'
    local namespace=kind=='virtual' and 'virtual-signal' or kind
    local name='signal_'..i; local slot=grid[name]; local sprite=namespace..'/'..(signal.name or '')
    local identity=sprite..'/'..quality
    if not helpers.is_valid_sprite_path(sprite) then sprite='utility/questionmark' end
    if slot and slot.tags.identity~=identity then slot.destroy(); slot=nil end
    if not slot then slot=grid.add{type='sprite-button',name=name,sprite=sprite,
      number=e.count,quality=quality,style=wire=='output' and 'compact_slot' or wire..'_circuit_network_content_slot',
      tags={identity=identity}} end
    slot.number=e.count
    slot.tooltip={ '',tr(wire),'\n',kind,'/',signal.name or '', '\n',quality,'\n',tostring(e.count)}
    if slot.get_index_in_parent()~=i then grid.swap_children(slot.get_index_in_parent(),i) end
    -- Enabled only for native tooltips/backplates. The click router exposes no
    -- action for these ordinary sprite buttons; they are never signal pickers.
  end
  local children=grid.children
  for i=#children,#(entries or {})+1,-1 do children[i].destroy() end
end
draw_logic=function(p,s,d)
  p.tooltip=tr('logic-help')
  local both=p.logic_regions
  if both and both.direction~=(s.narrow and 'vertical' or 'horizontal') then both.destroy(); both=nil end
  if not both then
    p.clear(); both=p.add{type='flow',name='logic_regions',direction=s.narrow and 'vertical' or 'horizontal'}
    local input=both.add{type='flow',name='inputs',direction='vertical'}
    input.style.minimal_width=280; label(input,tr('inputs'))
    local output=both.add{type='flow',name='outputs',direction='vertical'}
    output.style.minimal_width=280; label(output,tr('outputs'))
  end
  local input=both.inputs
  slots(input,'red',d.red,d.connected.red,d.red_tick,d.errors and d.errors.red)
  slots(input,'green',d.green,d.connected.green,d.green_tick,d.errors and d.errors.green)
  slots(both.outputs,'output',d.output,true,d.output_tick)
end
draw_pending=function(f,s,rec,powered)
  local p=f.details; p.clear(); s.drawn=nil
  if rec.kind=='logic' then draw_logic(p,s,{connected={},errors={}}); return end
  local reason=tr(not powered and rec.kind~='monitor' and 'physical-unavailable' or 'pending')
  if rec.kind=='recipe_searcher' or rec.kind=='factoriopedia_interface' or rec.kind=='production_statistics' then reason=tr('identity-only')
  elseif rec.kind=='kv' then label(p,tr('keys')); p.tooltip=tr('kv-help')
  elseif rec.kind=='configurator' then
    p.tooltip=tr('targets-help')
    local grid=p.add{type='table',column_count=5}
    for _,key in ipairs({'prototype','unique','red','green','entity-type'}) do label(grid,tr(key)) end
  elseif rec.kind=='monitor' then
    p.tooltip=tr('monitor-help')
    label(p,tr('tiles','—','—','—')); label(p,tr('terminal','—','—')); label(p,tr('scale','—'))
  end
  p.add{type='label',name='pending_content',caption=reason}
end
local function set_text(e,value) if e.text~=value then e.text=value end end
local function update_page(p,current,total)
  p.previous.enabled=current>1; p.next_page.enabled=current<total
  p.page_label.caption=tr('page',current,math.max(1,total))
end
local function update_rows(p,prefix,entries)
  local keep={}
  for position,entry in ipairs(entries) do
    local name=prefix..entry.index; local row=p[name]
    if row and row.tags.identity~=entry.identity then row.destroy(); row=nil end
    if not row then row=button(p,name,entry.caption); row.tags={identity=entry.identity} end
    row.caption=entry.caption; keep[name]=true
    if row.get_index_in_parent()~=position then p.swap_children(row.get_index_in_parent(),position) end
  end
  local children=p.children
  for i=#children,1,-1 do if not keep[children[i].name] then children[i].destroy() end end
end
local function draw_kv(p,s,view)
  -- Keep the native value/key widgets mounted across polling and type changes.
  -- Only rows whose exact identity disappeared are retired; unchanged text is
  -- never reassigned, preserving selection, focus and each native scroll bar.
  if not p.key_rows then
    p.clear(); p.tooltip=tr('kv-help'); label(p,tr('keys'))
    p.add{type='flow',name='key_rows',direction='vertical'}
    page(p,'keys_page',1,1)
    label(p,'','selection_status')
    label(p,tr('key'),'key_label'); text(p,'full_key','').style.height=60
    p.add{type='flow',name='field_rows',direction='vertical'}
    page(p,'fields_page',1,1)
    label(p,tr('field'),'field_label'); text(p,'full_field','').style.height=60
    label(p,tr('value'),'value_label'); text(p,'full_value','').style.height=180
    page(p,'value_chunks',1,1)
  end
  update_rows(p.key_rows,'key_',view.keys); update_page(p.keys_page,s.page,view.pages)
  update_rows(p.field_rows,'field_',view.fields or {})
  update_page(p.fields_page,s.field_page,view.field_pages or 1)
  update_page(p.value_chunks,s.value_page,view.value_pages or 1)
  p.selection_status.caption=tr(s.key~=nil and 'selection-gone' or 'empty')
  p.selection_status.visible=not view.entry or (view.fields~=nil and view.field==nil)
  for _,name in ipairs({'key_label','full_key'}) do p[name].visible=view.entry~=nil end
  for _,name in ipairs({'field_rows','fields_page'}) do p[name].visible=view.fields~=nil end
  for _,name in ipairs({'field_label','full_field'}) do p[name].visible=view.field~=nil end
  for _,name in ipairs({'value_label','full_value','value_chunks'}) do p[name].visible=view.value~=nil end
  set_text(p.full_key,view.key or ''); set_text(p.full_field,view.field or ''); set_text(p.full_value,view.value or '')
end
local function draw(f,s,view)
  if s.drawn==view.signature then return end
  if view.kind=='kv' and not view.message then
    draw_kv(f.details,s,view); s.drawn=view.signature; return
  end
  if view.kind=='logic' and not view.message then
    draw_logic(f.details,s,view.signals); s.drawn=view.signature; return
  end
  if view.kind=='configurator' and not view.message then
    local p=f.details
    if not p.groups then
      p.clear(); p.tooltip=tr('targets-help'); label(p,tr('empty'),'empty_groups')
      local grid=p.add{type='table',name='groups',column_count=5}
      grid.style.horizontal_spacing=16; grid.style.vertical_spacing=12
      for _,key in ipairs({'prototype','unique','red','green','entity-type'}) do label(grid,tr(key)) end
      page(p,'groups_page',1,1)
    end
    local grid=p.groups
    p.empty_groups.visible=#view.groups==0
    for i,g in ipairs(view.groups) do
      local name='group_'..i; local row=grid[name]
      if row and row.tags.prototype~=g.prototype then row.destroy(); row=nil end
      if not row then
        row=grid.add{type='flow',name=name,direction='vertical',tags={prototype=g.prototype}}
        row.add{type='sprite',sprite='entity/'..g.prototype}
        label(row,prototypes.entity[g.prototype].localised_name); label(row,g.prototype)
      end
      for column,key in ipairs({'total','red','green','type'}) do
        local cell=name..'_'..key
        if not grid[cell] then label(grid,'',cell) end
        grid[cell].caption=key=='type' and prototypes.entity[g.prototype].type or tostring(g[key])
        local target=5+(i-1)*5+column+1
        if grid[cell].get_index_in_parent()~=target then grid.swap_children(grid[cell].get_index_in_parent(),target) end
      end
      local target=6+(i-1)*5
      if row.get_index_in_parent()~=target then grid.swap_children(row.get_index_in_parent(),target) end
    end
    local children=grid.children
    for i=#children,6+#view.groups*5,-1 do children[i].destroy() end
    update_page(p.groups_page,s.page,view.pages); s.drawn=view.signature; return
  end
  local p=f.details; p.clear()
  if view.message then label(p,view.message)
  elseif view.kind=='monitor' then
    local g=view.geometry
    label(p,tr('tiles',g.width_tiles,g.height_tiles,g.tiles))
    label(p,tr('terminal',g.columns,g.rows)); label(p,tr('scale',g.scale))
    p.tooltip=tr('monitor-help')

  end
  s.drawn=view.signature
end
function M.on_click(event)
  local player,f,s,rec=owned(event); if not player then return end
  local e=event.element
  if e==f.heading.dismiss then M.close(player); return end
  if e==f.identity.select_name then
    -- Re-resolve monitor identity at the action boundary: a pending regroup may
    -- invalidate the previously selected logical name between refresh samples.
    if rec.kind=='monitor' then
      local ok,g=pcall(monitor.resolve,rec)
      if not ok or not g or f.identity.api_name.text~=g.id then s.pending=true; f.identity.api_name.text=''; return end
    end
    f.identity.api_name.focus(); f.identity.api_name.select_all(); return
  end

  -- A candidate may be admitted before its GUI construction fits the ledger.
  -- Old row indices must not select data from that not-yet-presented snapshot.
  if s.redraw then return end
  local groups=f.details.groups_page
  if rec.kind=='configurator' and groups and (e==groups.previous or e==groups.next_page) and e.enabled then
    s.page=math.max(1,s.page+(e==groups.previous and -1 or 1)); s.redraw=true; return
  end
  local d=s.snapshot and s.snapshot.details
  if not d or rec.kind~='kv' then return end
  local i=tonumber(e.name:match('^key_(%d+)$'))
  if i and f.details.key_rows and e==f.details.key_rows[e.name] and d.entries[i] then
    s.key=d.entries[i].key; s.field=nil; s.field_page=1; s.value_page=1; s.redraw=true; return
  end
  local entry=s.key~=nil and find(d.entries,s.key,'key') or nil
  i=tonumber(e.name:match('^field_(%d+)$'))
  if i and entry and entry.fields and entry.fields[i] and f.details.field_rows and e==f.details.field_rows[e.name] then
    s.field=entry.fields[i].field; s.value_page=1; s.redraw=true; return
  end
  local keys={keys_page='page',fields_page='field_page',value_chunks='value_page'}
  for parent,key in pairs(keys) do
    local flow=f.details[parent]
    if flow and (e==flow.previous or e==flow.next_page) and e.enabled then
      s[key]=math.max(1,s[key]+(e==flow.previous and -1 or 1)); s.redraw=true; return
    end
  end
end
function M.on_closed(event)
  local player,f=owned(event,true)
  if player and event.element==f then M.close(player) end
end
function M.on_player_unavailable(event)
  local player=game.get_player(event.player_index)
  if player and player.valid then M.close(player) else model.close(event.player_index) end
end
function M.on_size(event) M.resize(game.get_player(event.player_index)) end
function M.tick(tick)
  if tick%15~=0 then return end
  local root=registry.get(); if not registry.supported(root) then return end
  local spend=scheduler.maintenance(root,tick)
  local viewers=game.connected_players; local n=#viewers
  if n==0 then return end
  local start=(root.peripheral_inspector_cursor or 0)%n
  root.peripheral_inspector_cursor=(start+1)%n
  for offset=1,n do
    local player=viewers[(start+offset-1)%n+1]
    local s=model.session(player.index); local f=frame(player)
    if s then
      if not f or not f.valid or f.visible==false or f.enabled==false or player.opened~=f or f.tags.token~=s.token or f.tags.ui_version~=model.version then M.close(player)
      else
        scheduler.try_maintenance(function()
          spend(128)
          local ok,rec=pcall(model.current,player,s.token)
          if not ok then M.close(player); return end
          local powered=lifecycle.available(rec)
          if s.snapshot and powered~=s.snapshot.powered then
            s.snapshot=nil; s.logic_partial=nil; s.pending=true
            draw_pending(f,s,rec,powered)
          end
          if not s.redraw or not s.snapshot then
            s.pending=true; f.availability.caption=tr(not powered and 'physical-unavailable' or s.snapshot and 'pending-stale' or 'pending')
            local candidate,admitted
            local success,err=pcall(function()
              admitted=scheduler.try_maintenance(function() candidate=model.read(rec,tick,spend,s) end)
            end)
            if not success then
              spend(128); f.availability.caption=tr('unavailable',type(err)=='table' and err.code or 'E_ENGINE')
              if f.details.pending_content then f.details.pending_content.caption=f.availability.caption end
              -- Retain the last detached view as explicitly stale. Monitor
              -- identity may have changed, so it is not copyable until resolved.
              if rec.kind=='monitor' then f.identity.api_name.text=''; f.identity.select_name.enabled=false end
              return
            end
            if not admitted or not candidate then return end -- Credits remain spent; candidate stays private.
            s.identity_changed=s.snapshot and s.snapshot.name~=candidate.name or false
            s.snapshot=candidate; s.pending=false; s.redraw=true
          end
          if s.redraw and s.snapshot then
            local view=prepare(s,spend)
            -- Bound native construction including worst-case slot rows and KV
            -- chunks; no partial query is published as a complete inventory.
            spend(12000+(view.groups and #view.groups*160 or 0))
            draw(f,s,view); s.redraw=false

            if f.identity.api_name.text~=s.snapshot.name then f.identity.api_name.text=s.snapshot.name end
            f.identity.select_name.enabled=true
            f.availability.caption=tr(not s.snapshot.powered and 'physical-unavailable' or s.identity_changed and 'identity-changed' or 'available')
            if view.kind=='logic' and view.signals and (not view.signals.red_tick or not view.signals.green_tick
              or next(view.signals.errors or {})) then f.availability.caption=tr('signals-pending') end

            local width=math.max(300,math.min(720,math.floor(player.display_resolution.width/player.display_scale)-32))
            for _,e in pairs(f.details.children) do if e.type=='text-box' then e.style.width=width-48 end end
          end
        end)
      end
    elseif f and f.valid then f.destroy() end
  end
end
scheduler.register_phase('render','ui-peripheral-inspectors',M.tick)
return M
