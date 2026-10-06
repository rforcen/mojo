# Python binding.
from sh import Mesh, SphericalHarmonics
from sh_codes import N_SH_CODES
from coord import Coord
from color_map import N_COLOR_MAPS
from vector import Vector
#
from std.memory.alloc import alloc, dealloc, Layout
from std.python import Python, PythonObject

# exporting structure

struct CMesh(Copyable): 
    var coords: Pointer[Float32, MutUntrackedOrigin]
    var normals: Pointer[Float32, MutUntrackedOrigin]
    var colors: Pointer[Float32, MutUntrackedOrigin]
    var textures: Pointer[Float32, MutUntrackedOrigin]
    var vertex_count : Int64

    def __init__(out self, mesh : Mesh):       
        var vc = len(mesh.coords) 
        
        self.coords = CMesh.copy_coords(mesh.coords)
        self.normals = CMesh.copy_coords(mesh.normals)
        self.colors = CMesh.copy_coords(mesh.colors)
        self.textures = CMesh.copy_coords(mesh.textures)
        self.vertex_count = Int64(vc)

    def __init__(out self):
        self.coords = alloc[Float32]({count = 1}).unsafe_leak()
        self.normals = alloc[Float32]({count = 1}).unsafe_leak()
        self.colors = alloc[Float32]({count = 1}).unsafe_leak()
        self.textures = alloc[Float32]({count = 1}).unsafe_leak()
        self.vertex_count = 0

    @staticmethod
    def copy_coords(imm coords: Vector[Coord]) -> Pointer[Float32, MutUntrackedOrigin]:
        """
        Create a pointer with a copy of coords content.
        """
        var vc = len(coords)
        var p_coords = alloc[Float32]({count = vc * 3}).unsafe_leak()
        for i in range(vc):
            p_coords.unsafe_offset(i * 3)[] = coords[i].x
            p_coords.unsafe_offset(i * 3 + 1)[] = coords[i].y
            p_coords.unsafe_offset(i * 3 + 2)[] = coords[i].z
        
        return p_coords

    def free_coords(self: CMesh):
        self.coords.unsafe_free()
        self.normals.unsafe_free()
        self.colors.unsafe_free()
        self.textures.unsafe_free()
        
    # def __deinit__(deinit self: CMesh):
    #     self.free_coords()

# python binding
@export
def generate_mesh(mut mesh: CMesh, res: Int, colorMap: Int, code: Int) abi("C"):
    var sh = SphericalHarmonics(res, colorMap, code)       
    mesh = CMesh(sh.mesh)

@export
def free_mesh(mut mesh: CMesh) abi("C"):
    mesh.free_coords()

@export
def n_codes() abi("C") -> Int : return N_SH_CODES

@export
def n_color_maps() abi("C") -> Int : return N_COLOR_MAPS

@export
def gen_faces(res: Int32) abi("C") -> Pointer[UInt32, MutUntrackedOrigin]:
    var faces = Mesh.gen_faces_flat(Int(res))
    var p_faces = alloc[UInt32]({count = len(faces)}).unsafe_leak()
    for i in range(len(faces)):
        p_faces.unsafe_offset(i)[] = UInt32(faces[i])
    return p_faces

@export
def free_faces(faces: Pointer[UInt32, MutUntrackedOrigin], nitems: Int32) abi("C"):
    faces.unsafe_free()

# test
def test_mesh(): 
    var sh = SphericalHarmonics(1024, 1, 0)
    for _ in range(10):
        print("creating CMesh...", end='')
        var cmesh = CMesh(sh.mesh)
        print("done, vertex: ", cmesh.vertex_count)
        cmesh.free_coords()
 
def test_ffi():
    var mesh = CMesh()
    generate_mesh(mesh, 1024, 1, 0)
    print("vertex count: ", mesh.vertex_count, " coords: ", mesh.coords.unsafe_offset(0)[], " normals: ", mesh.normals, " colors: ", mesh.colors, " textures: ", mesh.textures)
    free_mesh(mesh)
    var faces = gen_faces(1024)
    free_faces(faces, 0)
    print("done")
    
def main(): test_ffi()