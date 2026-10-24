-- Contract inventory exercised as actual compiled guest source in the factory.
return [[return {api_version=1,handlers={start=function(event)
  assert(type(computer.getID)=='function' and type(computer.getLabel)=='function')
  assert(type(computer.setLabel)=='function' and type(computer.getTick)=='function')
  assert(type(computer.getLimits)=='function' and type(computer.getState)=='function')
  assert(type(computer.getResourceStatus)=='function')
  local status=computer.getResourceStatus()
  assert(status.policy_version==2 and type(status.resources)=='table' and type(status.dropped_events.total)=='number')
  assert(type(computer.setState)=='function' and type(computer.deleteState)=='function')
  assert(type(computer.log)=='function' and type(computer.stop)=='function')
  assert(type(computer.on)=='function' and type(computer.off)=='function')
  assert(type(computer.after)=='function' and type(computer.every)=='function' and type(computer.cancelTimer)=='function')
  for _,method in ipairs({'getNames','isPresent','getType','getMethods','describe','wrap','call','find','getName','getWire','setMonitorSyncGroup','getMonitorSyncGroup'}) do
    assert(type(peripheral[method])=='function')
  end
  local expected={
    speaker={'getInstruments','getLimits','getNotes','getSounds','playNote','playSound'},
    modem={'open','isOpen','close','closeAll','transmit','isWireless','getLimits'},
    recipe_searcher={'findRecipes','getLimits'},
    kv_database={'get','set','del','exists','type','hget','hset','hdel','hexists','hgetall','hlen','expire','ttl','persist','getLimits'},
    logic_handler={'readSignal','readSignals','getInputStatus','getOutput','setOutput','clearOutput','subscribe','unsubscribe','getLimits'},
    configurator={'getDevices','getDevice','getCapabilities','getConfiguration','setConfiguration','getLimits','getSections','addSection','setSection','removeSection'},
    monitor={'write','blit','clear','clearLine','scroll','getSize','getCursorPos','setCursorPos','getCursorBlink','setCursorBlink',
      'getTextColor','getTextColour','setTextColor','setTextColour','getBackgroundColor','getBackgroundColour',
      'setBackgroundColor','setBackgroundColour','isColor','isColour','setPaletteColor','setPaletteColour',
      'getPaletteColor','getPaletteColour','getTextScale','setTextScale','getLimits'}
  }
  for kind,list in pairs(expected) do
    local device=peripheral.find(kind,'red')
    -- Legacy factory scenes have no radar; the native modem fixture separately
    -- requires and exercises this same closed seven-method inventory.
    if kind~='modem' and kind~='speaker' or device then
      assert(device)
      local methods=peripheral.getMethods(peripheral.getName(device),'red')
      table.sort(list); assert(#list==#methods)
      for i,name in ipairs(list) do assert(name==methods[i] and type(device[name])=='function') end
    end
  end
  assert(colours==colors and colors.grey==colors.gray and colors.lightGrey==colors.lightGray)
  computer.setState('api_inventory',true)
end}}]]
