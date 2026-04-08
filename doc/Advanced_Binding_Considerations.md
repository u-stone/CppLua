# 工业级 Lua C++ 扩展高阶考量

在进行 C++ 与 Lua 的大规模扩展开发时，仅仅完成基础函数绑定是不够的。以下是必须处理的高阶架构挑战，若处理不当，极易引发程序崩溃或内存泄漏。

## 1. 内存所有权 (Memory Ownership)
必须明确 Lua 中的 `userdata` 回收时，关联的 C++ 对象应如何处理。

*   **最佳实践**：尽量使用 `std::shared_ptr` 进行管理。`Sol2` 能自动识别 `std::shared_ptr`，实现跨语言的引用计数。

```cpp
// 示例：返回 shared_ptr，Sol2 自动接管生命周期
lua["create_shared_calculator"] = []() -> std::shared_ptr<Calculator> {
    return std::make_shared<Calculator>(0.0);
};
```

## 2. 异常传播 (Exception Propagation)
**绝不能让 C++ 异常跳出 Lua 的执行边界。**

*   **处理策略**：利用 Sol2 的 `sol::error` 转换机制。

```cpp
// 示例：安全除法，抛出 Lua 可捕获异常
lua["safe_divide"] = [](double a, double b) -> double {
    if (b == 0) throw sol::error("Division by zero!");
    return a / b;
};
```

## 3. 多态与虚函数 (Polymorphism)
Lua 无法直接感知 C++ 的运行时类型信息（RTTI）。如果您绑定了基类，但在 Lua 中通过指针持有派生类对象，直接调用基类虚函数可行，但无法直接获取派生类的特殊方法。

*   **处理策略**：通常需要手动为每个派生类分别注册。避免过度依赖复杂的虚函数树与 Lua 的动态类型进行跨语言交互。

## 4. 边界交叉性能 (Boundary Crossing)
频繁的 Lua-C++ 调用（Context Switching）是严重的性能瓶颈，涉及栈检查与类型转换。

*   **优化策略**：
    *   **批处理**：将数据打包为 Lua Table，一次性传入 C++ 进行处理，而不是循环调用单一功能函数。
    *   **热路径 (Hot Path)**：将核心算法放在 C++ 中执行，Lua 仅负责高层逻辑编排。

## 5. 复杂类型映射 (Type Mapping)
`std::vector`、`std::map` 在 Lua 中没有原生的映射。

*   **处理策略**：不要试图强行绑定复杂的嵌套容器结构。将它们转换为简单的 Lua Table 进行交互，或者在 C++ 侧提供专门的访问函数进行读写，而非直接操作内部容器对象。

## 6. 线程安全性 (Thread Safety)
**Lua 状态机 (`lua_State`) 本身不是线程安全的。**

*   **处理策略**：遵循“单一线程，单一状态机”的原则。严禁在多个线程间共享同一个 `lua_State`。如果必须并发，请为每个线程创建独立的状态机，并通过线程间消息队列进行数据交互。
