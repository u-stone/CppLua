# Lua Extension Development Scheme 1: Raw C API Deep Implementation Guide

## 1. Deep Principle Analysis

The native Raw C API is a low-level C-based interaction interface provided officially by Lua. It does not depend on any third-party libraries and provides the most direct and efficient control over the Lua virtual machine. Understanding the Raw C API is a necessary path for deep mastery of Lua extension development. For projects pursuing ultimate performance and zero dependencies, it is the only choice.

### 1. Lua Virtual Machine and Virtual Stack (Virtual Stack) Explained
The core of Lua is its virtual stack machine model. All data interaction between the Lua virtual machine and the host language (C/C++) is performed through a stack. The stack is a LIFO (Last-In-First-Out) bidirectional structure.
*   **Interaction Process**: When Lua calls a C function, Lua pushes parameters onto the stack in order, with the top of the stack being the last parameter of the function. The C function accesses this data using stack indices `1` (bottom of the stack, i.e., the first parameter), `2`, or negative indices like `-1` (top of the stack, i.e., the last parameter), `-2`, etc. After processing business logic, C++ pushes the result back to the top of the stack and returns an integer indicating how many return values are in the stack to Lua.
*   **Memory Space Management**: The Lua stack is not just for passing parameters; it is also a buffer for C++ to operate on Lua data. Developers must use `lua_checkstack` to ensure the stack has sufficient space, otherwise it will crash. Although this mechanism is low-level and tedious, it effectively decouples Lua's GC (Garbage Collection) from C++'s manual memory management. Before C++ logic operates on data, it must ensure that the relevant data has entered the stack and perform explicit type checking and conversion.
*   **Type Checking**: Raw C API provides the `luaL_check*` series of functions (e.g., `luaL_checkinteger`, `luaL_checknumber`, `luaL_checkudata`). They call `luaL_error` upon check failure, directly aborting the current execution of the Lua script and throwing an error with detailed position information, which is an important debugging tool in development.

### 2. Userdata and Metatable: Key to Implementing Object-Orientation
Lua is a weakly typed language and does not natively support class and object definitions. To export C++ class instances to Lua, we must implement a custom object system via Userdata and Metatable.
*   **Userdata Memory Model**: `lua_newuserdata` allocates a block of contiguous byte space in Lua's managed memory. We store the pointer of the C++ object into this block of memory (or directly placement new the object instance, but this involves complex lifecycle management). The common practice is to store a pointer to avoid premature C++ object destruction.
*   **Metatable**: Userdata itself has no behavior. To implement calls like `calc:add()`, we need to create a metatable via `luaL_newmetatable`. This metatable contains a special key `__index`, pointing to a table holding method functions. When Lua searches for a method on Userdata, it triggers an `__index` lookup, thus finding the C++ bound function.
*   **Construction and Method Calling**: In the constructor `new`, we create a Userdata, store the C++ pointer, and set its metatable. Thereafter, all method calls on this Userdata are routed to corresponding C++ functions through the metatable.

### 3. Lifecycle Management and GC (__gc)
Memory safety is the core of C++ extension development. When a Userdata instance in Lua is garbage collected because its reference count hits zero, the Lua interpreter does not know that the C++ heap memory pointed to by this Userdata needs to be `delete`d.
*   **Mission of __gc**: If a `__gc` method is defined in the metatable, Lua GC calls this function before destroying Userdata completely. We must retrieve the C++ pointer in this function and execute `delete`, and explicitly set the pointer to null to prevent reentrancy or dangling pointer access.
*   **Preventive Checks**: In complex systems, `__gc` alone is insufficient. If a Lua script holds the Userdata pointer through other means after the object is GC'd, continuing to call methods will lead to severe UAF (Use-After-Free) vulnerabilities. Therefore, the industry practice is to maintain a `bool is_valid` flag, set it to `false` in `__gc`, and verify this flag before each method call.

### 4. ABI Stability, Symbol Export, and Multi-version Compatibility
Different versions of Lua (5.1, 5.2, 5.3, 5.4, LuaJIT) have subtle but fatal differences in APIs (e.g., `luaL_register` was deprecated after 5.2).
*   **C ABI**: To ensure extension libraries can be dynamically loaded under different versions of the Lua interpreter, functions must be declared as `extern "C"`.
*   **Symbol Visibility**: On Windows, not only is `__declspec(dllexport)` required, but care must be taken with `dumpbin /exports` to check if symbols are correctly exported.
*   **Bridging C API and C++**: Because Lua's error handling is based on `longjmp`, it is **strictly forbidden** to directly let C++ exceptions skip the Lua boundary in Raw C API functions. All C++ code must be wrapped in `try-catch`, and errors transformed into Lua errors via `luaL_error`.

---

## 2. Detailed Code Example: Implementing a Complete Calculator Binding

This example demonstrates how to implement a complex binding including C++ object construction, multiple member methods, GC lifecycle management, global variable export, and global function export.

```cpp
#include <lua.hpp>
#include <iostream>
#include <string>
#include <vector>
#include "../../core/math_engine.h"

// Macro define metatable name for type validation within Lua VM
#define META_CALC "CalculatorMeta"

/**
 * --- Auxiliary Function: Type Safety Check ---
 * luaL_checkudata is the most basic and important safety protection in Raw C API programming.
 * It checks if the specified position on the stack is indeed a Userdata object with a specific metatable.
 * If types do not match, luaL_checkudata directly throws an error at the Lua level,
 * terminating script execution, thus preventing illegal pointer access at the C++ level.
 */
static Calculator* check_calc(lua_State* L, int index) {
    void* ud = luaL_checkudata(L, index, META_CALC);
    if (!ud) {
        luaL_argerror(L, index, "expected Calculator object");
    }
    // Dereference the Calculator pointer in Userdata. UserData itself holds a pointer
    return *static_cast<Calculator**>(ud);
}

// --- Constructor Binding: calc = Calculator.new(val) ---
static int l_Calculator_new(lua_State* L) {
    try {
        // Get the first parameter
        double val = luaL_checknumber(L, 1);
        
        // 1. Allocate space in Lua memory heap to hold the C++ pointer
        // Here, space for a pointer size is allocated
        Calculator** ud = static_cast<Calculator**>(lua_newuserdata(L, sizeof(Calculator*)));
        
        // 2. Construct C++ object and store pointer
        *ud = new Calculator(val);
        
        // 3. Associate metatable
        luaL_getmetatable(L, META_CALC);
        lua_setmetatable(L, -2);
        
        return 1; // Push Userdata onto stack and return
    } catch (const std::exception& e) {
        // Convert C++ exception to Lua error
        return luaL_error(L, "Calculator constructor failed: %s", e.what());
    }
}

// --- Member Method Binding: calc:add(val) ---
static int l_Calculator_add(lua_State* L) {
    try {
        Calculator* calc = check_calc(L, 1); // Stack position 1 is self
        double val = luaL_checknumber(L, 2); // Stack position 2 is val
        calc->add(val);
        return 0; // No return value
    } catch (const std::exception& e) {
        return luaL_error(L, "Calculator::add failed: %s", e.what());
    }
}

// --- Member Method Binding: calc:multiply(val) ---
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

// --- Member Method Binding: calc:get_value() ---
static int l_Calculator_get_value(lua_State* L) {
    try {
        Calculator* calc = check_calc(L, 1);
        lua_pushnumber(L, calc->get_value()); // Push result to top of stack for Lua use
        return 1; // Return value
    } catch (const std::exception& e) {
        return luaL_error(L, "Calculator::get_value failed: %s", e.what());
    }
}

// --- Member Method Binding: calc:reset() ---
static int l_Calculator_reset(lua_State* L) {
    try {
        Calculator* calc = check_calc(L, 1);
        calc->reset();
        return 0;
    } catch (const std::exception& e) {
        return luaL_error(L, "Calculator::reset failed: %s", e.what());
    }
}

// --- Destructor Binding: __gc (Automatically called by Lua upon GC triggering) ---
// Extremely important: When Lua GC reclaims an object, C++ memory must be manually freed
static int l_Calculator_gc(lua_State* L) {
    Calculator** ud = static_cast<Calculator**>(lua_touserdata(L, 1));
    if (*ud) {
        delete *ud;
        *ud = nullptr; // Set to null to prevent double free or dangling pointer access
    }
    return 0;
}

// --- Module Entry: Initialization ---
// Note: Must use extern "C" to ensure exported symbols are not modified by C++ Name Mangling
extern "C" __declspec(dllexport) int luaopen_lua_raw(lua_State* L) {
    // 1. Define class method mapping
    luaL_Reg methods[] = {
        {"add", l_Calculator_add},
        {"multiply", l_Calculator_multiply},
        {"get_value", l_Calculator_get_value},
        {"reset", l_Calculator_reset},
        {"__gc", l_Calculator_gc}, // GC method registration
        {NULL, NULL}
    };
    
    // 2. Create and configure metatable (Metatable)
    // luaL_newmetatable automatically stores the metatable into the registry
    luaL_newmetatable(L, META_CALC);
    
    // Configure __index: when Lua calls an object method, automatically look up in metatable
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    
    // Register all member methods to metatable
    luaL_setfuncs(L, methods, 0);
    lua_pop(L, 1); // Pop metatable, maintain stack balance
    
    // 3. Create module export table (used for require "lua_raw")
    lua_newtable(L);
    
    // Export constructor: mylib.new(val)
    lua_pushcfunction(L, l_Calculator_new);
    lua_setfield(L, -2, "new");
    
    // Export global function: mylib.add(a, b)
    lua_pushcfunction(L, l_global_add); // Assuming l_global_add is defined
    lua_setfield(L, -2, "add");
    
    // Export global constant: mylib.PI
    lua_pushnumber(L, get_PI());
    lua_setfield(L, -2, "PI");
    
    // Export global statistics variable: mylib.call_count
    lua_pushinteger(L, get_global_call_count());
    lua_setfield(L, -2, "call_count");
    
    return 1; // Push module table to top of stack, require will return this table
}
```

### Development Suggestions and Industry Best Practices
1.  **Memory Safety Checks**: In complex systems, `__gc` alone is insufficient. It is recommended to add an `isValid` flag to the `Calculator` binding and set it to `false` in `__gc`. Check this flag in method bindings, and throw a Lua error if it has become invalid. This prevents most dangling pointer access issues.
2.  **Stack Balance Principle**: Every `lua_push...` operation must have a clear destination. Do not leave unused stack elements inside functions, as this leads to memory leaks and logical confusion in subsequent stack operations.
3.  **Type Conversion Safety**: Always insist on using the `luaL_check*` series of functions rather than `lua_to*` series. The strictness of the former not only guarantees code robustness but also allows rapid investigation of parameter passing errors during development.
4.  **Error Propagation**: Industry norms require catching all exceptions on the C++ side and converting them into `luaL_error`. This is to follow Lua's own error handling mechanism and prevent unhandled exceptions when crossing different language boundaries.
