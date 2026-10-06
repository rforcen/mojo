from std.math import sqrt

comptime float4 = SIMD[DType.float32, 4]

struct Coord(Copyable):
    var data: float4

    @always_inline
    def __init__(out self):
        self.data = float4(0.0, 0.0, 0.0, 0.0)
    @always_inline
    def __init__(out self, x: Float32, y: Float32, z: Float32):
        self.data = float4(x, y, z, 0.0)
    def __init__(out self, other: float4):
        self.data = other

    @always_inline
    def __add__(self, other: Coord) -> Coord:
        var res = Coord(0.0, 0.0, 0.0)
        res.data = self.data + other.data # Operación vectorial directa
        return res^
    @always_inline
    def __sub__(self, other: Coord) -> Coord:
        var res = Coord(0.0, 0.0, 0.0)
        res.data = self.data - other.data # Operación vectorial directa
        return res^
    @always_inline
    def __mul__(self, other: Float32) -> Coord:
        var res = Coord(0.0, 0.0, 0.0)
        res.data = self.data * other # Operación vectorial directa
        return res^
    @always_inline
    def __div__(self, other: Float32) -> Coord:
        var res = Coord(0.0, 0.0, 0.0)
        res.data = self.data / other # Operación vectorial directa
        return res^
    def length(self) -> Float32:
        return sqrt(self.data[0] * self.data[0] + self.data[1] * self.data[1] + self.data[2] * self.data[2])
    def normalize(self) -> Coord:
        var res = Coord(self.data)
        var l = self.length()
        if l != 0:
            res.data /= l
        return res^
    def max_abs(self) -> Float32:
        return max(abs(self.data[0]), abs(self.data[1]), abs(self.data[2]))
    
    @staticmethod
    def cross(c0 : Coord, c1 : Coord) -> Coord:
        return Coord(
            c0.data[1] * c1.data[2] - c0.data[2] * c1.data[1],
            c0.data[2] * c1.data[0] - c0.data[0] * c1.data[2],
            c0.data[0] * c1.data[1] - c0.data[1] * c1.data[0]
        )
    @staticmethod
    def normal(c0: Coord, c1: Coord, c2: Coord) -> Coord:
        return Coord.cross(c1 - c2, c1 - c0).normalize()
  
def main(): print("CoordSIMD loaded")