#ifndef C_MATH_ENGINE_H
#define C_MATH_ENGINE_H

#ifdef C_API_EXPORTS
#define C_EXPORT __declspec(dllexport)
#else
#define C_EXPORT __declspec(dllimport)
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle for Calculator
typedef void* CalculatorHandle;
typedef void* ShapeHandle;

C_EXPORT CalculatorHandle create_calculator(double initial_value);
C_EXPORT void destroy_calculator(CalculatorHandle h);
C_EXPORT void calculator_add(CalculatorHandle h, double val);
C_EXPORT void calculator_add_int(CalculatorHandle h, int val);
C_EXPORT void calculator_multiply(CalculatorHandle h, double val);
C_EXPORT double calculator_get_value(CalculatorHandle h);
C_EXPORT void calculator_reset(CalculatorHandle h);

// Polymorphism
C_EXPORT ShapeHandle create_circle(double r);
C_EXPORT void destroy_shape(ShapeHandle h);
C_EXPORT double get_shape_area(ShapeHandle h);

// Complex Types
C_EXPORT double calculator_process_batch(CalculatorHandle h, const double* data, int size);

C_EXPORT double c_add(double a, double b);
C_EXPORT int get_global_call_count();
C_EXPORT double get_PI();

// Threading
C_EXPORT void run_lua_in_thread(const char* lua_code);

#ifdef __cplusplus
}
#endif

#endif
