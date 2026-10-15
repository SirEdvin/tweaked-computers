# Complete runnable programs

Copy a whole code block into the [single-document editor](editor.md), Validate,
Save, then Run. These are the exact shipped source documents, with host wrappers
removed. There is no guest require/file import. Small fixtures are not unlimited
factory managers; keep the described topology. Runtime effects were exercised by
the implementation harness; documentation checks compile these blocks without
claiming graphical keyboard/focus/touch delivery.

## peripheral-program

Wire a computer NETWORK to any device NETWORK on red. Inspect each color in Peripherals; read program output in Console.

```lua
return {
  api_version = 1,
  handlers = {
    start = function(event)
      computer.on('peripheral_attach', 'changed')
      computer.on('peripheral_detach', 'changed')
      for _, wire in ipairs({'red', 'green'}) do
        local names = peripheral.getNames(wire)
        computer.setState('names_' .. wire, names)
        for _, name in ipairs(names) do
          local info = peripheral.describe(name, wire)
          local device = peripheral.wrap(name, wire)
          if info and device then
            local capacities = device.getLimits()
            computer.log(wire .. ' / ' .. peripheral.getName(device) .. ' / ' .. info.type)
            assert(peripheral.getWire(device) == wire and type(capacities) == 'table')
          end
        end
      end
    end,
    changed = function(event)
      computer.log(event.name .. ' / ' .. event.wire .. ' / ' .. event.peripheral)
      local ok, names = pcall(peripheral.getNames, event.wire)
      if ok then computer.setState('names_' .. event.wire, names)
      else computer.log('Discovery unavailable; retry after the next topology event or timer.') end
    end
  }
}
```

## logic-controller

Follow [your first inserter controller](first-controller.md). Stock INPUT red, discovery NETWORK red, OUTPUT to the inserter.

```lua
return {
  api_version = 1,
  handlers = {
    start = function(event)
      computer.setState("starts", (computer.getState("starts") or 0) + 1)
      local io = peripheral.find("logic_handler", "red")
      assert(io, "Wire a logic NETWORK port to the computer on red")
      io.subscribe({input="red", signals={{type="item",name="iron-plate",quality="normal"}}, initial=true}, "changed")
      computer.log("Controller subscribed")
    end,
    changed = function(event)
      local io = peripheral.wrap(event.peripheral, event.wire)
      if not io then return end
      local stock = 0
      for _,entry in ipairs(event.current) do stock=entry.count end
      local enabled = 0
      if stock < 100 then enabled=1 end
      io.setOutput({{signal={type="virtual",name="signal-A",quality="normal"},count=enabled}})
      computer.setState("stock", stock)
      computer.setState("sample_tick", event.sample_tick)
      computer.setState("last_changes", event.changes)
      computer.setState("input_connected", event.connected)
      computer.setState("resync", event.resync)
    end
  }
}
```

## kv-program

Connect one powered database NETWORK on red. Save/Run; inspect the delayed status/TTL in Console.

```lua
return {
  api_version=1,
  handlers={
    start=function(event)
      local db=peripheral.find('kv_database','red')
      if not db then return end
      db.hset('machine','status','ready','owner',computer.getID())
      db.expire('machine',30)
      computer.after(60,'inspect')
    end,
    inspect=function(event)
      local db=peripheral.find('kv_database','red')
      if not db then return end
      local fields=db.hgetall('machine')
      computer.log(fields.status or 'expired')
      computer.log('TTL='..tostring(db.ttl('machine')))
    end
  }
}
```

## monitor-program

Connect a powered monitor NETWORK on red. Run, then activate a character cell; use matching adjacent tiles to test resize.

```lua
return {api_version=1,handlers={
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
}}
```

## configurator-program

Discovery NETWORK red; separate TARGETS green to one inserter. Sets A > 4, not A > 0. Supply an external A signal of at least 5 for motion.

```lua
return {api_version=1,handlers={start=function(e)
  local cfg=peripheral.find('configurator','red'); assert(cfg)
  local devices=cfg.getDevices('green')
  for _,device in ipairs(devices) do
    if device.type=='inserter' then
      cfg.setConfiguration(device.id,{set={
        circuit_enable_disable=true,
        circuit_condition={first_signal={type='virtual',name='signal-A'},comparator='>',constant=4}
      }},'green')
      computer.setState('configured',device.id)
    end
  end
end}}
```

## configurator-sections

Discovery NETWORK red; TARGETS green to one constant combinator. Adds a section, activates it and saves its actual index in computer state; it intentionally writes no signal filters.

```lua
return {api_version=1,handlers={start=function(event)
  local cfg=peripheral.find('configurator','red'); assert(cfg)
  for _,device in ipairs(cfg.getDevices('green')) do
    if device.type=='constant-combinator' then
      local index=cfg.addSection(device.id,{active=false},'green')
      cfg.setSection(device.id,index,{set={active=true}},'green')
      computer.setState('section',index)
    end
  end
end}}
```

## factory-controller

Follow the complete [factory wiring tutorial](factory.md). Keep one device per type reachable. Paste this whole document.

```lua
return {
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
}
```

## shared-telemetry

Use the [second-computer setup](factory.md#second-computer-shared-and-private-data): shared database on red, separate physical database on green.

```lua
return {
  api_version = 1,
  handlers = {
    start = function(event)
      local shared = peripheral.find("kv_database", "red")
      local independent = peripheral.find("kv_database", "green")
      assert(shared and independent, "Connect one database on each color")
      assert(peripheral.getName(shared) ~= peripheral.getName(independent), "Use two physical databases")
      shared.set("observer", computer.getID())
      independent.set("observer", "private")
      computer.every(60, "inspect")
    end,
    inspect = function(event)
      local shared = peripheral.find("kv_database", "red")
      local independent = peripheral.find("kv_database", "green")
      assert(shared and independent, "Database disconnected")
      local stock = shared.hgetall("stock:iron")
      computer.setState("shared_status", stock.status or "expired")
      computer.setState("shared_count", stock.count or "expired")
      computer.setState("private_status", independent.hget("stock:iron", "status") or "absent")
      computer.setState("observer", shared.get("observer"))
      computer.log((stock.status or "expired") .. " / private=" .. independent.get("observer"))
    end
  }
}
```
