-- Plain byte-cell terminal state; no rendering objects or guest references.
local errors=require('scripts.runtime.errors')
local M={limits={width_tiles=6,height_tiles=6,cells=10584,write_bytes=16384,
  render_latency_ticks=256,tiles=256,aggregate_cells=80000,render_cells_per_tick=1024,
  peripheral_call_bytes=65536,peripheral_call_entries=4096,
  sync_group_cells=10584,
  render_snapshot_cells=80000,render_staging_cells=10584,render_retired_cells=10584,
  render_staging_frames=256,render_retired_frames=256,render_commit_objects=42352,
  render_commit_work=160000,render_object_limit=203872,render_retained_cells=362336}}
local MAX=9007199254740991
local palette={0xF0F0F0,0xF2B233,0xE57FD8,0x99B2F2,0xDEDE6C,0x7FCC19,0xF2B2CC,0x4C4C4C,
  0x999999,0x4C99B2,0xB266E5,0x3366CC,0x7F664C,0x57A64E,0xCC4C4C,0x111111}
local function digit(byte)
  if byte>=48 and byte<=57 then return byte-48 end
  if byte>=97 and byte<=102 then return byte-87 end
  return nil
end
local function integer(n)
  if type(n)~='number' then errors.raise('E_ARGUMENT','number required') end
  if not errors.integer(n,-MAX,MAX) then errors.raise('E_RANGE','safe integer required') end; return n
end
local function color(n)
  for i=0,15 do if n==2^i then return i end end
  errors.raise(type(n)=='number' and 'E_RANGE' or 'E_ARGUMENT','one color constant required')
end
local function string_arg(s)
  if type(s)~='string' then errors.raise('E_ARGUMENT','string required') end
  if #s>M.limits.write_bytes then errors.raise('E_LIMIT','monitor write byte limit') end
end
function M.size(w,h,scale)
  if type(scale)~='number' then errors.raise('E_ARGUMENT','numeric scale required') end
  if not errors.finite(scale) or scale<=0 or not errors.finite(9*scale) then
    errors.raise('E_RANGE','positive finite representable scale required')
  end
  local width=math.max(1,math.floor((64*w-4)/(6*scale)))
  local height=math.max(1,math.floor((64*h-4)/(9*scale)))
  if not errors.integer(width,1,MAX) or not errors.integer(height,1,MAX)
    or not errors.integer(width*height,1,MAX) then errors.raise('E_RANGE','unrepresentable monitor geometry') end
  return width,height
end
local function blank(m) return {32,m.fg,m.bg} end
local function full_damage(m)
  m.damage={}; m.damage_count=0; m.damage_full=true
  m.damage_generation=(m.damage_generation or 0)+1
end
M.invalidate=full_damage -- Trusted settings-paste/import paths also replace palettes.
local function damaged(m,i)
  -- Older saves have no damage baseline: conservatively rebuild once.
  if not m.damage then full_damage(m) end
  if not m.damage[i] then m.damage[i]=true; m.damage_count=m.damage_count+1 end
end
local function clear(m)
  local cells={}; for i=1,m.width*m.height do cells[i]=blank(m) end; m.cells=cells; m.cells_shared=nil
  full_damage(m)
end
-- Cell records and palette triples are immutable. Only the flat root is copied
-- on the first admitted in-place write after a snapshot, not on every write.
local function copy_cost(m) return m.cells_shared and m.width*m.height or 0 end
local function own(m)
  if m.cells_shared then
    local cells={}; for i,c in ipairs(m.cells) do cells[i]=c end
    m.cells=cells; m.cells_shared=nil
  end
end
function M.capture(m,spend)
  spend(80+(m.damage_count or 0)*2)
  local s={}; for _,k in ipairs({'x','y','blink','fg','bg','scale','revision','width','height'}) do s[k]=m[k] end
  s.palette={}; for i,p in ipairs(m.palette) do s.palette[i]=p end
  s.damage={}; for i in pairs(m.damage or {}) do s.damage[#s.damage+1]=i end
  s.damage_full=m.damage_full or not m.damage; s.damage_generation=m.damage_generation
  s.cells=m.cells; m.cells_shared=true; return s
end
-- The publisher prepays this bounded acknowledgement before changing visibility.
-- Never consume later writes, a later clear/palette epoch, or coalesced damage.
function M.acknowledge_cost(m,s)
  if not s.damage or m.damage_generation~=s.damage_generation or not m.damage then return 0 end
  if m.cells==s.cells then return 1 end
  return #s.damage
end
function M.acknowledge(m,s)
  if not s.damage or m.damage_generation~=s.damage_generation or not m.damage then return end
  if m.cells==s.cells then
    m.damage={}; m.damage_count=0; m.damage_full=nil; return
  end

  for _,i in ipairs(s.damage) do
    if m.damage[i] and m.cells[i]==s.cells[i] then m.damage[i]=nil; m.damage_count=m.damage_count-1 end
  end
  if s.damage_full then m.damage_full=nil end
end
function M.new(w,h,inherit)
  local m={x=1,y=1,blink=false,fg=0,bg=15,scale=1,palette={},revision=1}
  if inherit then
    for _,k in ipairs({'x','y','blink','fg','bg','scale'}) do m[k]=inherit[k] end
    for i=1,16 do local p=inherit.palette[i]; m.palette[i]={p[1],p[2],p[3]} end
  else
    for i,p in ipairs(palette) do m.palette[i]={math.floor(p/65536)/255,math.floor(p/256)%256/255,p%256/255} end
  end
  m.width,m.height=M.size(w,h,m.scale)
  if m.width*m.height>M.limits.cells then errors.raise('E_CAPACITY','monitor storage admission requires shared host ownership') end
  if inherit and inherit.width==m.width and inherit.height==m.height then
    m.cells={}; for i,c in ipairs(inherit.cells) do m.cells[i]={c[1],c[2],c[3]} end
    full_damage(m)
  else clear(m) end
  return m
end
function M.resize(m,w,h)
  local x,y=M.size(w,h,m.scale)
  if x==m.width and y==m.height then return false end
  if x*y>M.limits.cells then errors.raise('E_CAPACITY','monitor storage admission requires shared host ownership') end
  local oldw,oldh=m.width,m.height; m.width=x; m.height=y; clear(m); m.revision=m.revision+1
  return true,oldw,oldh
end
local calls={}
local function method(name,n,fn)
  calls[name]=function(m,spend,...)
    if select('#',...)~=n then errors.raise('E_ARGUMENT','unexpected argument count; use dot calls') end
    spend(1); return fn(m,spend,...)
  end
end
method('getSize',0,function(m) return m.width,m.height end)
method('getCursorPos',0,function(m) return m.x,m.y end)
method('getCursorBlink',0,function(m) return m.blink end)
method('getTextColor',0,function(m) return 2^m.fg end)
method('getBackgroundColor',0,function(m) return 2^m.bg end)
method('getTextScale',0,function(m) return m.scale end)
method('isColor',0,function() return true end)
method('setCursorPos',2,function(m,spend,x,y) integer(x); integer(y); spend(2); m.x=x; m.y=y; m.revision=m.revision+1 end)
method('setCursorBlink',1,function(m,spend,b)
  if type(b)~='boolean' then errors.raise('E_ARGUMENT','boolean required') end
  spend(1); m.blink=b; m.revision=m.revision+1
end)
method('setTextColor',1,function(m,spend,c) c=color(c); spend(1); m.fg=c; m.revision=m.revision+1 end)
method('setBackgroundColor',1,function(m,spend,c) c=color(c); spend(1); m.bg=c end)
local function write(m,spend,text,fg,bg)
  string_arg(text)
  integer(m.x+#text)
  if fg then
    string_arg(fg); string_arg(bg)
    if #fg~=#text or #bg~=#text then errors.raise('E_ARGUMENT','blit strings must have equal lengths') end
    spend(#text*3+1)
    for i=1,#text do
      if not digit(fg:byte(i)) or not digit(bg:byte(i)) then errors.raise('E_ARGUMENT','lowercase hexadecimal blit colors required') end
    end
  end
  local first,last=math.max(1,2-m.x),math.min(#text,m.width-m.x+1)
  local visible=m.y>=1 and m.y<=m.height and math.max(0,last-first+1) or 0
  spend(#text+visible*8+1)
  if m.y>=1 and m.y<=m.height then
    for i=first,last do
      local f,b=m.fg,m.bg
      if fg then f=digit(fg:byte(i)); b=digit(bg:byte(i)) end
      local index=(m.y-1)*m.width+m.x+i-1; local byte=text:byte(i); local old=m.cells[index]
      if old[1]~=byte or old[2]~=f or old[3]~=b then
        if m.cells_shared then spend(copy_cost(m)) end -- Before the first cell mutation only.
        own(m) -- Identical full-row blits must not allocate a grid-sized copy.
        m.cells[index]={byte,f,b}; damaged(m,index)
      end
    end
  end
  m.x=m.x+#text; m.revision=m.revision+1
end
method('write',1,function(m,s,t) write(m,s,t) end)
method('blit',3,function(m,s,t,f,b) write(m,s,t,f,b) end)
method('clear',0,function(m,s) s(m.width*m.height*3+5); clear(m); m.revision=m.revision+1 end)
method('clearLine',0,function(m,s)
  s(m.width*7+1)
  if m.y>=1 and m.y<=m.height then
    for x=1,m.width do
      local i=(m.y-1)*m.width+x; local c=m.cells[i]
      if c[1]~=32 or c[2]~=m.fg or c[3]~=m.bg then
        if m.cells_shared then s(copy_cost(m)) end
        own(m); m.cells[i]=blank(m); damaged(m,i)
      end
    end
    m.revision=m.revision+1
  end
end)
method('scroll',1,function(m,s,lines)
  integer(lines); s(m.width*m.height*3+5)
  local cells={}
  for y=1,m.height do
    local source=y+lines
    for x=1,m.width do
      local i=(y-1)*m.width+x
      cells[i]=source>=1 and source<=m.height and m.cells[(source-1)*m.width+x] or blank(m)
    end
  end
  m.cells=cells; m.cells_shared=nil; m.revision=m.revision+1
  full_damage(m)
end)
method('getPaletteColor',1,function(m,s,c) c=color(c); local p=m.palette[c+1]; return p[1],p[2],p[3] end)
calls.setPaletteColor=function(m,s,...)
  local n=select('#',...); if n~=2 and n~=4 then errors.raise('E_ARGUMENT','palette expects color/rgb or color/r/g/b') end
  local c,r,g,b=...; c=color(c)
  if n==2 then
    if type(r)~='number' then errors.raise('E_ARGUMENT','numeric packed RGB required') end
    if not errors.integer(r,0,16777215) then errors.raise('E_RANGE','24-bit packed RGB required') end
    r,g,b=math.floor(r/65536)/255,math.floor(r/256)%256/255,r%256/255
  else
    if type(r)~='number' or type(g)~='number' or type(b)~='number' then errors.raise('E_ARGUMENT','three numeric channels required') end
    for _,v in ipairs({r,g,b}) do if v~=v or v<0 or v>1 then errors.raise('E_RANGE','finite palette channels 0..1 required') end end
  end
  s(8); local old=m.palette[c+1]
  if old[1]~=r or old[2]~=g or old[3]~=b then full_damage(m) end
  m.palette[c+1]={r,g,b}; m.revision=m.revision+1
end
for _,name in ipairs({'getTextColor','setTextColor','getBackgroundColor','setBackgroundColor','getPaletteColor','setPaletteColor','isColor'}) do
  calls[(name:gsub('Color','Colour'))]=calls[name]
end
M.calls=calls
function M.scale(m,w,h,s,scale)
  local width,height=M.size(w,h,scale)
  -- Keep the existing safety envelope until shared host lifetime admission lands.
  if width*height>M.limits.cells then errors.raise('E_CAPACITY','monitor storage admission requires shared host ownership') end
  s(width*height*3+5)
  local oldw,oldh=m.width,m.height; m.scale=scale
  if width~=oldw or height~=oldh then m.width=width; m.height=height; clear(m) end
  m.revision=m.revision+1; return width~=oldw or height~=oldh,oldw,oldh
end
-- Shared affine geometry for rendering and touch. World box starts at left/top.
function M.geometry(g)
  local m=g.model; local cw,ch=6*m.scale/64,9*m.scale/64
  return cw,ch,(g.width_tiles-m.width*cw)/2,(g.height_tiles-m.height*ch)/2
end
function M.world(g,u,v)
  local d=g.direction
  if d==0 then return g.left+u,g.top+v
  elseif d==4 then return g.left+g.world_width-v,g.top+u
  elseif d==8 then return g.left+g.world_width-u,g.top+g.world_height-v
  else return g.left+v,g.top+g.world_height-u end
end
function M.local_position(g,x,y)
  x=x-g.left; y=y-g.top
  if g.direction==0 then return x,y elseif g.direction==4 then return y,g.world_width-x
  elseif g.direction==8 then return g.world_width-x,g.world_height-y else return g.world_height-y,x end
end
function M.touch(g,x,y)
  local u,v=M.local_position(g,x,y); local cw,ch,ox,oy=M.geometry(g)
  if u<ox or v<oy or u>=ox+g.model.width*cw or v>=oy+g.model.height*ch then return nil end
  return math.floor((u-ox)/cw)+1,math.floor((v-oy)/ch)+1
end
return M
