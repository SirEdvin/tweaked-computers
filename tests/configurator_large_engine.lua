-- Strict integration gate: do not weaken common Data limits to pass this fixture.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local sections=require('scripts.configuration.sections')
local targets=require('scripts.configuration.targets')
local validation=require('scripts.configuration.validation')
local M={}; local loaded=false
local function nop() end
local function f() return storage.configurator_large_fixture end
function M.run()
  registry.initialize(); game.forces.player.research_all_technologies()
  local surface=game.surfaces[1]
  local cfg=assert(lifecycle.build(assert(surface.create_entity{name=defs.devices.configurator.entity_name,position={0,0},force='player'})))
  local entity=assert(surface.create_entity{name='constant-combinator',position={3,0},force='player'})
  local cb=entity.get_or_create_control_behavior()
  while cb.sections_count<33 do assert(cb.add_section('')) end
  local item={id=targets.identity(entity),entity=entity}
  local before=sections.get(item,nop)
  assert(#before==33)
  local result=sections.set(item,cfg,33,{set={active=false}},nop)
  assert(result.index==33 and result.active==false and cb.sections_count==33)
  storage.configurator_large_fixture={item=item,cfg=cfg.id,sections=sections.get(item,nop),phase='armed'}
  log('TC_CONTRACT native-33-sections-complete-inspection-and-mutation')
  log('TC_CONTRACT_TOTAL 1')
end
function M.on_load()
  if f().phase=='frozen' then loaded=true; log('TC_COLD_ON_LOAD_UNCHANGED') end
end
function M.on_tick()
  if f().phase=='done' then return end
  if f().phase=='frozen' then
    if not loaded then return end
    assert(validation.equal(sections.get(f().item,nop),f().sections))
    assert(sections.remove(f().item,registry.record(f().cfg),33,nop))
    f().phase='done'; log('TC_COLD_OK'); return
  end
  f().phase='frozen'; game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
end
return M
