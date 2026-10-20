# magick wrapper
# mojo build magick.mojo -Xlinker magick.o -Xlinker -lMagickWand-7.Q16 -Xlinker -lMagickCore-7.Q16

from std.ffi import external_call, c_int
#
def img_resize(filename: String, width: Int, height: Int) -> List[UInt32]:
    var sz = width * height
    var p_img = Span[UInt8](
        unsafe_ptr = external_call["process_image_to_rgb", Pointer[UInt8, MutUntrackedOrigin]]((filename+"\0").unsafe_ptr(), c_int(width), c_int(height)),
        length = sz * 3
    )

    # copy to List32
    var res = List[UInt32](length=sz, fill=0)
    for i in range(0, sz):
        res[i] = UInt32(0xff00_0000) | (UInt32(p_img[i*3]) << 16) | (UInt32(p_img[i*3+1]) << 8) | UInt32(p_img[i*3+2])

    # free pixel mem
    _ = external_call["free_rgb_pixels", NoneType](p_img.unsafe_ptr())

    return res^

#
def save_image(filename: String, format: String, image: List[UInt32], width: Int, height: Int) -> c_int:
    return external_call["save_image", c_int]((filename+"\0").unsafe_ptr(), (format+"\0").unsafe_ptr(), image.unsafe_ptr(), c_int(width), c_int(height))
  
#
def writePAM(image: List[UInt32], width: Int, height: Int, filename: String):
    try:
        with open(filename, "w") as f:
            f.write(t"P7\nWIDTH {width}\nHEIGHT {height}\nDEPTH 4\nMAXVAL 255\nTUPLTYPE RGB_ALPHA\nENDHDR\n")
            f.write_bytes(Span[UInt8](unsafe_ptr=image.unsafe_ptr().unsafe_bitcast[UInt8](), length=image.byte_length()))
    except:
        print("Error writing PAM file")
#
def main():
    var w = 500
    var h = 500
    var img = img_resize("/home/asd/code/stereogram/images/texturePatterns/rand4.jpg", w, h)
    print(img[:10])
    var result = save_image("test.png", "RGBA", img, w, h)
    print(result)
    
    