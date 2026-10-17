-- Native component sharing, cancellation and separate-process publication.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local monitor=require('scripts.services.monitor')
local model=require('scripts.monitor-model')
local renderer=require('scripts.rendering')
local defs=require('scripts.device-definitions')
local M={}; local loaded=false
local function nop() end
local function f() return storage.tc_components end
local function settle()
  for _=1,100 do
    monitor.reconcile(game.tick,nop); renderer.tick(game.tick,nop)
    local p=registry.get().monitors.presentation
    if p and #p.jobs==0 and #p.retired==0 and #p.orphans==0 and p.pending_cells==0 then return end
  end
  error('component fixture did not settle')
end
local function write(g,text,fg,bg)
  model.calls.setCursorPos(g.model,nop,1,1); model.calls.blit(g.model,nop,text,fg or '0',bg or 'f')
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
  local tile=assert(lifecycle.build(body)); lifecycle.power_entity(tile).energy=100000; tile.powered=true
  settle(); local g=assert(monitor.resolve(tile))
  assert(monitor.available(g,nop))
  local at=body.position; assert(body.teleport({at.x+1,at.y}))
  assert(not monitor.available(g,nop),'same-event move reused an old physical proof')
  assert(body.teleport(at)); assert(monitor.available(g,nop))
  body.direction=4; assert(not monitor.available(g,nop)); body.direction=0
  local foreign=game.create_force('tc-components-foreign')
  body.force=foreign; assert(not monitor.available(g,nop)); body.force='player'
  local power=lifecycle.power_entity(tile); power.energy=0
  assert(not monitor.available(g,nop)); power.energy=100000
  assert(monitor.available(g,nop))
  log('TC_COMPONENT_AUTHORITY_OK live-same-event-position-direction-force-power')
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
  power.energy=0; renderer.tick(game.tick,nop)
  assert(not background.visible and not glyph.visible and not staged.glyph.visible)
  renderer.changed(g)
  -- Cancelled staging must never destroy borrowed objects. Cancelled guest
  -- content remains authoritative; restore the old image before a new seal.
  write(g,'B','0','1'); settle()
  assert(background.valid and glyph.valid and not staged.glyph.valid and not background.visible)
  power.energy=100000; settle()
  assert(background.valid and glyph.valid and g.render.cells[1].background==background and g.render.cells[1].glyph==glyph)
  assert(not staged.glyph.valid)
  write(g,' ' ,'4','1'); settle()
  assert(g.render.cells[1].background==background and not g.render.cells[1].glyph and not glyph.valid)
  write(g,' ' ,'5','1'); settle()
  assert(g.render.cells[1].background==background and not g.render.cells[1].glyph)
  write(g,'D','0','1'); settle()
  glyph=g.render.cells[1].glyph
  model.calls.setPaletteColor(g.model,nop,1,0x123456); settle()
  assert(g.render.cells[1].background==background and not glyph.valid)
  glyph=g.render.cells[1].glyph
  model.calls.setPaletteColor(g.model,nop,2,0x223344); settle()
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
  lifecycle.power_entity(registry.record(x.tile)).energy=100000
  settle()
  assert(g.render.cells[1].background==x.background and x.background.valid and x.background.visible)
  assert(not x.glyph.valid and g.render.cells[1].glyph.sprite=='tc-glyph-69')
  local final_glyph=g.render.cells[1].glyph
  lifecycle.remove(x.tile,'component-fixture-cleanup',true); settle()
  assert(not x.background.valid and not final_glyph.valid)
  x.phase='done'; log('TC_COLD_OK component-sharing retained-ready-job exactly-once-transfer teardown')
end
return M
