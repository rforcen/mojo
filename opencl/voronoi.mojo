# voronoi tiles gpu
from std.sys import has_accelerator
from std.gpu.primitives.id import block_dim, block_idx, thread_idx
from max.gpu.host import DeviceContext
#
from  std.testing.prop import Rng
from std.time import perf_counter

comptime UInt32Ptr = Pointer[UInt32, MutUnsafeAnyOrigin]

def Voronoi(width: Int, height:Int, n_points:Int, mut image : List[UInt32]) raises -> Int:
        
    # Kernel generates voronoi tiles
    def voronoi_kernel(
        image_ptr: UInt32Ptr,

        point_x_ptr: UInt32Ptr,
        point_y_ptr: UInt32Ptr,
        color_ptr: UInt32Ptr,
        n_points: Int32,

        width: Int32,
        height: Int32,
    ):
        var x = Int32((block_idx.x * block_dim.x) + thread_idx.x)
        var y = Int32((block_idx.y * block_dim.y) + thread_idx.y)

        # img in bounds
        if x < width and y < height:

            @always_inline
            def dist2(x2: UInt32, y2: UInt32) {imm x, imm y} -> Float32:
                var dx = UInt32(x) - x2
                var dy = UInt32(y) - y2
                return Float32(dx * dx + dy * dy)
            @always_inline
            def px(i:Int32) {imm point_x_ptr} -> UInt32:  return point_x_ptr.unsafe_offset(i)[]
            @always_inline
            def py(i:Int32) {imm point_y_ptr} -> UInt32:  return point_y_ptr.unsafe_offset(i)[]

            var color : UInt32 = 0xff00_0000
            var dist : Float32 = dist2(px(0), py(0))

            for i in range(Int32(1), n_points):
                var d = dist2(px(i), py(i))
                
                if d < 4: # black central point
                    color = 0xff00_0000
                    break
                elif d < dist:
                    dist = d
                    color = color_ptr.unsafe_offset(i)[]
            
            var idx = y * width + x
            image_ptr.unsafe_offset(idx).unsafe_write(color)        

        
    if not has_accelerator():
        print("no GPU found")
        return 0
    else:          
        var point_x = List[UInt32](length=n_points, fill=0)
        var point_y = List[UInt32](length=n_points, fill=0)
        var color = List[UInt32](length=n_points, fill=0xff00_0000)

        # fill points w/random values in range
        var rng = Rng(seed=Int(perf_counter()))
        for i in range(n_points):
            point_x[i] = UInt32(rng.rand_int(min=0, max=width-1))
            point_y[i] = UInt32(rng.rand_int(min=0, max=height-1))
            color[i] = 0xff00_0000 | UInt32(rng.rand_int(min=0, max=0x00ff_ffff))

        with DeviceContext() as ctx:     
            # gpu buffer with List length
            var buffer_img = ctx.enqueue_create_buffer[DType.uint32](len(image))
            var buffer_points_x = ctx.enqueue_create_buffer[DType.uint32](len(point_x))
            var buffer_points_y = ctx.enqueue_create_buffer[DType.uint32](len(point_y))
            var buffer_colors = ctx.enqueue_create_buffer[DType.uint32](len(color))
            
            # copy to gpu
            ctx.enqueue_copy(buffer_img, image.unsafe_ptr())
            ctx.enqueue_copy(buffer_points_x, point_x.unsafe_ptr())
            ctx.enqueue_copy(buffer_points_y, point_y.unsafe_ptr())
            ctx.enqueue_copy(buffer_colors, color.unsafe_ptr())

            # configure dimensions 2D (16x16 threads per block)
            comptime BLOCK_SIZE = 16
            var grid_x = (width + BLOCK_SIZE - 1) // BLOCK_SIZE
            var grid_y = (height + BLOCK_SIZE - 1) // BLOCK_SIZE

            var lap = perf_counter()
            # run kernel w/params
            ctx.enqueue_function[voronoi_kernel](
                buffer_img.unsafe_ptr(),
                buffer_points_x.unsafe_ptr(),
                buffer_points_y.unsafe_ptr(),
                buffer_colors.unsafe_ptr(),
                Int32(len(point_x)),
                Int32(width),
                Int32(height),
                
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
        

def main() raises:
    var k = 2
    var w = 1024*k
    var h = 1024*k
    var n_points=1000

    var image = List[UInt32](length=w * h, fill=0)

    print(t"Voronoi {w} x {h} x {n_points} ", end='')
    var lap = Voronoi(w, h, n_points, image)        
    
    print(t", lap: {lap} ms, writing voronoi.pam")

    writePAM(image, w, h, "voronoi.pam")
    
