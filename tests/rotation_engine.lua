-- Packaged headless regression for rotation authority and synchronous cleanup.
-- Real keyboard delivery, positive engine rotation and wire retention are SC2
-- client evidence; mocks here must not be labelled native input acceptance.
local registry=require('scripts.registry')
local lifecycle=require('scripts.lifecycle')
local defs=require('scripts.device-definitions')
local contract=require('tests.rotation_contract')
local M={}
function M.run()
  registry.initialize()
  local function build(kind,x)
    local body=assert(game.surfaces[1].create_entity{name=defs.devices[kind].entity_name,position={x,0},force='player'})
    return assert(lifecycle.build(body))
  end
  local computer=build('computer',0); local logic=build('logic',4)
  contract.run(computer.id,logic.id,false)
  assert(lifecycle.remove(computer.id,'fixture-cleanup',true))
  assert(lifecycle.remove(logic.id,'fixture-cleanup',true))
  log('TC_CONTRACT rotation-real-body-authority-refusals')
  log('TC_CONTRACT rotation-mocked-native-entry-restoration')
  log('TC_CONTRACT_TOTAL 2')
end
return M
