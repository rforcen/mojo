# python binding
# usage:

# import dc
# expr = dc.random_expression(5)
# img = dc.generate_dc(512, 512, expr)
# pil_img = Image.frombytes("RGBA", (512, 512), img)
# pil_img.show()

# dc helpers
import expr_gen
import dc_gpu

# python binding stuff
from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder
from std.python.numpy import copy_to_numpy_array

# generate random expression of given complexity
def random_expression(complexity : PythonObject) -> PythonObject:
    try: 
        var complexity_int = Int(py=complexity)
        return PythonObject(expr_gen.random_expression(complexity_int))
    except:
        print("random_expression: Error converting complexity to int")
        return None
    
# createa numpy uint32 array ARGB from expression string
def generate_dc(w : PythonObject, h : PythonObject, expr : PythonObject) -> PythonObject:
    try: 
        var w_int = Int(py=w)
        var h_int = Int(py=h)
        var expr_str = String(py=expr)

        var res = dc_gpu.DomainColoringGPU(w_int, h_int, expr_str)

        var ret = Python.list(copy_to_numpy_array(res[0].copy()), res[1])
        return ret
    except:
        print("generate_dc: Error converting parameters to int or string")
        return None

# return image, expression
def generate_random_dc(w : PythonObject, h : PythonObject, complexity : PythonObject) -> PythonObject:
    try: 
        var w_int = Int(py=w)
        var h_int = Int(py=h)
        var complexity_int = Int(py=complexity)
        
        var expr = expr_gen.random_expression(complexity_int)

        var res = dc_gpu.DomainColoringGPU(w_int, h_int, expr)
        return Python.list(copy_to_numpy_array(res[0].copy()), PythonObject(expr))
    except:
        print("generate_random_dc: Error converting parameters to int or string")
        return None

# python module init
@export
def PyInit_dc() abi("C") -> PythonObject:
    """Initialize the dc module."""
    try:
        var builder = PythonModuleBuilder("dc")

        builder.def_function[random_expression]("random_expression", "Generate a random expression")
        builder.def_function[generate_dc]("generate_dc", "Generate a domain coloring image")
        builder.def_function[generate_random_dc]("generate_random_dc", "Generate a random domain coloring image")
        
        return builder.finalize()
    except:
        print("PyInit_dc: Error building module dc")
        return None