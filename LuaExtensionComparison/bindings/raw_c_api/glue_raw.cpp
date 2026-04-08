#include <lua.hpp>
#include <vector>
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
    if (lua_isnumber(L, 2)) {
        calculator_add_int(*ud, (int)lua_tonumber(L, 2));
    } else {
        calculator_add(*ud, luaL_checknumber(L, 2));
    }
    return 0;
}

static int l_Calculator_process_batch(lua_State* L) {
    CalculatorHandle* ud = (CalculatorHandle*)luaL_checkudata(L, 1, "CalculatorMeta");
    luaL_checktype(L, 2, LUA_TTABLE);
    int len = lua_objlen(L, 2);
    std::vector<double> vec;
    for (int i = 1; i <= len; ++i) {
        lua_rawgeti(L, 2, i);
        vec.push_back(luaL_checknumber(L, -1));
        lua_pop(L, 1);
    }
    lua_pushnumber(L, calculator_process_batch(*ud, vec.data(), vec.size()));
    return 1;
}

// Circle methods
static int l_Circle_new(lua_State* L) {
    double r = luaL_checknumber(L, 1);
    ShapeHandle* ud = (ShapeHandle*)lua_newuserdata(L, sizeof(ShapeHandle));
    *ud = create_circle(r);
    luaL_getmetatable(L, "CircleMeta");
    lua_setmetatable(L, -2);
    return 1;
}

static int l_Circle_area(lua_State* L) {
    ShapeHandle* ud = (ShapeHandle*)luaL_checkudata(L, 1, "CircleMeta");
    lua_pushnumber(L, get_shape_area(*ud));
    return 1;
}

static int l_Circle_gc(lua_State* L) {
    ShapeHandle* ud = (ShapeHandle*)luaL_checkudata(L, 1, "CircleMeta");
    destroy_shape(*ud);
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

// Helper to set methods on the table on top of stack
static void set_methods(lua_State* L, const luaL_Reg* methods) {
    for (; methods->name != NULL; methods++) {
        lua_pushcfunction(L, methods->func);
        lua_setfield(L, -2, methods->name);
    }
}

extern "C" LUA_EXPORT int luaopen_lua_raw(lua_State* L) {
    // Metatable for Calculator
    luaL_newmetatable(L, "CalculatorMeta");
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_Reg calc_methods[] = {
        {"add", l_Calculator_add},
        {"get_value", l_Calculator_get_value},
        {"process_batch", l_Calculator_process_batch},
        {"__gc", l_Calculator_gc},
        {NULL, NULL}
    };
    set_methods(L, calc_methods);
    lua_pop(L, 1);

    // Metatable for Circle
    luaL_newmetatable(L, "CircleMeta");
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_Reg circle_methods[] = {
        {"area", l_Circle_area},
        {"__gc", l_Circle_gc},
        {NULL, NULL}
    };
    set_methods(L, circle_methods);
    lua_pop(L, 1);

    lua_newtable(L);
    lua_pushcfunction(L, l_Calculator_new);
    lua_setfield(L, -2, "new_calculator");
    lua_pushcfunction(L, l_Circle_new);
    lua_setfield(L, -2, "new_circle");
    lua_pushcfunction(L, l_add);
    lua_setfield(L, -2, "add");
    lua_pushnumber(L, get_PI());
    lua_setfield(L, -2, "PI");
    
    return 1;
}

