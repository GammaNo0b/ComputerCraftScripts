local jsonutils = require('utils.jsonutils')

local content = jsonutils.readJsonFile('test.json')
print(textutils.serialise(content))