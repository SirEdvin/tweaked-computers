-- Row-text presenter backend. Guest bytes map to private-use glyphs, so only
-- host-built [color] tags reach the rich-text parser.
local scheduler=require('scripts.scheduler')
local model=require('scripts.monitor-model')
local buffered=require('scripts.monitor-presentation')
local graphics=require('scripts.monitor-graphics')
local M={}
local char,sub,find,gsub,rep,concat=string.char,string.sub,string.find,string.gsub,string.rep,table.concat
-- Sprites draw below every text object, so only the panel stays a sprite.
local PANEL='higher-object-under'
local MAP={} -- Byte to the UTF-8 encoding of U+E000+byte.
for b=0,255 do MAP[char(b)]=char(0xEE,0x80+math.floor(b/64),0x80+b%64) end
local BLOCK,CURSOR=char(0xEE,0x84,0x80),char(0xEE,0x84,0x81) -- Font-only U+E100 and U+E101.
local NOT={} -- Digit to the pattern of any other digit.
for i=0,15 do local d=model.DIGIT[i]; NOT[d]='[^'..d..']' end
scheduler.reserve_render_work(60000)
-- Every monitor-owned native object is counted against render_object_limit (D6).
local function destroy(o) if o and o.valid then o.destroy(); graphics.count(-1) end end
local function clear_cell(c,staged) -- Legacy per-cell fronts and staging only.
  if c then
    if not staged or not c.shared_background then destroy(c.background) end
    if not staged or not c.shared_glyph then destroy(c.glyph) end
  end
end
M.retire=buffered.retire
local function tags(s)
  local t={}
  for i=0,15 do local p=s.palette[i+1]; t[model.DIGIT[i]]=string.format('[color=%.5f,%.5f,%.5f]',p[1],p[2],p[3]) end
  return t
end
-- One string per row: the colour runs of `f` wrap `fill(x,e)` in host tags.
local function runs(f,tag,fill)
  local parts,n,x,w={},0,1,#f
  while x<=w do
    local d=sub(f,x,x); local e=(find(f,NOT[d],x) or w+1)-1
    parts[n+1]=tag[d]; parts[n+2]=fill(x,e); parts[n+3]='[/color]'; n=n+3; x=e+1
  end
  return concat(parts,'',1,n)
end
-- Glyph and background text of one snapshot row; '' means no glyph object.
function M.row_strings(s,y,tag)
  tag=tag or tags(s)
  local t,f,b=table.unpack(s.rows[y])
  local glyph=find(t,'[^ ]') and runs(f,tag,function(x,e) return (gsub(sub(t,x,e),'.',MAP)) end) or ''
  return glyph,runs(b,tag,function(x,e) return rep(BLOCK,e-x+1) end)
end
local function row(c,r,y)
  local glyph,background=M.row_strings(r.snapshot,y,r.tags)
  r.data[#r.data+1]={y,glyph,background}
end
local function cursor(c,r)
  local s=r.snapshot
  r.cursor_key=not r.graphics and s.blink and s.x>=1 and s.x<=s.width and s.y>=1 and s.y<=s.height
    and string.format('%d,%d,%s',s.x,s.y,r.tags[model.DIGIT[s.fg]]) or false
end
local function text(c,y,x,s,visible,rich)
  local cw,ch,ox,oy=model.geometry(c); local wx,wy=model.world(c,ox+(x-1)*cw,oy+(y-1)*ch)
  graphics.count(1)
  return rendering.draw_text{surface=c.surface_index,text=s,font='tc-term',color={1,1,1,1},target={wx,wy},
    scale=0.125*c.model.scale,alignment='left',vertical_alignment='top',orientation=c.direction/16,
    use_rich_text=rich,visible=visible}
end
local function new_front(c,visible)
  local m=c.model
  local a,b={model.world(c,2/64,2/64)},{model.world(c,c.width_tiles-2/64,c.height_tiles-2/64)}
  local l,t,rr,bb=math.min(a[1],b[1]),math.min(a[2],b[2]),math.max(a[1],b[1]),math.max(a[2],b[2])
  graphics.count(1)
  local panel=rendering.draw_sprite{surface=c.surface_index,sprite='tc-monitor-fill',target={(l+rr)/2,(t+bb)/2},
    x_scale=(rr-l)*32,y_scale=(bb-t)*32,tint={0,0,0,1},render_layer=PANEL,visible=visible}
  return {version=1,row_version=1,context=c,snapshot=m,slots=m.width*m.height,width=m.width,height=m.height,
    scale=m.scale,panel=panel,rows={},cursor_key=false}
end
-- Native writes of one prepared frame; the caller prepaid them and proved validity.
local function apply(F,r,visible)
  local c=r.context; local created=false
  if r.graphics then -- A graphics display keeps only its panel; graphics objects live outside the front.
    for y,o in pairs(F.rows) do destroy(o.bg); destroy(o.glyph); F.rows[y]=nil end
  end
  for _,d in ipairs(r.data) do
    local y,glyph,background=d[1],d[2],d[3]
    local o=F.rows[y]; if not o then o={}; F.rows[y]=o end
    if o.b~=background then
      if o.bg then o.bg.text=background else o.bg=text(c,y,1,background,visible,true); created=true end
      o.b=background
    end
    if o.g~=glyph then
      if glyph=='' then destroy(o.glyph); o.glyph=nil
      elseif o.glyph then o.glyph.text=glyph
      else o.glyph=text(c,y,1,glyph,visible,true); created=true end
      o.g=glyph
    end
  end
  if F.cursor_key~=r.cursor_key then
    destroy(F.cursor); F.cursor=nil
    if r.cursor_key then
      local s=r.snapshot; local p=s.palette[s.fg+1]
      F.cursor=text(c,s.y,s.x,CURSOR,visible,false); F.cursor.color={p[1],p[2],p[3],1}; F.cursor.blink_interval=30
    end
    F.cursor_key=r.cursor_key
  elseif created and F.cursor then F.cursor.bring_to_front() end
end
-- Native objects a prepared frame may touch in its target front.
local function valid(F,r)
  if not F.panel.valid or F.cursor and not F.cursor.valid then return false end
  for _,d in ipairs(r.data) do
    local o=F.rows[d[1]]
    if o and (o.bg and not o.bg.valid or o.glyph and not o.glyph.valid) then return false end
  end
  return true
end
buffered.install{clear_cell=clear_cell,destroy=destroy,row=row,cursor=cursor,new_front=new_front,apply=apply,valid=valid,
  frame_cost=function() return 32 end,
  frame=function(c,front)
    local m=c.model
    local r={version=1,row_version=1,context=c,snapshot=m,slots=m.width*m.height,width=m.width,height=m.height,
      scale=m.scale,front=front,data={},tags=tags(m)}
    -- A matching row front takes only the damaged rows; anything else rebuilds all rows.
    if m.mode=='graphics' then r.graphics=true
    elseif front and front.row_version==1 and not m.damage_full and m.damage then r.indices=m.damage end
    return r
  end}
M.tick=buffered.tick
M.bind=buffered.bind
M.participate=buffered.participate
M.matches=buffered.matches
M.supported=buffered.supported
M.select=buffered.select
M.status=buffered.status
M.release=buffered.release
M.changed=buffered.changed
M.regroup=buffered.regroup
M.marked=buffered.marked
M.leave_group=buffered.leave_group
scheduler.register_phase('render','monitor-world',M.tick,function(r)
  local s=r.monitors
  if s==nil then return false end
  if type(s)~='table' or s.version~=1 then return true end
  local p=s.presentation
  if type(p)~='table' or not p.demand_version or p.layout_dirty then return true end
  if type(p.jobs)~='table' or type(p.orphans)~='table' or type(p.retired)~='table'
    or type(p.work)~='table' or type(p.shells)~='table' then return true end
  if next(p.jobs)~=nil or next(p.orphans)~=nil or next(p.retired)~=nil or next(p.work)~=nil or next(p.shells)~=nil then return true end
  -- Run once more to withdraw a previous render demand.
  local demand=r.scheduler.render_demand_work
  return demand~=nil and demand~=0
end)
return M
