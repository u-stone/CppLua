# Lua 扩展开发方案一：原生 Raw C API

## 1. 原理详解

原生 Raw C API 是 Lua 官方提供的一套基于 C 语言的接口，它是所有其他绑定库（如 LuaBridge, Sol2）的底层基石。理解 Raw C API 是深入掌握 Lua 扩展开发的必经之路。

### 核心机制：虚拟栈 (Virtual Stack)
Lua 的核心是其**虚拟栈**。Lua 虚拟机与宿主语言（C/C++）之间的所有数据交换，都必须通过这个栈进行。例如，当 Lua 调用 `mylib.add(1, 2)` 时，Lua 解释器会将 `mylib` 对象、`add` 函数名、参数 `1` 和 `2` 依次压入栈中。C++ 编写的 `l_add` 函数需要从栈中依次弹出这些参数，执行计算，将结果压回栈，并返回告知 Lua 栈中有多少个返回值。

### 核心机制：Userdata 与 Metatable
Lua 的数据类型（Number, String, Table, Function, Userdata）是与 C++ 类型有差异的。为了让 Lua 持有 C++ 对象，我们使用 **Userdata**。Userdata 是一块原生的内存块，我们将 C++ 对象的指针存放在其中。由于 Userdata 在 Lua 中没有任何预定义的操作，为了实现 `calc:add()` 这种语法，我们必须通过 **Metatable (元表)**。通过为 `Userdata` 设置元表，我们能在其中定义 `__index`（用于查找方法表）和 `__gc`（用于在 Lua GC 回收 Userdata 时释放 C++ 内存）。

### 核心机制：ABI 稳定与导出
C++ 的 ABI（二进制接口）是非常不稳定的，受编译器、标准库版本、名称修饰等影响。因此，所有导出的入口函数 `luaopen_mylib` 必须声明为 `extern "C"`，并使用 `__declspec(dllexport)` 进行显式符号导出。这确保了 Lua 解释器能够准确无误地定位到模块的初始化入口函数。

---

## 2. 核心代码实现

为了演示，我们需要导出一个具有构造函数、方法、全局变量和全局函数的 `Calculator` 类。

```cpp
#include <lua.hpp>
#include <iostream>
#include <string>
#include "../../core/math_engine.h"

// 宏定义元表名称，用于在 Lua 中查找
#define META_CALC "CalculatorMeta"

// --- 辅助函数：类型安全检查 ---
static Calculator* check_calc(lua_State* L, int index) {
    // 检查栈上指定位置是否为指定元表的 Userdata
    void* ud = luaL_checkudata(L, index, META_CALC);
    if (!ud) {
        luaL_argerror(L, index, "expected Calculator object");
    }
    return *static_cast<Calculator**>(ud);
}

// --- 绑定函数：Constructor (calc = Calculator.new(val)) ---
static int l_Calculator_new(lua_State* L) {
    double val = luaL_checknumber(L, 1);
    
    // 1. 在 Lua 中分配内存以存放 C++ 指针
    Calculator** ud = static_cast<Calculator**>(lua_newuserdata(L, sizeof(Calculator*)));
    // 2. 构造 C++ 对象
    *ud = new Calculator(val);
    
    // 3. 设置元表
    luaL_getmetatable(L, META_CALC);
    lua_setmetatable(L, -2);
    
    return 1; // 将 userdata 压栈返回
}

// --- 绑定方法：calc:add(val) ---
static int l_Calculator_add(lua_State* L) {
    Calculator* calc = check_calc(L, 1);
    double val = luaL_checknumber(L, 2);
    calc->add(val);
    return 0; // 无返回值
}

// --- 绑定方法：calc:get_value() ---
static int l_Calculator_get_value(lua_State* L) {
    Calculator* calc = check_calc(L, 1);
    lua_pushnumber(L, calc->get_value());
    return 1; // 返回值
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

// --- 绑定 GC 方法：释放 C++ 内存 (自动调用) ---
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
    lua_pushnumber(L, a + b);
    return 1;
}

// --- 模块入口：初始化 ---
extern "C" __declspec(dllexport) int luaopen_lua_raw(lua_State* L) {
    // 1. 定义类方法映射
    luaL_Reg methods[] = {
        {"add", l_Calculator_add},
        {"multiply", l_Calculator_multiply},
        {"get_value", l_Calculator_get_value},
        {"reset", l_Calculator_reset},
        {"__gc", l_Calculator_gc}, // GC 方法
        {NULL, NULL}
    };
    
    // 2. 创建并配置元表
    luaL_newmetatable(L, META_CALC);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index"); // __index 指向自身，实现方法查找
    luaL_setfuncs(L, methods, 0); // 批量注册方法
    lua_pop(L, 1); // 弹出元表
    
    // 3. 创建模块导出表
    lua_newtable(L);
    
    // 导出构造函数
    lua_pushcfunction(L, l_Calculator_new);
    lua_setfield(L, -2, "new");
    
    // 导出全局函数
    lua_pushcfunction(L, l_global_add);
    lua_setfield(L, -2, "add");
    
    // 导出全局变量 (简单的数值)
    lua_pushnumber(L, 3.1415926535);
    lua_setfield(L, -2, "PI");
    
    return 1; // 返回模块表
}
```
",filePath: