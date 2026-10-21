-- Small in-game Reference tutorial; host wrapper is not guest source.
return [[function start(event)
  local speaker = peripheral.find("speaker", "red")
  assert(speaker, "Connect one speaker on red")
  local admitted = speaker.playNote("piano", 0.5, 0)
  print("Note submitted:", admitted)
end
]]
