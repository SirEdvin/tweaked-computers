local registry = require('scripts.registry')
-- All trusted imports and hook registration occur at control parsing time.
local scheduler = require('scripts.scheduler')
script.on_init(function() registry.initialize() end)
script.on_configuration_changed(function() registry.initialize() end)
script.on_event(defines.events.on_tick,function(event) scheduler.tick(event.tick) end)
-- on_load deliberately has no handler: it executes no source and changes no state.
