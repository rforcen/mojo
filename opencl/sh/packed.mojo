# simulate packed structs by offset
from std.sys.info import size_of

struct Packed[N:Int]:
    var data : Array[UInt8, Self.N]
    var offset : Int

    @always_inline
    def __init__(out self):
        self.data = Array[UInt8, Self.N](fill=0)
        self.offset = 0
        
    @always_inline
    def get_item(self, offset:Int) -> Pointer[UInt8]: return self.data.unsafe_ptr().unsafe_offset(offset)
        
    @always_inline
    def write[T:ImplicitlyCopyable](mut self, off:Int, value:T): self.get_item(off).unsafe_bitcast[T]().unsafe_write(value)
    
    @always_inline
    def write_array[NV:Int](mut self, off:Int, imm value:Array[UInt8,NV]): self.get_item(off).unsafe_bitcast[Array[UInt8,NV]]().unsafe_write(value.copy())

    @always_inline # reset offset = 0
    def span(mut self) -> Span[T=UInt8, origin=origin_of(self.data)]:
        self.offset=0
        return Span(self.data)
    
    @always_inline # resets offset to 0
    def span_toOffset(mut self) -> Span[T=UInt8, origin=origin_of(self.data)]:
        var offset = self.offset
        return self.span()[:offset]


    def length(self) -> Int: return Self.N

    @always_inline # no range check performed
    def append[T:ImplicitlyCopyable](mut self, value:T):   
        # if self.is_full(): raise Exception("Packed buffer is full")
        self.data.unsafe_ptr().unsafe_offset(self.offset).unsafe_bitcast[T]().unsafe_write(value)
        self.offset += size_of[T]()
    @always_inline
    def append_array[NV:Int](mut self, ref value:Array[UInt8,NV]):   
        # if self.is_full(): raise Exception("Packed buffer is full")
        self.data.unsafe_ptr().unsafe_offset(self.offset).unsafe_bitcast[Array[UInt8,NV]]().unsafe_write(value.copy())
        self.offset += NV
    @always_inline
    def is_full(self) -> Bool: return self.offset >= Self.N
    @always_inline
    def not_empty(self) -> Bool: return self.offset > 0

def main(): 
    var mesh = Packed[27]()
    mesh.write[UInt8](0, 1)
    print(mesh.span())