function start(event)
  local db = peripheral.find("kv_database", "red")
  if not db then
    computer.log("Connect a database on red NETWORK")
    return
  end
  local ok, value = pcall(db.get, "counter")
  if ok then
    computer.log(value or "No counter yet")
  elseif type(value) == "table" then
    computer.log(value.code .. ": " .. value.message)
  else
    computer.log(tostring(value))
  end
end
