local model=require('scripts.monitor-model')
local monitor=require('scripts.services.monitor')
local M={}
local function nop() end
local function copy(t)
  if type(t)~='table' then return t end
  local r={}; for k,v in pairs(t) do r[k]=copy(v) end; return r
end
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end; return true
end
function M.run()
  local m=model.new(6,6); model.scale(m,6,6,nop,2)
  local initial=model.capture(m,nop); assert(initial.damage_full)
  model.acknowledge(m,initial); assert(not m.damage_full and m.damage_count==0)
  model.calls.write(m,nop,'A'); local first=model.capture(m,nop); local frozen=copy(first)
  model.calls.write(m,nop,'B'); assert(equal(first,frozen) and m.damage_count==2)
  model.acknowledge(m,first)
  assert(m.damage_count==1 and m.damage[2] and not m.damage[1],'acknowledgement consumed a later cell write')
  model.calls.setCursorPos(m,nop,2,1); model.calls.write(m,nop,'C')
  local second=model.capture(m,nop)
  model.calls.setCursorPos(m,nop,2,1); model.calls.write(m,nop,'D')
  model.acknowledge(m,second); assert(m.damage_count==1 and m.damage[2],'acknowledgement consumed a later same-cell write')
  local latest=model.capture(m,nop); model.acknowledge(m,latest)
  assert(m.damage_count==0)
  model.calls.setCursorPos(m,nop,2,1); model.calls.write(m,nop,'D')
  assert(m.damage_count==0,'identical write dirtied an unchanged cell')
  model.calls.clear(m,nop); local cleared=model.capture(m,nop)
  model.calls.setPaletteColor(m,nop,1,0x123456); model.acknowledge(m,cleared)
  assert(m.damage_full,'old clear acknowledgement consumed a later palette invalidation')
  local colored=model.capture(m,nop); model.acknowledge(m,colored); assert(not m.damage_full)
  m.damage=nil; m.damage_count=nil; m.damage_full=nil; m.damage_generation=nil
  local legacy=model.capture(m,nop); assert(legacy.damage_full)
  model.calls.write(m,nop,'legacy'); model.acknowledge(m,legacy); assert(m.damage_full)
  log('TC_SNAPSHOT_DAMAGE_ACK_OK immutable coalesced later-writes palette legacy')
  local cases=0
  for w=1,6 do for h=1,6 do for step=1,10 do for _,direction in ipairs({0,4,8,12}) do
    local m=model.new(w,h); model.scale(m,w,h,nop,step/2)
    local x,y=model.size(w,h,step/2); assert(m.width==x and m.height==y and #m.cells==x*y and #m.cells<=10584)
    local g={left=0,top=0,width_tiles=w,height_tiles=h,world_width=(direction==4 or direction==12) and h or w,
      world_height=(direction==4 or direction==12) and w or h,direction=direction,model=m}
    local cw,ch,ox,oy=model.geometry(g); local wx,wy=model.world(g,ox+cw/2,oy+ch/2)
    local a,b=model.touch(g,wx,wy); assert(a==1 and b==1)
    model.calls.write(m,nop,'A'); local snap=model.capture(m,nop)
    local root=m.cells; local revision=m.revision; local cursor=m.x
    local budget=1; local ok=pcall(model.calls.write,m,function(n) budget=budget-n; if budget<0 then error('refused') end end,'B')
    assert(not ok and m.cells==root and m.revision==revision and m.x==cursor and m.cells_shared)
    model.calls.write(m,nop,'B'); assert(m.cells~=root and snap.cells[1][1]==65)
    model.calls.setPaletteColor(m,nop,1,0x123456); assert(snap.palette[1]~=m.palette[1])
    model.calls.clear(m,nop); assert(snap.cells[1][1]==65)
    cases=cases+1
  end end end end
  assert(cases==1440)
  local mutations={
    {'write','AB'}, {'blit','XY','05','f0'}, {'clear'}, {'clearLine'}, {'scroll',1}, {'scroll',-1}, {'scroll',0},
    {'setCursorPos',2,2}, {'setCursorBlink',true}, {'setTextColor',2}, {'setTextColour',4},
    {'setBackgroundColor',8}, {'setBackgroundColour',16}, {'setPaletteColor',1,0x123456},
    {'setPaletteColour',2,0.1,0.2,0.3}, {'setTextScale',0.5}}
  local checked=0
  for _,shape in ipairs({{1,1},{3,6},{6,3},{6,6}}) do for _,op in ipairs(mutations) do
    local m=model.new(shape[1],shape[2]); model.calls.write(m,nop,'KEEP')
    model.calls.setCursorPos(m,nop,1,1)
    local snapshot=model.capture(m,nop); local captured=copy(snapshot)
    local before=copy(m); local cells,palette=m.cells,m.palette
    local function invoke(spend)
      if op[1]=='setTextScale' then return model.scale(m,shape[1],shape[2],spend,op[2]) end
      return model.calls[op[1]](m,spend,table.unpack(op,2))
    end
    local cost=0; invoke(function(n) cost=cost+n end)
    assert(equal(snapshot,captured),'successful mutation changed captured snapshot: '..op[1])
    m=model.new(shape[1],shape[2]); model.calls.write(m,nop,'KEEP'); model.calls.setCursorPos(m,nop,1,1)
    snapshot=model.capture(m,nop); captured=copy(snapshot); before=copy(m); cells,palette=m.cells,m.palette
    local available=cost-1
    assert(not pcall(invoke,function(n) if n>available then error('one-short',0) end; available=available-n end))
    assert(equal(m,before) and m.cells==cells and m.palette==palette and equal(snapshot,captured),
      'refused mutation changed model/snapshot bookkeeping: '..op[1])
    checked=checked+1
  end end
  log('TC_SNAPSHOT_MUTATORS_OK cases='..checked)
  for _,shape in ipairs({{1,1},{1,6},{6,1},{3,6},{6,3},{6,6},{7,1},{1,7}}) do
    local tiles={}; for y=1,shape[2] do for x=1,shape[1] do tiles[#tiles+1]={id=x..'/'..y,position={x=x,y=y},direction=0,force_index=1,surface_index=1} end end
    local groups=monitor.partition(tiles)
    local n=0; for _,g in ipairs(groups) do assert(g.width_tiles<=6 and g.height_tiles<=6); n=n+#g.members end
    assert(n==#tiles)
    if shape[1]<=6 and shape[2]<=6 then assert(#groups==1) else assert(#groups==2) end
  end
  log('TC_SNAPSHOT_GEOMETRY_OK cases='..cases)
end
return M
