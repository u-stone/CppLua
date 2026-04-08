-- ==============================================================================
-- 方案三：Sol2 绑定测试脚本
-- ==============================================================================

local engine = require("lua_sol2") 
local PI = (type(engine) == "table" and engine.PI) or PI
local Calculator = (type(engine) == "table" and engine.Calculator) or Calculator
local global_call_count = (type(engine) == "table" and engine.global_call_count) or global_call_count

print(">>> [SOL2] 开始执行综合测试...")

-- 1. 检查全局属性
assert(type(PI) == "number", "PI 属性类型错误")
print(string.format("  - PI 访问测试: %f", PI))

-- 2. usertype 实例化测试
local calc = Calculator.new(50.0)

-- 3. 连续调用链路测试 (Fluent Interface)
calc:add(50.0)      -- 100
calc:multiply(3.0)  -- 300
calc:add(20.0)      -- 320

assert(calc:get_value() == 320.0, "错误：连续计算结果错误")
print("  - 连续计算链路验证成功")

-- 4. 高频调用性能模拟
local start_time = os.clock()
for i = 1, 5000 do
    calc:add(1.0)
end
local end_time = os.clock()
print(string.format("  - 5000 次 add 调用耗时: %f 秒", end_time - start_time))

-- 5. 变量动态绑定验证
-- 验证全局调用计数器
assert(global_call_count ~= nil, "错误：全局调用计数器未暴露")
print(string.format("  - 当前全局调用计数: %d", global_call_count))

print(">>> [SOL2] 全部测试通过！")
