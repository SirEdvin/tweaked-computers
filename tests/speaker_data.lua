-- Prototype-stage assertions, independent synthetic inventories and native snapshot.
local generator=require('__tweaked-computers__.prototypes.speaker-audio')
local native=data.raw['programmable-speaker']['programmable-speaker']
local original=serpent.block(native)
local function byname(list,name) for _,p in ipairs(list) do if p.name==name then return p end end end
local source=native.instruments[2].notes[1].sound
local function raw(instruments,sounds)
  return {['programmable-speaker']={['programmable-speaker']={instruments=instruments}},sound=sounds or {}}
end
local filename=type(source)=='string' and source or source.filename
assert(filename,'fixture requires pinned native single sample')
for shape_index,shape in ipairs({filename,{filename=filename,volume=.4,speed=.9},{{filename=filename,volume=.2},{filename=filename,volume=.8}},
    {variations={{filename=filename,volume=.3},{filename=filename,volume=.7}},allow_random_repeat=true}}) do
  local input=raw{{name='test',notes={{name='zero',sound=shape}}}}
  local before=serpent.block(input)
  local out=generator.generate(input)
  local alias=assert(byname(out,'tc-speaker-note-1-1'))
  assert(alias.category=='game-effect' and alias.audible_distance_modifier==1 and not alias.position)
  assert(serpent.block(input)==before)
  assert(byname(out,'tc-speaker-audio').data.instruments==1)
  -- Have the actual prototype loader validate every documented union shape.
  alias.name='tc-fixture-shape-'..shape_index; data:extend{alias}
end
local duplicate=raw{{name='duplicate',notes={{name='zero',sound=source}}},{name='duplicate',notes={{name='zero',sound=source}}}}
local out=generator.generate(duplicate)
assert(byname(out,'tc-speaker-audio').data.instrument_error=='E_UNSUPPORTED' and not byname(out,'tc-speaker-note-1-1'))
local many={}; for i=1,65 do many[i]={name='instrument-'..i,notes={{name='zero',sound=source}}} end
assert(byname(generator.generate(raw(many)),'tc-speaker-audio').data.instrument_error)
local notes={}; for i=1,129 do notes[i]={name='note-'..i,sound=source} end
assert(byname(generator.generate(raw{{name='too-many-notes',notes=notes}}),'tc-speaker-audio').data.instrument_error=='E_LIMIT')
out=generator.generate(raw{{name='duplicate-notes',notes={{name='zero',sound=source},{name='zero',sound=source}}}})
assert(byname(out,'tc-speaker-audio').data.instrument_error=='E_UNSUPPORTED')
local named={}; for i=1,151 do named[string.format('fixture-%03d',i)]={type='sound'} end
out=generator.generate(raw({{name='a',notes={{name='zero',sound=source}}}},named))
local h=byname(out,'tc-speaker-audio').data
assert(h.sound_count==157 and h.sound_chunks==4)
local all={}; for i=1,4 do
  local paths=byname(out,'tc-speaker-sounds-'..i).data.paths
  assert(#paths==(i==4 and 7 or 50))
  for _,p in ipairs(paths) do if p:sub(1,8)=='fixture-' then all[#all+1]=p end end
end
for i,path in ipairs(all) do assert(path==string.format('fixture-%03d',i)) end
named[string.rep('x',257)]={type='sound'}
h=byname(generator.generate(raw({{name='a',notes={{name='zero',sound=source}}}},named)),'tc-speaker-audio').data
assert(h.sound_error=='E_LIMIT' and h.sound_count==0 and h.sound_chunks==0)
local huge={}; for i=1,32769 do huge['oversized-'..i]={type='sound'} end
h=byname(generator.generate(raw({{name='a',notes={{name='zero',sound=source}}}},huge)),'tc-speaker-audio').data
assert(h.sound_error=='E_LIMIT' and h.sound_count==0 and h.sound_chunks==0)
assert(serpent.block(native)==original,'catalogue generator mutated native instrument source')
local unsupported=table.deepcopy(native); unsupported.name='tc-fixture-unsupported-speaker'; data:extend{unsupported}
local installed={}
for i=1,151 do installed[#installed+1]=generator.sound(source,string.format('tc-fixture-speaker-%03d',i)) end
data:extend(installed)
log('TC_SPEAKER_DATA_OK shapes=4 duplicate=2 oversized=4 pagination=151 source-preserved=true')
