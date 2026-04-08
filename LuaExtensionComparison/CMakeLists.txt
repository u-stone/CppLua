cmake_minimum_required(VERSION 3.10)
project(LuaExtensionComparison)

set(CMAKE_CXX_STANDARD 17)

set(LUA_DIR "C:/Program Files (x86)/Lua/5.1")
include_directories("${LUA_DIR}/include")
link_directories("${LUA_DIR}/lib")

# Core Library
add_library(core SHARED core/math_engine.cpp core/math_engine.h)
target_include_directories(core PUBLIC core)
target_compile_definitions(core PRIVATE CORE_EXPORTS)

# C API Library
add_library(c_api SHARED c_api/c_math_engine.cpp c_api/c_math_engine.h)
target_link_libraries(c_api PRIVATE core)
target_include_directories(c_api PUBLIC c_api)
target_compile_definitions(c_api PRIVATE C_API_EXPORTS)

# 1. Raw C API Binding
add_library(lua_raw MODULE bindings/raw_c_api/glue_raw.cpp)
target_link_libraries(lua_raw PRIVATE c_api "C:/Program Files (x86)/Lua/5.1/lib/lua5.1.lib")
target_include_directories(lua_raw PRIVATE "C:/Program Files (x86)/Lua/5.1/include")
set_target_properties(lua_raw PROPERTIES PREFIX "")

# 2. LuaBridge Binding
add_library(lua_bridge MODULE bindings/luabridge/glue_bridge.cpp)
target_link_libraries(lua_bridge PRIVATE core "C:/Program Files (x86)/Lua/5.1/lib/lua5.1.lib")
target_include_directories(lua_bridge PRIVATE "C:/Program Files (x86)/Lua/5.1/include" ../external/LuaBridge/Source)
set_target_properties(lua_bridge PROPERTIES PREFIX "")


# 3. Sol2 Binding
add_library(lua_sol2 MODULE bindings/sol2/glue_sol2.cpp)
target_link_libraries(lua_sol2 PRIVATE core "C:/Program Files (x86)/Lua/5.1/lib/lua5.1.lib")
target_include_directories(lua_sol2 PRIVATE "C:/Program Files (x86)/Lua/5.1/include" ../external/sol2/include)
set_target_properties(lua_sol2 PROPERTIES PREFIX "")

# Deployment
set(CMAKE_INSTALL_PREFIX "${CMAKE_SOURCE_DIR}/deploy")

install(TARGETS core c_api lua_raw lua_bridge lua_sol2 
        RUNTIME DESTINATION modules
        LIBRARY DESTINATION modules)

install(FILES tests/test_raw.lua tests/test_luabridge.lua tests/test_sol2.lua 
        DESTINATION scripts)
