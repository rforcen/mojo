# mojo wrapper to nc
from std.ffi import external_call

@fieldwise_init
struct NCDataType(ImplicitlyCopyable, ImplicitlyCopyable, Equatable):
    var value: Int
    # enum DataType { i8, i16, i32, i64, i128, f16, f32, f64, f80, f128, fmp };
    comptime no_type = NCDataType(-1)

    comptime i8 = NCDataType(0)
    comptime i16 = NCDataType(1)
    comptime i32 = NCDataType(2)
    comptime i64 = NCDataType(3)
    comptime i128 = NCDataType(4)
    comptime f16 = NCDataType(5)
    comptime f32 = NCDataType(6)
    comptime f64 = NCDataType(7)
    comptime f80 = NCDataType(8)
    comptime f128 = NCDataType(9)
    comptime fmp = NCDataType(10)

    comptime types = ["i8", "i16", "i32", "i64", "i128", "f16", "f32", "f64", "f80", "f128", "fmp"]

    def toString(self) -> String:
        var types = materialize[Self.types]()
        return types[self.value]
#
@fieldwise_init
struct Tensor(Writable):
    comptime VoidPtr = Optional[Pointer[NoneType, MutUntrackedOrigin]]
    comptime IntPtr = Optional[Pointer[Int, MutUntrackedOrigin]]

    var ptr: Self.VoidPtr
    var dtype: NCDataType
    var shape: List[Int]
    var ndim: Int

    def __init__(out self, dtype: NCDataType, shape: List[Int]):
        self.ptr = external_call["nc_new", Self.VoidPtr](dtype, len(shape), shape.unsafe_ptr())
        self.dtype = dtype
        self.shape = shape.copy()
        self.ndim = len(shape)

    def __init__(out self):
        self.ptr = None
        self.dtype = NCDataType.no_type
        self.shape = []
        self.ndim = 0
    
    def __init__(out self, span: Span[mut=True, T=Float64, origin=MutUnsafeAnyOrigin]):
        self.ptr = external_call["nc_new_from_span", Self.VoidPtr](span.unsafe_ptr(), len(span))
        self.dtype = NCDataType.f64
        self.shape = [len(span)]
        self.ndim = 1
        
    def __deinit__(deinit self):    external_call["nc_free", NoneType](self.ptr)

    def items(self) -> Int:
        var items = 1
        for i in range(self.ndim):
            items *= self.shape[i]
        return items
    def get_shape(self) -> List[Int]:
        return self.shape.copy()
    
    @staticmethod
    def identity(dtype: NCDataType, size: Int) -> Self:        
        return Self(external_call["nc_identity", Self.VoidPtr](dtype, size), dtype, [size, size], 2)

    @staticmethod
    def arange(dtype: NCDataType, shape: List[Int]) -> Self:        
        return Self(external_call["nc_arange", Self.VoidPtr](dtype, len(shape), shape.unsafe_ptr()), dtype, shape.copy(), len(shape))
        
    @staticmethod
    def fromString(dtype: NCDataType, sarr: String) -> Self:
        var pstr = sarr+"\0"
        return Self(external_call["nc_fromString", Self.VoidPtr](dtype, pstr.unsafe_ptr()), dtype, [], 0)
        
    def rand(mut self):             external_call["nc_rand", NoneType](self.ptr)
    @staticmethod
    def Rand(dtype:NCDataType, shape : List[Int]) -> Self:
        return Self(external_call["nc_random", Self.VoidPtr](dtype, len(shape), shape.unsafe_ptr()), dtype, shape.copy(), len(shape))
    def save(mut self, name: String):                    
        external_call["nc_save", NoneType](self.ptr, (name+"\0").unsafe_ptr())

    @staticmethod 
    def load(name: String) -> Self:                    
        var dtype = 0      
        var ndims = 0

        # load file -> dtype, ndims
        var ptr = external_call["nc_load", Self.VoidPtr]((name+"\0").unsafe_ptr(), Pointer(to=dtype), Pointer(to=ndims))
       
        var shape = List[Int](unsafe_uninit_length=ndims)
        _ = external_call["nc_getDims", NoneType](ptr, shape.unsafe_ptr())
        
        return Self(ptr, NCDataType(dtype), shape.copy(), ndims)

        
    def _print(self):            
        external_call["nc_print", NoneType](self.ptr)

    def to_string(self) -> String:
        var s = external_call["nc_to_string",Pointer[UInt8, MutUnsafeAnyOrigin]](self.ptr)
        var str = String(unsafe_from_utf8_ptr=s)
        return str
        
    def write_to(self, mut writer: Some[Writer]):  writer.write(self.to_string())

    def sum(self) -> Self:
        return Self(external_call["nc_sum", Self.VoidPtr](self.ptr), self.dtype, self.shape.copy(), self.ndim)
    
    def sum_all(self) -> Self:
        return Self(external_call["nc_sum_all", Self.VoidPtr](self.ptr), self.dtype, [1], 1)
    
    def getData[T:AnyType](self) -> Span[mut=True, T=T, origin=MutUnsafeAnyOrigin]:
        var data = external_call["nc_get_data", Pointer[T, MutUnsafeAnyOrigin]](self.ptr)
        return Span[mut=True, T=T, origin=MutUnsafeAnyOrigin](unsafe_ptr=data, length=external_call["nc_get_size", Int](self.ptr))
    
    def reshape(self, shape: List[Int]) -> Self:
        var nd = external_call["nc_reshape", Self.VoidPtr](self.ptr, len(shape), shape.unsafe_ptr())
        return Self(nd, self.dtype, shape.copy(), len(shape))

    # arithm.
    def __add__(self, other: Self) -> Self:
        var nd = external_call["nc_add", Self.VoidPtr](self.ptr, other.ptr)
        return Self(nd, self.dtype, self.shape.copy(), self.ndim)
    def __iadd__(self, other: Self):  external_call["nc_iadd", NoneType](self.ptr, other.ptr)
    def __sub__(self, other: Self) -> Self:
        var nd = external_call["nc_sub", Self.VoidPtr](self.ptr, other.ptr)
        return Self(nd, self.dtype, self.shape.copy(), self.ndim)
    def __isub__(self, other: Self):  external_call["nc_isub", NoneType](self.ptr, other.ptr)
    def __mul__(self, other: Self) -> Self:
        var nd = external_call["nc_mul", Self.VoidPtr](self.ptr, other.ptr)
        return Self(nd, self.dtype, self.shape.copy(), self.ndim)
    def __imul__(self, other: Self):  external_call["nc_imul", NoneType](self.ptr, other.ptr)
    def __truediv__(self, other: Self) -> Self:
        var nd = external_call["nc_div", Self.VoidPtr](self.ptr, other.ptr)
        return Self(nd, self.dtype, self.shape.copy(), self.ndim)
    def __itruediv__(self, other: Self):  external_call["nc_idiv", NoneType](self.ptr, other.ptr)
    
    #logic
    def __eq__(self, other: Self) -> Bool:  return  external_call["nc_eq", Bool](self.ptr, other.ptr)        
    def __ne__(self, other: Self) -> Bool:  return  external_call["nc_ne", Bool](self.ptr, other.ptr)

    def convert(self, new_type: NCDataType) -> Self:
        var nd = external_call["nc_convert", Self.VoidPtr](self.ptr, new_type)
        return Self(nd, new_type, self.shape.copy(), self.ndim)
    
    # linalg
    def det(self) -> Self:
        return Self(external_call["nc_det", Self.VoidPtr](self.ptr), self.dtype, self.shape.copy(), self.ndim)
    
    def inv(self) -> Self:
        return Self(external_call["nc_inv", Self.VoidPtr](self.ptr), self.dtype, self.shape.copy(), self.ndim)
    
    def dot(self, other: Self) -> Self:
        var nd = external_call["nc_dot", Self.VoidPtr](self.ptr, other.ptr)

        var ndims = external_call["nc_get_ndims", Int](nd)
        var shape = List[Int](unsafe_uninit_length=ndims)
        _ = external_call["nc_getDims", NoneType](nd, shape.unsafe_ptr())
        return Self(nd, self.dtype, shape.copy(), ndims)

    def apply(self, expr : String) -> Self:
        var nd = external_call["nc_apply", Self.VoidPtr](self.ptr, (expr+"\0").unsafe_ptr())
        return Self(nd, self.dtype, self.shape.copy(), self.ndim)
    def count(self, expr : String) -> Int:
        return external_call["nc_count", Int](self.ptr, (expr+"\0").unsafe_ptr())
    def filter(self, expr : String) -> Self:
        var nd = external_call["nc_filter", Self.VoidPtr](self.ptr, (expr+"\0").unsafe_ptr())
        var ndims = external_call["nc_get_ndims", Int](nd)
        var shape = List[Int](unsafe_uninit_length=ndims)        
        return Self(nd, self.dtype, shape.copy(), ndims)
    #
    def T(self) -> Self:
        var nd = external_call["nc_transpose", Self.VoidPtr](self.ptr)
        return Self(nd, self.dtype, self.shape.copy(), self.ndim)
    def sort(self) -> Self:
        var nd = external_call["nc_sort", Self.VoidPtr](self.ptr)
        return Self(nd, self.dtype, self.shape.copy(), self.ndim)
    def norm(self) -> Self:
        var nd = external_call["nc_norm", Self.VoidPtr](self.ptr)
        return Self(nd, self.dtype, self.shape.copy(), self.ndim)
    def round(self) -> Self:
        var nd = external_call["nc_round", Self.VoidPtr](self.ptr)
        return Self(nd, self.dtype, self.shape.copy(), self.ndim)
    def mean(self) -> Self:
        var nd = external_call["nc_mean", Self.VoidPtr](self.ptr)
        return Self(nd, self.dtype, self.shape.copy(), self.ndim)
    def max(self) -> Self:
        var nd = external_call["nc_max", Self.VoidPtr](self.ptr)
        return Self(nd, self.dtype, self.shape.copy(), self.ndim)
    def min(self) -> Self:
        var nd = external_call["nc_min", Self.VoidPtr](self.ptr)
        return Self(nd, self.dtype, self.shape.copy(), self.ndim)
    def stdev(self) -> Float64:
        return external_call["nc_stdev", Float64](self.ptr)
    def fill(self, v : Float64) -> Self:
        var nc = external_call["nc_fill", Self.VoidPtr](self.ptr, v)              
        return Self(nc, self.dtype, self.shape.copy(), self.ndim)
    def eps(self,  _eps : Float64) -> Self:
        var nd = external_call["nc_eps", Self.VoidPtr](self.ptr, _eps)
        return Self(nd, self.dtype, self.shape.copy(), self.ndim)
    
#
def test_all():
    var n = 5
    
    var nmat = Tensor(NCDataType.f32, [n,n])
    nmat.rand()
    print(nmat)
    nmat.save("nmat.npy")

    var l = Tensor.load("nmat.npy")
    print(l)
    print(l.det())
    
    var imat = Tensor.identity(NCDataType.f32, n)
    print(imat)

    var amat = Tensor.arange(NCDataType.f32, [n,n])
    print(amat)

    var smat = Tensor.fromString(NCDataType.f32, "1 2 3 4 5")
    print(smat)
    
    print("dtype:", NCDataType.f32.toString())

def test_linalg():
    var n = 600
    print(t"det {n}x{n}")
    var a = Tensor.Rand(NCDataType.f80, [n,n])    
    print(t"det: {a.det()}")

    print("inv")
    var ai = a.inv()
    print("dot")
    var ad = a.dot(ai)
    
    print(t"sum all:{ad.sum_all()}, n: {n}")   

def test_data():
    var n = 5
    var a = Tensor.Rand(NCDataType.f64, [n,n])
    var data = a.getData[Float64]()
    print(data)

    var b = Tensor(data)
    print(b)
    
    var c = a.reshape([n,n])
    print(c)
    
    print(a + c)
    
    a += c
    print(a)    
    
    print(a - c)
    
    a -= c
    print(a)
    
    print(a * c)
    
    a *= c
    print(a)
    
    print(a / c)
    
    a /= c
    print(a)
       
    print(a==c)
    print(a!=c)

    print(a.convert(NCDataType.f32))
    print(a.convert(NCDataType.f32).T())
    print(a.convert(NCDataType.f32)==a.convert(NCDataType.f32).T().T())
    
    print(a.fill(1.234), a.eps(2), b.sort())
    print("b:", b)
    print("sin(b):", b.apply("sin(x)"))

    print("-"*60)
    var expr = "(x > 0.1) & (x < 0.4)"
    print("mat   :", b)
    print("expr  :", expr)
    print("count :", b.count(expr))
    print("filter:", b.filter(expr))
    
    
def main():
    # test_all()
    # test_linalg()
    test_data()