-- Copy only the long-bracket document into a second computer; Save, then Run.
-- Red NETWORK reaches the controller's database. A separate green NETWORK
-- reaches a second database, with no complete green path to the shared one.
return [[function start(event)
  local shared = peripheral.find("kv_database", "red")
  local independent = peripheral.find("kv_database", "green")
  assert(shared and independent, "Connect one database on each color")
  assert(peripheral.getName(shared) ~= peripheral.getName(independent), "Use two physical databases")
  shared.set("observer", computer.getID())
  independent.set("observer", "private")
  computer.every(60, "inspect")
end

function inspect(event)
  local shared = peripheral.find("kv_database", "red")
  local independent = peripheral.find("kv_database", "green")
  assert(shared and independent, "Database disconnected")
  local stock = shared.hgetall("stock:iron")
  computer.setState("shared_status", stock.status or "expired")
  computer.setState("shared_count", stock.count or "expired")
  computer.setState("private_status", independent.hget("stock:iron", "status") or "absent")
  computer.setState("observer", shared.get("observer"))
  computer.log((stock.status or "expired") .. " / private=" .. independent.get("observer"))
end]]
