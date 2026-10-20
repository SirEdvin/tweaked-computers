return [[function start(event)
  computer.setState("starts", (computer.getState("starts") or 0) + 1)
  local modem = peripheral.find("modem", "red")
  assert(modem, "Connect a powered radar on red")
  modem.open(201)
  computer.on("modem_message", "reply")
  computer.every(60, "send")
end

function send(event)
  local modem = peripheral.find("modem", "red")
  assert(modem)
  local sequence = (computer.getState("sent") or 0) + 1
  modem.transmit(200, 201, {sequence = sequence, text = "Hello, distant factory"})
  computer.setState("sent", sequence)
end

function reply(event)
  if event.channel == 201 then
    assert(event.sequence > (computer.getState("last_sequence") or 0))
    computer.setState("last_sequence", event.sequence)
    computer.setState("last_reply", event.message)
    computer.log("Reply received on channel 201")
  end
end]]
