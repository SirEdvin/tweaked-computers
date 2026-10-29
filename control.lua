local budgets = require('scripts.runtime.budget-settings')
-- Rebuild only ephemeral effective limits at control parsing, including reload.
-- Never renew retained tick credits or execute player source here.
budgets.refresh()
script.on_event(defines.events.on_runtime_mod_setting_changed,budgets.refresh)
local registry = require('scripts.registry')
-- All trusted imports and hook registration occur at control parsing time.
local scheduler = require('scripts.scheduler')
if script.active_mods['tc-smoke'] and settings.startup['tc-smoke-production-fixture']
  and settings.startup['tc-smoke-production-fixture'].value=='tests.monitor_demand_engine' then
  require('tests.monitor_demand_observer')
end
local lifecycle = require('scripts.lifecycle')
local peripheral = require('scripts.services.peripheral')
local editor = require('scripts.ui.editor')
local interaction = require('scripts.ui.interaction')
local inspector = require('scripts.ui.peripheral-inspector')
local logic = require('scripts.services.logic')
local kv = require('scripts.services.kv')
local monitor = require('scripts.services.monitor')
local recipe_searcher = require('scripts.services.recipe-searcher')
local factoriopedia_interface = require('scripts.services.factoriopedia-interface')
local production_statistics = require('scripts.services.production-statistics')
local modem = require('scripts.services.modem')
local speaker = require('scripts.services.speaker')
local snapshots = require('scripts.lifecycle-data')
local blueprints = require('scripts.blueprints')
local computer_undo = require('scripts.computer-undo')
script.on_event(defines.events.on_marked_for_deconstruction,computer_undo.on_marked)
script.on_event(defines.events.on_cancelled_deconstruction,computer_undo.on_cancelled)
script.on_event({defines.events.on_undo_applied,defines.events.on_redo_applied},computer_undo.on_applied)
local device_art = require('scripts.device-art')
editor.register_inspector(require('scripts.ui.network-inspector'))
script.on_event(defines.events.on_gui_opened,interaction.on_opened)
script.on_event(defines.events.on_gui_closed,function(event) editor.on_closed(event); inspector.on_closed(event) end)
script.on_event(defines.events.on_gui_click,function(event) editor.on_click(event); inspector.on_click(event) end)
script.on_event(defines.events.on_gui_text_changed,editor.on_text)
script.on_event(defines.events.on_gui_confirmed,editor.on_confirmed)
script.on_event(defines.events.on_gui_selected_tab_changed,editor.on_tab)
script.on_event(defines.events.on_gui_selection_state_changed,editor.on_selection)
script.on_event(defines.events.on_gui_checked_state_changed,editor.on_checked)
script.on_event('tc-interact',interaction.on_input)
script.on_event({'tc-rotate','tc-reverse-rotate'},interaction.on_rotate)
script.on_event({defines.events.on_player_left_game,defines.events.on_player_died,
  defines.events.on_player_changed_force,defines.events.on_player_changed_surface},function(event)
    editor.on_player_unavailable(event); inspector.on_player_unavailable(event)
  end)
script.on_event({defines.events.on_player_display_resolution_changed,
  defines.events.on_player_display_scale_changed},function(event) editor.on_size(event); inspector.on_size(event) end)
script.on_init(function() registry.initialize(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing() end)
script.on_configuration_changed(function() registry.initialize(); lifecycle.upgrade_existing(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing() end)
script.on_event(defines.events.on_player_setup_blueprint,blueprints.on_setup)
script.on_event(defines.events.on_entity_settings_pasted,blueprints.on_pasted)
script.on_event({defines.events.on_pre_surface_deleted,defines.events.on_pre_surface_cleared},lifecycle.on_surface_removed)
script.on_event(defines.events.on_forces_merging,lifecycle.on_forces_merging)
script.on_event(defines.events.on_object_destroyed,function(event) lifecycle.on_object_destroyed(event); computer_undo.on_destroyed(event) end)

local configurator = require('scripts.services.configurator')
script.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity,
  defines.events.on_space_platform_built_entity,defines.events.script_raised_built,defines.events.script_raised_revive},lifecycle.on_built)
script.on_event({defines.events.on_player_mined_entity,defines.events.on_robot_mined_entity,
  defines.events.on_space_platform_mined_entity,defines.events.on_entity_died,defines.events.script_raised_destroy},lifecycle.on_removed)
script.on_event(defines.events.on_entity_cloned,lifecycle.on_cloned)
script.on_event(defines.events.on_player_rotated_entity,lifecycle.on_rotated)
script.on_event(defines.events.on_tick,function(event) scheduler.tick(event.tick) end)
-- on_load deliberately has no handler: it executes no source and changes no state.
-- Opt-in exact-archive harness: one mod owns native entity events. Loading the
-- same lifecycle in a second mod would create duplicate physical helpers.
if script.active_mods['tc-smoke'] and settings.startup['tc-smoke-production-fixture'] then
  local name=settings.startup['tc-smoke-production-fixture'].value
  local monitor_state_fixture={['tests.monitor_demand_engine']=true,['tests.monitor_state_idle']=true,['tests.monitor_state_pending']=true,
    ['tests.monitor_state_waiting']=true,['tests.monitor_state_preparing']=true,
    ['tests.monitor_state_ready']=true,['tests.monitor_state_retiring']=true,
    ['tests.acceptance_monitor_engine']=true,['tests.editor_reference_client_engine']=true,['tests.peripheral_inspector_engine']=true,
    ['tests.peripheral_inspector_client_engine']=true,['tests.peripheral_inspector_upgrade_engine']=true,['tests.ui_live_client_engine']=true,
    ['tests.reference_tutorials_engine']=true,['tests.native_circuit_engine']=true,['tests.native_circuit_upgrade_engine']=true,
    ['tests.factoriopedia_engine']=true,['tests.factoriopedia_large_engine']=true,['tests.factoriopedia_client_engine']=true,
    ['tests.production_statistics_engine']=true,['tests.production_statistics_large_engine']=true,['tests.production_statistics_client_engine']=true,
    ['tests.production_statistics_timing_engine']=true}
  assert(monitor_state_fixture[name] or name=='tests.speaker_competition_engine' or name=='tests.speaker_engine' or name=='tests.speaker_client_engine' or name=='tests.modem_competition_engine' or name=='tests.radar_client_engine' or name=='tests.radar_engine' or name=='tests.modem_engine' or name=='tests.acceptance_client_engine' or name=='tests.logic_recipe_engine' or name=='tests.recipe_searcher_client_engine' or name=='tests.recipe_searcher_engine' or name=='tests.shell_client_engine' or name=='tests.shell_cold' or name=='tests.lifecycle_engine' or name=='tests.integration_engine' or name=='tests.redesign_engine' or name=='tests.monitor_feedback_engine' or name=='tests.rd1_upgrade_engine' or name=='tests.monitor_budget_engine' or name=='tests.monitor_presentation_engine' or name=='tests.monitor_plot_baseline_engine' or name=='tests.runtime_budget_engine' or name=='tests.monitor_animation_engine','unknown production-context fixture')

  local test=require(name) -- control parsing only; never a guest source loader
  script.on_init(function()
    registry.initialize(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing()
    test.run(); log('TC_SMOKE_OK')
  end)
  script.on_load(test.on_load)
  script.on_event(defines.events.on_tick,test.on_tick)
  script.on_configuration_changed(function()
    registry.initialize(); lifecycle.upgrade_existing(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing()
    test.on_configuration_changed()
  end)
  if test.on_player_joined then
    script.on_event({defines.events.on_player_created,defines.events.on_player_joined_game},test.on_player_joined)
  end
end
-- Isolated Production Statistics installation driver.
if script.active_mods['tc-statistics-upgrade'] then
  local test=require('tests.production_statistics_upgrade_engine')
  script.on_init(function()
    registry.initialize(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing()
    test.run(); log('TC_SMOKE_OK')
  end)
  script.on_load(test.on_load)
  script.on_event(defines.events.on_tick,test.on_tick)
  script.on_configuration_changed(function()
    registry.initialize(); lifecycle.upgrade_existing(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing()
    test.on_configuration_changed()
  end)
end
-- End isolated Production Statistics installation driver.
-- Isolated Factoriopedia installation driver.
if script.active_mods['tc-factoriopedia-upgrade'] then
  local test=require('tests.factoriopedia_upgrade_engine')
  script.on_init(function()
    registry.initialize(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing()
    test.run(); log('TC_SMOKE_OK')
  end)
  script.on_load(test.on_load)
  script.on_event(defines.events.on_tick,test.on_tick)
  script.on_configuration_changed(function()
    registry.initialize(); lifecycle.upgrade_existing(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing()
    test.on_configuration_changed()
  end)
end
-- End isolated Factoriopedia installation driver.
-- Isolated speaker installation driver. The companion is never shipped.
if script.active_mods['tc-speaker-upgrade'] then
  local test=require('tests.speaker_upgrade_engine')
  script.on_init(function()
    registry.initialize(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing()
    test.run(); log('TC_SMOKE_OK')
  end)
  script.on_load(test.on_load)
  script.on_event(defines.events.on_tick,test.on_tick)
  script.on_configuration_changed(function()
    registry.initialize(); lifecycle.upgrade_existing(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing()
    test.on_configuration_changed()
  end)
end
-- End isolated speaker installation driver.
-- Isolated radar installation driver. The companion is never shipped.
if script.active_mods['tc-radar-upgrade'] then
  local test=require('tests.radar_upgrade_engine')
  script.on_init(function()
    registry.initialize(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing()
    test.run(); log('TC_SMOKE_OK')
  end)
  script.on_load(test.on_load)
  script.on_event(defines.events.on_tick,test.on_tick)
  script.on_configuration_changed(function()
    registry.initialize(); lifecycle.upgrade_existing(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing()
    test.on_configuration_changed()
  end)
end
-- End isolated radar installation driver.
-- Isolated radar-tracking installation driver. The companion is never shipped.
if script.active_mods['tc-radar-tracking-upgrade'] then
  local test=require('tests.radar_tracking_upgrade_engine')
  script.on_init(function()
    registry.initialize(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing()
    test.run(); log('TC_SMOKE_OK')
  end)
  script.on_load(test.on_load)
  script.on_event(defines.events.on_tick,test.on_tick)
  script.on_configuration_changed(function()
    registry.initialize(); lifecycle.upgrade_existing(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing()
    test.on_configuration_changed()
  end)
end
-- End isolated radar-tracking installation driver.
-- Isolated recipe-searcher installation driver. The companion is never shipped.
if script.active_mods['tc-recipe-upgrade'] then
  local test=require('tests.recipe_searcher_upgrade_engine')
  script.on_init(function()
    registry.initialize(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing()
    test.run(); log('TC_SMOKE_OK')
  end)
  script.on_load(test.on_load)
  script.on_event(defines.events.on_tick,test.on_tick)
  script.on_configuration_changed(function()
    registry.initialize(); lifecycle.upgrade_existing(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing()
    test.on_configuration_changed()
  end)
end
-- Isolated released-save upgrade driver. The companion is never shipped.
if script.active_mods['tc-buffer-upgrade'] and settings.startup['tc-buffer-upgrade-run']
  and settings.startup['tc-buffer-upgrade-run'].value then
  local test=require('tests.monitor_upgrade_engine')
  script.on_init(function()
    registry.initialize(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing()
    test.run(); log('TC_SMOKE_OK')
  end)
  script.on_load(test.on_load)
  script.on_event(defines.events.on_tick,test.on_tick)
  script.on_configuration_changed(function(event)
    registry.initialize(); lifecycle.upgrade_existing(); lifecycle.unlocks(); kv.initialize_existing(); snapshots.initialize_existing()
    test.on_configuration_changed(event)
  end)
end
