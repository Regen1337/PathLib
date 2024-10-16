-- Lua Pathing Library
-- Version: 1.2
-- Description: This library provides functionality for table traversal and manipulation.

local PathLib = {
    cacheSize = 5000,
    bDebugMode = true,
    bWrapWithErrorHandling = false,
    cache = {},
    deepCopyCache = {},
    circularCache = {}
}

PathLib.NodeType = {
    KEY = 1,
    INDEX = 2,
    WILDCARD = 3
}
local NODE_T_KEY = PathLib.NodeType.KEY
local NODE_T_INDEX = PathLib.NodeType.INDEX
local NODE_T_WILDCARD = PathLib.NodeType.WILDCARD

-- Utility
local unpack = (table and table.unpack) or unpack or error("unpack is not defined, please define it")
local tonumber, tostring, pairs, ipairs, type, getmetatable, setmetatable, concat = tonumber, tostring, pairs, ipairs, type, getmetatable, setmetatable, table.concat
local deepCopyCache = PathLib.deepCopyCache
local circularCache = PathLib.circularCache
local cache, cacheSize = PathLib.cache, PathLib.cacheSize

local function isTable(v) return type(v) == "table" end
local function isString(v) return type(v) == "string" end
local function isNil(v) return v == nil end

function PathLib.debugPrint(...) if PathLib.bDebugMode then _G.print(...) end end

local function findTraverse(t, currentPath, predicate, results)
    for k, v in pairs(t) do
        local newPath
        if type(k) == "number" then
            newPath = currentPath .. "[" .. tostring(k) .. "]"
        else
            newPath = currentPath .. (currentPath ~= "" and "." or "") .. tostring(k)
        end
        
        if predicate(v, newPath) then
            table.insert(results, newPath)
        end
        if isTable(v) then
            findTraverse(v, newPath, predicate, results)
        end
    end
end

local function flattenTraverse(t, prefix, result)
    for k, v in pairs(t) do
        local newKey
        if type(k) == "number" then
            newKey = prefix .. "[" .. tostring(k) .. "]"
        else
            newKey = prefix .. (prefix ~= "" and "." or "") .. tostring(k)
        end
        
        if isTable(v) then
            flattenTraverse(v, newKey, result)
        else
            result[newKey] = v
        end
    end
end

local function assertType(value, expectedType, paramName)
    if type(value) ~= expectedType then
        error(string.format("Expected %s to be %s, got %s", paramName, expectedType, type(value)), 3)
    end
end

local function wrapWithErrorHandling(func)
    return function(...)
        local success, result = pcall(func, ...)
        if not success then
            if type(result) == "string" and result:match("PathLib error:") then
                error(result, 2)
            else
                error("PathLib error: " .. tostring(result), 2)
            end
        end
        return result
    end
end

local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local function assertTableEquals(actual, expected, message)
    if actual == nil and expected == nil then
        return
    end
    if type(actual) ~= "table" or type(expected) ~= "table" then
        error(string.format("%s: expected tables, got %s and %s", message, type(actual), type(expected)), 2)
    end
    if #actual ~= #expected then
        error(string.format("%s: table length mismatch, expected %d, got %d", message, #expected, #actual), 2)
    end
    for i = 1, #expected do
        if type(actual[i]) == "table" and type(expected[i]) == "table" then
            assertTableEquals(actual[i], expected[i], message .. " (nested table at index " .. i .. ")")
        elseif actual[i] ~= expected[i] then
            error(string.format("%s: mismatch at index %d, expected %s, got %s", message, i, tostring(expected[i]), tostring(actual[i])), 2)
        end
    end
end

local function setRecursive(current, pathIndex, path, value)
    if pathIndex > #path then
        return
    end

    local node = path[pathIndex]
    if node.type == NODE_T_WILDCARD then
        for k, v in pairs(current) do
            if isTable(v) then
                setRecursive(v, pathIndex + 1, path, value)
            end
        end
    else
        if pathIndex == #path then
            if node.type == NODE_T_INDEX then
                current[tonumber(node.value)] = value
            else
                current[node.value] = value
            end
        else
            if node.type == NODE_T_INDEX then
                local index = tonumber(node.value)
                if isNil(current[index]) then
                    current[index] = {}
                end
                setRecursive(current[index], pathIndex + 1, path, value)
            else
                if isNil(current[node.value]) then
                    current[node.value] = {}
                end
                setRecursive(current[node.value], pathIndex + 1, path, value)
            end
        end
    end
end

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    if deepCopyCache[t] then return deepCopyCache[t] end

    local copy = {}
    deepCopyCache[t] = copy

    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[deepCopy(k)] = deepCopy(v)
        elseif type(v) == "function" or type(v) == "userdata" or type(v) == "thread" then
            -- For functions, userdata, and threads, we maintain the reference(?)
            copy[deepCopy(k)] = v
        else
            copy[deepCopy(k)] = v
        end
    end

    return setmetatable(copy, getmetatable(t))
end

local function checkCircular(t)
    if type(t) ~= "table" then
        return false
    end
    
    if circularCache[t] then
        return true
    end
    
    circularCache[t] = true
    
    for _, v in pairs(t) do
        if checkCircular(v) then
            return true
        end
    end
    
    circularCache[t] = nil
    return false
end

local function clearCircularCache()
    for k in pairs(circularCache) do
        circularCache[k] = nil
    end
end

-- AST implementation

local function createNode(type, value)
    return {type = type, value = value}
end

local function parsePath(path)
    local ast = {}
    local current = ""
    local inBracket = false

    for i = 1, #path do
        local char = path:sub(i, i)
        if char == "." and not inBracket then
            if current ~= "" then
                if current:find("*") then
                    table.insert(ast, createNode(NODE_T_WILDCARD, current))
                else
                    table.insert(ast, createNode(NODE_T_KEY, current))
                end
                current = ""
            end
        elseif char == "[" and not inBracket then
            if current ~= "" then
                if current:find("*") then
                    table.insert(ast, createNode(NODE_T_WILDCARD, current))
                else
                    table.insert(ast, createNode(NODE_T_KEY, current))
                end
                current = ""
            end
            inBracket = true
        elseif char == "]" and inBracket then
            if current ~= "" then
                if current:find("*") then
                    table.insert(ast, createNode(NODE_T_WILDCARD, current))
                else
                    table.insert(ast, createNode(NODE_T_INDEX, current))
                end
                current = ""
            end
            inBracket = false
        else
            current = current .. char
        end
    end

    if current ~= "" then
        if current:find("*") then
            table.insert(ast, createNode(NODE_T_WILDCARD, current))
        else
            table.insert(ast, createNode(NODE_T_KEY, current))
        end
    end

    return ast
end

local function handleWildcard(tbl, pattern, restPath)
    local results = {}
    for k, v in pairs(tbl) do
        if k:match(pattern) then
            if #restPath == 0 then
                table.insert(results, v)
            elseif isTable(v) then
                local subResult = PathLib.get(v, restPath)
                if subResult ~= nil then
                    if isTable(subResult) then
                        for _, sr in ipairs(subResult) do
                            table.insert(results, sr)
                        end
                    else
                        table.insert(results, subResult)
                    end
                end
            end
        end
    end
    return results
end

-- Cache implementation

local function addToCache(path, value)
    if #cache >= cacheSize then
        table.remove(cache, 1)
    end
    cache[path] = value
end

local function getFromCache(path)
    return cache[path]
end

-- Core functionality

local function get(tbl, path)
    if isString(path) then
        path = parsePath(path)
    end

    local current = tbl
    for i, node in ipairs(path) do
        if isNil(current) then return nil end

        if node.type == NODE_T_WILDCARD then
            local pattern = node.value:gsub("%*", ".*")
            return handleWildcard(current, "^" .. pattern .. "$", {unpack(path, i+1)})
        elseif isTable(current) then
            if node.type == NODE_T_INDEX then
                current = current[tonumber(node.value)]
            else
                current = current[node.value]
            end
        else
            return nil
        end
    end

    return current
end

local function set(tbl, path, value)
    if isString(path) then
        path = parsePath(path)
    end

    setRecursive(tbl, 1, path, value)
end

local function delete(tbl, path)
    if isString(path) then
        path = parsePath(path)
    end

    local current = tbl
    for i, node in ipairs(path) do
        if i == #path then
            if node.type == NODE_T_INDEX then
                table.remove(current, tonumber(node.value))
            else
                current[node.value] = nil
            end
            return true
        else
            if node.type == NODE_T_INDEX then
                current = current[tonumber(node.value)]
            else
                current = current[node.value]
            end
            if isNil(current) then
                return false
            end
        end
    end
end

-- Advanced features

local function find(tbl, predicate)
    local results = {}

    findTraverse(tbl, "", predicate, results)
    return results
end

local function flatten(tbl)
    local result = {}

    flattenTraverse(tbl, "", result)
    return result
end

local function unflatten(tbl)
    local result = {}

    for k, v in pairs(tbl) do
        local path = parsePath(k)
        local current = result
        for i, node in ipairs(path) do
            if i == #path then
                current[node.value] = v
            else
                current[node.value] = current[node.value] or {}
                current = current[node.value]
            end
        end
    end

    return result
end

-- Metatable and circular reference handling

local function isCircular(tbl)
    assertType(tbl, "table", "tbl")
    seenTables = {}
    return checkCircular(tbl)
end

-- Analysis functions

local function analyzePath(tbl, path)
    local result = {
        exists = false,
        value = nil,
        valueType = nil,
        isLeaf = false,
        depth = 0,
        pathComponents = {}
    }

    local current = tbl
    local components = parsePath(path)

    for i, node in ipairs(components) do
        result.pathComponents[i] = node.value
        result.depth = result.depth + 1

        if isNil(current) or not isTable(current) then
            break
        end

        if i == #components then
            result.exists = true
            result.value = current[node.value]
            result.valueType = type(result.value)
            result.isLeaf = not isTable(result.value)
        else
            current = current[node.value]
        end
    end

    return result
end

-- Public API

local function path(tbl, ...)
    local args = {...}
    if #args == 0 then
        error("PathLib error: No path provided", 2)
    end
    local path = concat(args, ".")
    local cached = getFromCache(path)
    if cached then return cached end

    local result = get(tbl, path)
    addToCache(path, result)
    return result
end

local function pathTo(tbl, ...)
    return path(tbl, ...)
end

local function setPath(tbl, value, ...)
    local path = concat({...}, ".")
    set(tbl, path, value)
    addToCache(path, value)
end

local function deletePath(tbl, ...)
    local path = concat({...}, ".")
    local result = delete(tbl, path)
    if result then
        addToCache(path, nil)
    end
    return result
end

local function validatePath(path)
    assertType(path, "string", "path")
    if path:match("%.%.") then
        error("Invalid path: contains empty segments", 2)
    end
    if path:match("^%.[^%[]") or path:match("[^%]]%.$") then
        error("Invalid path: starts or ends with a dot", 2)
    end
    if not path:match("^[%w_]") and not path:match("^%[") then
        error("Invalid path: must start with a word character or '['", 2)
    end
    -- Add more validation as needed
end

local function map(tbl, path, func)
    local values = get(tbl, path)
    if type(values) == "table" then
        for i, v in ipairs(values) do
            values[i] = func(v, path)
        end
        setPath(tbl, values, path)
    else
        setPath(tbl, func(values, path), path)
    end
    return tbl
end

local function filter(tbl, pathOrPredicate, predicateOrNil)
    local path, predicate
    if predicateOrNil then
        path = pathOrPredicate
        predicate = predicateOrNil
    else
        predicate = pathOrPredicate
    end

    local values = path and get(tbl, path) or tbl
    local filtered = {}
    
    if type(values) == "table" then
        for k, v in pairs(values) do
            if predicate(v, k) then
                table.insert(filtered, v)
            end
        end
        if path then
            setPath(tbl, filtered, path)
        end
    elseif predicate(values, path) then
        filtered = {values}
        -- Don't modify the original for single values
    end

    return filtered
end

local function reduce(tbl, path, reducer, initialValue)
    local values = path and PathLib.get(tbl, path) or tbl
    
    -- Handle case where get returns a function (e.g., for wildcards)
    if type(values) == "function" then
        values = values()
    end

    if type(values) == "table" then
        local result = initialValue
        if #values > 0 then
            -- Array-like table
            for i, v in ipairs(values) do
                result = reducer(result, v, i, path)
            end
        else
            -- Key-value pair table
            for k, v in pairs(values) do
                result = reducer(result, v, k, path)
            end
        end
        return result
    else
        -- Single value
        return reducer(initialValue, values, nil, path)
    end
end

do
    PathLib.assertType = assertType
    PathLib.assertEquals = assertEquals
    PathLib.assertTableEquals = assertTableEquals
    PathLib.wrapWithErrorHandling = wrapWithErrorHandling
    PathLib.setRecursive = setRecursive
    PathLib.deepCopy = deepCopy
    PathLib.checkCircular = checkCircular
    PathLib.clearCircularCache = clearCircularCache
    PathLib.createNode = createNode
    PathLib.parsePath = parsePath
    PathLib.handleWildcard = handleWildcard
    PathLib.addToCache = addToCache
    PathLib.getFromCache = getFromCache
    
    PathLib.get = get
    PathLib.set = set
    PathLib.delete = delete
    PathLib.find = find
    PathLib.flatten = flatten
    PathLib.unflatten = unflatten
    PathLib.isCircular = isCircular
    PathLib.analyzePath = analyzePath
    PathLib.path = path
    PathLib.pathTo = pathTo
    PathLib.setPath = setPath
    PathLib.deletePath = deletePath
    PathLib.validatePath = validatePath
    PathLib.map = map
    PathLib.filter = filter
    PathLib.reduce = reduce
end

if PathLib.bWrapWithErrorHandling then
    PathLib.get = wrapWithErrorHandling(PathLib.get)
    PathLib.set = wrapWithErrorHandling(PathLib.set)
    PathLib.delete = wrapWithErrorHandling(PathLib.delete)
    PathLib.find = wrapWithErrorHandling(PathLib.find)
    PathLib.flatten = wrapWithErrorHandling(PathLib.flatten)
    PathLib.unflatten = wrapWithErrorHandling(PathLib.unflatten)
    PathLib.isCircular = wrapWithErrorHandling(PathLib.isCircular)
    PathLib.analyzePath = wrapWithErrorHandling(PathLib.analyzePath)
end

return PathLib