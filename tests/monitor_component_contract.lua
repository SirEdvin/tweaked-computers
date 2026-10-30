-- Native component sharing, cancellation and separate-process publication.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local monitor=require('scripts.services.monitor')
local model=require('scripts.monitor-model')
local renderer=require('scripts.rendering')
local defs=require('scripts.device-definitions')
local snapshots=require('scripts.lifecycle-data')
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
  assert(not ok and problem==refused and g.render==front and front.cells[1].background.visible)
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
  write(g,'A'); settle()
  local a=g.render.cells[1]; local background=a.background; local glyph=a.glyph
  write(g,'B'); settle()
  assert(g.render.cells[1].background==background and background.valid,'glyph change rebuilt an unchanged background')
  assert(not glyph.valid and g.render.cells[1].glyph.sprite=='tc-glyph-66')
  glyph=g.render.cells[1].glyph
  write(g,'B','0','1'); settle()
  assert(g.render.cells[1].glyph==glyph and glyph.valid,'background change rebuilt an unchanged glyph')
  assert(not background.valid)
  background=g.render.cells[1].background
  write(g,'C','0','1'); local job=defer(g)
  local staged=job.frames[1].cells[1]
  assert(staged.background==background and background.visible and staged.shared_background)
  assert(staged.glyph.valid and not staged.glyph.visible and glyph.visible)
  tile.physical_error='injected temporary physical unavailability'; renderer.tick(game.tick,nop)
  assert(not background.visible and not glyph.visible and not staged.glyph.visible)
  renderer.changed(g)
  -- Cancelled staging must never destroy borrowed objects. Cancelled guest
  -- content remains authoritative; restore the old image before a new seal.
  write(g,'B','0','1'); settle()
  assert(background.valid and glyph.valid and not staged.glyph.valid and not background.visible)
  tile.physical_error=nil; settle()
  assert(background.valid and glyph.valid and g.render.cells[1].background==background and g.render.cells[1].glyph==glyph)
  assert(not staged.glyph.valid)
  write(g,' ' ,'4','1'); settle()
  assert(g.render.cells[1].background==background and not g.render.cells[1].glyph and not glyph.valid)
  write(g,' ' ,'5','1'); settle()
  assert(g.render.cells[1].background==background and not g.render.cells[1].glyph)
  write(g,'D','0','1'); settle()
  glyph=g.render.cells[1].glyph
  model.calls.setPaletteColor(g.model,nop,1,0x123456); renderer.participate(g); settle()
  assert(g.render.cells[1].background==background and not glyph.valid)
  glyph=g.render.cells[1].glyph
  model.calls.setPaletteColor(g.model,nop,2,0x223344); renderer.participate(g); settle()
  assert(g.render.cells[1].glyph==glyph and not background.valid)
  background=g.render.cells[1].background
  write(g,'E','0','1'); job=defer(g)
  storage.tc_components={phase='armed',group=g,tile=tile.id,job=job,front=g.render,background=background,glyph=glyph}
  log('TC_COMPONENTS_OK independent-glyph-background-reuse cancellation palette blank-foreground')
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
  local staged=x.job.frames[1].cells[1]
  assert(staged.background==x.background and not staged.glyph.visible)
  assert(lifecycle.available(registry.record(x.tile)))
  settle()
  assert(g.render.cells[1].background==x.background and x.background.valid and x.background.visible)
  assert(not x.glyph.valid and g.render.cells[1].glyph.sprite=='tc-glyph-69')
  local final_glyph=g.render.cells[1].glyph
  lifecycle.remove(x.tile,'component-fixture-cleanup',true); settle()
  assert(not x.background.valid and not final_glyph.valid)
  x.phase='done'; log('TC_COLD_OK component-sharing retained-ready-job exactly-once-transfer teardown')
end
return M
