-- Paid copy/sort cursors contain plain data only; no coroutine or saved iterator.
local M={}
local function room(g,j,slots)
  slots=math.max(j.slots or 0,slots+(j.operands or 0)*4)
  if g then g.job_resize(4096+slots*192) end
  j.slots=slots
end
function M.stage(d,tick,spend,j,g)
  if not j.copy then
    room(g,j,#d.order*4)
    j.copy={version=1,entries={},order={},bytes=0,fields=0,cursor=1}; j.copy_index=1
  end
  while j.copy_index<=#d.order do
    spend(1)
    local k=d.order[j.copy_index]; local e=d.entries[k]
    if not e.deadline or tick<e.deadline then
      local c=j.copy
      c.entries[k]=e; c.order[#c.order+1]=k
      c.bytes=c.bytes+#k+e.bytes; c.fields=c.fields+(e.count or 0)
      if e.deadline then j.deadline=math.min(j.deadline or e.deadline,e.deadline) end
    end
    j.copy_index=j.copy_index+1
  end
  return j.copy
end
function M.fields(e,spend,j,g)
  if not j.fields then
    room(g,j,#j.copy.order*4+(e and e.count or 0)*4)
    j.fields={}
  end
  if e and not j.fields_done then
    while true do
      spend(1)
      local k,v=next(e.fields,j.field_cursor)
      if k==nil then j.fields_done=true; break end
      j.fields[k]=v; j.field_cursor=k
    end
  end
  return j.fields
end
-- Bottom-up merge with a byte cursor also bounds comparisons of long prefixes.
function M.sorted(map,spend,j,g)
  if not j.sort then
    room(g,j,(#j.copy.order+(j.copy.fields or 0))*8+16)
    j.sort={keys={},collect=true,width=1,start=1}
  end
  local s=j.sort
  while s.collect do
    spend(1)
    local k=next(map,s.cursor)
    if k==nil then s.collect=false; s.cursor=nil; s.out={} else s.keys[#s.keys+1]=k; s.cursor=k end
  end
  while s.width<#s.keys do
    if s.start>#s.keys then
      spend(1)
      s.keys=s.out; s.out={}; s.width=s.width*2; s.start=1
    else
      if not s.left then
        s.left=s.start; s.middle=math.min(s.start+s.width-1,#s.keys)
        s.right=s.middle+1; s.last=math.min(s.start+s.width*2-1,#s.keys)
      end
      while s.left<=s.middle or s.right<=s.last do
        local left=s.left<=s.middle and s.keys[s.left]
        local right=s.right<=s.last and s.keys[s.right]
        if s.choose_left==nil then
          if not right then s.choose_left=true elseif not left then s.choose_left=false
          else
            s.byte=s.byte or 1
            while true do
              spend(1)
              local a,b=string.byte(left,s.byte),string.byte(right,s.byte)
              if a~=b or not a then s.choose_left=not a or b~=nil and a<b; break end
              s.byte=s.byte+1
            end
          end
        end
        spend(1)
        s.out[#s.out+1]=s.choose_left and left or right
        if s.choose_left then s.left=s.left+1 else s.right=s.right+1 end
        s.byte=nil; s.choose_left=nil
      end
      s.start=s.start+s.width*2; s.left=nil
    end
  end
  return s.keys
end
return M
