# mojo wrapper to btreedx
from std.ffi import external_call

comptime VoidPtr = Optional[Pointer[NoneType, MutUntrackedOrigin]]
comptime Btree_OK = 1

struct BtreeDX:
    var cdef: VoidPtr
    var fid : Int
    
    def __init__(out self):      
        self.cdef = external_call["btreedx_create", VoidPtr]()
        self.fid = -1
    def __deinit__(deinit self): 
        if self.fid != -1:
            try:
                self.close()
            except:
                pass
        _ = external_call["btreedx_destroy", NoneType](self.cdef)
    #
    def open(mut self, filename: String) raises:
        self.fid = external_call["btreedx_open", Int](self.cdef, (filename+"\0").unsafe_ptr())
        if self.fid != 0:  raise Error("Failed to open index")

    def close(self) raises:
        if external_call["btreedx_close", Int](self.cdef)!=Btree_OK:
            raise Error("Failed to close index")

    def create_index(mut self, filename: String, keylen: Int, unique: Int, overlay: Int) raises:
        if external_call["btreedx_create_index", Int](self.cdef, (filename+"\0").unsafe_ptr(), keylen, unique, overlay)!=1:
            raise Error("Failed to create index")
    #
    def add(mut self, key: String, recno: Int) raises:
        if external_call["btreedx_add", Int](self.cdef, (key+"\0").unsafe_ptr(), recno)!=Btree_OK:
            raise Error("Failed to add record")
    
    def find_eq(mut self, key: String) -> Bool:
        var recno = 0
        return external_call["btreedx_find_eq", Int](self.cdef, (key+"\0").unsafe_ptr(), Pointer(to=recno))==Btree_OK
    def find(mut self, key: String) -> Bool:
        var recno = 0
        return external_call["btreedx_find", Int](self.cdef, (key+"\0").unsafe_ptr(), Pointer(to=recno))==Btree_OK
    def next(mut self) raises -> Bool:
        var recno = 0
        var key = self.get_key()
        return external_call["btreedx_next", Int](self.cdef, (key+"\0").unsafe_ptr(), Pointer(to=recno))==Btree_OK
    #
    def erase_eq(mut self, key: String) -> Bool:
        return external_call["btreedx_erase_eq", Int](self.cdef, (key+"\0").unsafe_ptr())==Btree_OK
    def erase_match(mut self, key: String) -> Bool:
        return external_call["btreedx_erase_match", Int](self.cdef, (key+"\0").unsafe_ptr())==Btree_OK

    # getters    
    def get_key(self) -> String:
        var kp = external_call["btreedx_get_key", Pointer[UInt8,MutUnsafeAnyOrigin]](self.cdef)
        return String(unsafe_from_utf8_ptr=kp)
    def get_recno(self) -> Int:
        return external_call["btreedx_get_rec_no", Int](self.cdef)
    def get_key_recno(self) -> Tuple[String, Int]:
        return (self.get_key(), self.get_recno())
    def get_filename(self) -> String:
        var fp = external_call["btreedx_get_filename", Pointer[UInt8,MutUnsafeAnyOrigin]](self.cdef)
        return String(unsafe_from_utf8_ptr=fp)
       
#
def test01():
    print("btreedx test")

    var tree = BtreeDX() # create tree object

    try:
        # create index
        tree.create_index(filename="test.dbx", keylen=10, unique=1, overlay=1)
        print("Filename:", tree.get_filename())

        var n = 1_000_000

        print("adding", n, "keys")    
        for i in range(n): # add keys
            tree.add(key="key" + String(i), recno=i)   
            if i % 10000 == 0:
                print("Added", i, "keys", end='\r')
        
        print("finding first 100 keys")    
        for i in range(n): # find keys
            if tree.find_eq("key" + String(i)):
                print(tree.get_key(), tree.get_recno(), end='\r')
        print()

        if tree.find("key2"):
            print("Found:", tree.get_key(), tree.get_recno())
            while tree.next():
                print("Next:", tree.get_key(), tree.get_recno(), end="\r")
        print()

        tree.close()
    except e:
        print(e)
    

def main():
    test01()
