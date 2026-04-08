# Lua C++ 扩展开发深度指南

本指南旨在帮助新手深入理解 C++ 对 Lua 的扩展。我们将通过一个统一的示例场景——导出 `Calculator` 类——详细探讨三种主流绑定方案的实现逻辑。

---

## 1. 方案详解：从底层到现代

### 方案 1：Raw C API (原生方式)

这是与 Lua 交互的“母语”。你需要手动操作 Lua 的虚拟栈来传递数据，并负责内存安全。

#### 核心示例代码
```cpp
#include <lua.hpp>
#include "Calculator.h"

// 绑定 Calculator:add(val)
static int l_Calculator_add(lua_State* L) {
    // 1. 从栈中获取 Userdata 并校验类型
    Calculator** ud = (Calculator**)luaL_checkudata(L, 1, "CalculatorMeta");
    Calculator* calc = *ud;
    
    // 2. 从栈中获取第二个参数
    double val = luaL_checknumber(L, 2);
    
    // 3. 调用 C++ 方法
    calc->add(val);
    
    // 4. 返回值个数 (这里不返回值)
    return 0;
}

// 模块入口注册
extern "C" __declspec(dllexport) int luaopen_lua_raw(lua_State* L) {
    // 创建元表
    luaL_newmetatable(L, "CalculatorMeta");
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    
    // 注册方法
    lua_pushcfunction(L, l_Calculator_add);
    lua_setfield(L, -2, "add");
    
    // ... 绑定 new, gc 等 ...
    return 1;
}
```
**实现细节**：你需要显式地定义每一个函数的入栈和出栈操作，通过 `luaL_checkudata` 确保 Lua 脚本调用时传入的 `self` 参数确实是一个 `Calculator` 对象。这种方式虽然繁琐，但它是你完全控制内存和错误边界的唯一方式。

---

### 方案 2：LuaBridge (现代轻量封装)

LuaBridge 通过模板元编程自动帮你处理栈操作。

#### 核心示例代码
```cpp
#include <LuaBridge/LuaBridge.h>
#include "Calculator.h"

extern "C" __declspec(dllexport) int luaopen_lua_bridge(lua_State* L) {
    // 使用命名空间注册
    luabridge::getGlobalNamespace(L)
        .beginClass<Calculator>("Calculator")
            .addConstructor<void(*) (double)>() // 绑定构造函数
            .addFunction("add", &Calculator::add) // 自动处理栈操作
            .addFunction("get_value", &Calculator::get_value)
        .endClass();

    return 0;
}
```
**实现细节**：你不需要关注 `lua_State*` 指针或栈索引，LuaBridge 自动将 C++ 方法的参数类型映射到 Lua。例如 `&Calculator::add` 自动识别出它需要一个 `double` 参数。这种方式代码极度精简，且类型安全性得到了编译期的保障。

---

### 方案 3：Sol2 (工业界主流)

Sol2 极其强大，几乎可以绑定任何现代 C++ 结构。

#### 核心示例代码
```cpp
#include <sol/sol.hpp>
#include "Calculator.h"

extern "C" __declspec(dllexport) int luaopen_lua_sol2(lua_State* L) {
    sol::state_view lua(L);

    // 绑定类
    lua.new_usertype<Calculator>("Calculator",
        sol::constructors<Calculator(double)>(),
        "add", &Calculator::add,
        "get_value", &Calculator::get_value
    );

    // 绑定全局变量
    lua["PI"] = 3.14159;
    
    return 0;
}
```
**实现细节**：Sol2 将绑定简化为了声明式代码。`.new_usertype` 是一次性定义，绑定后在 Lua 中使用方式极其自然（如 `calc:add(50)`）。它在处理复杂类型（如 `std::vector`、自定义枚举）时的能力远超 LuaBridge，是目前工业界现代 C++ 项目处理 Lua 交互的首选。

---

## 2. 方案对比总结

| 特性 | Raw C API | LuaBridge | Sol2 |
| :--- | :--- | :--- | :--- |
| **代码量** | 极多 (样板代码) | 少 | 最少 (声明式) |
| **性能** | 理论最优 | 高 | 高 (极快) |
| **现代 C++ 兼容** | 无 (仅限 C 接口) | 好 | 极好 (支持闭包/智能指针) |
| **错误调试** | 极难 | 中 | 极好 (自动栈回溯) |

---

## 3. 给新手的进阶建议

1.  **从 Raw C API 开始打基础**：在深入高级库之前，写一遍 Raw C API 的类绑定。这会让你终身受益，因为当你面对 LuaBridge 或 Sol2 无法解决的奇怪内存报错时，只有理解了栈操作的人才能快速定位。
2.  **封装 C API 边界**：在 `core` C++ 库与绑定层之间，必须有一层稳定的 C ABI 封装。这不仅是跨语言的标准做法，也使得你的核心逻辑能够被 Python、Rust 等其他语言轻易复用。
3.  **防范异常穿越**：**切记**，Lua 是基于 C 的，不支持 C++ 的异常栈回溯。任何在绑定层调用的 C++ 代码必须包裹在 `try-catch` 中，错误通过 `luaL_error` 返回，否则程序大概率会崩溃。
