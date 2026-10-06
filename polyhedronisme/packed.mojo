# simulate packed structs by offset

struct Packed[N:Int]:
    var data : Array[UInt8, Self.N]

    @always_inline
    def __init__(out self):
        self.data = Array[UInt8, Self.N](fill=0)
        
    @always_inline
    def write[T:ImplicitlyCopyable](mut self, off:Int, value:T):   
        self.data.unsafe_ptr().unsafe_offset(off).unsafe_bitcast[T]().unsafe_write(value)

    @always_inline
    def write_array[NV:Int](mut self, off:Int, ref value:Array[UInt8,NV]):   
        self.data.unsafe_ptr().unsafe_offset(off).unsafe_bitcast[Array[UInt8,NV]]().unsafe_write(value.copy())

    @always_inline
    def span(ref self) -> Span[T=UInt8, origin=origin_of(self.data)]:
        return Span[T=UInt8, origin=origin_of(self.data)](self.data)

def main(): 
    var mesh = Packed[27]()
    mesh.write[UInt8](0, 1)
    print(mesh.span())