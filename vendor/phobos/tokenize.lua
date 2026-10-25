local admission = require("scripts.runtime.parse_admission")

local error_code_util = require("vendor.phobos.error_code_util")
local util = require("vendor.phobos.util")
local keywords = util.invert{
  "and", "break", "do", "else", "elseif", "end", "false",
  "for", "function", "if", "in", "local", "nil", "not",
  "or", "repeat", "return", "then", "true", "until",
  "while", "goto",
}

-- Reuse lowering's arena weights instead of a token/string count quota.
local function put(value,key,item)
  if value[key]==nil then admission.allocate(48) end
  value[key]=item
end
local function append(parts,value)
  admission.allocate(48)
  parts[#parts+1]=value
end
local function slice(str,first,last)
  local bytes=math.max(0,last-first+1)
  admission.enter(bytes+1)
  admission.allocate(32+bytes)
  return str:sub(first,last)
end
local function join(parts)
  local bytes=0
  for _,part in ipairs(parts) do admission.enter(); bytes=bytes+#part end
  admission.enter(bytes+1)
  admission.allocate(32+bytes)
  return table.concat(parts)
end

---@param token_type TokenType
---@param index number
---@param line number
---@param column number
---@return Token
local function new_token(token_type,index,line,column)
  admission.enter()
  admission.allocate(192+4*48)
  return {
    token_type = token_type,
    index = index,
    line = line,
    column = column
  }
end

local function add_error_code_inst(token, inst)

  admission.enter()
  if not token.error_code_insts then
    admission.allocate(192+48)
    token.error_code_insts={}
  end
  append(token.error_code_insts,inst)
end

---@param str string
---@param index integer
---@param next_char string
---@return integer
---@return Token
local function peek_equals(str,index,next_char,line,column)
  admission.enter()
  if str:sub(index+1,index+1) == "=" then
    return index+2,new_token(next_char.."=",index,line,column)
  else
    return index+1,new_token(next_char,index,line,column)
  end
end

local newline_chars = util.invert{"\n", "\r"}

-- Single-character probes bound work before input-sized copies.
local function scan(str, index, pattern)
  while str:sub(index,index):match(pattern) do
    admission.enter()
    index=index+1
  end
  return index
end

local function block_open(str,index)
  if str:sub(index,index)~="[" then return end
  local stop=scan(str,index+1,"^=$")
  if str:sub(stop,stop)~="[" then return end
  return index,stop
end

local function consume_newline(str, index, state, current_char)

  admission.enter()
  current_char = current_char or str:sub(index, index)
  assert(newline_chars[current_char], "Trying to consume a newline when there isn't a newline")
  local next_char = str:sub(index + 1, index + 1)
  state.line = state.line + 1
  if newline_chars[next_char] and next_char ~= current_char then
    state.line_offset = index + 1
  else
    state.line_offset = index
  end
    return state.line_offset + 1
end

local escape_sequence_lut = {
  a = "\a", b = "\b", f = "\f", n = "\n",
  r = "\r", t = "\t", v = "\v", ["\\"] = "\\",
  ['"'] = '"', ["'"] = "'",
  -- ["\r"] = "\r", ["\n"] = "\n", -- \r and \n are handled separately
}

---@param str string
---@param index integer
---@param quote "\""|"'"
---@param state TokenizeState
---@return integer
---@return Token
local function read_string(str,index,quote,state)
  admission.enter()
  local token = new_token("string",index,state.line,index - state.line_offset)

  local i = index + 1
  local next_char = str:sub(i,i)
  if next_char == quote then
    -- empty string
    put(token,'value',"")
    put(token,'src_quote',quote)
    put(token,'src_value',"")
    return i+1,token
  end

  admission.allocate(192)
  local parts = {}

  ::matching::
  local start_i = i
  -- read through normal text...
  while str:match("^[^"..quote.."\\\r\n]",i) do
    admission.enter()
    i = i + 1
  end

  if i ~= start_i then
    append(parts,slice(str,start_i,i-1))
  end

  next_char = str:sub(i,i)

  if next_char == quote then
    -- finished string
    if token.token_type == "invalid" then
      put(token,'value',slice(str,index,i))
    else
      put(token,'src_value',slice(str,index+1,i-1))
      put(token,'value',join(parts))
      -- token.src_is_block_str = false -- why bother setting quite literally anything to false :P
      put(token,'src_quote',quote)
    end
    return i+1,token
  elseif next_char == "" then
    token.token_type = "invalid"
    put(token,'value',slice(str,index,i-1))
    admission.allocate(2*192+5*48)
    add_error_code_inst(token, error_code_util.new_error_code{
      error_code = error_code_util.codes.unterminated_string,
      source = state.source,
      -- position at eof, so technically 1 char past the entire string
      position = {line = state.line, column = i - state.line_offset},
    })
    return i,token
  elseif newline_chars[next_char] then
    token.token_type = "invalid"
    put(token,'value',slice(str,index,i-1))
    admission.allocate(3*192+7*48+32)
    add_error_code_inst(token, error_code_util.new_error_code{
      error_code = error_code_util.codes.unterminated_string_at_eol,
      message_args = {tostring(state.line)},
      source = state.source,
      -- position at the newline
      position = {line = state.line, column = i - state.line_offset},
    })
    return i,token
  elseif next_char == "\\" then
    -- advance past an escape sequence...
    i = i + 1
    next_char = str:sub(i,i)
    if next_char == "x" then
      admission.allocate(34)
      local digits = str:match("^%x%x", i + 1)
      if not digits then
        token.token_type = "invalid"
        admission.allocate(4*192+10*48)
        add_error_code_inst(token, error_code_util.new_error_code{
          error_code = error_code_util.codes.invalid_hexadecimal_escape,
          message_args = {slice(str,i+1,math.min(#str,i+2))},
          source = state.source,
          -- start at \
          start_position = {line = state.line, column = (i - 1) - state.line_offset},
          -- stop at x
          stop_position = {line = state.line, column = i - state.line_offset},
        })
        i = i + 1 -- skip x
      else
        admission.allocate(33)
        append(parts,string.char(tonumber(digits,16)))
        i = i + 3 -- skip x and two hex digits
      end
      goto matching
    elseif newline_chars[next_char] then
      append(parts,"\n")
      i = consume_newline(str, i, state, next_char)
      goto matching
    elseif next_char == "z" then
      --skip z and whitespace
      i=i+1
      while str:sub(i,i):match("%s") do
        admission.enter()
        local char=str:sub(i,i)
        if newline_chars[char] then i=consume_newline(str,i,state,char)
        else i=i+1 end
      end
      goto matching
    elseif escape_sequence_lut[next_char] then
      append(parts,escape_sequence_lut[next_char])
      i = i + 1
      goto matching
    else
      admission.allocate(35)
      local digits_start, skip, digits = str:find("^(%d%d?%d?)",i)
      if digits_start then
        local number = tonumber(digits, 10)
        if number > 255 then
          token.token_type = "invalid"
          admission.allocate(4*192+10*48)
          add_error_code_inst(token, error_code_util.new_error_code{
            error_code = error_code_util.codes.too_large_decimal_escape,
            message_args = {digits},
            source = state.source,
            -- start at at \
            start_position = {line = state.line, column = (i - 1) - state.line_offset},
            -- stop at the last digit
            stop_position = {line = state.line, column = skip - state.line_offset},
          })
        else
          admission.allocate(33)
          append(parts,string.char(number))
        end
        i = skip + 1
        goto matching
      else
        token.token_type = "invalid"
        admission.allocate(4*192+10*48)
        add_error_code_inst(token, error_code_util.new_error_code{
          error_code = error_code_util.codes.unrecognized_escape,
          message_args = {next_char},
          source = state.source,
          -- start at \
          start_position = {line = state.line, column = (i - 1) - state.line_offset},
          -- stop at `next_char`
          stop_position = {line = state.line, column = i - state.line_offset},
        })
        -- nothing to skip
        goto matching
      end
    end
  end
end



---@param str string
---@param index integer
---@param state TokenizeState
---@return integer
---@return Token
local function read_block_string(str,index,state)
  admission.enter()
  local _,open_end = block_open(str,index)
  if not open_end then
    local token = new_token("invalid",index,state.line,index - state.line_offset)
    put(token,'value',"[")
    admission.allocate(2*192+5*48)
    add_error_code_inst(token, error_code_util.new_error_code{
      error_code = error_code_util.codes.invalid_block_string_open_bracket,
      source = state.source,
      -- position at [
      position = {line = state.line, column = index - state.line_offset},
    })
    return index+1,token
  end

  local pad=slice(str,index+1,open_end-1)
  local token_line = state.line
  local token_col = index - state.line_offset

  local has_leading_newline = false
  local next_index = open_end + 1
  do
    local first_char = str:sub(next_index,next_index)
    if newline_chars[first_char] then
      has_leading_newline = true
      next_index = consume_newline(str, next_index, state, first_char)
    end
  end

  admission.allocate(192+48)
  local parts = {""}
  while true do
    admission.enter()
    local stopped_at=scan(str,next_index,"^[^\r\n%]]$")
    local part,stop_char=slice(str,next_index,stopped_at-1),str:sub(stopped_at,stopped_at)
    append(parts,part)
    if stop_char == "]" then
      local stop=scan(str,stopped_at+1,"^=$")
      local bracket_end
      if stop-stopped_at-1==#pad and str:sub(stop,stop)=="]" then bracket_end=stop+1 end
      if bracket_end then
        local token = new_token("string", index, token_line, token_col)
        put(token,'value',join(parts))
        put(token,'src_is_block_str',true)
        put(token,'src_has_leading_newline',has_leading_newline)
        put(token,'src_pad',pad)
        return bracket_end, token
      else
        append(parts,"]")
        next_index = stopped_at + 1
      end
    elseif stop_char == "" then
      local token = new_token("invalid", index, token_line, token_col)
      admission.allocate(32+2+#pad+(has_leading_newline and 1 or 0))
      parts[1] = "["..pad.."["..(has_leading_newline and "\n" or "")
      put(token,'value',join(parts))
      admission.allocate(2*192+5*48)
      add_error_code_inst(token, error_code_util.new_error_code{
        error_code = error_code_util.codes.unterminated_block_string,
        source = state.source,
        -- position at eof, so technically 1 char past the entire string
        position = {line = state.line, column = stopped_at - state.line_offset},
      })
      return stopped_at, token
    else
      append(parts,"\n")
      next_index = consume_newline(str, stopped_at, state, stop_char)
    end
  end
end

---@param str string
---@param index integer
---@param state TokenizeState
---@return integer?
---@return Token?
local function read_number(str, index, state)
  admission.enter()
  local start_index = index
  ---cSpell:ignore llex
  -- this parsing matches how Lua parses numbers. While the logic is different, the result is identical
  -- see llex.c:229 (function "read_numeral")
  local exponent = "[Ee]"
  if str:find("^0[Xx]", index) then
    exponent = "[Pp]"
    index = index + 2
  end
  while true do
    admission.enter()
    local char=str:sub(index,index)
    if char:match(exponent) then
      index=index+1
      if str:sub(index,index):match("[+-]") then index=index+1 end
    elseif char:match("[%x.]") then index=index+1
    else break end
  end

  local src_value = slice(str,start_index,index-1)
  local value = tonumber(src_value)
  local token
  local error_code
  if value and state.use_int32 then
    if (value % 1) ~= 0
      or value > 0x7fffffff
      or src_value:find("%.")
      or src_value:find(exponent)
    then
      if value == 0x80000000 and not src_value:find("%.") and not src_value:find(exponent) then
        error_code = error_code_util.codes.number_exactly_past_max_int32
      else
        error_code = error_code_util.codes.number_must_be_int32
      end
      value = nil
    end
  end
  if value then
    token = new_token("number", start_index, state.line, start_index - state.line_offset)
    put(token,'src_value',src_value)
    put(token,'value',value)
  else
    token = new_token("invalid", start_index, state.line, start_index - state.line_offset)
    put(token,'value',src_value)
    admission.allocate(4*192+10*48)
    add_error_code_inst(token, error_code_util.new_error_code{
      error_code = error_code or error_code_util.codes.malformed_number,
      message_args = {src_value},
      source = state.source,
      -- start at the first char of the number
      start_position = {line = state.line, column = start_index - state.line_offset},
      -- stop at the last char of the number
      stop_position = {line = state.line, column = index - 1 - state.line_offset},
    })
  end
  return index, token
end

---@param invalid_char string
---@param index integer
---@param state TokenizeState
---@return integer
---@return Token
local function simple_invalid_token(invalid_char, index, state)
  admission.enter()
  local token = new_token("invalid",index,state.line,index - state.line_offset)
  put(token,'value',invalid_char)
  admission.allocate(3*192+7*48)
  add_error_code_inst(token, error_code_util.new_error_code{
    error_code = error_code_util.codes.invalid_token,
    message_args = {invalid_char},
    source = state.source,
    -- position at index
    position = {line = state.line, column = index - state.line_offset},
  })
  return index+1,token
end

local zero_byte = string.byte("0")
local nine_byte = string.byte("9")
---@param str string
---@param index integer
---@return boolean
local function is_digit(str, index)
  admission.enter()
  local byte = str:byte(index)
  return byte and zero_byte <= byte and byte <= nine_byte
end

---@param state TokenizeState
---@param index integer
---@return integer?
---@return Token?
local function next_token(state,index)
  admission.enter()
  if not index then index = 1 end
  local str = state.str
  local next_char = str:sub(index,index)
  if next_char == "" then
    return -- EOF
  end

  if next_char:match("%s") then
    local line_end=scan(str,index,"^[^%S\r\n]$")
    local value,newline=slice(str,index,line_end-1),str:sub(line_end,line_end)
    if not newline_chars[newline] then newline="" end
    local token = new_token("blank", index, state.line, index - state.line_offset)
    if newline ~= "" then -- ends with newline?
      admission.allocate(32+#value+1)
      put(token,'value',value.."\n")
      return consume_newline(str, line_end, state), token
    end
    put(token,'value',value)
    return line_end, token
  elseif next_char:match("[+*/%%^#;,(){}%]]") then
    return index+1,new_token(next_char,index,state.line,index - state.line_offset)
  elseif next_char:match("[>=<]") then
    return peek_equals(str,index,next_char,state.line,index - state.line_offset)
  elseif next_char == "[" then
    local peek = str:sub(index+1,index+1)
    if peek == "=" or peek == "[" then
      return read_block_string(str,index,state)
    else
      return index+1,new_token("[",index,state.line,index - state.line_offset)
    end
  elseif next_char == "-" then
    if str:sub(index+1,index+1) == "-" then
      if block_open(str, index + 2) then
        --[[
          read block string, build a token from that
        ]]
        local next_index,token = read_block_string(str,index+2,state)
        -- correct index and column
        token.index = index
        token.column = token.column - 2
        if token.token_type == "invalid" then
          admission.allocate(32+2+#token.value)
          token.value = "--"..token.value
        else
          token.token_type = "comment"
        end
        return next_index,token
      else
        local token_end=scan(str,index+2,"^[^\r\n]$")-1
        local text=slice(str,index+2,token_end)
        local token = new_token("comment",index,state.line,index - state.line_offset)
        put(token,'value',text)
        return token_end+1,token
      end
    else
      return index+1,new_token("-",index,state.line,index - state.line_offset)
    end
  elseif next_char == "~" then
    if str:sub(index+1,index+1) == "=" then
      return index+2,new_token("~=",index,state.line,index - state.line_offset)
    else
      return simple_invalid_token(next_char,index,state)
    end
  elseif next_char == ":" then
    if str:sub(index+1,index+1) == ":" then
      return index+2,new_token("::",index,state.line,index - state.line_offset)
    else
      return index+1,new_token(":",index,state.line,index - state.line_offset)
    end
  elseif next_char == "." then
    if str:sub(index+1,index+1) == "." then
      if str:sub(index+2,index+2) == "." then
        return index+3,new_token("...",index,state.line,index - state.line_offset)
      else
        return index+2,new_token("..",index,state.line,index - state.line_offset)
      end
    elseif is_digit(str, index + 1) then
      return read_number(str, index, state)
    else
      return index+1,new_token(".",index,state.line,index - state.line_offset)
    end
  elseif next_char == '"' then
    return read_string(str,index,next_char,state)
  elseif next_char == "'" then
    return read_string(str,index,next_char,state)
  elseif is_digit(next_char, 1) then
    return read_number(str, index, state)
  else
    -- try to match keywords/identifiers
    if next_char:match("^[_%a]$") then
      local match_end=scan(str,index+1,"^[_%w]$")-1
      local ident=slice(str,index,match_end)
      local token = new_token(
        keywords[ident] and ident or "ident",
        index,state.line,index - state.line_offset
      )
      if not keywords[ident] then
        put(token,'value',ident)
        if state.on_identifier then state.on_identifier(ident,token) end
      end
      return match_end+1,token
    else
      return simple_invalid_token(next_char,index,state)
    end
  end
end

---@class TokenizeState
---@field str string
---@field source string
---@field use_int32 boolean
---@field line integer
---@field line_offset integer @ the exact index of the last newline
---@field prev_line integer|nil
---@field prev_line_offset integer|nil
---see AstMain description for more info
---@field shebang_line string|nil

---@param str string
---@param source? string @ if provided it is used for the `source` field of error code instances
---@param options Options?
---@return fun(state: TokenizeState, index: integer|nil): integer|nil, Token next_token
---@return TokenizeState state
---@return integer? index
local function tokenize(str, source, options)
  admission.enter()
  local index
  admission.allocate(192+5*48)
  local state = {
    str = str,
    source = source,
    use_int32 = options and options.use_int32,
    line = 1,
    line_offset = 0, -- pretend the previous character was a newline. not too far fetched
  }
  if options and options.on_identifier then put(state,'on_identifier',options.on_identifier) end
  if str:find("^\xef\xbb\xbf") then -- ignore utf8 byte-order mark (BOM)
    state.line_offset = 3
    index = 4
  end
  ---cSpell:ignore skipcomment, lauxlib
  -- does the same thing as skipcomment in lauxlib.c
  if str:find("^#", index) then -- first line is a comment (Unix exec. file)?
    -- read first line and skip parsing it
    local stop=scan(str,index or 1,"^[^\n]$")
    local comment=slice(str,index or 1,stop-1)
    put(state,'shebang_line',comment)
    state.line_offset = stop - 1
    index = stop
  end
  return next_token,state,index
end

return tokenize
