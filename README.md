# Lua C++ Extension Development Learning Project

This project demonstrates and helps learn how to extend C++ libraries as dynamic libraries callable from Lua. By comparing three mainstream binding schemes, this project provides an extensible, maintainable, and industry-standard paradigm for cross-language interaction.

## Documentation Directory (`doc/`)

Project documentation is located in the `doc/` directory and contains the following:

*   **[Binding Scheme Comparison and Writing Guide]** - Deep analysis of three mainstream binding schemes:
    *   [Raw C API Scheme](./doc/Binding_RawCAPI.md) - Native low-level implementation.
    *   [LuaBridge Scheme](./doc/Binding_LuaBridge.md) - Modern lightweight wrapper implementation.
    *   [Sol2 Scheme](./doc/Binding_Sol2.md) - Industry-grade modern C++ binding implementation.
*   [LuaExtensionGuide.md](./doc/LuaExtensionGuide.md) - Project overall architecture and best practices guide.
*   [LuaExtensionTheory.md](./doc/solution.md) - Deep analysis of cross-language binding principles.
*   [Advanced_Binding_Considerations.md](./doc/Advanced_Binding_Considerations.md) - Advanced considerations for industry-grade Lua extension development.

## Project Structure (`LuaExtensionComparison/`)

This comparison project decouples core logic from binding implementation:

*   `core/`: C++ business core logic (clean, no dependencies).
*   `c_api/`: Stable C ABI interface layer (recommended industry-grade practice).
*   `bindings/`:
    *   `raw_c_api/`: Hand-written Lua C API binding.
    *   `luabridge/`: LuaBridge wrapper binding.
    *   `sol2/`: Sol2 wrapper binding.

## Build Instructions

Please use the scripts in the root directory for building (automatically handles include paths and linking):

*   PowerShell: `.\build.ps1`
*   Batch: `.\build.bat`

## How to Test

After the build is complete, the project will automatically install all binary files and scripts to the `LuaExtensionComparison/deploy/` directory. You can test by following these steps:

1.  Switch to the deployment directory:
    ```bash
    cd LuaExtensionComparison/deploy
    ```

2.  Set environment variables to ensure Lua can find the generated modules:
    ```powershell
    # Windows PowerShell
    $env:LUA_CPATH = ".\modules\?.dll;;"
    $env:PATH = "$pwd\modules;" + $env:PATH
    ```

3.  Run the corresponding test scripts:
    ```bash
    lua .\scripts\test_raw.lua
    lua .\scripts\test_luabridge.lua
    lua .\scripts\test_sol2.lua
    ```

