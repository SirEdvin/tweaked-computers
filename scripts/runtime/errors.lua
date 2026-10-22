local M = {}
local refusals=setmetatable({},{__mode='k'})
local resource_fields={'code','message','resource','setting','used','requested','limit','recoverable','line','column'}
local function resource_copy(value)
  local result={}; for _,key in ipairs(resource_fields) do result[key]=value[key] end; return result
end
function M.refuse(resource,setting,used,requested,limit,message,code)
  code=code or 'E_CAPACITY'
  assert(code=='E_CAPACITY' or code=='E_LIMIT' or code=='E_BUDGET','invalid resource error code')
  assert(type(resource)=='string' and #resource>0 and type(setting)=='string' and #setting>0 and type(message)=='string')
  for _,value in ipairs({used,requested,limit}) do assert(M.integer(value,0,9007199254740991),'invalid resource accounting') end
  local diagnostic={code=code,message=message,resource=resource,setting=setting,used=used,requested=requested,limit=limit,recoverable=true}
  local problem=resource_copy(diagnostic); refusals[problem]=diagnostic
  error(problem,0)
end
function M.resource_diagnostic(value)
  local diagnostic=refusals[value]
  return diagnostic and resource_copy(diagnostic)
end
function M.new(code, message, field)
  return {code = code, message = message, field = field}
end
function M.raise(code, message, field)
  error(M.new(code, message, field), 0)
end
function M.finite(n)
  return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end
function M.integer(n, minimum, maximum)
  return M.finite(n) and n % 1 == 0 and n >= minimum and n <= maximum
end
return M
