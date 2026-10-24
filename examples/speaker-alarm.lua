return [[function start(event)
  computer.setState("accepted", false)
  computer.every(120, "alarm")
end

function alarm(event)
  local speaker = peripheral.find("speaker", "red")
  assert(speaker, "Connect a powered vanilla programmable speaker on red")
  local accepted = speaker.playSound("utility/wire_connect_pole", 0.5)
  computer.setState("accepted", accepted)
  -- Submission success is not proof that a listener heard the sound.
end]]
