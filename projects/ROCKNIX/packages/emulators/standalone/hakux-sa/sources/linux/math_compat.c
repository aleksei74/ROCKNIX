#include <math.h>

/* remquo returns the same IEEE 754 remainder with an optional quotient. */
double remainder(double x, double y)
{
    int quotient;
    return remquo(x, y, &quotient);
}
