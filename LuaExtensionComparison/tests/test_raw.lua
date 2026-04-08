-- ==============================================================================
-- 方案一：Raw C API 绑定测试脚本
-- ==============================================================================

local engine = require("lua_raw") 

print(">>> [RAW C API] 开始执行综合测试...")

-- 1. 全局 API 校验
assert(engine.PI ~= nil, "错误：全局常量 PI 未正确绑定")
print(string.format("  - PI 常量验证成功: %f", engine.PI))

local sum = engine.add(10.0, 20.0)
assert(sum == 30.0, "错误：全局 add 函数计算错误")
print("  - 全局 add 函数验证成功")

-- 2. Calculator 实例生命周期测试
print("  - 开始 Calculator 实例测试...")
local calc = engine.new(100.0)
assert(calc ~= nil, "错误：无法创建 Calculator 实例")

-- 验证成员函数调用
calc:add(50.0)
local val = calc:get_value()
assert(val == 150.0, "错误：加法计算结果不匹配")
print(string.format("  - 实例计算结果验证通过: %f", val))

-- 测试垃圾回收机制
calc = nil
collectgarbage("collect") -- 强制触发 GC，验证 __gc 是否调用
print("  - Calculator 实例 GC 测试完成，未发生崩溃")

print(">>> [RAW C API] 全部测试通过！")
