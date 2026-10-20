return [[function start(event)
  computer.setState("starts", (computer.getState("starts") or 0) + 1)
  local modem = peripheral.find("modem", "red")
  assert(modem, "Connect a powered radar on red")
  modem.open(200)
  computer.on("modem_message", "receive")
end

function receive(event)
  if event.channel ~= 200 then return end
  assert(event.sequence > (computer.getState("last_sequence") or 0))
  computer.setState("last_sequence", event.sequence)
  computer.setState("last_message", event.message)
  computer.setState("received", (computer.getState("received") or 0) + 1)
  computer.log("Message received on channel 200")
  local modem = peripheral.wrap(event.peripheral, event.wire)
  if modem then
    modem.transmit(event.replyChannel, 200, {received = event.message})
  end
end]]
