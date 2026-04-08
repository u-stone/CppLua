# LuaExtensionComparison

本工程旨在演示并对比将 C++ 核心逻辑扩展为 Lua 调用库的几种主流工业级实现方案。通过分离核心逻辑、稳定 C 接口层以及具体的绑定实现，本 demo 提供了一个可扩展、可维护且符合工业标准的跨语言交互范例。

---

## 1. 工程架构 (工业级最佳实践)

本工程采用了严格的**三层架构**，以解决 C++ 与 Lua 跨语言调用中的 ABI 兼容性与维护难题：

1.  **Core Layer (`core/`)**: 纯 C++ 业务逻辑，不包含任何 Lua 依赖。
2.  **C API Layer (`c_api/`)**: 提供稳定的 `extern "C"` 接口，屏蔽 C++ 的名称修饰（name mangling）和复杂的 ABI 特性。
3.  **Binding Layer (`bindings/`)**: 具体的 Lua 绑定实现，直接调用 C API，保证了核心逻辑的纯粹性。

---

## 2. 方案对比分析

本工程通过不同的文件夹实现了 `solution.md` 中提到的多种工业界主流绑定方案，您可以直接对比其实现细节：

| 目录 | 绑定方案 | 技术栈 | 特点 |
| :--- | :--- | :--- | :--- |
| `bindings/raw_c_api/` | **Raw C API** | Lua C API | 原生实现，最底层，控制力强 |
| `bindings/luabridge/` | **LuaBridge** | 现代 C++ | 轻量级封装，语法直观 |
| `bindings/sol2/` | **sol2** | 现代 C++ | 功能最全，工业级首选，写法现代 |

| 方案 | 绑定方式 | 复杂度 | 依赖 | 维护性 | 适用场景 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Raw C API** | 手写 Lua 栈操作 | 高 | 无 | 低 (繁琐) | 接口少，性能/依赖极端敏感 |
| **LuaBridge** | 现代 C++ 模板 | 中 | Header-only | 中 | 需要权衡开发效率与二进制大小 |
| **sol2** | 现代 C++ 模板 | 低 | Sol2 库 | 高 | 大型接口，C++17/20 项目首选 |

---

## 3. 核心设计原则

### A. ABI 隔离
不要将复杂的 C++ 类直接暴露给 Lua。通过 `c_api/` 导出的 C ABI，可以保证 C++ 核心库在不同编译器或升级时，Lua 绑定层无需大范围重构。

### B. 内存与生命周期管理
*   **Lua userdata**: 用于在 Lua 中持有 C++ 对象的指针。
*   **`__gc` 元方法**: 必须在 Lua 绑定层正确实现 `__gc`，以在 Lua 垃圾回收时调用 `destroy_calculator` 释放 C++ 内存，防止内存泄漏。

### C. 安全的边界转换
*   **异常处理**: C++ 的异常绝不能跨越 Lua 边界。所有 C API 调用者必须在 `try-catch` 块内处理可能的异常，并使用 `luaL_error` 将其转化为 Lua 可识别的错误。
*   **Windows 导出**: 严格遵循 Windows DLL 导出规范，通过 `__declspec(dllexport)` 和 `__declspec(dllimport)` 正确处理动态库符号导出。

---

## 4. 构建与测试

### 构建
在项目根目录下，使用提供的构建脚本：

```powershell
# Windows PowerShell
powershell -File ".\build.ps1"
```

此脚本会自动：
1. 清理旧的构建产物。
2. 调用 CMake 生成 Visual Studio 工程。
3. 构建 `core.dll` 以及对应的绑定模块。

### 运行测试
执行测试脚本，该脚本会自动设置 `PATH` 环境变量，确保 Lua 能够正确加载所有的 DLL 依赖：

```batch
:: Windows Command Prompt
run_tests.bat
```

---

## 5. 如何扩展
1.  **新增逻辑**: 在 `core/` 中添加 C++ 类/方法。
2.  **暴露接口**: 在 `c_api/` 中添加对应的 C ABI 函数。
3.  **实现绑定**: 在相应的 `bindings/` 目录下添加绑定逻辑。
4.  **构建**: 重新运行 `build.ps1`。
