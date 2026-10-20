-- Native, player-scoped read-only inspectors. The scheduler owns all polling.
local registry=require('scripts.registry')
local scheduler=require('scripts.scheduler')
local model=require('scripts.ui.peripheral-inspector-model')
local lifecycle=require('scripts.lifecycle')
local monitor=require('scripts.services.monitor')
local M={frame_name='tc_peripheral_inspector'}
M.supports=model.supports
local function tr(key,...) return {'tc-inspector.'..key,...} end
local function frame(player) return player.gui.screen[M.frame_name] end
local function text(parent,name,value)
  local e=parent.add{type='text-box',name=name,text=value or ''}
  e.read_only=true; e.word_wrap=true; e.style.rich_text_setting=defines.rich_text_setting.disabled; return e
end
local function label(parent,caption)
  local e=parent.add{type='label',caption=caption}; e.style.single_line=false
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
  while e and e~=f do e=e.parent end
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
  identity.add{type='button',name='select_name',caption=tr('select-name')}
  label(f,tr('copy-help'))
  local types={kv='kv_database',logic='logic_handler',monitor='monitor',configurator='configurator',recipe_searcher='recipe_searcher'}
  label(f,tr('peripheral-type',types[rec.kind]))
  f.add{type='label',name='availability',caption=tr('pending')}
  local actions=f.add{type='flow',name='actions',direction='horizontal'}
  actions.add{type='label',name='sample_tick',caption=tr('pending')}
  actions.add{type='button',name='refresh_snapshot',caption=tr('refresh')}
  f.add{type='scroll-pane',name='details',horizontal_scroll_policy='auto',vertical_scroll_policy='auto'}
  -- No device controls are constructed until an admitted detached view exists.
  player.opened=f; M.resize(player)
  return f
end
local function button(parent,name,caption) return parent.add{type='button',name=name,caption=caption} end
local function page(parent,name,current,total)
  local flow=parent.add{type='flow',name=name,direction='horizontal'}
  button(flow,'previous',tr('previous')).enabled=current>1
  label(flow,tr('page',current,math.max(1,total)))
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
  if not d then view.message=snapshot.powered and tr('identity-only') or tr('unpowered'); return view end
  if snapshot.kind=='kv' then
    local entries=d.entries; view.keys={}; local pages=math.max(1,math.ceil(#entries/8))
    s.page=math.min(s.page,pages); view.pages=pages
    for i=(s.page-1)*8+1,math.min(s.page*8,#entries) do
      local e=entries[i]
      view.keys[#view.keys+1]={index=i,caption=e.type..'  '..model.escape(e.key:sub(1,32),spend)..(#e.key>32 and '…' or '')}
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
          local e=fields[i]; view.fields[#view.fields+1]={index=i,caption=model.escape(e.field:sub(1,32),spend)..(#e.field>32 and '…' or '')}
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
    for _,e in ipairs(view.keys) do parts[#parts+1]=e.caption end
    for _,e in ipairs(view.fields or {}) do parts[#parts+1]=e.caption end
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
      parts[#parts+1]=wire..tostring(d.connected[wire])
      for _,e in ipairs(d[wire]) do
        spend(#e.signal.name+#e.signal.quality+32)
        parts[#parts+1]=e.signal.type..'/'..e.signal.name..'/'..e.signal.quality..'/'..e.count
      end
    end
    view.signature=table.concat(parts,'\0')
  end
  view.signature=view.kind..'\0'..tostring(s.narrow)..'\0'..view.signature
  return view
end
local function slots(parent,wire,entries,connected,tick)
  label(parent,tr(wire))
  if tick then parent.add{type='label',name=wire..'_tick',caption=tr('snapshot',tick)} end
  if #entries==0 then label(parent,tr(connected==false and 'disconnected' or 'empty')); return end
  local grid=parent.add{type='table',column_count=6}
  for i,e in ipairs(entries) do
    local signal=e.signal
    local namespace=signal.type=='virtual' and 'virtual-signal' or signal.type
    grid.add{type='sprite-button',name='signal_'..i,sprite=namespace..'/'..signal.name,
      number=e.count,quality=signal.quality,style=wire=='output' and 'compact_slot' or wire..'_circuit_network_content_slot',
      tooltip={ '',tr(wire),'\n',signal.type,'/',signal.name,'\n',signal.quality,'\n',tostring(e.count)}}
    -- Enabled only for native tooltips/backplates. The click router exposes no
    -- action for these ordinary sprite buttons; they are never signal pickers.
  end
end
local function draw(f,s,view)
  if s.drawn==view.signature then return end
  local p=f.details; p.clear()
  if view.message then label(p,view.message)
  elseif view.kind=='kv' then
    label(p,tr('kv-help'))
    local list=p.add{type='flow',name='key_rows',direction='vertical'}
    for _,e in ipairs(view.keys) do button(list,'key_'..e.index,e.caption) end
    page(p,'keys_page',s.page,view.pages)
    if not view.entry then label(p,tr(s.key~=nil and 'selection-gone' or 'empty'))
    else
      label(p,tr('key')); text(p,'full_key',view.key).style.height=60
      if view.fields then
        local fields=p.add{type='flow',name='field_rows',direction='vertical'}
        for _,e in ipairs(view.fields) do button(fields,'field_'..e.index,e.caption) end
        page(p,'fields_page',s.field_page,view.field_pages)
        if view.field then label(p,tr('field')); text(p,'full_field',view.field).style.height=60 end
      end
      if view.value then
        label(p,tr('value')); text(p,'full_value',view.value).style.height=180
        page(p,'value_chunks',s.value_page,view.value_pages)
      else label(p,tr('selection-gone')) end
    end
  elseif view.kind=='configurator' then
    label(p,tr('targets-help'))
    if #view.groups==0 then label(p,tr('empty')) end
    local grid=p.add{type='table',column_count=5}
    grid.style.horizontal_spacing=16; grid.style.vertical_spacing=12
    for _,key in ipairs({'prototype','unique','red','green','entity-type'}) do label(grid,tr(key)) end
    for _,g in ipairs(view.groups) do
      local proto=prototypes.entity[g.prototype]
      local row=grid.add{type='flow',direction='vertical'}
      row.add{type='sprite',sprite='entity/'..g.prototype}
      label(row,proto.localised_name); label(row,g.prototype)
      label(grid,tostring(g.total)); label(grid,tostring(g.red)); label(grid,tostring(g.green)); label(grid,proto.type)
    end
    page(p,'groups_page',s.page,view.pages)
  elseif view.kind=='monitor' then
    local g=view.geometry
    label(p,tr('tiles',g.width_tiles,g.height_tiles,g.tiles))
    label(p,tr('terminal',g.columns,g.rows)); label(p,tr('scale',g.scale))
    label(p,tr('monitor-help'))
  elseif view.kind=='logic' then
    label(p,tr('logic-help'))
    local both=p.add{type='flow',name='logic_regions',direction=s.narrow and 'vertical' or 'horizontal'}
    local input=both.add{type='frame',name='inputs',direction='vertical',caption=tr('inputs')}
    input.style.minimal_width=280
    slots(input,'red',view.signals.red,view.signals.connected.red,view.signals.red_tick)
    slots(input,'green',view.signals.green,view.signals.connected.green,view.signals.green_tick)
    local output=both.add{type='frame',name='outputs',direction='vertical',caption=tr('outputs')}
    output.style.minimal_width=280
    slots(output,'output',view.signals.output,true,view.signals.output_tick)
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
  if e==f.actions.refresh_snapshot then s.pending=true; return end
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
      if not f or not f.valid or player.opened~=f or f.tags.token~=s.token or f.tags.ui_version~=model.version then M.close(player)
      else
        scheduler.try_maintenance(function()
          spend(128)
          local ok,rec=pcall(model.current,player,s.token)
          if not ok then M.close(player); return end
          local powered=lifecycle.has_power(rec)
          if s.snapshot and powered~=s.snapshot.powered then
            s.snapshot=nil; s.logic_partial=nil; s.drawn=nil; f.details.clear(); s.pending=true
          end
          if (s.pending or rec.kind=='logic' or rec.kind=='monitor') and (not s.redraw or not s.snapshot) then
            s.pending=true; f.availability.caption=tr('pending-stale')
            local candidate,admitted
            local success,err=pcall(function()
              admitted=scheduler.try_maintenance(function() candidate=model.read(rec,tick,spend,s) end)
            end)
            if not success then
              spend(128); f.availability.caption=tr('unavailable',type(err)=='table' and err.code or 'E_ENGINE')
              if rec.kind=='monitor' then f.identity.api_name.text=''; f.identity.select_name.enabled=false; f.details.clear(); s.drawn=nil end
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
            if view.kind=='logic' and view.signals then
              -- Tick-only changes must not rebuild slots, reset scroll or steal
              -- selection. Each color is explicitly an independent observation.
              local regions=f.details.logic_regions
              regions.inputs.red_tick.caption=tr('snapshot',view.signals.red_tick)
              regions.inputs.green_tick.caption=tr('snapshot',view.signals.green_tick)
              regions.outputs.output_tick.caption=tr('snapshot',view.signals.output_tick)
            end
            if f.identity.api_name.text~=s.snapshot.name then f.identity.api_name.text=s.snapshot.name end
            f.identity.select_name.enabled=true
            f.availability.caption=tr(not s.snapshot.powered and 'unpowered' or s.identity_changed and 'identity-changed' or 'available')
            f.actions.sample_tick.caption=tr('snapshot',s.snapshot.tick)
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
