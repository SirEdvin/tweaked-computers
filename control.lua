local registry = require('scripts.registry')
-- All trusted imports and hook registration occur at control parsing time.
local scheduler = require('scripts.scheduler')
local lifecycle = require('scripts.lifecycle')
local peripheral = require('scripts.services.peripheral')
script.on_init(function() registry.initialize(); lifecycle.unlocks() end)
script.on_configuration_changed(function() registry.initialize(); lifecycle.unlocks() end)
script.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity,
  defines.events.script_raised_built,defines.events.script_raised_revive},lifecycle.on_built)
script.on_event({defines.events.on_player_mined_entity,defines.events.on_robot_mined_entity,
  defines.events.on_entity_died,defines.events.script_raised_destroy},lifecycle.on_removed)
script.on_event(defines.events.on_player_rotated_entity,lifecycle.on_rotated)
script.on_event(defines.events.on_tick,function(event) scheduler.tick(event.tick) end)
-- on_load deliberately has no handler: it executes no source and changes no state.
