# File: facelist.mojo
# Author: robertoforcen@gmail.com
# Date: 2026-10-06
# Brief: Linked list implementation for Face pointers, providing add, clear, and iteration
#        operations for managing collections of faces in mesh data structures.
#
from face import FacePtr

@fieldwise_init
struct FaceList[T:DType]:
    var head : FacePtr[Self.T]
    var tail : FacePtr[Self.T]

    def __init__(out self): self = Self(None, None)

    def clear(mut self):
        self.head = None
        self.tail = None

    def add(mut self, face : FacePtr[Self.T]): 
        if not self.head:
            self.head = face            
        else:
            self.tail[].next = face

        face[].next = None
        self.tail = face

    def first(self) -> FacePtr[Self.T] : return self.head
    
    def isEmpty(self) -> Bool : return not self.head

    def len(self) -> Int:
        var count = 0
        var current = self.head
        while current is not None:
            count += 1
            current = current[].next
        return count
#        
            
def main():
    var _ = FaceList[Float32]()