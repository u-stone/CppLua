# C++ 函数重载绑定指南

本工程演示了在 Lua 绑定中处理 C++ 函数重载（Function Overloading）的两种工业级方法。

## 问题背景
C++ 支持同名但参数列表不同的函数，这在脚本语言（如 Lua）中会导致歧义，因为脚本语言往往不严格区分数值类型（如 int 和 double）。

## 1. 使用 Sol2 处理重载 (推荐)
Sol2 提供了 `sol::overload` 工具，可以自动根据传递给 Lua 的参数类型匹配最合适的 C++ 函数重载版本。

```cpp
// 绑定示例
"add", sol::overload(
    static_cast<void(Calculator::*)(double)>(&Calculator::add),
    static_cast<void(Calculator::*)(int)>(&Calculator::add)
)
```

## 2. 使用 LuaBridge 处理重载
LuaBridge 不具备自动类型匹配能力，因此必须为每个重载版本定义显式的 Lua 名称，或者使用 Lambda 包装器。

```cpp
// 绑定示例
.addFunction("add", static_cast<void(Calculator::*)(double)>(&Calculator::add))
.addFunction("add_int", static_cast<void(Calculator::*)(int)>(&Calculator::add))
```

## 建议
在大型项目中，如果重载逻辑复杂，推荐使用 `Sol2` 的 `sol::overload`，它能提供最符合 Lua 使用习惯（同一个函数名）的体验。
