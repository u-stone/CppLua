#include <lua.hpp>
#include <LuaBridge/LuaBridge.h>
#include "../../c_api/c_math_engine.h"
#include "../core/math_engine.h"

#ifdef _WIN32
#define LUA_EXPORT __declspec(dllexport)
#else
#define LUA_EXPORT
#endif

extern "C" LUA_EXPORT int luaopen_lua_bridge(lua_State* L) {
    luabridge::getGlobalNamespace(L)
        .beginClass<Calculator>("Calculator")
            .addConstructor<void (*) (double)>()
            .addFunction("add", &Calculator::add)
            .addFunction("multiply", &Calculator::multiply)
            .addFunction("get_value", &Calculator::get_value)
            .addFunction("reset", &Calculator::reset)
        .endClass();

    return 0;
}
