function start(event)
  local members, seen = {}, {}
  for _, wire in ipairs({"red", "green"}) do
    for _, name in ipairs(peripheral.getNames(wire)) do
      if not seen[name] and peripheral.getType(name, wire) == "monitor" then
        seen[name] = true
        members[#members + 1] = {name = name, wire = wire}
      end
    end
  end
  peripheral.setMonitorSyncGroup(members)
  computer.log("Selected synchronized monitors")
end
