-- Graphics mode: retained native objects in monitor content pixels (64 per tile).
-- Stored props are the source of truth; native objects are their projection.
local errors=require('scripts.runtime.errors')
local data=require('scripts.runtime.data')
local registry=require('scripts.registry')
local model=require('scripts.monitor-model')
local M={}
local L=model.limits
local EPS=1e-9
local TAU=2*math.pi
local SPRITE_LAYER='higher-object-above' -- Above the panel; every sprite layer draws below shapes and text.
-- Native icon scale for a 64-pixel box at x_scale 1 (calibrated, design D4).
local ICONS={item=1,fluid=1,entity=1,recipe=1,technology=0.25,['virtual-signal']=1,tile=1,['item-group']=0.5,
  quality=1,['space-location']=1,['asteroid-chunk']=1,equipment=1}
local LIGHT_TILES_PER_SCALE=4.25 -- utility/light_medium glow radius per native scale, conservative (D4).
local UNDER={sprite=true,light=true}
local MAP={} -- Byte to U+E000+byte: guest bytes never form rich text.
for b=0,255 do MAP[string.char(b)]=string.char(0xEE,0x80+math.floor(b/64),0x80+b%64) end
M.UNDER=UNDER

-- Property schema: key -> {kind, default}. A key without default is required.
local WHITE={r=1,g=1,b=1,a=1}
local COMMON={visible={'boolean',true},blink_interval={'tick',0},only_in_alt_mode={'boolean',false}}
local SCHEMA={
  line={from={'point'},to={'point'},color={'color'},width={'positive',2},dash_length={'nonneg',0},gap_length={'nonneg',0},dash_offset={'number',0}},
  polygon={vertices={'points'},color={'color'}},
  rectangle={left_top={'point'},right_bottom={'point'},color={'color'},filled={'boolean',false},width={'positive',2}},
  circle={target={'point'},radius={'positive'},color={'color'},filled={'boolean',false},width={'positive',2}},
  arc={target={'point'},min_radius={'nonneg'},max_radius={'positive'},start_angle={'number'},angle={'sweep'},color={'color'}},
  text={text={'text'},target={'point'},color={'color'},scale={'half',1},alignment={'halign','left'},
    vertical_alignment={'valign','top'},orientation={'turn',0}},
  sprite={sprite={'sprite'},target={'point'},x_scale={'positive',1},y_scale={'positive',1},tint={'color',WHITE},orientation={'turn',0}},
  light={target={'point'},radius={'positive'},color={'color',WHITE},intensity={'unit',1},minimum_darkness={'unit',0}},
}
for _,schema in pairs(SCHEMA) do for k,v in pairs(COMMON) do schema[k]=v end end
M.SCHEMA=SCHEMA
local ENUMS={halign={left=true,center=true,right=true},valign={top=true,middle=true,bottom=true}}

local function fail(code,message) errors.raise(code,message) end
local function number(v,key)
  if type(v)~='number' then fail('E_ARGUMENT',key..' must be a number') end
  if v~=v or v==math.huge or v==-math.huge then fail('E_RANGE',key..' must be finite') end
  return v
end
local function point(v,key)
  if type(v)~='table' then fail('E_ARGUMENT',key..' must be a point') end
  local x,y
  if v[1]~=nil then
    if #v~=2 or v.x~=nil or v.y~=nil then fail('E_ARGUMENT',key..' must be {x, y}') end
    x,y=v[1],v[2]
  else
    for k in pairs(v) do if k~='x' and k~='y' then fail('E_ARGUMENT',key..' has an unknown key') end end
    x,y=v.x,v.y
  end
  return {x=number(x,key..'.x'),y=number(y,key..'.y')}
end
local function color(v,key)
  if type(v)~='table' then fail('E_ARGUMENT',key..' must be a colour table') end
  local r,g,b,a
  if v[1]~=nil then
    if (#v~=3 and #v~=4) or v.r~=nil then fail('E_ARGUMENT',key..' must be {r, g, b[, a]}') end
    r,g,b,a=v[1],v[2],v[3],v[4]
  else
    for k in pairs(v) do if k~='r' and k~='g' and k~='b' and k~='a' then fail('E_ARGUMENT',key..' has an unknown key') end end
    r,g,b,a=v.r,v.g,v.b,v.a
  end
  local out={}
  for i,c in ipairs({{'r',r},{'g',g},{'b',b},{'a',a==nil and 1 or a}}) do
    local x=number(c[2],key..'.'..c[1]); if x<0 or x>1 then fail('E_RANGE',key..' channels must be 0..1') end
    out[c[1]]=x
  end
  return out
end
local CHECK={
  boolean=function(v,key) if type(v)~='boolean' then fail('E_ARGUMENT',key..' must be a boolean') end; return v end,
  number=number,
  tick=function(v,key) number(v,key); if not errors.integer(v,0,65535) then fail('E_RANGE',key..' must be an integer 0..65535') end; return v end,
  positive=function(v,key) number(v,key); if v<=0 then fail('E_RANGE',key..' must be greater than 0') end; return v end,
  nonneg=function(v,key) number(v,key); if v<0 then fail('E_RANGE',key..' must be 0 or more') end; return v end,
  sweep=function(v,key) number(v,key); if v<=0 or v>TAU then fail('E_RANGE',key..' must be in (0, 2*pi]') end; return v end,
  unit=function(v,key) number(v,key); if v<0 or v>1 then fail('E_RANGE',key..' must be 0..1') end; return v end,
  turn=function(v,key) number(v,key); if v<0 or v>1 then fail('E_RANGE',key..' must be 0..1') end; return v end,
  half=function(v,key) number(v,key); if not errors.integer(v*2,1,10) then fail('E_RANGE',key..' must be a half step 0.5..5') end; return v end,
  halign=function(v,key) if type(v)~='string' then fail('E_ARGUMENT',key..' must be a string') end; if not ENUMS.halign[v] then fail('E_RANGE','unknown '..key) end; return v end,
  valign=function(v,key) if type(v)~='string' then fail('E_ARGUMENT',key..' must be a string') end; if not ENUMS.valign[v] then fail('E_RANGE','unknown '..key) end; return v end,
  text=function(v,key) if type(v)~='string' then fail('E_ARGUMENT',key..' must be a string') end; if #v>L.write_bytes then fail('E_LIMIT','monitor write byte limit') end; return v end,
  sprite=function(v,key)
    if type(v)~='string' then fail('E_ARGUMENT',key..' must be a string') end
    local kind=v:match('^([%w%-]+)/.+$')
    if not kind or not ICONS[kind] or not helpers.is_valid_sprite_path(v) then fail('E_RANGE','sprite must be a valid game icon path') end
    return v
  end,
  point=point,color=color,
  points=function(v,key)
    if type(v)~='table' or #v<3 then fail('E_ARGUMENT',key..' must hold at least three points') end
    for k in pairs(v) do if not errors.integer(k,1,#v) then fail('E_ARGUMENT',key..' must be a dense array') end end
    local out={}; for i=1,#v do out[i]=point(v[i],key..'['..i..']') end; return out
  end,
}
local function copy_point(p) return {x=p.x,y=p.y} end
local function clone(v)
  if type(v)~='table' then return v end
  local out={}; for k,x in pairs(v) do out[k]=clone(x) end; return out
end
-- Complete validated props: `input` over `base` (set) or over defaults (draw).
local function validate(kind,input,base)
  local schema=SCHEMA[kind]
  for k in pairs(input) do if type(k)~='string' or not schema[k] then fail('E_ARGUMENT','property not supported by '..kind..': '..tostring(k)) end end
  local p={}
  for k,spec in pairs(schema) do
    local v=input[k]
    if v==nil then
      if base then p[k]=base[k] -- stored props are never mutated in place
      elseif spec[2]==nil then fail('E_ARGUMENT',kind..' requires '..k)
      else p[k]=clone(spec[2]) end
    else p[k]=CHECK[spec[1]](v,k) end
  end
  if kind=='rectangle' and (p.right_bottom.x<p.left_top.x or p.right_bottom.y<p.left_top.y) then fail('E_RANGE','right_bottom must not be left of or above left_top') end
  if kind=='arc' and p.max_radius<=p.min_radius then fail('E_RANGE','max_radius must be greater than min_radius') end
  return p
end
M.validate=validate

-- Exact covered box in content pixels (design D3).
local function rotated_box(cx,cy,x0,y0,x1,y1,turn)
  local a=turn*TAU; local c,s=math.cos(a),math.sin(a)
  local minx,miny,maxx,maxy=math.huge,math.huge,-math.huge,-math.huge
  for _,q in ipairs({{x0,y0},{x1,y0},{x0,y1},{x1,y1}}) do
    local dx,dy=q[1]-cx,q[2]-cy
    local x,y=cx+dx*c-dy*s,cy+dx*s+dy*c
    minx,miny,maxx,maxy=math.min(minx,x),math.min(miny,y),math.max(maxx,x),math.max(maxy,y)
  end
  return minx,miny,maxx,maxy
end
local function text_box(p)
  local w,h=#p.text*6*p.scale,9*p.scale; local x0,y0=p.target.x,p.target.y
  if p.alignment=='center' then x0=x0-w/2 elseif p.alignment=='right' then x0=x0-w end
  if p.vertical_alignment=='middle' then y0=y0-h/2 elseif p.vertical_alignment=='bottom' then y0=y0-h end
  return x0,y0,w,h
end
function M.bounds(kind,p)
  if kind=='line' then
    local d=p.width/2
    return math.min(p.from.x,p.to.x)-d,math.min(p.from.y,p.to.y)-d,math.max(p.from.x,p.to.x)+d,math.max(p.from.y,p.to.y)+d
  elseif kind=='rectangle' then
    local d=p.filled and 0 or p.width/2
    return p.left_top.x-d,p.left_top.y-d,p.right_bottom.x+d,p.right_bottom.y+d
  elseif kind=='circle' then
    local r=p.radius+(p.filled and 0 or p.width/2)
    return p.target.x-r,p.target.y-r,p.target.x+r,p.target.y+r
  elseif kind=='light' then
    local r=p.radius; return p.target.x-r,p.target.y-r,p.target.x+r,p.target.y+r
  elseif kind=='polygon' then
    local minx,miny,maxx,maxy=math.huge,math.huge,-math.huge,-math.huge
    for _,v in ipairs(p.vertices) do minx,miny,maxx,maxy=math.min(minx,v.x),math.min(miny,v.y),math.max(maxx,v.x),math.max(maxy,v.y) end
    return minx,miny,maxx,maxy
  elseif kind=='arc' then
    -- Annulus sector: both radii at both ends, plus every axis extreme inside the sweep.
    local cx,cy=p.target.x,p.target.y; local a0,a1=p.start_angle,p.start_angle+p.angle
    local minx,miny,maxx,maxy=math.huge,math.huge,-math.huge,-math.huge
    local function add(r,a) local x,y=cx+r*math.cos(a),cy+r*math.sin(a)
      minx,miny,maxx,maxy=math.min(minx,x),math.min(miny,y),math.max(maxx,x),math.max(maxy,y) end
    for _,r in ipairs({p.min_radius,p.max_radius}) do add(r,a0); add(r,a1) end
    local k=math.ceil(a0/(math.pi/2)-EPS)
    while k*math.pi/2<=a1+EPS do add(p.max_radius,k*math.pi/2); k=k+1 end
    return minx,miny,maxx,maxy
  elseif kind=='text' then
    local x0,y0,w,h=text_box(p)
    return rotated_box(p.target.x,p.target.y,x0,y0,x0+w,y0+h,p.orientation)
  elseif kind=='sprite' then
    local w,h=64*p.x_scale,64*p.y_scale
    return rotated_box(p.target.x,p.target.y,p.target.x-w/2,p.target.y-h/2,p.target.x+w/2,p.target.y+h/2,p.orientation)
  end
end
function M.size(g) return 64*g.width_tiles-4,64*g.height_tiles-4 end
local function inside(g,kind,p)
  local W,H=M.size(g); local x0,y0,x1,y1=M.bounds(kind,p)
  if x0<-EPS or y0<-EPS or x1>W+EPS or y1>H+EPS then fail('E_RANGE',kind..' leaves the content area') end
end
M.inside=inside

-- Native projection (design D2): content pixel -> local tile -> world.
local function world(g,x,y) local wx,wy=model.world(g,(2+x)/64,(2+y)/64); return {wx,wy} end
local function native_color(c) return {c.r,c.g,c.b,c.a} end
local function turn(g,o) return (o+g.direction/16)%1 end
local function native(g,kind,p,shown)
  local n={visible=p.visible and shown,blink_interval=p.blink_interval,only_in_alt_mode=p.only_in_alt_mode}
  if kind=='line' then
    n.from=world(g,p.from.x,p.from.y); n.to=world(g,p.to.x,p.to.y); n.color=native_color(p.color); n.width=p.width/2
    n.dash_length=p.dash_length/64; n.gap_length=p.gap_length/64; n.dash_offset=p.dash_offset/64
  elseif kind=='polygon' then
    n.vertices={}; for i,v in ipairs(p.vertices) do n.vertices[i]=world(g,v.x,v.y) end; n.color=native_color(p.color)
  elseif kind=='rectangle' then
    local a,b=world(g,p.left_top.x,p.left_top.y),world(g,p.right_bottom.x,p.right_bottom.y)
    n.left_top={math.min(a[1],b[1]),math.min(a[2],b[2])}; n.right_bottom={math.max(a[1],b[1]),math.max(a[2],b[2])}
    n.color=native_color(p.color); n.filled=p.filled; n.width=p.width/2
  elseif kind=='circle' then
    n.target=world(g,p.target.x,p.target.y); n.radius=p.radius/64; n.color=native_color(p.color); n.filled=p.filled; n.width=p.width/2
  elseif kind=='arc' then
    n.target=world(g,p.target.x,p.target.y); n.min_radius=p.min_radius/64; n.max_radius=p.max_radius/64
    n.start_angle=p.start_angle+g.direction/16*TAU; n.angle=p.angle; n.color=native_color(p.color)
  elseif kind=='text' then
    -- Anchor the rotated top-left corner and keep native left/top alignment (one engine text offset).
    local x0,y0=text_box(p); local a=p.orientation*TAU; local dx,dy=x0-p.target.x,y0-p.target.y
    local x,y=p.target.x+dx*math.cos(a)-dy*math.sin(a),p.target.y+dx*math.sin(a)+dy*math.cos(a)
    n.target=world(g,x,y); n.text=(p.text:gsub('.',MAP)); n.color=native_color(p.color); n.scale=0.125*p.scale
    n.orientation=turn(g,p.orientation)
  elseif kind=='sprite' then
    local factor=ICONS[p.sprite:match('^([%w%-]+)/')]
    n.sprite=p.sprite; n.target=world(g,p.target.x,p.target.y); n.x_scale=p.x_scale*factor; n.y_scale=p.y_scale*factor
    n.color=native_color(p.tint); n.orientation=turn(g,p.orientation)
  elseif kind=='light' then
    n.target=world(g,p.target.x,p.target.y); n.scale=p.radius/64/LIGHT_TILES_PER_SCALE; n.color=native_color(p.color)
    n.intensity=p.intensity; n.minimum_darkness=p.minimum_darkness
  end
  return n
end
local function create(g,kind,p,shown)
  local n=native(g,kind,p,shown); n.surface=g.surface_index
  if kind=='text' then n.font='tc-term'; n.alignment='left'; n.vertical_alignment='top'; n.use_rich_text=false end
  if kind=='sprite' then n.tint=n.color; n.color=nil; n.render_layer=SPRITE_LAYER end
  if kind=='light' then n.sprite='utility/light_medium' end
  return rendering['draw_'..kind](n)
end
local function update(g,o,kind,p,shown)
  for k,v in pairs(native(g,kind,p,shown)) do o[k]=v end
end
-- Text and colour of left-aligned text map to one native property each; other changes rebuild all.
local function update_text(o,input,p)
  for k in pairs(input) do if k~='text' and k~='color' then return false end end
  if input.text~=nil and p.alignment~='left' then return false end
  if input.text~=nil then o.text=(p.text:gsub('.',MAP)) end
  if input.color~=nil then o.color=native_color(p.color) end
  return true
end

-- Store (design D1) and the shared native-object count (design D6).
function M.store(g)
  local s=g.graphics
  if not s then s={next_id=1,under={},over={},objects={}}; g.graphics=s end
  return s
end
local function root() return registry.get().monitors end
function M.count(delta) local s=root(); s.native_objects=math.max(0,(s.native_objects or 0)+delta) end
function M.limit() return L.render_object_limit end -- Fixtures may lower only this view.
function M.shown(g) local r=g.render; return not (r and (r.hidden or r.marked)) end
function M.object_count(g) local s=g.graphics; return s and #s.under+#s.over or 0 end
-- Presentation visibility (unavailable or marked) applied to every object; stored props unchanged.
function M.show(g,shown)
  local s=g.graphics; if not s then return end
  for _,list in ipairs({s.under,s.over}) do for _,id in ipairs(list) do
    local o=s.objects[id]; if o.native.valid then o.native.visible=shown and o.props.visible end
  end end
end
function M.destroy_all(g)
  local s=g.graphics; if not s then return 0 end
  local n=0
  for _,o in pairs(s.objects) do if o.native.valid then o.native.destroy(); n=n+1 end end
  if n>0 then M.count(-n) end
  s.objects={}; s.under={}; s.over={}
  return n
end

-- Guest methods: fn(g, spend, ...). Dispatch charge 1, Data copy charges, 16 per native call.
local function args(n,...) if select('#',...)~=n then fail('E_ARGUMENT','unexpected argument count; use dot calls') end end
local function payload(props,spend)
  if type(props)~='table' or getmetatable(props)~=nil then fail('E_ARGUMENT','property table required') end
  -- Measure, not copy: validate() reads props once and builds fresh tables.
  local ok,stats=pcall(data.measure,props,spend,L.peripheral_call_bytes)
  if not ok then
    if type(stats)=='table' and stats.code=='E_CAPACITY' then fail('E_LIMIT','graphics payload exceeds the per-call byte allowance') end
    error(stats,0)
  end
  if stats.nodes>L.peripheral_call_entries then fail('E_LIMIT','graphics payload exceeds the per-call entry allowance') end
  return props
end
local function id_arg(id)
  if type(id)~='number' then fail('E_ARGUMENT','object id must be a number') end
  if not errors.integer(id,1,9007199254740991) then fail('E_RANGE','object id must be a positive safe integer') end
  return id
end
local function find(g,id)
  local s=g.graphics; local o=s and s.objects[id_arg(id)]
  if not o then fail('E_NOT_FOUND','unknown graphics object id') end
  return s,o
end
local function list_of(s,o) return UNDER[o.type] and s.under or s.over end
local function remove(list,id,spend)
  for i,x in ipairs(list) do if x==id then spend(i); table.remove(list,i); return end end
end
local calls={}
for kind in pairs(SCHEMA) do
  calls['draw'..kind:sub(1,1):upper()..kind:sub(2)]=function(g,spend,...)
    args(1,...); spend(1)
    local p=validate(kind,payload(...,spend)); inside(g,kind,p)
    if (root().native_objects or 0)+1>M.limit() then fail('E_CAPACITY','monitor presentation object limit') end
    spend(16)
    local s=M.store(g); local id=s.next_id
    local o=create(g,kind,p,M.shown(g)); M.count(1)
    s.next_id=id+1; s.objects[id]={type=kind,props=p,native=o}
    local list=UNDER[kind] and s.under or s.over; list[#list+1]=id
    return id
  end
end
function calls.set(g,spend,...)
  args(2,...); spend(1)
  local id,props=...
  local s,o=find(g,id)
  local p=validate(o.type,payload(props,spend),o.props); inside(g,o.type,p)
  spend(16)
  if not o.native.valid then o.native=create(g,o.type,p,M.shown(g))
  elseif not (o.type=='text' and update_text(o.native,props,p)) then update(g,o.native,o.type,p,M.shown(g)) end
  o.props=p
end
function calls.get(g,spend,...)
  args(1,...); spend(1)
  local s=g.graphics; local o=s and s.objects[id_arg(...)]
  if not o then return nil end
  local out=clone(o.props); out.type=o.type
  return (data.copy(out,spend,L.peripheral_call_bytes))
end
function calls.getObjects(g,spend,...)
  args(0,...); spend(1)
  local s=g.graphics; local out={}
  if s then for _,list in ipairs({s.under,s.over}) do for _,id in ipairs(list) do out[#out+1]=id end end end
  spend(#out+1)
  return out
end
function calls.destroy(g,spend,...)
  args(1,...); spend(1)
  local s,o=find(g,...); local id=...
  spend(16); remove(list_of(s,o),id,spend)
  if o.native.valid then o.native.destroy(); M.count(-1) end
  s.objects[id]=nil
end
local function reorder(front)
  return function(g,spend,...)
    args(1,...); spend(1)
    local s,o=find(g,...); local id=...
    if UNDER[o.type] then fail('E_UNSUPPORTED','sprites and lights draw in engine order; they cannot be reordered') end
    spend(16); remove(s.over,id,spend)
    if front then s.over[#s.over+1]=id else table.insert(s.over,1,id) end
    spend(#s.over)
    if o.native.valid then if front then o.native.bring_to_front() else o.native.move_to_back() end end
  end
end
calls.bringToFront=reorder(true)
calls.moveToBack=reorder(false)
-- Graphics clear: every object goes, ids continue.
function M.clear(g,spend)
  local s=g.graphics; spend(M.object_count(g)*2+5)
  M.destroy_all(g)
end
M.calls=calls
return M
