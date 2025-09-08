local jsonutils = {}

local templates = {}

local function deepCopyTemplate(obj, template, json)
    for k, v in pairs(template) do
        if type(v) == 'string' and string.sub(v, 1, 1) == '#' then
            v = json[string.sub(v, 2)]
        elseif type(v) == 'table' then
            v = deepCopyTemplate({}, v, json)
        end
        obj[k] = v
    end
    return obj
end

local function readJsonTemplate(template, json)
    local tmp = templates[template]
    if not tmp then
        tmp = jsonutils.readJsonFile(template .. '.json')
        if not tmp then
            print('Unable to read template \'' .. template .. '\'.')
            return nil
        end
        templates[template] = tmp
    end
    return deepCopyTemplate({}, tmp, json)
end

function jsonutils.readJsonFile(path)
    local file = fs.open(path, 'r')
    if not file then return nil end
    local content = file.readAll()
    content = textutils.unserialiseJSON(content)
    if content.template then
        content = readJsonTemplate(content.template, content)
    end
    return content
end

return jsonutils