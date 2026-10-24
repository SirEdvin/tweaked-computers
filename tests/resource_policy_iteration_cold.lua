-- Pinned-engine probe: explicit next-key cursors, never saved iterator functions.
local M={}
local loaded=false
local function check(f)
  for _,c in ipairs(f.cursors) do
    local key,value=next(f.values,c.key)
    local expected=f.expected[c.index+1]
    assert(key==(expected and expected.key) and value==(expected and expected.value),
      'native ordered-table cursor changed across cold serialization')
  end
end
function M.run()
  local values,objects={},{}
  for i=2500,1,-1 do values[i]='number-'..i end
  for i=1,40 do
    objects[i]={id=i}; values['text-'..i]=objects[i]; values[objects[i]]=i; values[-i]=false
  end
  values[false]='false-key'; values[true]='true-key'; values[values]=values
  local expected={}
  for key,value in pairs(values) do expected[#expected+1]={key=key,value=value} end
  local cursors={}
  for _,anchor in ipairs({1024,2048,'text-17',objects[17],values,false,true,-17}) do
    for i,row in ipairs(expected) do
      if rawequal(row.key,anchor) then cursors[#cursors+1]={key=anchor,index=i,start=i}; break end
    end
  end
  assert(#cursors==8)
  storage.tc_iteration_fixture={values=values,expected=expected,cursors=cursors,phase='armed'}
  game.speed=100
end
function M.on_load()
  local f=storage.tc_iteration_fixture
  if f.phase=='frozen' then check(f); log('TC_ITERATION_ON_LOAD_UNCHANGED'); loaded=true end
end
function M.on_tick()
  local f=storage.tc_iteration_fixture
  if f.phase=='done' then return end
  if f.phase=='armed' then
    check(f); f.phase='frozen'
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED'); return
  end
  if f.phase=='frozen' then
    if not loaded then return end
    check(f); f.phase='resume'
  end
  local done=true
  for _,c in ipairs(f.cursors) do
    for _=1,7 do
      if not c.done then
        local key,value=next(f.values,c.key)
        local expected=f.expected[c.index+1]
        assert(key==(expected and expected.key) and value==(expected and expected.value),'cursor skipped or repeated an entry')
        if key==nil then c.done=true else c.index=c.index+1; c.key=key end
      end
    end
    if not c.done then done=false end
  end
  if done then
    for _,c in ipairs(f.cursors) do assert(c.index==#f.expected and c.index>=c.start) end
    f.phase='done'; log('TC_COLD_OK native-next-cursors mixed-keys beyond-1024 aliases cycles')
  end
end
function M.on_configuration_changed() end
return M
