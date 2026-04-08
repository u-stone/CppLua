## 4. Polymorphism and Inheritance
LuaBridge supports C++ class inheritance. You need to use `.deriveClass` to establish the inheritance relationship.

```cpp
// Binding example
luabridge::getGlobalNamespace(L)
    .beginClass<Shape>("Shape")
        .addFunction("area", &Shape::area)
    .endClass()
    .deriveClass<Circle, Shape>("Circle")
        .addConstructor<void(*) (double)>()
    .endClass();
```

## 5. Complex Type Mapping (Batch Processing)
LuaBridge does not automatically map `std::vector` to Lua tables; manual conversion is required, or you can write a helper function to take `lua_State` and do it manually.
