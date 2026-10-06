# File: optpnt.mojo
# Author: robertoforcen@gmail.com
# Date: 2026-10-06
# Brief: Optional pointer wrapper that reduces value()[] syntax to [] for VertexPtr, FacePtr,
#        and HalfEdgePtr, providing safe pointer access with bounds checking.
#
# A wrapper around an optional pointer to a value of type T
# Provides safe access to the value with bounds checking

struct OptPnt[T: ImplicitlyCopyable](ImplicitlyCopyable, Copyable, Movable, Boolable, Writable, Equatable):
    var _op: Optional[Pointer[Self.T, MutUntrackedOrigin]]

    def __init__(out self): self._op = None
    @implicit
    def __init__(out self, value: None): self._op = None
    def __init__(out self, ptr: Pointer[Self.T, MutUntrackedOrigin]): self._op = ptr
    def __init__(out self, op : Optional[Pointer[Self.T, MutUntrackedOrigin]]): self._op = op
    def __init__(out self, op : Optional[Pointer[Self.T, MutUntrackedOrigin]], v : Self.T): 
        self._op = op
        if self._op: self._op.value().unsafe_write(v)
    def __bool__(self) -> Bool: return Bool(self._op)
    def __getitem__(self) -> ref [MutUntrackedOrigin] Self.T:  return self._op.value()[]
    def write_to(self, mut writer: Some[Writer]): writer.write(self._op)

    def __eq__(self, ref other : OptPnt[Self.T]) raises -> Bool: return self._op == other._op
    def __ne__(self, other : OptPnt[Self.T]) raises -> Bool: return self._op != other._op
    
    def __is__(self, other : NoneType) raises -> Bool: return self._op is None
    def __isnot__(self, other : NoneType) raises -> Bool: return self._op is not None
