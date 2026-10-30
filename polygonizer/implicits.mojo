# implicits functions
from std.math import sin, sqrt
#
comptime ImplicitFuncDef = def(x:Float32, y:Float32, z:Float32) thin -> Float32

@fieldwise_init
struct ImplicitFunc:
  var func_id : Int 
  var name : String
  var bounds : Int32
  var size : Float32
  
comptime ImplicitDefs = [
  Sphere,
  Blob,
  NordstarndWeird,
  DecoCube,
  Cassini,
  Orth,
  Orth3,
  Pretzel,
  Tooth,
  Pilz,
  Bretzel,
  BarthDecic,
  Clebsch0,
  Clebsch,
  Chubs,
  Chair,
  Roman,
  TangleCube,
  Goursat,
  Sinxyz
]

comptime ImplicitFuncs : List[ImplicitFunc] = [
  ImplicitFunc(0, "Sphere", 60, 0.06), 
  ImplicitFunc(1, "Blob", 60, 0.06), 
  ImplicitFunc(2, "NordstarndWeird", 20, 0.06), 
  ImplicitFunc(3, "DecoCube", 40, 0.025), 
  ImplicitFunc(4, "Cassini", 18, 0.06),
  ImplicitFunc(5, "Orth", 25, 0.016), 
  ImplicitFunc(6, "Orth3", 20, 0.06), 
  ImplicitFunc(7, "Pretzel", 25, 0.023), 
  ImplicitFunc(8, "Tooth", 15, 0.06), 
  ImplicitFunc(9, "Pilz", 24, 0.018),
  ImplicitFunc(10, "Bretzel", 15, 0.0152), 
  ImplicitFunc(11, "BarthDecic", 60, 0.06), 
  ImplicitFunc(12, "Clebsch0", 20, 0.06), 
  ImplicitFunc(13, "Clebsch", 20, 0.06), 
  ImplicitFunc(14, "Chubs", 31, 0.0381),
  ImplicitFunc(15, "Chair", 30, 0.13), 
  ImplicitFunc(16, "Roman", 30, 0.06), 
  ImplicitFunc(17, "TangleCube", 30, 0.06), 
  ImplicitFunc(18, "Goursat", 30, 0.06), 
  ImplicitFunc(19, "Sinxyz", 15, 0.06)
]

# helpers
@always_inline
def sqr(x: Float32) -> Float32:   return x * x
@always_inline
def cube(x: Float32) -> Float32: return x * x * x
@always_inline
def sqr3(x: Float32) -> Float32: return x * x * x
@always_inline
def sqr4(x: Float32) -> Float32: return x * x * x * x
@always_inline
def sphere(x: Float32, y: Float32, z: Float32) -> Float32: 
    var rsq = x*x + y*y + z*z
    return 1.0 / (0.00001 if rsq < 0.00001 else rsq)

# implicit functions implementation
def NordstarndWeird(x: Float32, y: Float32, z: Float32) -> Float32:
  return 25*(sqr3(x)*(y + z) + sqr3(y)*(x + z) + sqr3(z)*(x + y)) + 50*(x*x*y*y + x*x*z*z + y*y*z*z) - 125*(x*x*y*z + y*y*x*z + z*z*x*y) + 60*x*y*z - 4*(x*y + y*z + z*x)

def DecoCube(x: Float32, y: Float32, z: Float32) -> Float32:
  var (a, b) = (Float32(0.95), Float32(0.01))
  return (sqr(x*x + y*y - a*a) + sqr(z*z - 1))*(sqr(y*y + z*z - a*a) + sqr(x*x - 1))*(sqr(z*z + x*x - a*a) + sqr(y*y - 1)) - b

def Cassini(x:Float32,y:Float32,z:Float32) -> Float32:
  var (a, b) = (Float32(0.3), Float32(1.0))
  return (sqr((x - a)) + z*z) * (sqr((x + a)) + z*z) - b*sqr4(y) 
    
def Orth(x:Float32,y:Float32,z:Float32) -> Float32:
  var (a, b) = (Float32(0.06), Float32(2.0))
  return (sqr(x*x + y*y - 1) + z*z)*(sqr(y*y + z*z - 1) + x*x)*(sqr(z*z + x*x - 1) + y*y)-a*a*(1 + b*(x*x + y*y + z*z))

def Orthogonal(x:Float32,y:Float32,z:Float32) -> Float32:
  return Orth(x,y,z)

def Orth3(x:Float32,y:Float32,z:Float32) -> Float32:
  return 4.0 - Orth(x + 0.5, y - 0.5, z - 0.5) - Orth(x - 0.5, y + 0.5, z - 0.5) - Orth(x - 0.5, y - 0.5, z + 0.5)
    
def Pretzel(x:Float32,y:Float32,z:Float32) -> Float32:
  var aa = Float32(1.6)
  return sqr( ((x - 1)*(x - 1) + y*y - aa*aa) * ((x + 1)*(x + 1) + y*y - aa*aa)) + z*z*10 - 1
    
def Tooth(x:Float32,y:Float32,z:Float32) -> Float32:
  return sqr4(x) + sqr4(y) + sqr4(z) - sqr(x) - sqr(y) - sqr(z)
    
def Pilz(x:Float32,y:Float32,z:Float32) -> Float32:
  var (a,b) = (Float32(0.05), Float32(-0.1))
  return sqr( sqr(x*x + y*y - 1) + sqr(z - 0.5)) * ( sqr(y*y / a*a + sqr(z + b) - 1.0) + x*x) - a * (1.0 + a*sqr(z - 0.5))
    
def Bretzel(x:Float32,y:Float32,z:Float32) -> Float32:
  var (a,b) = (Float32(0.003), Float32(0.7))
  return sqr(x*x*(1 - x*x) - y*y)  + 0.5*z*z - a*(1 + b*(x*x + y*y + z*z))

def BarthDecic(x:Float32,y:Float32,z:Float32) -> Float32:
  var GR : Float32 = 1.6180339887 # Golden ratio
  var GR2 = GR * GR
  var GR4 = GR2 * GR2
  var w : Float32 = 0.3
  
  return 8*(x*x - GR4*y*y)*(y*y - GR4*z*z)*(z*z - GR4*x*x)*(sqr4(x) + sqr4(y) + sqr4(z) - 2*x*x*y*y - 2*x*x*z*z - 2*y*y*z*z)+
  (3 + 5*GR)*sqr((x*x + y*y + z*z - w*w))*sqr((x*x + y*y + z*z - (2 - GR)*w*w))*w*w
    
def Clebsch0 (x:Float32,y:Float32,z:Float32) -> Float32:
  return 81*(cube(x) + cube(y) + cube(z)) - 189*(sqr(x)*y + sqr(x)*z + sqr(y)*x + sqr(y)*z + sqr(z)*x + sqr(z)*y) + 54*(x*y*z) + 126*(x*y + x*z + y*z) - 9*(sqr(x) + sqr(y) + sqr(z)) - 9*(x + y + z) + 1
    
def Clebsch(x:Float32,y:Float32,z:Float32) -> Float32:
  return 16 * cube(x) + 16 * cube(y) - 31 * cube(z) + 24 * sqr(x) * z - 48 * sqr(x) * y - 48 * x * sqr(y) + 24 * sqr(y) * z - 54 * sqrt(Float32(3.0)) * sqr(z) - 72 * z
    
def Chubs(x:Float32,y:Float32,z:Float32) -> Float32:
  return sqr4(x) + sqr4(y) + sqr4(z) - sqr(x) - sqr(y) - sqr(z) + 0.5 # x^4 + y^4 + z^4 - x^2 - y^2 - z^2 + 0.5 = 0
    
def Chair(x:Float32,y:Float32,z:Float32) -> Float32:
  var (k,a,b) = (Float32(5.0), Float32(0.95), Float32(0.8))
  return sqr(sqr(x) + sqr(y) + sqr(z) - a*sqr(k)) - b*((sqr((z - k)) - 2*sqr(x))*(sqr((z + k)) - 2*sqr(y)))
  
def Roman(x:Float32,y:Float32,z:Float32)  -> Float32:
  var r : Float32=2.0
  return sqr(x)*sqr(y) + sqr(y)*sqr(z) + sqr(z)*sqr(x) - r*x*y*z

def Sinxyz(x:Float32,y:Float32,z:Float32) -> Float32:
  return sin(x)*sin(y)*sin(z)
    
def F001(x:Float32,y:Float32,z:Float32) -> Float32:
  return sqr3(x) + sqr3(y) + sqr4(z) - 10 # x^3 + y^3 + z^4 -10 = 0
    
def TangleCube(x:Float32,y:Float32,z:Float32) -> Float32:
  return sqr4(x) - 5*x*x + sqr4(y) - 5*y*y + sqr4(z) - 5*z*z + 11.8

def Goursat(x:Float32,y:Float32,z:Float32) -> Float32: # (x^4 + y^4 + z^4) + a * (x^2 + y^2 + z^2)^2 + b * (x^2 + y^2 + z^2) + c = 0 	
  var (a,b,c)=(Float32(0.0),Float32(0.0),Float32(-1.0))
  return sqr4(x) + sqr4(y) + sqr4(z) + a*(x*x + y*y + z*z)*(x*x + y*y + z*z) + b*(x*x + y*y + z*z) + c
    
@always_inline
def Blob(x:Float32,y:Float32,z:Float32) -> Float32:
  return 4 - sphere(x + 0.5, y - 0.5, z - 0.5) - sphere(x - 0.5, y + 0.5, z - 0.5) - sphere(x - 0.5, y - 0.5, z + 0.5)

def Sphere(x:Float32,y:Float32,z:Float32) -> Float32: return sphere(x,y,z)-1

# test
def test00():
    var funcs = materialize[ImplicitFuncs]()
    for i in range(len(funcs)):
        print(funcs[i](0.0, 0.0, 0.0))

def main():
    test00()