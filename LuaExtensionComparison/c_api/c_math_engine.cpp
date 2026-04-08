#include "c_math_engine.h"
#include "../core/math_engine.h"

CalculatorHandle create_calculator(double initial_value) {
    return new Calculator(initial_value);
}

void destroy_calculator(CalculatorHandle h) {
    delete static_cast<Calculator*>(h);
}

void calculator_add(CalculatorHandle h, double val) {
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

double c_add(double a, double b) {
    return add(a, b);
}

int get_global_call_count() {
    return global_call_count;
}

double get_PI() {
    return PI;
}
