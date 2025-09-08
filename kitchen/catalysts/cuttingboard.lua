local cuttingboard_peripheral = 'farmersdelight:cutting_board_1'
local knife_deployer_peripheral = 'create:deployer_3'
local output_peripheral = 'minecraft:barrel_2'

---@class CuttingRecipe : Recipe
---@field results Item[]
---@field ingredient string
---@field forEachResult fun(self: CuttingRecipe, itemAction: fun(item: Item), fluidAction: fun(fluid: Fluid))
---@field forEachIngredient fun(self: CuttingRecipe, itemAction: (fun(item: Item): boolean), fluidAction: fun(fluid: Fluid): boolean): boolean

---@class CuttingBoard : Catalyst
---@field name string
---@field itemResultHandler (fun(item: Item): boolean)
---@field fluidResultHandler (fun(fluid: Fluid): boolean)
local cuttingboard = {
    name = 'cutting',
    itemResultHandler = function(_) return false end,
    fluidResultHandler = function(_) return false end
}

---@param data any
---@param parser Parser
---@return CuttingRecipe|nil recipe
function cuttingboard.parseRecipe(data, parser)
    if not data then return nil end

    local results = parser.parseList(data.results, parser.parseItem)
    if not results then return nil end

    local ingredient = parser.parseString(data.ingredient)
    if not ingredient then return nil end

    ---@type CuttingRecipe
    local recipe = {
        type = cuttingboard.name,
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

---@param storage Storage
---@return boolean cleared
function cuttingboard.clear(storage)
    local location = storage.itemlocation(peripheral.wrap(cuttingboard_peripheral), 1)
    storage.insertItem(location)
    return location:isEmpty()
end

---@return boolean hasKnife
function cuttingboard.hasKnife()
    return nil ~= peripheral.call(knife_deployer_peripheral, 'getItemDetail', 1)
end

---@param location ItemLocation
---@return boolean success
function cuttingboard.putKnife(location)
    return location:move(knife_deployer_peripheral) > 0
end

---@param recipe CuttingRecipe
---@param amount integer
---@param storage Storage
---@return integer crafting
---@return string error
function cuttingboard.craft(recipe, amount, storage)
    if not cuttingboard.hasKnife() then
        return 0, 'Missing knife.'
    end

    local content = peripheral.call(cuttingboard_peripheral, 'getItemDetail', 1)
    if content then
        return 0, 'Already cutting item.'
    end

    local ingredient_locations, count = storage.findItem(recipe.ingredient, 1)
    if count <= 0 then
        return 0, 'Missing ingredients.'
    end

    if storage.extractItem(ingredient_locations, cuttingboard_peripheral, 1, 1) > 0 then
        return 0, 'Missing ingredients.'
    end

    return 1, 'Item cutting.'
end

---@param storage Storage
function cuttingboard.output(storage)
    local output = peripheral.wrap(output_peripheral)
    for slot, item in pairs(output.list()) do
        local stored = item.count - storage.insertItem(storage.itemlocation(output, slot), item.count)
        if stored > 0 and cuttingboard.itemResultHandler({name = item.name, count = stored}) then
            cuttingboard.itemResultHandler = function(_) return false end
        end
    end
end

return cuttingboard