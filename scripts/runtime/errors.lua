local M = {}
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
