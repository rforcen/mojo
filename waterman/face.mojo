# File: face.mojo
# Author: robertoforcen@gmail.com
# Date: 2026-10-06
# Brief: Face structure for 3D mesh with half-edge data structure, supporting triangle creation,
#        normal/centroid computation, and face merging operations for convex hull algorithms.
#
from std.math import abs
#
from vector3d import Vector3d, f32
from halfedge import HalfEdgePtr, HalfEdge
from vertex import Vertex, VertexPtr
from mempool import MemPool
from optpnt import OptPnt
#
comptime FacePtr[dtype : DType] = OptPnt[Face[dtype]]

comptime VISIBLE    = 1
comptime NON_CONVEX = 2
comptime DELETED    = 3

@fieldwise_init
struct Face[T : DType](Defaultable, ImplicitlyCopyable, Copyable, Writable):
    var he0 : HalfEdgePtr[Self.T]
    var area : Scalar[Self.T]
    var planeOffset : Scalar[Self.T]
    var numVerts : Int
    var next : FacePtr[Self.T]
    var mark : Int
    var outside : VertexPtr[Self.T]
    var normal : Vector3d[Self.T]
    var centroid : Vector3d[Self.T]

    def __init__(out self): self = Self(None, 0.0, 0.0, 0, None, VISIBLE, None, Vector3d[Self.T](), Vector3d[Self.T]())

    def __init__(out self, *, copy : Self): 
        self.he0 = copy.he0
        self.area = copy.area
        self.planeOffset = copy.planeOffset
        self.numVerts = copy.numVerts
        self.next = copy.next
        self.mark = copy.mark
        self.outside = copy.outside
        self.normal = copy.normal
        self.centroid = copy.centroid   

    def __init__(out self, p : Pointer[Face[Self.T], MutUntrackedOrigin]): 
        p[] = Face[Self.T]()
        self = p[]
        
    def ptr(mut self) -> FacePtr[Self.T]:
        return FacePtr(Pointer(to=self).unsafe_origin_cast[MutUntrackedOrigin]())
    
    # optional pointers must be passed as ref or mut
    @staticmethod 
    def createTrig(mut mp: MemPool,  vt0 : VertexPtr[Self.T], vt1 : VertexPtr[Self.T], vt2 : VertexPtr[Self.T]) raises -> FacePtr[Self.T]: 
        # print("** create trig", vt0, vt1, vt2)

        var face = FacePtr[Self.T](mp.newOpt[Face[Self.T]]())        

        var he0 = HalfEdge.newHalfEdge(mp, vt0, face)
        var he1 = HalfEdge.newHalfEdge(mp, vt1, face)
        var he2 = HalfEdge.newHalfEdge(mp, vt2, face)

        he0[].prev = he2 # thread
        he0[].next = he1
        he1[].prev = he0
        he1[].next = he2
        he2[].prev = he1
        he2[].next = he0

        face[].he0 = he0
        face[].computeNormalCentroid()      

        return face

    
    def computeCentroid(mut self):
        self.centroid.setZero()

        var he = self.he0

        while True:            
            self.centroid += he[].head()[].pnt
            he = he[].next           
            if he == self.he0: break

        self.centroid /= Scalar[Self.T](self.numVerts)
        

    def computeNormal(mut self):
        var he1 = self.he0[].next
        var he2 = he1[].next

        var p0 = self.he0[].head()[].pnt
        var p2 = he1[].head()[].pnt

        var d2 = p2 - p0
        self.normal = Vector3d[Self.T]()       

        self.numVerts = 2

        # print("** compute normal he2, self.he0:", he2, self.he0, he2[].head())

        while he2 != self.he0:
            var d1 = d2

            p2 = he2[].head()[].pnt
            d2 = p2 - p0

            self.normal += d1.cross(d2)

            # he1 = he2
            he2 = he2[].next

            self.numVerts+=1
        
        self.area = self.normal.norm()
        self.normal /= self.area

        # print("** normal", self.normal, ", numVerts:", self.numVerts)

    def computeNormalCentroid(mut self) raises:
        self.computeNormal()
        self.computeCentroid()

        self.planeOffset = self.normal.dot(self.centroid)
        var numv = 0

        var he = self.he0
        while True:
            numv += 1
            he = he[].next
            
            if he == self.he0:  break
		
        if numv != self.numVerts:
            print("compute centroid: numVerts=", self.numVerts, " should be ", numv)
            raise Error("#### -> face numVerts mismatch")
    
    def getEdge(self, _i: Int) -> HalfEdgePtr[Self.T]:
        var i = _i

        var he = self.he0
        while i > 0:
            he = he[].next
            i -= 1
        while i < 0:
            he = he[].prev
            i += 1
        
        return he

    def getFirstEdge(self) -> HalfEdgePtr[Self.T]:
        return self.he0

    def distanceToPlane(self, p: Vector3d[Self.T]) -> Scalar[Self.T]:
        var d = self.normal.dot(p) - self.planeOffset
        # print("** distanceToPlane:", d, "normal:", self.normal, "p:", p, "plane offset:", self.planeOffset)
        return d

    def numVertices(self) -> Int:
        return self.numVerts

    def getCentroid(self) -> Vector3d[Self.T]: return self.centroid

    def connectHalfEdges(mut self, hedgePrev: HalfEdgePtr[Self.T], hedge: HalfEdgePtr[Self.T]) raises -> FacePtr[Self.T]:
        var discardedFace: FacePtr[Self.T] = None

        # print("** connectHalfEdges: oppface", hedgePrev[].oppositeFace()[].normal)

        if hedgePrev[].oppositeFace() == hedge[].oppositeFace(): # then there is a redundant edge that we can get rid off
            
            var oppFace  : FacePtr[Self.T] = hedge[].oppositeFace()
            var hedgeOpp : HalfEdgePtr[Self.T]

            if hedgePrev == self.he0: 
                self.he0 = hedge
            
            if oppFace[].numVertices() == 3: # then we can get rid of the opposite face altogether
                hedgeOpp = hedge[].getOpposite()[].prev[].getOpposite()

                oppFace[].mark = DELETED
                discardedFace = oppFace
            else:
                hedgeOpp = hedge[].getOpposite()[].next

                if oppFace[].he0 == hedgeOpp[].prev:
                    oppFace[].he0 = hedgeOpp
                
                hedgeOpp[].prev = hedgeOpp[].prev[].prev
                hedgeOpp[].prev[].next = hedgeOpp
            
            hedge[].prev = hedgePrev[].prev
            hedge[].prev[].next = hedge

            hedge[].opposite = hedgeOpp
            hedgeOpp[].opposite = hedge

            # oppFace was modified, so need to recompute
            oppFace[].computeNormalCentroid()
            
        else:
            hedgePrev[].next = hedge
            hedge[].prev = hedgePrev

        # print("** connectHalfEdges: end")

        return discardedFace
    
    def checkConsistency(self) raises:
        # do a sanity check on the face
        var hedge = self.he0
        var maxd = Scalar[Self.T](0)
        var numv = 0

        if self.numVerts < 3:
            raise Error("#### degenerated face #####")
	
        while True:
            var hedgeOpp = hedge[].getOpposite()
            if not hedgeOpp: raise Error("#### -> unreflected half edge")
            elif hedgeOpp[].getOpposite() != hedge:
                raise Error("#### -> opposite half edge has opposite")
            if hedgeOpp[].head() != hedge[].tail() or
                hedge[].head() != hedgeOpp[].tail():
                raise Error("#### -> half edge reflected by")
            
            var oppFace = hedgeOpp[].face
            if not oppFace:
                raise Error("#### -> no face on half edge")
            elif oppFace[].mark == DELETED:
                raise Error("#### -> opposite face not on hull")
            
            var d = abs(self.distanceToPlane(hedge[].head()[].pnt))
            if d > maxd:
                maxd = d
            
            numv += 1
            hedge = hedge[].next

            if hedge == self.he0:
                break
            
        if numv != self.numVerts:
            raise Error(t"#### -> face, numVerts={self.numVerts} should be {numv}")

    def mergeAdjacentFace(mut self, _face: FacePtr[Self.T], hedgeAdj: HalfEdgePtr[Self.T], mut discarded: List[FacePtr[Self.T]]) raises -> Int:
        # print("** face.mergeAdjacentFace start, numVerts:", self.numVerts)
        var oppFace = hedgeAdj[].oppositeFace()
        var numDiscarded = 0
        discarded[numDiscarded] = oppFace
        numDiscarded+=1
        oppFace[].mark = DELETED

        var hedgeOpp = hedgeAdj[].getOpposite()

        var hedgeAdjPrev = hedgeAdj[].prev
        var hedgeAdjNext = hedgeAdj[].next
        var hedgeOppPrev = hedgeOpp[].prev
        var hedgeOppNext = hedgeOpp[].next

        while hedgeAdjPrev[].oppositeFace() == oppFace:
            hedgeAdjPrev = hedgeAdjPrev[].prev
            hedgeOppNext = hedgeOppNext[].next

        while hedgeAdjNext[].oppositeFace() == oppFace:
            hedgeOppPrev = hedgeOppPrev[].prev
            hedgeAdjNext = hedgeAdjNext[].next

        var hedge = hedgeOppNext
        while hedge != hedgeOppPrev[].next:            
            hedge[].face = _face 
            hedge = hedge[].next

        if hedgeAdj == self.he0:
            self.he0 = hedgeAdjNext
        

        # handle the half edges at the head
        var discardedFace = self.connectHalfEdges(hedgeOppPrev, hedgeAdjNext)

        if discardedFace:
            discarded[numDiscarded] = discardedFace
            numDiscarded+=1
        

        # handle the half edges at the tail
        discardedFace = self.connectHalfEdges(hedgeAdjPrev, hedgeOppNext)
        if discardedFace:
            discarded[numDiscarded] = discardedFace
            numDiscarded+=1

        # print("** face.mergeAdjacentFace before check, numDiscarded:", numDiscarded, ", numVerts:", self.numVerts)

        self.computeNormalCentroid()
        self.checkConsistency()

        # print("** face.mergeAdjacentFace end", numDiscarded)

        return numDiscarded

    def write_to(self, mut writer: Some[Writer]):  
        writer.write(String(t"face: he0:{self.he0}, next:{self.next},  numVerts={self.numVerts}, area={self.area}, planeOffset={self.planeOffset}, numVerts={self.numVerts}, mark={self.mark}, outside:{self.outside}, normal:{self.normal}, centroid:{self.centroid}"))
    

#
def test() raises:
    var mp = MemPool()
    var vt0 = VertexPtr(mp.newOpt[Vertex]())
    var vt1 = VertexPtr(mp.newOpt[Vertex]())
    var vt2 = VertexPtr(mp.newOpt[Vertex]())

    vt0[] = Vertex(Vector3d[Self.T](0.0, 0.0, 0.0), 0)
    vt1[] = Vertex(Vector3d[Self.T](1.0, 0.0, 0.0), 1)
    vt2[] = Vertex(Vector3d[Self.T](0.0, 1.0, 0.0), 2)
    
    var face = Face.createTrig(mp, vt0, vt1, vt2)
    