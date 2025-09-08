local completion = require('cc.completion')

local kitchen = require('kitchen')

local running = true

local function split(str, sep)
    local split = {}
    local n = 1

    local last_i = 1
    for i = 1, string.len(str) do
        if string.sub(str, i, i) == sep then
            split[n] = string.sub(str, last_i, i - 1)
            n = n + 1
            last_i = i + 1
        end
    end
    split[n] = string.sub(str, last_i)

    return split
end

local function collect()
    while running do
        kitchen.collect()
        coroutine.yield()
    end
end

local function craft()
    while running do
        kitchen.craft()
        coroutine.yield()
    end
end

local function main()
    local history = {}
    local history_i = 1

    while true do
        write('kitschn> ')
        local line = read(nil, history, function(text) return completion.choice(text, { 'craft', 'exit', 'reload', 'show' }) end)
        if line ~= history[history_i - 1] then
            history[history_i] = line
            history_i = history_i + 1
        end
        local args = split(line, ' ')
        local command = args[1]

        if command == 'exit' then
            running = false
            break
        end

        if command == 'craft' then
            local item = args[2]
            local amount = args[3]
            if item and amount then
                kitchen.schedule({name = item, count = amount})
            end
        elseif command == 'reload' then
            kitchen.init()
        elseif command == 'show' then
            kitchen.print()
        end

        coroutine.yield()
    end
end

kitchen.init()

parallel.waitForAny(main, collect, craft)