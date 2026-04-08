#include <lua.hpp>
#include <LuaBridge/LuaBridge.h>
#include <LuaBridge/Vector.h>
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
            .addFunction("add", static_cast<void(Calculator::*)(double)>(&Calculator::add))
            .addFunction("add_int", static_cast<void(Calculator::*)(int)>(&Calculator::add))
            .addFunction("multiply", &Calculator::multiply)
            .addFunction("get_value", &Calculator::get_value)
            .addFunction("reset", &Calculator::reset)
            .addFunction("process_batch", &Calculator::process_batch)
        .endClass()
        .beginClass<Shape>("Shape")
            .addFunction("area", &Shape::area)
        .endClass()
        .deriveClass<Circle, Shape>("Circle")
            .addConstructor<void(*) (double)>()
        .endClass();

    return 0;
}
