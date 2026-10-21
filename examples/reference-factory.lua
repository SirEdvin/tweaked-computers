-- Small in-game Reference tutorial; host wrapper is not guest source.
return [[function start(event)
  local cfg = peripheral.find("configurator", "red")
  assert(cfg, "Connect a Configurator on red")
  local target = nil
  for _, device in ipairs(cfg.getDevices("green")) do
    if device.type == "inserter" then
      assert(not target, "Use only one target inserter")
      target = device
    end
  end
  assert(target, "Connect an inserter on TARGETS green")
  cfg.setConfiguration(target.id, {set = {
    circuit_enable_disable = true,
    circuit_condition = {
      first_signal = {type = "virtual", name = "signal-A"},
      comparator = ">", constant = 0
    }
  }}, "green")
  computer.every(60, "update")
end

function update(event)
  local io = peripheral.find("logic_handler", "red")
  local db = peripheral.find("kv_database", "red")
  local screen = peripheral.find("monitor", "red")
  assert(io and db and screen, "Connect logic, database and monitor on red")
  local count = io.readSignal("red", {type = "item", name = "iron-plate"})
  local output = 0
  local status = "STOPPED"
  if count < 100 then
    output = 1
    status = "FILLING"
  end
  io.setOutput({{signal = {type = "virtual", name = "signal-A"}, count = output}})
  db.hset("stock:iron", "count", tostring(count), "status", status)
  db.expire("stock:iron", 3)
  screen.setCursorPos(1, 1)
  screen.write("Iron: " .. tostring(count) .. "    ")
  screen.setCursorPos(1, 2)
  screen.write(status .. "    ")
end
]]
