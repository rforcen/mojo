# mojo run -O3 mandel_test.mojo

from std.complex import ComplexFloat64
from std.time import perf_counter_ns
from mandel import Mandel
from mandelMP import MandelbrotMP
from mp import ComplexMP, BigFloat

def test_mandelf64(): 
    var w = 2048
    var h = 2048
    var iters = 100

    # st
    var mandel = Mandel(w, h, iters, 1.5, ComplexFloat64(-0.5, 0.0))        
    var start = perf_counter_ns()
    mandel.genImageST()
    var end = perf_counter_ns()
    print(t"Mandelbrot ST      {mandel.w}x{mandel.h}, iters {mandel.iters}, lap: ", (end - start) / 1_000_000, " ms")
 
    # mt
    mandel.reset()
    start = perf_counter_ns()
    mandel.genImageMT()
    end = perf_counter_ns()
    print(t"Mandelbrot MT      {mandel.w}x{mandel.h}, iters {mandel.iters}, lap: ", (end - start) / 1_000_000, " ms")
 
    # st simd
    mandel.reset()
    start = perf_counter_ns()
    mandel.genImageST_SIMD()
    end = perf_counter_ns()
    print(t"Mandelbrot ST SIMD {mandel.w}x{mandel.h}, iters {mandel.iters}, lap: ", (end - start) / 1_000_000, " ms")
    
    # mt simd
    mandel.reset()
    start = perf_counter_ns()
    mandel.genImageMT_SIMD()
    end = perf_counter_ns()
    print(t"Mandelbrot MT SIMD {mandel.w}x{mandel.h}, iters {mandel.iters}, lap: ", (end - start) / 1_000_000, " ms")
    
    mandel.writePAM("mandel.pam")
 
    # st slow
    mandel.reset()
    start = perf_counter_ns()
    mandel.genImageST_Slow()
    end = perf_counter_ns()
    print(t"Mandelbrot ST Slow {mandel.w}x{mandel.h}, iters {mandel.iters}, lap: ", (end - start) / 1_000_000, " ms")
 
    

struct MandelDef(ImplicitlyCopyable):
    var cr: String
    var ci : String
    var rad: String
    var iters: Int

    def __init__(out self, var cr: String, var ci: String, var rad: String, iters: Int):
        self.cr = cr^
        self.ci = ci^
        self.rad = rad^
        self.iters = iters

    
comptime mandel_defs : Array[MandelDef, 3] = [
    MandelDef(
            "-0.56220202130123957816449023695910543180251555548638877144858663740558269503842871",
            "-0.64281611907930380064599567644262307765213085815705577558092218834250488108602323",
            "0.000000000000013308814531779911325976388083886801776494897961803919560818301986950182277467004",
            450
    ),
    MandelDef(
            "0.25476641952991485595703125",
            "0.0005311667919158935546875",
            "0.000011444091796875",
            350
    ),
    MandelDef(
            "-0.54280584740634268367882858449016222926907465243354029312039262030034763062217093",
            "-0.61549567328280223372696654577766177370034035939345019559741864301726447118754571",
            "1.66153499473114484112975882535043072e-59",
            2200
    )
]

def test_mandelMP():
    print("MP mandel")
    BigFloat.set_prec(384)

    var w = 1024*2
    var h = 1024*2
    
    var md = materialize[mandel_defs[2]]()
    
    var center = ComplexMP(md.cr, md.ci)
    var rad = BigFloat(md.rad)
    
    var mandel = MandelbrotMP(w, h, md.iters, center^, rad^)

    var start = perf_counter_ns()
    mandel.renderMT()
    var end = perf_counter_ns()
    print(t"Mandelbrot MP {mandel.width}x{mandel.height}, iters {mandel.iters}, lap: ", (end - start) / 1_000_000, " ms")
    mandel.writePAM("mandel.pam")
 
def main():
    # test_mandelMP()
    test_mandelf64()
