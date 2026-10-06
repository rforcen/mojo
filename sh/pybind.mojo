# Python binding for SphericalHarmonics

from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder
from std.complex import ComplexFloat64
from std.sys import size_of
from std.time import perf_counter_ns
#
from sh import Mesh, Point, SphericalHarmonics
from sh_codes import N_SH_CODES
from coord import Coord
from color_map import N_COLOR_MAPS
from vector import Vector

# convert any Copyable Vector to a flat numpy array of numpy_type
struct Utils:
    @staticmethod
    def v_to_numpy[T:ImplicitlyCopyable & Writable](imm v : Vector[T], imm numpy_type : PythonObject, imm ctypes : PythonObject, imm np : PythonObject) -> PythonObject :
        """Convert a Vector[T] to a numpy array using mojo python numpy & ctypes binding."""

        # create numpy array from ctypes buffer
        try:
            return np.frombuffer(buffer = ctypes.string_at(ptr=v.unsafe_ptr_as_int(), size=v.size_in_bytes()), dtype=numpy_type)
        except e:
            print("Error creating numpy array:", e)
            return None

#   return faces (flat quads int64), coords (float32), normals (float32), colors (float32)
# usage: faces, coords, normals, colors = sh.render(128, 0, 1)
def render(resolution: PythonObject, color_map: PythonObject, code: PythonObject) -> PythonObject:    
    """Render Spherical Harmonics."""

    try:
        var resolution_int = Int(py=resolution) # extract params
        var color_map_int = Int(py=color_map)
        var code_int = Int(py=code)
        
        #  render spherical harmonics & faces
        var lap = perf_counter_ns()
        var sh = SphericalHarmonics(resolution_int, color_map_int, code_int)    
        lap = (perf_counter_ns() - lap) / 1_000_000
        
        sh.mesh.scale_coords()
        var faces = Mesh.gen_faces_flat(resolution_int)

        try:
            var ctypes = Python.import_module("ctypes") # load numpy & ctypes
            var np = Python.import_module("numpy")          

            return Python.list( # faces, coords, lap
                Utils.v_to_numpy[Int](v=faces, numpy_type=np.int64, ctypes=ctypes, np=np),
                Utils.v_to_numpy[Point](v=sh.mesh.points, numpy_type=np.float32, ctypes=ctypes, np=np),
                PythonObject(lap)
            )

        except e:
            print("Error importing python module:", e)
            return None     

    except e:
        print("Error converting parameters:", e)
        return None

def n_codes() -> PythonObject:
    """Return the number of codes."""
    return PythonObject(N_SH_CODES)

def n_color_maps() -> PythonObject:
    """Return the number of color maps."""
    return PythonObject(N_COLOR_MAPS)

@export
def PyInit_sh() abi("C") -> PythonObject:
    """Initialize the sh module."""
    try:
        var builder = PythonModuleBuilder("sh")

        builder.def_function[render]("render", "Render Spherical Harmonics")
        builder.def_function[n_codes]("n_codes", "Number of codes")
        builder.def_function[n_color_maps]("n_color_maps", "Number of color maps")

        return builder.finalize()
    except:
        print("Error building module sh")
        return None