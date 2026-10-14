local registry = require('scripts.registry')
-- All trusted imports and hook registration occur at control parsing time.
local scheduler = require('scripts.scheduler')
local lifecycle = require('scripts.lifecycle')
local peripheral = require('scripts.services.peripheral')
local editor = require('scripts.ui.editor')
local logic = require('scripts.services.logic')
local kv = require('scripts.services.kv')
local monitor = require('scripts.services.monitor')
local snapshots = require('scripts.lifecycle-data')
local blueprints = require('scripts.blueprints')
script.on_event('tc-monitor-activate',monitor.activate)
editor.register_inspector(require('scripts.ui.network-inspector'))
script.on_event(defines.events.on_gui_opened,editor.on_opened)
script.on_event(defines.events.on_gui_closed,editor.on_closed)
script.on_event(defines.events.on_gui_click,editor.on_click)
script.on_event(defines.events.on_gui_text_changed,editor.on_text)
script.on_event({'tc-open-editor','tc-open-selected-computer'},editor.on_input)
script.on_event({defines.events.on_player_left_game,defines.events.on_player_died,
  defines.events.on_player_changed_force,defines.events.on_player_changed_surface},editor.on_player_unavailable)
script.on_event({defines.events.on_player_display_resolution_changed,
  defines.events.on_player_display_scale_changed},editor.on_size)
script.on_init(function() registry.initialize(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing() end)
script.on_configuration_changed(function() registry.initialize(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing() end)
script.on_event(defines.events.on_player_setup_blueprint,blueprints.on_setup)
script.on_event(defines.events.on_entity_settings_pasted,blueprints.on_pasted)
script.on_event({defines.events.on_pre_surface_deleted,defines.events.on_pre_surface_cleared},lifecycle.on_surface_removed)
script.on_event(defines.events.on_forces_merging,lifecycle.on_forces_merging)

local configurator = require('scripts.services.configurator')
script.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity,
  defines.events.script_raised_built,defines.events.script_raised_revive},lifecycle.on_built)
script.on_event({defines.events.on_player_mined_entity,defines.events.on_robot_mined_entity,
  defines.events.on_entity_died,defines.events.script_raised_destroy},lifecycle.on_removed)
script.on_event(defines.events.on_entity_cloned,lifecycle.on_cloned)
script.on_event(defines.events.on_player_rotated_entity,lifecycle.on_rotated)
script.on_event(defines.events.on_tick,function(event) scheduler.tick(event.tick) end)
-- on_load deliberately has no handler: it executes no source and changes no state.
-- Opt-in exact-archive harness: one mod owns native entity events. Loading the
-- same lifecycle in a second mod would create duplicate physical helpers.
if script.active_mods['tc-smoke'] and settings.startup['tc-smoke-production-fixture'] then
  local name=settings.startup['tc-smoke-production-fixture'].value
  assert(name=='tests.lifecycle_engine','unknown production-context fixture')
  local test=require(name) -- control parsing only; never a guest source loader
  script.on_init(function()
    registry.initialize(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing()
    test.run(); log('TC_SMOKE_OK')
  end)
  script.on_load(test.on_load)
  script.on_event(defines.events.on_tick,test.on_tick)
  script.on_configuration_changed(function()
    registry.initialize(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing()
    test.on_configuration_changed()
  end)
end
