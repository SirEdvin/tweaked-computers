-- Scoped native reads/policy; logic_policy retains the strict large-filter gate.
local fixture=require('tests.logic_policy')
return {run=function() fixture.run(true) end,on_load=fixture.on_load,on_tick=fixture.on_tick}
