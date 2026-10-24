-- Preserve the original work-refusal cold gate; exercise memory refusal separately.
local bounded=require('tests.compiler_bounded')
return {
  run=function() bounded.run(true) end,
  on_load=bounded.on_load,
  on_tick=bounded.on_tick,
}
