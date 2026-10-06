from std.math import sqrt

struct Coord(ImplicitlyCopyable, Writable):
    var x: Float32
    var y: Float32
    var z: Float32

    @always_inline
    def __init__(out self, x: Float32, y: Float32, z: Float32):
        self.x = x
        self.y = y
        self.z = z
    def __init__(out self):
        self.x = 0.0
        self.y = 0.0
        self.z = 0.0
    @always_inline        
    def set(mut self, x: Float32, y: Float32, z: Float32):
        self.x = x
        self.y = y
        self.z = z
    @staticmethod
    def cross(c0 : Coord, c1 : Coord) -> Coord:
        return Coord(
            c0.y * c1.z - c0.z * c1.y,
            c0.z * c1.x - c0.x * c1.z,
            c0.x * c1.y - c0.y * c1.x
        )
    @always_inline
    def __sub__(self, other: Coord) -> Coord:
        return Coord(
            self.x - other.x,
            self.y - other.y,
            self.z - other.z
        )
    @always_inline
    def __add__(self, other: Coord) -> Coord:
        return Coord(
            self.x + other.x,
            self.y + other.y,
            self.z + other.z
        )
    @always_inline
    def __mul__(self, other: Float32) -> Coord:
        return Coord(
            self.x * other,
            self.y * other,
            self.z * other
        )
    @always_inline
    def __imul__(mut self, other: Float32) :
        self.x *= other
        self.y *= other
        self.z *= other
    @always_inline    
    def __div__(self, other: Float32) -> Coord:
        return Coord(
            self.x / other,
            self.y / other,
            self.z / other
        )
    @always_inline
    def length(self) -> Float32:
        return sqrt(self.x * self.x + self.y * self.y + self.z * self.z)

    @always_inline
    def normalize(self) -> Coord:
        var inv_len = 1.0 / (sqrt(self.x * self.x + self.y * self.y + self.z * self.z) + 1.0e-12)
        return Coord(self.x * inv_len, self.y * inv_len, self.z * inv_len)

    @always_inline
    @staticmethod
    def normal(c0: Coord, c1: Coord, c2: Coord) -> Coord:
        var ax = c1.x - c2.x
        var ay = c1.y - c2.y
        var az = c1.z - c2.z

        var bx = c1.x - c0.x
        var by = c1.y - c0.y
        var bz = c1.z - c0.z

        var nx = ay * bz - az * by
        var ny = az * bx - ax * bz
        var nz = ax * by - ay * bx

        var inv_len = 1.0 / (sqrt(nx * nx + ny * ny + nz * nz) + 1.0e-12)
        return Coord(nx * inv_len, ny * inv_len, nz * inv_len)

    @always_inline
    def max_abs(self) -> Float32:
        return max(abs(self.x), abs(self.y), abs(self.z))
    

    @always_inline
    def item(self, index: Int) -> Float32:
        if index == 0:
            return self.x
        elif index == 1:
            return self.y
        elif index == 2:
            return self.z
        else:
            return 0.0
    
    @always_inline
    def to_bytes(self) -> Array[UInt8, 3]:
        var result = Array[UInt8, 3](fill=0)
        result[0] = UInt8(self.x * 255.0)
        result[1] = UInt8(self.y * 255.0)
        result[2] = UInt8(self.z * 255.0)
        return result^