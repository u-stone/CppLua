-- ==============================================================================
-- Scheme 3: Sol2 Binding Test Script
-- ==============================================================================

local engine = require("lua_sol2") 
local PI = (type(engine) == "table" and engine.PI) or PI
local Calculator = (type(engine) == "table" and engine.Calculator) or Calculator
local global_call_count = (type(engine) == "table" and engine.global_call_count) or global_call_count
local safe_divide = (type(engine) == "table" and engine.safe_divide) or safe_divide
local create_shared_calculator = (type(engine) == "table" and engine.create_shared_calculator) or create_shared_calculator

print(">>> [SOL2] Starting comprehensive test...")

-- 1. Check global properties
assert(type(PI) == "number", "Error: PI property type error")
print(string.format("  - PI access test: %f", PI))

-- 2. usertype instantiation test
local calc = Calculator.new(50.0)

-- 7. Test Polymorphism (Circle as Shape)
local circle = Circle.new(5.0)
assert(circle ~= nil, "Error: Unable to create Circle")
print(string.format("  - Circle area: %f", circle:area()))

-- 8. Test Batch Processing
local data = {1.0, 2.0, 3.0}
local calc_batch = Calculator.new(10.0)
local sum = calc_batch:process_batch(data)
assert(sum == 6.0, "Error: Batch processing failed")
print("  - Batch processing successful")



print(">>> [SOL2] All tests passed!")

