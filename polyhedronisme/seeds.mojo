# polyhedron seeds

from common import Vertexes, Faces, f32, u32, i32, calc_range
from vertex import Vertex
from polyhedron import Polyhedron
#
from std.math import pi, tau, sin, cos, sqrt


comptime vx = Vertex

comptime Tetrahedron = Polyhedron(
    "T",
    [ vx(1.0, 1.0, 1.0), vx(1.0, -1.0, -1.0), vx(-1.0, 1.0, -1.0), vx(-1.0, -1.0, 1.0) ],
    [ [ 0, 1, 2 ], [ 0, 2, 3 ], [ 0, 3, 1 ], [ 1, 3, 2 ] ],)
comptime Cube = Polyhedron(
    "C",
    [ vx(0.707, 0.707, 0.707), vx(-0.707, 0.707, 0.707), vx(-0.707, -0.707, 0.707), vx(0.707, -0.707, 0.707), vx(0.707, -0.707, -0.707), vx(0.707, 0.707, -0.707), vx(-0.707, 0.707, -0.707), vx(-0.707, -0.707, -0.707) ],
    [ [ 3, 0, 1, 2 ], [ 3, 4, 5, 0 ], [ 0, 5, 6, 1 ], [ 1, 6, 7, 2 ], [ 2, 7, 4, 3 ], [ 5, 4, 7, 6 ] ],)
comptime Icosahedron = Polyhedron(
    "I",
    [ vx(0, 0, 1.176), vx(1.051, 0, 0.526), vx(0.324, 1.0, 0.525), vx(-0.851, 0.618, 0.526), vx(-0.851, -0.618, 0.526), vx(0.325, -1.0, 0.526), vx(0.851, 0.618, -0.526), vx(0.851, -0.618, -0.526), vx(-0.325, 1.0, -0.526), vx(-1.051, 0, -0.526), vx(-0.325, -1.0, -0.526), vx(0, 0, -1.176) ],
    [ [ 0, 1, 2 ], [ 0, 2, 3 ], [ 0, 3, 4 ], [ 0, 4, 5 ], [ 0, 5, 1 ], [ 1, 5, 7 ], [ 1, 7, 6 ], [ 1, 6, 2 ], [ 2, 6, 8 ], [ 2, 8, 3 ], [ 3, 8, 9 ], [ 3, 9, 4 ], [ 4, 9, 10 ], [ 4, 10, 5 ], [ 5, 10, 7 ], [ 6, 7, 11 ], [ 6, 11, 8 ], [ 7, 10, 11 ], [ 8, 11, 9 ], [ 9, 11, 10 ] ],)
comptime Octahedron = Polyhedron(
    "O",
    [ vx(0, 0, 1.414), vx(1.414, 0, 0), vx(0, 1.414, 0), vx(-1.414, 0, 0), vx(0, -1.414, 0), vx(0, 0, -1.414) ],
    [ [ 0, 1, 2 ], [ 0, 2, 3 ], [ 0, 3, 4 ], [ 0, 4, 1 ], [ 1, 4, 5 ], [ 1, 5, 2 ], [ 2, 5, 3 ], [ 3, 5, 4 ] ],)
comptime Dodecahedron = Polyhedron(
   "D", 
   [vx(0, 0, 1.07047), vx(0.713644, 0, 0.797878),
   vx(-0.356822, 0.618, 0.797878), vx(-0.356822, -0.618, 0.797878),
   vx(0.797878, 0.618034, 0.356822), vx(0.797878, -0.618, 0.356822),
   vx(-0.934172, 0.381966, 0.356822), vx(0.136294, 1.0, 0.356822),
   vx(0.136294, -1.0, 0.356822), vx(-0.934172, -0.381966, 0.356822),
   vx(0.934172, 0.381966, -0.356822), vx(0.934172, -0.381966, -0.356822),
   vx(-0.797878, 0.618, -0.356822), vx(-0.136294, 1.0, -0.356822),
   vx(-0.136294, -1.0, -0.356822), vx(-0.797878, -0.618034, -0.356822),
   vx(0.356822, 0.618, -0.797878), vx(0.356822, -0.618, -0.797878),
   vx(-0.713644, 0, -0.797878), vx(0, 0, -1.07047)],
   [[ 0, 1, 4, 7, 2 ], [ 0, 2, 6, 9, 3 ], [ 0, 3, 8, 5, 1 ],
   [ 1, 5, 11, 10, 4 ], [ 2, 7, 13, 12, 6 ], [ 3, 9, 15, 14, 8 ],
   [ 4, 10, 16, 13, 7 ], [ 5, 8, 14, 17, 11 ], [ 6, 12, 18, 15, 9 ],
   [ 10, 11, 17, 19, 16 ], [ 12, 13, 16, 19, 18 ], [ 14, 15, 18, 19, 17 ]])

def pyramid(n: Int, height: f32 = 1.0) -> Polyhedron:
    var theta = f32(tau) / f32(n) # pie angle

    var vertexes = Vertexes(length=n + 1, fill=Vertex())
    # base
    for i in range(n): vertexes[i] = Vertex(-cos(f32(i) * theta), -sin(f32(i) * theta), -0.2)
    # apex
    vertexes[n] = Vertex(0, 0, height)

    # faces (n+1)
    var faces = Faces(capacity=n+1)
    # base
    faces.append(calc_range(i32(n - 1), 0, True))
    # sides
    for i in range(n): faces.append([u32(i), u32((i + 1) % n), u32(n)])

    return Polyhedron( String(t"Y{n}"), vertexes^, faces^ )

def prism(n: Int, height: f32 = 1.0) -> Polyhedron:
    var theta = f32(tau) / f32(n) # pie angle
    # vertexes
    var vertexes = Vertexes(length=n * 2, fill=Vertex())
    for i in range(n):
        vertexes[i] = Vertex(-cos(f32(i) * theta), -sin(f32(i) * theta), -height)
        vertexes[i + n] = Vertex(-cos(f32(i) * theta), -sin(f32(i) * theta), height)
	
	# faces
    var faces = Faces(capacity=n + 2)
	# vertex #'s 0 to n-1 around one face, vertex #'s n to 2n-1 around other
    faces.append(calc_range(i32(n - 1), 0, True)) # base
    faces.append(calc_range(i32(n), i32(2 * n), False)) # top

    for i in range(n):
        # n rectangular sides
        faces.append([u32(i), u32((i + 1) % n), u32((i + 1) % n + n), u32(i + n)])

    return Polyhedron(String(t"P{n}"), vertexes^, faces^)

def antiprism(n : Int) -> Polyhedron:
    var theta       =  f32(tau) / f32(n) # pie angle
    var h           =  sqrt(1.0 - (4.0 / ((4.0 + (2.0 * cos(theta / 2.0))) - (2.0 * cos(theta)))))
    var r           =  sqrt(1.0 - (h * h))
    var f           =  sqrt((h * h) + (pow(r * cos(theta / 2.0), 2)))
    # correction so edge midpoints (not vertexes) on unit sphere
    var r_corrected = -r / f
    var h_corrected = -h / f
    # vertexes
    var vertexes =  Vertexes(length=n * 2, fill=Vertex())

    for i in range(n):
        vertexes[i] = Vertex(
            r_corrected * cos(f32(i) * theta),
            r_corrected * sin(f32(i) * theta),
            h_corrected)
        vertexes[i + n] = Vertex(
            r_corrected * cos(f32(i) * theta + theta / 2),
            r_corrected * sin(f32(i) * theta + theta / 2),
            -h_corrected)

	# faces
    var faces = Faces(capacity = n * 2 + 2)
    
    faces.append(calc_range(i32(n - 1), 0, True)) # base
    faces.append(calc_range(i32(n), 2 * i32(n), False)) # top

    for i in range(n):	
        # 2n triangular sides
        faces.append([u32(i), u32(i + 1) % u32(n), u32(i) + u32(n) ])
        faces.append([u32(i), u32(i) + u32(n), (u32(n) + u32(i) - 1) % u32(n) + u32(n) ])
    
    return Polyhedron(String(t"A{n}"), vertexes^, faces^)

#
def main():
    print(pyramid(4, 1.0))
    print(prism(5,0.2))
    print(antiprism(5))