#define SOL_ALL_SAFETIES_ON 1
#include <sol/sol.hpp>
#include "../../core/math_engine.h"

#ifdef _WIN32
#define LUA_EXPORT __declspec(dllexport)
#else
#define LUA_EXPORT
#endif

extern "C" LUA_EXPORT int luaopen_lua_sol2(lua_State* L) {
    sol::state_view lua(L);

    lua.new_usertype<Calculator>("Calculator",
        sol::constructors<Calculator(double)>(),
        "add", sol::overload(
            static_cast<void(Calculator::*)(double)>(&Calculator::add),
            static_cast<void(Calculator::*)(int)>(&Calculator::add)
        ),
        "multiply", &Calculator::multiply,
        "get_value", &Calculator::get_value,
        "reset", &Calculator::reset
    );

    lua["add"] = add;
    lua["PI"] = PI;
    lua["global_call_count"] = sol::var(global_call_count);

    return 0;
}
