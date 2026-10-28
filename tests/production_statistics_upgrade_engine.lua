-- Immutable pre-feature save installation, not a configuration-only substitute.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local defs=require('scripts.device-definitions')
local M={}; local loaded=false
local function f() return storage.tc_stat_upgrade end
local source=[[return {api_version=1,handlers={start=function() computer.setState('boots',(computer.getState('boots') or 0)+1) end}}]]
local function build(kind,x)
  local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,0},force='player'})
  lifecycle.on_built{entity=body}; return assert(registry.by_entity(body))
end
local function capture()
  local x=f(); local c=registry.record(x.c); local s=registry.record(x.s)
  local recipes,research={},{}
  for name,recipe in pairs(game.forces.player.recipes) do recipes[name]=recipe.enabled end
  for name,technology in pairs(game.forces.player.technologies) do research[name]=technology.researched end
  return {c=c,s=s,state=c.state,active=c.active,source=c.saved_source,boots=c.state.boots,
    unit=c.body.unit_number,port=s.body.unit_number,red=lifecycle.connector(c,'network','red').connection_count,
    green=lifecycle.connector(c,'network','green').connection_count,recipes=recipes,research=research}
end
local function unchanged()
  local a=f().before; local b=capture()
  for _,key in ipairs({'c','s','state','active','source','boots','unit','port','red','green'}) do assert(a[key]==b[key],'upgrade changed '..key) end
  for name,value in pairs(a.recipes) do assert(b.recipes[name]==value,'upgrade changed old recipe '..name) end
  for name,value in pairs(a.research) do assert(b.research[name]==value,'upgrade changed research '..name) end
end
function M.run()
  assert(not defs.devices.production_statistics,'baseline must predate statistics')
  storage.tc_stat_upgrade={phase='boot',start=game.tick}
  local x=f(); local c=build('computer',0); local s=build('recipe_searcher',3)
  x.c=c.id; x.s=s.id
  for _,color in ipairs({'red','green'}) do assert(lifecycle.connector(c,'network',color).connect_to(lifecycle.connector(s,'network',color))) end
  local supply=assert(game.surfaces[1].create_entity{name='electric-energy-interface',position={6,6},force='player'})
  supply.power_production=100000000; supply.power_usage=0
  assert(game.surfaces[1].create_entity{name='substation',position={3,3},force='player'})
  local force=game.forces.player
  force.technologies['tc-circuit-computers'].researched=true; force.technologies['tc-recipe-searcher'].researched=true
  lifecycle.unlocks(); assert(force.recipes['tc-recipe-searcher'].enabled)
  local fresh=game.create_force('tc-stat-upgrade-unresearched')
  fresh.technologies['tc-circuit-computers'].researched=true
  assert(runtime.save(c.id,source,0)); assert(runtime.activate(c.id,game.tick))
end
function M.on_load() loaded=true end
function M.on_configuration_changed()
  unchanged(); local x=f(); local fresh=game.forces['tc-stat-upgrade-unresearched']
  assert(game.forces.player.recipes['tc-production-statistics'].enabled)
  if x.phase=='frozen' then
    assert(not fresh.recipes['tc-production-statistics'].enabled and fresh.technologies['tc-circuit-computers'].researched and not fresh.technologies['tc-recipe-searcher'].researched)
    x.phase='installed'; log('TC_STAT_UPGRADE researched-and-circuit-only-forces-preserved')
  elseif x.phase=='waiting-later' then
    assert(fresh.technologies['tc-recipe-searcher'].researched and fresh.recipes['tc-production-statistics'].enabled)
    x.phase='later'
  else error('unexpected upgrade phase '..x.phase) end
end
function M.on_tick(event)
  local x=f()
  if x.phase=='frozen' then return end
  if x.phase=='waiting-later' then
    if loaded then unchanged(); loaded=false; log('TC_UPGRADE_ORDINARY_OK') end
    return
  end
  scheduler.tick(event.tick)
  local c=registry.record(x.c); assert(c.status=='running',serpent.line(c.diagnostic))
  if x.phase=='boot' and c.state.boots then
    assert(c.state.boots==1); x.before=capture(); x.phase='frozen'
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif x.phase=='installed' then
    unchanged()
    local fresh=game.forces['tc-stat-upgrade-unresearched']
    fresh.technologies['tc-recipe-searcher'].researched=true; fresh.recipes['tc-production-statistics'].enabled=false
    x.phase='waiting-later'; game.server_save('tc-stat-installed'); log('TC_UPGRADE_OK')
  elseif x.phase=='later' then unchanged(); x.phase='done'; log('TC_STAT_LATER_RECONCILIATION_OK') end
end
return M
