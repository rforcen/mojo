# ui for polygonizer
# Interactive OpenGL viewer for polyhedronisme patterns

import glfw

from OpenGL.GL import (
    glEnable,
    glShadeModel,
    glHint,
    glClearDepth,
    glDepthFunc,
    glClear,
    glClearColor,
    glViewport,
    glMatrixMode,
    glLoadIdentity,
    glTranslatef,
    glRotatef,
    glDeleteLists,
    glGenLists,
    glNewList,
    glEndList,
    glCallList,
    glLightfv,
    glLightModelfv,
    glMaterialfv,
    glBegin,
    glEnd,
    GL_FRONT,
    GL_SHININESS,
    GL_LIGHT_MODEL_TWO_SIDE,
    GL_LIGHT_MODEL_AMBIENT,
    GL_LIGHTING,
    GL_LIGHT0,
    GL_LIGHT1,
    GL_COLOR_MATERIAL,
    GL_AMBIENT,
    GL_DIFFUSE,
    GL_POSITION,
    GL_SPECULAR,
    GL_SMOOTH,
    GL_LINE_SMOOTH,
    GL_LINE_SMOOTH_HINT,
    GL_NICEST,
    GL_DEPTH_TEST,
    GL_LEQUAL,
    GL_POLYGON_SMOOTH_HINT,
    GL_PERSPECTIVE_CORRECTION_HINT,
    GL_COLOR_BUFFER_BIT,
    GL_DEPTH_BUFFER_BIT,
    GL_PROJECTION,
    GL_MODELVIEW,
    GL_TRIANGLES,
    GL_LINE_LOOP,
    GL_COMPILE,
    GL_FALSE,
    GL_TRUE,
)
from OpenGL.GLU import gluPerspective
from OpenGL import platform

import time
from numba import njit
import ctypes
import numpy as np

import polygonizer as poly


# numba openGL binding -> get used funcs addresses
def get_func_address_float(func_name):
    return ctypes.CFUNCTYPE(None, ctypes.POINTER(ctypes.c_float))(
        platform.PLATFORM.getExtensionProcedure(func_name.encode("utf-8"))
    )


glVertex3fv_pointer = get_func_address_float("glVertex3fv")
glColor3fv_pointer = get_func_address_float("glColor3fv")
glNormal3fv_pointer = get_func_address_float("glNormal3fv")
glBegin_pointer = ctypes.CFUNCTYPE(None, ctypes.c_int)(
    platform.PLATFORM.getExtensionProcedure("glBegin".encode("utf-8"))
)
glEnd_pointer = ctypes.CFUNCTYPE(None)(
    platform.PLATFORM.getExtensionProcedure("glEnd".encode("utf-8"))
)
GL_TRIANGLES_VAL = int(GL_TRIANGLES)
GL_LINE_LOOP_VAL = int(GL_LINE_LOOP)


#  fast numba rendering using prev. func pointers
#  pointers are required to wrap opengl calls


@njit
def fast_render(coords, normals, faces):
    glColor3fv_pointer(np.array([0.5, 0.5, 0], dtype=np.float32).ctypes)
    for face in faces:
        for ix in face:
            glNormal3fv_pointer(normals[ix].ctypes)
            glVertex3fv_pointer(coords[ix].ctypes)


def poly_ui():
    mousex = 0
    mousey = 0
    zoom = -4
    w = h = 800

    # impl_func def
    n_impl_func = 1
    imp_bounds = 30
    imp_size = 0.05

    scene_update = True
    compiled_list = -1

    def setGeo(mousex, mousey, zoom):
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        glClearColor(0.7, 0.7, 0.7, 1.0)  # light bg
        wg, hg = glfw.get_framebuffer_size(window)
        glViewport(0, 0, wg, hg)
        glMatrixMode(GL_PROJECTION)
        glLoadIdentity()
        gluPerspective(45.0, wg / hg, 0.1, 100.0)
        glMatrixMode(GL_MODELVIEW)
        glLoadIdentity()

        glTranslatef(0.0, 0.0, zoom)
        glRotatef(mousex, 0.0, 1.0, 0.0)
        glRotatef(mousey, 1.0, 0.0, 0.0)

    def sceneInit():  # works nice for golden solid colors (requires normals)
        lmodel_ambient = [0, 0, 0, 0]
        lmodel_twoside = [GL_FALSE]
        light0_ambient = [0.1, 0.1, 0.1, 1.0]
        light0_diffuse = [1.0, 1.0, 1.0, 0.0]
        light0_position = [1, 0.5, 1, 0]
        light1_position = [-1, 0.5, -1, 0]
        light0_specular = [1, 1, 1, 0]
        bevel_mat_ambient = [0, 0, 0, 1]
        bevel_mat_shininess = [40]
        bevel_mat_specular = [1, 1, 1, 0]
        bevel_mat_diffuse = [1, 0, 0, 0]

        glLightfv(GL_LIGHT0, GL_AMBIENT, light0_ambient)
        glLightfv(GL_LIGHT0, GL_DIFFUSE, light0_diffuse)
        glLightfv(GL_LIGHT0, GL_SPECULAR, light0_specular)
        glLightfv(GL_LIGHT0, GL_POSITION, light0_position)
        glEnable(GL_LIGHT0)

        glLightfv(GL_LIGHT1, GL_AMBIENT, light0_ambient)
        glLightfv(GL_LIGHT1, GL_DIFFUSE, light0_diffuse)
        glLightfv(GL_LIGHT1, GL_SPECULAR, light0_specular)
        glLightfv(GL_LIGHT1, GL_POSITION, light1_position)
        glEnable(GL_LIGHT1)

        glLightModelfv(GL_LIGHT_MODEL_TWO_SIDE, lmodel_twoside)
        glLightModelfv(GL_LIGHT_MODEL_AMBIENT, lmodel_ambient)
        glEnable(GL_LIGHTING)

        glMaterialfv(GL_FRONT, GL_AMBIENT, bevel_mat_ambient)
        glMaterialfv(GL_FRONT, GL_SHININESS, bevel_mat_shininess)
        glMaterialfv(GL_FRONT, GL_SPECULAR, bevel_mat_specular)
        glMaterialfv(GL_FRONT, GL_DIFFUSE, bevel_mat_diffuse)

        glEnable(GL_COLOR_MATERIAL)
        glShadeModel(GL_SMOOTH)

        glEnable(GL_LINE_SMOOTH)

        glHint(GL_LINE_SMOOTH_HINT, GL_NICEST)
        glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST)

        glClearDepth(1.0)  # Set background depth to farthest
        glEnable(GL_DEPTH_TEST)  # Enable depth testing for z-culling
        glDepthFunc(GL_LEQUAL)  # Set the type of depth-test
        glShadeModel(GL_SMOOTH)  # Enable smooth shading
        glHint(
            GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST
        )  #  Nice perspective corrections

    # call backs
    def mouse_callback(window, xpos, ypos):
        nonlocal mousex, mousey
        mousex = xpos
        mousey = ypos

    def key_callback(window, key, scancode, action, mods):
        if action != glfw.PRESS:
            return
        nonlocal scene_update, n_impl_func, imp_bounds, imp_size
        scene_update = True

        if key == glfw.KEY_ESCAPE:
            glfw.set_window_should_close(window, True)

        elif key == glfw.KEY_PAGE_DOWN: # impl_func
            if n_impl_func > 0:
                n_impl_func -= 1

        elif key == glfw.KEY_PAGE_UP:
            if n_impl_func < 20:
                n_impl_func += 1

        elif key == glfw.KEY_UP: # bounds ^|
            if imp_bounds < 200:
                imp_bounds += 10

        elif key == glfw.KEY_DOWN:
            if imp_bounds > 10:
                imp_bounds -= 10

        elif key == glfw.KEY_RIGHT: # size <->
            if imp_size < 1.0:
                imp_size += 0.01

        elif key == glfw.KEY_LEFT:
            if imp_size > 0.01:
                imp_size -= 0.01

        else:
            scene_update = False

    def scroll_callback(window, xoffset, yoffset):
        nonlocal zoom
        zoom += yoffset * 0.2

    # Initialize the GLFW library
    if not glfw.init():
        return

    # Create a windowed mode window and its OpenGL context
    window = glfw.create_window(w, h, "Polygonizer", None, None)
    if not window:
        glfw.terminate()
        return

    # Make the window's context current
    glfw.make_context_current(window)

    # assign callbacks
    glfw.set_cursor_pos_callback(window, mouse_callback)
    glfw.set_key_callback(window, key_callback)
    glfw.set_scroll_callback(window, scroll_callback)

    #  polygon
    lap = None
    coords = normals = None
    faces = None

    def create_poly():
        nonlocal faces, coords, normals, lap, n_impl_func

        start = time.time()

        coords, normals, faces = poly.polygonize(n_impl_func, imp_bounds, imp_size)

        lap = 1000 * (time.time() - start)

    sceneInit()

    # Loop until the user closes the window
    while not glfw.window_should_close(window):
        # Render here
        setGeo(mousex, mousey, zoom)

        if scene_update:
            create_poly()  # create the poly

            glfw.set_window_title(
                window,
                f"[mojo] Polygonizer - id: {n_impl_func}, bounds: {imp_bounds}, size: {imp_size:4.2f}, faces:{len(faces)}, vertices:{len(coords)}, lap:{lap:.0f}ms",
            )

            # display it

            if compiled_list != -1:  # create the compiled list
                glDeleteLists(compiled_list, 1)
            compiled_list = glGenLists(1)

            glNewList(compiled_list, GL_COMPILE)

            glBegin(GL_TRIANGLES)
            if len(coords) > 0:
                fast_render(coords, normals, faces)
            glEnd()

            glEndList()  # end list
            scene_update = False
        else:
            glCallList(compiled_list)

        glfw.swap_buffers(window)
        glfw.poll_events()

    glfw.destroy_window(window)
    glfw.terminate()


if __name__ == "__main__":
    poly_ui()
