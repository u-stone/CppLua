# Lua 扩展开发方案一：原生 Raw C API 深度实施指南

## 一、 深度原理详解

原生 Raw C API 是 Lua 官方提供的一套基于 C 语言的底层交互接口。它不依赖任何第三方库，提供了对 Lua 虚拟机最直接、最高效的控制能力。理解 Raw C API 是深入掌握 Lua 扩展开发的必经之路。对于追求极致性能、零依赖的项目，它是唯一选择。

### 1. Lua 虚拟机与虚拟栈 (Virtual Stack) 详解
Lua 的核心是其虚拟栈机模型。Lua 虚拟机与宿主语言（C/C++）之间的所有数据交互都通过一个栈进行。栈是一个 LIFO (后进先出) 的双向结构。
*   **交互过程**：当 Lua 调用一个 C 函数时，Lua 会将参数依次压入栈中，栈顶是该函数的最后一个参数。C 函数通过栈索引 `1` (栈底，即第一个参数)、`2`，或通过负索引 `-1` (栈顶，即最后一个参数)、`-2` 等来访问这些数据。C++ 在处理完业务逻辑后，将结果压回栈顶，并返回一个整数告知 Lua 栈中有多少个返回值。
*   **内存空间管理**：Lua 栈不仅仅是传递参数的地方，它还是 C++ 操作 Lua 数据的缓冲区。开发者必须使用 `lua_checkstack` 确保栈有足够的空间，否则会崩溃。这种机制虽然底层且繁琐，但它有效地解耦了 Lua 的 GC (垃圾回收) 与 C++ 的手动内存管理。C++ 逻辑在操作数据前，必须确保相关数据已进入栈，并进行明确的类型检查和转换。
*   **类型检查**：Raw C API 提供了 `luaL_check*` 系列函数（如 `luaL_checkinteger`, `luaL_checknumber`, `luaL_checkudata`）。它们在检查失败时会调用 `luaL_error`，直接中止 Lua 脚本的当前执行，并抛出带有详细位置信息的错误，这是开发中的重要调试利器。

### 2. Userdata 与 Metatable：实现面向对象的关键
Lua 是一门弱类型语言，本身并不支持类和对象的定义。为了将 C++ 类实例导出给 Lua 使用，我们必须通过 Userdata 和 Metatable 实现一套自定义的对象系统。
*   **Userdata 内存模型**：`lua_newuserdata` 会在 Lua 的托管内存中申请一块连续的字节空间。我们将 C++ 对象的指针存入这块内存（或者直接 placement new 将对象实例存入，但这涉及复杂的生命周期管理）。通常的做法是存储一个指针，以避免 C++ 对象过早析构。
*   **Metatable (元表)**：Userdata 本身是没有行为的。为了实现 `calc:add()` 的调用，我们需要通过 `luaL_newmetatable` 创建一个元表。该元表包含一个特殊键 `__index`，指向一个存放方法函数的表。当 Lua 在 Userdata 上查找方法时，它会触发 `__index` 查找，从而找到 C++ 绑定的函数。
*   **构造与方法调用**：在构造函数 `new` 中，我们创建一个 Userdata，将 C++ 指针存入，并为其设置元表。此后，所有对该 Userdata 的方法调用都会通过元表路由到相应的 C++ 函数。

### 3. 生命周期管理与 GC (__gc)
内存安全是 C++ 扩展开发的核心。当 Lua 中的 Userdata 实例因为引用计数归零而被 GC 回收时，Lua 解释器并不知道该 Userdata 指向的 C++ 堆内存需要被 `delete`。
*   **__gc 的使命**：如果在元表中定义了 `__gc` 方法，Lua GC 在彻底销毁 Userdata 前会调用此函数。我们必须在此函数中获取 C++ 指针并执行 `delete`，同时必须显式将指针置空，防止重入或野指针访问。
*   **预防性检查**：在复杂系统中，仅有 `__gc` 是不够的。如果 Lua 脚本在对象被 GC 后通过其它方式持有该 Userdata 指针，继续调用方法会导致严重的 UAF (Use-After-Free) 漏洞。因此，工业界做法是维护一个 `bool is_valid` 标志位，在 `__gc` 中将其置 `false`，在每次方法调用前校验该标志。

### 4. ABI 稳定、符号导出与多版本兼容
Lua 的不同版本（5.1, 5.2, 5.3, 5.4, LuaJIT）在 API 上存在细微但致命的差异（例如 `luaL_register` 在 5.2 后被废弃）。
*   **C ABI**：为了确保扩展库在不同版本的 Lua 解释器下都能被动态加载，函数必须声明为 `extern "C"`。
*   **符号可见性**：在 Windows 上，不仅需要 `__declspec(dllexport)`，还要注意 `dumpbin /exports` 查看符号是否被正确导出。
*   **C API 与 C++ 的桥接**：由于 Lua 的错误处理是基于 `longjmp` 的，**绝对严禁**在 Raw C API 的函数中直接让 C++ 异常跳过 Lua 边界。所有 C++ 代码都必须包裹在 `try-catch` 中，错误通过 `luaL_error` 转化为 Lua 错误。

---

## 二、 详尽的代码示例：实现完整的 Calculator 绑定

本示例展示了如何实现一个包含了：C++ 对象构造、多成员方法、GC 生命周期管理、全局变量和全局函数导出的复杂绑定。

```cpp
#include <lua.hpp>
#include <iostream>
#include <string>
#include <vector>
#include "../../core/math_engine.h"

// 宏定义元表名称，用于在 Lua 虚拟机内进行类型校验
#define META_CALC "CalculatorMeta"

/**
 * --- 辅助函数：类型安全检查 ---
 * luaL_checkudata 是 Raw C API 编程中最基础且最重要的安全防护。
 * 它检查栈上指定位置是否确实是一个具有特定元表的 Userdata 对象。
 * 如果类型不匹配，luaL_checkudata 会直接在 Lua 层面抛出错误，
 * 终止脚本执行，从而防止 C++ 层的非法指针访问。
 */
static Calculator* check_calc(lua_State* L, int index) {
    void* ud = luaL_checkudata(L, index, META_CALC);
    if (!ud) {
        luaL_argerror(L, index, "expected Calculator object");
    }
    // 解引用 userdata 中的 Calculator 指针。UserData 本身存放的是一个指针
    return *static_cast<Calculator**>(ud);
}

// --- 构造函数绑定：calc = Calculator.new(val) ---
static int l_Calculator_new(lua_State* L) {
    try {
        // 获取第一个参数
        double val = luaL_checknumber(L, 1);
        
        // 1. 在 Lua 内存堆中申请存放 C++ 指针的空间
        // 这里申请的是指针大小的空间
        Calculator** ud = static_cast<Calculator**>(lua_newuserdata(L, sizeof(Calculator*)));
        
        // 2. 构造 C++ 对象并存入指针
        *ud = new Calculator(val);
        
        // 3. 关联元表
        luaL_getmetatable(L, META_CALC);
        lua_setmetatable(L, -2);
        
        return 1; // 将创建的 Userdata 压栈并返回
    } catch (const std::exception& e) {
        // 将 C++ 异常转换为 Lua 错误
        return luaL_error(L, "Calculator constructor failed: %s", e.what());
    }
}

// --- 成员方法绑定：calc:add(val) ---
static int l_Calculator_add(lua_State* L) {
    try {
        Calculator* calc = check_calc(L, 1); // 栈位置 1 是 self
        double val = luaL_checknumber(L, 2); // 栈位置 2 是 val
        calc->add(val);
        return 0; // 无返回值
    } catch (const std::exception& e) {
        return luaL_error(L, "Calculator::add failed: %s", e.what());
    }
}

// --- 成员方法绑定：calc:multiply(val) ---
static int l_Calculator_multiply(lua_State* L) {
    try {
        Calculator* calc = check_calc(L, 1);
        double val = luaL_checknumber(L, 2);
        calc->multiply(val);
        return 0;
    } catch (const std::exception& e) {
        return luaL_error(L, "Calculator::multiply failed: %s", e.what());
    }
}

// --- 成员方法绑定：calc:get_value() ---
static int l_Calculator_get_value(lua_State* L) {
    try {
        Calculator* calc = check_calc(L, 1);
        lua_pushnumber(L, calc->get_value()); // 将结果压入栈顶，供 Lua 使用
        return 1; // 返回值
    } catch (const std::exception& e) {
        return luaL_error(L, "Calculator::get_value failed: %s", e.what());
    }
}

// --- 成员方法绑定：calc:reset() ---
static int l_Calculator_reset(lua_State* L) {
    try {
        Calculator* calc = check_calc(L, 1);
        calc->reset();
        return 0;
    } catch (const std::exception& e) {
        return luaL_error(L, "Calculator::reset failed: %s", e.what());
    }
}

// --- 析构绑定：__gc (垃圾回收触发时被 Lua 自动调用) ---
// 极其重要：在 Lua GC 回收对象时，必须手动释放 C++ 内存
static int l_Calculator_gc(lua_State* L) {
    Calculator** ud = static_cast<Calculator**>(lua_touserdata(L, 1));
    if (*ud) {
        delete *ud;
        *ud = nullptr; // 置空指针，防止二次释放或野指针访问
    }
    return 0;
}

// --- 模块入口：初始化 ---
// 注意：必须使用 extern "C" 确保导出符号不被 C++ Name Mangling 修改
extern "C" __declspec(dllexport) int luaopen_lua_raw(lua_State* L) {
    // 1. 定义类方法映射
    luaL_Reg methods[] = {
        {"add", l_Calculator_add},
        {"multiply", l_Calculator_multiply},
        {"get_value", l_Calculator_get_value},
        {"reset", l_Calculator_reset},
        {"__gc", l_Calculator_gc}, // GC 方法注册
        {NULL, NULL}
    };
    
    // 2. 创建并配置元表 (Metatable)
    // luaL_newmetatable 会自动将元表存入注册表中
    luaL_newmetatable(L, META_CALC);
    
    // 配置 __index：当 Lua 调用对象方法时，自动到元表中寻找
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    
    // 注册所有成员方法到元表
    luaL_setfuncs(L, methods, 0);
    lua_pop(L, 1); // 弹出元表，保持栈平衡
    
    // 3. 创建模块导出表 (用于 require "lua_raw")
    lua_newtable(L);
    
    // 导出构造函数：mylib.new(val)
    lua_pushcfunction(L, l_Calculator_new);
    lua_setfield(L, -2, "new");
    
    // 导出全局函数：mylib.add(a, b)
    lua_pushcfunction(L, l_global_add);
    lua_setfield(L, -2, "add");
    
    // 导出全局常量：mylib.PI
    lua_pushnumber(L, get_PI());
    lua_setfield(L, -2, "PI");
    
    // 导出全局统计变量：mylib.call_count
    lua_pushinteger(L, get_global_call_count());
    lua_setfield(L, -2, "call_count");
    
    return 1; // 将模块表压入栈顶，require 将返回此表
}
```

### 开发建议与工业界最佳实践
1.  **内存安全检查**：在复杂的系统中，仅有 `__gc` 是不够的。建议在 `Calculator` 绑定中加入一个 `isValid` 标志，在 `__gc` 中将其设置为 false。在方法绑定中检查该标志，如果已经失效则抛出 Lua 错误。这能预防绝大多数野指针访问问题。
2.  **栈平衡原则**：每一个 `lua_push...` 操作必须有明确的去向。不要在函数内部残留未使用的栈元素，这会导致内存泄漏和后续栈操作的逻辑混乱。
3.  **类型转换安全**：始终坚持使用 `luaL_check*` 系列函数，而非 `lua_to*` 系列。前者的严格性不仅能保证代码健壮，还能在开发期迅速排查参数传递错误。
4.  **错误传播**：工业界规范要求在 C++ 端捕获所有异常并转化为 `luaL_error`。这是为了遵循 Lua 自身的错误处理机制，防止跨越不同语言边界时的异常未处理。
