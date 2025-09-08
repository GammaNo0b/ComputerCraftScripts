local cookingpot_peripheral = 'farmersdelight:cooking_pot_1'
local extra_peripheral = 'create:depot_0'
local output_peripheral = 'create:depot_1'

---@class CookingRecipe : Recipe
---@field result Item
---@field ingredients Item[]
---@field extra? Item
---@field forEachResult fun(self: CookingRecipe, itemAction: fun(item: Item), fluidAction: fun(fluid: Fluid))
---@field forEachIngredient fun(self: CookingRecipe, itemAction: (fun(item: Item): boolean), fluidAction: fun(fluid: Fluid): boolean): string|nil Executes the actions for all ingredients and returns the name of the first ingredient failing.

---@class CookingPot : Catalyst
---@field name string
---@field itemResultHandler (fun(item: Item): boolean)
---@field fluidResultHandler (fun(fluid: Fluid): boolean)
local cookingpot = {
    name = 'cooking',
    itemResultHandler = function(_) return false end,
    fluidResultHandler = function(_) return false end
}

---@param data any
---@param parser Parser
---@return CookingRecipe|nil recipe
function cookingpot.parseRecipe(data, parser)
    if not data then return nil end

    local result = parser.parseItem(data.result)
    if not result then return nil end

    local ingredients = parser.parseList(data.ingredients, parser.parseItem)
    if not ingredients then return nil end

    ---@type CookingRecipe
    local recipe = {
        type = cookingpot.name,
        result = result,
        ingredients = ingredients,
        forEachIngredient = function(self, itemAction, fluidAction)
            for _, ingredient in pairs(self.ingredients) do
                itemAction(ingredient)
            end
            if self.extra then
                itemAction(self.extra)
            end
        end,
        forEachResult = function(self, itemAction, fluidAction)
            itemAction(self.result)
        end
    }
    return recipe
end

---@param recipe CookingRecipe
---@param amount integer
---@param storage Storage
---@return integer crafting
---@return string error
function cookingpot.craft(recipe, amount, storage)
    local content = peripheral.call(cookingpot_peripheral, 'list') or {}
    for slot = 1, 8 do
        if content[slot] then
            return 0, 'Already cooking items.'
        end
    end

    -- count ingredients
    ---@type table<string, integer>
    local ingredients = {}
    for _, item in ipairs(recipe.ingredients) do
        ingredients[item.name] = (ingredients[item.name] or 0) + item.count
    end

    -- gather ingredients
    ---@type table<string, ItemLocation[]>
    local ingredient_locations = {}
    local count
    for item, num in pairs(ingredients) do
        local required = num * amount
        ingredient_locations[item], count = storage.findItem(item, required)
        amount = math.floor(math.min(required, count) / num)
        if amount <= 0 then
            return 0, 'Missing ingredients.'
        end
    end

    -- gather extra ingredient
    if recipe.extra then
        local extra_locations
        local required = recipe.extra.count * amount
        extra_locations, count = storage.findItem(recipe.extra.name, required)
        amount = math.floor(math.min(required, count) / recipe.extra.count)
        if amount <= 0 then
            return 0, 'Missing extra.'
        end

        storage.extractItem(extra_locations, extra_peripheral, nil, recipe.extra.count * amount)
    end

    local slot = 1
    for item, num in pairs(ingredients) do
        for _ = 1, num do
            storage.extractItem(ingredient_locations[item], cookingpot_peripheral, slot, amount)
            slot = slot + 1
        end
    end

    return amount, 'Item cooking.'
end

---@param storage Storage
function cookingpot.output(storage)
    local output = peripheral.wrap(output_peripheral)
    for slot, item in pairs(output.list()) do
        local stored = item.count - storage.insertItem(storage.itemlocation(output, slot), item.count)
        if stored > 0 and cookingpot.itemResultHandler({name = item.name, count = stored}) then
            cookingpot.itemResultHandler = function(_) return false end
        end
    end
end

return cookingpot