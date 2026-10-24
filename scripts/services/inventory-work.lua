-- Private plain-data preparation; callers own/account the job, never guest Data.
local errors=require('scripts.runtime.errors')
local M={}
function M.job(guard,name)
  if guard and guard.continuation_enabled and not guard.job then
    errors.raise('E_UNSUPPORTED','durable inventory job admission unavailable')
  end
  return guard and guard.job and guard.job(name,function() return {} end) or {}
end
-- Bottom-up merge sort: every paid copy/comparison advances a persisted cursor.
function M.sort(values,job,spend,key)
  if job.done then return values end
  job.width=job.width or 1; job.left=job.left or 1; job.out=job.out or {}
  local n=#values
  while job.width<n do
    while job.left<=n do
      local middle=math.min(job.left+job.width,n+1)
      local last=math.min(job.left+2*job.width-1,n)
      job.i=job.i or job.left; job.j=job.j or middle
      while job.i<middle or job.j<=last do
        local a=job.i<middle and values[job.i] or nil
        local b=job.j<=last and values[job.j] or nil
        local ka=a and key(a); local kb=b and key(b)
        spend(2+(ka and #ka or 0)+(kb and #kb or 0))
        if a and (not b or ka<=kb) then
          job.out[#job.out+1]=a; job.i=job.i+1
        else job.out[#job.out+1]=b; job.j=job.j+1 end
      end
      job.left=job.left+2*job.width; job.i=nil; job.j=nil
    end
    job.copy=job.copy or 1
    while job.copy<=n do
      spend(2); values[job.copy]=job.out[job.copy]; job.copy=job.copy+1
    end
    job.width=job.width*2; job.left=1; job.out={}; job.copy=nil
  end
  job.done=true; job.out=nil
  return values
end
function M.names(map,job,spend)
  job.values=job.values or {}; job.sort=job.sort or {}
  if not job.scanned then
    while true do
      spend(2)
      local k=next(map,job.cursor)
      if k==nil then job.scanned=true; break end
      job.values[#job.values+1]=k; job.cursor=k
    end
  end
  return M.sort(job.values,job.sort,spend,function(v) return v end)
end
return M
