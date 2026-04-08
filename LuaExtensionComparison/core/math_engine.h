#ifndef MATH_ENGINE_H
#define MATH_ENGINE_H

#ifdef CORE_EXPORTS
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __declspec(dllimport)
#endif

class EXPORT Calculator {
public:
    Calculator(double initial_value);
    ~Calculator();
    void add(double val);
    void add(int val); // Overload
    void multiply(double val);
    double get_value() const;
    void reset();
private:
    double value;
};

extern "C" {
    EXPORT extern int global_call_count;
    EXPORT extern double PI;
    EXPORT double add(double a, double b);
}

#endif
