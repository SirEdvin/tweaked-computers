-- Host status only: never enter or wait for the guest execution lane.
local available,policy=pcall(require,'scripts.runtime.resource-policy')
local M={}
function M.read(rec,tick)
  if not available then return nil end
  return policy.status(rec,tick)
end
function M.summary(status)
  if not status then return 'Resource status unavailable' end
  local state=status.state
  local text=state=='resource_refused' and 'Resource refused (recoverable)' or state

  local drops=status.dropped_events
  if drops and (drops.total>0 or drops.saturated) then
    text=text..' / dropped '..tostring(drops.total)..(drops.saturated and '+' or '')
  end
  return text
end
function M.details(status,drafts)
  local lines={M.summary(status)}
  if status then
    if status.wait then
      local w=status.wait
      lines[#lines+1]='Waiting since tick '..w.since_tick..': '..w.resource..' / '..w.setting..(w.resumable and ' (resumes automatically)' or '')
    end
    local names={}; for name in pairs(status.resources) do names[#names+1]=name end; table.sort(names)
    for _,name in ipairs(names) do
      local r=status.resources[name]
      lines[#lines+1]=name..': '..r.used..' / '..r.limit..' '..r.unit..' / '..r.scope..' / '..r.setting..(r.over_limit and ' (over limit; accepted data retained)' or '')
    end
    local d=status.dropped_events
    lines[#lines+1]='Dropped events (cumulative): '..d.total..(d.saturated and ' (saturated)' or '')
    if d.last_tick then lines[#lines+1]='Last drop at tick '..d.last_tick..': '..(d.last_kind or '')..' / '..(d.last_reason or '') end
    local e=status.last_refusal
    if e then
      lines[#lines+1]='Last recoverable refusal: '..e.code..': '..e.message
      lines[#lines+1]=e.resource..': used '..e.used..', requested '..e.requested..', limit '..e.limit..' / '..e.setting
    end
  end
  if drafts then
    lines[#lines+1]='Player drafts: '..drafts.used..' / '..drafts.limit..' bytes / '..drafts.setting..(drafts.over_limit and ' (over limit; accepted drafts retained)' or '')
  end
  return table.concat(lines,'\n')
end
return M
