# File: ui.mojo
# Author: robertoforcen@gmail.com
# Date: 2026-10-06
# Brief: GLFW-based UI for visualizing Waterman polyhedra with interactive controls (zoom,
#        rotation, radius adjustment) and real-time convex hull rendering using OpenGL.
#
from quickhull3d import waterman_qhull3d
from vector3d import Vector3d

from  glfw import GLFW, glClear, glColor3f, glColor3fv, glBegin, glEnd, glVertex3f, glVertex3fv, glTranslatef, glRotatef, glMatrixMode, glLoadIdentity, \
    gluPerspective, glViewport, glClearColor, glHint, glEnable, glDisable, glDepthFunc, glClearDepth, glShadeModel, glDeleteLists, glGenLists, glNewList, glEndList, glCallList, \
    GL_POLYGON, GL_LINE_LOOP, GL_COLOR_BUFFER_BIT, GL_DEPTH_BUFFER_BIT, GL_PROJECTION, GL_MODELVIEW, GL_LEQUAL, GL_SMOOTH, GL_NICEST, \
    GL_DEPTH_TEST, GL_COLOR_MATERIAL, GL_LINE_SMOOTH, GL_PERSPECTIVE_CORRECTION_HINT, GL_LINE_SMOOTH_HINT, GL_POLYGON_SMOOTH_HINT, GL_COMPILE
#
from  std.testing.prop import Rng
from std.time import perf_counter
from std.math import floor

# call back's
def mouse_callback(window : GLFW.VoidPtr, xpos: Float64, ypos: Float64):
    var ui_dat = GLFW.get_user_ptr[UIData](window)
    
    ui_dat[].mousex = Float32(xpos)
    ui_dat[].mousey = Float32(ypos)
#
def key_callback(window : GLFW.VoidPtr, key: Int32, scan_code: Int32, action: Int32, mods: Int32):
    if action == 1:
        # print(t"Key callback: key:{key}, scan_code:{scan_code}, action:{action}, mods:{mods}")

        var ui_dat = GLFW.get_user_ptr[UIData](window)
        ui_dat[].scene_update = True

        if key == GLFW.KEY_ESCAPE: # exit
            ui_dat[].glfw.set_window_should_close(True)

        elif key == GLFW.KEY_SPACE: # random rad
            var rnd: Rng = Rng(seed=Int(perf_counter()))

            def rand() raises {mut rnd} -> Float32: return rnd.rand_scalar[DType.float32](min = 0.0, max = 1.0)
            try: ui_dat[].radius = floor(rand() * 100.0) + 4
            except : pass

        # +/- rad
        elif key == GLFW.KEY_KP_ADD:         ui_dat[].radius += 1.0
        elif key == GLFW.KEY_KP_SUBTRACT:
            if ui_dat[].radius > 5:
                ui_dat[].radius -= 1.0
                
        # page up/down rad +/- 10
        elif key == GLFW.KEY_PAGE_UP:         ui_dat[].radius += 10
        elif key == GLFW.KEY_PAGE_DOWN:
            if ui_dat[].radius > 10:
                ui_dat[].radius -= 10

        # rad = key * 10
        elif Int(key) in [GLFW.KEY_1, GLFW.KEY_2, GLFW.KEY_3, GLFW.KEY_4, GLFW.KEY_5, GLFW.KEY_6, GLFW.KEY_7, GLFW.KEY_8, GLFW.KEY_9]: # set rad 10, 20, 30, 40, 50, 60, 70, 80, 90
            ui_dat[].radius = Float32(10*(Int(key) - GLFW.KEY_1 + 1))

        elif key == GLFW.KEY_0: # set rad 200
            ui_dat[].radius = 200.0
#
def scroll_callback(window : GLFW.VoidPtr, xoffset: Float64, yoffset: Float64):    
    GLFW.get_user_ptr[UIData](window)[].zoom += Float32(yoffset * 0.2)
#
def gl_init():
    glEnable(GL_COLOR_MATERIAL)
    glShadeModel(GL_SMOOTH)

    glEnable(GL_LINE_SMOOTH)

    glHint(GL_LINE_SMOOTH_HINT, GL_NICEST)
    glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST)

    glClearDepth(1.0)  # Set background depth to farthest
    glEnable(GL_DEPTH_TEST)  # Enable depth testing for z-culling
    glDepthFunc(GL_LEQUAL)  # Set the type of depth-test
    glShadeModel(GL_SMOOTH)  # Enable smooth shading
    glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST)  #  Nice perspective corrections

def set_geo(ref ui_dat : UIData):
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glClearColor(Float32(0.7), Float32(0.7), Float32(0.7), Float32(1.0))     

    # Set up the viewport and projection
    var (fb_w, fb_h) = ui_dat.glfw.get_framebuffer_size()
    glViewport(0, 0, fb_w, fb_h)
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    gluPerspective(45.0, Float64(fb_w) / Float64(fb_h), 0.1, 100.0)
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()

    glTranslatef(0.0, 0.0, ui_dat.zoom)
    glRotatef(ui_dat.mousex, 0.0, 1.0, 0.0)
    glRotatef(ui_dat.mousey, 1.0, 0.0, 0.0)
    
struct UIData(ImplicitlyCopyable):
    comptime DataPtr = Pointer[UIData, MutUntrackedOrigin]

    var w : Int
    var h : Int
    var mousex : Float32
    var mousey : Float32
    var zoom : Float32
    var radius : Float32
    var scene_update : Bool
    var compiler_list : Int32
    var glfw : GLFW

    def __init__(out self):
        self.w = 0
        self.h = 0
        self.mousex = 0
        self.mousey = 0
        self.zoom = -4
        self.radius = 5 
        self.scene_update = True
        self.compiler_list = -1
        self.glfw = GLFW()
        
    def __init__(out self, w : Int, h : Int, glfw : GLFW):
        self.mousex = 0
        self.mousey = 0
        self.zoom = -4
        self.radius = 5
        self.scene_update = True
        self.compiler_list = -1

        self.w = w
        self.h = h
        self.glfw = glfw
        
    
    def toVoidPtr(mut self) -> GLFW.VoidPtr:
        return Pointer(to=self).unsafe_origin_cast[MutUntrackedOrigin]().unsafe_bitcast[NoneType]()

    def fromVoidPtr(self, ptr: GLFW.VoidPtr) -> Self.DataPtr:
        return ptr.unsafe_bitcast[UIData]()

#
def render(faces : List[List[Int]], vertices : List[Vector3d[DType.float32]], colors : List[Vector3d[DType.float32]]):
    @always_inline
    def render_vertex(ref v : Vector3d[DType.float32]): glVertex3fv(v.ptr())
    
    # faces 
    for i, face in enumerate(faces):
        glBegin(GL_POLYGON)        

        glColor3fv(colors[i].ptr())
        for ix in face:  render_vertex(vertices[ix])       
        
        glEnd()

    # wire?
    if len(faces) < 5000:
        glColor3f(0.0, 0.0, 0.0)
        for face in faces:
            glBegin(GL_LINE_LOOP)                     
            for ix in face: render_vertex(vertices[ix])       
            glEnd()

def ui() raises:
    var (w, h) = (800, 800)

    var glfw = GLFW("Waterman", w, h)

    var ui_dat = UIData(w, h, glfw)
    glfw.set_user_ptr(ui_dat.toVoidPtr())    
    
    glfw.set_mouse_callback(mouse_callback)
    glfw.set_key_callback(key_callback)
    glfw.set_scroll_callback(scroll_callback)
    
    gl_init()
    #
    while not glfw.should_close():
        # define geo
        set_geo(ui_dat)

        if ui_dat.scene_update:
            
            # delete & create new list
            if ui_dat.compiler_list != -1:
                glDeleteLists(ui_dat.compiler_list, 1)
            
            ui_dat.compiler_list = glGenLists(1)
            
            # create waterman hull & render in new list
            glNewList(ui_dat.compiler_list, GL_COMPILE)
            
            var lap = perf_counter()
            
            ref (faces, vertices, colors) = waterman_qhull3d(ui_dat.radius) 

            glfw.set_title(String(t"Waterman - Rad: {Int(ui_dat.radius)}, faces: {len(faces)}, vertices: {len(vertices)}, colors:{len(colors)}, time: {Int(1000*(perf_counter() - lap))} ms"))

            render(faces, vertices, colors)
            
            glEndList()
            
            ui_dat.scene_update = False

            
        else: # just call list
            glCallList(ui_dat.compiler_list)

        # update scene & dispath events
        glfw.swap_buffers()
        glfw.poll_events()
#

def main() raises: ui()