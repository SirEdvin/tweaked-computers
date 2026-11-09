-- Graphics mode contracts (monitor-graphics-mode) with actual native objects and a
-- separate-process reload. Activation players are headless mocks, not client evidence.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local lifecycle=require('scripts.lifecycle')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local defs=require('scripts.device-definitions')
local model=require('scripts.monitor-model')
local graphics=require('scripts.monitor-graphics')
local snapshots=require('scripts.lifecycle-data')
local monitor=require('scripts.services.monitor')
local renderer=require('scripts.rendering')
local M={}; local loaded=false
local function nop() end
local function f() return storage.tc_graphics end
local function report(s) f().groups=f().groups+1; log('TC_GRAPHICS '..s) end
local function error_is(code,fn,...)
  local ok,e=pcall(fn,...); assert(not ok and type(e)=='table' and e.code==code,'expected '..code..', got '..serpent.line(e))
end
local function build(kind,x,y,direction)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].name,position={x,y},direction=direction or 0,force='player'})
  local r=assert(lifecycle.build(body)); assert(not r.children.power and lifecycle.available(r)); return r
end
local function connect(a,b) assert(lifecycle.connector(a,'network','red').connect_to(lifecycle.connector(b,'network','red'))) end
local function settle()
  for _=1,200 do
    lifecycle.reconcile(game.tick,nop); monitor.reconcile(game.tick,nop); renderer.tick(game.tick,nop)
    local s=registry.get().monitors; local p=s.presentation
    if not s.job and p and #p.retired==0 and #p.orphans==0 and #p.jobs==0 and p.pending_cells==0 then return end
  end
  error('graphics fixture did not settle')
end
local function group(tile) return assert(monitor.resolve(tile)) end
local function run(c,text)
  local ctx=admission.context(admission.new(),c.id,0); local plan,e=compiler.compile('function start(e) '..text..' end',ctx); assert(plan,e and e.message)
  return compiler.run(plan,'start',{},function(g) return runtime.services(c,game.tick,g) end,ctx)
end
local function guest(c,text) local ok,why=run(c,text); assert(ok,serpent.line(why)) end
local function wrap(name) return "local m=peripheral.wrap("..string.format('%q',name)..",'red'); " end
local function near(a,b) return math.abs(a-b)<1e-9 end
local function MAP(text) return (text:gsub('.',function(c) local b=c:byte(); return string.char(0xEE,0x80+math.floor(b/64),0x80+b%64) end)) end
local function own_objects()
  local n=0; for _,o in pairs(rendering.get_all_objects()) do if o.valid then n=n+1 end end; return n
end
-- One fake geometry for pure bounds checks (2x2 tiles: 124x124 content pixels).
local square={width_tiles=2,height_tiles=2}
local function fits(kind,props) graphics.inside(square,kind,graphics.validate(kind,props)); return true end
local function outside(kind,props) error_is('E_RANGE',fits,kind,props) end
local function bounds_contract()
  local W=124
  outside('line',{from={10,10},to={W+5,10},color={1,1,1}})
  assert(fits('line',{from={1,1},to={W-1,1},color={1,1,1}})) -- width 2 covers 0..124 exactly
  outside('line',{from={0.5,1},to={W-1,1},color={1,1,1}})
  assert(fits('rectangle',{left_top={0,0},right_bottom={W,W},color={1,1,1},filled=true}))
  outside('rectangle',{left_top={0,0},right_bottom={W,W},color={1,1,1}}) -- outline extends width/2
  assert(fits('rectangle',{left_top={4,4},right_bottom={W-4,W-4},color={1,1,1},width=8}))
  error_is('E_RANGE',fits,'rectangle',{left_top={10,10},right_bottom={5,20},color={1,1,1}})
  assert(fits('circle',{target={62,62},radius=61,color={1,1,1}}))
  outside('circle',{target={62,62},radius=62,color={1,1,1}})
  assert(fits('circle',{target={62,62},radius=62,color={1,1,1},filled=true}))
  assert(fits('light',{target={62,62},radius=40}))
  outside('light',{target={20,62},radius=40})
  assert(fits('polygon',{vertices={{0,0},{W,0},{0,W}},color={1,1,1}}))
  outside('polygon',{vertices={{0,0},{W+0.001,0},{0,W}},color={1,1,1}})
  -- Arc near an edge: the right half-annulus fits although the full circle would not.
  assert(fits('arc',{target={2,62},min_radius=0,max_radius=60,start_angle=-math.pi/2,angle=math.pi,color={1,1,1}}))
  outside('arc',{target={2,62},min_radius=0,max_radius=60,start_angle=math.pi/2,angle=math.pi,color={1,1,1}})
  assert(fits('arc',{target={62,62},min_radius=50,max_radius=60,start_angle=0.1,angle=0.2,color={1,1,1}}))
  -- Text exact fit: ten bytes at scale 2 cover exactly 120 pixels.
  assert(fits('text',{text='0123456789',target={4,0},color={1,1,1},scale=2}))
  outside('text',{text='0123456789',target={4.5,0},color={1,1,1},scale=2})
  assert(fits('text',{text='0123456789',target={W,0},color={1,1,1},scale=2,alignment='right'}))
  assert(fits('text',{text='ABC',target={62,62},color={1,1,1},alignment='center',vertical_alignment='middle',orientation=0.25}))
  -- Rotated text: 10 bytes at scale 2 standing on the left edge after a quarter turn.
  assert(fits('text',{text='0123456789',target={18,2},color={1,1,1},scale=2,orientation=0.25}))
  outside('text',{text='0123456789',target={17,2},color={1,1,1},scale=2,orientation=0.25})
  -- Rotated sprite: a 64-pixel icon turned 1/8 needs 64*sqrt(2) pixels.
  assert(fits('sprite',{sprite='item/iron-plate',target={62,62},x_scale=1.9,y_scale=1}))
  outside('sprite',{sprite='item/iron-plate',target={62,62},x_scale=1.9,y_scale=1.9,orientation=0.125})
  assert(fits('sprite',{sprite='item/iron-plate',target={62,62},orientation=0.125}))
  -- Validation shapes and domains.
  error_is('E_ARGUMENT',fits,'line',{from={1,1},to={2,2},color={1,1,1},time_to_live=60})
  error_is('E_ARGUMENT',fits,'line',{from={1,1},to={2,2},color={1,1,1},players={1}})
  error_is('E_RANGE',fits,'line',{from={1,1},to={2,2},color={255,0,0}})
  error_is('E_ARGUMENT',fits,'line',{from={1,1},to={2,2},color=16384})
  error_is('E_ARGUMENT',fits,'line',{from={1,1},to={2,2}})
  error_is('E_RANGE',fits,'sprite',{sprite='file/__base__/graphics/icons/iron-plate.png',target={62,62}})
  error_is('E_RANGE',fits,'sprite',{sprite='utility/danger_icon',target={62,62}})
  error_is('E_RANGE',fits,'sprite',{sprite='item/no-such-item',target={62,62}})
  error_is('E_RANGE',fits,'text',{text='x',target={1,1},color={1,1,1},scale=0.75})
  error_is('E_ARGUMENT',fits,'polygon',{vertices={{0,0},{1,1}},color={1,1,1}})
  local p=graphics.validate('line',{from={x=1,y=2},to={3,4},color={r=1,g=0.5,b=0}})
  assert(p.from.x==1 and p.to.y==4 and p.color.a==1 and p.width==2 and p.visible and p.blink_interval==0)
  report('bounds-exact-fit-rotation-arc-sector-validation')
end
function M.run()
  storage.tc_graphics={groups=0,phase='armed'}
  registry.initialize(); bounds_contract()
  local c=build('computer',-3,0)
  -- 2x2 north wall, an east-facing 2x1 wall and two single terminal monitors for synchronization.
  local sq={build('monitor',0,0),build('monitor',1,0),build('monitor',0,1),build('monitor',1,1)}
  local east={build('monitor',3,0,4),build('monitor',3,1,4)}
  local a,b=build('monitor',6,0),build('monitor',8,0)
  settle(); connect(c,sq[1]); connect(sq[1],east[1]); connect(east[1],a); connect(a,b)
  c.status='running'; c.run_id=c.id..'/fixture'; c.active={source='function start(e) end',revision=1,api_version=1,
    compiler_version=limits.compiler_version,storage_version=limits.storage_version,handlers={start=true}}
  local g=group(sq[1]); local name=g.id; local m=wrap(name)
  -- Mode switching (task 2.1).
  guest(c,m.."m.write('TEXT'); assert(m.getMode()=='terminal'); local w,h=m.getSize(); assert(w==20 and h==13)")
  local ms=registry.get().monitors; ms.resizes={}; ms.resize_order={}
  guest(c,m.."m.setMode('graphics'); assert(m.getMode()=='graphics'); local w,h=m.getSize(); assert(w==124 and h==124)")
  for y=1,g.model.height do assert(g.model.rows[y][1]==string.rep(' ',g.model.width),'mode switch kept terminal text') end
  local resize=ms.resizes[g.id].payload
  assert(resize.reason=='mode' and resize.mode=='graphics' and resize.old_width==20 and resize.old_height==13 and resize.width==124 and resize.height==124)
  guest(c,m..[==[
    for _,call in ipairs({{'write','x'},{'setTextScale',2},{'getCursorPos'},{'blit','a','0','f'},{'setPaletteColor',colors.white,0x123456},{'getTextScale'},{'scroll',1},{'clearLine'}}) do
      local ok,e=pcall(m[call[1]],table.unpack(call,2)); assert(not ok and e.code=='E_UNSUPPORTED',call[1])
    end
    assert(m.isColor() and m.getLimits().render_object_limit>0); m.clear()
    local ok,e=pcall(m.setMode,'pixels'); assert(not ok and e.code=='E_RANGE')
    ok,e=pcall(m.setMode,1); assert(not ok and e.code=='E_ARGUMENT')
    local id=m.drawLine{from={10,10},to={100,40},color={1,0,0}}; assert(id==1)
  ]==])
  ms.resizes={}; ms.resize_order={}
  guest(c,m.."m.setMode('graphics'); local ids=m.getObjects(); assert(#ids==1 and ids[1]==1)")
  assert(next(ms.resizes)==nil,'same mode queued a resize')
  guest(c,m.."m.setMode('terminal'); local ok,e=pcall(m.drawLine,{from={1,1},to={2,2},color={1,1,1}}); assert(not ok and e.code=='E_UNSUPPORTED'); ok,e=pcall(m.getObjects); assert(not ok and e.code=='E_UNSUPPORTED')")
  assert(graphics.object_count(g)==0 and ms.resizes[g.id].payload.old_width==124 and ms.resizes[g.id].payload.width==20)
  guest(c,m.."m.setMode('graphics')")
  report('mode-switch-clear-same-mode-ranges-and-dispatch')
  -- Objects (task 3.2): stored props, native projection, order, ids, read-back copies.
  guest(c,m..[==[
    local ids={}
    ids.rect=m.drawRectangle{left_top={0,0},right_bottom={60,40},color={0,0,1},filled=true}
    ids.sprite=m.drawSprite{sprite='item/iron-plate',target={40,40}}
    ids.line=m.drawLine{from={2,2},to={100,40},color={1,1,1},width=4}
    ids.text=m.drawText{text='[item=iron-plate]',target={0,100},color={1,1,0}}
    ids.circle=m.drawCircle{target={90,90},radius=20,color={0,1,0},filled=false,width=2}
    ids.arc=m.drawArc{target={62,62},min_radius=10,max_radius=20,start_angle=0,angle=math.pi,color={1,0,1}}
    ids.poly=m.drawPolygon{vertices={{70,10},{90,10},{70,30},{90,30}},color={0,1,1}}
    ids.light=m.drawLight{target={62,62},radius=40}
    local order=m.getObjects(); assert(order[1]==ids.sprite and order[2]==ids.light and order[3]==ids.rect,'sprites and lights list first')
    m.moveToBack(ids.poly); order=m.getObjects(); assert(order[3]==ids.poly)
    m.bringToFront(ids.rect); order=m.getObjects(); assert(order[#order]==ids.rect)
    local ok,e=pcall(m.bringToFront,ids.sprite); assert(not ok and e.code=='E_UNSUPPORTED')
    ok,e=pcall(m.destroy,999); assert(not ok and e.code=='E_NOT_FOUND'); assert(m.get(999)==nil)
    ok,e=pcall(m.set,999,{}); assert(not ok and e.code=='E_NOT_FOUND')
    local copy=m.get(ids.circle); assert(copy.type=='circle' and copy.radius==20 and copy.target.x==90 and copy.color.a==1)
    copy.radius=1; assert(m.get(ids.circle).radius==20)
    ok,e=pcall(m.set,ids.rect,{right_bottom={130,40}}); assert(not ok and e.code=='E_RANGE'); assert(m.get(ids.rect).right_bottom.x==60)
    ok,e=pcall(m.drawCircle,{target={62,62},radius=5,color={1,1,1},time_to_live=60}); assert(not ok and e.code=='E_ARGUMENT')
    computer.setState('ids',ids)
  ]==])
  local ids=c.state.ids; local s=g.graphics
  local line=s.objects[ids.line].native; local wx,wy=model.world(g,(2+100)/64,(2+40)/64)
  assert(line.type=='line' and near(line.to.position.x,wx) and near(line.to.position.y,wy) and line.width==2)
  local text=s.objects[ids.text].native
  assert(text.font=='tc-term' and not text.use_rich_text and text.text==MAP('[item=iron-plate]'),'graphics text reached the rich-text parser')
  local sprite=s.objects[ids.sprite].native; assert(sprite.type=='sprite' and sprite.render_layer=='higher-object-above')
  local light=s.objects[ids.light].native; assert(math.abs(light.scale-40/64/4.25)<1e-6)
  -- Animate: the same native object moves; nothing else is created.
  local before=own_objects()
  guest(c,m.."m.set(computer.getState('ids').line,{to={100,60}})")
  local ty=select(2,model.world(g,(2+100)/64,(2+60)/64)); assert(s.objects[ids.line].native==line and near(line.to.position.y,ty) and own_objects()==before)
  -- Text/colour-only set writes those native properties alone; other changes still rebuild the projection.
  local tx,ty0=text.target.position.x,text.target.position.y
  guest(c,m.."local id=computer.getState('ids').text; m.set(id,{text='AB'}); m.set(id,{color={0,1,0}})")
  local tc=text.color
  assert(s.objects[ids.text].native==text and text.text==MAP('AB') and s.objects[ids.text].props.text=='AB' and own_objects()==before)
  assert(near(text.target.position.x,tx) and near(text.target.position.y,ty0) and tc.r==0 and tc.g==1 and tc.b==0 and tc.a==1)
  guest(c,m..[==[
    local id=computer.getState('ids').text
    local ok,e=pcall(m.set,id,{text=string.rep('W',40)}); assert(not ok and e.code=='E_RANGE'); assert(m.get(id).text=='AB')
    local centred=m.drawText{text='ABCD',target={62,0},color={1,1,1},alignment='center'}; computer.setState('centred',centred)
  ]==])
  assert(text.text==MAP('AB'),'refused text reached the native object')
  local centred=s.objects[c.state.centred].native; local cx=centred.target.position.x
  guest(c,m.."m.set(computer.getState('centred'),{text='AB'})")
  assert(centred.text==MAP('AB') and centred.target.position.x>cx,'centred text kept its old anchor')
  before=own_objects()
  -- A later failure keeps every earlier successful call of the same callback.
  local ok=run(c,m.."for i=1,20 do m.set(computer.getState('ids').line,{from={2,2+i}}) end; error('fixture failure after twenty moves')")
  assert(not ok and s.objects[ids.line].props.from.y==22 and near(line.from.position.y,select(2,model.world(g,(2+2)/64,(2+22)/64))))
  -- Ids are never reused after clear.
  guest(c,m.."local old=m.getObjects(); local top=0; for _,id in ipairs(old) do top=math.max(top,id) end; m.clear(); assert(#m.getObjects()==0 and m.get(old[1])==nil); assert(m.drawLine{from={1,1},to={9,9},color={1,1,1}}>top)")
  assert(not line.valid,'clear left a native object')
  -- Large polygon refused before any native object.
  before=own_objects()
  guest(c,m.."local v={}; for i=1,1500 do v[i]={i%120,(i*7)%120} end; local ok,e=pcall(m.drawPolygon,{vertices=v,color={1,1,1}}); assert(not ok and e.code=='E_LIMIT')")
  assert(own_objects()==before)
  report('objects-native-projection-order-ids-readback-same-tick-failure-and-limit')
  -- Capacity (task 3.3): only the fixture's view of the limit is lowered.
  local real=graphics.limit; local root=registry.get().monitors
  local cap=root.native_objects+2; graphics.limit=function() return cap end
  guest(c,m.."local a=m.drawLine{from={1,1},to={9,9},color={1,1,1}}; local b=m.drawLine{from={1,1},to={9,9},color={1,1,1}}; computer.setState('cap',a)")
  local count,objects=graphics.object_count(g),own_objects()
  guest(c,m.."local ok,e=pcall(m.drawLine,{from={1,1},to={9,9},color={1,1,1}}); assert(not ok and e.code=='E_CAPACITY')")
  assert(graphics.object_count(g)==count and own_objects()==objects)
  guest(c,m.."m.destroy(computer.getState('cap')); m.drawLine{from={1,1},to={9,9},color={1,1,1}}")
  -- A terminal commit defers instead of exceeding the shared limit.
  local ga=group(a); local front=ga.render; local presented=front.presented_revision
  guest(c,wrap(ga.id).."m.setCursorPos(1,1); m.write('DEFER')")
  graphics.limit=function() return root.native_objects end
  for _=1,3 do renderer.tick(game.tick,nop) end
  assert(ga.render==front and front.presented_revision==presented,'terminal commit exceeded the object limit')
  graphics.limit=real; settle(); assert(ga.render.presented_revision==ga.model.revision)
  report('capacity-refusal-unchanged-recovery-and-terminal-deferral')
  -- Touch and resize on a rotated non-square graphics display (task 2.2).
  local ge=group(east[1]); assert(ge.width_tiles==2 and ge.height_tiles==1 and ge.direction==4)
  guest(c,wrap(ge.id).."m.setMode('graphics'); local w,h=m.getSize(); assert(w==124 and h==60); m.drawLine{from={1,1},to={123,1},color={1,1,1}}")
  settle()
  local px,py=model.world(ge,2/64+1.5,2/64+0.25)
  local player={valid=true,index=1,force=east[1].body.force,surface=east[1].body.surface,cursor_stack={valid_for_read=false},
    can_reach_entity=function() return true end,print=nop}
  ms.touches={}
  assert(monitor.activate_for_player({input_name='tc-interact',tick=game.tick,cursor_position={x=px,y=py}},player))
  local touch=ms.touches[1].payload; assert(touch.mode=='graphics' and touch.x==96 and touch.y==16,serpent.line(touch))
  local bx,by=model.world(ge,1/64,1/64); assert(not monitor.activate_for_player({input_name='tc-interact',tick=game.tick,cursor_position={x=bx,y=by}},player),'bezel touch')
  ms.touches={}
  local ga_line=ge.graphics.objects[next(ge.graphics.objects)].native
  ms.resizes={}; ms.resize_order={}
  local added=build('monitor',3,2,4); settle()
  local grown=group(east[1]); assert(grown.model.mode=='graphics' and grown.width_tiles==3 and graphics.object_count(grown)==0 and not ga_line.valid)
  local payload=ms.resizes[grown.id].payload
  assert(payload.reason=='tiles' and payload.mode=='graphics' and payload.old_width==124 and payload.old_height==60 and payload.width==188 and payload.height==60)
  -- Split of a graphics wall keeps graphics mode.
  lifecycle.remove(added.id,'fixture',true); settle(); assert(group(east[1]).model.mode=='graphics')
  report('rotated-pixel-touch-bezel-and-tile-resize-clears-in-pixels')
  -- Synchronization groups (task 2.3).
  guest(c,"peripheral.setMonitorSyncGroup({{name="..string.format('%q',group(a).id)..",wire='red'},{name="..string.format('%q',group(b).id)..",wire='red'}})")
  assert(#c.monitor_sync.members==2)
  guest(c,wrap(group(b).id).."m.setMode('graphics')")
  assert(#c.monitor_sync.members==1 and c.monitor_sync.members[1].name==group(a).id,'graphics member stayed selected')
  local lane=registry.get().monitors.presentation.lanes[c.monitor_sync.key]; local sequence=lane.presented_sequence
  guest(c,wrap(group(a).id).."m.setCursorPos(1,1); m.write('ROUND')"); settle()
  assert(lane.presented_sequence>sequence,'remaining member stopped publishing')
  guest(c,"local ok,e=pcall(peripheral.setMonitorSyncGroup,{{name="..string.format('%q',group(a).id)..",wire='red'},{name="..string.format('%q',group(b).id)..",wire='red'}}); assert(not ok and e.code=='E_UNSUPPORTED')")
  assert(#c.monitor_sync.members==1 and c.monitor_sync.members[1].name==group(a).id,'refusal changed the selection')
  guest(c,"peripheral.setMonitorSyncGroup({})")
  report('sync-group-refuses-and-releases-graphics-members')
  -- Settings transfer (task 4.1): paste graphics onto terminal, v1 import, blueprint record.
  local pasted=snapshots.settings(b); assert(pasted.monitor.version==2 and pasted.monitor.mode=='graphics')
  guest(c,wrap(group(a).id).."m.setCursorPos(1,1); m.write('PASTE')")
  ms.resizes={}; ms.resize_order={}
  snapshots.apply_settings(a,pasted); local gp=group(a)
  assert(gp.model.mode=='graphics' and gp.model.rows[1][1]==string.rep(' ',gp.model.width))
  assert(ms.resizes[gp.id].payload.reason=='mode' and #ms.resize_order==1)
  local v1=snapshots.import_monitor{version=1,scale=1,fg=0,bg=15,blink=false,palette=pasted.monitor.palette}; assert(v1.mode=='terminal')
  local record=snapshots.monitor_snapshot(a); assert(record.version==2 and record.mode=='graphics')
  local item=build('monitor',17,8); snapshots.restore_monitor(item,record)
  monitor.reconcile(game.tick,nop); settle(); assert(group(item).model.mode=='graphics','blueprint record lost the mode')
  report('settings-v2-paste-v1-import-and-blueprint-record')
  -- Inspection (task 5.1): 2x2 graphics display with 12 objects.
  guest(c,m.."m.clear(); for i=1,12 do m.drawLine{from={1,i},to={9,i},color={1,1,1}} end")
  local info=monitor.inspect(sq[1],game.tick,nop)
  assert(info.mode=='graphics' and info.pixel_width==124 and info.pixel_height==124 and info.objects==12 and not info.columns)
  report('inspector-mode-pixels-objects')
  -- Cold fixture (task 4.2): 500 objects of every type on a 6x6 graphics wall.
  local wall={}
  for y=0,5 do for x=0,5 do wall[#wall+1]=build('monitor',10+x,y) end end
  settle(); connect(b,wall[1]); local gw=group(wall[1]); assert(#gw.members==36)
  guest(c,wrap(gw.id)..[==[m.setMode('graphics')
    local kinds={
      function(i) return m.drawLine{from={2+i%370,2},to={2+(i*3)%370,300},color={1,i%2,0},width=1+i%3} end,
      function(i) return m.drawRectangle{left_top={1+i%300,1+i%200},right_bottom={21+i%300,11+i%200},color={0,0,1,0.5},filled=i%2==0} end,
      function(i) return m.drawCircle{target={50+i%200,50+i%200},radius=10,color={0,1,0},filled=true} end,
      function(i) return m.drawArc{target={190,190},min_radius=5,max_radius=50,start_angle=i/10,angle=1,color={1,0,1}} end,
      function(i) return m.drawPolygon{vertices={{i%300,10},{i%300+20,10},{i%300,30}},color={0,1,1}} end,
      function(i) return m.drawText{text='T'..i,target={10,i%300},color={1,1,1},scale=1+i%2} end,
      function(i) return m.drawSprite{sprite='item/iron-plate',target={100+i%150,100},x_scale=0.5,y_scale=0.5} end,
      function(i) return m.drawLight{target={190,190},radius=30+i%20} end}
    for i=1,500 do kinds[i%8+1](i) end
    m.moveToBack(m.getObjects()[300])]==])
  local saved={ids=nil,props={},next_id=gw.graphics.next_id,objects=own_objects()}
  local list={}; for _,id in ipairs(gw.graphics.under) do list[#list+1]=id end; for _,id in ipairs(gw.graphics.over) do list[#list+1]=id end
  saved.ids=list; for _,id in ipairs(list) do saved.props[id]=helpers.table_to_json(gw.graphics.objects[id].props) end
  assert(#list==500)
  f().cold={computer=c.id,tile=wall[1].id,group=gw.id,saved=saved,tiles={}}
  for _,t in ipairs(wall) do f().cold.tiles[#f().cold.tiles+1]=t.id end
  log('TC_GRAPHICS_TOTAL '..f().groups)
end
function M.on_load() loaded=true end
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  if x.phase=='armed' then x.phase='frozen'; loaded=false; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return end
  if not loaded then return end
  local cold=x.cold; local c=registry.computer(cold.computer); local tile=registry.record(cold.tile)
  local g=group(tile); local s=g.graphics; local saved=cold.saved
  assert(g.id==cold.group and g.model.mode=='graphics' and s.next_id==saved.next_id)
  local list={}; for _,id in ipairs(s.under) do list[#list+1]=id end; for _,id in ipairs(s.over) do list[#list+1]=id end
  assert(#list==#saved.ids); for i,id in ipairs(list) do assert(id==saved.ids[i] and helpers.table_to_json(s.objects[id].props)==saved.props[id]) end
  for _,o in pairs(s.objects) do assert(o.native.valid and o.native.visible) end
  -- Hide-while-marked: objects hide, ids and props stay; cancel restores.
  local marked=registry.record(cold.tiles[8])
  -- This fixture's state lives in the smoke companion, so it delivers the event itself;
  -- monitor_feedback_engine proves real event delivery in the production context.
  assert(marked.body.order_deconstruction('player')); renderer.marked{entity=marked.body}
  for _,o in pairs(s.objects) do assert(not o.native.visible,'graphics drew above a marked display') end
  marked.body.cancel_deconstruction('player'); renderer.marked{entity=marked.body}
  for _,o in pairs(s.objects) do assert(o.native.visible) end
  c.status='running'
  guest(c,wrap(g.id).."assert(m.drawLine{from={1,1},to={2,2},color={1,1,1}}=="..saved.next_id..")")
  -- Removing the display destroys every object.
  local natives={}; for _,o in pairs(s.objects) do natives[#natives+1]=o.native end
  for _,id in ipairs(cold.tiles) do lifecycle.remove(id,'fixture',true) end; settle()
  for _,o in ipairs(natives) do assert(not o.valid,'removed display kept a graphics object') end
  x.phase='done'; log('TC_GRAPHICS_COLD_OK objects=500'); log('TC_COLD_OK')
end
return M
