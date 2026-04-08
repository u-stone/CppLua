要让 Lua 使用一个由 C++ 编写、CMake 构建、可作为动态库使用的模块，本质上有几条主路：

1. **给现有 C++ 动态库写一层 Lua 绑定层**
2. **直接把模块做成 Lua C 扩展库**
3. **通过 C 接口中转，再给 Lua 调用**
4. **用自动绑定工具减少手写工作**

业界里最常见、最稳妥的实践是：

- **C++ 核心逻辑**
- **导出稳定的 C API**
- **Lua 侧通过 Lua C API / sol2 / LuaBridge 等做绑定**
- **CMake 同时构建核心库和 Lua 扩展模块**

---

# 一、先理解关键问题

Lua 原生最容易对接的是 **C ABI**，不是复杂的 C++ ABI。

原因：

- C++ 名字修饰（name mangling）复杂
- 不同编译器/不同标准库之间 ABI 兼容性可能有问题
- 类、模板、异常、智能指针这些东西不能直接“无脑”暴露给 Lua

所以如果你已经有一个 C++ 动态库，**不要直接把一堆 C++ 类裸暴露给 Lua**，更推荐：

- 内部继续保持 C++ 实现
- 对外封装一层 **C 风格 API**
- Lua 绑定层调用这个 C API

这是工业界很常见的做法。

---

# 二、常见接入方案

---

## 方案 A：写一个 Lua 原生扩展模块（最常见）

Lua 支持加载动态库模块，比如：

```lua
local mylib = require("mylib")
mylib.foo()
```

这背后要求你的动态库导出一个固定入口函数：

```c
int luaopen_mylib(lua_State* L);
```

Lua 在 `require("mylib")` 时会去加载对应动态库，并调用 `luaopen_mylib`。

### 这种方式的结构通常是：

- `core`：你的 C++ 核心动态库
- `lua_mylib`：Lua 扩展模块，负责把 Lua 调用转给 core

例如：

```text
Lua 脚本
   ↓
lua require("mylib")
   ↓
Lua 扩展模块（luaopen_mylib）
   ↓
C/C++ 包装层
   ↓
你的 C++ 动态库
```

### 优点
- 标准 Lua 生态做法
- 可发布为 `.dll` / `.so` / `.dylib`
- Lua 用户体验自然：`require(...)`

### 缺点
- 要写绑定代码
- 需要处理 Lua 栈、参数检查、对象生命周期

---

## 方案 B：先导出 C API，再让 Lua 调 C API（强烈推荐）

假设你的 C++ 动态库现在是这样的：

```cpp
class Engine {
public:
    int add(int a, int b);
};
```

不要直接让 Lua 绑这个类，而是包一层：

```cpp
extern "C" {

typedef void* EngineHandle;

EngineHandle engine_create();
void engine_destroy(EngineHandle h);
int engine_add(EngineHandle h, int a, int b);

}
```

内部实现：

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

然后 Lua 绑定层只需要处理这些 C 函数。

### 为什么这是最佳实践
这是很多大型项目会做的：

- **核心层稳定**
- **语言绑定更容易做**
- **将来还能支持 Python / C# / Rust / Java 等**
- **C ABI 比 C++ ABI 稳定得多**

---

## 方案 C：使用 LuaJIT FFI 直接调用 C 接口

如果你用的是 **LuaJIT**，可以直接通过 FFI 调动态库，不一定非要写 Lua C 模块。

Lua 代码示例：

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

### 优点
- 非常快
- 不需要写 Lua C API 绑定层
- 适合快速集成已有 C API 动态库

### 缺点
- 依赖 LuaJIT，不是标准 Lua
- 对 C++ 直接支持不好，还是建议走 C API
- 跨平台细节和调试要更小心

### 适用场景
- 内部工具
- 性能敏感
- 已有稳定 C 接口

业界里这也是常见方案，尤其在游戏、脚本系统、热更新工具链中。

---

# 三、如果用标准 Lua，通常怎么写

---

## 1. 典型的绑定函数

比如导出一个简单函数：

```cpp
extern "C" int mylib_add(int a, int b) {
    return a + b;
}
```

Lua 绑定层：

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

Lua 使用：

```lua
local mylib = require("mylib")
print(mylib.add(1, 2))
```

---

## 2. 如果要暴露 C++ 对象

Lua 一般通过 **userdata** 保存 C++ 对象指针。

例如：

- `Engine*` 放进 userdata
- 给 userdata 绑定 metatable
- metatable 里定义方法和 `__gc`

### 一个简化思路：

- `engine.new()` -> 创建 C++ 对象
- `engine:add(1,2)` -> 调对象方法
- `__gc` -> Lua GC 时自动释放对象

伪代码结构：

```cpp
struct LuaEngine {
    Engine* ptr;
};
```

创建对象：

```cpp
int l_engine_new(lua_State* L) {
    LuaEngine* u = (LuaEngine*)lua_newuserdata(L, sizeof(LuaEngine));
    u->ptr = new Engine();

    luaL_getmetatable(L, "EngineMT");
    lua_setmetatable(L, -2);
    return 1;
}
```

调用方法：

```cpp
int l_engine_add(lua_State* L) {
    LuaEngine* u = (LuaEngine*)luaL_checkudata(L, 1, "EngineMT");
    int a = (int)luaL_checkinteger(L, 2);
    int b = (int)luaL_checkinteger(L, 3);
    lua_pushinteger(L, u->ptr->add(a, b));
    return 1;
}
```

GC 回收：

```cpp
int l_engine_gc(lua_State* L) {
    LuaEngine* u = (LuaEngine*)luaL_checkudata(L, 1, "EngineMT");
    delete u->ptr;
    u->ptr = nullptr;
    return 0;
}
```

---

# 四、CMake 里怎么组织

一个常见工程结构：

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

## 示例 CMake 结构

### 1. 核心库
```cmake
add_library(mycore SHARED
    src/engine.cpp
    src/c_api.cpp
)

target_include_directories(mycore PUBLIC src)
```

### 2. 查找 Lua
```cmake
find_package(Lua REQUIRED)
```

### 3. Lua 模块
```cmake
add_library(mylib MODULE
    lua/lua_binding.cpp
)

target_include_directories(mylib PRIVATE ${LUA_INCLUDE_DIR})
target_link_libraries(mylib PRIVATE mycore ${LUA_LIBRARIES})
```

### 4. 去掉前缀
Lua 的模块名通常希望生成：

- Windows: `mylib.dll`
- Linux: `mylib.so`

而不是 `libmylib.so`

```cmake
set_target_properties(mylib PROPERTIES
    PREFIX ""
)
```

有时还要显式设置输出目录，方便 `require()` 找到：

```cmake
set_target_properties(mylib PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lua
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lua
)
```

---

# 五、有哪些主流绑定方式

---

## 1. 直接使用 Lua C API
这是最底层、最通用的方法。

### 优点
- 无额外依赖
- 控制力最强
- 性能好
- 最稳定

### 缺点
- 开发繁琐
- 栈操作容易写错
- 大型接口维护成本高

### 适合
- 接口少
- 对依赖敏感
- 追求可控性

---

## 2. sol2
这是现代 C++ 里非常流行的 Lua 绑定库。

它让你更方便暴露类、函数、枚举等。

示意：

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

### 优点
- 写法现代
- 绑定类非常方便
- 降低样板代码

### 缺点
- 引入第三方库
- 模板重，编译慢
- 错误信息可能复杂

### 适合
- C++17/20 项目
- 类接口多
- 希望开发效率高

这是业界里**非常常见**的现代方案。

---

## 3. LuaBridge / luabind / Selene 等
这些也是绑定库。

### 实践现状
- **LuaBridge**：还算常见，轻量一些
- **luabind**：老项目里见得多，现在相对过时
- **Selene**：有一些使用者，但主流度不如 sol2

目前如果你问“新项目主流选什么”，通常回答是：

- **低层手写 Lua C API**
- **或者用 sol2**

---

## 4. SWIG / tolua++ / 自动生成绑定
这类工具可以从接口描述或头文件生成 Lua 绑定代码。

### 优点
- 适合接口量大
- 减少重复劳动
- 多语言绑定方便

### 缺点
- 生成代码调试麻烦
- 遇到复杂 C++ 特性容易痛苦
- 构建链更复杂

### 适合
- 大型跨语言 SDK
- 需要同时支持多种脚本语言
- 接口风格较规整

---

# 六、业界最佳实践总结

---

## 实践 1：核心逻辑与绑定层分离
推荐结构：

- `core/`：纯 C++ 业务逻辑
- `c_api/`：稳定 C 封装
- `lua_binding/`：Lua 绑定
- `tests/`：C++ 测试和 Lua 测试

这样做的好处：

- Lua 绑定坏了，不影响核心库
- 核心库升级时影响面可控
- 容易扩展到其他语言

这是非常典型的工业实践。

---

## 实践 2：尽量导出 C API，而不是直接暴露复杂 C++ 类
尤其如果你的动态库是 SDK 或公共组件，这点很重要。

不要让外部脚本层直接依赖：

- STL 容器布局
- 异常类型
- 模板实例
- 编译器 ABI

建议在边界层统一成：

- 整数、浮点、字符串
- 句柄（opaque handle）
- 简单 struct
- 错误码

---

## 实践 3：对象生命周期要非常明确
Lua 垃圾回收和 C++ RAII 并不是天然等价的。

要明确约定：

- 谁创建对象？
- 谁释放对象？
- Lua GC 是否负责析构？
- 是否允许 C++ 保留 Lua 对象引用？
- 多线程是否涉及跨 state 调用？

常见做法：

- userdata 持有裸指针或智能指针
- `__gc` 中释放
- 禁止复制 userdata
- 外部句柄加有效性检查

---

## 实践 4：错误处理不要把 C++ 异常直接穿过 Lua 边界
**非常重要。**

不要这样让异常直接飞过 C API 或 Lua C API 边界。

推荐：

- C++ 内部 catch 所有异常
- 转成 Lua 错误：`luaL_error`
- 或转成错误码 + 错误字符串

比如：

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

这是成熟项目里基本都会做的。

---

## 实践 5：版本兼容要提前设计
Lua 有多个版本：

- Lua 5.1
- Lua 5.2
- Lua 5.3
- Lua 5.4
- LuaJIT

它们 API 存在差异。

所以你要决定：

- 只支持某个版本
- 做兼容层
- 用第三方绑定库屏蔽差异

业界里很多项目会明确写死支持矩阵，而不是“理论支持所有 Lua”。

---

## 实践 6：Windows 下尤其注意导出符号和模块命名
在 Windows 上做 Lua 模块时，经常会踩这些坑：

- `__declspec(dllexport)`
- 动态库名字和 `require()` 名字不一致
- Lua 运行时位数不一致（32/64）
- Debug/Release CRT 不一致
- Lua 本身和扩展模块编译器不一致

如果是标准 Lua C 模块，最重要的是确保：
- 导出了 `luaopen_xxx`
- 生成的 dll 名字与 `require("xxx")` 匹配

---

# 七、推荐的落地方案

如果你问“我现在有一个 C++ 动态库，要给 Lua 用，最推荐怎么做”，我的建议是：

---

## 推荐方案 1：C++ 核心库 + C API + 手写少量 Lua 绑定
适合：
- 追求稳定
- 接口不算特别庞大
- 想要长期维护

结构：

```text
C++ core
  ↓
C API wrapper
  ↓
Lua binding (Lua C API)
```

这是最稳的。

---

## 推荐方案 2：C++ 核心库 + sol2
适合：
- 希望快速开发
- C++ 类很多
- 团队接受第三方依赖

但仍然建议：
- 核心模块尽量保持干净
- 不要让业务层彻底和 Lua 绑定机制耦合死

---

## 推荐方案 3：如果使用 LuaJIT，则直接 FFI 调 C API
适合：
- 内部项目
- 快速集成
- 已有稳定 C 接口
- 不要求标准 Lua 兼容

这在实际项目里非常高效。

---

# 八、一个简洁的业界判断标准

如果你的目标是**做一个正式可维护的 Lua 接口**，建议按下面优先级选：

1. **先整理出稳定 C API**
2. **小接口：手写 Lua C API**
3. **大接口：sol2 或自动绑定工具**
4. **如果是 LuaJIT 项目：优先考虑 FFI**

---

# 九、你可以直接照着做的最小实施步骤

1. **保留现有 C++ 动态库**
2. **新增一层 `extern "C"` 的 C API**
3. **新建一个 Lua 模块工程**
4. **导出 `luaopen_xxx`**
5. **在 `luaopen_xxx` 里注册函数/类**
6. **CMake 构建这个 Lua 模块并链接你的核心库**
7. **把生成的 dll/so 放到 Lua 的 `package.cpath` 可搜索路径**
8. **Lua 里用 `require("xxx")` 调用**

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