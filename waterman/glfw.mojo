# File: glfw.mojo
# Author: robertoforcen@gmail.com
# Date: 2026-10-06
# Brief: GLFW wrapper providing window management, input callbacks (mouse, keyboard, scroll),
#        and OpenGL function bindings for 3D graphics rendering.
#
from std.ffi import external_call
from std.math import floor
#
struct GLFW(ImplicitlyCopyable):
    comptime VoidPtr = Pointer[NoneType, MutUntrackedOrigin]    
    comptime MouseCallback = def(window : Self.VoidPtr, x : Float64, y : Float64)  thin
    comptime KeyCallBack = def(window : Self.VoidPtr, key: Int32, scan_code: Int32, action: Int32, mods: Int32)  thin
    comptime ScrollCallBack = def(window : Self.VoidPtr, xoffset: Float64, yoffset: Float64)  thin
    # keys
    comptime KEY_ESCAPE = 256
    comptime KEY_SPACE = 32
    comptime KEY_0 = 48
    comptime KEY_1 = 49
    comptime KEY_2 = 50
    comptime KEY_3 = 51
    comptime KEY_4 = 52
    comptime KEY_5 = 53
    comptime KEY_6 = 54
    comptime KEY_7 = 55
    comptime KEY_8 = 56
    comptime KEY_9 = 57
    comptime KEY_KP_DECIMAL = 330
    comptime KEY_KP_DIVIDE = 331
    comptime KEY_KP_MULTIPLY = 332
    comptime KEY_KP_SUBTRACT = 333
    comptime KEY_KP_ADD = 334
    comptime KEY_KP_ENTER = 335
    comptime KEY_PAGE_UP = 266
    comptime KEY_PAGE_DOWN = 267
    comptime KEY_KP_EQUAL = 336
    comptime KEY_LEFT_SHIFT = 340
    comptime KEY_LEFT_CONTROL = 341
    comptime KEY_LEFT_ALT = 342
    comptime KEY_LEFT_SUPER = 343
    comptime KEY_RIGHT_SHIFT = 344
    comptime KEY_RIGHT_CONTROL = 345
    comptime KEY_RIGHT_ALT = 346
    comptime KEY_RIGHT_SUPER = 347
    comptime KEY_MENU = 348
    #
    var window: Optional[Self.VoidPtr]
    #    
    def __init__(out self):
        self.window = None
        
    def __init__(out self, title : String, w : Int, h : Int) raises:
        var res = external_call["glfwInit", Int32]()        
        if not res: raise Error("Failed to initialize GLFW")
            
        self.window = external_call["glfwCreateWindow", Pointer[NoneType, MutUntrackedOrigin]](Int32(w), Int32(h), title.unsafe_ptr(), None, None)
        if not Optional(self.window): raise Error("Failed to create window")

        external_call["glfwMakeContextCurrent", NoneType](self.window)

    def set_title(self, t : String):
        external_call["glfwSetWindowTitle", NoneType](self.window, (t+'\0').unsafe_ptr())
        
    def set_mouse_callback(self, callback : Self.MouseCallback):
        external_call["glfwSetCursorPosCallback", NoneType](self.window, callback)

    def set_key_callback(self, callback : Self.KeyCallBack):
        external_call["glfwSetKeyCallback", NoneType](self.window, callback)
    
    def set_scroll_callback(self, callback : Self.ScrollCallBack):
        external_call["glfwSetScrollCallback", NoneType](self.window, callback)

    def set_user_ptr(self, ptr : Self.VoidPtr):
        external_call["glfwSetWindowUserPointer", NoneType](self.window, ptr)

    @staticmethod
    def get_user_ptr[T:AnyType](window : Self.VoidPtr) -> Pointer[T, MutUntrackedOrigin]:
        return external_call["glfwGetWindowUserPointer", Pointer[T, MutUntrackedOrigin]](window)

    def set_window_should_close(self, value : Bool):
        external_call["glfwSetWindowShouldClose", NoneType](self.window, value)

    def should_close(self) -> Bool:
        return external_call["glfwWindowShouldClose", Int32](self.window) != 0

    def get_framebuffer_size(self) -> Tuple[Int32, Int32]:
        var w : Int32 = 0
        var h : Int32 = 0
        external_call["glfwGetFramebufferSize", NoneType](self.window, Pointer(to=w), Pointer(to=h))
        return (w, h)
    
    def swap_buffers(self):
        external_call["glfwSwapBuffers", NoneType](self.window)
    
    def poll_events(self):
        external_call["glfwPollEvents", NoneType]()
    
    def __deinit__(deinit self):
        if Optional(self.window): external_call["glfwDestroyWindow", NoneType](self.window)
        external_call["glfwTerminate", NoneType]()

# gl constants
comptime GL_COLOR_BUFFER_BIT=0x00004000
comptime GL_DEPTH_BUFFER_BIT=0x00000100  
comptime GL_COLOR_MATERIAL=0x0B57
comptime GL_POLYGON=0x0009
comptime GL_LINE_LOOP=0x0002
comptime GL_FLAT=0x1D00
comptime GL_SMOOTH=0x1D01
comptime GL_LINE_SMOOTH=0x0B20
comptime GL_LINE_SMOOTH_HINT=0x0C52
comptime GL_POLYGON_SMOOTH_HINT=0x0C53
comptime GL_NICEST=0x1102
comptime GL_DEPTH_TEST=0x0B71
comptime GL_LEQUAL=0x0203
comptime GL_PERSPECTIVE_CORRECTION_HINT=0x0C50
comptime GL_PROJECTION=0x1701
comptime GL_MODELVIEW=0x1700
comptime GL_COMPILE=0x1300

# gl functions
def glClear(mask: Int32):  external_call["glClear", NoneType](mask)
def glClearColor(r: Float32, g: Float32, b: Float32, a: Float32):  external_call["glClearColor", NoneType](r, g, b, a)
def glColor3f(r: Float32, g: Float32, b: Float32):  external_call["glColor3f", NoneType](r, g, b)
def glColor3fv[origin: Origin](v: Pointer[Float32, origin]):    external_call["glColor3fv", NoneType](v)
def glBegin(mode: Int32):  external_call["glBegin", NoneType](mode)
def glEnd():  external_call["glEnd", NoneType]()
def glVertex3f(x: Float32, y: Float32, z: Float32):  external_call["glVertex3f", NoneType](x, y, z)
def glVertex3fv[origin: Origin](v: Pointer[Float32, origin]):    external_call["glVertex3fv", NoneType](v)
def glEnable(cap: Int32):  external_call["glEnable", NoneType](cap)
def glDisable(cap: Int32):  external_call["glDisable", NoneType](cap)
def glShadeModel(mode: Int32):  external_call["glShadeModel", NoneType](mode)
def glHint(target: Int32, mode: Int32):  external_call["glHint", NoneType](target, mode)
def glClearDepth(depth: Float64):  external_call["glClearDepth", NoneType](depth)
def glDepthFunc(func: Int32):  external_call["glDepthFunc", NoneType](func)
def glViewport(x: Int32, y: Int32, width: Int32, height: Int32):  external_call["glViewport", NoneType](x, y, width, height)
def glMatrixMode(mode: Int32):  external_call["glMatrixMode", NoneType](mode)
def glLoadIdentity():  external_call["glLoadIdentity", NoneType]()
def glTranslatef(x: Float32, y: Float32, z: Float32):  external_call["glTranslatef", NoneType](x, y, z)
def glRotatef(angle: Float32, x: Float32, y: Float32, z: Float32):  external_call["glRotatef", NoneType](angle, x, y, z)
def gluPerspective(fovy: Float64, aspect: Float64, zNear: Float64, zFar: Float64):  external_call["gluPerspective", NoneType](fovy, aspect, zNear, zFar)
def glDeleteLists(_list: Int32, _range: Int32):  external_call["glDeleteLists", NoneType](_list, _range)
def glGenLists(_range: Int) -> Int32: return external_call["glGenLists", Int32](Int32(_range))
def glNewList(list: Int32, mode: Int32):  external_call["glNewList", NoneType](list, mode)
def glEndList():  external_call["glEndList", NoneType]()
def glCallList(list: Int32):  external_call["glCallList", NoneType](list)
