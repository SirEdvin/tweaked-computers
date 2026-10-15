-- Persistent host render-object handles; model bytes never become rich text.
local registry=require('scripts.registry')
local scheduler=require('scripts.scheduler')
local model=require('scripts.monitor-model')
local M={}
-- 2.0.77: body=object (124), wires=131, entity-info-icon=153,
-- selection-box=187. Separate content strata prevent later dirty backgrounds
-- covering unchanged glyphs; every stratum stays below native world feedback.
local layers={panel='higher-object-under',background='higher-object-above',
  glyph='train-stop-top',cursor='item-in-inserter-hand'}
scheduler.reserve_render_work(60000)
local function color(p) return {r=p[1],g=p[2],b=p[3],a=1} end
local function destroy(o) if o and o.valid then o.destroy() end end
local function box(g,u,v,w,h)
  local ax,ay=model.world(g,u,v); local bx,by=model.world(g,u+w,v+h)
  return {math.min(ax,bx),math.min(ay,by)},{math.max(ax,bx),math.max(ay,by)}
end
local function fill(g,u,v,w,h,tint,layer)
  local a,b=box(g,u,v,w,h)
  return rendering.draw_sprite{surface=g.surface_index,sprite='tc-monitor-fill',
    target={(a[1]+b[1])/2,(a[2]+b[2])/2},x_scale=(b[1]-a[1])*32,y_scale=(b[2]-a[2])*32,
    tint=tint,render_layer=layer}
end
local function clear_cell(c) if c then destroy(c.background); destroy(c.glyph) end end
function M.retire(state,r)
  if not r then return end
  state.retired=state.retired or {}; state.retired[#state.retired+1]=r
end
local function cleanup(state,spend,remaining)
  while state.retired and #state.retired>0 and remaining>0 do
    local r=state.retired[1]; local i=r.cleanup_cursor or 1
    while i<=#r.cells and remaining>0 do
      spend(8); clear_cell(r.cells[i]); r.cells[i]=false
      i=i+1; r.cleanup_cursor=i; remaining=remaining-1
    end
    if i>#r.cells then spend(8); destroy(r.panel); destroy(r.cursor); table.remove(state.retired,1) else break end
  end
  return remaining
end
local function render_cell(g,r,i)
  local m=g.model; local value=m.cells[i]; local c=r.cells[i]
  local pfg,pbg=m.palette[value[2]+1],m.palette[value[3]+1]
  local old=c and c.value
  local matches=old and old[1]==value[1] and old[2]==value[2] and old[3]==value[3]
    and c.fg[1]==pfg[1] and c.fg[2]==pfg[2] and c.fg[3]==pfg[3]
    and c.bg[1]==pbg[1] and c.bg[2]==pbg[2] and c.bg[3]==pbg[3]
    and c.background.valid and (value[1]==32 or c.glyph and c.glyph.valid)
  if matches then return end
  clear_cell(c)
  local cw,ch,ox,oy=model.geometry(g); local x=(i-1)%m.width; local y=math.floor((i-1)/m.width)
  local background=fill(g,ox+x*cw,oy+y*ch,cw,ch,color(pbg),layers.background); local glyph
  if value[1]~=32 then
    local wx,wy=model.world(g,ox+(x+0.5)*cw,oy+(y+0.5)*ch)
    glyph=rendering.draw_sprite{surface=g.surface_index,sprite='tc-glyph-'..value[1],target={wx,wy},
      x_scale=m.scale/2,y_scale=m.scale/2,orientation=g.direction/16,tint=color(pfg),render_layer=layers.glyph}
  end
  r.cells[i]={background=background,glyph=glyph,value={value[1],value[2],value[3]},
    fg={pfg[1],pfg[2],pfg[3]},bg={pbg[1],pbg[2],pbg[3]}}
end
local function cursor(g,r)
  local m=g.model
  destroy(r.cursor); r.cursor=nil
  if m.blink and m.x>=1 and m.x<=m.width and m.y>=1 and m.y<=m.height then
    local cw,ch,ox,oy=model.geometry(g)
    r.cursor=fill(g,ox+(m.x-1)*cw,oy+m.y*ch-m.scale/64,cw,m.scale/64,color(m.palette[m.fg+1]),layers.cursor)
    r.cursor.blink_interval=30
  end
  r.cursor_revision=m.revision
end
function M.tick(tick,spend)
  local state=registry.get().monitors; if not state or state.version~=1 then return end
  local remaining=cleanup(state,spend,model.limits.render_cells_per_tick)
  spend(model.limits.tiles*8+1)
  local ids=state.order
  if #ids==0 then return end
  local start=math.min(state.render_cursor or 1,#ids)
  for offset=0,#ids-1 do
    local index=(start+offset-1)%#ids+1; local g=state.groups[ids[index]]; local m=g.model; local r=g.render
    if not g.powered then
      if r and not r.hidden then
        spend(#r.cells*3+8)
        for _,c in ipairs(r.cells) do if c then
          if c.background.valid then c.background.visible=false end
          if c.glyph and c.glyph.valid then c.glyph.visible=false end
        end end
        if r.cursor and r.cursor.valid then r.cursor.visible=false end
        if r.panel and r.panel.valid then r.panel.visible=false end
        r.hidden=true
      end
    else
      -- Geometry/scale owns all draw objects; stale-size grids are retired once.
      if r and (r.layer_version~=2 or r.width~=m.width or r.height~=m.height or r.scale~=m.scale or not r.panel.valid) then
        spend(4); M.retire(state,r); g.render=nil; r=nil
      end
      if not r then
        spend(16)
        r={layer_version=2,cells={},width=m.width,height=m.height,scale=m.scale,sweep_cursor=1,sweep_revision=m.revision,
          panel=fill(g,2/64,2/64,g.width_tiles-4/64,g.height_tiles-4/64,{0,0,0,1},layers.panel)}
        g.render=r
      end
      if r.hidden then
        spend(#r.cells*3+8)
        for _,c in ipairs(r.cells) do if c then
          if c.background.valid then c.background.visible=true end
          if c.glyph and c.glyph.valid then c.glyph.visible=true end
        end end
        r.panel.visible=true; if r.cursor and r.cursor.valid then r.cursor.visible=true end; r.hidden=nil
      end
      if r.presented_revision~=m.revision then
        if not r.sweep_cursor then r.sweep_cursor=1; r.sweep_revision=m.revision end
        while r.sweep_cursor<=m.width*m.height and remaining>0 do
          spend(48); render_cell(g,r,r.sweep_cursor); r.sweep_cursor=r.sweep_cursor+1; remaining=remaining-1
        end
        if r.sweep_cursor>m.width*m.height then
          if r.sweep_revision==m.revision then r.presented_revision=m.revision; r.sweep_cursor=nil
          else r.sweep_cursor=1; r.sweep_revision=m.revision end
        end
      end
      if r.cursor_revision~=m.revision then spend(16); cursor(g,r) end
    end
    state.render_cursor=index%#ids+1
    if remaining==0 then return end
  end
end
scheduler.register_phase('render','monitor-world',M.tick)
return M
