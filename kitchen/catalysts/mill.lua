local mill_peripheral = 'create:millstone_0'

---@class MillingRecipe
---@field results Item[]
---@field ingredient string
---@field forEachResult fun(self: MillingRecipe, itemAction: fun(item: Item), fluidAction: fun(fluid: Fluid))
---@field forEachIngredient fun(self: MillingRecipe, itemAction: (fun(item: Item): boolean), fluidAction: fun(fluid: Fluid): boolean): boolean

---@class Mill : Catalyst
---@field name string
---@field itemResultHandler (fun(item: Item): boolean)
---@field fluidResultHandler (fun(fluid: Fluid): boolean)
local mill = {
    name = 'milling',
    itemResultHandler = function(_) return false end,
    fluidResultHandler = function(_) return false end
}

---@param data any
---@param parser Parser
---@return MillingRecipe|nil recipe
function mill.parseRecipe(data, parser)
    if not data then return nil end

    local results = parser.parseList(data.results, parser.parseItem)
    if not results then return nil end

    local ingredient = parser.parseString(data.ingredient)
    if not ingredient then return nil end

    ---@type MillingRecipe
    local recipe = {
        type = mill.name,
        results = results,
        ingredient = ingredient,
        forEachIngredient = function(self, itemAction, fluidAction)
            return itemAction({name = self.ingredient, count = 1})
        end,
        forEachResult = function(self, itemAction, fluidAction)
            for _, result in pairs(self.results) do
                itemAction(result)
            end
        end
    }
    return recipe
end

---@param recipe MillingRecipe
---@param amount integer
---@param storage Storage
---@return integer crafting
---@return string error
function mill.craft(recipe, amount, storage)
    if peripheral.call(mill_peripheral, 'getItemDetail', 1) then
        return 0, 'Already milling items.'
    end

    -- gather ingredient
    local ingredient_locations, count = storage.findItem(recipe.ingredient, amount)
    if count <= 0 then
        return 0, 'Missing ingredient.'
    elseif count < amount then
        amount = count
    end

    -- insert ingredients
    storage.extractItem(ingredient_locations, mill_peripheral, 1, amount)

    return amount, 'Item milling.'
end

---@param storage Storage
function mill.output(storage)
    local inventory = peripheral.wrap(mill_peripheral)
    for slot, item in pairs(inventory.list()) do
        if slot > 1 then
            local stored = item.count - storage.insertItem(storage.itemlocation(inventory, slot), item.count)
            if stored > 0 and mill.itemResultHandler({name = item.name, count = stored}) then
                mill.itemResultHandler = function(_) return false end
            end
        end
    end
end

return mill