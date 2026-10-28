-- Packaged headless draw-object smoke, not native-client rendering evidence.
local M = {}
function M.run()
  local surface = game.surfaces[1]
  local count = 0
  local function draw(name)
    assert(helpers.is_valid_sprite_path(name), "missing registered sprite: " .. name)
    local object = rendering.draw_sprite{
      sprite = name, surface = surface, target = {0, 0}, tint = {r = 0.7, g = 0.8, b = 1},
    }
    assert(object.valid and object.sprite == name)
    object.destroy()
    assert(not object.valid)
    count = count + 1
  end
  for _, kind in ipairs{"computer", "kv", "monitor", "logic", "configurator", "recipe_searcher", "factoriopedia_interface", "production_statistics"} do
    draw("tc-art-" .. kind .. "-icon")
    for _, direction in ipairs{"north", "east", "south", "west"} do
      local prefix = "tc-art-" .. kind .. "-" .. direction
      draw(prefix .. "-body")
      draw(prefix .. "-shadow")
      for _, state in ipairs{"off", "unpowered", "powered", "fault", "blinking"} do
        for frame = 0, (state == "blinking" and 3 or 0) do draw(prefix .. "-" .. state .. "-" .. frame) end
      end
    end
  end
  for byte = 0, 255 do draw("tc-art-glyph-" .. byte) end
  assert(count == 584)
  log("TC_CONTRACT artwork 584 registered sprite draw/destroy checks; headless only")
  log("TC_CONTRACT_TOTAL 1")
end
return M
