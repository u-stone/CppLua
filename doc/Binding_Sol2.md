## 4. Polymorphism and Inheritance
Sol2 supports C++ class inheritance and polymorphism. By registering base classes and derived classes, Lua can treat derived objects as base objects.

```cpp
// Binding example
lua.new_usertype<Shape>("Shape", 
    "area", &Shape::area
);
lua.new_usertype<Circle>("Circle",
    sol::constructors<Circle(double)>(),
    sol::base_classes, sol::bases<Shape>()
);
```

## 5. Complex Type Mapping (Batch Processing)
Sol2 automatically handles mapping of STL containers like `std::vector` to Lua Tables.

```cpp
// Binding example
"process_batch", &Calculator::process_batch
```
