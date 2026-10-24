-- Actual cold-process continuity of an incremental ownership scan.
local ownership=require('scripts.runtime.ownership')
local M={}
local loaded=false
local function make()
  local c={frame={locals={},slots={},tuples={}},owned={},owned_order={},symbols={},symbols_order={},
    intern={},bindings={},bindings_order={}}
  local nodes={}
  for i=1,48 do nodes[i]={value=string.rep('x',100)} end
  for i,t in ipairs(nodes) do
    t.next=nodes[i%24+1+(i>24 and 24 or 0)]
    c.owned[t]={keys={'next','value'}}; c.owned_order[i]=t
  end
  c.frame.locals[1]=nodes[1]
  ownership.begin(c,{slots=0,locals=1})
  return c
end
function M.run()
  local baseline=make(); local actions=0
  ownership.advance(baseline,function(n) actions=actions+n end)
  assert(not baseline.collection and #baseline.owned_order==24)
  storage.tc_ownership_fixture={checkpoint=make(),expected_actions=actions,expected_bytes=baseline.memory_bytes,
    actions=0,phase='scan'}
end
local function frozen(f)
  local c=f.checkpoint
  assert(c.collection==f.collection and c.collection.head==f.head and c.collection.phase==f.gc_phase)
  assert(c.collection.queue[c.collection.head].cursor==f.cursor and f.actions==f.frozen_actions)
end
function M.on_load()
  local f=storage.tc_ownership_fixture
  if f.phase=='frozen' then frozen(f); log('TC_OWNERSHIP_ON_LOAD_UNCHANGED'); loaded=true end
end
function M.on_tick()
  local f=storage.tc_ownership_fixture
  if f.phase=='frozen' then
    if not loaded then return end
    frozen(f); f.phase='resume'
  end
  if f.phase=='done' then return end
  local c=f.checkpoint; local spent=false; local pause={}
  local ok,e=pcall(ownership.advance,c,function(n)
    assert(n==1)
    if spent then error(pause,0) end
    spent=true; f.actions=f.actions+1
  end)
  assert(ok or e==pause,type(e)=='table' and e.message or tostring(e))
  if f.phase=='scan' and c.collection.head>5 then
    f.phase='frozen'; f.collection=c.collection; f.head=c.collection.head
    f.gc_phase=c.collection.phase; f.cursor=c.collection.queue[c.collection.head].cursor
    f.frozen_actions=f.actions
    game.server_save('tc03-snapshot'); log('TC_COLD_SNAPSHOT_REQUESTED')
  elseif not c.collection then
    assert(f.phase=='resume','cold resume was not exercised')
    assert(f.actions==f.expected_actions and c.memory_bytes==f.expected_bytes and #c.owned_order==24)
    f.phase='done'; log('TC_CONTRACT ownership-paid-cursor-cold-no-restart'); log('TC_COLD_OK')
  end
end
function M.on_configuration_changed() end
return M
