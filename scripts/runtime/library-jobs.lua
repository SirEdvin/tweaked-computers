-- Durable synchronous library calls. Only plain cursors cross a work boundary.
local errors=require('scripts.runtime.errors')
local M={}
local MAX=9007199254740991
local function fail(message) errors.raise('E_ARGUMENT',message) end
local function integer(value,low,high)
  if not errors.integer(value,low,high) then fail('integer outside allowed range') end
  return value
end
local function text(value)
  if type(value)=='number' then return tostring(value) end
  if type(value)~='string' then fail('string or number required') end
  return value
end
local function keep(g,j,bytes,slots)
  g.job_resize(j,2048+(bytes or j.bytes or 0)*2+(slots or 0)*48)
end
local function append(g,j,value)
  local bytes=j.bytes+#value
  g.atomic(#value+4,#value+1)
  keep(g,j,bytes,#j.parts+1)
  j.parts[#j.parts+1]=value; j.bytes=bytes
end
local function joined(g,j)
  g.atomic(j.bytes+#j.parts+1,j.bytes)
  keep(g,j,j.bytes*2,#j.parts)
  return {n=1,table.concat(j.parts)}
end
local function concatenate(g,j,args,operator)
  if not j.phase then
    local t=args[1]
    if not operator then g.plain(t) end
    local sep=operator and '' or args[2] or ''
    if type(sep)~='string' then fail('string separator required') end
    local first=operator and 1 or args[3] or 1
    local last=operator and args.n or args[4] or #t
    integer(first,-MAX,MAX); integer(last,-MAX,MAX)
    keep(g,j,0,0)
    j.parts={}; j.bytes=0; j.index=first; j.first=first; j.last=last; j.sep=sep; j.phase='scan'
  end
  while j.index<=j.last do
    g.spend(2)
    local raw=operator and args[j.index] or args[1][j.index]
    if raw==nil then fail('missing concatenation value at '..j.index) end
    local value=text(raw)
    local prefix=j.index==j.first and '' or j.sep
    g.atomic(#prefix+#value+4,#prefix+#value+1)
    keep(g,j,j.bytes+#prefix+#value,#j.parts+1)
    j.parts[#j.parts+1]=prefix..value; j.bytes=j.bytes+#prefix+#value; j.index=j.index+1
  end
  return joined(g,j)
end
local function format(g,j,args)
  local pattern=args[1]
  if type(pattern)~='string' then fail('format string required') end
  if not j.phase then keep(g,j,0,0); j.parts={}; j.bytes=0; j.index=1; j.arg=2; j.phase='scan' end
  while j.index<=#pattern do
    g.spend(2)
    local c=string.sub(pattern,j.index,j.index)
    if not j.token and c~='%' then
      append(g,j,c); j.index=j.index+1
    elseif not j.token then
      j.token='%'; j.index=j.index+1
    elseif j.token=='%' and c=='%' then
      append(g,j,'%'); j.token=nil; j.index=j.index+1
    elseif c:match('[cdiouxXeEfgGqs]') then
      if j.arg>args.n then fail('missing format operand') end
      local token=j.token..c
      local value=args[j.arg]
      local width,precision=token:match('^%%[-+ #0]*(%d*)%.?(%d*)[cdiouxXeEfgGqs]$')
      if not width then fail('invalid format') end
      local bound=math.max(tonumber(width) or 0,512+(tonumber(precision) or 0))
      if c=='s' then value=g.describe(value); bound=math.max(#value,tonumber(width) or 0)
      elseif c=='q' then value=text(value); bound=#value*4+2
      else value=g.number(value); if not errors.finite(value) then fail('finite format operand required') end end
      g.atomic(bound+#token+1,bound)
      keep(g,j,j.bytes+bound,#j.parts+1)
      local value=string.format(token,value)
      j.parts[#j.parts+1]=value; j.bytes=j.bytes+#value; j.token=nil; j.arg=j.arg+1; j.index=j.index+1
    elseif c:match('[-+ #0%d%.]') then
      g.atomic(#j.token+2,#j.token+1)
      keep(g,j,j.bytes+#j.token+1,#j.parts)
      j.token=j.token..c; j.index=j.index+1
    else fail('invalid format') end
  end
  if j.token then fail('unfinished format') end
  return joined(g,j)
end
local function sort(g,j,args,call,prepare)
  local t,less=args[1],args[2]
  g.plain(t)
  if less~=nil and g.encoded_type(less)~='function' then fail('sort comparator must be callable') end
  if not j.phase then
    keep(g,j,0,0); j.n=#t; j.index=1; j.values={}; j.scratch={}; j.phase='copy'
  end
  while j.phase=='copy' and j.index<=j.n do
    g.host_work(2,1); keep(g,j,0,j.index*2)
    j.values[j.index]=t[j.index]; j.index=j.index+1
  end
  if j.phase=='copy' then j.width=1; j.start=1; j.phase='merge' end
  while j.width<j.n do
    g.spend(1)
    if j.start>j.n then
      j.values,j.scratch=j.scratch,j.values; j.width=j.width*2; j.start=1
    else
      if not j.left then
        j.left=j.start; j.middle=math.min(j.start+j.width,j.n+1)
        j.right=j.middle; j.stop=math.min(j.start+j.width*2-1,j.n); j.out=j.start
      end
      while j.out<=j.stop do
        g.spend(2)
        local take_right
        if j.left>=j.middle then take_right=true
        elseif j.right>j.stop then take_right=false
        elseif less then
          local result=call(less,{n=2,j.values[j.right],j.values[j.left]})
          if not result then return end
          take_right=not not result[1]
        else
          local a,b=j.values[j.right],j.values[j.left]
          g.scalar(a); g.scalar(b)
          take_right=a<b
        end
        local index=take_right and j.right or j.left
        j.scratch[j.out]=j.values[index]
        if take_right then j.right=j.right+1 else j.left=j.left+1 end
        j.out=j.out+1
      end
      j.start=j.stop+1; j.left=nil
    end
  end
  -- The guest comparator can mutate the target: preflight the whole publication.
  local result=prepare({n=0})
  if not j.committed then g.publish_sequence(t,j.values,j.n); j.committed=true end
  return result
end
local function unpack_values(g,j,args)
  local t=args[1]; g.plain(t)
  if not j.phase then
    local first,last=args[2],args[3]
    if first==nil then first=1 end
    if last==nil then last=#t end
    integer(first,-MAX,MAX); integer(last,-MAX,MAX)
    keep(g,j,0,0); j.index=first; j.first=first; j.last=last; j.values={n=math.max(0,last-first+1)}; j.phase='copy'
  end
  while j.index<=j.last do
    g.host_work(2,1); keep(g,j,0,j.index-j.first+1)
    j.values[j.index-j.first+1]=args[1][j.index]; j.index=j.index+1
  end
  return j.values
end
local function mutate(g,j,args,call,prepare,remove)
  local t=args[1]; g.plain(t)
  if not j.phase then
    local n=#t
    local position,value
    if remove then
      position=args[2]; if position==nil then position=n end
      integer(position,n==0 and 0 or 1,n+1)
    else
      if args.n==2 then position=n+1; value=args[2]
      elseif args.n==3 then position=args[2]; value=args[3]
      else fail('insert arity') end
      integer(position,1,n+1); g.scalar(value)
    end
    keep(g,j,0,0)
    j.values={}; j.n=n; j.position=position; j.value=value; j.index=1
    if remove then j.removed=t[position] end
    j.phase='copy'
  end
  local count=remove and j.n or j.n+1
  while j.index<=count do
    g.host_work(2,1); keep(g,j,0,j.index)
    local i=j.index
    if remove then
      if i<j.position then j.values[i]=t[i] else j.values[i]=t[i+1] end
    elseif i<j.position then j.values[i]=t[i]
    elseif i==j.position then j.values[i]=j.value
    else j.values[i]=t[i-1] end
    j.index=i+1
  end
  local result=prepare(remove and {n=1,j.removed} or {n=0})
  if not j.committed then
    g.publish_sequence(t,j.values,count,remove and math.max(j.position,j.n) or nil)
    j.committed=true
  end
  return result
end
local function transform(g,j,args,call,prepare,name)
  if j.result then return j.result end
  local source=args[1]
  if type(source)~='string' then fail('string required') end
  if not j.phase then
    local first,last=1,#source
    if name=='sub' or name=='byte' then
      first=args[2] or 1; last=args[3]
      if last==nil then last=name=='byte' and first or #source end
      first=g.number(first); last=g.number(last)
      if not errors.finite(first) or not errors.finite(last) then fail('finite string indexes required') end
      first=first<0 and math.max(#source+math.ceil(first)+1,1) or math.max(math.floor(first),1)
      last=last<0 and #source+math.ceil(last)+1 or math.floor(last)
      last=math.min(last,#source)
    end
    local count=math.max(0,last-first+1)
    -- One bounded native copy needs neither a chunk vector nor a second join.
    if name~='byte' and count<=256 then
      g.atomic(count*2+2,count+2)
      keep(g,j,count,0)
      local value
      if count==0 then value=''
      elseif name=='sub' then value=string.sub(source,first,last)
      else value=string[name](source) end
      j.result={n=1,value}
      return j.result
    end
    keep(g,j,0,0); j.parts={}; j.bytes=0; j.index=first; j.last=last; j.first=first
    j.values={n=math.max(0,last-first+1)}; j.phase='copy'
  end
  while j.index<=j.last do
    if name=='byte' then
      g.host_work(2,1); keep(g,j,0,j.index-j.first+1)
      j.values[j.index-j.first+1]=string.byte(source,j.index); j.index=j.index+1
    else
      -- Chunk size is scheduling granularity, not an input or output ceiling.
      local count=math.min(256,j.last-j.index+1)
      g.atomic(count*4+4,count*2+1)
      keep(g,j,j.bytes+count,#j.parts+1)
      local value
      if name=='reverse' then value=string.reverse(string.sub(source,#source-j.index-count+2,#source-j.index+1))
      else
        value=string.sub(source,j.index,j.index+count-1)
        if name~='sub' then value=string[name](value) end
      end
      j.parts[#j.parts+1]=value; j.bytes=j.bytes+#value; j.index=j.index+count
    end
  end
  if name=='byte' then return j.values end
  return joined(g,j)
end
local function character(g,j,args)
  if not j.phase then keep(g,j,0,0); j.parts={}; j.bytes=0; j.index=1; j.phase='copy' end
  while j.index<=args.n do
    g.spend(1); local value=integer(args[j.index],0,255)
    append(g,j,string.char(value)); j.index=j.index+1
  end
  return joined(g,j)
end
local function repeat_string(g,j,args)
  local value,sep=args[1],args[3]
  if sep==nil then sep='' end
  if type(value)~='string' or type(sep)~='string' then fail('string required') end
  local count=integer(args[2],-MAX,MAX)
  if count<=0 or #value==0 and #sep==0 then return {n=1,''} end
  if not j.phase then keep(g,j,0,0); j.parts={}; j.bytes=0; j.index=1; j.phase='copy' end
  while j.index<=count do
    local prefix=j.index==1 and '' or sep
    g.atomic(#prefix+#value+4,#prefix+#value+1)
    keep(g,j,j.bytes+#prefix+#value,#j.parts+1)
    j.parts[#j.parts+1]=prefix..value; j.bytes=j.bytes+#prefix+#value; j.index=j.index+1
  end
  return joined(g,j)
end
local function find_string(g,j,args)
  local source,needle=args[1],args[2]
  if type(source)~='string' or type(needle)~='string' then fail('strings required') end
  if args[4]~=true then fail('find requires explicit plain=true') end
  if not j.phase then
    local first=args[3] or 1; first=g.number(first)
    if not errors.finite(first) then fail('finite find index required') end
    first=first<0 and math.max(#source+math.ceil(first)+1,1) or math.max(math.floor(first),1)
    keep(g,j,0,0); j.index=first; j.offset=1; j.phase='scan'
  end
  if #needle==0 and j.index<=#source+1 then return {n=2,j.index,j.index-1} end
  while j.index+#needle-1<=#source do
    g.spend(4)
    if string.byte(source,j.index+j.offset-1)==string.byte(needle,j.offset) then
      j.offset=j.offset+1
      if j.offset>#needle then return {n=2,j.index,j.index+#needle-1} end
    else j.index=j.index+1; j.offset=1 end
  end
  return {n=1}
end
M.handlers={['table.concat']=function(g,j,args) return concatenate(g,j,args,false) end,['@concat']=function(g,j,args) return concatenate(g,j,args,true) end,
  ['string.format']=format,['table.sort']=sort,['table.unpack']=unpack_values,['unpack']=unpack_values,
  ['table.insert']=function(g,j,args,call,prepare) return mutate(g,j,args,call,prepare,false) end,
  ['table.remove']=function(g,j,args,call,prepare) return mutate(g,j,args,call,prepare,true) end,
  ['string.char']=character,['string.rep']=repeat_string,['string.find']=find_string}
for _,name in ipairs({'sub','byte','lower','upper','reverse'}) do
  M.handlers['string.'..name]=function(g,j,args,call,prepare) return transform(g,j,args,call,prepare,name) end
end
function M.supports(name) return M.handlers[name]~=nil end
function M.advance(name,g,job,args,call,prepare) return assert(M.handlers[name])(g,job,args,call,prepare) end
return M
