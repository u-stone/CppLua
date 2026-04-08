-- ==============================================================================
-- Scheme 2: LuaBridge Binding Test Script
-- ==============================================================================

local engine = require("lua_bridge") 
local Calculator = (type(engine) == "table" and engine.Calculator) or Calculator

print(">>> [LUABRIDGE] Starting comprehensive test...")

-- 1. Verify class factory function
local calc = Calculator(200.0)
assert(calc ~= nil, "Error: Unable to create instance via LuaBridge")

-- 2. Complex logic operation test
calc:multiply(2.0) -- 200 * 2 = 400
calc:add(100.0)    -- 400 + 100 = 500

local result = calc:get_value()
if result == 500.0 then
    print("  - Calculation logic verification successful: 500.0")
else
    error("Error: Calculation result error, expected 500.0, got " .. tostring(result))
end

-- 3. Reset and edge case verification
calc:reset()
assert(calc:get_value() == 0.0, "Error: Value is not 0 after reset()")
print("  - Reset function verification successful")

-- 4. Robustness test
local status, err = pcall(function() calc:add("invalid_string") end)
if not status then
    print("  - Caught expected error, type checking function normal: " .. err)
else
    error("Error: Expected type error not detected")
end

print(">>> [LUABRIDGE] All tests passed!")
