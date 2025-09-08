local mixer_peripheral = 'create:basin_0'
local fuel_deployer = 'create:deployer_6'

---@class MixingResult : Recipe
---@field items Item[]
---@field fluid? Fluid

---@class MixingRecipe
---@field result MixingResult
---@field ingredients Item[]
---@field fluids? Fluid[]
---@field heated? boolean
---@field forEachResult fun(self: MixingRecipe, itemAction: fun(item: Item), fluidAction: fun(fluid: Fluid))
---@field forEachIngredient fun(self: MixingRecipe, itemAction: (fun(item: Item): boolean), fluidAction: fun(fluid: Fluid): boolean): boolean


---@class Mixer : Catalyst
---@field name string
---@field itemResultHandler (fun(item: Item): boolean)
---@field fluidResultHandler (fun(fluid: Fluid): boolean)
local mixer = {
    name = 'mixing',
    itemResultHandler = function(_) return false end,
    fluidResultHandler = function(_) return false end
}

---@param data any
---@param parser Parser
---@return MixingRecipe|nil recipe
function mixer.parseRecipe(data, parser)
    if not data then return nil end

    local resultingItems = parser.parseList(data.result.items, parser.parseItem)
    if not resultingItems then return nil end

    local resultingFluid = parser.parseFluid(data.result.fluid)

    local result = {
        items = resultingItems
    }
    if resultingFluid then
        result.fluid = resultingFluid
    end

    local ingredients = parser.parseList(data.ingredients, parser.parseItem)
    if not ingredients then return nil end

    local fluids = parser.parseList(data.fluids, parser.parseFluid)

    ---@type MixingRecipe
    local recipe = {
        type = mixer.name,
        result = result,
        ingredients = ingredients,
        forEachIngredient = function(self, itemAction, fluidAction)
            local success = true
            for _, ingredient in pairs(self.ingredients) do
                if not itemAction(ingredient) then
                    success = false
                end
            end
            if self.fluids then
                for _, fluid in pairs(self.fluids) do
                    if not fluidAction(fluid) then
                        success = false
                    end
                end
            end
            return success
        end,
        forEachResult = function(self, itemAction, fluidAction)
            for _, item in pairs(self.result.items) do
                itemAction(item)
            end
            if self.result.fluid then
                fluidAction(self.result.fluid)
            end
        end
    }
    if fluids then
        recipe.fluids = fluids
    end
    if data.heated then
        recipe.heated = data.heated
    end
    return recipe
end

---@param recipe MixingRecipe
---@param amount integer
---@param storage Storage
---@return integer crafting
---@return string error
function mixer.craft(recipe, amount, storage)
    if #(peripheral.call(mixer_peripheral, 'list') or {}) > 0 then
        return 0, 'Already mixing items.'
    elseif #(peripheral.call(mixer_peripheral, 'tanks') or {}) > 0 then
        return 0, 'Already mixing fluids.'
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

    -- gather fluids
    ---@type table<string, FluidLocation[]>
    local fluid_locations = {}
    for _, fluid in ipairs(recipe.fluids or {}) do
        local required = fluid.amount * amount
        fluid_locations[fluid.name], count = storage.findFluid(fluid.name, required)
        amount = math.floor(math.min(1000, required, count) / fluid.amount)
        if amount <= 0 then
            return 0, 'Missing fluids.'
        end
    end

    -- gather fuel
    ---@type ItemLocation[]
    local fuel_locations = {}
    if recipe.heated then
        fuel_locations, count = storage.findItem('farmersdelight:straw', amount)
        if count <= 0 then
            return 0, 'Missing fuel.'
        elseif count < amount then
            amount = count
        end
    end

    -- insert ingredients
    for item, num in pairs(ingredients) do
        storage.extractItem(ingredient_locations[item], mixer_peripheral, nil, num * amount)
    end
    for _, fluid in pairs(recipe.fluids or {}) do
        storage.extractFluid(fluid_locations[fluid.name], mixer_peripheral, fluid.amount * amount)
    end
    storage.extractItem(fuel_locations, fuel_deployer, 1, amount)

    return amount, 'Item mixing.'
end

---@param storage Storage
function mixer.output(storage)
    local inventory = peripheral.wrap(mixer_peripheral)
    for slot, item in pairs(inventory.list()) do
        if slot > 9 then
            local stored = item.count - storage.insertItem(storage.itemlocation(inventory, slot), item.count)
            if stored > 0 and mixer.itemResultHandler({name = item.name, count = stored}) then
                mixer.itemResultHandler = function(_) return false end
            end
        end
    end
    for slot, fluid in pairs(inventory.tanks()) do
        if slot > 2 then
            local stored = fluid.amount - storage.insertFluid(storage.fluidlocation(inventory, slot), fluid.amount)
            if stored > 0 and mixer.fluidResultHandler({name = fluid.name, amount = stored}) then
                mixer.fluidResultHandler = function(_) return false end
            end
        end
    end
end

return mixer