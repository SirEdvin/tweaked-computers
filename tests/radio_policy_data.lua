-- Extend the actual native prototype, not just generator doubles.
require('__tweaked-computers__.tests.speaker_data')
local body=data.raw['programmable-speaker']['programmable-speaker']
local source=body.instruments[2].notes[1].sound
local notes={}
for i=1,129 do notes[i]={name='fixture-note-'..i,sound=table.deepcopy(source)} end
body.instruments[#body.instruments+1]={name='tc-fixture-large-notes',notes=notes}
body.instruments[#body.instruments+1]={name=string.rep('long-native-name-',20),notes={{name=string.rep('long-note-',30),sound=table.deepcopy(source)}}}
while #body.instruments<65 do
  body.instruments[#body.instruments+1]={name='tc-fixture-instrument-'..#body.instruments,notes={{name='zero',sound=table.deepcopy(source)}}}
end
assert(#body.instruments==65)
log('TC_RADIO_NATIVE_INSTRUMENTS count=65 notes=129 long-names=true')
