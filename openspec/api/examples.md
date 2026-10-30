# Integrated Lua examples and acceptance cases

These are maintained contract programs, not simulated execution transcripts. The planning check validates Lua 5.2 syntax and contract structure; actual editor/runtime execution and native-client observations are separately bound to the exact artifacts in the acceptance receipts. Static source alone never proves those gates.

## Case A: a configured, monitored stock controller

Prepare one computer, one KV database, one logic handler, one configurator and a 2×2 monitor rectangle; none needs electricity. Native factory targets such as inserters retain their own power requirements. For this example there is exactly one peripheral of each type on the selected discovery channel, so `peripheral.find` is unambiguous. Production programs can bind explicitly to names from discovery instead.

Wiring:

```text
COMPUTER --red network--> KV --red network--> MONITOR member
   |
   +--red network--> LOGIC middle NETWORK port
   |
   +--red network--> CONFIGURATOR NETWORK port

stock-reading chest --red signals--> LOGIC INPUT port
LOGIC OUTPUT port --green signals--> inserter circuit network
CONFIGURATOR TARGET port --green--> that same inserter network
```

The red input cable and red discovery cables terminate at different physical roles. The configurator's red discovery and green target connections also remain separate. There is no red-to-green discovery path and no direct computer messaging. The chest must be configured to read contents; the example configures the connected inserters, not an unconnected chest.

Paste and save this document through the in-game editor, then Run:

```lua
function start(event)
  local io = peripheral.find("logic_handler", "red")
  local db = peripheral.find("kv_database", "red")
  local monitor = peripheral.find("monitor", "red")
  local cfg = peripheral.find("configurator", "red")
  assert(io and db and monitor and cfg, "Connect all four peripherals")

  if computer.getState("enabled") == nil then
    computer.setState("enabled", true)
  end
  local configured = 0
  for _, device in ipairs(cfg.getDevices("green")) do
    if device.type == "inserter" then
      local caps = cfg.getCapabilities(device.id, "green")
      local enable = caps.settings.circuit_enable_disable
      local condition = caps.settings.circuit_condition
      if enable and enable.writable and condition and condition.writable then
        cfg.setConfiguration(device.id, {
          set = {
            circuit_enable_disable = true,
            circuit_condition = {
              first_signal = { type = "virtual", name = "signal-A", quality = "normal" },
              comparator = ">", constant = 0
            }
          }
        }, "green")
        configured = configured + 1
      end
    end
  end
  assert(configured > 0, "Connect a configurable inserter to the target port")

  -- Configuration/capability readback and subscriptions share one callback
  -- ceiling. Admit the next setup phase on a later real simulation tick.
  computer.after(1, "ready")
end

function ready(event)
  local io = peripheral.find("logic_handler", "red")
  local monitor = peripheral.find("monitor", "red")
  assert(io and monitor, "Required peripheral disconnected during setup")
  monitor.setTextScale(1)
  io.subscribe({
    input = "red",
    signals = { { type = "item", name = "iron-plate", quality = "normal" } },
    initial = true
  }, "changed")
  computer.on("monitor_touch", "touched")
  computer.on("monitor_resize", "resized")
  computer.every(60, "refresh")
  computer.after(1, "refresh")
end

function changed(event)
  -- Coarse refresh also exists; this wakes it promptly for stock changes.
  computer.after(1, "refresh")
end

function touched(event)
  local monitor = peripheral.find("monitor", "red")
  if monitor and event.peripheral == peripheral.getName(monitor) then
    computer.setState("enabled", not computer.getState("enabled"))
    computer.after(1, "refresh")
  end
end

function resized(event)
  computer.after(1, "refresh")
end

function refresh(event)
  local io = peripheral.find("logic_handler", "red")
  local db = peripheral.find("kv_database", "red")
  local monitor = peripheral.find("monitor", "red")
  assert(io and db and monitor, "Required peripheral disconnected")

  -- Read current native input instead of acting on an old queued sample.
  local count = io.readSignal("red", {
    type = "item", name = "iron-plate", quality = "normal"
  })
  local output = 0
  if computer.getState("enabled") and count < 100 then output = 1 end
  io.setOutput({
    { signal = { type = "virtual", name = "signal-A", quality = "normal" }, count = output }
  })

  local status = "STOPPED"
  if output == 1 then status = "FILLING" end
  db.hset("stock:iron", "count", tostring(count),
    "status", status, "sample_tick", tostring(computer.getTick()))
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
```

Required engine/client observations:

1. A real native inserter's condition readback is signal-A > 0. Inventory movement occurs below the threshold and ceases above it after normal circuit/in-flight-item settling.
2. KV telemetry contains strings and a live whole-key deadline. Stopping the controller leaves recent telemetry temporarily readable, then it expires by simulation time.
3. The merged world display shows stock/status. Touch toggles the explicit persistent enabled value and changes output after actual tick propagation.
4. Removing the current writer's discovery path clears its owned output. The monitor image and already applied inserter configuration remain. This demonstration is fail-safe on loss; it is not an automatic reconnection manager.
5. Change the threshold in the editor, Save without Apply, and prove the old revision still controls the factory. Then Apply and prove the changed saved source changes actual behavior.
6. Cold-load while enabled is false and timers/subscriptions are retained. Startup configuration is not replayed; state remains false and only retained work resumes.
7. Resize the monitor; the model clears, then the resize callback redraws it. Probe the same character coordinates visually and through a real client interaction.

The example does not promise deduplication of independently scheduled refresh timers or global transactions. Each accepted operation is serialized and bounded; queue/resource overflow remains a visible failure under the shared contract.

## Case B: discover both colors without mixing them

Use the complete program in [peripheral-network/lua-api.md](../specs/peripheral-network/lua-api.md). With computer --red--> database --green--> monitor, red discovery must contain the database but not the monitor, and green discovery from the computer must not invent a route. Adding an actual complete red route to the monitor permits red access; it does not retroactively authorize green-bound handles.

## Case C: precise cache expiration and type failures

Use [kv-database/lua-api.md](../specs/kv-database/lua-api.md) and [computer-runtime/lua-api.md](../specs/computer-runtime/lua-api.md). Verify nil versus empty strings, the WRONGTYPE table from GET of a hash, HSET preserving TTL, SET clearing it, deletion of the final field and exact deadline boundaries. Advance actual ticks; a made-up clock result is not engine evidence.

## Case D: signal events and multiple writers

Use [logic-handler/lua-api.md](../specs/logic-handler/lua-api.md). Drive red and green inputs independently with identical names but distinct qualities. Check summed values, filtered deltas including disappearance, selected-color connectivity changes and sample_tick versus dispatch tick. Have A write, B overwrite and A stop: only stopping/disconnecting B may clear B's still-owned bank.

## Case E: configurator inspection and containment

Use [device-configurator/lua-api.md](../specs/device-configurator/lua-api.md). Include devices behind poles, an unsupported device, an isolated combinator opposite connector, a ghost and a replacement at old coordinates. Verify complete descriptions/capabilities and refusal outside current target reachability. Use a constant-combinator shared group with an out-of-network member to prove shared content cannot be changed through local target authority.
