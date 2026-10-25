-- Install real over-former-limit inventories, not runtime metadata doubles.
local generator=require('__tweaked-computers__.prototypes.speaker-audio')
local speaker=data.raw['programmable-speaker']['programmable-speaker']
local sample=speaker.instruments[2].notes[1].sound

for i=1,65 do
  local notes={}
  for n=1,(i==1 and 129 or 1) do notes[n]={name='note-'..n,sound=table.deepcopy(sample)} end
  speaker.instruments[#speaker.instruments+1]={name=string.format('tc-resource-instrument-%03d',i),notes=notes}
end
local long='tc-resource-long-'..string.rep('x',257)
speaker.instruments[#speaker.instruments+1]={name=long,notes={{name=long,sound=table.deepcopy(sample)}}}
local oversized={}
for i=1,129 do oversized[i]={name=string.rep('n',5000)..i,sound=table.deepcopy(sample)} end
speaker.instruments[#speaker.instruments+1]={name='tc-resource-oversized',notes=oversized}
local sounds={}
for i=1,32769 do sounds[#sounds+1]=generator.sound(sample,string.format('tc-resource-sound-%05d',i)) end
sounds[#sounds+1]=generator.sound(sample,long)
sounds[#sounds+1]={type='mod-data',name='tc-resource-speaker-oracle',data={instruments=#speaker.instruments,long=long}}
data:extend(sounds)
log('TC_SPEAKER_RESOURCE_DATA_OK real-instruments=65 real-notes=129 real-sounds=32769 long-native-names=true oversized-native-block=true')
