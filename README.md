# Lua C++ 扩展开发学习工程

本项目用于演示和学习如何将 C++ 库扩展为 Lua 调用的动态库。通过对比三种主流的绑定方案，本项目提供了一个可扩展、可维护且符合工业标准的跨语言交互范例。

## 文档目录 (`doc/`)

本项目的文档存放在 `doc/` 目录下，包含以下内容：

*   **[绑定方案对比与编写指南]** - 深入解析三种主流绑定方案：
    *   [Raw C API 方案](./doc/Binding_RawCAPI.md) - 原生最底层实现。
    *   [LuaBridge 方案](./doc/Binding_LuaBridge.md) - 现代轻量级封装实现。
    *   [Sol2 方案](./doc/Binding_Sol2.md) - 工业级现代 C++ 绑定实现。
*   [LuaExtensionGuide.md](./doc/LuaExtensionGuide.md) - 项目整体架构与最佳实践导引。
*   [LuaExtensionTheory.md](./doc/solution.md) - 跨语言绑定的深度原理分析。

## 工程结构 (`LuaExtensionComparison/`)

该对比工程将核心逻辑与绑定实现解耦：

*   `core/`: C++ 业务核心逻辑（纯净，无依赖）。
*   `c_api/`: 稳定的 C ABI 接口层（推荐的工业级做法）。
*   `bindings/`:
    *   `raw_c_api/`: 手写 Lua C API 绑定。
    *   `luabridge/`: LuaBridge 封装绑定。
    *   `sol2/`: Sol2 封装绑定。

## 构建说明

请使用根目录下的脚本进行构建（自动处理包含路径与链接）：

*   PowerShell: `.\build.ps1`
*   Batch: `.\build.bat`

## 如何测试

构建完成后，项目将自动将所有二进制文件与脚本安装至 `LuaExtensionComparison/deploy/` 目录。您可以按以下步骤进行测试：

1.  切换至部署目录：
    ```bash
    cd LuaExtensionComparison/deploy
    ```

2.  设置环境变量以确保 Lua 能找到生成的模块：
    ```powershell
    # Windows PowerShell
    $env:LUA_CPATH = ".\modules\?.dll;;"
    $env:PATH = "$pwd\modules;" + $env:PATH
    ```

3.  运行对应的测试脚本：
    ```bash
    lua .\scripts\test_raw.lua
    lua .\scripts\test_luabridge.lua
    lua .\scripts\test_sol2.lua
    ```
