# polyhedron.mojo

from common import String, Vertexes, Face, Faces, u32, f32, random_palette
from vertex import Vertex
from packed import Packed
#
from std.sys import size_of
from max.algorithm import parallelize

# Polyhedron
struct Polyhedron(Writable, Copyable, Movable):
    var name : String
    var vertexes: Vertexes
    var faces: Faces
    var normals: Vertexes
    var colors: Vertexes
    var centers: Vertexes
    var areas: List[f32]

    def __init__(out self):
        self.name = ""
        self.vertexes = Vertexes()
        self.faces = Faces()
        self.normals = Vertexes()
        self.colors = Vertexes()
        self.centers = Vertexes()
        self.areas = List[f32]()
        
    def __init__(out self, name: String, vertexes: Vertexes, faces: Faces):
        self.name = name.copy()
        self.vertexes = vertexes.copy()
        self.faces = faces.copy()

        self.normals = Vertexes()
        self.colors = Vertexes()
        self.centers = Vertexes()
        self.areas = List[f32]()

    # copy constructor
    def __init__(out self, *, other: Self):
        self.name = other.name.copy()
        self.vertexes = other.vertexes.copy()
        self.faces = other.faces.copy()
        self.normals = other.normals.copy()
        self.colors = other.colors.copy()
        self.centers = other.centers.copy()
        self.areas = other.areas.copy()

    # move constructor
    def __init__(out self, *, deinit move: Self):
        self.name = move.name^
        self.vertexes = move.vertexes^
        self.faces = move.faces^
        self.normals = move.normals^
        self.colors = move.colors^
        self.centers = move.centers^
        self.areas = move.areas^
    
    def recalc(mut self):
        self.calc_normals()
        # self.calc_centers() # done in calc_colors
        self.calc_areas()
        self.calc_colors()

    def calc_normals(mut self):
        self.normals = Vertexes(unsafe_uninit_length = len(self.faces))
        
        def tn_fn(i : Int) {mut self}:
            self.normals[i] = Vertex.normal(self.vertexes[self.faces[i][0]], self.vertexes[self.faces[i][1]], self.vertexes[self.faces[i][2]])
        
        parallelize(tn_fn, len(self.faces))
    
    def avg_normals(mut self) -> Vertexes:
        var normals = List[Vertex](capacity = len(self.faces))

        for face in self.faces:
            var face_len = len(face)
            var normalV = Vertex()
            var v1 = self.vertexes[face[face_len - 2]]
            var v2 = self.vertexes[face[face_len - 1]]

            for ic in range(len(face)):
                var v3 = self.vertexes[ic]                
                normalV += Vertex.normal(v1,v2,v3)
                v1 = v2
                v2 = v3

            normals.append(normalV.unit())

        return normals^

    def calc_centers(mut self):
        self.centers = Vertexes(unsafe_uninit_length = len(self.faces))

        def th_fn(i : Int) {mut self}:
            var center = Vertex()
            for vertex_idx in self.faces[i]: center += self.vertexes[vertex_idx]
            self.centers[i] = center / f32(len(self.faces[i]))

        parallelize(th_fn, len(self.faces))

    def calc_areas(mut self):
        self.areas = List[f32](unsafe_uninit_length=len(self.faces))

        for i, face in enumerate(self.faces):
            
            var vsum = Vertex()
            var fl = len(face)
            var v1 = self.vertexes[face[fl - 2]]
            var v2 = self.vertexes[face[fl - 1]]

            for vertex_idx in face:
                vsum += v1.cross(v2)
                v1 = v2
                v2 = self.vertexes[vertex_idx]

            self.areas[i] = self.normals[i].dot(vsum) / 2.0
    
    def calc_colors(mut self):
        self.calc_centers()   

        # max distance from origin
        var max_dist : f32 = 0.0
        for center in self.centers:
            max_dist = max(max_dist, center.length())
        if max_dist == 0.0:  max_dist = 1.0

        # adapt tolerance
        var relative_eps : f32 = max_dist * 0.001

        var palette = random_palette()
        
        var unique_distances = List[f32]()
        var color_dict = Dict[Int, Vertex]()

        self.colors = List[Vertex](unsafe_uninit_length=len(self.faces))

        for i, cntr in enumerate(self.centers):
            var face_dist = cntr.length()
            var group_idx : Int = -1

            for idx, known_dist in enumerate(unique_distances):
                if abs(known_dist - face_dist) < relative_eps:
                    group_idx = idx
                    break
            
            if group_idx == -1:
                unique_distances.append(face_dist)
                group_idx = len(unique_distances) - 1
                color_dict[group_idx] = palette[len(color_dict) % len(palette)]

            try:
                self.colors[i] = color_dict[group_idx]
            except Exception:
                pass

    def centroid(self, face: Face) -> Vertex:
        var center = Vertex()
        for vertex_idx in face:
            center += self.vertexes[vertex_idx]
        return center / f32(len(face))

    def scale_vertexes(mut self):
        var max_val : f32 = 0.0
        for vertex in self.vertexes:
            max_val = max(max_val, vertex.max_abs())

        if max_val != 0.0:            
            for i, vertex in enumerate(self.vertexes):
                self.vertexes[i] = vertex / max_val


        
    #
    def write_to(self, mut writer: Some[Writer]):  
        writer.write("name     : ", self.name, "\n")
        writer.write("vertexes : ", self.vertexes, "\n")
        writer.write("faces    : ", self.faces, "\n")
        writer.write("normals  : ", self.normals, "\n")
        writer.write("colors   : ", self.colors, "\n")
        writer.write("centers  : ", self.centers, "\n")
        writer.write("areas    : ", self.areas, "\n")

    def write_PLYbin(self, filename: String) raises:        

        with open(filename, "w") as f:
        
            # header
            f.write(t"""ply
format binary_little_endian 1.0
comment mojo - sh generated
element vertex {len(self.vertexes)}
property float x
property float y
property float z
property float nx
property float ny
property float nz
property uchar red
property uchar green
property uchar blue                   
element face {len(self.faces)}
property list uchar int vertex_indices
end_header  
"""   )

            comptime sCoord = 3 * size_of[f32]()
            comptime s_u32 = size_of[u32]()
            
            # write mesh.points[] -> coords, normals, colors(3 x bytes r,g,b)
            var point_ply = Packed[2 * sCoord + 3]()            
            
            for i in range(len(self.vertexes)):
                var vertex = self.vertexes[i]

                point_ply.write[f32](off=0, value=vertex.x())
                point_ply.write[f32](off=4, value=vertex.y())
                point_ply.write[f32](off=8, value=vertex.z())

                def index_of(i: Int) raises {self}-> u32:
                    # find i in faces
                    for face in self.faces:
                        if u32(i) in face:
                            return u32(face.index(u32(i)))
                    return 0
                
                point_ply.write[f32](off=12, value=self.normals[index_of(i)].x())
                point_ply.write[f32](off=16, value=self.normals[index_of(i)].y())
                point_ply.write[f32](off=20, value=self.normals[index_of(i)].z())
                point_ply.write_array[3](off=2*sCoord, value=self.colors[index_of(i)].to_bytes())
                
                f.write_bytes(point_ply.span())

            # write faces (len , face)           
            for face in self.faces:
                var face_ply = Packed[1]()
                face_ply.write[UInt8](off=0, value=UInt8(len(face)))
                f.write_bytes(face_ply.span())

                for i in face: # quad x u32 face indices
                    var face_ply = Packed[s_u32]()
                    face_ply.write[UInt32](off=0, value=UInt32(i))
                    f.write_bytes(face_ply.span())

    def isTransformable(self) -> Bool:
        return True

    def calc_total_vertexes(self) -> Int:
        var total = 0
        for face in self.faces:
            total += len(face)
        return total

# test
from seeds import Tetrahedron, Cube, Icosahedron, Octahedron, Dodecahedron

def main():
    var p = materialize[Dodecahedron]()
    p.recalc()
    print(p)
    var p1 = p.copy()

    try:
        p1.write_PLYbin("dodecahedron.ply")
    except e:
        print("Error writing PLY file:", e)

    