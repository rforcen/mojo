# python binding
from std.python.bindings import PythonModuleBuilder
from std.python import Python, PythonObject
from std.python.numpy import copy_to_numpy_array
from std.time import perf_counter

#
from polyhedron import Polyhedron
from seeds import Dodecahedron
from common import flatten_faces, flatter_vertexes, transform
from conway import kis

# name, face_flat, coords(-1,3), colors(-1,3) = poly.transform(poly_string, n, 0.1)
def py_transform(trn_s : PythonObject, n : PythonObject, alpha: PythonObject) -> PythonObject:
    try:
        var trn_s = String(py=trn_s)
        var n = Int(py=n)
        var alpha = Float32(py=alpha)

        var lap = perf_counter()
        var p = transform(trn_s)
    
        var face_flat = copy_to_numpy_array(flatten_faces(p.faces))
        var flat_coords = copy_to_numpy_array(flatter_vertexes(p.vertexes)).reshape(-1,3)
        var flat_colors = copy_to_numpy_array(flatter_vertexes(p.colors)).reshape(-1,3)

        return Python.list(PythonObject(Int(1000*(perf_counter() - lap))), PythonObject(p.name), face_flat, flat_coords, flat_colors)

    except:
        print("Error converting parameters to String, Int, Float32")
        return None

def py_write_ply(tr : PythonObject, filename : PythonObject):
    try:
        var filename = String(py=filename)
        var tr = String(py=tr)
        
        var p = transform(tr)
        p.recalc()
        p.write_PLYbin(filename)
        
    except:
        print("Error converting parameters to String")
        
    
@export
def PyInit_poly() abi("C") -> PythonObject:
    """Initialize the poly module."""
    try:
        var builder = PythonModuleBuilder("poly")

        builder.def_function[py_write_ply]("write_ply", "Write a polyhedron to a PLY file, args: transformation string, filename")
        builder.def_function[py_transform]("transform", "Transform a string")
        
        return builder.finalize()
    except:
        print("Error building module sh")
        return None
