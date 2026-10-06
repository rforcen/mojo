# mandel gpu
from std.sys import has_accelerator
from std.gpu.primitives.id import block_dim, block_idx, thread_idx
from max.gpu.host import DeviceContext
#
from  std.testing.prop import Rng
from std.time import perf_counter
from file_palette import FirePalette

comptime UInt32Ptr = Pointer[UInt32, MutUnsafeAnyOrigin]
comptime u32 = DType.uint32

def Mandelbrot(width: Int, height:Int, iters:Int, center_re : Float64, center_im : Float64, radius : Float64, mut image : List[UInt32]) raises -> Int:
        
    # Kernel generates mandelbrot set using cardiod algo.
    def mandelbrot_kernel(
        image_ptr: UInt32Ptr,
        fire_palette_ptr: UInt32Ptr,

        center_re : Float64,
        center_im : Float64,
        rad : Float64,

        width: Int32,
        height: Int32,
        iters : Int32
    ):
        # image index
        var x = Int32((block_idx.x * block_dim.x) + thread_idx.x)
        var y = Int32((block_idx.y * block_dim.y) + thread_idx.y)
        var index = y * width + x

        # img in bounds?
        if x < width and y < height:       
            # scale item to complex plane
            def doScale(iw: Int32, jh: Int32) {imm width, imm height, imm rad, imm center_re, imm center_im} -> Tuple[Float64, Float64]:
                var aspect_ratio = Float64(width) / Float64(height)
                var real_part : Float64 = (Float64(iw) / Float64(width) - 0.5) * (2.0 * rad * aspect_ratio)
                var imag_part : Float64 = (Float64(jh) / Float64(height) - 0.5) * (2.0 * rad)

                return (real_part * aspect_ratio + center_re, imag_part * aspect_ratio + center_im)

            var (cr, ci) = doScale(index % width, index / width)     
            var zr = cr
            var zi = ci

            var ix = iters

            # Pre-calculate initial squares
            var zr2  = zr * zr
            var zi2  = zi * zi
            

            # optimized cardiod test
            var zr_minus_025 = zr - 0.25
            var q            = zr_minus_025 * zr_minus_025 + zi2

            if q * (q + zr_minus_025) < 0.25 * zi2:
                ix = iters
            elif (zr + 1.0) * (zr + 1.0) + zi2 < 0.0625:
                ix = iters
            else:
                # iterate -> it
                for it in range(iters):
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
                    if zr2 + zi2 > 4.0:
                        ix = it
                        break

            var color = 0xff000000 | (fire_palette_ptr.unsafe_offset((ix << 3) % 256)[] if ix != iters else 0)

            image_ptr.unsafe_offset(index).unsafe_write(color)

    # end of kernel
        
    if not has_accelerator():
        print("no GPU found")
        return 0
    else:          
       
        with DeviceContext() as ctx:     
            var FirePalette = materialize[FirePalette]()

            # gpu buffer with List length
            var buffer_img = ctx.enqueue_create_buffer[DType.uint32](len(image))
            var buffer_fire_palette = ctx.enqueue_create_buffer[DType.uint32](len(FirePalette))
            
            # copy to gpu
            ctx.enqueue_copy(buffer_img, image.unsafe_ptr())
            ctx.enqueue_copy(buffer_fire_palette, FirePalette.unsafe_ptr())

            # configure dimensions 2D (16x16 threads per block)
            comptime BLOCK_SIZE = 16
            var grid_x = (width + BLOCK_SIZE - 1) // BLOCK_SIZE
            var grid_y = (height + BLOCK_SIZE - 1) // BLOCK_SIZE

            var lap = perf_counter()
            # run kernel w/params
            ctx.enqueue_function[mandelbrot_kernel](
                buffer_img.unsafe_ptr(),
                buffer_fire_palette.unsafe_ptr(),

                center_re,
                center_im,
                radius,
                Int32(width),
                Int32(height),
                Int32(iters),
                
                grid_dim=(grid_x, grid_y),
                block_dim=(BLOCK_SIZE, BLOCK_SIZE),
            )
           

            # copy back to cpu            
            ctx.enqueue_copy(image.unsafe_ptr(), buffer_img)

            # wait for gpu to finish
            
            ctx.synchronize()
            lap = 1000*(perf_counter() - lap) # in ms

            return Int(lap)
        
def writePAM(image: List[UInt32], width : Int, height : Int, filename: String):
    try:
        with open(filename, "w") as f:
            f.write(t"P7\nWIDTH {width}\nHEIGHT {height}\nDEPTH 4\nMAXVAL 255\nTUPLTYPE RGB_ALPHA\nENDHDR\n")
            f.write_bytes(Span[UInt8](unsafe_ptr=image.unsafe_ptr().unsafe_bitcast[UInt8](), length=image.byte_length()))
    except:
        print("Error writing PAM file")
        

def test_mandel() raises:
    var k = 2
    var w = 1024*k
    var h = 1024*k
    var iters = 100

    var center_re = -0.5
    var center_im = 0.0
    var rad = 1.5

    var image = List[UInt32](length=w*h, fill=0)

    print(t"Mandelbrot {w} x {h} x {iters} ", end='')
    var lap = Mandelbrot(w, h, iters, center_re, center_im, rad, image)        
    
    print(t", lap: {lap} ms, writing mandel.pam")

    writePAM(image, w, h, "mandel.pam")
    

def main() raises:
    test_mandel()
    