# File: vertex.mojo
# Author: robertoforcen@gmail.com
# Date: 2026-10-06
# Brief: Vertex structure for 3D mesh representation, storing position, index, and adjacency
#        information (prev, next, face) for use in half-edge data structures.
#
from vector3d import Vector3d
from face import Face, FacePtr
from mempool import MemPool
from optpnt import OptPnt

comptime VertexPtr[dtype: DType] = OptPnt[Vertex[dtype]]

@fieldwise_init
struct Vertex[T:DType](ImplicitlyCopyable, Writable, Defaultable, Copyable):
    var pnt : Vector3d[Self.T]
    var index : Int
    var prev : VertexPtr[Self.T]
    var next : VertexPtr[Self.T]
    var face : FacePtr[Self.T]

    def __init__(out self):
        self.pnt = Vector3d[Self.T]()
        self.index = 0
        self.prev = None    
        self.next = None
        self.face = None
        
    def __init__(out self, pnt : Vector3d[Self.T], index : Int):
        self = Self()
        self.pnt = pnt
        self.index = index
    
    def ptr(mut self) -> VertexPtr[Self.T]:
        return VertexPtr[Self.T](Pointer(to=self).unsafe_origin_cast[MutUntrackedOrigin]())
        
    def write_to(self, mut writer: Some[Writer]):  writer.write(t"({self.pnt}, {self.index})")

    @staticmethod
    def newVertex[d:DType](mut mp : MemPool, v :Vertex[d]) -> VertexPtr[d]:        
        return VertexPtr[d](mp.newOpt[Vertex[d]](), v)

