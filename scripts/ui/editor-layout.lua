-- GUI units are scaled by Factorio; screen locations are physical pixels.
-- Pure geometry, not evidence of native client rendering.
local M={minimum_width=760,minimum_height=480}
function M.measure(resolution,scale,focus)
  local available_width=math.floor(resolution.width/scale)
  local available_height=math.floor(resolution.height/scale)
  local width=math.max(1,math.min(1040,available_width-32))
  local height=math.max(1,math.min(940,available_height-32))
  return {width=width,height=height,content_width=math.max(1,width-56),
    content_height=math.max(1,height-(focus and 72 or 108)),
    source_height=math.max(40,height-(focus and 108 or 200)),
    supported=available_width>=M.minimum_width and available_height>=M.minimum_height}
end
function M.clamp(location,resolution,scale,size)
  return {x=math.max(0,math.min(location.x,math.max(0,resolution.width-math.ceil(size.width*scale)))),
    y=math.max(0,math.min(location.y,math.max(0,resolution.height-math.ceil(size.height*scale))))}
end
return M
