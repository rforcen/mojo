# File: halfedge.mojo
# Author: robertoforcen@gmail.com
# Date: 2026-10-06
# Brief: Half-edge data structure for 3D mesh representation, storing vertex, face, and
#        adjacency information (next, prev, opposite) for efficient mesh traversal.
#
from vertex import Vertex, VertexPtr
from face import FacePtr
from optpnt import OptPnt
from mempool import MemPool
#
comptime HalfEdgePtr[dtype : DType] = OptPnt[HalfEdge[dtype]]

@fieldwise_init
struct HalfEdge[T:DType](Defaultable, ImplicitlyCopyable, Copyable, Writable):
    var vertex : VertexPtr[Self.T]
    var face : FacePtr[Self.T]
    
    var next : HalfEdgePtr[Self.T]
    var prev : HalfEdgePtr[Self.T]
    var opposite : HalfEdgePtr[Self.T]

    def __init__(out self): self = Self(None, None, None, None, None)
    def __init__(out self, *, copy : Self):
        self.vertex = copy.vertex
        self.face = copy.face
        self.next = copy.next
        self.prev = copy.prev
        self.opposite = copy.opposite
    def __init__(out self, vertex : VertexPtr[Self.T], face : FacePtr[Self.T]): self = Self(vertex, face, None, None, None)
    def __init__(out self, vertex : VertexPtr[Self.T]): self = Self(vertex, None, None, None, None)

    def ptr(mut self) -> HalfEdgePtr[Self.T]: return HalfEdgePtr[Self.T](Pointer(to=self).unsafe_origin_cast[MutUntrackedOrigin]())    
    
    def getNext(self) -> HalfEdgePtr[Self.T]: return self.next
    def setNext(mut self, mut next : HalfEdgePtr[Self.T]): self.next = next
    def setPrev(mut self, mut prev : HalfEdgePtr[Self.T]): self.prev = prev
    def getFace(self) -> FacePtr[Self.T]: return self.face
    def getOpposite(self) -> HalfEdgePtr[Self.T]: return self.opposite
    def setOpposite(mut self, opposite : HalfEdgePtr[Self.T]) raises: 
        self.opposite = opposite
        opposite[].opposite = self.ptr()
    def head(self) -> VertexPtr[Self.T]: return self.vertex
    def tail(self) -> VertexPtr[Self.T]: 
        return None if not self.prev else self.prev[].vertex
    def oppositeFace(self) -> FacePtr[Self.T]: 
        return None if not self.opposite else self.opposite[].face
    def getVertex(self) -> Vertex:  return self.vertex[]
    @staticmethod
    def newHalfEdge(mut mp : MemPool, vertex : VertexPtr[Self.T], face : FacePtr[Self.T]) -> HalfEdgePtr[Self.T]: 
        return HalfEdgePtr[Self.T](mp.newOpt[HalfEdge[Self.T]](), HalfEdge[Self.T](vertex, face))

    def write_to(self, mut writer: Some[Writer]):  
        writer.write(String(t"HalfEdge(vertex={self.vertex}, face={self.face}, next={self.next}, prev={self.prev}, opposite={self.opposite})"))
#
def main():
    var h = HalfEdge[f32]()
    print(h.vertex, h.face)