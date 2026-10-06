# MP mandel

from mp import BigFloat, ComplexMP
from std.complex import ComplexFloat64
from file_palette import FirePalette
from max.algorithm import parallelize
from std.sys.info import num_logical_cores
from std.math import ceildiv

comptime N_POINTS_SAMPLE = 16
comptime ESCAPE_VAL = 1e20

@always_inline
def sqr(x: Float64) -> Float64:
    return x * x


# creating a struct to hold the reference data and diffs 
# is much faster that including them as attrb in MandelbrotMP
struct ReferenceTuple:
    var ref_cmplx: List[ComplexFloat64]
    var diff_x: List[Float64]
    var diff_y: List[Float64]

    def __init__(out self, w : Int, h: Int):
        self.ref_cmplx = List[ComplexFloat64](length=0, fill=ComplexFloat64(0.0, 0.0))
        self.diff_x = List[Float64](length=w, fill=0.0)
        self.diff_y = List[Float64](length=h, fill=0.0)

struct MandelbrotMP:
    var width: Int
    var height: Int
    var iters: Int
    var size: Int
    var center: ComplexMP
    var rad: BigFloat
    var aspect_ratio: BigFloat
    var bf_w: BigFloat
    var bf_h: BigFloat
    var image: List[UInt32]
    var firePalette: Array[UInt32, 256]

    def __init__(out self, w : Int, h : Int, iters : Int, var center : ComplexMP, var rad : BigFloat):
        self.width = w
        self.height = h
        self.iters = iters
        self.size = w * h
        self.center = center^
        self.rad = rad^

        self.aspect_ratio = BigFloat(w) / BigFloat(h)
        self.bf_w = BigFloat(w)
        self.bf_h = BigFloat(h)
        self.image = List[UInt32](length=w*h, fill=0xff000000)
        self.firePalette = materialize[FirePalette]()
    
    def dump(self):
        print("width:", self.width)
        print("height:", self.height)
        print("iters:", self.iters)
        print("size:", self.size)
        print("center:", self.center)
        print("rad:", self.rad)
        print("aspect_ratio:", self.aspect_ratio)
        print("bf_w:", self.bf_w)
        print("bf_h:", self.bf_h)
    
    def doScale(self, iw: Int, jh: Int) -> ComplexMP:
        var real_part: BigFloat = (BigFloat(iw) / self.bf_w - BigFloat(0.5)) * (BigFloat(2.0) * self.rad * self.aspect_ratio)
        var imag_part: BigFloat = (BigFloat(jh) / self.bf_h - BigFloat(0.5)) * (BigFloat(2.0) * self.rad)
        return self.center + ComplexMP(real_part^, imag_part^)
    
    def genPixel(mut self, index: Int):
        """Generate a single pixel store in self.image."""
        var ix = self.iters
        var z: ComplexMP = self.doScale(index % self.width, index / self.width)

		# extract components before loop
        var cr: BigFloat = BigFloat(z.real)
        var ci: BigFloat = BigFloat(z.imag)

        var zr: BigFloat = BigFloat(z.real)
        var zi: BigFloat = BigFloat(z.imag)


		# Pre-calculate initial squares
        var zr2: BigFloat = zr * zr
        var zi2: BigFloat = zi * zi


		# optimized cardiod test
        var zr_minus_025: BigFloat = zr - BigFloat(0.25)
        var q: BigFloat = zr_minus_025 * zr_minus_025 + zi2

        if (q * (q + zr_minus_025) < BigFloat(0.25) * zi2):		
            ix = self.iters
        elif ((zr + BigFloat(1.0)) * (zr + BigFloat(1.0)) + zi2 < BigFloat(0.0625)):
            ix = self.iters
        else:
            # iterate -> it
            for it in range(self.iters):
            
                # z = z^2 + c  =>  (zr + i*zi)^2 + (cr + i*ci)
                # zr_new = zr^2 - zi^2 + cr
                # zi_new = 2 * zr * zi + ci

                # Use a temporary variable to avoid overwriting zr before calculating
                # zi
                zi = (zr + zr) * zi + ci
                zr = zr2 - zi2 + cr

                # Update squares for next iteration and escape condition
                zr2 = zr * zr
                zi2 = zi * zi

                # Escape condition: zr^2 + zi^2 > 4.0
                if (zr2 + zi2 > BigFloat(4.0)):
                    ix = it
                    break

        self.image[index] = 0xff000000 | (0 if (ix == self.iters) else self.firePalette[(ix << 3) % len(self.firePalette)])
    
    
    def find_best_pos(self, npnts: Int) -> ComplexMP:
        """Find the best position to center the mandelbrot set."""
        def test_orbit_depth(c: ComplexMP, max_iters: Int) -> Int:
            var z = ComplexMP(0.0, 0.0)
            var escape = BigFloat(ESCAPE_VAL)

            for i in range(max_iters):
                z = z * z + c # z = z^2 + c
                if (z.norm() > escape): return i # check escape condition

            return max_iters # deep black point (black) or very deep

        var best_pos = ComplexMP(self.center)

        var max_found_it: Int = -1

        for y in range(npnts):
            var pos = self.doScale(y * self.width / (npnts - 1), y * self.height / (npnts - 1))

            var it = test_orbit_depth(pos, self.iters)
            if (it > max_found_it):
                max_found_it = it
                best_pos = ComplexMP(pos)

        return best_pos^

    def calcReferences(self, position: ComplexMP) -> List[ComplexFloat64]:
        """Calculate the references for the mandelbrot set."""
        var refs = List[ComplexFloat64](length=self.iters, fill=ComplexFloat64(0.0, 0.0))

        var z = ComplexMP(0.0, 0.0)
        var escape = BigFloat(ESCAPE_VAL)

        for it in range(self.iters):
            refs[it] = z.to_complex()
            z = z * z + position # z = z^2 + c

            # check escape condition
            if (z.norm() > escape): break
        return refs^

    def gen_references(self) -> ReferenceTuple:
        var refs = ReferenceTuple(self.width, self.height)        
        
        var best_pos: ComplexMP = self.find_best_pos(N_POINTS_SAMPLE)
        refs.ref_cmplx = self.calcReferences(best_pos)

        var sx: BigFloat = BigFloat(2) * self.rad * self.aspect_ratio / BigFloat(self.width)
        var sy: BigFloat = BigFloat(2) * self.rad / BigFloat(self.height)
        var ox: BigFloat = self.center.real - (self.rad * self.aspect_ratio)
        var oy: BigFloat = self.center.imag - self.rad

        for iw in range(self.width): refs.diff_x[iw] = ((BigFloat(iw) * sx + ox) - best_pos.real).to_double()
        for jh in range(self.height): refs.diff_y[jh] = ((BigFloat(jh) * sy + oy) - best_pos.imag).to_double()

        return refs^
    
    def render_pixel(mut self, x: Int, y: Int, refs: ReferenceTuple):
        """Render a single pixel using the references."""
        var i = y * self.width + x
        var rSize = len(refs.ref_cmplx)

        var dzx = 0.0
        var dzy = 0.0

        var final_it = self.iters

        var cur_ref_re = refs.ref_cmplx[0].re
        var cur_ref_im = refs.ref_cmplx[0].im

        for it in range(rSize-1):
	
            var tr_z = 2.0 * cur_ref_re + dzx
            var ti_z = 2.0 * cur_ref_im + dzy

            var next_dzx = dzx * tr_z - dzy * ti_z + refs.diff_x[x]
            var next_dzy = dzx * ti_z + dzy * tr_z + refs.diff_y[y]
           
            dzx = next_dzx
            dzy = next_dzy

            cur_ref_re = refs.ref_cmplx[it + 1].re
            cur_ref_im = refs.ref_cmplx[it + 1].im

            var tr_pixel = cur_ref_re + dzx
            var ti_pixel = cur_ref_im + dzy

            if (sqr(tr_pixel) + sqr(ti_pixel) > 4.0):
                final_it = it + 1
                break

        if final_it != self.iters:
            self.image[i] = 0xff000000 | self.firePalette[(final_it << 3) % len(self.firePalette)]

    def genImageST(mut self):
        """Generate the image using single thread."""
        var refs = self.gen_references()
        
        for y in range(self.height):
            for x in range(self.width):
                self.render_pixel(x, y, refs)

    def renderMT(mut self):
        """Generate the image using multiple threads."""   
        var num_cores = num_logical_cores()
        var chunk_size = ceildiv(self.size, num_cores)
        var refs = self.gen_references()

        def thread_fn(thId: Int){ mut self, imm chunk_size, imm refs}:
            var start = thId * chunk_size
            var end = min(start + chunk_size, self.size)
            for idx in range(end - start):
                var index = start + idx
                self.render_pixel(index % self.width, index / self.width, refs)

        parallelize(thread_fn, num_cores)

    def writePAM(self, filename: String):
        """Write the image to a PAM file."""
        try:
            with open(filename, "w") as f:
                f.write(t"P7\nWIDTH {self.width}\nHEIGHT {self.height}\nDEPTH 4\nMAXVAL 255\nTUPLTYPE RGB_ALPHA\nENDHDR\n")
                f.write_bytes(Span[UInt8](unsafe_ptr=self.image.unsafe_ptr().unsafe_bitcast[UInt8](), length=self.image.byte_length()))
        except:
            print("Error writing PAM file")

