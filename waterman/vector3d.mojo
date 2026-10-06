# File: vector3d.mojo
# Author: robertoforcen@gmail.com
# Date: 2026-10-06
# Brief: 3D vector math library with SIMD support for efficient computation, including
#        arithmetic operations, dot/cross products, normalization, and geometric utilities.
#
from std.math import sqrt, floor

comptime f32 = Float32
comptime f64 = Float64

comptime FLOAT_PREC_F32 = Float32(1.1920929e-7)
comptime FLOAT_PREC_F64 = Float64(2.220446049250313e-16)

struct Vector3d[T: DType](Writable, ImplicitlyCopyable):
    # SIMD x 4 for better alignment
    var data: SIMD[Self.T, 4]

    # Constructores
    def __init__(out self, x: Scalar[Self.T], y: Scalar[Self.T], z: Scalar[Self.T]):  self.data = SIMD[Self.T, 4](x, y, z, 0.0)
    def __init__(out self, simd_data: SIMD[Self.T, 4]):  self.data = simd_data
    def __init__(out self, other: Self):        self.data = other.data
    def __init__(out self, l : Array[Scalar[Self.T], 3]):  self.data = SIMD[Self.T, 4](l[0], l[1], l[2], 0.0)
    def __init__(out self):                     self.data = SIMD[Self.T, 4](0.0, 0.0, 0.0, 0.0)

    # Access components
    @always_inline
    def x(self) -> Scalar[Self.T]: return self.data[0]

    @always_inline
    def y(self) -> Scalar[Self.T]: return self.data[1]

    @always_inline
    def z(self) -> Scalar[Self.T]: return self.data[2]

    @always_inline
    def serial(self) -> Array[Scalar[Self.T], 3]: return [self.x(), self.y(), self.z()]

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
    def __mul__(self, scalar: Scalar[Self.T]) -> Self: return Self(self.data * scalar)
    @always_inline
    def __imul__(mut self, scalar: Scalar[Self.T]): self.data *= scalar

    @always_inline
    def __truediv__(self, scalar: Scalar[Self.T]) -> Self: return Self(self.data / scalar)
    @always_inline
    def __itruediv__(mut self, scalar: Scalar[Self.T]): self.data /= scalar

    @always_inline
    def __eq__(self, other: Self) -> Bool: 
        return self.data[0]==other.data[0] and self.data[1]==other.data[1] and self.data[2]==other.data[2]
    @always_inline
    def __ne__(self, other: Self) -> Bool: 
        return self.data[0]!=other.data[0] or self.data[1]!=other.data[1] or self.data[2]!=other.data[2]
    @always_inline
    def __lt__(self, other: Self) -> Bool: 
        if self.data[0]==other.data[0]:
            if self.data[1]==other.data[1]:
                return self.data[2]<other.data[2]
            return self.data[1]<other.data[1]
        return self.data[0]<other.data[0]
    @always_inline
    def __le__(self, other: Self) -> Bool: 
        if self.data[0] <= other.data[0]: return True
        if self.data[0] == other.data[0]:
            if self.data[1] <= other.data[1]: return True
            if self.data[1] == other.data[1]:
                return self.data[2] <= other.data[2]
        return False
    @always_inline
    def __gt__(self, other: Self) -> Bool: 
        if self.data[0] > other.data[0]: return True
        if self.data[0] == other.data[0]:
            if self.data[1] > other.data[1]: return True
            if self.data[1] == other.data[1]:
                return self.data[2] > other.data[2]
        return False
    @always_inline
    def __ge__(self, other: Self) -> Bool: 
        if self.data[0] >= other.data[0]: return True
        if self.data[0] == other.data[0]:
            if self.data[1] >= other.data[1]: return True
            if self.data[1] == other.data[1]:
                return self.data[2] >= other.data[2]
        return False
 
    #  Dot Product
    @always_inline
    def dot(self, other: Self) -> Scalar[Self.T]: 
        var mul = self.data * other.data
        return mul[0] + mul[1] + mul[2]
    @always_inline
    def normSquared(self) -> Scalar[Self.T]: 
        var mul = self.data * self.data
        return mul[0] + mul[1] + mul[2]

    # Cross Product
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
    def length(self) -> Scalar[Self.T]:
        return sqrt(self.dot(self))
    @always_inline
    def lengthSq(self) -> Scalar[Self.T]:
        return self.dot(self)
    @always_inline
    def distance(self, other:Self) -> Scalar[Self.T]:
        return (self - other).length()
    @always_inline
    def distanceSq(self, other:Self) -> Scalar[Self.T]:
        return (self - other).lengthSq()
    
    @always_inline
    def unit(self) -> Self:
        var l = self.lengthSq()
        return self * (1.0 / l) if l != 0.0 else self
    @always_inline
    def normalize_old(self) -> Self:
        return self.unit()
    @always_inline
    def norm(self) -> Scalar[Self.T]:
        return self.length()
    @always_inline
    def max_abs(self) -> Scalar[Self.T]:
        var abs_data = abs(self.data)
        return max(abs_data[0], abs_data[1], abs_data[2])
    @always_inline
    def tween(self, other: Self, t: Scalar[Self.T]) -> Self:
        return Self(self.data * (1.0 - t) + other.data * t)
    @always_inline
    def one_third(self, other: Self) -> Self:
        return self.tween(other, 1.0 / 3.0)

    @always_inline
    def __setitem__(mut self, index: Int, value: Scalar[Self.T]):
        self.data[index] = value
    @always_inline
    def __getitem__(self, index: Int) -> Scalar[Self.T]:
        return self.data[index]
    

    def __str__(self) -> String:
        return String(t"({self.x()}, {self.y()}, {self.z()})")
    def write_to(self, mut writer: Some[Writer]):  writer.write(self.__str__())

    @staticmethod
    @always_inline
    def normal(v0: Self, v1: Self, v2: Self) -> Self:
        return (v1 - v0).cross(v2 - v0)
    @always_inline
    def to_bytes(self) -> Array[UInt8, 3]:
        var result = Array[UInt8, 3](uninitialized=True)
        result[0] = UInt8(255.0 * self.x())
        result[1] = UInt8(255.0 * self.y())
        result[2] = UInt8(255.0 * self.z())
        return result^

    def normalize(self) -> Self:
        var lenSqr = self.x()*self.x() + self.y()*self.y() + self.z()*self.z()
        var err = lenSqr - 1
        var vt = self
        if Self.T == DType.float32:
            if err > Scalar[Self.T](2*FLOAT_PREC_F32) or err < Scalar[Self.T](-(2*FLOAT_PREC_F32)):
                var len = sqrt(lenSqr)
                vt = vt / len
        elif Self.T == DType.float64:
            if err > Scalar[Self.T](2*FLOAT_PREC_F64) or err < Scalar[Self.T](-(2*FLOAT_PREC_F64)):
                var len = sqrt(lenSqr)
                vt = vt / len
        return vt

    def max(self) -> Scalar[Self.T]: return max(self.x(), self.y(), self.z())
    def min(self) -> Scalar[Self.T]: return min(self.x(), self.y(), self.z())
    
    def setZero(mut self):
        self.data = SIMD[Self.T, 4](0,0,0,0)

    def floor(self) -> Self:
        return Self(floor(self.data[0]), floor(self.data[1]), floor(self.data[2]))

    def ptr(self) -> Pointer[Float32, ImmUntrackedOrigin]:
        return Pointer(to=self).unsafe_origin_cast[ImmUntrackedOrigin]().unsafe_bitcast[Float32]()
# test
def test_vector():
    var v1 = Vector3d(1.0, 2.0, 3.0)
    var v2 = Vector3d(4.0, 5.0, 6.0)

    var sum = v1 + v2
    var dot_product = v1.dot(v2)
    var cross_product = v1.cross(v2)

    print("Sum: ", sum)
    print("Dot Product:", dot_product)
    print("Cross Product: ", cross_product)

def main():
    test_vector()
