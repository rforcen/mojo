# gmp wrapper
# call are performed using external_call so gmp must be linked from command line
# using fixed absolute path

# mojo build mp.mojo -Xlinker /usr/lib/x86_64-linux-gnu/libgmp.so

from std.ffi import external_call, OwnedDLHandle, c_char, c_double, c_long, c_int, CStringSlice
from std.sys.info import platform_map
from std.complex import ComplexFloat64

#comptime LIBGMP = platform_map["libgmp", linux="libgmp.so", macos="libgmp.dylib"]()
comptime SIZE_OF_MPZ = 24 # current sizeof(mpz_t)
comptime PRECISION = 15

@fieldwise_init # basic gmp support struct opaqued
struct MPZ(Copyable, ImplicitlyCopyable):    
    var inner : Array[UInt8, SIZE_OF_MPZ]

    def __init__(out self):
        self.inner = Array[UInt8, SIZE_OF_MPZ](fill=0)
        external_call["__gmpf_init", NoneType](Pointer(to=self.inner))
    def __init__(out self, *, copy: Self): # copy constructor
        self.inner = Array[UInt8, SIZE_OF_MPZ](fill=0)
        external_call["__gmpf_init", NoneType](Pointer(to=self.inner))
        external_call["__gmpf_set", NoneType](Pointer(to=self.inner), Pointer(to=copy.inner))
       
struct BigFloat(Writable, Floatable, Copyable, ImplicitlyCopyable):
    var data : MPZ        

    def __init__(out self) : self.data = MPZ()         
    def __init__(out self, other : Self):
        self.data = MPZ()
        external_call["__gmpf_set", NoneType](Pointer(to=self.data), Pointer(to=other.data))
    def __init__(out self, value : Float64):
        self.data = MPZ()
        external_call["__gmpf_set_d", NoneType](Pointer(to=self.data), value)
    def __init__(out self, value : Int):
        self.data = MPZ()
        external_call["__gmpf_set_d", NoneType](Pointer(to=self.data), Float64(value))
    def __init__(out self, value : String) raises: # must convert String to null terminated (\0) char* 
        self.data = MPZ() 
        external_call["__gmpf_set_str", NoneType](Pointer(to=self.data), CStringSlice(value + "\0").as_bytes_with_nul().unsafe_ptr(), 10)    
    def __init__(out self, *, copy: Self): # copy constructor
        self.data = MPZ()
        external_call["__gmpf_set", NoneType](Pointer(to=self.data), Pointer(to=copy.data))
    
    def __deinit__(deinit self): external_call["__gmpf_clear", NoneType](Pointer(to=self.data))

    def set(self, value: Float64): external_call["__gmpf_set_d", NoneType](Pointer(to=self.data), value)
    def set(self, value: Self): external_call["__gmpf_set", NoneType](Pointer(to=self.data), Pointer(to=value.data))
    def get(self) -> Float64: return external_call["__gmpf_get_d", c_double](Pointer(to=self.data))
    def get_prec(self) -> Int: return Int(external_call["__gmpf_get_prec", c_int](Pointer(to=self.data)))
    def to_double(self) -> Float64: return external_call["__gmpf_get_d", c_double](Pointer(to=self.data))
    def __float__(self) -> Float64: return self.to_double()
   
        
    def __str__(self) -> String:
        var buf = Array[c_char, 1024](fill=0)
        var _ : c_int = external_call["__gmp_snprintf", c_int](
            buf.unsafe_ptr(), 
            len(buf)-1, 
            "%.*Fg".as_c_string_slice().unsafe_ptr(),             
            c_int(PRECISION),
            Pointer(to=self.data))
        return String(unsafe_from_utf8_ptr=buf.unsafe_ptr())
        
    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.__str__())

    # arithmetical
    @always_inline
    def __add__(self, other: Self) -> Self:
        var result = Self(0.0)
        external_call["__gmpf_add", NoneType](Pointer(to=result.data), Pointer(to=self.data), Pointer(to=other.data))
        return result^
    @always_inline
    def __sub__(self, other: Self) -> Self:
        var result = Self(0.0)
        external_call["__gmpf_sub", NoneType](Pointer(to=result.data), Pointer(to=self.data), Pointer(to=other.data))
        return result^    
    @always_inline
    def __mul__(self, other: Self) -> Self:
        var result = Self(0.0)
        external_call["__gmpf_mul", NoneType](Pointer(to=result.data), Pointer(to=self.data), Pointer(to=other.data))
        return result^
    @always_inline
    def __truediv__(self, other: Self) -> Self:
        var result = Self(0.0)
        external_call["__gmpf_div", NoneType](Pointer(to=result.data), Pointer(to=self.data), Pointer(to=other.data))
        return result^

    # funcs
    def sqrt(self) -> Self:
        var result = Self(0.0)
        external_call["__gmpf_sqrt", NoneType](Pointer(to=result.data), Pointer(to=self.data))
        return result^
    @always_inline
    def acc(self, other: Self): # accumulate on self+=other
        external_call["__gmpf_add", NoneType](Pointer(to=self.data), Pointer(to=self.data), Pointer(to=other.data))

    #logical
    @always_inline
    def cmp(self, other: Self) -> c_int:
        return external_call["__gmpf_cmp", c_int](
            Pointer(to=self.data),
            Pointer(to=other.data)
        )
    @always_inline 
    def __eq__(self, other: Self) -> Bool:        return self.cmp(other) == 0
    @always_inline 
    def __ne__(self, other: Self) -> Bool:        return not (self == other)
    @always_inline 
    def __lt__(self, other: Self) -> Bool:        return self.cmp(other) < 0
    @always_inline 
    def __le__(self, other: Self) -> Bool:        return self.cmp(other) <= 0
    @always_inline 
    def __gt__(self, other: Self) -> Bool:        return self.cmp(other) > 0
    @always_inline 
    def __ge__(self, other: Self) -> Bool:        return self.cmp(other) >= 0

    @staticmethod
    def set_prec(prec : Int64):
        external_call["__gmpf_set_default_prec", NoneType](prec)
    @staticmethod
    def get_prec() -> Int64:
        return external_call["__gmpf_get_default_prec", Int64]()

    @staticmethod
    def zero() -> Self:  return Self(0.0)
    @staticmethod
    def one() -> Self:  return Self(1.0)
    @staticmethod
    def two() -> Self:  return Self(2.0)
    @staticmethod
    def four() -> Self:  return Self(4.0)
    @staticmethod
    def half() -> Self:  return Self(0.5)

# Complex
struct ComplexMP(Writable, Copyable, ImplicitlyCopyable):
    var real: BigFloat
    var imag: BigFloat
    
    def __init__(out self):
        self.real = BigFloat.zero()
        self.imag = BigFloat.zero()
    def __init__(out self, other: Self):
        self.real = BigFloat(other.real)
        self.imag = BigFloat(other.imag)
    def __init__(out self, real : Float64, imag: Float64):
        self.real = BigFloat(real)
        self.imag = BigFloat(imag)
    def __init__(out self, var real: BigFloat, var imag: BigFloat):
        self.real = real
        self.imag = imag
    def __init__(out self, var real: String, var imag: String) raises:
        self.real = BigFloat(real)
        self.imag = BigFloat(imag)
    def __init__(out self, *, copy: Self): # copy constructor
        self.real = copy.real
        self.imag = copy.imag
    
    def __add__(self, other: Self) -> Self:
        return Self(self.real + other.real, self.imag + other.imag)
    
    def __sub__(self, other: Self) -> Self:
        return Self(self.real - other.real, self.imag - other.imag)
    
    def __mul__(self, other: Self) -> Self:
        return Self(self.real * other.real - self.imag * other.imag,
                        self.real * other.imag + self.imag * other.real)
    
    def __truediv__(self, other: Self) -> Self:
        var denom = other.real * other.real + other.imag * other.imag
        return Self((self.real * other.real + self.imag * other.imag) / denom,
                        (self.imag * other.real - self.real * other.imag) / denom)
    def abs(self) -> BigFloat:
        return (self.real * self.real + self.imag * self.imag).sqrt()
    def norm(self) -> BigFloat:
        return self.real * self.real + self.imag * self.imag
    def to_complex(self) -> ComplexFloat64:
        return ComplexFloat64(self.real.to_double(), self.imag.to_double())
    def set(self, b : Self):
        self.real.set(b.real)
        self.imag.set(b.imag)
    @staticmethod
    def zero() -> Self:
        return Self(BigFloat.zero(), BigFloat.zero())
    def sqrAdd(mut self, other: Self):
        self = self * self + other

    def __str__(self) -> String:
        return self.real.__str__() + " + " + self.imag.__str__() + "i"
    def get_prec(self) -> Int:
        return self.real.get_prec()
       
    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.__str__())

# test       
def test_mp() raises:
    BigFloat.set_prec(1024)
    
    var a = BigFloat(22.33)
    var b = BigFloat("12.3456789012345678901234567890")

    b = a # implicit copy -> pointers are different
    print(t"Pointer(to=a) == Pointer(to=b): {Pointer(to=a) == Pointer(to=b)}")
    
    var c = a+b
    print(a,"+",b,"=",c)
    
    var d = a-b
    print(a,"-",b,"=",d)
    
    var e = a*b
    print(a,"*",b,"=",e)
    
    var f = a/b
    print(a,"/",b,"=",f)
    
    print(t"a={a}, b={b}, a==a {a==a}, a!=b {a!=b}, a<b {a<b}, a>b {a>b}, a<=b {a<=b}, a>=b {a>=b}")

    var x = BigFloat(0.1)
    var zp1 = BigFloat()
    zp1.set(0.1)
    for i in range(1_000_000):
        x = x + zp1 * BigFloat(i % 100)
    print(t"x = {x}")
    
    var y = BigFloat(2.0)
    var z = y.sqrt()
    print(t"sqrt(2) = {z}")
    print(t"sqrt(2) as float64 = {z.get()}")

    print("array test")
    var af: List[BigFloat] = List[BigFloat]()
    print("assigning values...")
    for i in range(3, 100, 10):
        af.append(BigFloat(i*i))        
    print("done, printing")
    for i in range(len(af)):
        print(t"{af[i]}", end=", ")
    print()
    
    return

def test_ComplexMP() raises:
    BigFloat.set_prec(1024)

    for i in range(10_000_000):
        var a = ComplexMP(BigFloat(1.0), BigFloat(2.0))
        var b = ComplexMP(BigFloat(3.0), BigFloat(4.0))
        var c = a + b * b /a
        if i == 0:
            print(t"a={a}, b={b}, a+b={a+b}, a-b={a-b}, a*b={a*b}, a/b={a/b}, abs(a)={a.abs()}, norm(a)={a.norm()}, c:{c}")

        a = ComplexMP(BigFloat(5.0), BigFloat(6.0))

        if i == 0:
            print(t"a={a}, cmplx:{a.to_complex()}")

        a = ComplexMP("5.0", "6.0")
        if i == 0:
            print(t"a={a}, cmplx:{a.to_complex()}")

        a= ComplexMP(  "-0.54280584740634268367882858449016222926907465243354029312039262030034763062217093",
                        "-0.61549567328280223372696654577766177370034035939345019559741864301726447118754571")
        if i == 0:
            print(t"a={a}")

        a = ComplexMP(5, 6)
        if i == 0:
            print(t"a={a}")

def main() raises: test_mp()

