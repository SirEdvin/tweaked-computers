-- Persistent host render-object handles; model bytes never become rich text.
local registry=require('scripts.registry')
local scheduler=require('scripts.scheduler')
local model=require('scripts.monitor-model')
local buffered=require('scripts.monitor-presentation')
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
    tint=tint,render_layer=layer,visible=false}
end
local function clear_cell(c) if c then destroy(c.background); destroy(c.glyph) end end
M.retire=buffered.retire

local function render_cell(g,r,i)
  local m=g.model; local value=m.cells[i]; local c=r.front and r.front.cells[i]
  local pfg,pbg=m.palette[value[2]+1],m.palette[value[3]+1]
  local old=c and c.value
  local matches=old and old[1]==value[1] and old[2]==value[2] and old[3]==value[3]
    and c.fg[1]==pfg[1] and c.fg[2]==pfg[2] and c.fg[3]==pfg[3]
    and c.bg[1]==pbg[1] and c.bg[2]==pbg[2] and c.bg[3]==pbg[3]
    and c.background.valid and (value[1]==32 or c.glyph and c.glyph.valid)
  if matches then r.cells[i]=c; r.reused[i]=true; return end
  local cw,ch,ox,oy=model.geometry(g); local x=(i-1)%m.width; local y=math.floor((i-1)/m.width)
  local background=fill(g,ox+x*cw,oy+y*ch,cw,ch,color(pbg),layers.background); local glyph
  if value[1]~=32 then
    local wx,wy=model.world(g,ox+(x+0.5)*cw,oy+(y+0.5)*ch)
    glyph=rendering.draw_sprite{surface=g.surface_index,sprite='tc-glyph-'..value[1],target={wx,wy},
      x_scale=m.scale/2,y_scale=m.scale/2,orientation=g.direction/16,tint=color(pfg),render_layer=layers.glyph,visible=false}
  end
  r.cells[i]={background=background,glyph=glyph,value={value[1],value[2],value[3]},
    fg={pfg[1],pfg[2],pfg[3]},bg={pbg[1],pbg[2],pbg[3]}}
end
local function cursor(g,r)
  local m=g.model
  local previous=r.front and r.front.snapshot
  if previous and previous.x==m.x and previous.y==m.y and previous.blink==m.blink and previous.fg==m.fg then
    local a,b=previous.palette[previous.fg+1],m.palette[m.fg+1]
    if a[1]==b[1] and a[2]==b[2] and a[3]==b[3] and (not r.front.cursor or r.front.cursor.valid) then
      r.cursor=r.front.cursor; r.shared_cursor=true; r.cursor_revision=m.revision; return
    end
  end
  destroy(r.cursor); r.cursor=nil
  if m.blink and m.x>=1 and m.x<=m.width and m.y>=1 and m.y<=m.height then
    local cw,ch,ox,oy=model.geometry(g)
    r.cursor=fill(g,ox+(m.x-1)*cw,oy+m.y*ch-m.scale/64,cw,m.scale/64,color(m.palette[m.fg+1]),layers.cursor)
    r.cursor.blink_interval=30
  end
  r.cursor_revision=m.revision
end
buffered.install{clear_cell=clear_cell,destroy=destroy,cell=render_cell,cursor=cursor,
  frame=function(c,front)
    local m=c.model
    return {version=1,layer_version=3,context=c,snapshot=m,slots=m.width*m.height,
      cells={},reused={},width=m.width,height=m.height,scale=m.scale,front=front,
      shared_panel=front~=nil,panel=front and front.panel or fill(c,2/64,2/64,
        c.width_tiles-4/64,c.height_tiles-4/64,{0,0,0,1},layers.panel)}
  end}
M.tick=buffered.tick
M.bind=buffered.bind
M.participate=buffered.participate
M.matches=buffered.matches
M.select=buffered.select
M.status=buffered.status
M.release=buffered.release
M.changed=buffered.changed
M.regroup=buffered.regroup
scheduler.register_phase('render','monitor-world',M.tick)
return M
