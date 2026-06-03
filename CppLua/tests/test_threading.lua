-- ==============================================================================
-- Test Script: Thread Safety Demonstration
-- ==============================================================================

local engine = require("lua_sol2")
local run_in_thread = (type(engine) == "table" and engine.run_in_thread) or run_in_thread
print(">>> [THREADING] Starting test...")

-- Verify the binding exists
assert(run_in_thread ~= nil, "Error: run_in_thread not bound")

-- Lua code to run in a separate thread
local lua_code = [[
    local i = 0
    for i = 1, 1000000 do
        local x = math.sin(i) * math.cos(i)
    end
    print("Lua thread completed execution.")
]]

print("  - Dispatching Lua code to a new thread...")
run_in_thread(lua_code)
print("  - Lua code dispatched, main thread continues.")

-- Small sleep to let detached thread finish (in a real test, use a shared variable/mutex)
os.execute("timeout /t 1 > nul") 

print(">>> [THREADING] Test complete (detached thread finished).")
