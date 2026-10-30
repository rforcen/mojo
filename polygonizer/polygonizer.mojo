# polygonizer
from implicits import ImplicitFuncs, ImplicitFuncDef, ImplicitDefs
#
from std.testing.prop.random import Rng
from std.time import perf_counter
from std.math import sqrt
from std.collections import Set
#

comptime TET = 0   # use tetrahedral decomposition
comptime NOTET = 1 # no tetrahedral decomposition

comptime RES = 40 # converge iterations   

comptime L = 0   # left direction:	-x, -i  
comptime R = 1   # right direction:	+x, +i  
comptime B = 2   # bottom direction: -y, -j 
comptime T = 3   # top direction:	+y, +j  
comptime N = 4   # near direction:	-z, -k  
comptime F = 5   # far direction:	+z, +k  
comptime LBN = 0 # left bottom near corner  
comptime LBF = 1 # left bottom far corner  
comptime LTN = 2 # left top near corner     
comptime LTF = 3 # left top far corner      
comptime RBN = 4 # right bottom near corner 
comptime RBF = 5 # right bottom far corner  
comptime RTN = 6 # right top near corner    
comptime RTF = 7 # right top far corner    

comptime LB = 0
comptime LT = 1
comptime LN = 2
comptime LF = 3
comptime RB = 4
comptime RT = 5
comptime RN = 6
comptime RF = 7
comptime BN = 8
comptime BF = 9
comptime TN = 10
comptime TF = 11

# bit operations
def BIT(i: Int32, bit: Int32) -> Int32:    return (i >> bit) & 1  # bit set?
def FLIP(i: Int32, bit: Int32) -> Int32:    return i ^ (1 << bit) # flip bit 

# structs
@fieldwise_init
struct Point(ImplicitlyCopyable, Hashable, Equatable):
    var x: Float32
    var y: Float32
    var z: Float32 

    @always_inline
    def __hash__(self) -> Int:        
        return Int(hash(self.x) ^ hash(self.y) ^ hash(self.z))

    @always_inline
    def __eq__(self, other: Self) -> Bool:
        return self.x == other.x and self.y == other.y and self.z == other.z    

    def __init__(out self):
        self.x = 0.0
        self.y = 0.0
        self.z = 0.0
    
    def normalized(self) -> Point:
        var p = self
        var f = sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
        if f != 0.0:
            p.x /= f
            p.y /= f
            p.z /= f
        return p

    def max(self) -> Float32:
        return max(abs(self.x), abs(self.y), abs(self.z))

    def mid(self, other: Self) -> Point:
        return Point((self.x + other.x) / 2, (self.y + other.y) / 2, (self.z + other.z) / 2)

    def as_array(self) -> Array[Float32, 3]:
        return [self.x, self.y, self.z]
    
    def __itruediv__(mut self, other: Float32):
        self.x /= other
        self.y /= other
        self.z /= other
        

@fieldwise_init
struct Test:
    var p: Point
    var value: Float32
    var ok: Int32

@fieldwise_init
struct Vertex(ImplicitlyCopyable):
    var position: Point
    var normal: Point

    def __init__(out self):
        self.position = Point()
        self.normal = Point()
      
@fieldwise_init
struct Triangle(ImplicitlyCopyable):
    var i1: Int32
    var i2: Int32
    var i3: Int32

struct Cube(Copyable):
    var i: Int32
    var j: Int32
    var k: Int32
    var corners: Array[Corner, 8]

    def __init__(out self, i : Int32, j : Int32, k : Int32):
        self.i = i
        self.j = j
        self.k = k        
        self.corners = Array[Corner, 8](fill=Corner(0,0,0,Point(),0.0))

    def __init__(out self, *, other : Cube):
        self.i = other.i
        self.j = other.j
        self.k = other.k
        self.corners = other.corners.copy()
    
@fieldwise_init
struct Center(ImplicitlyCopyable, Hashable, Equatable):
    var i: Int32
    var j: Int32
    var k: Int32

    def __hash__(self) -> Int:
        return Int(hash(self.i) ^ hash(self.j) ^ hash(self.k))

    def __eq__(self, other: Self) -> Bool:
        return self.i == other.i and self.j == other.j and self.k == other.k
 
@fieldwise_init
struct Corner(ImplicitlyCopyable, Hashable, Equatable):
    var i: Int32
    var j: Int32
    var k: Int32
    var point : Point    
    var value : Float32

    @always_inline
    def __hash__(self) -> Int:
        return Int(hash(self.i) ^ hash(self.j) ^ hash(self.k))

    @always_inline
    def __eq__(self, other: Self) -> Bool:
        return self.i == other.i and self.j == other.j and self.k == other.k

@fieldwise_init
struct Edge(Hashable, Equatable):
    var i1: Int32
    var j1: Int32
    var k1: Int32
    var i2: Int32
    var j2: Int32
    var k2: Int32

    @always_inline
    def __hash__(self) -> Int:        
        return Int(hash(self.i1) ^ hash(self.j1) ^ hash(self.k1) ^ hash(self.i2) ^ hash(self.j2) ^ hash(self.k2))

    @always_inline
    def __eq__(self, other: Self) -> Bool:
        return (
            self.i1 == other.i1 and 
            self.j1 == other.j1 and 
            self.k1 == other.k1 and 
            self.i2 == other.i2 and 
            self.j2 == other.j2 and 
            self.k2 == other.k2 
        )

# geo collections
comptime Triangles  = List[Triangle]
comptime CubeList   = List[Cube]
comptime Vertices   = List[Vertex]
comptime EdgeDict   = Dict[Edge, Int32] # vid
comptime IntList    = List[Int32]
comptime IntLists   = List[IntList]
comptime CornerDict = Dict[Corner, Float32] # value
comptime CenterSet  = Set[Center]

# polygonizer process structure
struct Polygonizer:
    var implicit_func: ImplicitFuncDef
    
    var size: Float32
    var delta: Float32
    var bounds: Int32
    var start: Point
    var cubes: CubeList
    var vertices: Vertices
    var centers: CenterSet
    var corners: CornerDict
    var edges  : EdgeDict
    
    var triangles: Triangles
   
    var lefthanded: Int32

    var cubetable : Array[IntLists, 256]
    var corner1   : Array[Int32, 12]
    var corner2   : Array[Int32, 12]
    var leftface  : Array[Int32, 12]
    var rightface : Array[Int32, 12]

    var _rnd : Rng

    def __init__(out self, 
            implicit_func: ImplicitFuncDef, 
            size : Float32, 
            bounds : Int32, 
            x : Float32 = 0.0, 
            y : Float32 = 0.0, 
            z : Float32 = 0.0, 
            mode : Int32 = TET):

        self.implicit_func = implicit_func
        self.size = size
        self.delta = Float32(size / Float32(RES * RES))
        self.bounds = bounds
        self.start = Point(x, y, z)
        self.cubes = CubeList()
        self.vertices = Vertices()
        self.centers = CenterSet()
        self.corners = CornerDict()
        self.edges = EdgeDict()
        self.triangles = Triangles()    
        self.lefthanded = 0

        self.corner1   = [LBN, LTN, LBN, LBF, RBN, RTN, RBN, RBF, LBN, LBF, LTN, LTF]
        self.corner2   = [LBF, LTF, LTN, LTF, RBF, RTF, RTN, RTF, RBN, RBF, RTN, RTF]
        self.leftface  = [B, L, L, F, R, T, N, R, N, B, T, F]
        self.rightface = [L, T, N, L, B, R, R, F, B, F, N, T]

        self.cubetable = Array[IntLists, 256](fill=IntLists())
        self._rnd = Rng(seed = Int(perf_counter()))
    
    def otherface(self, edge: Int32, face: Int32) -> Int32:
        var other: Int32 = self.leftface[edge]
        return self.rightface[edge] if face == other else other

    def nextcwedge(self, edge: Int32, face: Int32) -> Int32:
        if edge == LB:
            return LF if face == L else BN
        elif edge == LT:
            return LN if face == L else TF
        elif edge == LN:
            return LB if face == L else TN
        elif edge == LF:
            return LT if face == L else BF
        elif edge == RB:
            return RN if face == R else BF
        elif edge == RT:
            return RF if face == R else TN
        elif edge == RN:
            return RT if face == R else BN
        elif edge == RF:
            return RB if face == R else TF
        elif edge == BN:
            return RB if face == B else LN
        elif edge == BF:
            return LB if face == B else RF
        elif edge == TN:
            return LT if face == T else RN
        elif edge == TF:
            return RT if face == T else LF
        else:
            return -1

    def makecubetable(mut self):
        
        var pos = Array[Int32, 8](fill=0)
        
        for i in range(256):
            var done = Array[Bool, 12](fill=False)
            for c in range(8):   pos[c] = BIT(Int32(i), Int32(c))

            for e in range(12):
                
                if not done[e] and pos[self.corner1[e]] != pos[self.corner2[e]]:
                    
                    var ints = IntList()
                    
                    var (start, edge) = (Int32(e), Int32(e))

                    # get face that is to right of edge from pos to neg corner: 
                    var face = self.rightface[e] if pos[self.corner1[e]] else self.leftface[e]
                    
                    while True:
                        edge = self.nextcwedge(edge, face)
                        done[edge] = True

                        if pos[self.corner1[edge]] != pos[self.corner2[edge]]:
                            ints.append(edge)

                            if edge == start:
                                break
                            face = self.otherface(edge, face)
        
                    self.cubetable[i].append(ints^)

    def rand(mut self) raises -> Float32:   return Float32(self._rnd.rand_scalar[DType.float64](min=-0.5, max=0.5))

    def vnormal(mut self, point: Point) -> Point:
        var f: Float32 = self.implicit_func(point.x, point.y, point.z)
        
        return Point(
            self.implicit_func(point.x + self.delta, point.y, point.z) - f,
            self.implicit_func(point.x, point.y + self.delta, point.z) - f,
            self.implicit_func(point.x, point.y, point.z + self.delta) - f
        ).normalized()        
        
        
    def find(mut self, sign : Bool, x : Float32, y : Float32, z : Float32) raises -> Test:
        var test = Test(Point(), 0, 0)
        var frange : Float32 = self.size
        test.ok = 1

        for _ in range(20_000):
            test.p = Point(
                x + frange * self.rand(),
                y + frange * self.rand(),
                z + frange * self.rand()
            )
            test.value = self.implicit_func(test.p.x, test.p.y, test.p.z)
            if sign == (test.value > 0.0):
                return test^
            frange = frange * 1.0005  # slowly expand search outwards
        test.ok = 0
        return test^

    def setcenter(mut self, i : Int32, j : Int32, k : Int32) raises -> Bool:
        var center = Center(i, j, k)
        if center in self.centers:
            return True

        self.centers.add(center)
        return False

    def setcorner(mut self, i : Int32, j : Int32, k : Int32) raises -> Corner:
        var corner = Corner(i, j, k, 
            Point(
                self.start.x + (Float32(i) - 0.5) * self.size, 
                self.start.y + (Float32(j) - 0.5) * self.size, 
                self.start.z + (Float32(k) - 0.5) * self.size
            ),
            0.0
        )
        if corner in self.corners: # change value if corner already exists
            corner.value = self.corners[corner]
            return corner

        corner.value = self.implicit_func(corner.point.x, corner.point.y, corner.point.z)

        self.corners[corner] = corner.value
        return corner

    def testface(mut self, i : Int32, j : Int32, k : Int32, old : Cube, face : Int32, c1 : Int32, c2 : Int32, c3 : Int32, c4 : Int32) raises:
        
        var facebit : List[Int32] = [2, 2, 1, 1, 0, 0]
        
        var pos = old.corners[c1].value > 0.0 
        var bit = facebit[face]

        #  test if no surface crossing, cube out of bounds, or already visited: 
        if (old.corners[c2].value > 0) == pos and \
           (old.corners[c3].value > 0) == pos and \
           (old.corners[c4].value > 0) == pos:
            return

        if abs(i) > self.bounds or abs(j) > self.bounds or abs(k) > self.bounds:
            return

        if self.setcenter(i, j, k):
            return

        # create new cube: 
        var new_cube = Cube(i, j, k)

        new_cube.corners[FLIP(c1, bit)] = old.corners[c1]
        new_cube.corners[FLIP(c2, bit)] = old.corners[c2]
        new_cube.corners[FLIP(c3, bit)] = old.corners[c3]
        new_cube.corners[FLIP(c4, bit)] = old.corners[c4]
        
        for n in range(8):            
            new_cube.corners[n] = self.setcorner(i + BIT(Int32(n), 2), j + BIT(Int32(n), 1), k + BIT(Int32(n), 0))

        # add cube to top of stack:         
        self.cubes.append(new_cube^)

    def vertid(mut self, c1 : Corner, c2 : Corner) raises -> Int32 :        
        var vid : Int32 = self.getedge(c1.i, c1.j, c1.k, c2.i, c2.j, c2.k)
        if vid != -1: return vid

        var a = c1.point
        var b = c2.point

        var v = Vertex()
        v.position = self.converge(a, b, c1.value) # position
        v.normal = self.vnormal(v.position) # normal
        self.addtovertices(v) # save vertex

        vid = Int32(len(self.vertices)) - 1
        self.setedge(c1, c2, vid)
        return vid

    def docube(mut self, cube : Cube) raises -> Int32:
        
        var index = 0
        for i in range(8):
            if cube.corners[i].value > 0.0:
                index += (1 << i)
        
        for polys in self.cubetable[index]:
            
            var (a, b, count) = (Int32(-1), Int32(-1), Int32(0))
            
            for edges in polys:
            
                var c1 = cube.corners[self.corner1[edges]]
                var c2 = cube.corners[self.corner2[edges]]
                var c = self.vertid(c1, c2)

                if count > 2 and not self.triproc(a, b, c): return 0
                
                count += 1
                if count < 3:  a = b
                b = c
                
        return 1

    def setedge(mut self, ref c1 : Corner, ref c2 : Corner, vid : Int32):
        self.setedge(c1.i, c1.j, c1.k, c2.i, c2.j, c2.k, vid)

    def setedge(mut self, _i1:Int32, _j1:Int32, _k1:Int32, _i2:Int32, _j2:Int32, _k2:Int32, vid:Int32):
        var (i1, j1, k1, i2, j2, k2) = (_i1, _j1, _k1, _i2, _j2, _k2)

        if (i1 > i2 or (i1 == i2 and (j1 > j2 or (j1 == j2 and k1 > k2)))):
            swap(i1, i2)
            swap(j1, j2)
            swap(k1, k2)
            
        self.edges[Edge(i1, j1, k1, i2, j2, k2)] = vid

    # addtovertices: add v to sequence of vertices
    def addtovertices(mut self, ref v : Vertex):
        self.vertices.append(v)

    def addtotriangles(mut self, t : Triangle):
        self.triangles.append(t)                
    
    def triproc(mut self, i1 : Int32, i2 : Int32, i3 : Int32) -> Int32:
        var t : Triangle = Triangle(i1, i2, i3)
        if not self.lefthanded: swap(t.i2, t.i3)
        
        self.addtotriangles(t)
        return 1

    def dotet(mut self, cube : Cube, c1 : Int32, c2 : Int32, c3 : Int32, c4 : Int32) raises -> Int32:
        var (a, b, c, d) = (
            cube.corners[c1], 
            cube.corners[c2], 
            cube.corners[c3], 
            cube.corners[c4]
        )
        var (apos, bpos, cpos, dpos) = (
            a.value > 0.0, 
            b.value > 0.0, 
            c.value > 0.0, 
            d.value > 0.0
        )

        var index : Int32 = 0
        if apos: index += 8
        if bpos: index += 4
        if cpos: index += 2
        if dpos: index += 1

        # index is now 4-bit number representing one of the 16 possible cases */
        var (e1, e2, e3, e4, e5, e6) = (Int32(0), Int32(0), Int32(0), Int32(0), Int32(0), Int32(0))

        if apos != bpos:  e1 = self.vertid(a, b)
        if apos != cpos:  e2 = self.vertid(a, c)
        if apos != dpos:  e3 = self.vertid(a, d)
        if bpos != cpos:  e4 = self.vertid(b, c)
        if bpos != dpos:  e5 = self.vertid(b, d)
        if cpos != dpos:  e6 = self.vertid(c, d)
          
        # 14 productive tetrahedral cases (0000 and 1111 do not yield polygons)
        if index == 1:      return self.triproc(e5, e6, e3)
        elif index == 2:    return self.triproc(e2, e6, e4)
        elif index == 3:    return self.triproc(e3, e5, e4) and self.triproc(e3, e4, e2)
        elif index == 4:    return self.triproc(e1, e4, e5)
        elif index == 5:    return self.triproc(e3, e1, e4) and self.triproc(e3, e4, e6)
        elif index == 6:    return self.triproc(e1, e2, e6) and self.triproc(e1, e6, e5)
        elif index == 7:    return self.triproc(e1, e2, e3)
        elif index == 8:    return self.triproc(e1, e3, e2)
        elif index == 9:    return self.triproc(e1, e5, e6) and self.triproc(e1, e6, e2)
        elif index == 10:   return self.triproc(e1, e3, e6) and self.triproc(e1, e6, e4)
        elif index == 11:   return self.triproc(e1, e5, e4)
        elif index == 12:   return self.triproc(e3, e2, e4) and self.triproc(e3, e4, e5)
        elif index == 13:   return self.triproc(e6, e2, e4)
        elif index == 14:   return self.triproc(e5, e3, e6)

        return 1

    # # getedge: return vertex id for edge; return -1 if not set 
    def getedge(mut self, _i1 : Int32, _j1 : Int32, _k1 : Int32, _i2 : Int32, _j2 : Int32, _k2 : Int32) raises -> Int32:
    
      var (i1, j1, k1) = (_i1, _j1, _k1)
      var (i2, j2, k2) = (_i2, _j2, _k2)
      
      if i1 > i2 or (i1 == i2 and (j1 > j2 or (j1 == j2 and k1 > k2))):
        swap(i1, i2)
        swap(j1, j2)
        swap(k1, k2)
      
      var edge = Edge(i1, j1, k1, i2, j2, k2)

      if edge in self.edges:
        return self.edges[edge]
      return -1

    def converge(mut self,  p1 : Point, p2 : Point, v : Float32) -> Point:
      var i = 0
      var pos : Point
      var neg : Point      

      if v < 0:  pos=p2; neg=p1
      else:      pos=p1; neg=p2

      while True:
        var p = pos.mid(neg) # mid point
        
        if i == RES: return p

        if self.implicit_func(p.x, p.y, p.z) > 0.0: pos = p
        else: neg = p
   
        i += 1

    def polygonize(mut self, mode:Int32 = TET) raises:
        var noabort : Int32

        self.makecubetable()
        
        var in_test  = self.find(True, self.start.x, self.start.y, self.start.z)
        var out_test = self.find(False, self.start.x, self.start.y, self.start.z)
        
        if not in_test.ok or not out_test.ok:
            raise Error("can't find starting point")

        self.start = self.converge(in_test.p, out_test.p, in_test.value)

        # push initial cube on stack
        self.cubes.append(Cube(0,0,0))

        # set corners initial cube
        for n in range(8):            
            var corner = self.setcorner(BIT(Int32(n),2), BIT(Int32(n),1), BIT(Int32(n),0))
            self.cubes[0].corners[n] = corner
        
        self.vertices = Vertices()
        _ = self.setcenter(0, 0, 0)
       
        var i = 0
        while i < len(self.cubes): # process active cubes till none left
                 
            var c = self.cubes[i].copy()

            if mode == TET:
                noabort = self.dotet(c, LBN, LTN, RBN, LBF) and \
                          self.dotet(c, RTN, LTN, LBF, RBN) and \
                          self.dotet(c, RTN, LTN, LTF, LBF) and \
                          self.dotet(c, RTN, RBN, LBF, RBF) and \
                          self.dotet(c, RTN, LBF, LTF, RBF) and \
                          self.dotet(c, RTN, LTF, RTF, RBF)
            else:
                noabort = self.docube(c)
            
            if not noabort: raise Error("polygonize, noabort==0, aborted")           
            
            # test six face directions, maybe add to stack:
            self.testface(c.i - 1, c.j, c.k, c, L, LBN, LBF, LTN, LTF)
            self.testface(c.i + 1, c.j, c.k, c, R, RBN, RBF, RTN, RTF)
            self.testface(c.i, c.j - 1, c.k, c, B, LBN, LBF, RBN, RBF)
            self.testface(c.i, c.j + 1, c.k, c, T, LTN, LTF, RTN, RTF)
            self.testface(c.i, c.j, c.k - 1, c, N, LBN, LTN, RBN, RTN)
            self.testface(c.i, c.j, c.k + 1, c, F, LBF, LTF, RBF, RTF)

            i += 1 # test face may add cubes to the end of self.cubes
            
    def write_ply(self, file_name : String) raises:
        with open(file_name, "w") as f:
            f.write("ply\n")
            f.write("format ascii 1.0\n")
            f.write("comment polygonize generated\n")
            f.write(t"element vertex {len(self.vertices)}\n")
            f.write("property float x\n")
            f.write("property float y\n")
            f.write("property float z\n")
            f.write("property float nx\n")
            f.write("property float ny\n")
            f.write("property float nz\n")
            f.write(t"element face {len(self.triangles)}\n")
            f.write("property list uchar int vertex_indices\n")
            f.write("end_header\n")
            for v in self.vertices:
                f.write(t"{v.position.x} {v.position.y} {v.position.z} {v.normal.x} {v.normal.y} {v.normal.z}\n")
            for t in self.triangles:
                f.write(t"3 {t.i1} {t.i2} {t.i3}\n")

    # flattern trigs & coords ( vertices, normals )
    def flattern_triangles(self) -> List[Int32]:
        var faces = List[Int32]() # flattern trigs
        for t in self.triangles: faces.extend([t.i1, t.i2, t.i3])
        return faces^
    
    def flatten_vertices(self) -> List[Float32]:
        var vertices = List[Float32]() # flatten verts
        for v in self.vertices: vertices.extend(v.position.as_array())
        return vertices^
    
    def flatten_normals(self) -> List[Float32]:
        var normals = List[Float32]() # flatten normals
        for v in self.vertices: normals.extend(v.normal.as_array())
        return normals^

    def scale_coords(mut self):
        var max_coord = Float32(0.0)
        for v in self.vertices:
            max_coord = max(max_coord, v.position.max())
        if max_coord > 0.0:
            for ref v in self.vertices: v.position /= max_coord

# helper fn
def polygonize(
    ifunc : ImplicitFuncDef, 
    bounds : Int32, 
    size : Float32, 
    x : Float32 = 0, 
    y : Float32 = 0, 
    z : Float32 = 0, 
    mode : Int32 = TET
) raises -> Tuple[List[Float32], List[Float32], List[Int32]]:

    var p = Polygonizer(ifunc, size, bounds, x, y, z, mode)
    p.polygonize()
    p.scale_coords()

    var faces    = p.flattern_triangles()
    var vertices = p.flatten_vertices()
    var normals  = p.flatten_normals()

    return (vertices^, normals^, faces^)
    
#python bindings

# mojo build -O3 polygonizer.mojo --emit shared-lib -o polygonizer$(PY_SUFFIX) 
from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder
from std.python.numpy import copy_to_numpy_array, from_numpy_array
#

def py_polygonize(_fn_id: PythonObject, _bounds : PythonObject, _size : PythonObject) -> PythonObject:

    try:
        var fn_id = Int(py=_fn_id)
        var bounds = Int32(py=_bounds)
        var size = Float32(py=_size)

        var defs = materialize[ImplicitDefs]()

        ref (vertices, normals, faces) = polygonize(defs[fn_id % len(defs)], bounds, size)
        # convert to numpy arrays (vertices, normals, faces - trigs) in [n,3] shape
        var vertices_np = copy_to_numpy_array[DType.float32](vertices).reshape(-1,3) # x,y,z coords
        var normals_np  = copy_to_numpy_array[DType.float32](normals).reshape(-1,3)  # x,y,z coords
        var faces_np    = copy_to_numpy_array[DType.int32](faces).reshape(-1,3)      # trigs
        
        # return as python object
        return Python.list(vertices_np, normals_np, faces_np)
    except e:
        print("py_polygonize: Error polygonizing", e)
        try:
            return Python.list([], [], [])
        except:
            print("py_polygonize: Error creating empty list")
            return PythonObject()
    
# python module init
@export
def PyInit_polygonizer() abi("C") -> PythonObject:
    """Initialize the polygonizer module."""
    try:
        var builder = PythonModuleBuilder("polygonizer")
        builder.def_function[py_polygonize]("polygonize", "Generate a polygonized mesh for an implicit function\nparams: fn_id : Int, bounds : Int, size : Float32")
        return builder.finalize()
    except:
        print("PyInit_polygonizer: Error building module polygonizer")
        return None

# test  
def t01() raises:
    print("polygonizing test")
    var implicits = materialize[ImplicitFuncs]()
    var defs = materialize[ImplicitDefs]()

    for i in range(len(implicits)):        

        var p = Polygonizer(implicit_func=defs[i], size=implicits[i].size, bounds=implicits[i].bounds)
    
        var lap = perf_counter()
        try:
            p.polygonize()
        except e:
            print("Error: ", e)
            
        print(implicits[i].name, " " * (20-min(20,implicits[i].name.byte_length()))," lap: ", Int32(1000*(perf_counter() - lap)), " ms")

        p.write_ply(String(t"ply/{implicits[i].name}.ply"))

def t02() raises:
    print("polygonizing test")
    var implicits = materialize[ImplicitFuncs]()
    var defs = materialize[ImplicitDefs]()

    var i = 1    

    var p = Polygonizer(implicit_func=defs[implicits[i].func_id], size=implicits[i].size, bounds=implicits[i].bounds)
    
    var lap = perf_counter()
    try:
        p.polygonize()
    except e:
        print("Error: ", e)
        
    print(implicits[i].name, " " * (20-min(20,implicits[i].name.byte_length()))," lap: ", Int32(1000*(perf_counter() - lap)), " ms")

    p.write_ply(String(t"ply/{implicits[i].name}.ply"))


# def main() raises:   t02()