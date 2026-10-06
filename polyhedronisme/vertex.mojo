#vector

from common import f32
from std.math import sqrt

struct Vertex(Writable, ImplicitlyCopyable):
    # Registros SIMD de 4 elementos para mayor alineación de memoria y rendimiento
    var data: SIMD[DType.float32, 4]

    # Constructores
    def __init__(out self, x: f32, y: f32, z: f32):  self.data = SIMD[DType.float32, 4](x, y, z, 0.0)
    def __init__(out self, simd_data: SIMD[DType.float32, 4]):  self.data = simd_data
    def __init__(out self, other: Self):        self.data = other.data
    def __init__(out self, l : Array[f32, 3]):  self.data = SIMD[DType.float32, 4](l[0], l[1], l[2], 0.0)
    def __init__(out self):                     self.data = SIMD[DType.float32, 4](0.0, 0.0, 0.0, 0.0)

    # Acceso a componentes
    @always_inline
    def x(self) -> f32: return self.data[0]

    @always_inline
    def y(self) -> f32: return self.data[1]

    @always_inline
    def z(self) -> f32: return self.data[2]

    # arith
    @always_inline
    def __neg__(self) -> Self: return Self(-self.data)
    
    @always_inline
    def __add__(self, other: Self) -> Self: return Self(self.data + other.data)
    @always_inline
    def __iadd__(mut self, other: Self): self.data += other.data

    @always_inline
    def __sub__(self, other: Self) -> Self: return Self(self.data - other.data)
    @always_inline
    def __isub__(mut self, other: Self): self.data -= other.data

    @always_inline
    def __mul__(self, scalar: f32) -> Self: return Self(self.data * scalar)
    @always_inline
    def __imul__(mut self, scalar: f32): self.data *= scalar

    @always_inline
    def __truediv__(self, scalar: f32) -> Self: return Self(self.data / scalar)
    @always_inline
    def __itruediv__(mut self, scalar: f32): self.data /= scalar

    # Producto escalar (Dot Product)
    @always_inline
    def dot(self, other: Self) -> f32: 
        var mul = self.data * other.data
        return mul[0] + mul[1] + mul[2]

    # Producto vectorial (Cross Product)
    @always_inline
    def cross(self, other: Self) -> Self:
        # .x = a.y * b.z - a.z * b.y, .y = a.z * b.x - a.x * b.z, .z = a.x * b.y - a.y * b.x
        return Self(self.y() * other.z() - self.z() * other.y(), 
                   self.z() * other.x() - self.x() * other.z(), 
                   self.x() * other.y() - self.y() * other.x())

        # var a_yzx = self.data.shuffle[1, 2, 0, 3]()
        # var b_zxy = other.data.shuffle[2, 0, 1, 3]()
        # var a_zxy = self.data.shuffle[2, 0, 1, 3]()
        # var b_yzx = other.data.shuffle[1, 2, 0, 3]()
        
        # return Self(a_yzx * b_zxy - a_zxy * b_yzx)

    # Longitud / Magnitud del vector
    @always_inline
    def length(self) -> f32:
        return sqrt(self.dot(self))
    @always_inline
    def lengthSq(self) -> f32:
        return self.dot(self)
    @always_inline
    def distance(self, other:Vertex) -> f32:
        return (self - other).length()
    @always_inline
    def distanceSq(self, other:Vertex) -> f32:
        return (self - other).lengthSq()
    
    @always_inline
    def unit(self) -> Self:
        var l = self.lengthSq()
        return self * (1.0 / l) if l != 0.0 else self
    @always_inline
    def normalize(self) -> Self:
        return self.unit()
    @always_inline
    def max_abs(self) -> f32:
        var abs_data = abs(self.data)
        return max(abs_data[0], abs_data[1], abs_data[2])
    @always_inline
    def tween(self, other: Self, t: f32) -> Self:
        return self * (1.0 - t) + other * t
    @always_inline
    def one_third(self, other: Self) -> Self:
        return self.tween(other, 1.0 / 3.0)

    def __str__(self) -> String:
        return String(t"({self.x()}, {self.y()}, {self.z()})")
    def write_to(self, mut writer: Some[Writer]):  writer.write(self.__str__())

    @staticmethod
    @always_inline
    def normal(v0: Self, v1: Self, v2: Self) -> Self:
        return (v1 - v0).cross(v2 - v1)
    @always_inline
    def to_bytes(self) -> Array[UInt8, 3]:
        var result = Array[UInt8, 3](uninitialized=True)
        result[0] = UInt8(255.0 * self.x())
        result[1] = UInt8(255.0 * self.y())
        result[2] = UInt8(255.0 * self.z())
        return result^

# test
def test_vector():
    var v1 = Vertex(1.0, 2.0, 3.0)
    var v2 = Vertex(4.0, 5.0, 6.0)

    var sum = v1 + v2
    var dot_product = v1.dot(v2)
    var cross_product = v1.cross(v2)

    print("Sum: ", sum)
    print("Dot Product:", dot_product)
    print("Cross Product: ", cross_product)

def main():
    test_vector()
