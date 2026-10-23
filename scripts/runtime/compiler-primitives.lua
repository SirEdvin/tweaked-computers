-- These helpers are compiled to the same durable host frames as Phobos.
local raw=require('compiler.native')
local M={}
function M.concat(values,separator,first,last)
  separator=separator or ''; first=first or 1; last=last or #values
  local bins,height={},0
  for i=first,last do
    local value=values[i]
    assert(type(value)=='string' or type(value)=='number','invalid compiler concatenation value')
    local piece=raw.tostring(value)
    if i>first then piece=raw.concat(separator,piece) end
    local level=1
    while bins[level] do piece=raw.concat(bins[level],piece); bins[level]=nil; level=level+1 end
    bins[level]=piece
    height=math.max(height,level)
  end
  local result=''
  for i=height,1,-1 do if bins[i] then result=raw.concat(result,bins[i]) end end
  return result
end
function M.sort(values,compare)
  local width=1
  local count=#values
  while width<count do
    local start=1
    while start<=count do
      local left,right,stop=start,math.min(start+width,count+1),math.min(start+2*width-1,count)
      local middle=right
      local out={}
      while left<middle or right<=stop do
        local take_left=right>stop
        if not take_left and left<middle then
          if compare then take_left=not compare(values[right],values[left])
          else take_left=not (values[right]<values[left]) end
        end
        if take_left then out[#out+1]=values[left]; left=left+1
        else out[#out+1]=values[right]; right=right+1 end
      end
      for i=1,#out do values[start+i-1]=out[i] end
      start=start+2*width
    end
    width=width*2
  end
end
function M.insert(values,position,value)
  if value==nil then value=position; position=#values+1 end
  for i=#values,position,-1 do values[i+1]=values[i] end
  values[position]=value
end
function M.remove(values,position)
  position=position or #values
  local value=values[position]
  for i=position,#values-1 do values[i]=values[i+1] end
  values[#values]=nil
  return value
end
return M
