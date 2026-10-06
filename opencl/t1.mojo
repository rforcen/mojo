from std.sys import has_accelerator
from std.sys.info import is_amd_gpu

from max.gpu.host import DeviceContext
from std.gpu.primitives.id  import block_dim, block_idx,thread_idx


def print_threads():
    """Print thread IDs."""
    # print(block_dim.x, block_dim.y, block_dim.z, end=", ")
    # print(block_idx.x, block_idx.y, block_idx.z, end=", ")
    print(block_dim.x, block_idx.x, thread_idx.x, end=", ")


def main() raises:
    comptime if not has_accelerator():
        print("No compatible GPU found")
    else:
        var ctx = DeviceContext()
        print("block\tthread")

        ctx.enqueue_function[print_threads](
            grid_dim=2, block_dim=8
        )
        ctx.synchronize()
        print("Program finished")