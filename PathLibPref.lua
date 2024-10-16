local PathLib = require("PathLib")

-- test table
local testTable = {
    a = {
        b = {
            c = {
                d = {
                    e = "value1"
                }
            },
            f = "value2"
        },
        g = "value3"
    },
    h = {
        i = {
            j = "value4"
        }
    },
    k = "value5"
}

-- Test paths
local testPaths = {
    "a.b.c.d.e",
    "a.b.f",
    "a.g",
    "h.i.j",
    "k",
    "a.b.c.nonexistent",
    "x.y.z"
}

-- Benchmark functions
local get, set, delete = PathLib.get, PathLib.set, PathLib.delete
local clock, insert, ipairs, pairs, type = os.clock, table.insert, ipairs, pairs, type
local function benchmarkPathLib(table, path, iterations)
    local startTime = clock()
    for _ = 1, iterations do
        get(table, path)
    end
    return clock() - startTime
end

local function benchmarkNativeAccess(table, path, iterations)
    local pathComponents = {}
    for component in path:gmatch("[^.]+") do
        insert(pathComponents, component)
    end
    
    local startTime = clock()
    for _ = 1, iterations do
        local value = table
        for _, component in ipairs(pathComponents) do
            if type(value) ~= "table" then
                value = nil
                break
            end
            value = value[component]
        end
    end
    return clock() - startTime
end

local function average(t)
    local sum = 0
    for _, v in ipairs(t) do sum = sum + v end
    return sum / #t
end

-- Test runner
local function runPerformanceTest(path, iterations, trials)
    print(string.format("Testing path: %s", path))
    print(string.format("Iterations: %d, Trials: %d", iterations, trials))
    
    local pathLibTimes = {}
    local nativeTimes = {}
    
    for _ = 1, trials do
        insert(pathLibTimes, benchmarkPathLib(testTable, path, iterations))
        insert(nativeTimes, benchmarkNativeAccess(testTable, path, iterations))
    end
    
    local pathLibAvg = average(pathLibTimes)
    local nativeAvg = average(nativeTimes)
    
    print(string.format("PathLib average time: %.6f seconds", pathLibAvg))
    print(string.format("Native average time: %.6f seconds", nativeAvg))
    print(string.format("Performance ratio (PathLib/Native): %.2f", pathLibAvg / nativeAvg))
    print()
end

-- Run tests
collectgarbage("collect")

local iterations = 1000
local trials = 150

for _, path in ipairs(testPaths) do
    runPerformanceTest(path, iterations, trials)
end

-- Additional test for wildcard paths
print("Testing wildcard path: a.*.f")
local wildcardStartTime = clock()
for _ = 1, iterations do
    get(testTable, "a.*.f")
end
local wildcardEndTime = clock()
print(string.format("PathLib wildcard time: %.6f seconds", wildcardEndTime - wildcardStartTime))
print()

-- Test for setting a value
print("Testing PathLib.set")
local setStartTime = clock()
for _ = 1, iterations do
    set(testTable, "a.b.c.d.e", "new_value")
end
local setEndTime = clock()
print(string.format("PathLib set time: %.6f seconds", setEndTime - setStartTime))

local setStartTime = clock()
for _ = 1, iterations do
    testTable.a.b.c.d.e = "new_value"
end
local setEndTime = clock()
print(string.format("Regular set time: %.6f seconds", setEndTime - setStartTime))