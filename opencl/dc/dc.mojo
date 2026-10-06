# dc.mojo DomainColoring
#
from eval import evaluate
from cmath import atan2
import dc_gpu 
#
from std.complex import ComplexFloat32
from std.math import e, pi, tau, floor, ceildiv, isfinite
#
comptime UInt32Ptr  = Pointer[UInt32,  MutUnsafeAnyOrigin]
comptime Float32Ptr = Pointer[Float32, MutUnsafeAnyOrigin]

# helpers

@always_inline
def _gen_pixel(z: ComplexFloat32, code : UInt32Ptr, consts : Float32Ptr) -> UInt32:
    @always_inline
    def _hsv_2_rgb(_h: Float32, _s: Float32, _v: Float32) -> UInt32:
        var h = _h
        var s = _s
        var v = _v
        
        var r: Float32 = 0.0
        var g: Float32 = 0.0
        var b: Float32 = 0.0

        if s==0.0:
            r = v
            g = v
            b = v
        else:
            if h==1.0:
                h = 0.0
            var z = floor(h * 6.0)
            var i = Int32(z)

            var f = h * 6.0 - z
            var p = v * (1.0 - s)
            var q = v * (1.0 - s * f)
            var t = v * (1.0 - s * (1.0 - f))

            if i == 0:
                r = v
                g = t
                b = p
            elif i == 1:
                r = q
                g = v
                b = p
            elif i == 2:
                r = p
                g = v
                b = t
            elif i == 3:
                r = p
                g = q
                b = v
            elif i == 4:
                r = t
                g = p
                b = v
            elif i == 5:
                r = v
                g = p
                b = q
            
        # Convert to UInt32
        return UInt32((Int32(r * 255.0) << 16) | (Int32(g * 255.0) << 8) | Int32(b * 255.0))

    try:
        var res = evaluate(code, consts, z)
    
        if not (isfinite(res.re) and isfinite(res.im)): return 0xFF000000
        
        var m = res.norm()
        var range_s: Float32 = 0.0
        var range_e: Float32 = 1.0

        while m > range_e:
            range_s = range_e
            range_e *= Float32(e)

        var k = (m - range_s) / (range_e - range_s)
        var kk = k*2 if k < 0.5 else 1 - (k - 0.5) * 2

        var hue = (atan2(res.im, res.re) % tau) / tau
        var sat = 0.4 + (1 - (1 - kk) * (1 - kk) * (1 - kk)) * 0.6
        var val = 0.6 + (1 - (1 - (1 - kk)) * (1 - (1 - kk)) * (1 - (1 - kk))) * 0.4
        
        return 0xff00_0000 | _hsv_2_rgb(hue, sat, val)

    except Exception:
        return 0xFF000000


@always_inline
def gen_pixel(x: Int32, y: Int32, width: Int32, height: Int32, code : UInt32Ptr, consts : Float32Ptr) -> UInt32:
    var limit = Float32(pi)
    var rmi = -limit
    var rma = limit
    var imi = -limit
    var ima = limit
    
    var xv = rmi + (rma - rmi) * Float32(x) / Float32(width)
    var yv = imi + (ima - imi) * Float32(y) / Float32(height)

    var z = ComplexFloat32(xv, yv)
    
    return _gen_pixel(z, code, consts)

def writePAM(image: List[UInt32], width : Int, height : Int, filename: String):
    try:
        with open(filename, "w") as f:
            f.write(t"P7\nWIDTH {width}\nHEIGHT {height}\nDEPTH 4\nMAXVAL 255\nTUPLTYPE RGB_ALPHA\nENDHDR\n")
            f.write_bytes(Span[UInt8](unsafe_ptr=image.unsafe_ptr().unsafe_bitcast[UInt8](), length=image.byte_length()))
    except:
        print(t"Error writing PAM file: {filename}")
    
#        
def test_dc() raises:
    var k = 2
    var w = 1024*k
    var h = 1024*k
    var expr = "(((((0.25/z)+sin(0.60))/tan((z-0.11)))-c(((z^0.92)/(1.00/0.21)),((i*0.71)-(0.86/i))))+c((sin(exp(0.66))^((i^z)/log(0.93))),asin(((0.79^0.02)*acos(0.10))))) "
    print(t"Domain Coloring {w} x {h}, {expr} ", end='')
    
    try:
        
        var res = dc_gpu.DomainColoringGPU(w, h, expr)   

        var image = res[0].copy()
        var lap = res[1]    
    
        writePAM(image, w, h, "dc.pam")   
        
        print(t", lap: {lap} ms, writing dc.pam", end=', ')

        print("done")
    except e:
        print(t"Error: {e}")
        return
    
    


def main() raises:  test_dc()
    