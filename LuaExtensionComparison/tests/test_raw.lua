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
local calc = engine.new_calculator(100.0)
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

-- 3. Test Polymorphism (Circle as Shape)
local circle = engine.new_circle(5.0)
assert(circle ~= nil, "Error: Unable to create Circle")
print(string.format("  - Circle area: %f", circle:area()))

-- 4. Test Batch Processing
local calc_batch = engine.new_calculator(10.0)
local data = {1.0, 2.0, 3.0}
local sum = calc_batch:process_batch(data)
assert(sum == 6.0, "Error: Batch processing failed")
print("  - Batch processing successful")

-- 5. Test Threading
print("  - Testing Threading...")
local lua_code = [[
    local x = 0
    for i = 1, 1000 do x = x + i end
    print("Lua thread completed execution.")
]]
engine.run_in_thread(lua_code)
os.execute("timeout /t 1 > nul") 
print("  - Threading test dispatched.")

print(">>> [RAW C API] All tests passed!")
