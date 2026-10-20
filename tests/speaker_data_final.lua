-- tc-smoke depends on the candidate, so this executes after its final-fixes
-- catalogue capture. A direct-only path must stay valid without being indexed.
local generator=require('__tweaked-computers__.prototypes.speaker-audio')
local source=data.raw['programmable-speaker']['programmable-speaker'].instruments[2].notes[1].sound
-- Independent missing-registry seed. Runtime checks the full entity/item/tile
-- family cross product, not the production generator's field tests or chunks.
local names={}
for name in pairs(data.raw.sound) do
  if not name:match('^tc%-speaker%-note%-%d+%-%d+$') then names[#names+1]=name end
end
for name in pairs(data.raw['ambient-sound']) do names[#names+1]='ambient/'..name end
for field in pairs(data.raw['utility-sounds'].default) do if field~='type' and field~='name' then names[#names+1]='utility/'..field end end
assert(#names<4096)
data:extend{{type='mod-data',name='tc-fixture-speaker-oracle',data={paths=names}}}
data:extend{generator.sound(source,'tc-fixture-speaker-direct-only')}
log('TC_SPEAKER_LATE_PATH_REGISTERED')
