# File: qhull.mojo
# Author: robertoforcen@gmail.com
# Date: 2026-10-06
# Brief: QHull wrapper for convex hull computation with Waterman polyhedra, including
#        Python bindings for exporting hull data (faces, vertices, colors) to NumPy arrays.
#
from vector3d_f64 import Vector3d
from waterman_f64 import watermancoords
#
from std.ffi import external_call
from std.math import floor, atan2, pow
#
# LabelsGroupID
struct LabelsGroupID:
    var labels : List[Int]
    var num_groups : Int

    def __init__(out self, labels : List[Int], num_groups : Int):
        self.labels = labels.copy()
        self.num_groups = num_groups
    
    def __init__(out self, *, copy: Self):
        self.labels = copy.labels.copy()
        self.num_groups = copy.num_groups

# Equation
struct Equation(Comparable, Copyable):
    var normal: Vector3d
    var offset: Float64
    var index: Int

    def __init__(out self):
        self.normal = Vector3d()
        self.offset = 0.0
        self.index = 0
        
    def __init__(out self, normal : Vector3d, offset : Float64, index : Int):
        self.normal = normal
        self.offset = offset
        self.index = index

    def __lt__(self, other: Equation) -> Bool:
        if self.normal == other.normal:
            return self.offset < other.offset
        return self.normal < other.normal
    
    def __eq__(self, other : Equation) -> Bool:
        return self.normal == other.normal and self.offset == other.offset

    @staticmethod
    def to_equation(equations : List[Float64]) -> List[Equation]:
        var n_eq = len(equations) / 4
        var eqs = List[Equation]()
        
        for i in range(n_eq):            
            eqs.append(Equation(
                Vector3d(equations[i * 4 + 0], equations[i * 4 + 1], equations[i * 4 + 2]), 
                equations[i * 4 + 3], i))
        
        return eqs^
    
#
struct FloatInt(Comparable, Copyable):
    var f : Float64
    var index : Int

    def __init__(out self):
        self.f = 0.0
        self.index = 0
    def __init__(out self, f : Float64, index : Int):
        self.f = f
        self.index = index
    
    def __lt__(self, other : FloatInt) -> Bool:
        return self.f < other.f
    def __eq__(self, other : FloatInt) -> Bool:
        return self.f == other.f and self.index == other.index

# Waterman
struct Waterman:
    var radius: Float64
    var points: List[Vector3d]
    var equations: List[Equation]
    var simplices: List[Int32]
    var hull_points: List[Int32]

    var flat_vertices: List[Int]
    var face_offsets: List[Int]
    var areas : List[Float64]
    var colors : List[Vector3d]
    var flat_faces : List[Int]
    var n_faces : Int
    
    def __init__(out self, radius : Float64) raises:
        self.radius = radius
        self.points = watermancoords(radius)

        # create flat doubel List of points
        var points_dbl = List[Float64]()
        for point in self.points:
            points_dbl.append(Float64(point.x()))
            points_dbl.append(Float64(point.y()))
            points_dbl.append(Float64(point.z()))

        # prepare call parameters
        var _f64 : Float64 = 0.0
        var _i32 : Int32 = 0

        var n_points : Int32 = Int32(len(self.points))
        var n_equations : Int = 0
        var equations : Pointer[Float64, MutUntrackedOrigin] = Pointer(to=_f64).unsafe_origin_cast[MutUntrackedOrigin]()
        var n_simplices : Int = 0
        var out_simplices : Pointer[Int32, MutUntrackedOrigin] = Pointer(to=_i32).unsafe_origin_cast[MutUntrackedOrigin]()
        var n_hull_points : Int = 0
        var out_hull_points : Pointer[Int32, MutUntrackedOrigin] = Pointer(to=_i32).unsafe_origin_cast[MutUntrackedOrigin]()

        # int qhull3d(int numPoints, double *points, size_t *n_equations,
        #             double **out_equations, size_t *n_simplices, int **out_simplices,
        #             size_t *n_hull_points, int **out_hull_points) 

        var exitcode = external_call["qhull3d", Int32](
            n_points, points_dbl.unsafe_ptr(),
            Pointer(to=n_equations), Pointer(to=equations),
            Pointer(to=n_simplices), Pointer(to=out_simplices),
            Pointer(to=n_hull_points), Pointer(to=out_hull_points))
        
        # print("rad:", self.radius, ", exitcode:", exitcode, "n.points:", n_points, ", n_equations:", n_equations, ", n_simplices:", n_simplices, ", n_hull_points:", n_hull_points)
        if exitcode != 0:
            raise Error("qhull3d failed")

        # convert to list
        var l_equations = List[Float64](Span[Float64](unsafe_ptr = equations, length = n_equations))
        self.equations = Equation.to_equation(l_equations)
        # print("equations: ", l_equations[:5], ", len:", len(self.equations))

        self.simplices = List[Int32](Span[Int32](unsafe_ptr = out_simplices, length = n_simplices))
        # print("simplicies: ",l_simplicies)

        self.hull_points = List[Int32](Span[Int32](unsafe_ptr = out_hull_points, length = n_hull_points))
        # print("hull_points: ", l_hull_points)

        # free resources
        _ = external_call["qhull3d_free", NoneType](
            equations,
            out_simplices,
            out_hull_points)

        # init pending
        self.flat_vertices = List[Int]()
        self.face_offsets = List[Int]()
        self.areas = List[Float64]()
        self.colors = List[Vector3d]()
        self.flat_faces = List[Int]()
        self.n_faces = 0

        var lg = self.find_coplanar_groups()
        # print("lg: ", lg.labels, lg.num_groups)
        
        self.build_polygons(lg)
        # print("face_offsets: ", self.face_offsets)
        self.calc_areas()
        self.generate_colors()
        self.calc_flat_faces()


    def find_coplanar_groups(self, tol : Float64 = 1e-8) -> LabelsGroupID:
        var n_facets = len(self.equations) # nº trigs

        #  We round (floor) to a fixed precision to create 'bins'
        # This is equivalent to grouping by a tolerance 
        var scaled_eq = self.equations.copy()
        for i in range(len(scaled_eq)):
            scaled_eq[i].normal = (scaled_eq[i].normal / tol).floor()
            scaled_eq[i].offset = floor(scaled_eq[i].offset / tol)
            scaled_eq[i].index = i
                   
        sort(scaled_eq)

        # for i in range(10):
        #     print("sc[",i,"]", scaled_eq[i].normal, scaled_eq[i].offset, scaled_eq[i].index)
       
        var labels = List[Int](length=n_facets, fill=0)
        var group_id = 0
        labels[scaled_eq[0].index] = 0

        for k in range(1, n_facets):

            var curr_eq = scaled_eq[k].copy()
            var prev_eq = scaled_eq[k-1].copy()

            if curr_eq != prev_eq:
                group_id += 1
            
            labels[curr_eq.index] = group_id

        # print("labels:" , labels)
        return LabelsGroupID(labels^, group_id + 1)

    def build_polygons(mut self, lg: LabelsGroupID):
        var n_simplices = len(self.simplices) / 3

        # 1. Count how many vertices per group (including duplicates initially)
        # We use this to pre-allocate a temporary storage
        var group_counts = List[Int](length=lg.num_groups, fill=0)
        for i in range(n_simplices):
            group_counts[lg.labels[i]] += 3
        
        # 2. Map simplices to their groups
        # We store which triangle index belongs to which group        
        var current_offset = List[Int](length=lg.num_groups, fill=0)
        var group_offsets = List[Int](length=lg.num_groups + 1, fill=0)

        for i in range(lg.num_groups):
            group_offsets[i + 1] = group_offsets[i] + group_counts[i]/3
        
        var tri_in_groups = List[Int](length=n_simplices, fill=0)
        for i in range(n_simplices):
            var g = lg.labels[i]
            tri_in_groups[group_offsets[g] + current_offset[g]] = i
            current_offset[g] += 1

        # 3. Final outputs
	    # We'll use a maximum possible size and then slice it
        var flat_vertices = List[Int](length=n_simplices * 3, fill=0)
        var face_offsets = List[Int](length=lg.num_groups + 1, fill=0)

        var v_ptr = 0
        for g in range(lg.num_groups):
            # Collect all vertices for this group
            var start_tri = group_offsets[g]
            var end_tri   = group_offsets[g + 1]

            # Temporary unique vertex extraction
            # For Waterman solids, faces usually have 3-8 vertices
            var temp_v = List[Int]()            

            for t_idx in range(start_tri, end_tri):
                var tri = tri_in_groups[t_idx]

                for v_idx in self.simplices[tri * 3 : tri * 3 + 3]:
                    if not Int(v_idx) in temp_v:
                        temp_v.append(Int(v_idx))

            # print("temp_v:", temp_v)

            # Convert to array for sorting
            var unique_v = temp_v.copy()
            var n_unique = len(unique_v)

            if n_unique >= 3:
                # Get normal from first triangle in group
                var normal = self.equations[tri_in_groups[start_tri]].normal
                # Extract coordinates for sorting
                var face_coords = List[Vector3d](length=n_unique, fill=Vector3d())
                
                for i in range(n_unique):
                    face_coords[i] = self.points[unique_v[i]]

                # sort
                var sort_idx = self.sort_face_vertices(face_coords, normal)                

                # Store results
                face_offsets[g] = v_ptr
                for i in range(n_unique):
                    flat_vertices[v_ptr] = unique_v[sort_idx[i].index]
                    v_ptr += 1
            else:
                face_offsets[g] = v_ptr
        

        face_offsets[lg.num_groups] = v_ptr

        self.flat_vertices = List[Int](flat_vertices[:v_ptr])
        self.face_offsets = face_offsets^
        
    @staticmethod
    def sort_face_vertices(face_coords: List[Vector3d], normal: Vector3d) -> List[FloatInt]:
        # (Same as previous: Centroid -> Projection -> Arctan2 -> Argsort)
        var centroid = Vector3d()
        
        for i in range(len(face_coords)):
            centroid += face_coords[i]
        centroid /= Float64(len(face_coords))

        var _ref = Vector3d(1.0, 0.0, 0.0)
        if abs(_ref.dot(normal)) > 0.9:
            _ref = Vector3d(0.0, 1.0, 0.0)

        var u = normal.cross(_ref).normalize()
        var v = normal.cross(u)

        var angles = List[FloatInt](length=len(face_coords), fill=FloatInt())
        
        for i in range(len(face_coords)):
            var diff = face_coords[i] - centroid
            angles[i] = FloatInt(atan2(Float64(diff.dot(v)), Float64(diff.dot(u))), i)
        
        sort(angles)

        return angles^

    def calc_flat_faces(mut self):
        var faces_flat = List[Int]()
        
        self.n_faces = 0
        for i in range(len(self.face_offsets) - 1):
            var start = self.face_offsets[i]
            var end = self.face_offsets[i + 1]
            
            var face = self.flat_vertices[start:end]
            
            faces_flat.append(len(face))
            for f in face:
                faces_flat.append(f)
            
            self.n_faces += 1
        
        self.flat_faces = faces_flat^

    def calc_areas(mut self):
        var num_faces = len(self.face_offsets) - 1
        self.areas = List[Float64](length=num_faces, fill=0.0)
        
        for i in range(num_faces):
            var start          = self.face_offsets[i]
            var end            = self.face_offsets[i + 1]
            var face_indices = self.flat_vertices[start:end]
            var n_verts        = len(face_indices)

            if n_verts < 3:
                self.areas[i] = 0.0
                continue
            
            # centroid
            var centroid = Vector3d()
            for idx in face_indices:
                centroid += self.points[idx]
            centroid /= Float64(n_verts)

            var face_area = 0.0
            for j in range(n_verts):
                var v1 = self.points[face_indices[j]] - centroid
                var v2 = self.points[face_indices[(j + 1) % n_verts]] - centroid

                var cp           = v1.cross(v2)
                var triangle_area = 0.5 * cp.norm()
                face_area += Float64(triangle_area)

            self.areas[i] = face_area


    def generate_colors(mut self):
        var num_faces = len(self.areas)
        self.colors = List[Vector3d](length=num_faces, fill=Vector3d())
        
        for i in range(num_faces):
            var decs    : Int     = 4
            var ten_d   : Float64 = pow(10.0, decs)
            var area_id : Int     = Int(floor((floor(self.areas[i] * ten_d) / ten_d) * ten_d))

            # print("area ID:", self.areas[i], area_id, ", ten_d:", ten_d)

            # Linear Congruential Generator (LCG) approach
            # Instead of np.random.seed (which is slow/unsupported in loops),
            # we use a simple deterministic hash for the color. 

            # Salted hash for Red
            var r_seed = Int((area_id * 1103515245 + 12345) & 0x7fffffff)
            self.colors[i][0] = Float64(r_seed % 1000) / 1000.0

            # Salted hash for Green
            var g_seed = Int((r_seed * 1103515245 + 12345) & 0x7fffffff)
            self.colors[i][1] = Float64(g_seed % 1000) / 1000.0

            # Salted hash for Blue
            var b_seed = Int((g_seed * 1103515245 + 12345) & 0x7fffffff)
            self.colors[i][2] = Float64(b_seed % 1000) / 1000.0

   
### python binding
from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder
from std.python.numpy import copy_to_numpy_array

# helpers
def waterman_qhull(_rad : PythonObject) raises -> PythonObject:
    var rad = Float64(py=_rad)

    var w = Waterman(rad)
    
    def flattern_coords(coords : List[Vector3d]) -> List[Float64]:
        var result = List[Float64]()
        for c in coords: result.extend(c.serial())
        return result^

    def conv_faces(faces : List[Int]) -> List[Int64]:
        var result = List[Int64]()
        for face in faces:  result.append(Int64(face))
        return result^

   
    return Python.list(
        copy_to_numpy_array(conv_faces(w.flat_faces)),
        copy_to_numpy_array(flattern_coords(w.points)).reshape(-1,3),
        copy_to_numpy_array(flattern_coords(w.colors)).reshape(-1,3)
    )

# python module init
@export
def PyInit_waterman() abi("C") -> PythonObject:
    """Initialize the waterman module."""
    try:
        var builder = PythonModuleBuilder("waterman")
        builder.def_function[waterman_qhull]("waterman_qhull", "Generate a waterman qhull")
         
        return builder.finalize()
    except:
        print("PyInit_waterman: Error building module waterman")
        return None


# test
def test() raises:
    var w = Waterman(5.0)  
    
    print("faces:", w.flat_faces[:10], ", len:", len(w.flat_faces))
    print("points:", w.points[:10], ", len:", len(w.points))
    print("colors:", w.colors[:10], ", len:", len(w.colors))
    print("flat vertices: ", w.flat_vertices[:10], ", len:", len(w.flat_vertices))
    print("face_offset: ", w.face_offsets[:10], ", len:", len(w.face_offsets))
    
    print("done") 

# def main() raises:   test()
    
