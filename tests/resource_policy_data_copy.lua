local fixture=require('tests.resource_policy_data')
return {run=function() fixture.run('copy') end,on_load=fixture.on_load,on_tick=fixture.on_tick}
