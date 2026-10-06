# comlpex math extensions
from std.complex import ComplexFloat32
from std.math import isfinite, sqrt, cos, sin, sinh, cosh, exp, log, log10, e, pi

comptime I = ComplexFloat32(0.0, 1.0)

@always_inline
def atan2(y: Float32, x: Float32) -> Float32:
    var ax = abs(x)
    var ay = abs(y)
    var mx = max(ax, ay)
    var mn = min(ax, ay)
    var a = mn / (mx + 1e-20)

    # aprox atan(a) in [0, 1]
    var s = a * a
    var r = ((-0.0464964749 * s + 0.15931422) * s - 0.327622764) * s * a + a

    # map whole circle
    if ay > ax:
        r = pi / 2 - r  # pi/2 - r
    if x < 0:
        r = pi - r
    if y < 0:
        r = -r
    return r

@always_inline
def c_is_valid(c: ComplexFloat32) -> Bool: return isfinite(c.re) and isfinite(c.im)

@always_inline
def c_arg(c: ComplexFloat32) -> Float32: return atan2(c.im, c.re)

@always_inline
def c_abs(c: ComplexFloat32) -> Float32: return c.norm()

@always_inline
def c_pow(base: ComplexFloat32, exp: ComplexFloat32) -> ComplexFloat32: 
    return c_exp(exp * c_log(base))

@always_inline
def c_exp(z: ComplexFloat32) -> ComplexFloat32: 
    var magnitude = Float32(e) ** z.re
    return ComplexFloat32(magnitude * cos(z.im), magnitude * sin(z.im))

@always_inline
def c_log(z: ComplexFloat32) -> ComplexFloat32: 
    return ComplexFloat32(log(z.norm()), c_arg(z))

@always_inline
def c_log10(z: ComplexFloat32) -> ComplexFloat32: 
    return ComplexFloat32(log10(z.norm()), c_arg(z))

@always_inline
def c_sin(z: ComplexFloat32) -> ComplexFloat32: 
    return ComplexFloat32(sin(z.re) * cosh(z.im), cos(z.re) * sinh(z.im))

@always_inline
def c_cos(z: ComplexFloat32) -> ComplexFloat32: 
    return ComplexFloat32(cos(z.re) * cosh(z.im), -sin(z.re) * sinh(z.im))

@always_inline
def c_tan(z : ComplexFloat32) -> ComplexFloat32:  return c_sin(z) / c_cos(z)

@always_inline
def c_sqrt(z: ComplexFloat32) -> ComplexFloat32:  
    var radius = c_abs(z)
    var re     = sqrt((radius + z.re) / 2.0)
    var im     = sqrt((radius - z.re) / 2.0)
    return ComplexFloat32(re, im)

@always_inline
def c_asin(z: ComplexFloat32) -> ComplexFloat32:
    var term1 = I * z
    var term2 = c_sqrt(ComplexFloat32(1.0, 0.0) - z * z)
    return -I * c_log(term1 + term2)

@always_inline
def c_acos(z: ComplexFloat32) -> ComplexFloat32:
    var term2 = I * c_sqrt(ComplexFloat32(1.0, 0.0) - z * z)
    return -I * c_log(z + term2)

@always_inline
def c_atan(z: ComplexFloat32) -> ComplexFloat32:
    var num = ComplexFloat32(1.0, 0.0) - I * z
    var den = ComplexFloat32(1.0, 0.0) + I * z
    return (I / ComplexFloat32(2.0, 0.0)) * c_log(num / den)