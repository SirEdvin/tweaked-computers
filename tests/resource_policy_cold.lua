local cold=require('tests.computer_cold')
return {run=cold.resource_policy_run,on_load=cold.resource_policy_load,on_tick=cold.resource_policy_tick}
