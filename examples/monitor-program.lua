-- Native API v1 source; paste the returned document into the single-source editor.
return [[return {api_version=1,handlers={
  start=function(event)
    computer.on('monitor_touch','touched')
    computer.on('monitor_resize','resized')
    local m=peripheral.find('monitor','red')
    if m then
      m.setBackgroundColour(colors.black); m.setTextColour(colors.lime)
      m.clear(); m.setCursorPos(1,1); m.write('READY')
    end
  end,
  touched=function(event)
    local m=peripheral.wrap(event.peripheral,event.wire)
    if m then
      m.setCursorPos(1,1)
      m.write(tostring(event.x)..','..tostring(event.y))
    end
  end,
  resized=function(event)
    local m=peripheral.wrap(event.peripheral,event.wire)
    if m then m.setCursorPos(1,1); m.write('RESIZED') end
  end
}}]]
