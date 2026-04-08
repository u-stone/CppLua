For a C++ library built with CMake to be used as a dynamic module in Lua, there are essentially a few main paths:

1. **Write a Lua binding layer for an existing C++ dynamic library**
2. **Make the module directly into a Lua C extension library**
3. **Use a C interface as an intermediary, then call it from Lua**
4. **Use automatic binding tools to reduce manual labor**

The most common and stable practice in the industry is:

- **C++ Core Logic**
- **Export stable C API**
- **Binding layer in Lua via Lua C API / sol2 / LuaBridge, etc.**
- **CMake builds both core library and Lua extension module simultaneously**

---

# I. Understanding Key Issues

Lua natively interacts most easily with **C ABI**, not complex C++ ABI.

Reasons:
- C++ name mangling is complex
- ABI compatibility between different compilers/standard libraries may be an issue
- Classes, templates, exceptions, smart pointers, etc., cannot be directly "blindly" exposed to Lua

Therefore, if you already have a C++ dynamic library, **do not directly expose a bunch of C++ classes nakedly to Lua**. It is more recommended to:

- Maintain C++ implementation internally
- Encapsulate a C-style API layer externally
- Have the Lua binding layer call this C API

This is a very common practice in the industry.

---

# II. Common Integration Schemes

---

## Scheme A: Write a Lua Native Extension Module (Most Common)

Lua supports loading dynamic library modules, such as:

```lua
local mylib = require("mylib")
mylib.foo()
```

This requires your dynamic library to export a fixed entry function:

```c
int luaopen_mylib(lua_State* L);
```

When Lua calls `require("mylib")`, it will load the corresponding dynamic library and call `luaopen_mylib`.

### The structure of this approach is usually:

- `core`: Your C++ core dynamic library
- `lua_mylib`: Lua extension module, responsible for passing Lua calls to core

For example:

```text
Lua script
   ↓
lua require("mylib")
   ↓
Lua extension module (luaopen_mylib)
   ↓
C/C++ wrapper layer
   ↓
Your C++ dynamic library
```

### Advantages
- Standard Lua ecosystem approach
- Can be published as `.dll` / `.so` / `.dylib`
- Natural Lua user experience: `require(...)`

### Disadvantages
- Need to write binding code
- Need to handle Lua stack, parameter checking, object lifecycle

---

## Scheme B: Export C API first, then let Lua call the C API (Strongly Recommended)

Assuming your C++ dynamic library is currently like this:

```cpp
class Engine {
public:
    int add(int a, int b);
};
```

Do not directly let Lua bind this class, but wrap it:

```cpp
extern "C" {

typedef void* EngineHandle;

EngineHandle engine_create();
void engine_destroy(EngineHandle h);
int engine_add(EngineHandle h, int a, int b);

}
```

Internal implementation:

```cpp
class Engine {
public:
    int add(int a, int b) { return a + b; }
};

extern "C" {

EngineHandle engine_create() {
    return new Engine();
}

void engine_destroy(EngineHandle h) {
    delete static_cast<Engine*>(h);
}

int engine_add(EngineHandle h, int a, int b) {
    return static_cast<Engine*>(h)->add(a, b);
}

}
```

Then the Lua binding layer only needs to handle these C functions.

### Why this is Best Practice
This is what many large projects do:

- **Core layer is stable**
- **Language binding is easier to do**
- **Can support Python / C# / Rust / Java, etc., in the future**
- **C ABI is much more stable than C++ ABI**

---

## Scheme C: Use LuaJIT FFI to call C interfaces directly

If you are using **LuaJIT**, you can directly call dynamic libraries via FFI without necessarily writing a Lua C module.

Lua code example:

```lua
local ffi = require("ffi")

ffi.cdef[[
typedef void* EngineHandle;
EngineHandle engine_create();
void engine_destroy(EngineHandle h);
int engine_add(EngineHandle h, int a, int b);
]]

local lib = ffi.load("mylib")

local h = lib.engine_create()
print(lib.engine_add(h, 3, 4))
lib.engine_destroy(h)
```

### Advantages
- Very fast
- No need to write Lua C API binding layer
- Suitable for quickly integrating existing C API dynamic libraries

### Disadvantages
- Depends on LuaJIT, not standard Lua
- Poor direct support for C++ (still recommended to go through C API)
- Cross-platform details and debugging need more care

### Applicable Scenarios
- Internal tools
- Performance sensitive
- Existing stable C interfaces

In the industry, this is also a common scheme, especially in game engines, scripting systems, and hot-reload toolchains.


---

# III. If using standard Lua, how is it typically written?

---

## 1. Typical Binding Function

For example, exporting a simple function:

```cpp
extern "C" int mylib_add(int a, int b) {
    return a + b;
}
```

Lua binding layer:

```cpp
extern "C" {
#include "lua.h"
#include "lauxlib.h"
}

int l_add(lua_State* L) {
    int a = (int)luaL_checkinteger(L, 1);
    int b = (int)luaL_checkinteger(L, 2);
    int result = mylib_add(a, b);
    lua_pushinteger(L, result);
    return 1;
}

extern "C" int luaopen_mylib(lua_State* L) {
    luaL_Reg funcs[] = {
        {"add", l_add},
        {NULL, NULL}
    };

#if LUA_VERSION_NUM >= 502
    luaL_newlib(L, funcs);
#else
    lua_newtable(L);
    luaL_register(L, "mylib", funcs);
#endif
    return 1;
}
```

Lua usage:

```lua
local mylib = require("mylib")
print(mylib.add(1, 2))
```

---

## 2. If you want to expose C++ objects

Lua generally saves C++ object pointers via **userdata**.

For example:

- Put `Engine*` into userdata
- Bind metatable to userdata
- Define methods and `__gc` in metatable

### A simplified idea:

```cpp
struct LuaEngine {
    Engine* ptr;
};
```

Create object:

```cpp
int l_engine_new(lua_State* L) {
    LuaEngine* u = (LuaEngine*)lua_newuserdata(L, sizeof(LuaEngine));
    u->ptr = new Engine();

    luaL_getmetatable(L, "EngineMT");
    lua_setmetatable(L, -2);
    return 1;
}
```

Call method:

```cpp
int l_engine_add(lua_State* L) {
    LuaEngine* u = (LuaEngine*)luaL_checkudata(L, 1, "EngineMT");
    int a = (int)luaL_checkinteger(L, 2);
    int b = (int)luaL_checkinteger(L, 3);
    lua_pushinteger(L, u->ptr->add(a, b));
    return 1;
}
```

GC reclamation:

```cpp
int l_engine_gc(lua_State* L) {
    LuaEngine* u = (LuaEngine*)luaL_checkudata(L, 1, "EngineMT");
    delete u->ptr;
    u->ptr = nullptr;
    return 0;
}
```

---

# IV. How to organize in CMake

A common project structure:

```text
project/
  CMakeLists.txt
  src/
    engine.cpp
    engine.hpp
    c_api.cpp
  lua/
    lua_binding.cpp
```

---

## Example CMake structure

### 1. Core library
```cmake
add_library(mycore SHARED
    src/engine.cpp
    src/c_api.cpp
)

target_include_directories(mycore PUBLIC src)
```

### 2. Find Lua
```cmake
find_package(Lua REQUIRED)
```

### 3. Lua Module
```cmake
add_library(mylib MODULE
    lua/lua_binding.cpp
)

target_include_directories(mylib PRIVATE ${LUA_INCLUDE_DIR})
target_link_libraries(mylib PRIVATE mycore ${LUA_LIBRARIES})
```

### 4. Remove Prefix
Lua module names usually want to generate:

- Windows: `mylib.dll`
- Linux: `mylib.so`

Rather than `libmylib.so`

```cmake
set_target_properties(mylib PROPERTIES
    PREFIX ""
)
```

Sometimes you also need to explicitly set the output directory to make it easier for `require()` to find it:

```cmake
set_target_properties(mylib PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lua
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lua
)
```

---

# V. What are the mainstream binding methods

---

## 1. Directly use Lua C API
This is the lowest-level and most universal method.

### Advantages
- No extra dependencies
- Greatest control
- Good performance
- Most stable

### Disadvantages
- Tedious development
- Stack operations are easy to write wrong
- High maintenance cost for large interfaces

### Suitable for
- Few interfaces
- Dependency-sensitive
- Seeking controllability

---

## 2. sol2
This is a very popular Lua binding library in modern C++.

It makes it more convenient to expose classes, functions, enums, etc.

Illustration:

```cpp
#include <sol/sol.hpp>

class Engine {
public:
    int add(int a, int b) { return a + b; }
};

extern "C" int luaopen_mylib(lua_State* L) {
    sol::state_view lua(L);

    sol::table mod = lua.create_table();

    mod.new_usertype<Engine>("Engine",
        sol::constructors<Engine()>(),
        "add", &Engine::add
    );

    lua.push(mod);
    return 1;
}
```

### Advantages
- Modern style
- Very convenient to bind classes
- Reduces boilerplate code

### Disadvantages
- Introduces third-party library
- Template-heavy, slow compilation
- Error messages can be complex

### Suitable for
- C++17/20 projects
- Many class interfaces
- Want high development efficiency

This is a **very common** modern scheme in the industry.

---

## 3. LuaBridge / luabind / Selene, etc.
These are also binding libraries.

### Practical Status
- **LuaBridge**: Still quite common, lighter
- **luabind**: Often seen in old projects, relatively outdated now
- **Selene**: Has some users, but not as mainstream as sol2

Currently, if you ask "what is the mainstream choice for new projects", the usual answer is:

- **Low-level hand-written Lua C API**
- **Or use sol2**

---

## 4. SWIG / tolua++ / Automatic binding generation
These types of tools can generate Lua binding code from interface descriptions or header files.

### Advantages
- Suitable for large interface volume
- Reduces repetitive labor
- Convenient for multi-language binding

### Disadvantages
- Generated code is troublesome to debug
- Painful when encountering complex C++ features
- Build chain is more complex

### Suitable for
- Large cross-language SDKs
- Need to support multiple scripting languages simultaneously
- Interface style is relatively regular


---

# VI. Summary of Industry Best Practices

---

## Practice 1: Decouple Core Logic from Binding Layer
Recommended structure:

- `core/`: Pure C++ business logic
- `c_api/`: Stable C wrapper
- `lua_binding/`: Lua binding
- `tests/`: C++ tests and Lua tests

Benefits:
- Lua binding breakage does not affect the core library
- Impact when upgrading the core library is controllable
- Easy to extend to other languages

This is a very typical industry practice.

---

## Practice 2: Export C API whenever possible, instead of directly exposing complex C++ classes
Especially if your dynamic library is an SDK or a common component, this is important.

Do not let the external scripting layer directly depend on:
- STL container layouts
- Exception types
- Template instances
- Compiler ABI

It is recommended to unify at the boundary layer into:
- Integers, floats, strings
- Handles (opaque handles)
- Simple structs
- Error codes

---

## Practice 3: Object lifecycle must be very clear
Lua garbage collection and C++ RAII are not naturally equivalent.

Clearly agree on:
- Who creates the object?
- Who releases the object?
- Does Lua GC take responsibility for destruction?
- Is C++ allowed to retain references to Lua objects?
- Does multi-threading involve cross-state calls?

Common practices:
- userdata holds raw pointers or smart pointers
- Release in `__gc`
- Prohibit userdata copying
- Add validity checks for external handles

---

## Practice 4: Error handling, do not let C++ exceptions directly穿过 (pass through) Lua boundaries
**Very important.**

Do not let exceptions fly directly across C API or Lua C API boundaries.

Recommended:
- C++ internally catches all exceptions
- Convert to Lua errors: `luaL_error`
- Or convert to error codes + error strings

For example:

```cpp
int l_add(lua_State* L) {
    try {
        int a = (int)luaL_checkinteger(L, 1);
        int b = (int)luaL_checkinteger(L, 2);
        lua_pushinteger(L, risky_add(a, b));
        return 1;
    } catch (const std::exception& e) {
        return luaL_error(L, "add failed: %s", e.what());
    } catch (...) {
        return luaL_error(L, "add failed: unknown error");
    }
}
```

This is basic in mature projects.

---

## Practice 5: Version compatibility must be designed in advance
Lua has multiple versions:

- Lua 5.1
- Lua 5.2
- Lua 5.3
- Lua 5.4
- LuaJIT

There are differences in their APIs.

Therefore, you have to decide:
- Only support a specific version
- Build a compatibility layer
- Use third-party binding libraries to shield the differences

In the industry, many projects explicitly write down a support matrix rather than "theoretically supporting all Lua".

---

## Practice 6: Pay special attention to exported symbols and module naming on Windows
When doing Lua modules on Windows, you often step on these pits:

- `__declspec(dllexport)`
- Dynamic library name is inconsistent with `require()` name
- Lua runtime bitness inconsistency (32/64)
- Debug/Release CRT inconsistency
- Lua itself and extension module compiler inconsistency

If it is a standard Lua C module, the most important things are:
- Exported `luaopen_xxx`
- The generated dll name matches `require("xxx")`

---

# VII. Recommended Landing Schemes

If you ask "I have a C++ dynamic library now, to be used by Lua, what is most recommended?", my suggestions are:

---

## Recommended Scheme 1: C++ Core Library + C API + Hand-written small Lua bindings
Suitable for:
- Pursuing stability
- Interfaces are not particularly huge
- Want long-term maintenance

Structure:
```text
C++ core
  ↓
C API wrapper
  ↓
Lua binding (Lua C API)
```

This is the most stable.

---

## Recommended Scheme 2: C++ Core Library + sol2
Suitable for:
- Hope for rapid development
- Many C++ classes
- Team accepts third-party dependencies

However, it is still recommended:
- Keep core modules clean
- Do not let the business layer be completely coupled with the Lua binding mechanism

---

## Recommended Scheme 3: If using LuaJIT, call C API directly via FFI
Suitable for:
- Internal projects
- Rapid integration
- Existing stable C interfaces
- No strict requirement for standard Lua compatibility

This is extremely efficient in actual projects.

---

# VIII. A concise industry judgment standard

If your goal is to **make a formal maintainable Lua interface**, it is recommended to select by the following priority:

1. **Organize stable C API first**
2. **Small interface: Hand-write Lua C API**
3. **Large interface: sol2 or automatic binding tools**
4. **If it is a LuaJIT project: prioritize FFI**

---

# IX. Minimum implementation steps you can follow directly

1. **Keep existing C++ dynamic library**
2. **Add an `extern "C"` C API layer**
3. **Create a new Lua module project**
4. **Export `luaopen_xxx`**
5. **Register functions/classes in `luaopen_xxx`**
6. **CMake build this Lua module and link your core library**
7. **Put the generated dll/so into a searchable path of Lua's `package.cpath`**
8. **Call via `require("xxx")` in Lua**


---

# 十、如果你愿意，我可以继续给你两种具体内容

我可以下一步直接给你：

### 方案 A：
**一个完整可编译的最小示例**
- C++ 核心类
- C API
- Lua 绑定
- CMakeLists.txt
- Lua 测试脚本

### 方案 B：
**一个基于 sol2 的现代 C++ 绑定示例**
- 更少样板代码
- 更适合类接口

如果你愿意，我可以直接按 **Windows + CMake + Lua 5.4 + DLL** 的方式给你写一套完整目录结构和代码。