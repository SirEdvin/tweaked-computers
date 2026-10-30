-- Complete guest document; no imports or native prototype access.
return [[function start(event)
  local encyclopedia = peripheral.find("factoriopedia_interface", "red")
  assert(encyclopedia, "Connect a Factoriopedia Interface on red")
  local item = encyclopedia.getItem("iron-plate")
  computer.log(item.name .. " stack size=" .. tostring(item.stack_size))
  if item.rocket_capacity ~= nil then
    computer.log("Reference items per rocket=" .. tostring(item.rocket_capacity))
  else
    computer.log("No finite mass-limited rocket count")
  end
  local fluid = encyclopedia.getFluid("water")
  computer.log(fluid.name .. " temperature=" .. tostring(fluid.default_temperature)
    .. ".." .. tostring(fluid.max_temperature) .. " C")
  local function reportNames(method, label)
    local ok, result = pcall(method)
    if ok then
      computer.log(label .. ": " .. tostring(#result))
    elseif type(result) == "table" and result.code == "E_LIMIT" then
      computer.log(label .. ": complete list exceeds shared Data limits")
    else
      error(result)
    end
  end
  reportNames(encyclopedia.listItems, "Installed item names")
  reportNames(encyclopedia.listFluids, "Installed fluid names")
  computer.setState("factoriopedia_example", true)
end]]
