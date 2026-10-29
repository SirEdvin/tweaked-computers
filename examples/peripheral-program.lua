-- Trusted source-text fixture; copy the document inside [[...]] into the editor.
-- It runs as a native named-callback program, not a host require extension.
return [[function start(event)
  computer.on('peripheral_attach', 'changed')
  computer.on('peripheral_detach', 'changed')
  for _, wire in ipairs({'red', 'green'}) do
    local names = peripheral.getNames(wire)
    computer.setState('names_' .. wire, names)
    for _, name in ipairs(names) do
      local info = peripheral.describe(name, wire)
      local device = peripheral.wrap(name, wire)
      if info and device then
        local capacities = device.getLimits()
        computer.log(wire .. ' / ' .. peripheral.getName(device) .. ' / ' .. info.type)
        assert(peripheral.getWire(device) == wire and type(capacities) == 'table')
      end
    end
  end
end

function changed(event)
  computer.log(event.name .. ' / ' .. event.wire .. ' / ' .. event.peripheral)
  local ok, names = pcall(peripheral.getNames, event.wire)
  if ok then computer.setState('names_' .. event.wire, names)
  else computer.log('Discovery unavailable; retry after the next topology event or timer.') end
end]]
