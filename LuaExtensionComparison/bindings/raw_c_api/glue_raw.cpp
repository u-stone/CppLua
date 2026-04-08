#include <lua.hpp>
#include "../../c_api/c_math_engine.h"
#include "../../core/math_engine.h"

#ifdef _WIN32
#define LUA_EXPORT __declspec(dllexport)
#else
#define LUA_EXPORT
#endif

// Helper to get Calculator from userdata
static Calculator* check_calculator(lua_State* L, int index) {
    return *(Calculator**)luaL_checkudata(L, index, "CalculatorMeta");
}

// Calculator methods
static int l_Calculator_new(lua_State* L) {
    double val = luaL_checknumber(L, 1);
    CalculatorHandle* ud = (CalculatorHandle*)lua_newuserdata(L, sizeof(CalculatorHandle));
    *ud = create_calculator(val);
    luaL_getmetatable(L, "CalculatorMeta");
    lua_setmetatable(L, -2);
    return 1;
}

static int l_Calculator_add(lua_State* L) {
    CalculatorHandle* ud = (CalculatorHandle*)luaL_checkudata(L, 1, "CalculatorMeta");
    double val = luaL_checknumber(L, 2);
    calculator_add(*ud, val);
    return 0;
}

static int l_Calculator_get_value(lua_State* L) {
    CalculatorHandle* ud = (CalculatorHandle*)luaL_checkudata(L, 1, "CalculatorMeta");
    lua_pushnumber(L, calculator_get_value(*ud));
    return 1;
}

static int l_Calculator_gc(lua_State* L) {
    CalculatorHandle* ud = (CalculatorHandle*)luaL_checkudata(L, 1, "CalculatorMeta");
    destroy_calculator(*ud);
    return 0;
}

// Global functions
static int l_add(lua_State* L) {
    double a = luaL_checknumber(L, 1);
    double b = luaL_checknumber(L, 2);
    lua_pushnumber(L, c_add(a, b));
    return 1;
}

extern "C" LUA_EXPORT int luaopen_lua_raw(lua_State* L) {
    // Create metatable for Calculator
    luaL_newmetatable(L, "CalculatorMeta");
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, l_Calculator_add);
    lua_setfield(L, -2, "add");
    lua_pushcfunction(L, l_Calculator_get_value);
    lua_setfield(L, -2, "get_value");
    lua_pushcfunction(L, l_Calculator_gc);
    lua_setfield(L, -2, "__gc");
    lua_pop(L, 1);

    lua_newtable(L);
    lua_pushcfunction(L, l_Calculator_new);
    lua_setfield(L, -2, "new");
    lua_pushcfunction(L, l_add);
    lua_setfield(L, -2, "add");
    lua_pushnumber(L, get_PI());
    lua_setfield(L, -2, "PI");
    
    return 1;
}
