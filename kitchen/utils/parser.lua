---@alias T T
---@alias K K
---@alias V V
---@class Parser : { parseString: (fun(data: any): string), parseList: (fun(data: any, parser: fun(data: any): T|nil): T[]|nil), parseTable: (fun(data: any, keyParser: (fun(data: any): K|nil), valueParser: (fun(data: any): V|nil)): table<K, V>|nil), parseItem: (fun(data: any): Item|nil), parseFluid: (fun(data: any): Fluid|nil) }
local parser = {}

---@param data any
---@return string|nil
function parser.parseString(data)
    if type(data) ~= 'string' then return nil end
    return data
end

---@generic T
---@param parser fun(data: any): T|nil
---@return T[]|nil
function parser.parseList(data, parser)
    if type(data) ~= 'table' then return nil end
    local list = {}
    local i = 1
    for _, element in ipairs(data) do
        local t = parser(element)
        if not t then return nil end
        list[i] = t
        i = i + 1
    end
    return list
end

---@generic K, V
---@param data any
---@param keyParser fun(data: any): K|nil
---@param valueParser fun(data: any): V|nil
---@return table<K, V>|nil
function parser.parseTable(data, keyParser, valueParser)
    if type(data) ~= 'table' then return nil end
    local tbl = {}
    for k, v in pairs(data) do
        local key = keyParser(k)
        if not key then return nil end
        local value = valueParser(v)
        if not value then return nil end
        tbl[key] = value
    end
    return tbl
end

---@param data any
---@return Item|nil
function parser.parseItem(data)
    if not data then return nil end
    if type(data) == 'string' then
        return {
            name = data,
            count = 1
        }
    elseif data.name then
        return {
            name = data.name,
            count = data.count or 1
        }
    end
    return nil
end

---@param data any
---@return Fluid|nil
function parser.parseFluid(data)
    if not data or not data.name or not data.amount then return nil end
    return {
        name = data.name,
        amount = data.amount
    }
end

return parser