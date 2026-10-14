-- Minimal versioned root. Entity binding/identity lifecycle is completed in TC03.
local limits = require('scripts.runtime.limits')
local M = {}
function M.initialize()
  if storage.tweaked_computers then
    assert(storage.tweaked_computers.schema_version == limits.storage_version, 'unsupported Tweaked Computers storage; data retained')
    return storage.tweaked_computers
  end
  storage.tweaked_computers = {schema_version = limits.storage_version, next_id = 1,
    entities = {}, computers = {}, devices = {}, player_drafts = {}}
  return storage.tweaked_computers
end
function M.get() return storage.tweaked_computers end
return M
