function start(event)
  computer.on("monitor_touch", "touched")
  computer.on("monitor_resize", "resized")
  local m = peripheral.find("monitor", "red")
  if m then
    m.setBackgroundColor(colors.black)
    m.setTextColor(colors.lime)
    m.clear()
    m.setCursorPos(1, 1)
    m.write("READY")
  end
end

function touched(event)
  local m = peripheral.wrap(event.peripheral, event.wire)
  if m then
    m.setCursorPos(1, 1)
    m.write(tostring(event.x) .. "," .. tostring(event.y))
  end
end

function resized(event)
  local m = peripheral.wrap(event.peripheral, event.wire)
  if m then
    m.setCursorPos(1, 1)
    m.write("RESIZED")
  end
end
