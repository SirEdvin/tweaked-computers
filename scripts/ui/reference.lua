-- Native selectable document blocks, not a Markdown viewer. No draft authority.
local M={}
local function height(text,kind,width)
  if kind=='code' then
    local _,lines=text:gsub('\n','')
    return math.min(320,math.max(64,(lines+1)*18+12))
  end
  -- Conservative wrapping allowance for the shipped fonts. Native word_wrap
  -- performs display wrapping; never insert line breaks into copied text.
  local columns=math.max(12,math.floor((width-24)/(kind=='heading' and 12 or 8)))
  local lines=1; local used=0
  for word in text:gmatch('%S+') do
    local _,length=word:gsub('[^\128-\191]','')
    if used>0 and used+1+length>columns then lines=lines+1; used=0 end
    local rows=math.floor(math.max(0,length-1)/columns)
    lines=lines+rows; used=(used>0 and used+1 or 0)+length-rows*columns
  end
  return lines*(kind=='heading' and 26 or 20)+12
end
function M.resize(parent,width)
  parent.style.width=width
  for _,element in ipairs(parent.children) do
    element.style.width=math.max(1,width-20) -- keep the vertical scrollbar clear
    element.style.height=height(element.text,element.tags.reference_kind,width-20)
  end
end
function M.show(parent,topic,width)
  local key=topic and topic.title or ''
  if parent.tags.reference_topic==key then M.resize(parent,width); return end
  parent.clear()
  local blocks=topic and topic.blocks or {{kind='prose',text='No matching topic. Clear Search or choose another category.'}}
  for i,block in ipairs(blocks) do
    local e=parent.add{type='text-box',name='block_'..i,text=block.text,
      style='tc_reference_'..block.kind,tags={reference_kind=block.kind}}
    e.read_only=true; e.word_wrap=block.kind~='code'
    e.style.rich_text_setting=defines.rich_text_setting.disabled
    e.tooltip={'tc-editor.copy-note'}
  end
  parent.tags={reference_topic=key}
  M.resize(parent,width)
  -- New text boxes place their caret at the end, and the next native layout can
  -- scroll back to that caret after scroll_to_top. Move it without focusing or
  -- selecting bytes, once at creation only. Never touch an unchanged selection.
  for _,element in ipairs(parent.children) do
    element.select(1,0); element.scroll_to_top(); element.scroll_to_left()
  end
  parent.scroll_to_top(); parent.scroll_to_left()
end
return M
