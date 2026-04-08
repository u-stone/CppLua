# Lua 扩展开发方案二：LuaBridge 现代轻量封装

## 1. 原理详解

LuaBridge 是一个轻量级的、Header-only 的 C++ 库，旨在为 Lua 交互提供一种简洁、现代且类型安全的语法，从而屏蔽底层冗余的 C API 栈操作。

### 核心机制：模板元编程 (Template Metaprogramming)
LuaBridge 的本质是利用 C++ 的模板元编程技术。当您在 LuaBridge 中使用 `.addFunction("add", &Calculator::add)` 这样的声明时，LuaBridge 会在编译期自动根据成员函数 `Calculator::add` 的签名（返回值类型和参数类型），生成相应的 C++ 函数模板实例化。这个模板实例化包含了从 Lua 栈读取参数（使用 `LuaBridge::Stack` 类）、调用 C++ 成员函数、以及将返回值压入 Lua 栈的全过程。

### 生命周期与类型映射
LuaBridge 自动处理 C++ 对象的生命周期。当您在 Lua 中调用构造函数时，LuaBridge 会在 Lua 的 Userdata 中分配内存，并调用 C++ 的 placement new 来初始化对象。同时，它会注册一个 C++ 生成的 `__gc` 元方法，当 Lua 的垃圾回收机制回收该 Userdata 时，会自动触发 C++ 对象的析构函数，防止内存泄漏。对于类型映射，它能够将 C++ 的 `int`、`double`、`std::string` 等基础类型与 Lua 类型自动互转，对于用户自定义类，通过 `beginClass` 注册后也能透明转换。

### 相对于 Raw C API 的优势
与 Raw C API 相比，LuaBridge 极大提升了开发效率：
1.  **无需手动栈管理**：开发者完全不需要关注 `lua_State*` 栈的压栈出栈次序，降低了出错概率。
2.  **代码可读性**：绑定逻辑更加贴近 C++ 的面向对象定义，代码可维护性极高。
3.  **类型安全**：借助 C++ 强类型系统，参数类型不匹配时能在底层自动抛出可识别的 Lua 错误。

---

## 2. 核心代码实现

为了演示，我们将 `Calculator` 类及相关全局元素导出给 Lua。

```cpp
#include <lua.hpp>
#include <LuaBridge/LuaBridge.h>
#include <iostream>
#include <string>
#include "../../core/math_engine.h"

// 假设我们需要向 Lua 暴露全局变量
// 确保变量在绑定前已正确初始化
double PI = 3.1415926535;

/**
 * 模块初始化入口函数
 * 必须使用 extern "C" 声明，确保 Lua 可以正确查找到此导出符号
 */
extern "C" __declspec(dllexport) int luaopen_lua_bridge(lua_State* L) {
    // 1. 获取全局命名空间 (Global Namespace)
    // 这是 LuaBridge 的顶层入口，所有的绑定都在命名空间中进行
    luabridge::getGlobalNamespace(L)
        // 2. 注册类：Calculator
        .beginClass<Calculator>("Calculator")
            // 绑定构造函数：接受一个 double 参数
            .addConstructor<void(*) (double)>()
            // 绑定成员方法：自动处理参数与返回值映射
            .addFunction("add", &Calculator::add)
            .addFunction("multiply", &Calculator::multiply)
            .addFunction("get_value", &Calculator::get_value)
            .addFunction("reset", &Calculator::reset)
        .endClass() // 结束类绑定
        
        // 3. 绑定全局函数
        // 任何满足 C 风格签名的函数都可以被直接添加
        .addFunction("add_global", &add)
        
        // 4. 绑定全局变量
        // 第三个参数 false 表示为只读变量
        .addVariable("PI", &PI, false);

    // LuaBridge 绑定的模块通常不需要显式返回表，
    // 因为它直接将类和函数注册到了全局命名空间中。
    return 0;
}

// 附注：如果你需要更复杂的逻辑，比如自定义错误处理，
// LuaBridge 提供了 luabridge::LuaException 类。
// 当发生类型不匹配时，它会抛出异常，通常在绑定的
// C++ 函数内部捕获并处理。
```

### 实现细节与注意事项
*   **命名空间作用域**：`luabridge::getGlobalNamespace(L)` 直接操作 Lua 全局环境。如果需要隔离，可以先通过 `luabridge::getGlobalNamespace(L).beginNamespace("myEngine")` 创建一个新的 Lua Table 作为命名空间。
*   **const 成员与只读属性**：在 `.addVariable` 中，通过第三个参数 `bool isWritable` 控制变量是否在 Lua 中可被修改。对于 `const` 类型的 C++ 变量，此参数必须设置为 `false`。
*   **构造函数绑定**：`.addConstructor<void(*) (double)>()` 中的模板参数是函数指针类型，指明了构造函数所需的参数列表。确保 C++ 侧有对应的构造函数重载。
*   **库的轻量级优势**：LuaBridge 的所有实现都在头文件中，这意味着你不需要额外的 `.lib` 文件来编译 LuaBridge 本身，这简化了复杂的 CMake 项目构建流程。
