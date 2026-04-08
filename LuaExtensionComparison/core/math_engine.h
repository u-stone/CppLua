#ifndef MATH_ENGINE_H
#define MATH_ENGINE_H

#include <vector>
#include <map>
#include <string>

#ifdef CORE_EXPORTS
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __declspec(dllimport)
#endif

// Polymorphism Support
class EXPORT Shape {
public:
    virtual ~Shape() {}
    virtual double area() const = 0;
};

class EXPORT Circle : public Shape {
    double r;
public:
    Circle(double r) : r(r) {}
    double area() const override { return 3.14159 * r * r; }
};

class EXPORT Calculator {
public:
    Calculator(double initial_value);
    ~Calculator();
    void add(double val);
    void add(int val); // Overload
    void multiply(double val);
    double get_value() const;
    void reset();

    // Complex Types
    double process_batch(const std::vector<double>& values);
    double process_map(const std::map<std::string, double>& values);
private:
    double value;
};

extern "C" {
    EXPORT extern int global_call_count;
    EXPORT extern double PI;
    EXPORT double add(double a, double b);
}

#endif
