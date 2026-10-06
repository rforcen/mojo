# Spherical Harmonics
# mojo stuff
from std.math import pi, sin, cos
from max.algorithm import parallelize
from std.sys.info import num_logical_cores
from std.math import ceildiv, tau
from std.ffi import external_call
from std.sys import size_of
# sh's
from sh_codes import SH_CODES, N_SH_CODES, code_to_ints, code_to_f32
from coord import Coord
from color_map import ColorMap
from vector import Vector
from packed import Packed
#
comptime TWO_PI : Float32 = pi * 2
comptime SH = SphericalHarmonics

# SIMD support
comptime AVX512_WIDTH : Int = 16
comptime simd_f32 = SIMD[DType.float32, AVX512_WIDTH] # AVX-512 -> 16 float32
comptime simd_iota = SIMD[DType.float32, AVX512_WIDTH](0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15)

# fast SH dedicated pown 0..8
@always_inline
def pown(x:Float32, n : Int) -> Float32:
    if n==0: return 1
    elif n==1: return x
    elif n==2: return x*x
    elif n==3: return x*x*x
    elif n==4: return x*x*x*x
    elif n==5: return x*x*x*x*x
    elif n==6: return x*x*x*x*x*x
    elif n==7: return x*x*x*x*x*x*x
    elif n==8: return x*x*x*x*x*x*x*x
    return 0

@always_inline
def pown_simd(x:simd_f32, n : Int) -> simd_f32:
    if n==0: return 1
    elif n==1: return x
    elif n==2: return x*x
    elif n==3: return x*x*x
    elif n==4: return x*x*x*x
    elif n==5: return x*x*x*x*x
    elif n==6: return x*x*x*x*x*x
    elif n==7: return x*x*x*x*x*x*x
    elif n==8: return x*x*x*x*x*x*x*x
    return 0

# represents coords, normals, color, texture of a 3d point
struct Point(ImplicitlyCopyable, Writable):
    var coord: Coord
    var normal: Coord
    var color: Coord
    var texture: Coord
    def __init__(out self, coord: Coord, normal: Coord, color: Coord, texture: Coord):
        self.coord = coord
        self.normal = normal
        self.color = color
        self.texture = texture


# vector of points
struct Mesh:
    var points : Vector[Point]

    def __init__(out self, res : Int):
        var size = res*res
        self.points = Vector[Point](size)
    
    def set(mut self, index: Int, ref coord: Coord, ref normal: Coord, ref color: Coord, ref texture: Coord):
        self.points[index] = Point(coord, normal, color, texture)
    
    @staticmethod
    def gen_faces_flat(res: Int) -> Vector[Int]:
        "Generate faces as quads for a grid of size res x res."
        var faces = Vector[Int](res*res*4)
        var ix = 0
        
        for i in range(res):
            var current_row = i * res
            var next_row = (i + 1) * res if i + 1 < res else 0
            for j in range(res):
                var next_j = j + 1 if j + 1 < res else 0
                faces[ix + 0] = current_row + j
                faces[ix + 1] = next_row + j
                faces[ix + 2] = next_row + next_j
                faces[ix + 3] = current_row + next_j
                ix += 4
        return faces^

    def scale_coords(mut self):
        var max_val : Float32 = -1e9
        for c in range(self.points._len):
            max_val = max(max_val, self.points[c].coord.max_abs())
        if max_val > 1e-9:
            var inv_max = 1.0 / max_val
            for c in range(self.points._len):
                self.points[c].coord *= inv_max

# SH main def
struct SphericalHarmonics:
    var colorMap : Int
    var resolution : Int
    var n_vertex : Int
    var code : Int
    
    var du : Float32
    var dv : Float32
    var dx : Float32
    var du10 : Float32
    var dv10 : Float32
   
    var m : Vector[Int]
    var mf : Vector[Float32]

    var mesh : Mesh
   
    def __init__(out self, resolution : Int, colorMap : Int, code : Int):
        self.resolution = resolution
        self.colorMap = colorMap
        self.code = code
        self.n_vertex = resolution * resolution
        self.du = TWO_PI / Float32(resolution)
        self.dv = pi / Float32(resolution)
        self.dx = 1.0 / Float32(resolution)
        self.du10 = self.du / 10.0
        self.dv10 = self.dv / 10.0
        self.m = code_to_ints(code)
        self.mf = code_to_f32(code)

        self.mesh = Mesh(self.resolution)

        self.calc_meshMT_SIMD() # multithreaded / simd
        
             
    @staticmethod
    @always_inline
    def calcCoord(theta: Float32, phi: Float32, ref mf: Vector[Float32], ref m: Vector[Int]) -> Coord:
        var r : Float32 = pown(sin(mf[0] * phi) , m[1]) + 
            pown(cos(mf[2] * phi) , m[3]) + 
            pown(sin(mf[4] * theta) , m[5]) + 
            pown(cos(mf[6] * theta) , m[7])
        return Coord(r * sin(phi) * cos(theta), r * cos(phi), r * sin(phi) * sin(theta))

    @always_inline
    def calc_point(mut self, index: Int, i: Float32, j: Float32):
        var u : Float32 = self.du * i
        var v : Float32 = self.dv * j
        
        var idx : Float32 = i * self.dx
        var jdx : Float32 = j * self.dx
        
        var cdrs : Coord = SH.calcCoord(theta=u, phi=v, mf=self.mf, m=self.m)
        var crd_up : Coord = SH.calcCoord(theta=u + self.du10, phi=v, mf=self.mf, m=self.m) # used in normal calc
        var crd_right : Coord = SH.calcCoord(theta=u, phi=v + self.dv10, mf=self.mf, m=self.m)
        
        self.mesh.set(index, cdrs, Coord.normal(cdrs, crd_up, crd_right), ColorMap(u, 0.0, tau, self.colorMap), Coord(idx, jdx, 0.0))
   
    @staticmethod
    @always_inline
    def calcCoordSIMD(theta: simd_f32, phi: simd_f32, ref mf: Vector[Float32], ref m: Vector[Int]) -> Tuple[simd_f32, simd_f32, simd_f32]:
        var r : simd_f32 = pown_simd(sin(mf[0] * phi), m[1]) + 
            pown_simd(cos(mf[2] * phi), m[3]) + 
            pown_simd(sin(mf[4] * theta), m[5]) + 
            pown_simd(cos(mf[6] * theta), m[7])        
        
        return (r * sin(phi) * cos(theta), r * cos(phi), r * sin(phi) * sin(theta))
     
    @always_inline
    def calc_pointSIMD(mut self, index: Int, i : simd_f32, j:simd_f32):
        
        var u : simd_f32 = self.du * i
        var v : simd_f32 = self.dv * j
        
        var idx : simd_f32 = i * self.dx
        var jdx : simd_f32 = j * self.dx
        
        var (rx, ry, rz)  = SH.calcCoordSIMD(theta=u, phi=v, mf=self.mf, m=self.m)
        var (rx_up, ry_up, rz_up) = SH.calcCoordSIMD(theta=u + self.du10, phi=v, mf=self.mf, m=self.m) # used in normal calc
        var (rx_right, ry_right, rz_right) = SH.calcCoordSIMD(theta=u, phi=v + self.dv10, mf=self.mf, m=self.m)
        
        for k in range(AVX512_WIDTH):
            self.mesh.set(index + k, Coord(rx[k], ry[k], rz[k]), Coord.normal(Coord(rx[k], ry[k], rz[k]), Coord(rx_up[k], ry_up[k], rz_up[k]), Coord(rx_right[k], ry_right[k], rz_right[k])), ColorMap(u[k], 0.0, tau, self.colorMap), Coord(idx[k], jdx[k], 0.0))

    def calc_meshST(mut self) :
        for index in range(self.n_vertex):
            var i_idx = Float32(index / self.resolution)
            var j_idx = Float32(index % self.resolution)
            self.calc_point(index, i_idx, j_idx)

    def calc_meshSIMD(mut self) :
        var si = (simd_f32(0) + simd_iota) / Float32(self.resolution)
        
        for index in range(0, self.n_vertex, AVX512_WIDTH):        
            self.calc_pointSIMD(index, si, (simd_f32(index) + simd_iota) % Float32(self.resolution))

            if index % self.resolution == 0:
                si = (simd_f32(index) + simd_iota) / Float32(self.resolution)
            

    def calc_meshMT(mut self):             
        def thread_fn(row: Int) {mut self}:
            var i_idx = Float32(row)
            var index  = row * self.resolution            

            for j in range(self.resolution):
                self.calc_point(index, i_idx, Float32(j))
                index += 1

        parallelize(thread_fn, self.resolution)

    def calc_meshMT_SIMD(mut self):             
        def thread_fn(row: Int) {mut self}:
            var index  = row * self.resolution
            var si = (simd_f32(index) + simd_iota) / Float32(self.resolution)

            for j in range(0, self.resolution, AVX512_WIDTH):
                self.calc_pointSIMD(index, si, (simd_f32(j) + simd_iota) % Float32(self.resolution))  
                index += AVX512_WIDTH             

        parallelize(thread_fn, self.resolution)

    # view w/ castle-model-viewer
    def writeVRML(self, fileName: String) raises:
        comptime SCALE_FACTOR = 0.03;

        with open(fileName, "w") as f:

            f.write("""#VRML V2.0 utf8
#Generated by sh
NavigationInfo {
  type [ "EXAMINE", "ANY" ]
}
Transform {
  scale 1 1 1
  translation 0 0 0
  children
  [
    Shape
    { 
      geometry IndexedFaceSet
      {
        creaseAngle .5
        solid FALSE
        coord Coordinate
        {
          point
          [
""")
            
            # re-scaled xyz coordinates
            for i in range(self.n_vertex):
                var c = self.mesh.points[i].coord * SCALE_FACTOR
                f.write(t"{c.x} {c.y} {c.z}{',\n' if i < self.n_vertex - 1 else '\n'}")
	

            # colors
            f.write("""   ]
            }
            color Color
            {
              color [""")
	
            for i in range(self.n_vertex):
                var c = self.mesh.points[i].color
                f.write(t"{c.x} {c.y} {c.z}{',\n' if i < self.n_vertex - 1 else '\n'}")
            f.write("""]
            }
            colorPerVertex FALSE
            coordIndex
            [""")
	

            # face indices
            var faces = Mesh.gen_faces_flat(self.resolution)	
            var res = self.resolution

            for i in range(res):
                for j in range(res):
                    for k in range(4):
                        f.write(t"{faces[i * res * 4 + j * 4 + k]},")
                    f.write("-1,\n")
                    

            f.write("""       ]
                  }
                  appearance Appearance
                  {
                    material Material
                    {
                      ambientIntensity 0.2
                      diffuseColor 0.9 0.9 0.9
                      specularColor .1 .1 .1
                      shininess .5
                    }
                  }
                }
              ]
            }"""
            )

    def writePLYbin(self, filename: String) raises:
        var res = self.resolution

        with open(filename, "w") as f:
        
            # header
            f.write(t"""ply
format binary_little_endian 1.0
comment mojo - sh generated
element vertex {self.n_vertex}
property float x
property float y
property float z
property float nx
property float ny
property float nz
property uchar red
property uchar green
property uchar blue                   
element face {self.n_vertex}
property list uchar int vertex_indices
end_header  
"""   )

            comptime sCoord = size_of[Coord]()
            comptime s_u32 = size_of[UInt32]()
            
            # write mesh.points[] -> coords, normals, colors(3 x bytes r,g,b)
            var point_ply = Packed[2 * sCoord + 3]()            
            
            for i in range(len(self.mesh.points)):
                var mp = self.mesh.points[i]

                point_ply.write[Coord](off=0, value=mp.coord)
                point_ply.write[Coord](off=sCoord, value=mp.normal)
                point_ply.write_array[3](off=2*sCoord, value=mp.color.to_bytes())
                
                f.write_bytes(point_ply.span())

            # write faces (4 , quad)
            var faces = Mesh.gen_faces_flat(res)
            var face_ply = Packed[1 + 4 * s_u32]()
            
            for i in range(len(faces) // 4):
                face_ply.write[UInt8](off=0, value=UInt8(4)) # 4 items in face (quads)
                for j in range(4): # quad x u32 face indices
                    face_ply.write[UInt32](off=1 + j * s_u32, value=UInt32(faces[i*4 + j]))

                f.write_bytes(face_ply.span())

          


###############
from std.time import perf_counter_ns
def main(): 
  
    var sh = SphericalHarmonics(1024, 12, 111)

    var t0 = perf_counter_ns()
    sh.calc_meshST()
    print(t"SH st,      res:{sh.resolution}, code:{sh.code}, lap: {(perf_counter_ns() - t0) / 1_000_000} ms")
    
    t0 = perf_counter_ns()
    sh.calc_meshMT()
    print(t"SH mt,      res:{sh.resolution}, code:{sh.code}, lap: {(perf_counter_ns() - t0) / 1_000_000} ms")
    
    t0 = perf_counter_ns()
    sh.calc_meshSIMD()
    print(t"SH st simd, res:{sh.resolution}, code:{sh.code}, lap: {(perf_counter_ns() - t0) / 1_000_000} ms")

    t0 = perf_counter_ns()
    sh.calc_meshMT_SIMD()
    print(t"SH mt simd, res:{sh.resolution}, code:{sh.code}, lap: {(perf_counter_ns() - t0) / 1_000_000} ms")

    try :
        print("writing ply...", end='')
        sh.writePLYbin("sh.ply")
        print("done")
    except e:
        print("Failed to write PLY file", e)
