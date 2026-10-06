# File: mempool.mojo
# Author: robertoforcen@gmail.com
# Date: 2026-10-06
# Brief: Memory pool implementation using calloc for dynamic allocation, with automatic cleanup
#        on deinit. Includes a pure Mojo version with fixed-size pre-allocation.
#
from std.ffi import external_call
from std.sys.info import size_of
from std.memory.alloc import alloc, dealloc, Layout, Allocation

# using calloc & free std
comptime c_calloc = "calloc"
comptime c_free = "free"
#

struct MemPool: # calloc based
    comptime VoidPtr = Pointer[NoneType, MutUntrackedOrigin]
    var pool : List[Self.VoidPtr] # list to sotre alloc's
    var sz : Int # total allocated size

    def __init__(out self):
        self.pool = List[Self.VoidPtr]()
        self.sz = 0

    def __deinit__(deinit self): # release all saved alloc's        
        for p in self.pool: _ = external_call[c_free, NoneType](p)
        # print("MemPool deinit, sz:", self.sz)

    # both new & newObj return an init T object
    def new[T:Defaultable & Copyable & Writable](mut self) -> Pointer[T, MutUntrackedOrigin]:        
        var p = external_call[c_calloc, Pointer[T, MutUntrackedOrigin]](UInt64(size_of[T]()), UInt64(1)) # calloc
        p.unsafe_write(T()) # init T
        self.pool.append(p.unsafe_origin_cast[MutUntrackedOrigin]().unsafe_bitcast[NoneType]()) # keep it for final release
        self.sz += size_of[T]()
        return p

    def newOpt[T:Defaultable & Copyable & Writable](mut self) -> Optional[Pointer[T, MutUntrackedOrigin]]:          
        return self.new[T]()

    def tic(self): pass # hold pool from gc

    @staticmethod
    def toOpt[T:Defaultable & Copyable & Writable](p: Pointer[T, MutUntrackedOrigin]) -> Optional[Pointer[T, MutUntrackedOrigin]]:
        return Optional[Pointer[T, MutUntrackedOrigin]](p)

# pure mojo version but requires fixed memory size at creation, NOT DYNAMIC as calloc

struct MemPool_mojo(Deinitable):
    var layout : Layout[UInt8]
    var allocation : Allocation[UInt8]    
    var cnt : Int

    def __init__(out self, count : Int = 10_000):
        self.layout = Layout[UInt8](count=count)
        self.allocation = alloc(self.layout)    
        self.cnt = 0

    def __init__(out self, radius : Float32): # waterman radius based init
        self.layout = Layout[UInt8](count = MemPool_mojo.waterman_required(radius))
        self.allocation = alloc(self.layout)    
        self.cnt = 0

    def __deinit__(deinit self):
        dealloc(self.allocation^)

    # memory required for radius R waterman polyhedron, 
    # M(R) = 98 R^3 + 680 R^2 + 10,000 R
    @staticmethod
    def waterman_required(r: Float32) -> Int: return Int(98 * r**3 + 680 * r**2 + 10000 * r)

    def new[T:Defaultable & ImplicitlyCopyable & Writable](mut self, val : T) raises -> Optional[Pointer[T, MutUntrackedOrigin]]:
        var size = size_of[T]()

        if self.cnt + size > self.layout.count(): 
            raise Error("\n\n*** mem arena, new: not enough space ***\n")
        
        var p = self.allocation.unsafe_ptr().unsafe_offset(self.cnt).unsafe_origin_cast[MutUntrackedOrigin]().unsafe_bitcast[T]()
        p.unsafe_write(val)

        self.cnt += size
        return p

    def getFree(self) -> Int: return self.layout.count() - self.cnt
