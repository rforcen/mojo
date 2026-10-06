# common

from vertex import Vertex
from polyhedron import Polyhedron
from seeds import Dodecahedron, Icosahedron, Cube, Octahedron, Tetrahedron
from johnson import Johnson
from conway import kis, ambo, quinto, whirl, chamfer, insetN, gyro, propellor, hollow
#
from  std.testing.prop import Rng

comptime u32 = UInt32
comptime i32 = Int32
comptime f32 = Float32
comptime MAX_UINT = u32(0xffff_ffff)

comptime Face = List[u32]
comptime Faces = List[Face]
comptime Vertexes = List[Vertex]

#
struct EdgeKey(Hashable, Equatable, ImplicitlyCopyable):
    var v1: u32
    var v2: u32
    
    @always_inline
    def __init__(out self, v1: u32, v2: u32):
        self.v1 = v1
        self.v2 = v2
    
    @always_inline
    def __hash__(self) -> u32:
        var h: u32 = 5381
        h = ((h << 5) + h) + self.v1
        h = ((h << 5) + h) + self.v2
        return h
        
    @always_inline
    def __eq__(self, other: Self) -> Bool:
        return self.v1 == other.v1 and self.v2 == other.v2
        
    @always_inline
    @staticmethod
    def init_sorted(a: u32, b: u32) -> Self:
        return Self(v1=a, v2=b) if a < b else Self(v1=b, v2=a)


# EdgeVertices
@fieldwise_init
struct EdgeVertices(ImplicitlyCopyable):
    var v1_third: u32
    var v2_third: u32

# EdgeFaces
@fieldwise_init
struct EdgeFaces(ImplicitlyCopyable):
    var f1: u32
    var f2: u32


# misc def
def serial_len(faces: Faces) -> u32:
    var tlen: u32 = 0
    for face in faces:
        tlen += 1 + u32(len(face))
    return tlen

def serial_len(vertexes: Vertexes) -> u32:
    return u32(len(vertexes) * 3)

def flatten_faces(faces: Faces) -> List[u32]:
    var tlen: u32 = serial_len(faces)
    var flat: List[u32] = List[u32](unsafe_uninit_length=Int(tlen))
    var index: u32 = 0
    for face in faces:
        flat[index] = u32(len(face))
        index += 1
        for v in face:
            flat[index] = v
            index += 1
    return flat^

def flatter_vertexes(vertexes: Vertexes) -> List[f32]:
    var tlen: u32 = serial_len(vertexes)
    var flat: List[f32] = List[f32](unsafe_uninit_length=Int(tlen))
    var index: u32 = 0
    for vertex in vertexes:
        flat[index] = vertex.x()
        flat[index + 1] = vertex.y()
        flat[index + 2] = vertex.z()
        index += 3
    return flat^

def calc_range(from_val: i32, to_val: i32, inclusive: Bool) -> List[u32]:
    var result = Face()
    var step: i32 = 1 if from_val <= to_val else -1
    var current: i32 = from_val
    var end: i32 = to_val
    
    while True:
        if step == 1:
            if inclusive and current > end:
                break
            if not inclusive and current >= end:
                break
        else:
            if inclusive and current < end:
                break
            if not inclusive and current <= end:
                break
        
        result.append(u32(current))
        current += step
    
    return result^
#
from std.time import perf_counter

def random_palette(n: Int = 64) -> Vertexes:
    var rng = Rng(seed=Int(perf_counter()))
    def random_value() {mut rng}-> f32:
        var r : f32
        try:
            r = f32(rng.rand_scalar[DType.float32](min=0.0, max=1.0))
        except:
            r = 0.0
        return r

    var palette = Vertexes(capacity=n)

    for _ in range(n):
        palette.append({ random_value(), random_value(), random_value() })
    return palette^

def transform(tr : String) -> Polyhedron:
    var ltr = tr.byte_length()
    var ps = tr[byte=ltr-1]
    var p : Polyhedron

    if   ps == 'D': p = materialize[Dodecahedron]()
    elif ps == 'I': p = materialize[Icosahedron]()
    elif ps == 'C': p = materialize[Cube]()
    elif ps == 'O': p = materialize[Octahedron]()
    elif ps == 'T': p = materialize[Tetrahedron]()
    elif ps == 'J': 
        var j = materialize[Johnson]()
        p = j[rand_int(0, len(j)-1)].copy()
    else:           p = materialize[Dodecahedron]() # default

    for i in range(ltr-1):
        var t = tr[byte=ltr-i-2]

        if   t=='k' : p=kis(p)
        elif t=='a' : p=ambo(p)
        elif t=='q' : p=quinto(p)
        elif t=='w' : p=whirl(p)  
        elif t=='c' : p=chamfer(p, 0.1)  
        elif t=='n' : p=insetN(p, inset_dist=0.5, popout_dist=-0.2)  
        elif t=='g' : p=gyro(p)  
        elif t=='p' : p=propellor(p)  
        elif t=='h' : p=hollow(p)  
    
    p.recalc()
    return p^
    
def rand_int(min: Int, max: Int) -> Int:
    var rng = Rng(seed=Int(perf_counter()))
    try:
        return Int(rng.rand_scalar[DType.int32](min=Int32(min), max=Int32(max)))
    except:
        return 0

# test
from std.collections import Dict

def test_common():
    var e = EdgeKey(1, 2)
    print(e.__hash__())
    print(e.__eq__(EdgeKey(1, 2)))
    
    var d = Dict[EdgeKey, u32]()
    d[EdgeKey(1, 2)] = 1

    print(calc_range(5, 1, False))
    print(calc_range(5, 1, True))
    



def main():
    test_common()