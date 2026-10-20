return [[function start(event)
  computer.setState("after", "")
  computer.setState("count", 0)
  computer.setState("complete", false)
  computer.after(1, "page")
end

function page(event)
  local speaker = peripheral.find("speaker", "red")
  assert(speaker, "Connect a powered vanilla programmable speaker on red")
  local result = speaker.getSounds("", computer.getState("after"))
  computer.setState("last_page", result.sounds)
  computer.setState("count", computer.getState("count") + #result.sounds)
  computer.log("Sound paths discovered: " .. tostring(computer.getState("count")))
  if result.next then
    computer.setState("after", result.next)
    computer.after(1, "page")
  else
    computer.setState("complete", true)
  end
end]]
