-- ==============================================================================
-- Scheme 1: Raw C API Binding Test Script
-- ==============================================================================

local engine = require("lua_raw") 

print(">>> [RAW C API] Starting comprehensive test...")

-- 1. Global API validation
assert(engine.PI ~= nil, "Error: Global constant PI not bound correctly")
print(string.format("  - PI constant verification successful: %f", engine.PI))

local sum = engine.add(10.0, 20.0)
assert(sum == 30.0, "Error: Global add function calculation error")
print("  - Global add function verification successful")

-- 2. Calculator instance lifecycle test
print("  - Starting Calculator instance test...")
local calc = engine.new(100.0)
assert(calc ~= nil, "Error: Unable to create Calculator instance")

-- Verify member function call
calc:add(50.0)
local val = calc:get_value()
assert(val == 150.0, "Error: Addition calculation result mismatch")
print(string.format("  - Instance calculation result verified: %f", val))

-- Test garbage collection mechanism
calc = nil
collectgarbage("collect") -- Force trigger GC to verify if __gc is called
print("  - Calculator instance GC test complete, no crash occurred")

print(">>> [RAW C API] All tests passed!")
