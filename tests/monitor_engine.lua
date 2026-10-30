-- Focused deterministic contracts and actual 2.0.77 render-object/cold evidence.
-- No player exists in a headless create; activation player objects below are mocks.
local registry=require('scripts.registry')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local lifecycle=require('scripts.lifecycle')
local peripheral=require('scripts.services.peripheral')
local compiler=require('scripts.runtime.compiler')
local admission=require('scripts.runtime.admission')
local limits=require('scripts.runtime.limits')
local defs=require('scripts.device-definitions')
local model=require('scripts.monitor-model')
local snapshots=require('scripts.lifecycle-data')
local monitor=require('scripts.services.monitor')
local interaction=require('scripts.ui.interaction')
local editor_contract=require('tests.editor_contract')
local renderer=require('scripts.rendering')
local example_source=require('examples.monitor-program')
local M={}; local loaded=false
local function nop() end
local function f() return storage.tc09_fixture end
local function report(s) f().groups=f().groups+1; log('TC_CONTRACT '..s) end
local function error_is(code,fn)
  local ok,e=pcall(fn); assert(not ok and type(e)=='table' and e.code==code,'expected '..code..', got '..serpent.line(e))
end
local function value_equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not value_equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end; return true
end
local function copy(t) if type(t)~='table' then return t end; local r={}; for k,v in pairs(t) do r[k]=copy(v) end; return r end
local function atomic(m,code,fn) local old=copy(m); error_is(code,fn); assert(value_equal(old,m),'rejected terminal call mutated state') end
local function build(kind,x,y,direction,force)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].name,position={x,y},direction=direction or 0,force=force or 'player'})
  local r=assert(lifecycle.build(body)); assert(not r.children.power and lifecycle.available(r)); return r
end
local function connect(a,b,wire) assert(lifecycle.connector(a,'network',wire).connect_to(lifecycle.connector(b,'network',wire))) end
local function settle()
  for _=1,200 do
    monitor.reconcile(game.tick,nop); renderer.tick(game.tick,nop)
    local s=registry.get().monitors; local p=s.presentation
    if not s.job and p and #p.retired==0 and #p.orphans==0 and #p.jobs==0 and p.pending_cells==0 then return end
  end
  error('group lifecycle failed to settle')
end
local function group(tile) return assert(monitor.resolve(tile)) end
local function guest(c,text)
  local source='function start(e) '..text..' end'
  local ctx=admission.context(admission.new(),c.id,0); local plan,e=compiler.compile(source,ctx); assert(plan,e and e.message)
  local ok,diagnostic=compiler.run(plan,'start',{},function(g) return runtime.services(c,game.tick,g) end,ctx)
  assert(ok,serpent.line(diagnostic))
end
local source=[[function start(e)
  computer.setState('boots',(computer.getState('boots') or 0)+1)
  computer.on('monitor_resize','resized'); computer.on('monitor_touch','touched')
  local m=peripheral.find('monitor','red'); assert(m)
  computer.setState('monitor',peripheral.getName(m)); m.setCursorPos(1,1); m.write('COLD')
end

function resized(e)
  local m=peripheral.wrap(e.peripheral,e.wire); local w,h=m.getSize()
  assert(w==e.width and h==e.height); computer.setState('resize',e)
end

function touched(e) computer.setState('touch',e) end

function check(e)
  local m=peripheral.wrap(computer.getState('monitor'),'red'); assert(m)
  m.setCursorPos(1,2); m.write('RESUMED'); computer.setState('checked',true)
end]]
function M.run()
  registry.initialize(); storage.tc09_fixture={groups=0,phase='armed'}
  local m=model.new(1,1); local called={}
  local function call(name,...) called[name]=true; return model.calls[name](m,nop,...) end
  assert(call('getSize')==10); local w,h=call('getSize'); assert(w==10 and h==6)
  assert(call('getCursorBlink')==false and call('isColor') and call('isColour'))
  assert(call('getTextColor')==1 and call('getBackgroundColor')==32768 and call('getTextScale')==1)
  local x,y=call('getCursorPos'); assert(x==1 and y==1)
  call('setCursorPos',-2,1); call('write','abcdef'); assert(m.x==4 and m.cells[1][1]==100 and m.cells[3][1]==102)
  call('setCursorBlink',true); call('setTextColour',8192); assert(call('getTextColour')==8192)
  call('setBackgroundColour',2); assert(call('getBackgroundColour')==2)
  call('setTextColor',1); call('setBackgroundColor',32768); call('clear'); call('setCursorPos',1,1)
  call('blit','[font=x]', '01234567','fedcba98'); assert(m.cells[1][1]==91 and m.cells[8][3]==8)
  atomic(m,'E_ARGUMENT',function() call('blit','abc','01','123') end)
  atomic(m,'E_ARGUMENT',function() call('blit','ab','0F','00') end)
  atomic(m,'E_RANGE',function() call('setTextColor',3) end)
  atomic(m,'E_ARGUMENT',function() call('setCursorBlink',1) end)
  atomic(m,'E_RANGE',function() call('setCursorPos',1.1,1) end)
  atomic(m,'E_ARGUMENT',function() call('setCursorPos','1',1) end)
  call('setCursorPos',9007199254740991,1)
  atomic(m,'E_RANGE',function() call('write','a') end)
  call('setCursorPos',0,0); call('write','\0\n'); assert(m.x==2)
  call('setCursorPos',1,2); call('write','ROW2'); call('scroll',1); assert(m.cells[1][1]==82)
  call('scroll',-1); assert(m.cells[1][1]==32 and m.cells[11][1]==82)
  call('scroll',9007199254740991); for _,c in ipairs(m.cells) do assert(c[1]==32) end
  call('setCursorPos',1,1); call('write','X'); call('clearLine'); assert(m.cells[1][1]==32)
  call('setPaletteColor',1,0x123456); local r,g,b=call('getPaletteColour',1)
  assert(r==0x12/255 and g==0x34/255 and b==0x56/255)
  call('setPaletteColour',2,0.2,0.3,0.4); r,g,b=call('getPaletteColor',2); assert(r==0.2 and g==0.3 and b==0.4)
  atomic(m,'E_RANGE',function() call('setPaletteColor',1,0/0,0,0) end)
  atomic(m,'E_ARGUMENT',function() call('setPaletteColor',1,1,0) end)
  for name in pairs(model.calls) do assert(called[name],'method omitted from contract: '..name) end
  report('all-terminal-methods-aliases-clipping-scroll-and-rejection-atomicity')
  for i=1,10 do
    model.scale(m,4,4,nop,i/2); w,h=model.size(4,4,i/2); assert(m.width==w and m.height==h)
    assert(m.x==2 and m.y==1 and m.blink and m.palette[1][1]==0x12/255)
  end
  atomic(m,'E_RANGE',function() model.scale(m,1,1,nop,1.1) end)
  atomic(m,'E_BUSY',function() model.calls.clear(m,function() error({code='E_BUSY'},0) end) end)
  model.scale(m,6,6,nop,0.5); assert(m.width*m.height==model.limits.cells)
  local spent=0
  model.calls.blit(m,function(n) spent=spent+n; assert(spent<=limits.callback_work) end,
    string.rep('x',model.limits.write_bytes),string.rep('0',model.limits.write_bytes),string.rep('f',model.limits.write_bytes))
  report('all-scales-maximum-cells-and-admission-before-model-mutation')
  local fake={}; for y=1,3 do for x=1,3 do if x~=2 or y~=2 then fake[#fake+1]={id=x..'-'..y,position={x=x,y=y},direction=0,force_index=1,surface_index=1} end end end
  local partition=monitor.partition(fake); local seen={}; local area=0
  for _,rect in ipairs(partition) do area=area+rect.world_width*rect.world_height; for _,id in ipairs(rect.members) do assert(not seen[id]); seen[id]=true end end
  assert(area==8 and #partition==4); assert(value_equal(partition,monitor.partition(fake)))
  local row={}; for x=1,7 do row[x]={id='a'..x,position={x=x,y=0},direction=0,force_index=1,surface_index=1} end
  partition=monitor.partition(row); assert(#partition==2 and partition[1].world_width==6)
  report('deterministic-hole-l-shape-and-oversized-partition')
  for _,d in ipairs({0,4,8,12}) do
    local g0={left=10,top=20,world_width=2,world_height=1,direction=d,
      width_tiles=(d==4 or d==12) and 1 or 2,height_tiles=(d==4 or d==12) and 2 or 1}
    g0.model=model.new(g0.width_tiles,g0.height_tiles)
    local cw,ch,ox,oy=model.geometry(g0)
    for _,cell in ipairs({{1,1},{g0.model.width,g0.model.height}}) do
      local wx,wy=model.world(g0,ox+(cell[1]-0.5)*cw,oy+(cell[2]-0.5)*ch)
      local cx,cy=model.touch(g0,wx,wy); assert(cx==cell[1] and cy==cell[2])
    end
    local wx,wy=model.world(g0,0,0); assert(not model.touch(g0,wx,wy))
    wx,wy=model.world(g0,ox+g0.model.width*cw,oy+ch/2); assert(not model.touch(g0,wx,wy))
  end
  report('shared-world-transform-cardinal-corners-and-border-rejection')
  local c=build('computer',-2,0); local a=build('monitor',0,0); local b0=build('monitor',1,0)
  settle(); local display=group(a); assert(group(b0)==display and #display.members==2)
  connect(c,b0,'red'); connect(c,a,'green')
  c.status='running'; c.run_id=c.id..'/fixture'; c.active={source='',api_version=1,
    compiler_version=limits.compiler_version,storage_version=limits.storage_version,handlers={start=true}}
  guest(c,"local m=peripheral.find('monitor','red'); assert(m); local w,h=m.getSize(); assert(w==20 and h==6); m.write('NATIVE'); local limits=m.getLimits(); limits.cells=0; assert(m.getLimits().cells==10584); local p=m.getPaletteColour(colors.white); assert(p>0)")
  assert(display.model.cells[1][1]==78)
  local before=copy(display.model)
  guest(c,"local m=peripheral.find('monitor','red'); local ok,e=pcall(m.blit,'x','F','0'); assert(not ok and e.code=='E_ARGUMENT'); ok,e=pcall(m.setCursorPos,{},1); assert(not ok and e.code=='E_ARGUMENT'); local size=m.getLimits(); size.cells=1; assert(m.getLimits().cells==10584); assert(type(m.getPaletteColor(colors.white))=='number')")
  assert(value_equal(before,display.model))
  local hidden=build('kv',2,0); connect(b0,hidden,'green')
  assert(not peripheral.inventory(c,'red',nop)[hidden.id],'geometric group bridged wires')
  lifecycle.remove(hidden.id,'fixture',true)
  local original=display.id; model.calls.setCursorPos(display.model,nop,99,-2); model.calls.setCursorBlink(display.model,nop,true)
  local below=build('monitor',0,1); settle(); assert(group(a).id==original)
  local second=group(below); assert(second~=group(a))
  local corner=build('monitor',1,1); settle(); display=group(a)
  assert(#display.members==4 and display.id==original and display.model.x==99 and display.model.y==-2 and display.model.blink)
  error_is('E_UNREACHABLE',function() peripheral.services(c,game.tick,{spend=nop,check=nop,service=function(fn) return fn end,namespace=function(t) return t end,accept_handle=nop}).peripheral.call(second.id,'red','getSize') end)
  lifecycle.remove(a.id,'fixture',true); settle(); assert(group(b0).id~=original,'removed anchor identity retargeted')
  lifecycle.remove(below.id,'fixture',true); lifecycle.remove(corner.id,'fixture',true); settle()
  display=group(b0); f().c=c.id; f().tile=b0.id; f().display=display.id
  report('real-physical-group-merge-split-anchor-retirement-and-no-wire-bridge')
  for _,d in ipairs({4,8,12,0}) do
    local old=b0.body.direction; b0.body.direction=d; assert(lifecycle.rotate(b0,old)); settle()
    assert(group(b0).id==f().display and group(b0).direction==d)
  end
  report('native-owned-tile-rotation-retains-anchor-identity')
  display=group(b0); model.calls.setCursorPos(display.model,nop,1,1)
  model.calls.setPaletteColor(display.model,nop,1,0xABCDEF); model.calls.write(display.model,nop,'PALETTE')
  renderer.participate(display); renderer.tick(game.tick,nop); assert(display.render.presented_revision==display.model.revision)
  local object=display.render.cells[1].glyph; assert(object and object.valid and object.sprite=='tc-glyph-80')
  assert(math.abs(object.color.r-0xAB/255)<0.01)
  model.calls.write(display.model,nop,'LATEST'); renderer.participate(display); renderer.tick(game.tick,nop)
  assert(display.render.presented_revision==display.model.revision)
  local root=registry.get(); root.scheduler.maintenance_tick=game.tick; root.scheduler.maintenance_spent=limits.maintenance_work_per_tick-60000
  assert(not scheduler.try_maintenance(function() scheduler.maintenance(root,game.tick)(1) end))
  model.calls.setCursorPos(display.model,nop,1,1); model.calls.write(display.model,nop,'PALETTE')
  renderer.participate(display); renderer.tick(game.tick,scheduler.maintenance(root,game.tick,true))
  assert(display.render.presented_revision==display.model.revision)
  root.scheduler.maintenance_spent=0 -- Isolated fixture, not a production clock reset.
  b0.powered=false; registry.monitor_changed(b0,false); monitor.reconcile(game.tick,nop); renderer.tick(game.tick,nop)
  assert(not display.render.hidden and object.visible and display.model.cells[1][1]==80)
  guest(c,"local m=peripheral.find('monitor','red'); assert(peripheral.describe(peripheral.getName(m),'red').powered); m.write('NOPOWER')")
  b0.powered=true; registry.monitor_changed(b0,false); monitor.reconcile(game.tick,nop); renderer.tick(game.tick,nop)
  assert(not display.render.hidden and object.visible and display.model.cells[1][1]==80)
  local retained_model=display.model
  b0.physical_error='fixture-owned-port-fault'
  registry.monitor_changed(b0,false)
  monitor.reconcile(game.tick,nop); renderer.tick(game.tick,nop)
  assert(group(b0)==display and display.model==retained_model and display.render.hidden)
  b0.physical_error=nil
  registry.monitor_changed(b0,false)
  monitor.reconcile(game.tick,nop); renderer.tick(game.tick,nop)
  assert(display.model==retained_model and not display.render.hidden)
  report('actual-world-glyph-objects-palette-dirty-revision-power-blank-and-restore')
  local pasted=snapshots.settings(b0); pasted.monitor.palette[1]={0.2,0.4,0.6}
  snapshots.apply_settings(b0,pasted)
  assert(display.model.damage_full,'settings paste failed to invalidate unchanged cells')
  renderer.tick(game.tick,nop)
  assert(math.abs(display.render.cells[1].glyph.color.r-0.2)<0.01,'pasted palette did not reach unchanged native glyph')
  report('settings-paste-palette-invalidates-sparse-native-front')
  local previous_active,previous_subscriptions=c.active,c.subscriptions
  local ctx=admission.context(admission.new(),c.id,0)
  local plan,e=compiler.compile(example_source,ctx); assert(plan,e and e.message)
  c.active={source=example_source,api_version=1,compiler_version=limits.compiler_version,
    storage_version=limits.storage_version,handlers=plan.handlers}; c.subscriptions={}
  local ok,diagnostic=compiler.run(plan,'start',{name='start'},function(g) return runtime.services(c,game.tick,g) end,ctx)
  assert(ok,serpent.line(diagnostic)); assert(display.model.cells[1][1]==82 and display.model.fg==5)
  c.active=previous_active; c.subscriptions=previous_subscriptions
  -- Authentic event subscriptions, physical red/green proofs and mocked headless
  -- player interaction. This is deliberately NOT native player/client evidence.
  c.active.handlers.touch=true; c.active.handlers.resize=true
  runtime.subscribe(c,'monitor_touch','touch',nil,nop); runtime.subscribe(c,'monitor_resize','resize',nil,nop)
  connect(c,b0,'green')
  local player={valid=true,index=1,force=b0.body.force,surface=b0.body.surface,cursor_stack={valid_for_read=false},
    can_reach_entity=function() return true end,print=nop}
  local engine_get_player=game.get_player -- Cannot substitute LuaGameScript fields.
  -- Touch mapping and event publication use actual authority; custom-input
  -- production player validation is exercised separately with an injected lookup.
  local cw,ch,ox,oy=model.geometry(display); local px,py=model.world(display,ox+cw/2,oy+ch/2)
  assert(monitor.activate_for_player({input_name='tc-interact',tick=game.tick,in_gui=false,cursor_position={x=px,y=py}},player))
  assert(not monitor.activate_for_player({input_name='tc-interact',tick=game.tick,in_gui=true,cursor_position={x=px,y=py}},player))
  local foreign={valid=true,index=2,force=game.create_force('tc09-foreign'),surface=b0.body.surface,cursor_stack={valid_for_read=false},can_reach_entity=function() return true end,print=nop}
  assert(not monitor.activate_for_player({input_name='tc-interact',tick=game.tick,in_gui=false,cursor_position={x=px,y=py}},foreign))
  local job=registry.get().monitors.touches[1]
  local original_game=game
  local world_player=editor_contract.player(3001,b0.body); world_player.cursor_stack={valid_for_read=false}
  local ok,err=pcall(function()
    game={get_player=function(index) assert(index==world_player.index); return world_player end,tick=original_game.tick}
    local event={input_name='tc-interact',player_index=world_player.index,tick=original_game.tick,cursor_position={x=px,y=py}}
    local before=#registry.get().monitors.touches
    world_player.selected=b0.body; assert(interaction.on_input(event))
    world_player.selected=nil; assert(interaction.on_input(event),'position-based monitor touch must work without a selected tile')
    assert(#registry.get().monitors.touches==before+2 and not world_player.opened and #world_player.gui.screen.children==0)
    world_player.cursor_ghost='tc-computer'; assert(not interaction.on_input(event)); world_player.cursor_ghost=nil
    assert(#registry.get().monitors.touches==before+2)
  end)
  game=original_game; if not ok then error(err,0) end
  monitor.deliver(job,display,c,game.tick,nop,player)
  assert(#c.queue==1 and c.queue[1].event.x==1 and #c.queue[1].event.wires==2 and c.queue[1].event.wire=='red')
  registry.get().monitors.touches={}; c.queue={}; c.queue_bytes=0
  guest(c,"local m=peripheral.find('monitor','red'); m.setTextScale(2)")
  monitor.notifications(game.tick,nop); assert(#c.queue==1 and c.queue[1].event.reason=='scale')
  guest(c,"local m=peripheral.find('monitor','red'); m.setTextScale(3)")
  monitor.notifications(game.tick,nop)
  assert(#c.queue==1 and c.queue[1].event.width==display.model.width and c.queue[1].event.height==display.model.height)
  guest(c,"local m=peripheral.find('monitor','red'); m.setTextScale(2)"); monitor.notifications(game.tick,nop)
  c.queue={}; c.queue_bytes=0
  report('mock-world-activation-with-authentic-deduplicated-channel-events-and-resize')
  -- Maximum physical rectangle, all 256 literal byte slots, mixed-revision sweep.
  local maximum={}
  for y=0,5 do for x=0,5 do maximum[#maximum+1]=build('monitor',10+x,10+y) end end
  settle(); local maxg=group(maximum[1]); assert(#maxg.members==36)
  model.scale(maxg.model,6,6,nop,0.5); assert(maxg.model.width*maxg.model.height==10584)
  for row=0,3 do
    local bytes={}; for byte=row*64,row*64+63 do bytes[#bytes+1]=string.char(byte) end
    model.calls.setCursorPos(maxg.model,nop,1,row+1); model.calls.write(maxg.model,nop,table.concat(bytes))
  end
  renderer.participate(maxg); renderer.tick(game.tick,nop); assert(not maxg.render or maxg.render.presented_revision~=maxg.model.revision)
  model.calls.setPaletteColor(maxg.model,nop,1,0x112233)
  renderer.participate(maxg)
  local count=0
  repeat count=count+1; renderer.tick(game.tick,nop) until maxg.render and maxg.render.presented_revision==maxg.model.revision or count>30
  assert(count<=30)
  for byte=0,255 do
    local i=math.floor(byte/64)*maxg.model.width+byte%64+1; local cell=maxg.render.cells[i]
    assert(cell.value[1]==byte)
    if byte~=32 then assert(cell.glyph.valid and cell.glyph.sprite=='tc-glyph-'..byte) end
  end
  local retired_object=maxg.render.cells[1].background
  for _,r0 in ipairs(maximum) do lifecycle.remove(r0.id,'fixture',true) end; settle()
  assert(not retired_object.valid)
  report('maximum-rectangle-byte-atlas-and-no-falsely-current-mixed-sweep')
  -- Keep the cold participant genuinely powered under real simulation ticks.
  local pole=assert(game.surfaces[1].create_entity{name='substation',position={0,4},force='player'})
  local power=assert(game.surfaces[1].create_entity{name='electric-energy-interface',position={-3,4},force='player'})
  power.power_production=1000000; power.power_usage=0
  runtime.stop(c.id); runtime.save(c.id,source,c.saved_revision); assert(runtime.activate(c.id,game.tick))
  f().power=power; f().pole=pole
  report('actual-tick-cold-fixture-armed')
  log('TC_CONTRACT_TOTAL '..f().groups)
end
local function snapshot()
  local r=registry.get(); local c=registry.computer(f().c); local g=r.monitors.groups[f().display]
  return {model=g.model,render=g.render,revision=g.model.revision,cells=copy(g.model.cells),palette=copy(g.model.palette),
    id=g.id,anchor=g.anchor,body=g.body.unit_number,boots=c.state.boots,run_id=c.run_id,
    total=r.ledger.total,tick=r.ledger.tick,machine=r.ledger.machines[c.id],work=r.ledger.machines[c.id].work,
    maintenance=r.scheduler.maintenance_spent,sequence=r.next_sequence,source=c.active.source}
end
local function unchanged()
  local a=f().snapshot; local b=snapshot()
  for _,k in ipairs({'model','render','revision','id','anchor','body','boots','run_id','total','tick','machine','work','maintenance','sequence','source'}) do
    assert(a[k]==b[k],'cold load changed '..k)
  end
  assert(value_equal(a.cells,b.cells) and value_equal(a.palette,b.palette))
  local r=b.render
  assert(r.presented_revision==a.presented_revision and r.sweep_revision==a.sweep_revision and r.sweep_cursor==a.sweep_cursor)
  assert(b.model.cells[1][1]==67 and b.model.scale==2)
end
function M.on_load()
  loaded=true
  if f().phase=='frozen' then unchanged(); log('TC_COLD_ON_LOAD_UNCHANGED') end
end
function M.on_tick(event)
  local fixture=f(); local c=registry.computer(fixture.c)
  if fixture.phase=='frozen' then
    if not loaded then return end
    unchanged(); loaded=false; fixture.phase='resuming'
    local ctx=admission.context(registry.get().ledger,c.id,fixture.snapshot.tick)
    assert(not admission.reserve(ctx,'work',limits.callback_work+1-ctx.machine.work))
    runtime.enqueue(c,'check',{name='fixture'},event.tick)
  elseif fixture.phase=='armed' then loaded=false end
  if fixture.phase=='done' then return end
  scheduler.tick(event.tick)
  assert(c.status=='running',serpent.line(c.diagnostic))
  local g=group(registry.record(fixture.tile))
  if fixture.phase=='armed' and c.state.boots==1 and g.render and g.render.presented_revision==g.model.revision then
    -- Save a post-dispatch accepted write beside the prior complete front.
    -- Actual partially prepared/coalesced cold state is covered by the full-world
    -- monitor_presentation_engine fixture, not by inventing a second tick here.
    model.calls.setCursorPos(g.model,nop,1,1); model.calls.write(g.model,nop,'COLD')
    renderer.participate(g)
    local spent=registry.get().scheduler.maintenance_spent; local front=g.render
    renderer.tick(event.tick,scheduler.maintenance(registry.get(),event.tick,true))
    assert(registry.get().scheduler.maintenance_spent==spent and g.render==front and g.render.presented_revision~=g.model.revision)
    -- A different writer can resize after notifications but before this computer
    -- dispatches. A retained stale payload must normalize at actual dispatch.
    runtime.emit(c.id,'monitor_resize',{peripheral=g.id,wire='red',wires={'red'},old_width=10,old_height=6,
      width=1,height=1,reason='scale'},event.tick)
    fixture.phase='frozen'; fixture.snapshot=snapshot()
    fixture.snapshot.presented_revision=g.render.presented_revision; fixture.snapshot.sweep_revision=g.render.sweep_revision
    fixture.snapshot.sweep_cursor=g.render.sweep_cursor
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif fixture.phase=='resuming' and c.state.checked and g.render.presented_revision==g.model.revision then
    assert(c.state.boots==1 and g.id==fixture.snapshot.id and g.model.cells[1][1]==67)
    assert(g.model.cells[g.model.width+1][1]==82); fixture.phase='done'; log('TC_COLD_OK')
  end
end
return M
