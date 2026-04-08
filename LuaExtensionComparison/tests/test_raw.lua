-- test_raw.lua
package.cpath = package.cpath .. ";../build/Release/?.dll"
local lib = require("lua_raw")
print("Raw API PI: " .. lib.PI)
local calc = lib.new(100)
calc:add(50)
print("Calc value: " .. calc:get_value())
