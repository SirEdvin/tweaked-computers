-- Copy the document inside the long brackets into the editor; Save, then Run.
-- Wiring and exact actions: docs/factory-example.md. No external file loading.
return [[return {
  api_version = 1,
  handlers = {
    start = function(event)
      local io = peripheral.find("logic_handler", "red")
      local db = peripheral.find("kv_database", "red")
      local monitor = peripheral.find("monitor", "red")
      local cfg = peripheral.find("configurator", "red")
      assert(io and db and monitor and cfg, "Connect all four peripherals")
      computer.setState("starts", (computer.getState("starts") or 0) + 1)
      if computer.getState("enabled") == nil then computer.setState("enabled", true) end
      local configured = 0
      for _, device in ipairs(cfg.getDevices("green")) do
        if device.type == "inserter" then
          local caps = cfg.getCapabilities(device.id, "green")
          local enable = caps.settings.circuit_enable_disable
          local condition = caps.settings.circuit_condition
          if enable and enable.writable and condition and condition.writable then
            cfg.setConfiguration(device.id, {set = {
              circuit_enable_disable = true,
              circuit_condition = {
                first_signal = {type = "virtual", name = "signal-A", quality = "normal"},
                comparator = ">", constant = 0
              }
            }}, "green")
            configured = configured + 1
          end
        end
      end
      assert(configured > 0, "Connect a configurable inserter to the target port")
      -- Full expansion capability readback and subscription admission share
      -- the callback ceiling; finish setup on the next real simulation tick.
      computer.after(1, "ready")
    end,
    ready = function(event)
      local io = peripheral.find("logic_handler", "red")
      local monitor = peripheral.find("monitor", "red")
      assert(io and monitor, "Required peripheral disconnected during setup")
      monitor.setTextScale(1)
      io.subscribe({input = "red", signals = {
        {type = "item", name = "iron-plate", quality = "normal"}
      }, initial = true}, "changed")
      computer.on("monitor_touch", "touched")
      computer.on("monitor_resize", "resized")
      computer.every(60, "refresh")
      computer.after(1, "refresh")
    end,
    changed = function(event)
      computer.after(1, "refresh")
    end,
    touched = function(event)
      local monitor = peripheral.find("monitor", "red")
      if monitor and event.peripheral == peripheral.getName(monitor) then
        computer.setState("enabled", not computer.getState("enabled"))
        computer.after(1, "refresh")
      end
    end,
    resized = function(event)
      computer.after(1, "refresh")
    end,
    refresh = function(event)
      local io = peripheral.find("logic_handler", "red")
      local db = peripheral.find("kv_database", "red")
      local monitor = peripheral.find("monitor", "red")
      assert(io and db and monitor, "Required peripheral disconnected")
      local count = io.readSignal("red", {type = "item", name = "iron-plate", quality = "normal"})
      local output = 0
      if computer.getState("enabled") and count < 100 then output = 1 end
      io.setOutput({{signal = {type = "virtual", name = "signal-A", quality = "normal"}, count = output}})
      local status = "STOPPED"
      if output == 1 then status = "FILLING" end
      db.hset("stock:iron", "count", tostring(count), "status", status,
        "sample_tick", tostring(computer.getTick()))
      db.expire("stock:iron", 3)
      monitor.setBackgroundColor(colors.black)
      monitor.setTextColor(colors.white)
      monitor.clear()
      monitor.setCursorPos(1, 1)
      monitor.write("Iron: " .. tostring(count))
      monitor.setCursorPos(1, 2)
      monitor.setTextColor(colors.lime)
      monitor.write(status)
      monitor.setCursorPos(1, 3)
      monitor.write("Touch to toggle")
    end
  }
}]]
