# File: mempool.mojo
# Author: robertoforcen@gmail.com
# Date: 2026-10-06
# Brief: Memory pool implementation using unsafe_alloc for dynamic allocation, with automatic cleanup
#        on deinit. 
#
from std.ffi import external_call
from std.sys.info import size_of
from std.memory.alloc import unsafe_alloc
#
struct MemPool: 
    comptime VoidPtr = Pointer[NoneType, MutUntrackedOrigin]
    var pool : List[Self.VoidPtr] # list to sotre alloc's
    var sz : Int # total allocated size

    def __init__(out self):
        self.pool = List[Self.VoidPtr]()
        self.sz = 0

    def __deinit__(deinit self): # release all saved alloc's        
        for p in self.pool: p.unsafe_free()
        # print("MemPool deinit, sz:", self.sz)

    # both new & newObj return an init T object
    def new[T:Defaultable & Copyable](mut self) -> Pointer[T, MutUntrackedOrigin]:        
        var p = unsafe_alloc[T](1) # alloc
        p.unsafe_write(T()) # init T
        self.pool.append(p.unsafe_bitcast[NoneType]()) # keep it for final release
        self.sz += size_of[T]()
        return p

    def newOpt[T:Defaultable & Copyable](mut self) -> Optional[Pointer[T, MutUntrackedOrigin]]:          
        return self.new[T]()

    def tic(self): pass # hold pool from gc

    @staticmethod
    def toOpt[T:Defaultable & Copyable](p: Pointer[T, MutUntrackedOrigin]) -> Optional[Pointer[T, MutUntrackedOrigin]]:
        return Optional[Pointer[T, MutUntrackedOrigin]](p)

