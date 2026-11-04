function start(event)
  local speaker = peripheral.find("speaker", "red")
  assert(speaker, "Connect a powered vanilla speaker on red")
  for _, instrument in ipairs(speaker.getInstruments()) do
    computer.log(instrument)
  end
  local notes = speaker.getNotes("piano")
  assert(#notes > 0)
  computer.log(notes[1].name)
  computer.log(tostring(speaker.playNote("piano", 0.5, notes[1].pitch)))
  local page = speaker.getSounds("utility/")
  if #page.sounds > 0 then
    computer.log(tostring(speaker.playSound(page.sounds[1], 0.5)))
  end
  computer.setState("speaker", peripheral.getName(speaker))
  computer.every(60, "chime")
end

function chime(event)
  local speaker = peripheral.wrap(computer.getState("speaker"), "red")
  if speaker then
    local accepted = speaker.playNote("piano", 0.25, 0)
    if not accepted then computer.log("Speaker busy this tick") end
  end
end
