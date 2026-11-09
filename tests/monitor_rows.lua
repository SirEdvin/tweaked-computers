-- Shared fixture checks for row-text fronts (and legacy cell frames from older saves).
local renderer=require('scripts.rendering')
local M={}
-- Every native object a front, staging or retired frame owns.
function M.objects(r,fn)
  if not r then return end
  if r.panel then fn(r.panel) end
  if r.cursor then fn(r.cursor) end
  if r.rows then for _,o in pairs(r.rows) do if o.bg then fn(o.bg) end; if o.glyph then fn(o.glyph) end end end
  if r.cells then for _,c in ipairs(r.cells) do if c then
    if c.background then fn(c.background) end; if c.glyph then fn(c.glyph) end
  end end end
end
function M.count(r) local n=0; M.objects(r,function(o) if o.valid then n=n+1 end end); return n end
-- The front shows exactly its snapshot; `visible` (optional) is the expected row visibility.
function M.verify(r,visible)
  assert(r and r.row_version==1,'row-text front required')
  local s=r.snapshot
  if s.mode=='graphics' then -- A graphics display keeps only its panel.
    assert(next(r.rows)==nil and not r.cursor,'graphics front kept terminal rows'); return true
  end
  for y=1,s.height do
    local glyph,background=renderer.row_strings(s,y); local o=r.rows[y]
    assert(o and o.bg and o.bg.valid and o.bg.text==background,'row background differs from its snapshot')
    if glyph=='' then assert(not o.glyph,'blank row kept a glyph object')
    else assert(o.glyph and o.glyph.valid and o.glyph.text==glyph,'row glyphs differ from their snapshot') end
    if visible~=nil then assert(o.bg.visible==visible and (not o.glyph or o.glyph.visible==visible),'row visibility') end
  end
  return true
end
return M
