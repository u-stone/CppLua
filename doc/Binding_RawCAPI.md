# Lua 扩展开发方案一：原生 Raw C API

## 1. 深度原理详解

原生 Raw C API 是 Lua 官方提供的一套基于 C 语言的底层交互接口。它不依赖任何第三方库，提供了对 Lua 虚拟机最直接、最高效的控制能力。理解 Raw C API 是深入掌握 Lua 扩展开发的必经之路。

### 核心机制一：虚拟栈 (Virtual Stack)
Lua 的核心是其**虚拟栈**。Lua 虚拟机与宿主语言（C/C++）之间的所有数据交换，都必须通过这个栈进行。栈是一个 LIFO (后进先出) 结构。当 Lua 调用一个 C++ 函数时，Lua 解释器会将该函数的参数依次压入栈中，栈顶是该函数的最后一个参数。C++ 编写的函数从栈中读取这些参数（通过索引，例如 `1` 代表第一个参数，`-1` 代表栈顶），处理完业务逻辑后，将结果压入栈中，并返回一个整数告知 Lua 栈中有多少个返回值。这种设计是为了解决两种语言在内存布局、数据表示和生命周期管理上的差异。栈有效地隔离了 Lua 的垃圾回收（GC）机制和 C++ 的手动内存管理。C++ 逻辑在操作数据前，必须确保相关数据已进入栈，并进行类型转换校验，从而保证内存安全。

### 核心机制二：Userdata 与 Metatable (面向对象实现)
Lua 原生不支持 C++ 类。为了让 Lua 持有 C++ 对象，我们使用 **Userdata**。Userdata 是一块在 Lua GC 内存中申请的原始内存块，专门用于存储 C++ 对象的指针。然而 Userdata 在 Lua 中没有任何预定义操作，因此我们必须通过 **Metatable (元表)** 来定义其行为。通过为 `Userdata` 设置元表，我们能在其中定义 `__index`（用于查找方法表）和 `__gc`（用于在 Lua GC 回收 Userdata 时释放 C++ 内存）。当 Lua 执行 `obj:method()` 时，底层的 Lua 虚拟机通过元表查找到对应的方法并调用它，传入该对象的 `Userdata` 作为 `self` 参数。

### 核心机制三：ABI 稳定与符号导出
C++ 的 ABI（二进制接口）是非常不稳定的，受编译器、标准库版本、名称修饰（Name Mangling）等影响。为了让 Lua 解释器能够准确无误地定位到模块的初始化入口函数（如 `luaopen_lua_raw`），必须采取以下措施：
1.  **extern "C"**: 使用 `extern "C"` 禁止 C++ 编译器对函数名进行名称修饰，从而维持一个平坦的符号表。
2.  **显式符号导出**: 在 Windows 上必须使用 `__declspec(dllexport)` 进行显式符号导出，否则该函数对外部（如 Lua 解释器）是不可见的。
3.  **版本匹配**: 必须确保编译扩展库时使用的 `lua.h` 版本与 Lua 解释器运行的版本一致，否则在调用 API 时会发生未定义的行为或崩溃。

---

## 2. 详细示例代码 (Raw C API)

以下代码实现了 `Calculator` 类的完整绑定，包括构造函数、方法、GC 管理、全局变量和全局函数，并包含了详尽的注释和错误处理机制。

```cpp
#include <lua.hpp>
#include <iostream>
#include <string>
#include "../../core/math_engine.h"

// 宏定义元表名称，用于在 Lua 中唯一标识 Calculator 对象类型
#define META_CALC "CalculatorMeta"

// --- 辅助函数：类型安全检查 ---
// 此函数是 Raw C API 开发中最基础且最重要的安全防护。
// 它检查栈上的指定位置是否确实是一个 CalculatorUserdata 对象。
// 如果 Lua 用户传入了非法的 Userdata 或其他类型，
// luaL_checkudata 会直接在 Lua 层面抛出一个错误，从而保护 C++ 层不发生非法指针访问。
static Calculator* check_calc(lua_State* L, int index) {
    // luaL_checkudata 检查栈指定索引处是否为名为 META_CALC 的元表实例
    void* ud = luaL_checkudata(L, index, META_CALC);
    if (!ud) {
        luaL_argerror(L, index, "expected Calculator object");
    }
    // 解引用 userdata 中的 Calculator 指针。UserData 本身存放的是一个指针
    return *static_cast<Calculator**>(ud);
}

// --- 绑定函数：构造函数 (calc = Calculator.new(val)) ---
// 构造函数在 Lua 中需要返回一个新的 Userdata
static int l_Calculator_new(lua_State* L) {
    // 获取第一个参数
    double val = luaL_checknumber(L, 1);
    
    // 1. 在 Lua GC 内存中为 Userdata 分配空间。UserData 实际存放的是 Calculator*
    Calculator** ud = static_cast<Calculator**>(lua_newuserdata(L, sizeof(Calculator*)));
    
    // 2. 在 C++ 堆中创建 Calculator 实例，并将指针存入 Userdata
    *ud = new Calculator(val);
    
    // 3. 重点：将元表关联到 Userdata。不设置元表，此对象将无法调用任何方法
    luaL_getmetatable(L, META_CALC);
    lua_setmetatable(L, -2);
    
    // 返回 Userdata
    return 1;
}

// --- 绑定方法：calc:add(val) ---
// 绑定成员函数时，栈索引 1 是 self (即 Userdata)，索引 2 开始才是真正的参数
static int l_Calculator_add(lua_State* L) {
    // 检查并获取 self (Calculator 指针)
    Calculator* calc = check_calc(L, 1);
    
    // 获取第二个参数 (val)
    double val = luaL_checknumber(L, 2);
    
    // 安全调用 C++ 方法
    calc->add(val);
    
    return 0; // 无返回值
}

// --- 绑定方法：calc:get_value() ---
static int l_Calculator_get_value(lua_State* L) {
    Calculator* calc = check_calc(L, 1);
    
    // 调用 C++ 方法并压入栈中
    lua_pushnumber(L, calc->get_value());
    
    return 1; // 返回 1 个值
}

// --- 绑定方法：calc:multiply(val) ---
static int l_Calculator_multiply(lua_State* L) {
    Calculator* calc = check_calc(L, 1);
    double val = luaL_checknumber(L, 2);
    calc->multiply(val);
    return 0;
}

// --- 绑定方法：calc:reset() ---
static int l_Calculator_reset(lua_State* L) {
    Calculator* calc = check_calc(L, 1);
    calc->reset();
    return 0;
}

// --- 绑定析构方法：__gc ---
// Lua 垃圾回收时会调用此函数，负责清理 C++ 内存，非常重要！
static int l_Calculator_gc(lua_State* L) {
    Calculator** ud = static_cast<Calculator**>(lua_touserdata(L, 1));
    if (*ud) {
        delete *ud;
        *ud = nullptr;
    }
    return 0;
}

// --- 绑定全局函数：add(a, b) ---
static int l_global_add(lua_State* L) {
    double a = luaL_checknumber(L, 1);
    double b = luaL_checknumber(L, 2);
    lua_pushnumber(L, c_add(a, b));
    return 1;
}

// --- 模块入口：初始化 (luaopen_lua_raw) ---
// Lua require 时调用的函数，将 C++ 的类、函数、变量注册到 Lua 的 Table 中
extern "C" __declspec(dllexport) int luaopen_lua_raw(lua_State* L) {
    
    // A. 创建并配置类元表 (Metatable)
    luaL_Reg methods[] = {
        {"add", l_Calculator_add},
        {"multiply", l_Calculator_multiply},
        {"get_value", l_Calculator_get_value},
        {"reset", l_Calculator_reset},
        {"__gc", l_Calculator_gc}, // GC 回收方法
        {NULL, NULL}
    };
    
    // 创建一个新的元表，仅限此模块内部使用
    luaL_newmetatable(L, META_CALC);
    
    // 设置 __index = self，这样 Lua 查找方法时，会从元表里的方法表查找
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    
    // 使用 luaL_setfuncs 批量注册方法
    luaL_setfuncs(L, methods, 0);
    
    lua_pop(L, 1); // 弹出元表，保持栈平衡
    
    // B. 创建并注册模块导出表 (Module Table)
    lua_newtable(L);
    
    // 注册构造函数：mylib.new(val)
    lua_pushcfunction(L, l_Calculator_new);
    lua_setfield(L, -2, "new");
    
    // 注册全局函数：mylib.add(a, b)
    lua_pushcfunction(L, l_global_add);
    lua_setfield(L, -2, "add");
    
    // 注册全局变量：mylib.PI
    lua_pushnumber(L, get_PI());
    lua_setfield(L, -2, "PI");
    
    // 注册全局计数器：mylib.call_count
    lua_pushinteger(L, get_global_call_count());
    lua_setfield(L, -2, "call_count");
    
    return 1; // 将模块表压入栈顶，require 将返回此表
}
```

### 开发建议与工业界最佳实践
1.  **手动垃圾回收处理**：Raw C API 中，GC 的控制权完全在开发者手中。如果在 `__gc` 中忘记 `delete`，就是典型的内存泄漏。如果指针已经释放但 Lua 又调用了方法（UAF），则会导致崩溃。工业界做法是增加“有效性标记”检查：在 Userdata 结构中额外存放一个 `bool isValid`，在 `__gc` 后置为 false，每次调用方法前先检查。
2.  **栈平衡原则**：每一个 `lua_push...` 操作都必须有一个对应的逻辑消耗（被 Lua 使用或被 `lua_pop`），否则栈会溢出，导致 Lua 报错退出。
3.  **类型转换安全**：始终使用 `luaL_check*` 系列函数而不是 `lua_to*`，前者会自动在 Lua 层面抛出类型不匹配错误，后者若类型不符则返回默认值或 null，更容易隐藏 Bug。
