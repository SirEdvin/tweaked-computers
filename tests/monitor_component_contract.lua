-- Native component sharing, cancellation and separate-process publication.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local monitor=require('scripts.services.monitor')
local model=require('scripts.monitor-model')
local renderer=require('scripts.rendering')
local defs=require('scripts.device-definitions')
local snapshots=require('scripts.lifecycle-data')
local rows=require('tests.monitor_rows')
local M={}; local loaded=false
local function nop() end
local function f() return storage.tc_components end
local function settle()
  for _=1,100 do
    lifecycle.reconcile(game.tick,nop)
    monitor.reconcile(game.tick,nop); renderer.tick(game.tick,nop)
    local p=registry.get().monitors.presentation
    if p and #p.jobs==0 and #p.retired==0 and #p.orphans==0 and p.pending_cells==0 then return end
  end
  error('component fixture did not settle')
end
local function write(g,text,fg,bg)
  model.calls.setCursorPos(g.model,nop,1,1); model.calls.blit(g.model,nop,text,fg or '0',bg or 'f')
  renderer.participate(g)
end
local function defer(g)
  local refused={}; local p=registry.get().monitors.presentation; local front=g.render
  local ok,problem=pcall(renderer.tick,game.tick,function()
    if p.jobs[1] and p.jobs[1].ready then error(refused,0) end
  end)
  assert(not ok and problem==refused and g.render==front and front.rows[1].bg.visible)
  assert(#p.jobs==1 and p.jobs[1].ready)
  return p.jobs[1]
end
function M.run()
  registry.initialize()
  local body=assert(game.surfaces[1].create_entity{name=defs.devices.monitor.entity_name,position={0,0},force='player'})
  local tile=assert(lifecycle.build(body)); assert(not tile.children.power and lifecycle.available(tile))
  settle(); local g=assert(monitor.resolve(tile))
  assert(monitor.available(g,nop))
  local at=body.position; assert(body.teleport({at.x+1,at.y}))
  assert(not monitor.available(g,nop),'same-event move reused an old physical proof')
  assert(body.teleport(at)); assert(monitor.available(g,nop))
  body.direction=4; assert(not monitor.available(g,nop)); body.direction=0
  local foreign=game.create_force('tc-components-foreign')
  body.force=foreign; assert(not monitor.available(g,nop)); body.force='player'
  local bindings=registry.get().entities; local binding=bindings[body.unit_number]
  bindings[body.unit_number]={id='unrelated',role='body'}
  assert(not monitor.available(g,nop)); bindings[body.unit_number]=binding
  assert(monitor.available(g,nop))
  log('TC_COMPONENT_AUTHORITY_OK live-same-event-position-direction-force-ownership')
  local state=registry.get().monitors
  local settings=snapshots.settings(tile); settings.monitor.scale=2
  local width,height=g.model.width,g.model.height
  snapshots.apply_settings(tile,settings)
  local resize=state.resizes[g.id]
  assert(resize and resize.payload.old_width==width and resize.payload.old_height==height
    and resize.payload.width==g.model.width and resize.payload.height==g.model.height,
    'settings paste changed dimensions without a resize notification')
  settings.monitor.scale=1; snapshots.apply_settings(tile,settings); settle()
  log('TC_COMPONENT_SETTINGS_OK paste-resize-and-presentation-without-guest-participation')
  local p=state.presentation
  for _,legacy in ipairs({false,true}) do
    for _,field in ipairs({'demand_version','work','members','shells','lanes','jobs','orphans','retired'}) do
      if not legacy or field~='demand_version' then
        local saved,version=p[field],p.demand_version; local front=g.render; local tick=p.tick
        if legacy then p.demand_version=nil end
        p[field]=field=='demand_version' and 99 or false
        local ok,problem=pcall(monitor.resolve,tile)
        assert(not ok and problem.code=='E_UNSUPPORTED','unsupported demand state authorized a service: '..field..' legacy='..tostring(legacy))
        renderer.tick(game.tick,nop)
        assert(g.render==front and p.tick==tick and p[field]~=saved,'unsupported demand state was reset')
        p[field]=saved; p.demand_version=version
      end
    end
  end
  log('TC_COMPONENT_DEMAND_UNSUPPORTED_OK recoverable-format-and-index-refusal')
  local function glyphs(text) return (string.gsub(text,'.',function(c) local b=c:byte(); return string.char(0xEE,0x80+math.floor(b/64),0x80+b%64) end)) end
  local function tag(v) return string.format('[color=%.5f',v) end
  write(g,'A'); settle()
  local background=g.render.rows[1].bg; local glyph=g.render.rows[1].glyph
  write(g,'B'); settle()
  -- A changed row updates its visible objects in place at commit.
  assert(g.render.rows[1].bg==background and background.valid,'glyph change rebuilt the row background')
  assert(g.render.rows[1].glyph==glyph and glyph.valid and glyph.text:find(glyphs('B'),1,true),'glyph change rebuilt its object')
  write(g,'B','0','1'); settle()
  assert(g.render.rows[1].glyph==glyph and glyph.valid,'background change rebuilt the row glyphs')
  assert(g.render.rows[1].bg==background and background.text:find(tag(g.model.palette[2][1]),1,true),'background colour not updated in place')
  rows.verify(g.render,true)
  local objects=#rendering.get_all_objects()
  write(g,'C','0','1'); local job=defer(g)
  -- Prepared but uncommitted: the front still shows B and the frame holds only row data.
  local staged=job.frames[1]
  assert(staged.data[1] and not staged.rows and not staged.panel and not staged.cursor)
  assert(#rendering.get_all_objects()==objects,'preparation created native objects')
  assert(background.visible and glyph.visible and glyph.text:find(glyphs('B'),1,true))
  tile.physical_error='injected temporary physical unavailability'; renderer.tick(game.tick,nop)
  assert(not background.visible and not glyph.visible)
  renderer.changed(g)
  -- A cancelled frame owns nothing to retire; guest content stays authoritative.
  assert(#rendering.get_all_objects()==objects,'cancelled frame owned native objects')
  write(g,'B','0','1'); settle()
  -- The cancelled C was never applied to the front.
  assert(background.valid and glyph.valid and glyph.text:find(glyphs('B'),1,true) and not background.visible)
  tile.physical_error=nil; settle()
  assert(background.valid and glyph.valid and g.render.rows[1].bg==background and g.render.rows[1].glyph==glyph)
  assert(glyph.visible and glyph.text:find(glyphs('B'),1,true))
  write(g,' ' ,'4','1'); settle()
  assert(g.render.rows[1].bg==background and not g.render.rows[1].glyph and not glyph.valid)
  write(g,' ' ,'5','1'); settle()
  assert(g.render.rows[1].bg==background and not g.render.rows[1].glyph)
  write(g,'D','0','1'); settle()
  glyph=g.render.rows[1].glyph
  -- A palette change rewrites the rows in place.
  model.calls.setPaletteColor(g.model,nop,1,0x123456); renderer.participate(g); settle()
  assert(g.render.rows[1].bg==background and g.render.rows[1].glyph==glyph and glyph.text:find(tag(0x12/255),1,true))
  model.calls.setPaletteColor(g.model,nop,2,0x223344); renderer.participate(g); settle()
  assert(g.render.rows[1].glyph==glyph and g.render.rows[1].bg==background and background.text:find(tag(0x22/255),1,true))
  rows.verify(g.render,true)
  write(g,'E','0','1'); job=defer(g)
  storage.tc_components={phase='armed',group=g,tile=tile.id,job=job,front=g.render,background=background,glyph=glyph,panel=g.render.panel}
  log('TC_COMPONENTS_OK row-identity cancellation-owns-nothing palette-in-place blank-row')
end
function M.on_load() loaded=true end
function M.on_tick(event)
  local x=f(); if x.phase=='done' then return end
  if x.phase=='armed' then
    x.phase='frozen'; loaded=false; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  if not loaded then return end
  local g=x.group; local p=registry.get().monitors.presentation
  assert(g.render==x.front and p.jobs[1]==x.job and x.job.ready)
  assert(x.background.valid and x.background.visible and x.glyph.valid and x.glyph.visible)
  local function glyphs(text) return (string.gsub(text,'.',function(c) local b=c:byte(); return string.char(0xEE,0x80+math.floor(b/64),0x80+b%64) end)) end
  -- The saved, ready frame holds row data only; the front still shows D until commit.
  assert(x.job.frames[1].data[1] and x.glyph.text:find(glyphs('D'),1,true))
  assert(lifecycle.available(registry.record(x.tile)))
  settle()
  assert(g.render==x.front and g.render.rows[1].bg==x.background and x.background.valid and x.background.visible)
  assert(g.render.rows[1].glyph==x.glyph and x.glyph.valid and x.glyph.visible and x.glyph.text:find(glyphs('E'),1,true))
  rows.verify(g.render,true)
  lifecycle.remove(x.tile,'component-fixture-cleanup',true); settle()
  assert(not x.background.valid and not x.glyph.valid and not x.panel.valid)
  x.phase='done'; log('TC_COLD_OK row-identity retained-ready-frame exactly-once teardown')
end
return M
