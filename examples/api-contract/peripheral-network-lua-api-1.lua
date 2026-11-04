function start(event)
  for _, wire in ipairs({ "red", "green" }) do
    for _, name in ipairs(peripheral.getNames(wire)) do
      local info = peripheral.describe(name, wire)
      if info then
        computer.log(wire .. " / " .. name .. " / " .. info.type)
      end
    end
  end
end
