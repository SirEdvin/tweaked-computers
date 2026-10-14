-- Test-only native burner assembler: the base game has no burner assembler.
-- Load only from the isolated tc-smoke data stage, never production data.lua.
local machine=table.deepcopy(data.raw['assembling-machine']['assembling-machine-1'])
machine.name='tc11-burner-assembling-machine'
machine.energy_source=table.deepcopy(data.raw.furnace['stone-furnace'].energy_source)
data:extend{machine}
