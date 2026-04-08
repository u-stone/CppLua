-- ==============================================================================
-- 方案二：LuaBridge 绑定测试脚本
-- ==============================================================================

local engine = require("lua_bridge") 
local Calculator = (type(engine) == "table" and engine.Calculator) or Calculator

print(">>> [LUABRIDGE] 开始执行综合测试...")

-- 1. 验证类工厂函数
local calc = Calculator(200.0)
assert(calc ~= nil, "错误：无法通过 LuaBridge 创建实例")

-- 2. 复杂逻辑运算测试
calc:multiply(2.0) -- 200 * 2 = 400
calc:add(100.0)    -- 400 + 100 = 500

local result = calc:get_value()
if result == 500.0 then
    print("  - 计算逻辑验证成功: 500.0")
else
    error("错误：计算结果错误，期望 500.0，实际得到 " .. tostring(result))
end

-- 3. 重置与边缘情况验证
calc:reset()
assert(calc:get_value() == 0.0, "错误：reset() 之后值不为 0")
print("  - 重置功能验证成功")

-- 4. 健壮性测试
local status, err = pcall(function() calc:add("invalid_string") end)
if not status then
    print("  - 捕获到了预期的错误，类型检查功能正常: " .. err)
else
    error("错误：未检测到预期的类型错误")
end

print(">>> [LUABRIDGE] 全部测试通过！")
