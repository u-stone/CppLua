#define SOL_ALL_SAFETIES_ON 1
#include <sol/sol.hpp>
#include <memory>
#include <stdexcept>
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
        "reset", &Calculator::reset,
        "process_batch", &Calculator::process_batch
    );

    // Polymorphism
    lua.new_usertype<Shape>("Shape", 
        "area", &Shape::area
    );
    lua.new_usertype<Circle>("Circle",
        sol::constructors<Circle(double)>(),
        sol::base_classes, sol::bases<Shape>()
    );

    lua["add"] = add;
    lua["PI"] = PI;
    lua["global_call_count"] = sol::var(global_call_count);

    // Advanced: Exception Handling
    lua["safe_divide"] = [](double a, double b) -> double {
        if (b == 0) throw sol::error("Division by zero!");
        return a / b;
    };

    // Advanced: Shared Pointer Ownership
    lua["create_shared_calculator"] = []() -> std::shared_ptr<Calculator> {
        return std::make_shared<Calculator>(0.0);
    };

    return 0;
}
