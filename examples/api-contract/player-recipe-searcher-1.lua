function start(event)
    local searcher = peripheral.find("recipe_searcher", "red")
    assert(searcher, "Connect a Recipe Searcher on red")
    local recipes = searcher.findRecipes("item", "iron-plate", "smelting")
    local limits = searcher.getLimits()
end
