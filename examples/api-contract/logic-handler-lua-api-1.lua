function start(event)
  local io = peripheral.find("logic_handler", "red")
  if io then
    io.subscribe({
      input = "red",
      signals = { { type = "item", name = "iron-plate", quality = "normal" } },
      initial = true
    }, "changed")
  end
end

function changed(event)
  local io = peripheral.wrap(event.peripheral, event.wire)
  if not io then return end
  local count = 0
  for _, entry in ipairs(event.current) do
    count = entry.count
  end
  local enable = 0
  if count < 100 then enable = 1 end
  io.setOutput({
    { signal = { type = "virtual", name = "signal-A", quality = "normal" }, count = enable }
  })
end
