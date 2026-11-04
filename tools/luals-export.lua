-- Loaded only by the pinned LuaLS documentation hook, never by Factorio.
-- Keep parsed annotations: hover-oriented exports omit alias bodies/overloads.
local files = require 'files'
local original = export.makeDocObject.INIT
export.makeDocObject.INIT = function(source, seen)
    local obj = original(source, seen)
    obj.optional = source.optional or false
    if source.type and source.type:sub(1, 4) == 'doc.' then
        if type(source[1]) ~= 'table' then obj.literal = source[1] end
        if source.comment then
            obj.comment = type(source.comment) == 'table' and source.comment.text or source.comment
        end
        local uri = guide.getUri(source)
        local state = uri and files.getState(uri)
        local text = uri and files.getText(uri)
        if state and text and source.start and source.finish then
            obj.text = text:sub(guide.positionToOffset(state, source.start) + 1,
                               guide.positionToOffset(state, source.finish))
        end
    end
    return obj
end

for _, kind in ipairs({'doc.alias', 'doc.param', 'doc.type.arg', 'doc.type.array', 'doc.type.sign', 'doc.type.tablefield'}) do
    local previous = export.makeDocObject[kind]
    export.makeDocObject[kind] = function(source, obj, seen)
        previous(source, obj, seen)
        for _, key in ipairs({'extends', 'node', 'signs', 'param', 'field'}) do
            if source[key] then obj[key] = export.documentObject(source[key], seen) end
        end
    end
end

export.makeDocObject['doc.return'] = function(source, obj, seen)
    obj.returns = export.documentObject(source.returns, seen)
end

export.makeDocObject['doc.overload'] = function(source, obj, seen)
    obj.overload = export.documentObject(source.overload, seen)
end

export.makeDocObject['doc.type.function'] = function(source, obj)
    obj.args, obj.returns = {}, {}
    for _, arg in ipairs(source.args or {}) do
        obj.args[#obj.args + 1] = export.documentObject(arg)
    end
    for _, result in ipairs(source.returns or {}) do
        obj.returns[#obj.returns + 1] = export.documentObject(result)
    end
end

local originalFunction = export.makeDocObject['function']
export.makeDocObject['function'] = function(source, obj, seen)
    originalFunction(source, obj, seen)
    obj.annotations = {}
    obj.comments = {}
    for _, doc in ipairs(source.bindDocs or {}) do
        if doc.type == 'doc.comment' then
            obj.comments[#obj.comments + 1] = doc.comment.text
        elseif doc.type == 'doc.param' or doc.type == 'doc.return' or doc.type == 'doc.overload' then
            obj.annotations[#obj.annotations + 1] = export.documentObject(doc)
        end
    end
end

export.makeDocObject['getfield'] = function(source, obj)
    obj.aliases = {}
    for _, definition in ipairs(vm.getDefs(source)) do
        obj.aliases[#obj.aliases + 1] = {
            file = export.getLocalPath(guide.getUri(definition)),
            start = {guide.rowColOf(definition.start)},
            type = definition.type,
        }
    end
    table.sort(obj.aliases, export.sortDoc)
end
export.makeDocObject['getglobal'] = export.makeDocObject['getfield']

local originalEnum = export.makeDocObject['doc.enum']
export.makeDocObject['doc.enum'] = function(source, obj, seen)
    originalEnum(source, obj, seen)
    obj.members = {}
    for _, member in ipairs(vm.getEnums(source) or {}) do
        obj.members[#obj.members + 1] = export.documentObject(member, seen)
    end
end

export.makeDocObject['tablefield'] = function(source, obj, seen)
    obj.name = source.field[1]
    obj.value = export.documentObject(source.value, seen)
end

for _, kind in ipairs({'integer', 'number', 'string', 'boolean'}) do
    export.makeDocObject[kind] = function(source, obj)
        obj.value = source[1]
    end
end
