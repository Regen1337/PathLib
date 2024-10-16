local PathLib = require("PathLib")
local debugPrint = PathLib.debugPrint
local assertEquals, assertTableEquals = PathLib.assertEquals, PathLib.assertTableEquals

local function testGet()
    local testTable = {
        a = 1,
        b = {
            c = 2,
            d = {
                e = 3
            }
        },
        f = {4, 5, 6}
    }

    debugPrint("Test table:")
    for k, v in pairs(testTable) do
        debugPrint(k, type(v), v)
        if type(v) == "table" then
            for k2, v2 in pairs(v) do
                debugPrint("", k2, type(v2), v2)
            end
        end
    end

    assertEquals(PathLib.get(testTable, "a"), 1, "Simple key access failed")
    assertEquals(PathLib.get(testTable, "b.c"), 2, "Nested key access failed")
    assertEquals(PathLib.get(testTable, "b.d.e"), 3, "Deep nested key access failed")
    assertEquals(PathLib.get(testTable, "f[2]"), 5, "Array index access failed")
    assertEquals(PathLib.get(testTable, "nonexistent"), nil, "Nonexistent key should return nil")
    assertEquals(PathLib.get(testTable, "b.nonexistent"), nil, "Nonexistent nested key should return nil")
end

local function testSet()
    local testTable = {}

    PathLib.set(testTable, "a", 1)
    assertEquals(testTable.a, 1, "Simple key set failed")
    debugPrint("After setting 'a':", testTable.a)

    PathLib.set(testTable, "b.c", 2)
    assertEquals(testTable.b.c, 2, "Nested key set failed")
    debugPrint("After setting 'b.c':", testTable.b.c)

    PathLib.set(testTable, "d[1]", 3)
    assertEquals(testTable.d[1], 3, "Array index set failed")
    debugPrint("After setting 'd[1]':", testTable.d[1])
end

local function testDelete()
    local testTable = {
        a = 1,
        b = {
            c = 2,
            d = 3
        },
        e = {4, 5, 6}
    }

    PathLib.delete(testTable, "a")
    assertEquals(testTable.a, nil, "Simple key delete failed")

    PathLib.delete(testTable, "b.c")
    assertEquals(testTable.b.c, nil, "Nested key delete failed")
    assertEquals(testTable.b.d, 3, "Delete should not affect sibling keys")

    PathLib.delete(testTable, "e[2]")
    assertTableEquals(testTable.e, {4, 6}, "Array index delete failed")
end

local function testFind()
    local testTable = {
        a = 1,
        b = {
            c = 2,
            d = {
                e = 3
            }
        },
        f = {4, 5, 6}
    }

    local results = PathLib.find(testTable, function(v) return type(v) == "number" and v > 2 end)
    debugPrint("Find results:", table.concat(results, ", "))
    
    table.sort(results)
    local expectedResults = {"b.d.e", "f[1]", "f[2]", "f[3]"}
    table.sort(expectedResults)
    
    assertTableEquals(results, expectedResults, "Find with predicate failed")
end

local function testFlattenAndUnflatten()
    local testTable = {
        a = 1,
        b = {
            c = 2,
            d = {
                e = 3
            }
        },
        f = {4, 5, 6}
    }

    local flattened = PathLib.flatten(testTable)
    debugPrint("Flattened table:")
    local sortedKeys = {}
    for k in pairs(flattened) do
        table.insert(sortedKeys, k)
    end
    table.sort(sortedKeys)
    for _, k in ipairs(sortedKeys) do
        debugPrint(k, flattened[k])
    end
    assertTableEquals(flattened, {
        ["a"] = 1,
        ["b.c"] = 2,
        ["b.d.e"] = 3,
        ["f[1]"] = 4,
        ["f[2]"] = 5,
        ["f[3]"] = 6
    }, "Flatten failed")

    local unflattened = PathLib.unflatten(flattened)
    assertTableEquals(unflattened, testTable, "Unflatten failed")
end

local function testCircularReference()
    local testTable = {
        a = 1,
        b = {}
    }
    testTable.b.c = testTable

    debugPrint("Testing circular reference:")
    local isCircular = PathLib.isCircular(testTable)
    debugPrint("Circular table result:", isCircular)
    assertEquals(isCircular, true, "Circular reference detection failed")

    local nonCircularTable = {a = 1, b = {c = 2}}
    debugPrint("Testing non-circular reference:")
    isCircular = PathLib.isCircular(nonCircularTable)
    debugPrint("Non-circular table result:", isCircular)
    assertEquals(isCircular, false, "Non-circular table incorrectly detected as circular")

    local deepNonCircularTable = {
        a = 1,
        b = {
            c = 2,
            d = {
                e = 3,
                f = {
                    g = 4
                }
            }
        }
    }
    debugPrint("Testing deep non-circular reference:")
    isCircular = PathLib.isCircular(deepNonCircularTable)
    debugPrint("Deep non-circular table result:", isCircular)
    assertEquals(isCircular, false, "Deep non-circular table incorrectly detected as circular")
end

local function testWildcard()
    local testTable = {
        a = {
            b = 1,
            c = 2
        },
        d = {
            b = 3,
            c = 4
        },
        e = {
            f = {
                b = 5
            }
        }
    }

    debugPrint("Testing wildcard:")
    local result = PathLib.get(testTable, "*.b")
    debugPrint("Wildcard result '*.b':", table.concat(result, ", "))
    assertTableEquals(result, {1, 3}, "Wildcard get '*.b' failed")

    result = PathLib.get(testTable, "*.c")
    debugPrint("Wildcard result '*.c':", table.concat(result, ", "))
    assertTableEquals(result, {2, 4}, "Wildcard get '*.c' failed")

    result = PathLib.get(testTable, "*.f.b")
    debugPrint("Wildcard result '*.f.b':", table.concat(result, ", "))
    assertTableEquals(result, {5}, "Nested wildcard get '*.f.b' failed")

    result = PathLib.get(testTable, "*")
    debugPrint("Wildcard result '*':", #result)
    assertEquals(#result, 3, "Wildcard get '*' failed")
end

local function testAnalyzePath()
    local testTable = {
        a = 1,
        b = {
            c = 2,
            d = {
                e = 3
            }
        }
    }

    local analysis = PathLib.analyzePath(testTable, "b.d.e")
    assertTableEquals(analysis, {
        exists = true,
        value = 3,
        valueType = "number",
        isLeaf = true,
        depth = 3,
        pathComponents = {"b", "d", "e"}
    }, "Path analysis failed")
end

local function testErrorHandling()
    local success, error = pcall(function() PathLib.validatePath("invalid..path") end)
    assertEquals(success, false, "Invalid path should throw an error")
    assertEquals(string.match(error, "Invalid path: contains empty segments") ~= nil, true, "Error message mismatch")

    success, error = pcall(function() PathLib.path({}) end)
    assertEquals(success, false, "No path argument should throw an error")
    assertEquals(string.match(error, "PathLib error: No path provided") ~= nil, true, "Error message should mention no path provided")

    -- Test that multiple arguments are accepted
    success, error = pcall(function() return PathLib.path({a = {b = {c = 1}}}, "a", "b", "c") end)
    assertEquals(success, true, "Multiple arguments should be accepted")
    assertEquals(error, 1, "Path with multiple arguments should return correct value")
end

local function testCache()
    local testTable = {
        a = {
            b = {
                c = 1
            }
        }
    }

    -- First access should cache the result
    local result1 = PathLib.path(testTable, "a", "b", "c")
    assertEquals(result1, 1, "Initial path access failed")

    -- Modify the table directly
    testTable.a.b.c = 2

    -- Second access should return the cached result
    local result2 = PathLib.path(testTable, "a", "b", "c")
    assertEquals(result2, 1, "Cached path access failed")

    -- Clear the cache by setting a new value
    PathLib.setPath(testTable, 3, "a", "b", "c")

    -- Third access should return the new value
    local result3 = PathLib.path(testTable, "a", "b", "c")
    assertEquals(result3, 3, "Path access after cache clear failed")
end

local function testMap()
    local testTable = {
        a = {1, 2, 3},
        b = {
            c = {4, 5, 6},
            d = 7
        }
    }

    -- Test map on array
    PathLib.map(testTable, "a", function(v) return v * 2 end)
    assertTableEquals(testTable.a, {2, 4, 6}, "Map on array failed")

    -- Test map on nested array
    PathLib.map(testTable, "b.c", function(v) return v + 1 end)
    assertTableEquals(testTable.b.c, {5, 6, 7}, "Map on nested array failed")

    -- Test map on single value
    PathLib.map(testTable, "b.d", function(v) return v * 2 end)
    assertEquals(testTable.b.d, 14, "Map on single value failed")

    debugPrint("Map tests passed")
end

local function testFilter()
    local testTable = {
        a = {1, 2, 3, 4, 5},
        b = {
            c = {2, 4, 6, 8, 10},
            d = 7
        }
    }

    -- Test filter on array
    local resultA = PathLib.filter(testTable, "a", function(v) return v % 2 == 0 end)
    assertTableEquals(resultA, {2, 4}, "Filter on array failed")
    assertTableEquals(testTable.a, {2, 4}, "Filter should modify original table when path is provided")

    -- Test filter on nested array
    local resultB = PathLib.filter(testTable, "b.c", function(v) return v > 5 end)
    assertTableEquals(resultB, {6, 8, 10}, "Filter on nested array failed")
    assertTableEquals(testTable.b.c, {6, 8, 10}, "Filter should modify original table when path is provided")

    -- Test filter on single value (should not change original, but return filtered result)
    local resultD = PathLib.filter(testTable, "b.d", function(v) return v > 10 end)
    assertTableEquals(resultD, {}, "Filter on single value should return empty table when condition is not met")
    assertEquals(testTable.b.d, 7, "Filter on single value should not change the original value")

    -- Test filter without path (should not modify original table)
    local testArray = {1, 2, 3, 4, 5}
    local resultArray = PathLib.filter(testArray, function(v) return v % 2 == 0 end)
    assertTableEquals(resultArray, {2, 4}, "Filter without path failed")
    assertTableEquals(testArray, {1, 2, 3, 4, 5}, "Filter without path should not modify original table")

    debugPrint("Filter tests passed")
end

local function testReduce()
    local testTable = {
        a = {1, 2, 3, 4, 5},
        b = {
            c = {2, 4, 6, 8, 10},
            d = 7
        }
    }

    -- Test reduce on array
    local sum = PathLib.reduce(testTable, "a", function(acc, v) return acc + v end, 0)
    assertEquals(sum, 15, "Reduce sum on array failed")

    -- Test reduce on nested array
    local product = PathLib.reduce(testTable, "b.c", function(acc, v) return acc * v end, 1)
    assertEquals(product, 3840, "Reduce product on nested array failed")

    -- Test reduce on single value
    local double = PathLib.reduce(testTable, "b.d", function(acc, v) return v * 2 end, 0)
    assertEquals(double, 14, "Reduce on single value failed")

    debugPrint("Reduce tests passed")
end

local function runAllTests()
    local tests = {
        testGet,
        testSet,
        testDelete,
        testFind,
        testFlattenAndUnflatten,
        testCircularReference,
        testWildcard,
        testAnalyzePath,
        testErrorHandling,
        testCache,
        testMap,
        testFilter,
        testReduce
    }

    local passed = 0
    local failed = 0

    for _, test in ipairs(tests) do
        local success, error = pcall(test)
        if success then
            passed = passed + 1
            debugPrint("Test passed")
        else
            failed = failed + 1
            debugPrint("Test failed:", error)
        end
    end

    print(string.format("\nTest summary: %d passed, %d failed", passed, failed))
end

runAllTests()