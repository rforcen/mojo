# sh gpu
from std.sys import has_accelerator
from std.gpu.primitives.id import block_dim, block_idx, thread_idx
from std.sys.info import size_of
from max.gpu.host import DeviceContext
#
from std.time import perf_counter
from std.math import sin, cos, pi, tau
#
from coord import Coord
from sh_codes import SH_CODES, N_SH_CODES, CODE_LENGTH, code_to_f32, code_to_ints
from color_map import N_COLOR_MAPS, ColorMap
from packed import Packed
#
comptime UInt32Ptr = Pointer[UInt32, MutUntrackedOrigin]
comptime Int32Ptr = Pointer[Int32, MutUntrackedOrigin]
comptime Float32Ptr = Pointer[Float32, MutUntrackedOrigin]
comptime MeshPtr = Pointer[Float32, MutUntrackedOrigin]
comptime CoordPtr = Pointer[Coord, MutUntrackedOrigin]
comptime u32 = DType.uint32

# pointer access helper
struct Pnt[T : Movable & Writable & ImplicitlyCopyable ,  /]:
    var p : Pointer[Self.T, MutUntrackedOrigin]

    def __init__(out self, ptr : Pointer[Self.T, MutUntrackedOrigin]): self.p = ptr

    @always_inline
    def __getitem__(self, index: Int) -> ref [self.p] Self.T:  return self.p.unsafe_offset(index)[]

struct Mesh(Copyable):
    var v : List[Float32]    
    var res : Int    

    def __init__(out self, res : Int):
        self.res = res
        self.v = List[Float32](length=res * res * 4 * 3, fill=0.0)

    def __copy__(self) -> Mesh:
        var res = Mesh(self.res)
        res.v = self.v.copy()
        return res^

    def get_coord_ptr(self, index:Int) -> Pointer[Coord, origin_of(self.v)]: return self.v.unsafe_ptr().unsafe_bitcast[Coord]().unsafe_offset(index)
    def get_coord_ptr_mut(mut self, index:Int) -> Pointer[Coord, origin_of(self.v)]: return self.v.unsafe_ptr().unsafe_bitcast[Coord]().unsafe_offset(index).unsafe_mut_cast[True]()

    def unsafe_ptr(self) -> Pointer[Float32, origin_of(self.v)]:
        return self.v.unsafe_ptr()

    def length(self) -> Int:
        return len(self.v)
    def n_vertex(self) -> Int:
        return len(self.v) // 12

    def get_vertex(self, index:Int) -> Coord: return self.get_coord_ptr(index*4)[]
    def set_vertex(mut self, index:Int, vertex:Coord): self.get_coord_ptr_mut(index*4)[] = vertex
     
    def get_normal(self, index:Int) -> Coord: return self.get_coord_ptr(index*4 + 1)[]
    def set_normal(mut self, index:Int, normal:Coord): self.get_coord_ptr_mut(index*4 + 1)[] = normal

    def get_color(self, index:Int) -> Coord:  return self.get_coord_ptr(index*4 + 2)[]
    def set_color(mut self, index:Int, color:Coord): self.get_coord_ptr_mut(index*4 + 2)[] = color

    def get_uv(self, index:Int) -> Coord:  return self.get_coord_ptr(index*4 + 3)[]
    def set_uv(mut self, index:Int, uv:Coord): self.get_coord_ptr_mut(index*4 + 3)[] = uv

    @always_inline
    @staticmethod
    def coord_ptr(ptr : MeshPtr, index : Int32) -> CoordPtr:       return ptr.unsafe_bitcast[Coord]().unsafe_offset(index).unsafe_mut_cast[True]()
    
    @always_inline
    @staticmethod
    def write_coord(ptr: MeshPtr, index: Int32, coord: Coord):     Mesh.coord_ptr(ptr, index * 4 + 0)[] = coord        
    @always_inline
    @staticmethod
    def write_normal(ptr: MeshPtr, index: Int32, normal: Coord):   Mesh.coord_ptr(ptr, index * 4 + 1)[] = normal        
    @always_inline
    @staticmethod
    def write_color(ptr: MeshPtr, index: Int32, color: Coord):     Mesh.coord_ptr(ptr, index * 4 + 2)[] = color        
    @always_inline
    @staticmethod
    def write_uv(ptr: MeshPtr, index: Int32, uv: Coord):           Mesh.coord_ptr(ptr, index * 4 + 3)[] = uv        

    # view with: f3d sh.ply 
    def writePLYbin(self, filename: String) raises:
        with open(filename, "w") as f:
        
            # header
            f.write(t"""ply
format binary_little_endian 1.0
comment mojo - sh generated
element vertex {self.n_vertex()}
property float x
property float y
property float z
property float nx
property float ny
property float nz
property uchar red
property uchar green
property uchar blue                   
element face {self.n_vertex()}
property list uchar int vertex_indices
end_header  
"""   )

            comptime sCoord = size_of[Coord]()
            comptime s_u32 = size_of[UInt32]()
            
            # write mesh.points[] -> coords, normals, colors(3 x bytes r,g,b)
            comptime SZ_BUFF = 1024 # nº of items buffer
            comptime SZ_VTX_ITEM = 2 * sCoord + 3
            var point_ply = Packed[SZ_BUFF * SZ_VTX_ITEM]()            
            
            for i in range(self.n_vertex()):           
                
                point_ply.append[Coord](value=self.get_vertex(i))
                point_ply.append[Coord](value=self.get_normal(i))
                point_ply.append_array[3](value=self.get_color(i).to_bytes())
                                
                if point_ply.is_full():
                    f.write_bytes(point_ply.span())  # write span & reset        
                    
            # write remaining bytes if any
            if point_ply.not_empty(): f.write_bytes(point_ply.span_toOffset())

            
            # write faces (4 , quad)
            var faces = gen_faces_flat(self.res)

            comptime SZ_FACE_ITEM = 1 + 4 * s_u32
            var face_ply = Packed[SZ_BUFF * SZ_FACE_ITEM]()
            for i in range(len(faces) // 4): # quads
                face_ply.append[UInt8](value=UInt8(4)) # 4 items in face (quads)

                for j in range(4): # quad x u32 face indices
                    face_ply.append[UInt32](value=UInt32(faces[i*4 + j]))

                if face_ply.is_full(): f.write_bytes(face_ply.span()) # write span & reset
            
            # write remaining bytes if any
            if face_ply.not_empty(): f.write_bytes(face_ply.span_toOffset())
          

@always_inline
def pown(x:Float32, n : Int32) -> Float32:
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
def calcCoord(theta: Float32, phi: Float32, mf: Pnt[Float32], m: Pnt[Int32]) -> Coord:
    var r : Float32 = pown(sin(mf[0] * phi) , m[1]) + 
        pown(cos(mf[2] * phi) , m[3]) + 
        pown(sin(mf[4] * theta) , m[5]) + 
        pown(cos(mf[6] * theta) , m[7])
    
    return Coord(r * sin(phi) * cos(theta), r * cos(phi), r * sin(phi) * sin(theta))
#

def SphericalHarmonics(res : Int, code : Int, color_map:Int) raises -> Tuple[Mesh, Int]:
        
    # Kernel generates mandelbrot set using cardiod algo.
    def sh_kernel(
        mesh_ptr  : MeshPtr,

        res       : Int32,
        code      : Int32,        
        color_map : Int32,

        m  : Int32Ptr,
        mf : Float32Ptr
    ):

        var pm = Pnt[Int32](m)
        var pmf = Pnt[Float32](mf)        
        
        # image index
        var x = Int32((block_idx.x * block_dim.x) + thread_idx.x)
        var y = Int32((block_idx.y * block_dim.y) + thread_idx.y)
        var index = y * res + x

        # img in bounds?
        if x < res and y < res:          
            var du : Float32 = tau / Float32(res)
            var dv : Float32 = pi / Float32(res)   

            var u : Float32 = du * Float32(x)
            var v : Float32 = dv * Float32(y)

            var du10 : Float32 = du / 10.0
            var dv10 : Float32 = dv / 10.0

            var crd : Coord       = calcCoord(u, v, pmf, pm)
            var crd_up : Coord    = calcCoord(u + du10, v, pmf, pm) # used in normal calc
            var crd_right : Coord = calcCoord(u, v + dv10, pmf, pm)
            
            Mesh.write_coord  (mesh_ptr, index, crd)
            Mesh.write_normal (mesh_ptr, index, Coord.normal(crd, crd_up, crd_right))
            Mesh.write_color  (mesh_ptr, index, ColorMap(u, 0.0, tau, Int(color_map)))
            Mesh.write_uv     (mesh_ptr, index, Coord(Float32(x)/Float32(res), Float32(y)/Float32(res), 0.0))
            

    # end of kernel
        
    if not has_accelerator():
        print("no GPU found")
        var res = Tuple[Mesh, Int](Mesh(0), 0)
        return res^
    else:          
        var mf = code_to_f32(code)
        var m = code_to_ints(code)

        var mesh = Mesh(res)

        with DeviceContext() as ctx:                             

            # gpu buffer 
            var buffer_mesh = ctx.enqueue_create_buffer[DType.float32](mesh.length())
            var buffer_mf = ctx.enqueue_create_buffer[DType.float32](len(mf))
            var buffer_m = ctx.enqueue_create_buffer[DType.int32](len(m))
            
            # copy to gpu
            ctx.enqueue_copy(buffer_mesh, mesh.v.unsafe_ptr())
            ctx.enqueue_copy(buffer_mf, mf.unsafe_ptr())
            ctx.enqueue_copy(buffer_m, m.unsafe_ptr())

            # configure dimensions 2D (16x16 threads per block)
            comptime BLOCK_SIZE = 16
            var grid_x = (res + BLOCK_SIZE - 1) // BLOCK_SIZE
            var grid_y = (res + BLOCK_SIZE - 1) // BLOCK_SIZE

            var lap = perf_counter()
            # run kernel w/params
            ctx.enqueue_function[sh_kernel](
                buffer_mesh,

                Int32(res),
                Int32(code),                
                Int32(color_map),
                buffer_m,
                buffer_mf,
                
                grid_dim=(grid_x, grid_y),
                block_dim=(BLOCK_SIZE, BLOCK_SIZE),
            )
           
            # copy back to cpu            
            ctx.enqueue_copy(mesh.v.unsafe_ptr(), buffer_mesh)

            # wait for gpu to finish            
            ctx.synchronize()
            lap = 1000*(perf_counter() - lap) # in ms            

            var r = Tuple[Mesh, Int](mesh^, Int(lap))
            return r^

def gen_faces_flat(res: Int) -> List[Int]:
    "Generate faces as quads for a grid of size res x res."
    var faces = List[Int](length=res*res*4, fill=0)
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


#
def test_sh() raises:
    var code = 0
    var res = 512 * 2
    var color_map = 0
    
    print(t"SH {res} ", end='')

    var result = SphericalHarmonics(res=res, code=code, color_map=color_map)     
    var mesh = result[0].copy()
    var lap = result[1]
    
    print(t", lap: {lap} ms")
    
    mesh.writePLYbin("sh.ply")
#
def main() raises:
    test_sh()
    