# basic fast access, unchecked vector

from std.memory import alloc, Layout, dealloc, unsafe_destroy_n
from std.sys import size_of

struct Vector[T: Movable & Writable & ImplicitlyCopyable ,  /](Sized, Writable, ImplicitlyCopyable):
    comptime _PointerType = Pointer[Self.T, MutUntrackedOrigin]

    var _data: Self._PointerType    
    var _len: Int
    # var _span : Span[Self.T, MutUntrackedOrigin]

    @always_inline
    def __init__(out self, len : Int):
        self._data = alloc(Layout[Self.T](count=len)).unsafe_leak()
        self._len = len
        # self._span = Span[Self.T](unsafe_ptr = self._data, length = self._len)

    def __deinit__(deinit self):
        self._data.unsafe_free()
        # self._len = 0
    
    @always_inline
    def set(self, index: Int, var value: Self.T) -> None:        self._data.unsafe_offset(index).unsafe_write(value^)
    @always_inline
    def __setitem__(self, index: Int, var value: Self.T) -> None:  self._data.unsafe_offset(index).unsafe_write(value^)

    @always_inline
    def get(self, index: Int) -> ref [self._data] Self.T:  return self._data.unsafe_offset(index)[]
    
    @always_inline
    def __getitem__(self, index: Int) -> ref [self._data] Self.T:  return self._data.unsafe_offset(index)[]
    @always_inline
    def __len__(self) -> Int:  return self._len
    @always_inline
    def size_in_bytes(self) -> Int: return self._len * size_of[self.T]()

    @always_inline
    def unsafe_ptr(self) -> Self._PointerType:  return self._data
    @always_inline
    def unsafe_ptr_as_int(self) -> Int:  return Int(self._data)

    def copy(self) -> Self:
        var v = Vector[self.T](self._len)
        for i in range(self._len):
            v[i] = self[i]
        return v^

    # def get_span(self) -> Span[Self.T, MutUntrackedOrigin]:
    #     return self._span

    def write_to(self, mut writer: Some[Writer]):
        writer.write("Vector[", self._len, "](")
        for i in range(self._len):
            writer.write(self[i])
            if i < self._len - 1:
                writer.write(", ")
        writer.write(")")

def main() : 
    var v0 : Vector[Int]

    v0 = Vector[Int](100)
    v0[40]=999
    print("v0[40]=", v0[40])


    var v = Vector[Int](60)
    print("v._data=", v._data)
    
    v[0] = 42
    v[1] = 55
    v[30] = 77
    v[len(v)-1] = 99

    print("v[0]=", v[0])
    print(v.get(0), v0.get(40), v0.get(50))
    print("v._data=", v._data)
    # print(v.get_span()[0], v.get_span()[40], v.get_span()[50])
    for i in range(len(v)): print(t"{i}:{v[i]}", end=', ')
    print()