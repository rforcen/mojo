# File: quickhull3d.mojo
# Author: robertoforcen@gmail.com
# Date: 2026-10-06
# Brief: QuickHull3D algorithm implementation for convex hull generation from 3D point sets,
#        supporting both f32 and f64 precision with Python bindings for NumPy integration.
#
from vector3d import Vector3d, FLOAT_PREC_F32, FLOAT_PREC_F64
from vertex import Vertex, VertexPtr
from halfedge import HalfEdge, HalfEdgePtr
from face import Face, FacePtr, VISIBLE, NON_CONVEX, DELETED
from facelist import FaceList
from vertexlist import VertexList
from mempool import MemPool
from waterman import watermancoords

#
from std.math import sqrt
from  std.testing.prop import Rng
from std.time import perf_counter

#
comptime CLOCKWISE                 = 0x1
comptime INDEXED_FROM_ONE          = 0x2
comptime INDEXED_FROM_ZERO         = 0x4
comptime POINT_RELATIVE            = 0x8
comptime AUTOMATIC_TOLERANCE       = -1
comptime NONCONVEX_WRT_LARGER_FACE = 1
comptime NONCONVEX                 = 2
#
# QuickHull3D
@fieldwise_init
struct QuickHull3D[T:DType]:
    var charLength         : Scalar[Self.T]
    var pointBuffer        : List[VertexPtr[Self.T]]    
    var vertexPointIndices : List[Int]
    var faces              : List[FacePtr[Self.T]]    
    var he                 : List[HalfEdgePtr[Self.T]]    
    var horizon            : List[HalfEdgePtr[Self.T]]

    var numVertices        : Int
    var numPoints          : Int
    var explicitTolerance  : Scalar[Self.T]
    var tolerance          : Scalar[Self.T]
    var discardedFaces     : List[FacePtr[Self.T]]
    var maxVtxs            : List[VertexPtr[Self.T]]
    var minVtxs            : List[VertexPtr[Self.T]]
    var newFaces           : FaceList[Self.T]
    var unclaimed          : VertexList[Self.T]
    var claimed            : VertexList[Self.T]

    var mp                 : MemPool    

    def __init__(out self):
        self.charLength = 0.0
        self.pointBuffer = List[VertexPtr[Self.T]]()
        self.vertexPointIndices = List[Int]()

        self.faces = List[FacePtr[Self.T]]()
        
        self.he = List[HalfEdgePtr[Self.T]]()
        
        self.horizon = List[HalfEdgePtr[Self.T]]()
        self.numVertices = 0
        self.numPoints = 0
        self.explicitTolerance = Scalar[Self.T](AUTOMATIC_TOLERANCE)
        self.tolerance = Scalar[Self.T](0.0)
        self.discardedFaces = List[FacePtr[Self.T]](length=3, fill=None)
        self.maxVtxs = List[VertexPtr[Self.T]](length=3, fill=None)
        self.minVtxs = List[VertexPtr[Self.T]](length=3, fill=None)
        self.newFaces = FaceList[Self.T]()
        self.unclaimed = VertexList[Self.T]()
        self.claimed = VertexList[Self.T]()

        self.mp = MemPool()
    
    def __init__(out self, coords : List[Vector3d[Self.T]]) raises:
        self = Self()    
        self.setCoords(coords)       

    def setCoords(mut self, coords: List[Vector3d[Self.T]]) raises:
        if len(coords) < 4: raise Error("coords length < 4 ")

        self.vertexPointIndices = List[Int](length=len(coords), fill=0)
        self.numPoints = len(coords)

        self.pointBuffer.clear()
        for i, c in enumerate(coords): 
            var coord = c
            self.pointBuffer.append(Vertex[Self.T].newVertex(self.mp, Vertex[Self.T](coord, i))) 

    def buildHull(mut self) raises:
        self.calcMaxMin()
        self.createInitialSimplex()

        var eyeVtx = self.nextPointToAdd()      
        while eyeVtx != None:
            self.addPointToHull(eyeVtx)
            eyeVtx = self.nextPointToAdd()        
        
        self.reindexFacesVertices()


    def addPointToFace(mut self, vtx: VertexPtr[Self.T], face: FacePtr[Self.T]):
        vtx[].face = face

        if not face[].outside:
            self.claimed.Add(vtx)
        else:
            self.claimed.InsertBefore(vtx, face[].outside)
        
        face[].outside = vtx
        
    def removePointFromFace(mut self, mut vtx: VertexPtr[Self.T], face: FacePtr[Self.T]):
        if vtx == face[].outside:
            if vtx[].next != None and vtx[].next[].face == face:
                face[].outside = vtx[].next
            else:
                face[].outside = None
        self.claimed.Delete(vtx)

    def removeAllPointsFromFace(mut self, face: FacePtr[Self.T]) -> VertexPtr[Self.T]:
        if face[].outside == None:
            return None
        
        var end = face[].outside
        while end[].next != None and end[].next[].face == face:
            end = end[].next
        
        self.claimed.Delete2(face[].outside, end)
        end[].next = None

        return face[].outside

    def calcMaxMin(mut self):

        for i in range(3):
            self.maxVtxs[i] = self.pointBuffer[0]
            self.minVtxs[i] = self.pointBuffer[0]

        var _max = self.pointBuffer[0][].pnt
        var _min = _max
        
        for i in range(1, self.numPoints):
            var pnt = self.pointBuffer[i][].pnt

            for j in range(3):
                if pnt[j] > _max[j]:
                    _max[j] = pnt[j]
                    self.maxVtxs[j] = self.pointBuffer[i]
                else:
                    _min[j] = pnt[j]
                    self.minVtxs[j] = self.pointBuffer[i]
               

        self.charLength = (_max - _min).max()

        if self.explicitTolerance == AUTOMATIC_TOLERANCE:
            var mf : Scalar[Self.T] = Scalar[Self.T](1.0)

            if Self.T == DType.float32:
                mf = Scalar[Self.T](3.0 * FLOAT_PREC_F32)
            elif Self.T == DType.float64:
                mf = Scalar[Self.T](3.0 * FLOAT_PREC_F64)

            self.tolerance = mf * (max(abs(_max.x()), abs(_min.x())) +
                    max(abs(_max.y()), abs(_min.y())) +
                    max(abs(_max.z()), abs(_min.z())))
        else:
            self.tolerance = self.explicitTolerance

    # Creates the initial simplex from which the hull will be built.
    def createInitialSimplex(mut self) raises:
        var _max = Scalar[Self.T](0.0)
        var imax = 0

        for i in range(3):
            var diff = self.maxVtxs[i][].pnt[i] - self.minVtxs[i][].pnt[i]
            if diff > _max:
                _max = diff
                imax = i

        if _max <= self.tolerance:
            raise Error("Quickhull3d, createInitialSimplex, Input points appear to be coincident")

        # set first two vertices to be those with the greatest
        # one dimensional separation
        var vtx0 = self.maxVtxs[imax]
        var vtx1 = self.minVtxs[imax]
        var vtx2 : VertexPtr[Self.T] = None
        var vtx3 : VertexPtr[Self.T] = None

        # set third vertex to be the vertex farthest from
        # the line between vtx0 and vtx1
        var u01    : Vector3d[Self.T]
        var diff02 : Vector3d[Self.T]
        var nrml   = Vector3d[Self.T]()
        var xprod  : Vector3d[Self.T]
        var maxSqr = Scalar[Self.T](0)
        
        u01 = vtx1[].pnt - vtx0[].pnt
        u01 = u01.normalize()
        
        for i in range(self.numPoints):
            diff02 = self.pointBuffer[i][].pnt - vtx0[].pnt
            xprod = u01.cross(diff02)
            var lenSqr = xprod.normSquared()
            if lenSqr > maxSqr and
                self.pointBuffer[i] != vtx0 and # paranoid
                self.pointBuffer[i] != vtx1:

                maxSqr = lenSqr
                vtx2 = self.pointBuffer[i][].ptr()
                nrml = xprod
            
        if sqrt(maxSqr) <= 100*self.tolerance: 
            raise Error("Quickhull3d, createInitialSimplex, Input points appear to be colinear")

        nrml = nrml.normalize()

        var maxDist = Scalar[Self.T](0)
        var d0 = vtx2[].pnt.dot(nrml)

        for i in range(self.numPoints):
            var dist = abs(self.pointBuffer[i][].pnt.dot(nrml) - d0)
            if dist > maxDist and
                self.pointBuffer[i] != vtx0 and # paranoid
                self.pointBuffer[i] != vtx1 and
                self.pointBuffer[i] != vtx2:

                maxDist = dist
                vtx3 = self.pointBuffer[i][].ptr()
            
        if abs(maxDist) <= 100 * self.tolerance: 
            raise Error("Quickhull3d, createInitialSimplex, Input points appear to be coplanar")

        # create tris 
        var tris = List[FacePtr[Self.T]](length=4, fill=None)
        
        if vtx3[].pnt.dot(nrml) - d0 < 0:
            tris[0] = Face.createTrig(self.mp, vtx0, vtx1, vtx2)
            tris[1] = Face.createTrig(self.mp, vtx3, vtx1, vtx0)
            tris[2] = Face.createTrig(self.mp, vtx3, vtx2, vtx1)
            tris[3] = Face.createTrig(self.mp, vtx3, vtx0, vtx2)

            for i in range(3):
                var k = (i + 1) % 3
                tris[i+1][].getEdge(1)[].setOpposite(tris[k+1][].getEdge(0))
                tris[i+1][].getEdge(2)[].setOpposite(tris[0][].getEdge(k))
        else:
            tris[0] = Face.createTrig(self.mp, vtx0, vtx2, vtx1)
            tris[1] = Face.createTrig(self.mp, vtx3, vtx0, vtx1)
            tris[2] = Face.createTrig(self.mp, vtx3, vtx1, vtx2)
            tris[3] = Face.createTrig(self.mp, vtx3, vtx2, vtx0)

            for i in range(3):
                var k = (i + 1) % 3                
                tris[i+1][].getEdge(0)[].setOpposite(tris[k+1][].getEdge(1))
                tris[i+1][].getEdge(2)[].setOpposite(tris[0][].getEdge((3 - i) % 3))
        
        self.faces.extend(tris.copy())

        for k in range(len(self.pointBuffer)):
            
            if self.pointBuffer[k] in [vtx0, vtx1, vtx2, vtx3]:
                continue
                
            var maxDist = self.tolerance
            var maxFace : FacePtr[Self.T] = None

            for j in range(4):
                var dist = tris[j][].distanceToPlane(self.pointBuffer[k][].pnt)

                if dist > maxDist:
                    maxFace = tris[j]
                    maxDist = dist
            
            if maxFace is not None:      
                var v = self.pointBuffer[k]
                self.addPointToFace(v, maxFace)
        
    def getNumVertices(mut self) -> Int:
        return self.numVertices
        
    def getVertices(mut self) -> List[Vector3d[Self.T]]:
        var vtxs = List[Vector3d[Self.T]](capacity = self.numVertices)
        for i in range(self.numVertices):
            vtxs.append(self.pointBuffer[self.vertexPointIndices[i]][].pnt)
        return vtxs^

    def getVertexPointIndices(mut self) -> List[Int]:
        var indices = List[Int](capacity = self.numVertices)
        for i in range(self.numVertices):
            indices.append(self.vertexPointIndices[i])
        return indices^
    
    def getNumFaces(mut self) -> Int:
        return len(self.faces)
    
    def getFaces(mut self) -> List[List[Int]]:
        return self.getFacesIdxFlag(0)
    
    def getFacesIdxFlag(mut self, indexFlags: Int) -> List[List[Int]]:
        var allFaces = List[List[Int]](capacity = len(self.faces))

        for i, face in enumerate(self.faces):
            var faceIndices = List[Int](length=face[].numVertices(), fill=0)
            var fci = self.faces[i]
            self.getFaceIndices(faceIndices, fci, indexFlags)
            allFaces.append(faceIndices^)

        return allFaces^
    
    def getFaceIndices(mut self, mut indices: List[Int], face: FacePtr, flags: Int):
        var ccw = ((flags & CLOCKWISE) == 0)
        var indexedFromOne = ((flags & INDEXED_FROM_ONE) != 0)
        var pointRelative = ((flags & POINT_RELATIVE) != 0)

        var hedge = face[].he0
        var k = 0

        while True:
            var idx = hedge[].head()[].index
            if pointRelative:   idx = self.vertexPointIndices[idx]
            if indexedFromOne:  idx+=1
            
            indices[k] = idx
            k += 1

            if ccw:  hedge = hedge[].next
            else:    hedge = hedge[].prev

            if hedge == face[].he0:  break

    def resolveUnclaimedPoints(mut self):
        var vtxNext = self.unclaimed.First()
        var vtx = vtxNext
        
        while vtx != None:
            vtxNext = vtx[].next

            var maxDist = self.tolerance
            
            var maxFace : FacePtr[Self.T] = None
            var newFace = self.newFaces.first()

            while newFace != None:
                if newFace[].mark == VISIBLE:
                    var dist = newFace[].distanceToPlane(vtx[].pnt)
                    if dist > maxDist:
                        maxDist = dist
                        maxFace = newFace
                    if maxDist > 1000*self.tolerance:
                        break
                newFace = newFace[].next
            
            if maxFace != None:
                self.addPointToFace(vtx, maxFace)

            vtx = vtxNext

    def deleteFacePoints(mut self, face: FacePtr[Self.T], absorbingFace: FacePtr[Self.T]):
        var faceVtxs = self.removeAllPointsFromFace(face)

        if faceVtxs != None:
            if absorbingFace == None:
                self.unclaimed.AddAll(faceVtxs)
            else:
                var vtxNext = faceVtxs
                var vtx = vtxNext

                while vtxNext != None:
                    vtxNext = vtx[].next
                    var dist = absorbingFace[].distanceToPlane(vtx[].pnt)
                    if dist > Scalar[self.T](self.tolerance):
                        self.addPointToFace(vtx, absorbingFace)
                    else:
                        self.unclaimed.Add(vtx)

                    vtx = vtxNext

    def oppFaceDistance(self, he: HalfEdgePtr[Self.T]) -> Scalar[Self.T]:
        return he[].face[].distanceToPlane(he[].opposite[].face[].getCentroid())

    def doAdjacentMerge(mut self, face: FacePtr[Self.T], mergeType: Int) raises -> Bool:
        var hedge = face[].he0
        var convex = True
            
        while True:
            var oppFace = hedge[].opposite[].face
            var merge = False
            var dist1 = self.oppFaceDistance(hedge)
            var dist2 = self.oppFaceDistance(hedge[].opposite)

            if mergeType == NONCONVEX: # then merge faces if they are definitively non-convex
                if dist1 > -self.tolerance or dist2 > -self.tolerance:
                    merge = True
            else: # mergeType == NONCONVEX_WRT_LARGER_FACE
                # merge faces if they are parallel or non-convex
                # wrt to the larger face; otherwise, just mark
                # the face non-convex for the second pass.
                if face[].area > oppFace[].area:
                    if dist1 > -self.tolerance:
                        merge = True
                    elif dist2 > -self.tolerance:
                        convex = False
                else:
                    if dist2 > -self.tolerance:
                        merge = True
                    elif dist1 > -self.tolerance:
                        convex = False

            if merge:
                var numd = face[].mergeAdjacentFace(face, hedge, self.discardedFaces)
                for i in range(numd):
                    var df = self.discardedFaces[i]
                    self.deleteFacePoints(df, face)
                return True

            hedge = hedge[].next
            if hedge == face[].he0:
                break

        if not convex:
            face[].mark = NON_CONVEX
        return False

    def calculateHorizon(mut self, eyePnt: Vector3d[Self.T], mut edge0: HalfEdgePtr[Self.T], face: FacePtr[Self.T]):

        self.deleteFacePoints(face, None)
        face[].mark = DELETED
        
        var edge : HalfEdgePtr[Self.T]

        if not edge0:
            edge0 = face[].getEdge(0)
            edge = edge0
        else:
            edge = edge0[].getNext()
        
        while True:
            var oppFace = edge[].oppositeFace()
            if oppFace[].mark == VISIBLE:
                if oppFace[].distanceToPlane(eyePnt) > self.tolerance:
                    var opp = edge[].getOpposite()
                    self.calculateHorizon(eyePnt, opp, oppFace)
                else:
                    self.horizon.append(edge)

            edge = edge[].getNext()
            if edge == edge0:
                break

    def addAdjoiningFace(mut self, eyeVtx: VertexPtr[Self.T], he: HalfEdgePtr[Self.T]) raises -> HalfEdgePtr[Self.T]:
        # create a Face object
        var face = Face.createTrig(self.mp, eyeVtx, he[].tail(), he[].head())        
        self.faces.append(face)
        face[].getEdge(-1)[].setOpposite(he[].getOpposite())
        return face[].getEdge(0)       

    def addNewFaces(mut self, eyeVtx: VertexPtr[Self.T]) raises:
        # print("** addNewFaces")
        
        self.newFaces.clear()

        var hedgeSidePrev: HalfEdgePtr[Self.T] = None
        var hedgeSideBegin: HalfEdgePtr[Self.T] = None
        

        for h in self.horizon:
            var horizonHe = h
            var hedgeSide = self.addAdjoiningFace(eyeVtx, horizonHe)

            if hedgeSidePrev != None:
                hedgeSide[].next[].setOpposite(hedgeSidePrev)
            else:
                hedgeSideBegin = hedgeSide
            
            self.newFaces.add(hedgeSide[].getFace())
            hedgeSidePrev = hedgeSide
        
        hedgeSideBegin[].next[].setOpposite(hedgeSidePrev)

    def nextPointToAdd(mut self) -> VertexPtr[Self.T]:
        if not self.claimed.IsEmpty():
            var eyeFace = self.claimed.First()[].face
            var eyeVtx: VertexPtr[Self.T] = None
            var maxDist = Scalar[Self.T](0.0)
            var vtx = eyeFace[].outside

            while vtx != None and vtx[].face == eyeFace:
                var dist = eyeFace[].distanceToPlane(vtx[].pnt)
                if dist > maxDist:
                    maxDist = dist
                    eyeVtx = vtx
                vtx = vtx[].next
            return eyeVtx
        else:
            return None

    def addPointToHull(mut self, mut eyeVtx: VertexPtr[Self.T]) raises:
        self.horizon.clear()
        self.unclaimed = VertexList[Self.T]()

        self.removePointFromFace(eyeVtx, eyeVtx[].face)
        var edge0: HalfEdgePtr[Self.T] = None
        self.calculateHorizon(eyeVtx[].pnt, edge0, eyeVtx[].face)
        self.newFaces.clear()

        self.addNewFaces(eyeVtx)

        # first merge pass ... merge faces which are non-convex
        # as determined by the larger face

        var face = self.newFaces.first()
        while face != None:
            if face[].mark == VISIBLE:
                while self.doAdjacentMerge(face, NONCONVEX_WRT_LARGER_FACE):
                    pass
            face = face[].next

        # second merge pass ... merge faces which are non-convex
        # wrt either face
        face = self.newFaces.first()
        while face != None:
            if face[].mark == NON_CONVEX:
                face[].mark = VISIBLE
                while self.doAdjacentMerge(face, NONCONVEX):
                    pass
            face = face[].next

        self.resolveUnclaimedPoints()

    def markFaceVertices(mut self, face: FacePtr[Self.T], mark: Int):
        var he0 = face[].getFirstEdge()

        var he = he0
        while True:
            he[].head()[].index = mark
            he = he[].next

            if he == he0:
                break
 
    def reindexFacesVertices(mut self):
        for i in range(self.numPoints): self.pointBuffer[i][].index = -1
	
        # remove inactive faces and mark active vertices
        var newFaces = List[FacePtr[Self.T]]()

        for i in range(len(self.faces)):
            var face = self.faces[i]
            if face[].mark == VISIBLE:                
                newFaces.append(face)                
                self.markFaceVertices(face, 0)

        self.faces = newFaces^
        
        # reindex vertices
        self.numVertices = 0
        for i in range(self.numPoints):
            var vtx = self.pointBuffer[i]
            if vtx[].index == 0:
                self.vertexPointIndices[self.numVertices] = i
                vtx[].index = self.numVertices
                self.numVertices += 1

    def getColors(mut self) raises -> List[Vector3d[Self.T]]:
        def sigDigits(mut f: Scalar[Self.T], n: Int) -> Int: # n significant digits, loop solution is much faster than math one
            
            if f == 0 or n < 1: return 0
            
            var po10: Scalar[Self.T]
            var po100: Scalar[Self.T]
            
            if n == 1 or n == 2:
                po10 = 10.0
                po100 = 100.0
            elif n == 3:
                po10 = 100.0
                po100 = 1000.0
            elif n == 4:
                po10 = 1000.0
                po100 = 10000.0
            elif n == 5:
                po10 = 10000.0
                po100 = 100000.0
            else:
                po10 = Scalar[Self.T](10.0 ** (n - 1))
                po100 = po10 * 10
            
            if f >= po100:
                while f >= po100:
                    f /= 10.0
            elif f < po10:
                while f < po10:
                    f *= 10.0
            
            return Int(f)
        
        var rnd: Rng = Rng(seed=Int(perf_counter()))

        var colors = List[Vector3d[Self.T]]()
        var color_dict = Dict[Int, Vector3d[Self.T]]() # 3 digs or area | color
        
        var faces = self.getFaces()
        var vertices = self.getVertices()

        for face in faces:
            var normal = Vector3d.normal(vertices[face[0]], vertices[face[1]], vertices[face[2]]).normalize()
            
            var vsum = Vector3d[Self.T]() # calc area
            var vt : Vector3d[Self.T]

            var v1 = vertices[face[len(face)-2]]
            var v2 = vertices[face[len(face)-1]]

            for v in face:
                vt = v1.cross(v2)
                vsum += vt
                v1 = v2
                v2 = vertices[v]

            var area = Scalar[Self.T](abs(normal.dot(vsum)) / 2.0)
            var sf = sigDigits(area, 3) # 3 significant digits

            if sf not in color_dict:
                def rand() raises {mut rnd} -> Scalar[Self.T]: return rnd.rand_scalar[Self.T](min = Scalar[Self.T](0.0), max = Scalar[Self.T](1.0))

                color_dict[sf] = Vector3d(rand(), rand(), rand())

            colors.append(color_dict[sf])

        return colors^

# helper fn used in ui
def waterman_qhull3d[T:DType](rad : Scalar[T]) raises -> Tuple[List[List[Int]], List[Vector3d[T]], List[Vector3d[T]]]:
    var q = QuickHull3D[T](watermancoords[T](rad))
    q.buildHull()
    return (q.getFaces(), q.getVertices(), q.getColors())
    
#
# python binding: mojo build -O3 quickhull3d.mojo --emit shared-lib -o waterman$(PY_SUFFIX) 
#
from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder
from std.python.numpy import copy_to_numpy_array

# helpers
def py_waterman_qhull(_rad : PythonObject) raises -> PythonObject:
    var rad = Float32(py=_rad)

    var q = QuickHull3D[DType.float32](watermancoords[DType.float32](rad))
    q.buildHull()
    
    # create a flat f64 array with Vector3d f32 ones
    def flattern_coords(coords : List[Vector3d[DType.float32]]) -> List[Float64]:
        var result = List[Float64]()
        for c in coords: 
            result.append(Float64(c.x()))
            result.append(Float64(c.y()))
            result.append(Float64(c.z()))            
        return result^

    # from [[int]] to [len64, ix's...]
    def conv_faces(faces : List[List[Int]]) -> List[Int64]:
        var result = List[Int64]()
        for face in faces:  
            result.append(Int64(len(face)))
            for ix in face: result.append(Int64(ix))
        return result^
    
    var faces = q.getFaces()
    var vertexes = q.getVertices()    
    var colors = q.getColors()

    return Python.list(
        copy_to_numpy_array(conv_faces(faces)),
        copy_to_numpy_array(flattern_coords(vertexes)).reshape(-1,3),
        copy_to_numpy_array(flattern_coords(colors)).reshape(-1,3)
    )

# python module init
@export
def PyInit_waterman() abi("C") -> PythonObject:
    """Initialize the waterman module."""
    try:
        var builder = PythonModuleBuilder("waterman")
        builder.def_function[py_waterman_qhull]("waterman_qhull", "Generate a waterman qhull")
         
        return builder.finalize()
    except:
        print("PyInit_waterman: Error building module waterman")
        return None


# test

def test[T:DType]() raises:   
    print("quickhull 3d")

    var rad = Scalar[T](5.0)
    var coords = watermancoords[T](rad)
    print("coords length:", len(coords))
    var q = QuickHull3D(coords)
    q.buildHull()
    
    print("Hull built successfully")
    print(t"Number of vertices: {q.numVertices}")
    print(t"Number of faces: {len(q.faces)}")

    var faces = q.getFaces()
    var vertices = q.getVertices()    

    for face in faces:
        for ix in face:
            if ix >= len(vertices):
                print("ERROR: face index out of bounds")
                return
        print(face, end=":")
        for ix in face : print(vertices[ix], end=", ")
        print()

# def main() raises: test()