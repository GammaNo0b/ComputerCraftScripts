local crafter_peripherals = {
    'create:mechanical_crafter_0',
    'create:mechanical_crafter_1',
    'create:mechanical_crafter_2',
    'create:mechanical_crafter_3',
    'create:mechanical_crafter_4',
    'create:mechanical_crafter_5',
    'create:mechanical_crafter_6',
    'create:mechanical_crafter_7',
    'create:mechanical_crafter_8'
}

local output_peripheral = 'minecraft:barrel_1'

local redstone_control_side = 'top'

---@class CraftingRecipe : Recipe
---@field result Item
---@field pattern string[]
---@field ingredients table<string, string>
---@field countIngredients fun(self: CraftingRecipe): table<string, integer>
---@field forEachResult fun(self: CraftingRecipe, itemAction: fun(item: Item), fluidAction: fun(fluid: Fluid))
---@field forEachIngredient fun(self: CraftingRecipe, itemAction: (fun(item: Item): boolean), fluidAction: fun(fluid: Fluid): boolean): boolean

---@class Crafter : Catalyst
---@field result Item The item currently being crafted.
---@field itemResultHandler (fun(item: Item): boolean)
---@field fluidResultHandler (fun(fluid: Fluid): boolean)
local crafter = {
    name = 'crafting',
    results = {},
    itemResultHandler = function(_) return false end,
    fluidResultHandler = function(_) return false end
}

---@param data any
---@param parser Parser
---@return CraftingRecipe|nil recipe
function crafter.parseRecipe(data, parser)
    if not data then return nil end

    local result = parser.parseItem(data.result)
    if not result then return nil end

    local pattern = parser.parseList(data.pattern, parser.parseString)
    if not pattern then return nil end

    local ingredients = parser.parseTable(data.ingredients, parser.parseString, parser.parseString)
    if not ingredients then return nil end

    ---@type CraftingRecipe
    local recipe = {
        type = crafter.name,
        result = result,
        pattern = pattern,
        ingredients = ingredients,
        countIngredients = function(self)
            local count = {}
            for _, row in ipairs(self.pattern) do
                for i = 1, string.len(row) do
                    local symbol = string.sub(row, i, i)
                    count[symbol] = (count[symbol] or 0) + 1
                end
            end
            return count
        end,
        forEachIngredient = function(self, itemAction, fluidAction)
            local success = true
            local count = self:countIngredients()
            for symbol, amount in pairs(count) do
                if not itemAction({name = self.ingredients[symbol], count = amount}) then
                    success = false
                end
            end
            return success
        end,
        forEachResult = function(self, itemAction, fluidAction)
            itemAction(self.result)
        end
    }
    return recipe
end

---@param recipe CraftingRecipe
---@param _ integer
---@param storage Storage
---@return integer crafting
---@return string error
function crafter.craft(recipe, _, storage)
    if crafter.result then
        return 0, 'Crafting still in progress.'
    end

    local symbols = recipe:countIngredients()
    -- find ingredients
    ---@type table<string, ItemLocation[]>
    local ingredient_locations = {}
    local count
    for symbol, amount in pairs(symbols) do
        local name = recipe.ingredients[symbol]
        if name then
            ingredient_locations[symbol], count = storage.findItem(name, amount)
            if amount > count then
                return 0, 'Missing ingredients.'
            end
        end
    end

    -- insert ingredients
    for r, row in ipairs(recipe.pattern) do
        for c = 1, string.len(row) do
            local symbol = string.sub(row, c, c)
            local locations = ingredient_locations[symbol]
            if locations then
                storage.extractItem(locations, crafter_peripherals[3 * r + c - 3], 1, 1)
            end
        end
    end

    -- activate using redstone
    redstone.setOutput(redstone_control_side, true)
    sleep(0.1)
    redstone.setOutput(redstone_control_side, false)

    crafter.result = recipe.result

    return 1, 'Crafting started.'
end

---@param storage Storage
function crafter.output(storage)
    local p = peripheral.wrap(output_peripheral)
    if p then
        for slot, item in pairs(p.list()) do
            local result = crafter.result
            if result and result.name == item.name then
                result.count = result.count - item.count
                if result.count <= 0 then
                    crafter.result = nil
                end
            end
            local stored = item.count - storage.insertItem(storage.itemlocation(p, slot), item.count)
            if stored > 0 and crafter.itemResultHandler({name = item.name, count = stored}) then
                crafter.itemResultHandler = function(_) return false end
            end
        end
    end
end

return crafter
