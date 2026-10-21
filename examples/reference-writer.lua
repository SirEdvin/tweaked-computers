-- First computer in the in-game shared-data tutorial.
return [[function start(event)
  local db = peripheral.find("kv_database", "red")
  assert(db, "Connect the shared database on red")
  db.hset("stock:iron", "count", "5", "status", "FILLING")
end
]]
