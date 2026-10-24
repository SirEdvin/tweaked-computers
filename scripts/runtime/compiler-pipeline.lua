-- Trusted compiler pipeline; transformed offline with the pinned Phobos grammar.
local parse=require('vendor.phobos.parser')
local tokenize=require('vendor.phobos.tokenize')
local messages=require('vendor.phobos.error_code_util')
local validate=require('compiler.validation')
local lower=require('compiler.lower')
local function compile(source,mode)
  local iterator,state,index=tokenize(source,'@computer')
  while true do
    local token
    index,token=iterator(state,index)
    if not token then break end
    if token.token_type=='ident' then validate.identifier(token.value,token) end
  end
  local main,diagnostics,expression
  if mode=='shell' then
    main,diagnostics=parse('return '..source,'@computer')
    expression=#diagnostics==0
    if not expression then main,diagnostics=parse(source,'@computer') end
  else main,diagnostics=parse(source,'@computer') end
  if #diagnostics>0 then
    local d=diagnostics[1]
    error({code='E_PROGRAM',message=messages.get_message(d),
      line=d.start_position and d.start_position.line or state.line,
      column=d.start_position and d.start_position.column or #source+1-state.line_offset},0)
  end
  local ok,generated,handlers,nodes=pcall(validate.emit,main,mode,expression)
  if not ok then
    if expression and type(generated)=='table' and generated.line==1 and type(generated.column)=='number' then
      generated.column=math.max(1,generated.column-7)
    end
    error(generated,0)
  end
  local artifact=lower.lower(main,validate.reject,validate.position,mode)
  return {source=source,mode=mode,handlers=handlers,nodes=nodes,artifact=artifact}
end
return compile
