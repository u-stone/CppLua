-- ==============================================================================
-- Scheme 3: Sol2 Binding Test Script
-- ==============================================================================

local engine = require("lua_sol2") 
local PI = (type(engine) == "table" and engine.PI) or PI
local Calculator = (type(engine) == "table" and engine.Calculator) or Calculator
local global_call_count = (type(engine) == "table" and engine.global_call_count) or global_call_count

print(">>> [SOL2] Starting comprehensive test...")

-- 1. Check global properties
assert(type(PI) == "number", "Error: PI property type error")
print(string.format("  - PI access test: %f", PI))

-- 2. usertype instantiation test
local calc = Calculator.new(50.0)

-- 3. Fluent interface test
-- Test continuity of calculation results
calc:add(50.0)      -- 100
calc:multiply(3.0)  -- 300
calc:add(20.0)      -- 320

assert(calc:get_value() == 320.0, "Error: Continuous calculation result error")
print("  - Fluent interface verification successful")

-- 4. High-frequency call performance simulation
local start_time = os.clock()
for i = 1, 5000 do
    calc:add(1.0)
end
local end_time = os.clock()
print(string.format("  - Time for 5000 add calls: %f seconds", end_time - start_time))

-- 5. Variable dynamic binding verification
-- Verify global call counter
assert(global_call_count ~= nil, "Error: Global call counter not exposed")
print(string.format("  - Current global call count: %d", global_call_count))

-- 6. Test Advanced Bindings
print("  - Testing Advanced Bindings...")

-- Test Exception Handling (safe_divide)
local status, err = pcall(function() engine.safe_divide(10.0, 0.0) end)
assert(not status, "Error: safe_divide should have thrown an error on division by zero")
print("  - Exception handling test passed (caught expected error)")

-- Test Shared Pointer Ownership (create_shared_calculator)
local shared_calc = engine.create_shared_calculator()
assert(shared_calc ~= nil, "Error: Unable to create shared_ptr calculator")
shared_calc:add(10.0)
assert(shared_calc:get_value() == 10.0, "Error: Shared pointer calculator calculation mismatch")
print("  - Shared pointer ownership test passed")

print(">>> [SOL2] All tests passed!")

