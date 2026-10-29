-- Run by the owning mod. Legacy copy receives only this fixture + opt-in hook.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local runtime=require('scripts.runtime.computer')
local scheduler=require('scripts.scheduler')
local defs=require('scripts.device-definitions')
local M={}; local loaded=false
local function f() return storage.tc_recipe_upgrade end
local function nop() end
local source=[[function start(e)
  computer.setState('boots',(computer.getState('boots') or 0)+1)
  computer.setState('factory','retained')
end]]
local function retained()
  local x=f(); local c=registry.record(x.c); local db=registry.record(x.db)
  assert(c==x.saved.c and c.state==x.saved.state and c.active==x.saved.active and c.run_id==x.saved.run)
  assert(c.state.boots==1 and c.saved_source==source and c.state.factory=='retained')
  assert(db==x.saved.db and db.database==x.saved.database)
  assert(lifecycle.connector(c,'network','red').connection_count==1)
end
function M.run()
  assert(not defs.devices.recipe_searcher,'must originate before the feature')
  storage.tc_recipe_upgrade={phase='legacy',start=game.tick}
  local x=f(); local function build(kind,pos)
    local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position=pos,force='player'})
    lifecycle.on_built{entity=body}; local rec=assert(registry.by_entity(body)); return rec
  end
  local c=build('computer',{0,0}); local db=build('kv',{3,0}); x.c=c.id; x.db=db.id
  assert(lifecycle.connector(c,'network','red').connect_to(lifecycle.connector(db,'network','red')))
  local supply=assert(game.surfaces[1].create_entity{name='electric-energy-interface',position={6,4},force='player'})
  supply.power_production=100000000; supply.power_usage=0
  assert(game.surfaces[1].create_entity{name='substation',position={3,3},force='player'})
  game.forces.player.technologies['tc-circuit-computers'].researched=true
  assert(runtime.save(c.id,source,0)); assert(runtime.activate(c.id,game.tick))
end
function M.on_load()
  loaded=true
  if f() and f().saved then retained(); log('TC_RECIPE_UPGRADE_ON_LOAD_RETAINED') end
end
function M.on_configuration_changed()
  retained(); local x=f()
  assert(x.phase=='legacy-frozen' and defs.devices.recipe_searcher)
  local force=game.forces.player
  assert(force.technologies['tc-circuit-computers'].researched)
  for _,kind in ipairs({'computer','kv','monitor','logic','configurator'}) do assert(force.recipes[defs.devices[kind].name].enabled) end
  assert(not force.technologies['tc-recipe-searcher'].researched and not force.recipes['tc-recipe-searcher'].enabled,
    'Circuit Computers bypassed new research on installation')
  -- Reconciliation is additive, including script-enabled unrelated recipes.
  force.recipes['steel-plate'].enabled=true; lifecycle.unlocks(); assert(force.recipes['steel-plate'].enabled)
  force.technologies['tc-recipe-searcher'].researched=true
  lifecycle.unlocks(); assert(force.recipes['tc-recipe-searcher'].enabled)
  x.phase='installed'; log('TC_RECIPE_INSTALL_CONFIGURATION_OK')
end
function M.on_tick(event)
  local x=f()
  if x.phase=='legacy-frozen' then return end
  if x.phase=='installed' then
    retained(); x.phase='done'; log('TC_UPGRADE_OK'); return
  end
  if x.phase=='done' then
    if loaded then
      retained(); assert(game.forces.player.recipes['tc-recipe-searcher'].enabled)
      loaded=false; log('TC_UPGRADE_ORDINARY_OK')
    end
    return
  end
  loaded=false; scheduler.tick(event.tick)
  local c=registry.record(x.c); assert(c.status=='running',serpent.line(c.diagnostic))
  assert(event.tick-x.start<120)
  if c.state.boots==1 then

    local db=registry.record(x.db)
    x.saved={c=c,state=c.state,active=c.active,run=c.run_id,db=db,database=db.database}
    x.phase='legacy-frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  end
end
return M
