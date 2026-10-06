# tar.gz file libarchive wrapper
# mojo build targz.mojo -Xlinker /usr/lib/x86_64-linux-gnu/libarchive.so
# must use 'build' when linking w/ XLinker

from std.ffi import external_call, c_char, c_double, c_long, c_int, c_ssize_t, CStringSlice
from std.memory import alloc, Layout, dealloc, unsafe_destroy_n

# main archive pointer & entry
comptime Archive = Optional[Pointer[NoneType, MutUntrackedOrigin]]
comptime ArchiveEntry = Optional[Pointer[NoneType, MutUntrackedOrigin]]
comptime BUFF_SIZE = 1024 * 16  


# error codes
comptime ARCHIVE_EOF = 1
comptime ARCHIVE_OK = 0
comptime ARCHIVE_RETRY = -10
comptime ARCHIVE_WARN = -20
comptime ARCHIVE_FAILED = -25
comptime ARCHIVE_FATAL = -30

# wrapper
comptime char_ptr = Pointer[Scalar[DType.uint8], MutUntrackedOrigin]
def vesion_string[ver_fn:String]() -> String:
    var p = external_call[ver_fn, char_ptr]()
    return String(unsafe_from_utf8_ptr = p) if Int(p)!=0 else ""

def archive_zlib_version() -> String:   return vesion_string["archive_zlib_version"]()
def archive_liblzma_version() -> String:   return vesion_string["archive_liblzma_version"]()
def archive_bzlib_version() -> String:   return vesion_string["archive_bzlib_version"]()
def archive_liblz4_version() -> String:   return vesion_string["archive_liblz4_version"]()
def archive_libzstd_version() -> String:   return vesion_string["archive_libzstd_version"]()
def archive_liblzo2_version() -> String:   return vesion_string["archive_liblzo2_version"]()
def archive_libexpat_version() -> String:   return vesion_string["archive_libexpat_version"]()
def archive_libbsdxml_version() -> String:   return vesion_string["archive_libbsdxml_version"]()
def archive_libxml2_version() -> String:   return vesion_string["archive_libxml2_version"]()
def archive_mbedtls_version() -> String:   return vesion_string["archive_mbedtls_version"]()
def archive_nettle_version() -> String:   return vesion_string["archive_nettle_version"]()
def archive_openssl_version() -> String:   return vesion_string["archive_openssl_version"]()
def archive_libmd_version() -> String:   return vesion_string["archive_libmd_version"]()
def archive_commoncrypto_version() -> String:   return vesion_string["archive_commoncrypto_version"]()
def archive_cng_version() -> String:   return vesion_string["archive_cng_version"]()
def archive_wincrypt_version() -> String:   return vesion_string["archive_wincrypt_version"]()
def archive_librichacl_version() -> String:   return vesion_string["archive_librichacl_version"]()
def archive_libacl_version() -> String:   return vesion_string["archive_libacl_version"]()
def archive_libattr_version() -> String:   return vesion_string["archive_libattr_version"]()
def archive_libiconv_version() -> String:   return vesion_string["archive_libiconv_version"]()
def archive_libpcre_version() -> String:   return vesion_string["archive_libpcre_version"]()
def archive_libpcre2_version() -> String:   return vesion_string["archive_libpcre2_version"]()
def archive_version_details() -> String:   return vesion_string["archive_version_details"]()
def archive_version_string() -> String:   return vesion_string["archive_version_string"]()

#
def archive_read_new() raises -> Archive:  return external_call["archive_read_new", Archive]()
def archive_read_support_format_all(var archive: Archive) raises -> c_int:   return external_call["archive_read_support_format_all", c_int](archive)
def archive_read_support_filter_all(var archive: Archive) raises -> c_int:   return external_call["archive_read_support_filter_all", c_int](archive)
def archive_read_open_filename(var archive: Archive, filename: String) raises -> c_int: # ARCHIVE_OK = 0
    return external_call["archive_read_open_filename", c_int](archive, CStringSlice(filename + "\0").as_bytes_with_nul().unsafe_ptr(), BUFF_SIZE)
def archive_read_close(var archive: Archive) raises -> c_int:  return external_call["archive_read_close", c_int](archive)
def archive_read_free(var archive: Archive) raises -> c_int:   return external_call["archive_read_free", c_int](archive)
def archive_read_next_header(var archive: Archive, mut entry: ArchiveEntry) raises -> c_int:   
    return external_call["archive_read_next_header", c_int](archive, Pointer(to=entry))
def archive_entry_pathname(var entry: ArchiveEntry) -> String:
    return String(unsafe_from_utf8_ptr=external_call["archive_entry_pathname", Pointer[c_char, MutUntrackedOrigin]](entry))
def archive_entry_size(var entry: ArchiveEntry) -> Int:
    return Int(external_call["archive_entry_size", c_ssize_t](entry))
def archive_read_data(var entry: ArchiveEntry, buffer: Array[c_char, BUFF_SIZE+1], size: Int) -> Int:
    return Int(external_call["archive_read_data", c_ssize_t](entry, buffer.unsafe_ptr(), size))

# tar.gz reader
struct TarGzReader(ImplicitlyCopyable):
    var archive: Archive
    var entry: ArchiveEntry
    var stat : Int
    
    
    def __init__(out self) :
        self.archive = Archive(None) 
        self.entry = ArchiveEntry(None)
        self.stat= 0
    
    def __init__(out self, filename: String) raises:
        self.archive = archive_read_new()
        self.entry = ArchiveEntry(None)
        _ = archive_read_support_format_all(self.archive)
        self.stat= Int(archive_read_support_filter_all(self.archive))
        self.stat = self.open(filename)
    
    def __deinit__(deinit self):      
        try:    
            if self.archive:
                _ = archive_read_close(self.archive)
                _ = archive_read_free(self.archive)
        except:
            pass
    
    def open(self, filename: String) raises -> Int:
        return Int(archive_read_open_filename(self.archive, filename))
    
    def close(mut self) raises:
        self.stat = Int(archive_read_close(self.archive))
    
    def next_header(mut self) raises -> Bool:
        var res = archive_read_next_header(self.archive, self.entry) == ARCHIVE_OK
        return res
    
    def get_pathname(self) -> String:
        return archive_entry_pathname(self.entry)
    
    def get_size(self) -> Int:
        return archive_entry_size(self.entry)
    
    def read(self) -> String:        
        var size = self.get_size()
        if size == 0 : return ""

        var res : String = ""
        var buff = Array[c_char, BUFF_SIZE+1](uninitialized=True)  # \0 terminated
        
        while True:
            var br = archive_read_data(self.archive, buff, BUFF_SIZE)
            if br <= 0:
                break
            buff[br] = 0 # terminate in \0

            res += String(unsafe_from_utf8_ptr=buff.unsafe_ptr()) # copy \0 terminated char*
        
        return res

# test
def test_version():
    print("zlib version:", archive_zlib_version())
    print("liblzma version:", archive_liblzma_version())
    print("bzlib version:", archive_bzlib_version())
    print("liblz4 version:", archive_liblz4_version())
    print("libzstd version:", archive_libzstd_version())
    print("liblzo2 version:", archive_liblzo2_version())
    print("libexpat version:", archive_libexpat_version())
    print("libbsdxml version:", archive_libbsdxml_version())
    print("libxml2 version:", archive_libxml2_version())
    print("mbedtls version:", archive_mbedtls_version())
    print("nettle version:", archive_nettle_version())
    print("openssl version:", archive_openssl_version())
    print("libmd version:", archive_libmd_version())
    print("commoncrypto version:", archive_commoncrypto_version())
    print("cng version:", archive_cng_version())
    print("wincrypt version:", archive_wincrypt_version())
    print("librichacl version:", archive_librichacl_version())
    print("libacl version:", archive_libacl_version())
    print("libattr version:", archive_libattr_version())
    print("libiconv version:", archive_libiconv_version())
    print("libpcre version:", archive_libpcre_version())
    print("libpcre2 version:", archive_libpcre2_version())

    print("version string:", archive_version_string())
    print("version details:", archive_version_details())

def test_traverse() raises:
    # test_version()    
    var archive = archive_read_new()
    var entry = ArchiveEntry(None)
    
    var res = archive_read_support_format_all(archive)
    print("result format all:", res)
    res = archive_read_support_filter_all(archive)
    print("result filter all:", res)

    var result = archive_read_open_filename(archive, "../data/ghcnd_all.tar.gz")
    print("result open:", result)

    var i = 0
    while (archive_read_next_header(archive, entry)==ARCHIVE_OK):
        if i % 1000 == 0:
            print(t"{i} : result next header:{result}, entry:{entry}, path name: {archive_entry_pathname(entry)}")
        i += 1

    _ = archive_read_close(archive)
    _ = archive_read_free(archive)


def main() raises:
    test_traverse()