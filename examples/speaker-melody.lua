return [[function start(event)
  local speaker = peripheral.find("speaker", "red")
  assert(speaker, "Connect a powered vanilla programmable speaker on red")
  local notes = speaker.getNotes("piano")
  assert(#notes >= 3)
  computer.setState("speaker", peripheral.getName(speaker))
  computer.setState("pitches", {notes[1].pitch, notes[2].pitch, notes[3].pitch, notes[2].pitch})
  computer.setState("step", 1)
  computer.every(30, "note")
end

function note(event)
  local speaker = peripheral.wrap(computer.getState("speaker"), "red")
  assert(speaker, "Speaker disconnected; reconnect and Run again")
  local step = computer.getState("step")
  local pitches = computer.getState("pitches")
  assert(speaker.playNote("piano", 0.35, pitches[step]))
  computer.setState("step", step % #pitches + 1)
end]]
