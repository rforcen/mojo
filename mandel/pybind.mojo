"""Python binding for mandel mandel.cpython-ver-plat.so  .

example usage:


###################
import mandel
import numpy as np
from PIL import Image

w = 2048
h = 2048
iters = 100
center_re = "-0.5"
center_im = "0"
rad = "1.5"

image = mandel.render(w, h, iters, center_re, center_im, rad)
Image.fromarray(image.view(np.uint8).reshape(h, w, 4)).show()

image = mandel.renderMP(
    w,
    h,
    2200,
    "-0.54280584740634268367882858449016222926907465243354029312039262030034763062217093",
    "-0.61549567328280223372696654577766177370034035939345019559741864301726447118754571",
    "1.66153499473114484112975882535043072e-59",
)
Image.fromarray(image.view(np.uint8).reshape(h, w, 4)).show()
###################."""

from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder
from std.complex import ComplexFloat64
from std.time import perf_counter
from std.runtime import initialize_runtime

from mandel import Mandel
from mandelMP import MandelbrotMP
from mp import ComplexMP, BigFloat


def to_numpy(imm image : List[UInt32]) -> PythonObject :
    """Convert a List[UInt32] to a numpy array using mojo python numpy & ctypes binding."""

    try:
        var ctypes = Python.import_module("ctypes")
        var np = Python.import_module("numpy")

        var total_bytes = image.byte_length()  
        var ptr_address = Int(image.unsafe_ptr()) # address of image as Int

        # create numpy array from ctypes buffer
        try:
            var c_buffer = ctypes.string_at(ptr_address, total_bytes)
            var arr = np.frombuffer(c_buffer, dtype=np.uint32)
            return arr.copy()
        except e:
            print("Error creating numpy array:", e)
            return None

    except e:
        print("Error importing python module:", e)
        return None
    
def render(w: PythonObject, h : PythonObject, iters: PythonObject, center_re: PythonObject, center_im: PythonObject, rad: PythonObject) -> PythonObject:    
    """Render Mandelbrot set in f64 precision."""

    try:
        var width = Int(py=w)
        var height = Int(py=h)
        var iterations = Int(py=iters)
        
        # center & rad are string as in MP        
        var radius = Float64(BigFloat(String(py=rad)))
        var center = ComplexFloat64(Float64(BigFloat(String(py=center_re))), Float64(BigFloat(String(py=center_im))))
      
        #  render mandelbrot set in f64
        var mandel = Mandel(width, height, iterations, radius, center)
        var lap = perf_counter()
        mandel.genImageMT_SIMD()        
        lap = 1000 * (perf_counter() - lap)

        var res = Python.evaluate("[]") 
        res.append(to_numpy(mandel.image))
        res.append(PythonObject(Int(lap)))

        return res
    except e:
        print("Error converting parameters:", e)
        return None


def renderMP(w: PythonObject, h : PythonObject, iters: PythonObject, center_re: PythonObject, center_im: PythonObject, rad: PythonObject) -> PythonObject:    
    """Render Mandelbrot set in MP precision."""

    try:        

        var width = Int(py=w) # get ints
        var height = Int(py=h)
        var iterations = Int(py=iters)
        
        var radius = BigFloat(String(py=rad)) # convert to BigFloat
        var center = ComplexMP(String(py=center_re), String(py=center_im)) # convert to ComplexMP
        
        #  render mandelbrot set
        var mandel = MandelbrotMP(width, height, iterations, center^, radius^)
        
        var lap = perf_counter()
        mandel.renderMT()        
        lap = 1000 * (perf_counter() - lap)

        var res = Python.evaluate("[]") 
        res.append(to_numpy(mandel.image))
        res.append(PythonObject(Int(lap)))

        return res
        
    except e:
        print("Error converting parameters:", e)
        return None

@export
def PyInit_mandel() abi("C") -> PythonObject:
    """Initialize the mandel module."""

    initialize_runtime()

    try:
        BigFloat.set_prec(512) # default prec

        var builder = PythonModuleBuilder("mandel")

        builder.def_function[render]("render", "Render Mandelbrot set in f64 precision, radius & center as strings")
        builder.def_function[renderMP]("renderMP", "Render Mandelbrot set in MP precision, radius & center as strings")

        return builder.finalize()
    except:
        print("Error building module mandel")
        return None