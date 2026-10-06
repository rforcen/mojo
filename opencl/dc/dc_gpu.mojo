# DomainColoring gpu

from std.sys import has_accelerator
from std.gpu.primitives.id import block_dim, block_idx, thread_idx
from max.gpu.host import DeviceContext, HostBuffer
from std.sys.info import size_of
#
from std.time import perf_counter
#
from dc import gen_pixel, UInt32Ptr, Float32Ptr
from zcompiler import ZCompiler
#

def DomainColoringGPU(width: Int, height:Int, expr : String) raises -> Tuple[List[UInt32], Int]:
        
    # DC Kernel -> image
    def dc_kernel(
        image_ptr: UInt32Ptr,

        code : UInt32Ptr,
        consts : Float32Ptr,        
        
        width: Int32,
        height: Int32,        
    ):
        # image index
        var x = Int32((block_idx.x * block_dim.x) + thread_idx.x)
        var y = Int32((block_idx.y * block_dim.y) + thread_idx.y)
        var index = y * width + x


        # img in bounds?
        if x < width and y < height:       
            var color = gen_pixel(x, y, width, height, code, consts)
            image_ptr.unsafe_offset(index).unsafe_write(color)

    # end of kernel
        
    if not has_accelerator():
        raise Error("no GPU found")
    else:          
       
        with DeviceContext() as ctx:                 
            var zc = ZCompiler(expr)            

            if zc.has_errors(): raise Error(t"ZCompiler error: {zc.err_msg}")

            var image = List[UInt32](length=width * height, fill=0)

            # gpu buffer with List length
            var buffer_img    = ctx.enqueue_create_buffer[DType.uint32](len(image))
            var buffer_code   = ctx.enqueue_create_buffer[DType.uint32](len(zc.code))
            var buffer_consts = ctx.enqueue_create_buffer[DType.float32](len(zc.consts))            
            
            # copy to gpu
            ctx.enqueue_copy(buffer_img, image.unsafe_ptr())
            ctx.enqueue_copy(buffer_code, zc.code.unsafe_ptr())
            ctx.enqueue_copy(buffer_consts, zc.consts.unsafe_ptr())            

            # configure dimensions 2D (16x16 threads per block)
            comptime BLOCK_SIZE = 16
            var grid_x = (width + BLOCK_SIZE - 1) // BLOCK_SIZE
            var grid_y = (height + BLOCK_SIZE - 1) // BLOCK_SIZE

            var lap = perf_counter()
            # run kernel w/params
            ctx.enqueue_function[dc_kernel](
                buffer_img.unsafe_ptr(),

                buffer_code.unsafe_ptr(),
                buffer_consts.unsafe_ptr(),
                
                Int32(width),
                Int32(height),            
                
                grid_dim=(grid_x, grid_y),
                block_dim=(BLOCK_SIZE, BLOCK_SIZE),
            )         

            # copy back image to cpu            
            ctx.enqueue_copy(image.unsafe_ptr(), buffer_img)

            # wait for gpu to finish            
            ctx.synchronize()
            lap = 1000*(perf_counter() - lap) # in ms

            return (image^, Int(lap))
#

def main(): pass