-- Opt-in red/green entry points, packaged against real runtime modules.
local runtime=require('tests.runtime_contract')
return {run=runtime.resource_policy}
