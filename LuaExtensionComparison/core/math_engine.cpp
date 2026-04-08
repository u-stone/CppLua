#include "math_engine.h"
#include <iostream>

int global_call_count = 0;
double PI = 3.14159265358979323846; // Changed to double (non-const)

double add(double a, double b) {
    global_call_count++;
    return a + b;
}

Calculator::Calculator(double initial_value) : value(initial_value) {
    std::cout << "Calculator created with value: " << value << std::endl;
}

Calculator::~Calculator() {
    std::cout << "Calculator destroyed." << std::endl;
}

void Calculator::add(double val) {
    value += val;
    global_call_count++;
}

void Calculator::add(int val) {
    value += static_cast<double>(val);
    global_call_count++;
}

void Calculator::multiply(double val) {
    value *= val;
    global_call_count++;
}

double Calculator::get_value() const {
    return value;
}

void Calculator::reset() {
    value = 0;
    global_call_count++;
}
