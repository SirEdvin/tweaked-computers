function start()
  local stats = peripheral.find("production_statistics", "red")
  assert(stats, "Connect a Production Statistics device with red wire")
  local items = stats.getTotals("item")
  local normal = items.input.normal or {}
  computer.log("Iron produced: " .. tostring(normal["iron-plate"] or 0))

  local fluids = stats.getRates("fluid", "one_minute")
  computer.log("Water consumed/min: " .. tostring(fluids.output.water or 0))

  local pollution = stats.getTotals("pollution")
  for name, amount in pairs(pollution.input) do
    computer.log(name .. " emitted " .. tostring(amount))
  end

  local history = stats.getHistory("item", "iron-plate", "one_minute", "normal")
  computer.log("Newest iron production/min: " .. tostring(history.input[1]))
end
