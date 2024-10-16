# Lua Pathing Library

## Overview

The Lua Pathing Library is a flexible tool for traversing and manipulating nested Lua tables. It provides a simple and intuitive API for accessing, modifying, and analyzing complex data structures using string-based paths.

## Tested Languages

- Lua 5.1

## Features

- Easy access to nested table values using dot notation and array indices
- Set values at any depth in a table structure
- Delete values from nested tables
- Find values in complex structures using custom predicates
- Flatten and unflatten nested tables
- Detect circular references in tables
- Wildcard support for flexible querying
- Path analysis for detailed information about specific paths
- Caching mechanism for improved performance
- Map, filter, and reduce operations on nested data structures

## Installation

To use the Lua Pathing Library, simply include the `PathLib.lua` file in your Lua project.

```lua
local PathLib = require("PathLib")
```

Otherwise you can take the core file and do as you wish.

## Usage

### Basic Operations

```lua
-- Access nested values
local value = PathLib.get(table, "path.to.value")

-- Set nested values
PathLib.set(table, "path.to.new.value", 42)

-- Delete nested values
PathLib.delete(table, "path.to.delete")
```

### Advanced Features

```lua
-- Find values using a predicate
local results = PathLib.find(table, function(v) return type(v) == "number" and v > 10 end)

-- Flatten a nested table
local flat = PathLib.flatten(table)

-- Unflatten a table
local nested = PathLib.unflatten(flat)

-- Check for circular references
local isCircular = PathLib.isCircular(table)

-- Use wildcards
local results = PathLib.get(table, "*.users.*.name")

-- Analyze a path
local analysis = PathLib.analyzePath(table, "path.to.analyze")

-- Find values using a predicate
local results = PathLib.find(table, function(v) return type(v) == "number" and v > 10 end)

-- Flatten a nested table
local flat = PathLib.flatten(table)

-- Unflatten a table
local nested = PathLib.unflatten(flat)

-- Check for circular references
local isCircular = PathLib.isCircular(table)

-- Use wildcards
local results = PathLib.get(table, "*.users.*.name")

-- Analyze a path
local analysis = PathLib.analyzePath(table, "path.to.analyze")

-- Map operation
PathLib.map(table, "path.to.array", function(v) return v * 2 end)

-- Filter operation
local filtered = PathLib.filter(table, "path.to.array", function(v) return v % 2 == 0 end)

-- Reduce operation
local sum = PathLib.reduce(table, "path.to.array", function(acc, v) return acc + v end, 0)
```

## Examples

Check the `PathLibExample.lua` file for more detailed usage examples.

## Testing

The library comes with a test suite in `PathLibTest.lua`. Run this file to ensure everything is working correctly in your environment.

## Configuration

You can configure the library's behavior by modifying the following variables in `PathLib.lua`:

- `PathLib.cacheSize`: Set the maximum size of the cache
- `PathLib.bDebugMode`: Enable or disable debug output
- `PathLib.bWrapWithErrorHandling`: Enable or disable automatic error handling wrapping

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This library is released under the MIT License. See the LICENSE file for details.