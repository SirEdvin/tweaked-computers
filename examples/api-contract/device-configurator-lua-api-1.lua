function start(event)
  local cfg = peripheral.find("configurator", "red")
  if not cfg then return end
  for _, device in ipairs(cfg.getDevices("green")) do
    computer.log(device.prototype .. " at " ..
      tostring(device.position.x) .. "," .. tostring(device.position.y))
    if device.type == "inserter" then
      local caps = cfg.getCapabilities(device.id, "green")
      local enable = caps.settings.circuit_enable_disable
      local condition = caps.settings.circuit_condition
      if enable and enable.writable and condition and condition.writable then
        cfg.setConfiguration(device.id, {
          set = {
            circuit_enable_disable = true,
            circuit_condition = {
              comparator = ">",
              first_signal = { type = "virtual", name = "signal-A", quality = "normal" },
              constant = 0
            }
          }
        }, "green")
      end
    end
  end
end
