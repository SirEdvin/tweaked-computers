local admission = require("scripts.runtime.parse_admission")

local util = require("vendor.phobos.util")

local function new_stack()

  admission.enter()
  return {size = 0}
end

---@generic T
---@param iter fun(): (T?)
---@return T[]|{size: integer}
local function from_iterator(iter)
  admission.enter()
  local size = 0
  local stack = {size = 0} -- To make sure the table has an entry in the hash part allocated...
  for value in iter do
    admission.enter()
    size = size + 1
    stack[size] = value
  end
  stack.size = size -- ... that way this definitely does not cause the table to grow/reallocate.
  return stack
end

local function clear_stack(stack)

  admission.enter()
  util.clear_array(stack)
end

---@generic T
---@param stack T[]|{size: integer}
---@param value T
local function push(stack, value)
  admission.enter()
  local size = stack.size + 1
  stack.size = size
  stack[size] = value
end

---@generic T
---@param stack T[]|{size: integer}
---@return T
local function pop(stack)
  admission.enter()
  local size = stack.size
  local value = stack[size]
  stack[size] = nil
  stack.size = size - 1
  return value
end

---@generic T
---@param stack T[]|{size: integer}
---@return T
local function get_top(stack)
  admission.enter()
  ---@diagnostic disable-next-line: undefined-field
  return stack[stack.size]
end

local function is_empty(stack)

  admission.enter()
  return stack.size == 0
end

return {
  new_stack = new_stack,
  from_iterator = from_iterator,
  clear_stack = clear_stack,
  push = push,
  pop = pop,
  get_top = get_top,
  is_empty = is_empty,
}
