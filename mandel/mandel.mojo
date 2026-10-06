# mandelbrot set

from std.complex import ComplexFloat64, ComplexSIMD
from max.algorithm import parallelize
from std.sys.info import num_logical_cores
from std.math import ceildiv
from file_palette import FirePalette

# simd defs for avx-512
comptime simd_length = 4 # 512 bits / 8 bits per byte / 8 bytes per f64 / 2 f64 per complex (re, im)

comptime simd_f64 = SIMD[DType.float64, simd_length]
comptime simd_int = SIMD[DType.int, simd_length]
comptime simd_bool = SIMD[DType.bool, simd_length]
comptime simd_c64 = ComplexSIMD[DType.float64, simd_length]

#

struct Mandel:
    var w : Int
    var h : Int
    var size : Int
    var iters : Int
    var aspect_ratio : Float64

    var rad : Float64
    var center : ComplexFloat64

    var image : List[UInt32]
    var firePalette : Array[UInt32, 256]

    # simd
    var center_sd : simd_c64
    var rad_sd : simd_f64
    var aspect_ratio_sd : simd_f64

    def __init__(out self, w: Int, h: Int, iters: Int, rad: Float64, center: ComplexFloat64):
        self.w = w
        self.h = h
        self.iters = iters
        self.rad = rad
        self.center = center

        self.size = w * h        
        self.aspect_ratio = Float64(w) / Float64(h)
        
        self.image = List[UInt32](length=w*h, fill=0xff000000)
        self.firePalette = materialize[FirePalette]()

        self.center_sd = simd_c64(self.center.re, self.center.im)
        self.rad_sd = simd_f64(self.rad)
        self.aspect_ratio_sd = simd_f64(self.aspect_ratio)


    def reset(mut self):
        self.image = List[UInt32](length=self.w*self.h, fill=0xff000000)

    @always_inline
    def doScale(self, iw: Int, jh: Int) -> ComplexFloat64:
        var real_part : Float64 = (Float64(iw) / Float64(self.w) - 0.5) * (2.0 * self.rad * self.aspect_ratio)
        var imag_part : Float64 = (Float64(jh) / Float64(self.h) - 0.5) * (2.0 * self.rad)

        return ComplexFloat64(real_part * self.aspect_ratio + self.center.re, imag_part * self.aspect_ratio + self.center.im)
    
    @always_inline
    def doScaleSIMD(self, iw: Int, jh: Int) -> simd_c64:
        var real_part : simd_f64 = (simd_f64(Float64(iw)) / simd_f64(Float64(self.w)) - 0.5) * (2.0 * self.rad * self.aspect_ratio)
        var imag_part : simd_f64 = (simd_f64(Float64(jh)) / simd_f64(Float64(self.h)) - 0.5) * (2.0 * self.rad)

        return simd_c64(real_part * self.aspect_ratio_sd + self.center_sd.re, imag_part * self.aspect_ratio_sd + self.center_sd.im)

    def genPixelSIMD_slow(mut self, index: Int):
        var c0 = self.doScaleSIMD(index % self.w, index / self.w)
        var z = c0
        
        var ix = simd_int(0)
        var max_iters = simd_int(self.iters)
        var active = simd_bool(fill=True) 

        while active.reduce_or():
            z = z.squared_add(c0)

            var not_escaped = z.norm().le(4.0)
            var under_max = ix.lt(max_iters)
            
            active = not_escaped & under_max
           
            ix = active.select(ix + 1, ix)

        for i in range(4):
            if ix[i] != self.iters:
                self.image[index + i] = UInt32(0xff000000) | self.firePalette[(Int(ix[i]) << 3) % len(self.firePalette)]

    @always_inline
    def genPixelSIMD(mut self, index: Int):
        var c0 = self.doScaleSIMD(index % self.w, index / self.w)
        
        var zr: SIMD[DType.float64, 4] = c0.re
        var zi: SIMD[DType.float64, 4] = c0.im

        var zr2 = zr * zr
        var zi2 = zi * zi

        # Constantes SIMD explícitas
        var v_025   = SIMD[DType.float64, 4](0.25)
        var v_10    = SIMD[DType.float64, 4](1.0)
        var v_00625 = SIMD[DType.float64, 4](0.0625)
        var v_four  = SIMD[DType.float64, 4](4.0)

        # 1. Test del Cardioide y Bulbo usando .lt()
        var zr_minus_025 = zr - v_025
        var q = zr_minus_025 * zr_minus_025 + zi2

        var in_cardioid = (q * (q + zr_minus_025)).lt(v_025 * zi2)
        var in_bulb     = ((zr + v_10) * (zr + v_10) + zi2).lt(v_00625)

        var in_main_set = in_cardioid | in_bulb
        var active      = ~in_main_set

        var ix = SIMD[DType.int, 4](self.iters)

        # 2. Bucle principal SIMD con reduce_or()[0]
        if active.reduce_or()[0]:
            ix = active.select(SIMD[DType.int, 4](0), ix)
            var max_iters = SIMD[DType.int, 4](self.iters)

            while active.reduce_or()[0]:
                zi = (zr + zr) * zi + c0.im
                zr = zr2 - zi2 + c0.re

                zr2 = zr * zr
                zi2 = zi * zi

                # Evaluaciones de escape y límite de iteraciones
                var not_escaped = (zr2 + zi2).le(v_four)
                var under_max   = ix.lt(max_iters)

                active = not_escaped & under_max
                ix = active.select(ix + 1, ix)

        # 3. Escritura de resultados en memoria
        for i in range(4):
            if ix[i] != self.iters:
                self.image[index + i] = UInt32(0xff000000) | self.firePalette[(Int(ix[i]) << 3) % len(self.firePalette)]

    def genImageST_SIMD(mut self):
        for i in range(0, self.size, 4):
            self.genPixelSIMD(i)

    def genImageMT_SIMD(mut mandel):
        var num_cores = num_logical_cores()
        var chunk_size = ceildiv(mandel.size, num_cores)

        def thread_fn(thId: Int){ mut mandel, imm chunk_size}:
            var start = thId * chunk_size
            var end = min(start + chunk_size, mandel.size)
            for idx in range(start, end, 4):
                mandel.genPixelSIMD(idx)

        parallelize(thread_fn, num_cores)

    def genPixelSlow(mut self, index : Int):
        var c0 = self.doScale(index % self.w, index / self.w)
        var z  = c0

        for ix in range(self.iters):
            z = z.squared_add(c0)
            if z.norm() > 4.0:
                self.image[index] = 0xff000000 | self.firePalette[(ix << 3) % len(self.firePalette)]
                break

    def genImageST_Slow(mut self):
        for i in range(self.size):
            self.genPixelSlow(i)

    @always_inline
    def genPixel(mut self, index: Int):
        var c0 = self.doScale(index % self.w, index / self.w)
        var z  = c0

        # extract components before loop
        var cr = c0.re
        var ci = c0.im

        var zr = z.re
        var zi = z.im

        var ix = self.iters

        # Pre-calculate initial squares
        var zr2  = zr * zr
        var zi2  = zi * zi
        var four = 4.0

        # optimized cardiod test
        var zr_minus_025 = zr - 0.25
        var q            = zr_minus_025 * zr_minus_025 + zi2

        if q * (q + zr_minus_025) < 0.25 * zi2:
            ix = self.iters
        elif (zr + 1.0) * (zr + 1.0) + zi2 < 0.0625:
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
                if zr2 + zi2 > four:
                    ix = it
                    break

        if ix != self.iters:
            self.image[index] = 0xff000000 | self.firePalette[(ix << 3) % len(self.firePalette)]



    def genImageST(mut self):
        for i in range(self.size):
            self.genPixel(i)

    def genImageMT(mut mandel):
        var num_cores = num_logical_cores()
        var chunk_size = ceildiv(mandel.size, num_cores)

        def thread_fn(thId: Int){ mut mandel, imm chunk_size}:
            var start = thId * chunk_size
            var end = min(start + chunk_size, mandel.size)
            for idx in range(start, end):
                mandel.genPixel(idx)

        parallelize(thread_fn, num_cores)

    def writePAM(mut self, filename: String):
        try:
            with open(filename, "w") as f:
                f.write(t"P7\nWIDTH {self.w}\nHEIGHT {self.h}\nDEPTH 4\nMAXVAL 255\nTUPLTYPE RGB_ALPHA\nENDHDR\n")
                f.write_bytes(Span[UInt8](unsafe_ptr=self.image.unsafe_ptr().unsafe_bitcast[UInt8](), length=self.image.byte_length()))
        except:
            print("Error writing PAM file")
        
from std.time import perf_counter

def main():
    var w = 2048
    var h = 2048
    var iters = 100
    
    var mandel = Mandel(w, h, iters, 1.5, ComplexFloat64(-0.5, 0.0))
    var start = perf_counter()
    mandel.genImageMT_SIMD()
    var end = perf_counter()
    print(t"MT: {w}x{h}x{iters}, lap: {Int(1000*(end - start))} ms")
    mandel.writePAM("mandel.pam")
    
    start = perf_counter()
    mandel.genImageST_SIMD()
    end = perf_counter()
    print(t"ST: {w}x{h}x{iters}, lap: {Int(1000*(end - start))} ms")
    # mandel.writePAM("mandel.pam")
