# File: waterman.mojo
# Author: robertoforcen@gmail.com
# Date: 2026-10-06
# Brief: Waterman polyhedron coordinate generation algorithm, producing sphere-like point
#        distributions based on integer lattice points within a given radius.
#
from std.math import sqrt, ceil, floor, abs, round
#
from vector3d import Vector3d

def watermancoords[T : DType](rad: Scalar[T]) -> List[Vector3d[T]]:
    var rad2 = rad * rad
    var limit = Int(floor(rad))   
    var coords = List[Vector3d[T]]()

    for x in range(-limit, limit + 1):
        var x2 = Scalar[T](x * x)
        var dz2_x = rad2 - x2
        if dz2_x < 0: continue

        for y in range(-limit, limit + 1):
            var y2 = Scalar[T](y * y)
            var dz2_xy = dz2_x - y2
            if dz2_xy < 0: continue

            var z_max = Int(floor(sqrt(dz2_xy)))
            var z_start = -z_max

            # Forzar que z_start tenga la misma paridad que (x + y)
            var target_parity = (x + y) % 2
            if target_parity < 0: 
                target_parity += 2 # Corrección para enteros negativos en Mojo

            if abs(z_start % 2) != target_parity:
                z_start += 1 # Ajustar al primer z válido dentro de la esfera

            for z in range(z_start, z_max + 1, 2):
                coords.append(Vector3d(Scalar[T](x), Scalar[T](y), Scalar[T](z)))

    for ref c in coords: c /= rad
    # print("waterman : rad:", rad, " n.points:", len(coords), coords)
    # M(R) = 98 R^3 + 680 R^2 + 10,000 R
    # def mem_required(r: Int) -> Int: return 98 * r**3 + 680 * r**2 + 10000 * r
    # print("mem required:", mem_required(Int(rad)))
    return coords^

#
def main():
    var c = watermancoords(Scalar[DType.float32](5)) 