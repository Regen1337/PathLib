-- Lua Pathing Library
-- Version: 1.0
-- Description: This library provides functionality for table traversal and manipulation.

local PathLib = {
    cacheSize = 5000,
    bDebugMode = true,
    bWrapWithErrorHandling = true,
    cache = {},
    deepCopyCache = {},
    circularCache = {}
}

-- Utility
local unpack = (table and table.unpack) or unpack or error("unpack is not defined, please define it")

local function isTable(v) return type(v) == "table" end
local function isString(v) return type(v) == "string" end
local function isNil(v) return v == nil end

function PathLib.debugPrint(...) if PathLib.bDebugMode then _G.print(...) end end

function PathLib.assertType(value, expectedType, paramName)
    if type(value) ~= expectedType then
        error(string.format("Expected %s to be %s, got %s", paramName, expectedType, type(value)), 3)
    end
end
local assertType = PathLib.assertType

function PathLib.wrapWithErrorHandling(func)
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
local wrapWithErrorHandling = PathLib.wrapWithErrorHandling

function PathLib.assertEquals(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end
local assertEquals = PathLib.assertEquals

function PathLib.assertTableEquals(actual, expected, message)
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
local assertTableEquals = PathLib.assertTableEquals

local deepCopyCache = PathLib.deepCopyCache
function PathLib.deepCopy(t)
    if not isTable(t) then return t end
    if deepCopyCache[t] then return deepCopyCache[t] end

    local copy = {}
    deepCopyCache[t] = copy

    for k, v in pairs(t) do
        copy[deepCopy(k)] = deepCopy(v)
    end

    return setmetatable(copy, getmetatable(t))
end
local deepCopy = PathLib.deepCopy

local circularCache = PathLib.circularCache
function PathLib.checkCircular(t)
    if type(t) ~= "table" then
        return false
    end
    
    if circularCache[t] then
        return true
    end
    
    circularCache[t] = true
    
    for _, v in pairs(t) do
        if PathLib.checkCircular(v) then
            return true
        end
    end
    
    circularCache[t] = nil
    return false
end
local checkCircular = PathLib.checkCircular

function PathLib.clearCircularCache()
    for k in pairs(circularCache) do
        circularCache[k] = nil
    end
end
local clearCircularCache = PathLib.clearCircularCache

-- AST implementation

PathLib.NodeType = {
    KEY = 1,
    INDEX = 2,
    WILDCARD = 3
}

function PathLib.createNode(type, value)
    return {type = type, value = value}
end
local createNode = PathLib.createNode

function PathLib.parsePath(path)
    local ast = {}
    local current = ""
    local inBracket = false

    for i = 1, #path do
        local char = path:sub(i, i)
        if char == "." and not inBracket then
            if current ~= "" then
                if current:find("*") then
                    table.insert(ast, createNode(PathLib.NodeType.WILDCARD, current))
                else
                    table.insert(ast, createNode(PathLib.NodeType.KEY, current))
                end
                current = ""
            end
        elseif char == "[" and not inBracket then
            if current ~= "" then
                if current:find("*") then
                    table.insert(ast, createNode(PathLib.NodeType.WILDCARD, current))
                else
                    table.insert(ast, createNode(PathLib.NodeType.KEY, current))
                end
                current = ""
            end
            inBracket = true
        elseif char == "]" and inBracket then
            if current ~= "" then
                if current:find("*") then
                    table.insert(ast, createNode(PathLib.NodeType.WILDCARD, current))
                else
                    table.insert(ast, createNode(PathLib.NodeType.INDEX, current))
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
            table.insert(ast, createNode(PathLib.NodeType.WILDCARD, current))
        else
            table.insert(ast, createNode(PathLib.NodeType.KEY, current))
        end
    end

    return ast
end
local parsePath = PathLib.parsePath

function PathLib.handleWildcard(tbl, pattern, restPath)
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
local handleWildcard = PathLib.handleWildcard

-- Cache implementation

local cache, cacheSize = PathLib.cache, PathLib.cacheSize
function PathLib.addToCache(path, value)
    if #cache >= cacheSize then
        table.remove(cache, 1)
    end
    cache[path] = value
end
local addToCache = PathLib.addToCache

function PathLib.getFromCache(path)
    return cache[path]
end
local getFromCache = PathLib.getFromCache

-- Core functionality

function PathLib.get(tbl, path)
    if isString(path) then
        path = parsePath(path)
    end

    local current = tbl
    for i, node in ipairs(path) do
        if isNil(current) then return nil end

        if node.type == PathLib.NodeType.WILDCARD then
            local pattern = node.value:gsub("%*", ".*")
            return handleWildcard(current, "^" .. pattern .. "$", {unpack(path, i+1)})
        elseif isTable(current) then
            if node.type == PathLib.NodeType.INDEX then
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

function PathLib.set(tbl, path, value)
    if isString(path) then
        path = parsePath(path)
    end

    local function setRecursive(current, pathIndex)
        if pathIndex > #path then
            return
        end

        local node = path[pathIndex]
        if node.type == PathLib.NodeType.WILDCARD then
            for k, v in pairs(current) do
                if isTable(v) then
                    setRecursive(v, pathIndex + 1)
                end
            end
        else
            if pathIndex == #path then
                if node.type == PathLib.NodeType.INDEX then
                    current[tonumber(node.value)] = value
                else
                    current[node.value] = value
                end
            else
                if node.type == PathLib.NodeType.INDEX then
                    local index = tonumber(node.value)
                    if isNil(current[index]) then
                        current[index] = {}
                    end
                    setRecursive(current[index], pathIndex + 1)
                else
                    if isNil(current[node.value]) then
                        current[node.value] = {}
                    end
                    setRecursive(current[node.value], pathIndex + 1)
                end
            end
        end
    end

    setRecursive(tbl, 1)
end

function PathLib.delete(tbl, path)
    if isString(path) then
        path = parsePath(path)
    end

    local current = tbl
    for i, node in ipairs(path) do
        if i == #path then
            if node.type == PathLib.NodeType.INDEX then
                table.remove(current, tonumber(node.value))
            else
                current[node.value] = nil
            end
            return true
        else
            if node.type == PathLib.NodeType.INDEX then
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

function PathLib.find(tbl, predicate)
    local results = {}

    local function traverse(t, currentPath)
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
                traverse(v, newPath)
            end
        end
    end

    traverse(tbl, "")
    return results
end

function PathLib.flatten(tbl)
    local result = {}

    local function traverse(t, prefix)
        for k, v in pairs(t) do
            local newKey
            if type(k) == "number" then
                newKey = prefix .. "[" .. tostring(k) .. "]"
            else
                newKey = prefix .. (prefix ~= "" and "." or "") .. tostring(k)
            end
            
            if isTable(v) then
                traverse(v, newKey)
            else
                result[newKey] = v
            end
        end
    end

    traverse(tbl, "")
    return result
end

function PathLib.unflatten(tbl)
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

function PathLib.isCircular(tbl)
    assertType(tbl, "table", "tbl")
    seenTables = {}
    return checkCircular(tbl)
end

-- Analysis functions

function PathLib.analyzePath(tbl, path)
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

function PathLib.path(tbl, ...)
    local args = {...}
    if #args == 0 then
        error("PathLib error: No path provided", 2)
    end
    local path = table.concat(args, ".")
    local cached = getFromCache(path)
    if cached then return cached end

    local result = PathLib.get(tbl, path)
    addToCache(path, result)
    return result
end

function PathLib.pathTo(tbl, ...)
    return PathLib.path(tbl, ...)
end

function PathLib.setPath(tbl, value, ...)
    local path = table.concat({...}, ".")
    PathLib.set(tbl, path, value)
    addToCache(path, value)
end

function PathLib.deletePath(tbl, ...)
    local path = table.concat({...}, ".")
    local result = PathLib.delete(tbl, path)
    if result then
        addToCache(path, nil)
    end
    return result
end

function PathLib.validatePath(path)
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