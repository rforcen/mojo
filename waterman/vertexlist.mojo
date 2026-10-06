# File: vertexlist.mojo
# Author: robertoforcen@gmail.com
# Date: 2026-10-06
# Brief: Linked list implementation for Vertex pointers, providing add, delete, insert,
#        and iteration operations for managing collections of vertices in mesh algorithms.
#
from vertex import VertexPtr

@fieldwise_init
struct VertexList[T:DType]:
    var head : VertexPtr[Self.T]
    var tail : VertexPtr[Self.T]

    def __init__(out self): self = Self(None, None)

    def Add(mut self, vtx : VertexPtr[Self.T]): 
        if not self.head:
            self.head = vtx
        else:
            self.tail[].next = vtx

        vtx[].prev = self.tail
        vtx[].next = None
        self.tail = vtx
    
    def AddAll(mut self, _vtx : VertexPtr[Self.T]):
        var vtx = _vtx

        if not self.head:
            self.head = vtx
        else:
            self.tail[].next = vtx

        vtx[].prev = self.tail
        while vtx[].next:
            vtx = vtx[].next
        self.tail = vtx
    
    def Delete(mut self, vtx : VertexPtr[Self.T]): 
        if not vtx[].prev:
            self.head = vtx[].next
        else:
            vtx[].prev[].next = vtx[].next
            
        if not vtx[].next:
            self.tail = vtx[].prev
        else:
            vtx[].next[].prev = vtx[].prev
    
    def Delete2(mut self, vtx1 : VertexPtr[Self.T], vtx2 : VertexPtr[Self.T]): 
        if not vtx1[].prev:
            self.head = vtx2[].next
        else:
            vtx1[].prev[].next = vtx2[].next

        if not vtx2[].next:
            self.tail = vtx1[].prev
        else:
            vtx2[].next[].prev = vtx1[].prev

    def InsertBefore(mut self, vtx : VertexPtr[Self.T], next : VertexPtr[Self.T]): 
        vtx[].prev = next[].prev
        if not next[].prev:
            self.head = vtx
        else:
            next[].prev[].next = vtx
        vtx[].next = next
        next[].prev = vtx
    
    def First(self) -> VertexPtr[Self.T]:
        return self.head
    
    def IsEmpty(self) -> Bool:
        return not self.head

    def len(self) -> Int:
        var count = 0
        var current = self.head
        while current:
            count += 1
            current = current[].next
        return count
#

def main():
    _ = VertexList[Float32]()