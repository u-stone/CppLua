#include "c_math_engine.h"
#include "../core/math_engine.h"
#include <vector>

// Calculator
CalculatorHandle create_calculator(double initial_value) {
    return new Calculator(initial_value);
}

void destroy_calculator(CalculatorHandle h) {
    delete static_cast<Calculator*>(h);
}

void calculator_add(CalculatorHandle h, double val) {
    static_cast<Calculator*>(h)->add(val);
}

void calculator_add_int(CalculatorHandle h, int val) {
    static_cast<Calculator*>(h)->add(val);
}

void calculator_multiply(CalculatorHandle h, double val) {
    static_cast<Calculator*>(h)->multiply(val);
}

double calculator_get_value(CalculatorHandle h) {
    return static_cast<Calculator*>(h)->get_value();
}

void calculator_reset(CalculatorHandle h) {
    static_cast<Calculator*>(h)->reset();
}

// Polymorphism
ShapeHandle create_circle(double r) {
    return new Circle(r);
}

void destroy_shape(ShapeHandle h) {
    delete static_cast<Shape*>(h);
}

double get_shape_area(ShapeHandle h) {
    return static_cast<Shape*>(h)->area();
}

// Complex Types
double calculator_process_batch(CalculatorHandle h, const double* data, int size) {
    std::vector<double> vec(data, data + size);
    return static_cast<Calculator*>(h)->process_batch(vec);
}

// Utils
double c_add(double a, double b) {
    return add(a, b);
}

int get_global_call_count() {
    return global_call_count;
}

double get_PI() {
    return PI;
}
