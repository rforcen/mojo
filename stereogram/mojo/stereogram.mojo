# stereogram mojo implementation
from std.testing.prop.random import Rng
from std.time import perf_counter
from std.python import Python, PythonObject
from std.ffi import external_call
#

struct Stereogram:
  var width : Int
  var height : Int

  def __init__(out self, width : Int, height : Int):
    self.width = width
    self.height = height

  
  comptime ColorRGBX = UInt32
  comptime Image = List[UInt32]

  comptime red = Self.ColorRGBX(0xff0000ff)
  comptime green = Self.ColorRGBX(0x00ff00ff)
  comptime blue = Self.ColorRGBX(0x0000ffff)
  comptime black = Self.ColorRGBX(0x000000ff)
  comptime white = Self.ColorRGBX(0xffffffff)

  # depth calculation helpers
  @staticmethod
  @always_inline
  def mindepth(separationFactor:Float64, maxdepth:Int, observationDistance:Int, suppliedMinDepth:Int) -> Int :
    var computedMinDepth = ( (separationFactor * Float64(maxdepth) * Float64(observationDistance)) /
      (((1 - separationFactor) * Float64(maxdepth)) + Float64(observationDistance)) )
    return Int(min(max(computedMinDepth, Float64(suppliedMinDepth)), Float64(maxdepth)))

  @staticmethod
  @always_inline
  def maxdepth(suppliedMaxDepth:Int, observationDistance:Int) -> Int :
    return min(suppliedMaxDepth, observationDistance)

  @staticmethod
  @always_inline
  def topixels(valueInches : Float64, ppi : Int) -> Int :
    return Int(valueInches * Float64(ppi))
      
  @staticmethod
  @always_inline
  def getRed(color:Self.ColorRGBX) -> Int :
    return Int((color >> 16) & 0xFF)

  @staticmethod
  @always_inline
  def depth(depth : Self.ColorRGBX, maxDepth : Int, minDepth : Int) -> Int :
    return maxDepth - (Self.getRed(depth) * (maxDepth - minDepth) // 255)
      
  @staticmethod
  @always_inline
  def separation(observationDistance : Int, eyeSeparation : Int, depth : Int) -> Int :
    return (eyeSeparation * depth) // (depth + observationDistance)

  @staticmethod
  def toSeq(n : Int) -> List[Int]:
    var result = List[Int](length=n, fill=0)
    for i in range(n): result[i] = i
    return result^

  #
  def generateSIRD(
    self,
    depthMap : String, 
    color1 : Self.ColorRGBX, color2 : Self.ColorRGBX, color3 : Self.ColorRGBX, 
    colorIntensity : Float64,
    observationDistanceInches : Float64 = 14.0, 
    eyeSeparationInches : Float64 = 2.5,
    maxDepthInches : Float64 = 12.0, 
    minDepthInches : Float64 = 0.0,  
    horizontalPPI : Int = 72) raises -> Self.Image:

      var rand = Rng(seed=Int(perf_counter()))

      var stereogram  = List[UInt32](length=self.width * self.height, fill=0)
      var rdepthMap   = Self.img_resize(depthMap, self.width, self.height) # resize image to target dimensions   

      var seq0_w = Self.toSeq(self.width)

      var observationDistance = Self.topixels(observationDistanceInches, horizontalPPI)
      var eyeSeparation       = Self.topixels(eyeSeparationInches, horizontalPPI)
      var maxdepth            = Self.maxdepth( Self.topixels(maxDepthInches, horizontalPPI), observationDistance )
      var minDepth            = Self.mindepth(0.55, maxdepth, observationDistance, Self.topixels(minDepthInches, horizontalPPI) )
      var colors  = [color1, color2, color3]

      def choose_color() raises {imm color3, imm colorIntensity, imm colors, mut rand} -> Self.ColorRGBX:
        if color3==0: 
          if (Float64(rand.rand_int(min=0, max=100)) / 100.0) < colorIntensity: return colors[0]
          else: return colors[1]
        else: return colors[rand.rand_int(min=0, max=len(colors)-1)]

      
      for l in range(self.height):
        var linksL = seq0_w.copy()
        var linksR = seq0_w.copy()

        for c in range(self.width):
          var depth = Self.depth( rdepthMap[c*self.width+l], maxdepth, minDepth )
          var separation = Self.separation( observationDistance, eyeSeparation, depth )
          var left = c - (separation // 2)
          var right = left + separation

          if left >= 0 and right < self.width:
            var visible = True

            if linksL[right] != right:
              if linksL[right] < left:
                linksR[linksL[right]] = linksL[right]
                linksL[right] = right
              else:   visible = False 
            
            if linksR[left] != left:
              if linksR[left] > right:
                linksL[linksR[left]] = linksR[left]
                linksR[left] = left
              else: visible = False 
            
            if visible: linksL[right] = left; linksR[left] = right      

        for c in range(self.width):
          stereogram[c + l * self.width] = choose_color() if linksL[c] == c else stereogram[linksL[c] + l * self.width]
      
      return stereogram^

  def generateTexturedSIRD(
    self,
    depthMap : String, 
    texturePattern : String,    
    observationDistanceInches : Float64, 
    eyeSeparationInches : Float64,  
    maxDepthInches : Float64, 
    minDepthInches : Float64,
    horizontalPPI : Int, 
    verticalPPI : Int) raises -> Self.Image:

    var stereogram = List[UInt32](length=self.width * self.height, fill=0)

    var rdepthMap = Self.img_resize(depthMap, self.width, self.height) # resize image to target dimensions   
    var seq0_w = Self.toSeq(self.width)

    var observationDistance = Self.topixels(observationDistanceInches, horizontalPPI)
    var eyeSeparation       = Self.topixels(eyeSeparationInches, horizontalPPI)
    var maxDepth            = Self.maxdepth( Self.topixels(maxDepthInches, horizontalPPI), observationDistance )
    var minDepth            = Self.mindepth( 0.55, maxDepth, observationDistance, Self.topixels(minDepthInches, horizontalPPI) )
    var verticalShift       = verticalPPI // 16
    var maxSeparation       = Self.separation(observationDistance, eyeSeparation, maxDepth)
    var wtexturePattern     = Self.img_resize(texturePattern, maxSeparation , maxSeparation)

    for l in range(self.height):
      var linksL = seq0_w.copy()
      var linksR = seq0_w.copy()
      
      for c in range(self.width):
        var depth = Self.depth( rdepthMap[c*self.width + l], maxDepth, minDepth )
        var separation = Self.separation(observationDistance, eyeSeparation, depth)
        var left = c - (separation // 2)
        var right = left + separation

        if left >= 0 and right < self.width:
          var visible = True

          if linksL[right] != right:
            if linksL[right] < left:
              linksR[linksL[right]] = linksL[right]
              linksL[right] = right
            else:  visible = False 
            
          if linksR[left] != left:
            if linksR[left] > right:
              linksL[linksR[left]] = linksR[left]
              linksR[left] = left
            else: visible = False

          if visible:
            linksL[right] = left
            linksR[left] = right
                      
      var lastLinked = -10
      for c in range(self.width):
        if linksL[c] == c:
          stereogram[c + l * self.width] =  stereogram[c - 1 + l * self.width] \
            if lastLinked == c - 1 else \
            wtexturePattern[c % maxSeparation + ((l + ((c // maxSeparation) * verticalShift)) % maxSeparation) * maxSeparation]
        else:
          stereogram[c + l * self.width] = stereogram[linksL[c] + l * self.width]
          lastLinked = c
    
    return stereogram^

  # opens an image, resizes it and rotates it 90 degrees, then converts it to a list of UInt32, uses python PIL
  @staticmethod 
  def img_resize_py(file_name : String, width : Int, height : Int) raises -> Self.Image:
      # add PIL pip global install location
      Python.add_to_path("/usr/lib/python3/dist-packages")
    
      # load PIL     
      var PIL = Python.import_module("PIL.Image")
      
      # create a span of bytes from the image, rotate 90º & resize -> bytes RGB array flattened
      var img = Span[UInt8](
        unsafe_ptr = PIL.open(file_name).\
            convert("RGB").\
            rotate(90, expand=True).\
            resize(Python.list(width, height)).\
            tobytes().\
            unchecked_downcast_value_ptr[UInt8](),
        length     =width * height * 3
      ) 
      
      # convert to UInt32    
      var sz = width * height
      var res = List[UInt32](length=sz, fill=0)    
      
      for i in range(0, sz):
        res[i] = UInt32(0xff00_0000) | (UInt32(img[i*3]) << 16) | (UInt32(img[i*3+1]) << 8) | UInt32(img[i*3+2])
      
      return res^

  # using magick wrapper -> much faster
  @staticmethod 
  def img_resize(filename: String, width: Int, height: Int) -> List[UInt32]:
      var sz = width * height
      var p_img = Span[UInt8](
          unsafe_ptr = external_call["process_image_to_rgb", Pointer[UInt8, MutUntrackedOrigin]]((filename+"\0").unsafe_ptr(), width, height),
          length = sz * 3
      )

      # copy to List32
      var res = List[UInt32](length=sz, fill=0)
      for i in range(0, sz):
          res[i] = UInt32(0xff00_0000) | (UInt32(p_img[i*3]) << 16) | (UInt32(p_img[i*3+1]) << 8) | UInt32(p_img[i*3+2])

      # free pixel mem
      _ = external_call["free_rgb_pixels", NoneType](p_img.unsafe_ptr())

      return res^


  @staticmethod
  def writePAM(image: List[UInt32], width: Int, height: Int, filename: String):
    try:
        with open(filename, "w") as f:
            f.write(t"P7\nWIDTH {width}\nHEIGHT {height}\nDEPTH 4\nMAXVAL 255\nTUPLTYPE RGB_ALPHA\nENDHDR\n")
            f.write_bytes(Span[UInt8](unsafe_ptr=image.unsafe_ptr().unsafe_bitcast[UInt8](), length=image.byte_length()))
    except:
        print("Error writing PAM file")
      
  @staticmethod
  def save_image(filename: String, format: String, image: List[UInt32], width: Int, height: Int):
    _ = external_call["save_image", Int]((filename+"\0").unsafe_ptr(), (format+"\0").unsafe_ptr(), image.unsafe_ptr(), Int32(width), Int32(height))

  # default values for sird / texture
  def sird(mut self, depthMap: String) raises -> Self.Image:
    return self.generateSIRD(
      depthMap=depthMap, 

      color1=Stereogram.black, # default values
      color2=Stereogram.white, 
      color3=Stereogram.red, 
      colorIntensity=0.5,     
      observationDistanceInches = 14, 
      eyeSeparationInches=2.5, 
      maxDepthInches=12, 
      minDepthInches=0, 
      horizontalPPI=72
    )  
  def textured(mut self, depthMap: String, texture: String) raises -> Self.Image:
    return self.generateTexturedSIRD(
      depthMap=depthMap, 
      texturePattern=texture, 

      observationDistanceInches= 14, # default values
      eyeSeparationInches=2.5, 
      maxDepthInches=12, 
      minDepthInches=0, 
      horizontalPPI=72, 
      verticalPPI=72
    )
  
# test
def test_sird() raises:
  var w = 1024 * 2
  var h = 1024 * 2  

  var lap = perf_counter()

  var stereogram = Stereogram(w, h)

  var stereogramc = stereogram.sird(depthMap="/home/asd/code/stereogram/images/depthMaps/panak.jpg")   
  
  print(t"stereogram {w}x{h}, lap: {Int(1000*(perf_counter() - lap))} ms")
  Stereogram.save_image("sird.png", "ARGB", stereogramc, w, h)

def test_textured_sird() raises:
  var w = 1024 * 2
  var h = 1024 * 2  

  var lap = perf_counter()

  var stereogram = Stereogram(w, h)

  var stereogramc = stereogram.textured(
    depthMap = "/home/asd/code/stereogram/images/depthMaps/struna.jpg", 
    texture  = "/home/asd/code/stereogram/images/texturePatterns/tree.jpg")  
  
  print(t"stereogram {w}x{h}, lap: {Int(1000*(perf_counter() - lap))} ms")
  Stereogram.save_image("textured_sird.png", "BGRA", stereogramc, w, h)

def main() raises: 
  test_sird()
  test_textured_sird()