# Lua C++ 扩展开发学习工程

本项目用于演示和学习如何将 C++ 库扩展为 Lua 调用的动态库。

## 文档目录 (`doc/`)

本项目的文档存放在 `doc/` 目录下，包含以下内容：

*   [HowToWriteBindings.md](./doc/HowToWriteBindings.md) - **[新手必读]** 三种绑定方案的入门总结与编写指南。
*   [LuaExtensionGuide.md](./doc/LuaExtensionGuide.md) - 项目结构说明与工业级最佳实践导引。
*   [LuaExtensionTheory.md](./doc/solution.md) - 深入解析跨语言绑定的原理与方案选择。

## 工程结构 (`LuaExtensionComparison/`)

包含三个主要的对比实现：

*   `bindings/raw_c_api/`: 原生 Lua C API 实现。
*   `bindings/luabridge/`: LuaBridge 现代封装实现。
*   `bindings/sol2/`: Sol2 工业级封装实现。

## 构建说明

请使用根目录下的脚本进行构建：

*   PowerShell: `.\build.ps1`
*   Batch: `.\build.bat`
