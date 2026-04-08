# LuaExtensionComparison

This project aims to demonstrate and compare several mainstream industry-grade implementation schemes for extending C++ core logic as Lua-callable libraries. By decoupling core logic, a stable C interface layer, and concrete binding implementations, this demo provides an extensible, maintainable, and industry-standard paradigm for cross-language interaction.

---

## 1. Project Architecture (Industry Best Practices)

This project adopts a strict **three-layer architecture** to solve ABI compatibility and maintenance challenges in C++ to Lua cross-language calls:

1.  **Core Layer (`core/`)**: Pure C++ business logic, containing no Lua dependencies.
2.  **C API Layer (`c_api/`)**: Provides stable `extern "C"` interfaces, shielding C++'s name mangling and complex ABI characteristics.
3.  **Binding Layer (`bindings/`)**: Concrete Lua binding implementations, directly calling the C API, ensuring the purity of the core logic.

---

## 2. Scheme Comparison Analysis

This project implements multiple industry-mainstream binding schemes mentioned in `solution.md` through different folders, allowing you to directly compare implementation details:

| Directory | Binding Scheme | Technology Stack | Characteristics |
| :--- | :--- | :--- | :--- |
| `bindings/raw_c_api/` | **Raw C API** | Lua C API | Native implementation, lowest-level, high control |
| `bindings/luabridge/` | **LuaBridge** | Modern C++ | Lightweight wrapper, intuitive syntax |
| `bindings/sol2/` | **sol2** | Modern C++ | Most comprehensive features, industry-grade choice, modern style |

| Scheme | Binding Method | Complexity | Dependencies | Maintainability | Applicable Scenarios |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Raw C API** | Hand-written Lua stack operations | High | None | Low (tedious) | Few interfaces, performance/dependency extreme sensitivity |
| **LuaBridge** | Modern C++ templates | Medium | Header-only | Medium | Need to balance development efficiency and binary size |
| **sol2** | Modern C++ templates | Low | Sol2 library | High | Large-scale interfaces, preferred for C++17/20 projects |

---

## 3. Core Design Principles

### A. ABI Isolation
Do not expose complex C++ classes directly to Lua. Through the C ABI exported by `c_api/`, you can ensure that when the C++ core library is updated or changed across compilers, the Lua binding layer does not need large-scale refactoring.

### B. Memory and Lifecycle Management
*   **Lua userdata**: Used to hold pointers to C++ objects in Lua.
*   **`__gc` metamethod**: Must be correctly implemented in the Lua binding layer to call `destroy_calculator` during Lua garbage collection to release C++ memory and prevent memory leaks.

### C. Safe Boundary Conversion
*   **Exception Handling**: C++ exceptions must never cross the Lua boundary. All C API callers must handle potential exceptions within `try-catch` blocks and use `luaL_error` to convert them into Lua-recognizable errors.
*   **Windows Export**: Strictly follow Windows DLL export specifications, correctly handling dynamic library symbol export via `__declspec(dllexport)` and `__declspec(dllimport)`.

---

## 4. Build and Test

### Build
In the project root directory, use the provided build script:

```powershell
# Windows PowerShell
powershell -File ".\build.ps1"
```

This script will automatically:
1. Clean old build artifacts.
2. Call CMake to generate the Visual Studio project.
3. Build `core.dll` and corresponding binding modules.

### Run Tests
Execute the test script. This script automatically sets the `PATH` environment variable to ensure Lua can correctly load all DLL dependencies:

```batch
:: Windows Command Prompt
run_tests.bat
```

---

## 5. How to Extend
1.  **Add Logic**: Add C++ classes/methods in `core/`.
2.  **Expose Interfaces**: Add corresponding C ABI functions in `c_api/`.
3.  **Implement Binding**: Add binding logic in the corresponding `bindings/` directory.
4.  **Build**: Re-run `build.ps1`.
