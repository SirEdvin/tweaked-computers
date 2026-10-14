local registry = require('scripts.registry')
-- Import trusted runtime during control parsing, never inside event handlers.
local compiler = require('scripts.runtime.compiler')
script.on_init(function() registry.initialize() end)
script.on_configuration_changed(function() registry.initialize() end)
-- on_load deliberately runs no user source and mutates no durable state.
