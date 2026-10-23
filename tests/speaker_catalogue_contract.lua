-- Explicit metadata/native-validator doubles. The independent full catalogue
-- oracle in speaker_engine separately proves actual installed prototype paths.
local audio=require('scripts.speaker-audio')
local errors=require('scripts.runtime.errors')
local limits=require('scripts.runtime.limits')
local M={}
function M.run()
  local original_prototypes,original_helpers=prototypes,helpers
  local ok,problem=pcall(function()
    local blocks,valid={},{}
    prototypes={mod_data=setmetatable({},{__index=function(_,name)
      local data=blocks[name]; return data and {data=data} or nil
    end})}
    helpers={is_valid_sound_path=function(path) return valid[path]==true end}
    local function nop() end
    local function failure(code,fn)
      local success,e=pcall(fn); assert(not success and type(e)=='table' and e.code==code,serpent.line(e))
    end
    local function catalogue(paths)
      blocks={}; valid={}
      blocks['tc-speaker-audio']={version=1,instruments=0,instrument_cost=32,sound_count=#paths,sound_chunks=math.ceil(#paths/50)}
      for i=1,math.ceil(#paths/50) do
        local chunk={}; local cost=32
        for j=(i-1)*50+1,math.min(i*50,#paths) do
          chunk[#chunk+1]=paths[j]; cost=cost+#paths[j]+8; valid[paths[j]]=true
        end
        blocks['tc-speaker-sounds-'..i]={version=1,paths=chunk}
        blocks['tc-speaker-sound-index-'..i]={version=1,first=chunk[1],last=chunk[#chunk],count=#chunk,cost=cost}
      end
    end
    catalogue({}); local page=audio.sounds('','',nop); assert(#page.sounds==0 and page.next==nil)
    local paths={}; for i=1,151 do paths[i]=string.format('fixture-%03d',i) end
    catalogue(paths)
    valid['fixture-001']=false; valid['fixture-051']=false
    local found={}; local cursor=''
    repeat
      page=audio.sounds('fixture-',cursor,nop)
      assert(#page.sounds<=50)
      for _,path in ipairs(page.sounds) do found[#found+1]=path end
      if page.next then assert(page.next==page.sounds[#page.sounds]); cursor=page.next end
    until not page.next
    assert(#found==149)
    local saved_page_size=limits.speaker_sound_page_size
    for _,size in ipairs({7,73}) do
      limits.speaker_sound_page_size=size
      local all={}; local next_path=''
      repeat
        local p=audio.sounds('fixture-',next_path,nop)
        assert(#p.sounds<=size)
        for _,path in ipairs(p.sounds) do all[#all+1]=path end
        next_path=p.next
      until not next_path
      assert(#all==149)
      for i,path in ipairs(found) do assert(all[i]==path) end
    end
    limits.speaker_sound_page_size=saved_page_size
    local at=1
    for _,path in ipairs(paths) do if valid[path] then assert(found[at]==path); at=at+1 end end
    page=audio.sounds('fixture-','fixture-050a',nop)
    assert(page.sounds[1]=='fixture-052' and #page.sounds==50 and page.next=='fixture-101')
    page=audio.sounds('fixture-1','before-prefix',nop); assert(page.sounds[1]=='fixture-100')
    assert(#audio.sounds('fixture.%','',nop).sounds==0) -- literal, not a pattern
    catalogue({table.unpack(paths,1,50)})
    page=audio.sounds('','',nop); assert(#page.sounds==50 and page.next==nil)
    catalogue({'changed'}); page=audio.sounds('','fixture-050',nop); assert(#page.sounds==0 and page.next==nil)
    valid['direct-only']=true; assert(audio.valid('direct-only',nop))
    assert(#audio.sounds('direct-only','',nop).sounds==0)
    catalogue(paths)
    local entered=0
    failure('E_BUDGET',function() audio.sounds('','',function(cost)
      entered=entered+cost; if entered>3000 then errors.raise('E_BUDGET','injected exhausted work') end
    end) end)
    assert(entered>3000) -- Failure returns no fabricated partial/terminal page.
    blocks['tc-speaker-audio'].sound_error='E_LIMIT'
    failure('E_LIMIT',function() audio.sounds('','',nop) end)
    blocks['tc-speaker-audio'].sound_error=nil
    blocks['tc-speaker-sound-index-1'].cost=1
    failure('E_UNSUPPORTED',function() audio.sounds('','',nop) end)
    blocks['tc-speaker-audio'].version=999
    failure('E_UNSUPPORTED',function() audio.sounds('','',nop) end)
    catalogue({}); blocks['tc-speaker-audio'].instrument_error='E_LIMIT'
    failure('E_LIMIT',function() audio.index(nop) end)
    blocks['tc-speaker-audio'].instrument_error=nil
    blocks['tc-speaker-audio'].instruments=1
    blocks['tc-speaker-instruments']={version=1,entries={{name='test',index=1,count=2,cost=1024}}}
    blocks['tc-speaker-instrument-1']={version=1,name='test',notes={
      {name='duplicate',pitch=0,path='tc-speaker-note-1-1'},
      {name='duplicate',pitch=1,path='tc-speaker-note-1-2'}}}
    failure('E_UNSUPPORTED',function() audio.instrument('test',nop) end)
    local huge={}
    for i=1,32769 do huge[i]=string.format('huge-%05d',i) end
    huge[#huge+1]=string.rep('z',257)
    catalogue(huge)
    local total,next_path=0,''
    repeat
      local p=audio.sounds('',next_path,nop)
      for _,path in ipairs(p.sounds) do total=total+1; assert(path==huge[total]) end
      next_path=p.next
    until not next_path
    assert(total==32770)
  end)
  prototypes,helpers=original_prototypes,original_helpers
  assert(ok,serpent.line(problem))
  log('TC_SPEAKER_CATALOGUE_BOUNDARIES_OK explicit-metadata-doubles=true')
end
return M
