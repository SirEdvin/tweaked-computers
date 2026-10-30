-- RD4 exact-archive native state/render properties, NOT graphical X evidence.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local scheduler=require('scripts.scheduler')
local monitor=require('scripts.services.monitor')
local model=require('scripts.monitor-model')
local renderer=require('scripts.rendering')
local M={}; local loaded=false
local function nop() end
local function f() return storage.rd4 end
local function copy(t) if type(t)~='table' then return t end; local r={}; for k,v in pairs(t) do r[k]=copy(v) end; return r end
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end; return true
end
local function report(s) f().contracts=f().contracts+1; log('TC_CONTRACT '..s) end
local function terminal(m)
  local result={}
  for _,key in ipairs({'x','y','blink','fg','bg','scale','revision','width','height','cells','palette'}) do result[key]=copy(m[key]) end
  return result
end
local function resolve(row) return assert(monitor.resolve(registry.record(row.ids[1]))) end
local function settle()
  for _=1,200 do
    lifecycle.reconcile(game.tick,nop)
    monitor.reconcile(game.tick,nop); renderer.tick(game.tick,nop)
    local s=registry.get().monitors; local p=s.presentation
    local ready=not s.job and (not p or #p.jobs==0 and #p.orphans==0 and #p.retired==0 and p.pending_cells==0)
    for _,g in pairs(s.groups) do ready=ready and g.render and g.render.presented_revision==g.model.revision end
    if ready then return end
  end
  error('monitor feedback fixture did not settle')
end
local function properties(g)
  local r=g.render; assert(r.layer_version==3)
  assert(r.panel.type=='sprite' and r.panel.sprite=='tc-monitor-fill' and r.panel.render_layer=='higher-object-under')
  local cw,ch,ox,oy=model.geometry(g)
  for i,c in ipairs(r.cells) do
    assert(c.background.type=='sprite' and c.background.render_layer=='higher-object-above')
    local x,y=(i-1)%g.model.width,math.floor((i-1)/g.model.width)
    local ax,ay=model.world(g,ox+x*cw,oy+y*ch)
    local bx,by=model.world(g,ox+(x+1)*cw,oy+(y+1)*ch)
    assert(math.abs(c.background.x_scale-math.abs(bx-ax)*32)<1e-8)
    assert(math.abs(c.background.y_scale-math.abs(by-ay)*32)<1e-8)
    local p=c.background.target.position
    assert(math.abs(p.x-(ax+bx)/2)<1e-8 and math.abs(p.y-(ay+by)/2)<1e-8)
    if c.glyph then assert(c.glyph.type=='sprite' and c.glyph.render_layer=='train-stop-top' and c.glyph.orientation==g.direction/16) end
  end
  assert(r.cursor and r.cursor.type=='sprite' and r.cursor.render_layer=='item-in-inserter-hand' and r.cursor.blink_interval==30)
end
local function unchanged(row)
  local g=resolve(row); local a=row.snapshot
  assert(g==row.group and g.model==row.model and g.render==row.render)
  assert(g.id==row.id and g.anchor==row.anchor and equal(g.members,row.members))
  assert(equal(g.model,a),'mark/cancel/reload changed display model')
  assert(not registry.get().monitors.job and next(registry.get().monitors.resizes)==nil)
end
local function capture(row)
  local g=resolve(row)
  row.group=g; row.id=g.id; row.anchor=g.anchor; row.model=g.model; row.render=g.render
  row.members=copy(g.members); row.snapshot=copy(g.model)
end
local function handles(r)
  local list={r.panel,r.cursor}
  for _,c in ipairs(r.cells) do list[#list+1]=c.background; if c.glyph then list[#list+1]=c.glyph end end
  return list
end
-- Preserve production ownership and count authentic robot lifecycle delivery.
local removed=script.get_event_handler(defines.events.on_robot_mined_entity)
script.on_event(defines.events.on_robot_mined_entity,function(e)
  local x=f(); local unit=e.entity.unit_number
  removed(e)
  if x and unit==x.robot_unit then x.robot_events=(x.robot_events or 0)+1 end
end)
function M.run()
  storage.rd4={contracts=0,rows={},phase='armed',start=game.tick}
  local s=game.surfaces[1]
  for index,d in ipairs({0,4,8,12}) do
    local row={ids={}}; f().rows[#f().rows+1]=row
    for y=0,1 do for x=0,1 do
      local body=assert(s.create_entity{name=defs.devices.monitor.entity_name,position={index*12+x,y},direction=d,force='player'})
      lifecycle.on_built{entity=body}; local rec=assert(registry.by_entity(body))
      assert(not rec.children.power and lifecycle.available(rec))
      row.ids[#row.ids+1]=rec.id
    end end
    -- Real power for the ticks preceding the cold snapshot.
    local pole=assert(s.create_entity{name='substation',position={index*12,5},force='player'})
    local power=assert(s.create_entity{name='electric-energy-interface',position={index*12+3,5},force='player'})
    power.power_production=10000000; power.power_usage=0
    row.pole=pole; row.power=power
  end
  settle()
  for _,row in ipairs(f().rows) do
    local g=resolve(row); assert(#g.members==4)
    model.calls.setPaletteColor(g.model,nop,1,0x2468AC)
    model.calls.setBackgroundColor(g.model,nop,2)
    model.calls.setCursorBlink(g.model,nop,true)
    model.calls.write(g.model,nop,'NATIVE X')
    model.calls.setCursorPos(g.model,nop,2,2)
    renderer.participate(g)
  end
  settle()
  for _,row in ipairs(f().rows) do
    local g=resolve(row); properties(g); capture(row)
    local objects=#rendering.get_all_objects(); local first=g.render.cells[1].glyph
    local marked=registry.record(row.ids[4]); assert(marked.id~=g.anchor)
    assert(marked.body.order_deconstruction('player') and marked.body.to_be_deconstructed('player'))
    assert(not registry.record(row.ids[1]).body.to_be_deconstructed('player'))
    -- Touch on the non-anchor tile through the unchanged cardinal transform.
    local cw,ch,ox,oy=model.geometry(g); local found=false
    for y=1,g.model.height do for x=1,g.model.width do
      local wx,wy=model.world(g,ox+(x-0.5)*cw,oy+(y-0.5)*ch)
      if not found and math.abs(wx-marked.body.position.x)<0.49 and math.abs(wy-marked.body.position.y)<0.49 then
        local tx,ty=model.touch(g,wx,wy); assert(tx==x and ty==y); found=true
        -- Headless has no player: table-backed authorization/activation, with
        -- actual body reach target and the production pending event payload.
        local player={valid=true,index=1,force=marked.body.force,surface=marked.body.surface,
          cursor_stack={valid_for_read=false},can_reach_entity=function(body) return body==marked.body end,print=nop}
        assert(monitor.activate_for_player({input_name='tc-interact',tick=game.tick,
          cursor_position={x=wx,y=wy}},player))
        local state=registry.get().monitors; assert(#state.touches==1)
        local event=state.touches[1].payload
        assert(event.peripheral==g.id and event.x==x and event.y==y and event.name=='monitor_touch')
        state.touches={}
      end
    end end
    assert(found); settle(); unchanged(row)
    marked.body.cancel_deconstruction('player'); assert(not marked.body.to_be_deconstructed('player'))
    settle(); unchanged(row)
    assert(#rendering.get_all_objects()==objects and g.render.cells[1].glyph==first,'mark/cancel rebuilt presentation')
    -- Redraw changes only what the writer requested, not mark state/grouping.
    assert(marked.body.order_deconstruction('player'))
    model.calls.setCursorPos(g.model,nop,1,2); model.calls.write(g.model,nop,'LIVE')
    model.calls.setPaletteColor(g.model,nop,2,0xAB3412)
    renderer.participate(g)
    model.capture(g.model,nop)
    local expected=terminal(g.model)
    settle(); assert(equal(terminal(g.model),expected)); capture(row); unchanged(row); properties(g)
    assert(marked.body.to_be_deconstructed('player'))
    -- Unsupported availability hides/restores without changing committed content.
    marked.availability_version=99
    lifecycle.reconcile(game.tick,nop)
    monitor.reconcile(game.tick,nop); renderer.tick(game.tick,nop)
    assert(g.render.hidden and not g.render.panel.visible); unchanged(row)
    marked.availability_version=1
    settle(); unchanged(row); assert(not g.render.hidden and g.render.panel.visible)
    -- A real scale change makes the old front's grid obsolete immediately.
    -- Headless table-backed Ctrl-click must not map that still-visible image
    -- into the new character grid while its replacement is pending.
    local old=g.render
    model.scale(g.model,g.width_tiles,g.height_tiles,nop,2); renderer.changed(g)
    assert(not renderer.matches(g,old))
    local cw,ch,ox,oy=model.geometry(g)
    local wx,wy=model.world(g,ox+cw/2,oy+ch/2)
    local tile=registry.record(g.anchor)
    local player={valid=true,index=1,force=tile.body.force,surface=tile.body.surface,
      cursor_stack={valid_for_read=false},can_reach_entity=function() return true end,print=nop}
    local state=registry.get().monitors; local touches=#state.touches
    assert(not monitor.activate_for_player({input_name='tc-interact',tick=game.tick,cursor_position={x=wx,y=wy}},player))
    assert(#state.touches==touches,'obsolete image accepted a touch against a new grid')
    settle(); assert(g.id==row.id and renderer.matches(g,g.render)); properties(g); capture(row)
    assert(monitor.activate_for_player({input_name='tc-interact',tick=game.tick,cursor_position={x=wx,y=wy}},player))
    local payload=state.touches[#state.touches].payload
    assert(payload.x==1 and payload.y==1 and payload.peripheral==g.id); state.touches={}
  end
  report('four-cardinal-scale-invalidation-rejects-stale-grid-touch-until-native-publication')
  report('four-cardinal-native-marked-subsets-cancel-live-updates-power-and-non-anchor-touch')
  report('native-sprite-strata-centers-extents-cursor-below-wires-selection-info')
  -- Genuine legacy draw objects, with missing new presentation metadata. Model
  -- remains current; migration is presentation-only and must be paid, not on_load.
  local legacy=resolve(f().rows[4]); local r=legacy.render
  r.panel.destroy(); r.panel=rendering.draw_rectangle{surface=s,left_top={47.5,-0.5},right_bottom={49.5,1.5},color={0,0,0},filled=true}
  for _,c in ipairs(r.cells) do if c.glyph then c.glyph.render_layer='light-effect' end end
  r.layer_version=nil; r.version=nil
  renderer.changed(legacy)
  local count=#rendering.get_all_objects(); local before=copy(legacy.model)
  local ok=pcall(renderer.tick,game.tick,function() error('fixture-zero-credit',0) end)
  assert(not ok and legacy.render==r and r.panel.valid and equal(before,legacy.model) and #rendering.get_all_objects()==count)
  f().legacy=r
  f().legacy_handles=handles(r)
  report('legacy-high-layer-render-graph-zero-credit-refusal-retains-model-and-objects')
  -- Capture current AND legacy render graphs while native body marks are pending.
  for _,row in ipairs(f().rows) do capture(row) end
  log('TC_CONTRACT_TOTAL '..f().contracts)
end
function M.on_load()
  loaded=true
  if f().phase=='frozen' then
    for _,row in ipairs(f().rows) do unchanged(row); assert(registry.record(row.ids[4]).body.to_be_deconstructed('player')) end
    assert(f().legacy.panel.valid and f().legacy.layer_version==nil)
    log('TC_RD4_MARKED_ON_LOAD_UNCHANGED')
  end
end
function M.on_configuration_changed() end
function M.on_tick(e)
  local x=f()
  if x.phase=='done' then return end
  if x.phase=='armed' then
    -- Do not run scheduler yet: retain the real legacy graph for cold upgrade.
    loaded=false; x.phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  elseif x.phase=='frozen' then
    if not loaded then return end
    loaded=false
    for _,row in ipairs(x.rows) do unchanged(row) end
    scheduler.tick(e.tick)
    -- Old high-layer handles drain through normal bounded cleanup next tick.
    x.phase='restoring'; x.resume_tick=e.tick; return
  end
  scheduler.tick(e.tick)
  if x.phase=='restoring' and e.tick>x.resume_tick then
    local p=registry.get().monitors.presentation
    if #p.jobs>0 or #p.orphans>0 or #p.retired>0 or p.pending_cells>0 then return end
    local legacy=resolve(x.rows[4]); assert(legacy.model==x.rows[4].model and equal(legacy.model,x.rows[4].snapshot))
    assert(not x.legacy.panel.valid and not x.legacy.cursor.valid)
    for _,object in ipairs(x.legacy_handles) do assert(not object.valid) end
    for _,c in ipairs(x.legacy.cells) do assert(c==false) end
    for _,row in ipairs(x.rows) do
      local g=resolve(row); properties(g)
      assert(g==row.group and equal(g.model,row.snapshot) and equal(g.members,row.members))
      assert(registry.record(row.ids[4]).body.to_be_deconstructed('player'))
      registry.record(row.ids[4]).body.cancel_deconstruction('player')
      assert(not registry.record(row.ids[4]).body.to_be_deconstructed('player'))
    end
    x.rows[4].render=legacy.render -- Admitted presentation upgrade, never a model replacement.
    log('TC_RD4_COLD_MARK_CANCEL_AND_LEGACY_REDRAW_OK')
    local row=x.rows[1]; local rec=registry.record(row.ids[4]); local s=rec.body.surface
    x.robot_unit=rec.body.unit_number; x.robot_id=rec.id; x.robot_parts=copy(rec.children)
    x.old_render=row.group.render; x.old_group=row.id
    x.old_handles=handles(x.old_render)
    x.roboport=assert(s.create_entity{name='roboport',position={12,11},force='player'})
    x.roboport.energy=100000000
    x.roboport.get_inventory(defines.inventory.roboport_robot).insert{name='construction-robot',count=1}
    x.chest=assert(s.create_entity{name='storage-chest',position={16,11},force='player'})
    assert(rec.body.order_deconstruction('player')); x.phase='mining'; x.mining_tick=e.tick
  elseif x.phase=='mining' then
    assert(e.tick-x.mining_tick<3600,'native robot removal deadline')
    if not x.robot_events then return end
    assert(x.robot_events==1 and not registry.record(x.robot_id))
    local state=registry.get().monitors; local p=state.presentation
    if state.job or #p.retired>0 or #p.orphans>0 or #p.jobs>0 or p.pending_cells>0 then return end
    local inv=x.chest.get_inventory(defines.inventory.chest)
    if inv.get_item_count('tc-monitor')~=1 then return end
    assert(not x.old_render.panel.valid and not x.old_render.cursor.valid)
    for _,object in ipairs(x.old_handles) do assert(not object.valid) end
    for _,part in pairs(x.robot_parts) do assert(not part.valid) end
    local row=x.rows[1]; local seen={}; local total=0
    for _,id in ipairs(row.ids) do if id~=x.robot_id then
      local g=assert(monitor.resolve(registry.record(id)))
      if not seen[g.id] then seen[g.id]=true; total=total+#g.members end
      assert(g.model.width==model.size(g.width_tiles,g.height_tiles,g.model.scale))
      assert(g.render and g.render.panel.valid)
    end end
    assert(total==3 and seen[x.old_group])
    for index=2,4 do unchanged(x.rows[index]) end
    x.phase='done'; log('TC_RD4_NATIVE_ROBOT_ONCE_CLEANUP_SPLIT_OK'); log('TC_COLD_OK')
  end
end
return M
