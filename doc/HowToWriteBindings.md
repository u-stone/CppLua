# Lua C++ 扩展开发入门指南

本指南旨在帮助新手快速理解并上手编写 C++ 对 Lua 的扩展。我们推荐通过以下三种方案来对比学习。

---

## 快速上手：三种绑定方案对比

### 方案 1：Raw C API (原生方式)
**最底层，无依赖，最稳妥。**
*   **适用场景**：对外部依赖极其敏感、追求极致性能或接口极其简单的项目。
*   **编写要点**：
    1.  编写 `extern "C" int luaopen_xxx(lua_State* L)` 入口函数。
    2.  手动操作 Lua 栈（`lua_pushnumber`, `lua_getfield`, 等）。
    3.  通过 `luaL_newmetatable` 实现面向对象的类绑定。
*   **示例代码片段**：
    ```cpp
    static int l_add(lua_State* L) {
        double a = luaL_checknumber(L, 1);
        double b = luaL_checknumber(L, 2);
        lua_pushnumber(L, a + b); // 手动入栈
        return 1;
    }
    ```

### 方案 2：LuaBridge (现代轻量封装)
**语义清晰， Header-only，上手快。**
*   **适用场景**：不想引入大型第三方库，但又想告别繁琐栈操作的项目。
*   **编写要点**：
    1.  使用 `luabridge::getGlobalNamespace` 命名空间绑定。
    2.  `beginClass<T>("ClassName")` 声明类。
    3.  `.addFunction` 自动绑定成员方法。
*   **示例代码片段**：
    ```cpp
    luabridge::getGlobalNamespace(L)
        .beginClass<Calculator>("Calculator")
            .addConstructor<void(*) (double)>()
            .addFunction("add", &Calculator::add)
        .endClass();
    ```

### 方案 3：Sol2 (工业界主流)
**功能最强，工业级标准，写法现代。**
*   **适用场景**：大型 C++ 项目，接口复杂，且希望绑定层代码尽可能简洁的项目。
*   **编写要点**：
    1.  使用 `sol::state_view` 处理状态。
    2.  `lua.new_usertype<T>(...)` 定义类。
*   **示例代码片段**：
    ```cpp
    lua.new_usertype<Calculator>("Calculator",
        sol::constructors<Calculator(double)>(),
        "add", &Calculator::add
    );
    ```

---

## 新手建议
1.  **从 `raw_c_api` 开始**：即使以后不用，也要至少写一次，因为它是所有高级绑定库的底层。理解了栈和元表，你才能排查所有绑定报错。
2.  **工程实践**：永远把 **Core 逻辑** 和 **Lua 绑定层** 分离。绑定层坏了不应该导致核心逻辑崩溃。
3.  **异常处理**：永远不要让 C++ 异常直接抛到 Lua，必须在绑定函数内 `try-catch` 并转化为 `luaL_error`。
