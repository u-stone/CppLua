# Lua 扩展开发方案一：原生 Raw C API

## 1. 原理深度详解

原生 Raw C API 是 Lua 官方提供的一套基于 C 语言的底层交互接口。它不依赖任何第三方库，提供了对 Lua 虚拟机最直接、最高效的控制能力。理解 Raw C API 是掌握所有高级绑定库（如 LuaBridge, Sol2）的根本，因为这些库在底层最终都是通过 Raw C API 实现对 Lua 的操作。

### 核心机制一：虚拟栈 (Virtual Stack)
Lua 与宿主程序（C/C++）之间的所有数据交互都通过一个**虚拟栈**进行。这是一个 LIFO (后进先出) 结构。
*   **通信模型**：当 Lua 调用一个 C++ 函数时，Lua 虚拟机将该函数的参数依次压入栈中，并确保栈顶是该函数的参数。C++ 函数从栈中读取参数（通过栈索引，如 `1` 表示第一个参数），执行业务逻辑，然后将结果压回栈顶，并返回一个整数告知 Lua 栈中有多少个返回值。
*   **栈索引**：索引 `1` 代表栈底的第一个参数，索引 `-1` 代表栈顶（即最后一个压入的数据）。通过这种方式，C++ 可以灵活地操作 Lua 中的任意类型数据。

### 核心机制二：Userdata 与 Metatable (面向对象实现)
Lua 原生不支持 C++ 类。为了将 C++ 对象传给 Lua，我们必须将其“装箱”。
*   **Userdata**: Lua 的 `userdata` 类型允许在 Lua 的垃圾回收内存中分配一块 C++ 能够管理的二进制内存，用于存放 C++ 对象的指针（`Calculator*`）。
*   **Metatable (元表)**：由于 Userdata 本身没有任何方法（如 `calc:add()` 会失败），我们需要为 Userdata 设置一个元表（Metatable）。元表是一个 Table，我们通过在其中设置 `__index` 字段指向另一个包含类方法（如 `add`）的表，从而实现了方法查找。Lua 在执行 `obj:method()` 时，会自动在 `obj` 的元表中查找名为 `method` 的函数。

### 核心机制三：生命周期管理 (__gc)
C++ 使用 RAII（资源获取即初始化）来管理内存，而 Lua 使用垃圾回收 (GC)。当 Lua 中的 Userdata 实例被 GC 回收时，Lua 并不知晓其内部持有的 C++ 指针需要被 `delete`。因此，我们必须在元表中显式绑定 `__gc` 元方法。当 Lua GC 触发时，会自动调用我们在 `__gc` 中注册的 C++ 函数，由我们在该函数内手动执行 `delete`，从而避免内存泄漏。

### 核心机制四：ABI 稳定与符号导出
C++ 的名称修饰（Name Mangling）机制非常复杂，且不同编译器之间不兼容。为了让 Lua 加载动态库时能精确找到 `luaopen_mylib` 入口函数，必须：
1.  使用 `extern "C"` 禁止 C++ 编译器对函数名进行重命名。
2.  使用 `__declspec(dllexport)` (Windows) 或可见性属性 (Linux) 显式导出该符号。

---

## 2. 核心代码实现

这是一个完整的 Calculator 绑定示例，展示了全局函数、类导出、变量导出及 GC 回收。

```cpp
#include <lua.hpp>
#include <iostream>
#include <string>
#include "../../core/math_engine.h"

// 宏定义元表名称，用于 Lua 虚拟机内识别类型
#define META_CALC "CalculatorMeta"

/**
 * --- 辅助函数：类型安全检查 ---
 * luaL_checkudata 是 Lua 提供的安全机制，检查栈上的 Userdata 
 * 是否具有正确的元表 META_CALC。如果不匹配，直接抛出 Lua 错误。
 */
static Calculator* check_calc(lua_State* L, int index) {
    void* ud = luaL_checkudata(L, index, META_CALC);
    if (!ud) {
        luaL_argerror(L, index, "expected Calculator object");
    }
    // 解引用 userdata 中的 Calculator 指针
    return *static_cast<Calculator**>(ud);
}

/**
 * --- 构造函数绑定：calc = Calculator.new(val) ---
 * 1. lua_newuserdata: 在 Lua 堆中申请内存，存入 C++ 指针
 * 2. new Calculator: 在 C++ 堆中创建对象
 * 3. lua_setmetatable: 绑定元表，使其实例化后的对象具有 Calculator 的所有方法
 */
static int l_Calculator_new(lua_State* L) {
    double val = luaL_checknumber(L, 1);
    
    // 分配 userdata 空间
    Calculator** ud = static_cast<Calculator**>(lua_newuserdata(L, sizeof(Calculator*)));
    // 初始化 C++ 对象
    *ud = new Calculator(val);
    
    // 获取已注册的元表，并赋给 userdata
    luaL_getmetatable(L, META_CALC);
    lua_setmetatable(L, -2);
    
    return 1; // 将创建的 userdata 压入栈顶并返回
}

/**
 * --- 方法绑定：calc:add(val) ---
 * 栈索引：1 为 self (userdata)，2 为参数 val
 */
static int l_Calculator_add(lua_State* L) {
    Calculator* calc = check_calc(L, 1);
    double val = luaL_checknumber(L, 2);
    calc->add(val);
    return 0; // 该方法无返回值
}

/**
 * --- 方法绑定：calc:get_value() ---
 */
static int l_Calculator_get_value(lua_State* L) {
    Calculator* calc = check_calc(L, 1);
    lua_pushnumber(L, calc->get_value()); // 将结果压栈，让 Lua 读取
    return 1;
}

/**
 * --- 析构函数绑定：__gc (由 Lua GC 自动调用) ---
 * 必须在此处理 C++ 内存释放，否则会导致严重内存泄漏
 */
static int l_Calculator_gc(lua_State* L) {
    Calculator** ud = static_cast<Calculator**>(lua_touserdata(L, 1));
    if (*ud) {
        delete *ud;
        *ud = nullptr;
    }
    return 0;
}

/**
 * --- 全局函数绑定：add(a, b) ---
 */
static int l_global_add(lua_State* L) {
    double a = luaL_checknumber(L, 1);
    double b = luaL_checknumber(L, 2);
    lua_pushnumber(L, a + b);
    return 1;
}

/**
 * --- 模块初始化入口 ---
 * Lua require 时调用的函数，必须满足 lua_CFunction 原型
 */
extern "C" __declspec(dllexport) int luaopen_lua_raw(lua_State* L) {
    // 1. 定义类方法表
    luaL_Reg methods[] = {
        {"add", l_Calculator_add},
        {"get_value", l_Calculator_get_value},
        {"__gc", l_Calculator_gc}, // GC 回收方法
        {NULL, NULL}
    };
    
    // 2. 创建并配置类元表 (Metatable)
    luaL_newmetatable(L, META_CALC);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index"); // __index 指向自身，实现 calc:method() 调用
    luaL_setfuncs(L, methods, 0); // 批量向元表中注册方法
    lua_pop(L, 1); // 弹出元表
    
    // 3. 创建模块导出表
    lua_newtable(L);
    
    // 导出构造函数
    lua_pushcfunction(L, l_Calculator_new);
    lua_setfield(L, -2, "new");
    
    // 导出全局函数
    lua_pushcfunction(L, l_global_add);
    lua_setfield(L, -2, "add");
    
    // 导出全局常量
    lua_pushnumber(L, 3.1415926535);
    lua_setfield(L, -2, "PI");
    
    return 1; // 返回表
}
```

### 总结
编写 Raw C API 代码时，一定要严格遵循“检查、使用、压栈、返回”的生命周期模式。任何未压栈就尝试在 Lua 层面使用的 C++ 类型都是无效的，任何在 Userdata 创建后遗漏 `__gc` 绑定的做法都是在为程序种下内存泄露的祸根。
