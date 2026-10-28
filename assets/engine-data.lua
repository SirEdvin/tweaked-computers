-- Isolated asset registration fixture ONLY; not a production data entry point.
local art = require("assets.sprites")
local directions = {"north", "east", "south", "west"}
local kinds = {"computer", "kv", "monitor", "logic", "configurator", "recipe_searcher", "factoriopedia_interface", "production_statistics"}
local states = {"off", "unpowered", "powered", "fault", "blinking"}
local count = 0
local function register(name, sprite, frame)
  local copy = table.deepcopy(sprite)
  copy.type, copy.name = "sprite", name
  copy.frame_count, copy.line_length, copy.animation_speed = nil, nil, nil
  if frame then copy.x = frame * copy.width end
  data:extend({copy})
  count = count + 1
end
for _, kind in ipairs(kinds) do
  local device = art.devices[kind]
  register("tc-art-" .. kind .. "-icon", {filename = device.icon, width = 64, height = 64})
  for _, direction in ipairs(directions) do
    local images = device[direction]
    local name = "tc-art-" .. kind .. "-" .. direction
    register(name .. "-body", images.body)
    register(name .. "-shadow", images.shadow)
    for _, state in ipairs(states) do
      local image = images.states[state]
      for frame = 0, (image.frame_count or 1) - 1 do
        register(name .. "-" .. state .. "-" .. frame, image, frame)
      end
    end
  end
end
for byte = 0, 255 do register("tc-art-glyph-" .. byte, art.glyphs[byte]) end
assert(count == 584, "complete artwork fixture inventory")
log("TC_ART_DATA_OK " .. count)
