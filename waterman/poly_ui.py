# ui for polyhedronisme
# Interactive OpenGL viewer for polyhedronisme patterns

import glfw
import random
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
    GL_COLOR_MATERIAL,
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
    GL_POLYGON,
    GL_LINE_LOOP,
    GL_COMPILE,
)
from OpenGL.GLU import gluPerspective
from OpenGL import platform

import time
from numba import njit
import ctypes
import numpy as np

import waterman


# numba openGL binding -> get used funcs addresses
def get_func_address_double(func_name):
    return ctypes.CFUNCTYPE(None, ctypes.POINTER(ctypes.c_double))(
        platform.PLATFORM.getExtensionProcedure(func_name.encode("utf-8"))
    )

glVertex3dv_pointer = get_func_address_double("glVertex3dv")
glColor3dv_pointer = get_func_address_double("glColor3dv")
glBegin_pointer = ctypes.CFUNCTYPE(None, ctypes.c_int)(
    platform.PLATFORM.getExtensionProcedure("glBegin".encode("utf-8"))
)
glEnd_pointer = ctypes.CFUNCTYPE(None)(
    platform.PLATFORM.getExtensionProcedure("glEnd".encode("utf-8"))
)
GL_POLYGON_VAL = int(GL_POLYGON)
GL_LINE_LOOP_VAL = int(GL_LINE_LOOP)


#  fast numba rendering using prev. func pointers
#  pointers are required to wrap opengl calls
#  [face0_len, v0, v1..., face1_len, v0, v1...]


@njit
def fast_render_flat(flat_faces, coords, colors):
    cursor = 0
    face_count = 0

    # --- Part 1: Draw Polygons ---
    # We iterate until the cursor hits the end of the flat_faces array
    while cursor < len(flat_faces):
        # The first value at the cursor is the number of vertices in this face
        face_len = flat_faces[cursor]
        cursor += 1  # Move to the first vertex index

        glBegin_pointer(GL_POLYGON_VAL)

        # Access color for this specific face
        # colors should be shape (num_faces, 3)
        glColor3dv_pointer(colors[face_count].ctypes)

        # Loop through the indices for this specific face

        for i in range(face_len):
            vert_idx = flat_faces[cursor + i]
            glVertex3dv_pointer(coords[vert_idx].ctypes)

        glEnd_pointer()

        # Advance the cursor to the start of the next face block
        cursor += face_len
        face_count += 1

    # --- Part 2: Draw Outlines (Wireframe) ---
    # Reset cursor for the second pass
    if len(coords) < 30_000:
        cursor = 0
        # Set color to black for the wireframe
        black_color = np.array([0.0, 0.0, 0.0], dtype=np.float64)
        glColor3dv_pointer(black_color.ctypes)

        while cursor < len(flat_faces):
            face_len = flat_faces[cursor]
            cursor += 1

            glBegin_pointer(GL_LINE_LOOP_VAL)
            for i in range(face_len):
                vert_idx = flat_faces[cursor + i]
                glVertex3dv_pointer(coords[vert_idx].ctypes)
            glEnd_pointer()

            cursor += face_len


@njit
def count_faces_flat(flat_faces):
    """
    Counts total faces in a flattened list formatted as:
    [face0_len, v0, v1..., face1_len, v0, v1...]
    """
    count = 0
    cursor = 0
    total_elements = len(flat_faces)

    while cursor < total_elements:
        face_len = flat_faces[cursor]
        count += 1
        cursor += 1 + face_len

    return count


def poly_ui():
    mousex = 0
    mousey = 0
    zoom = -4
    w = h = 800

    radius = 50

    scene_update = True
    compiled_list = -1

    def gl_init():
        glEnable(GL_COLOR_MATERIAL)   

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

    def setGeo(mousex, mousey, zoom, w, h):
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        glClearColor(0.7, 0.7, 0.7, 1.0)  # light bg

        # Set up the viewport and projection
        fb_w, fb_h = glfw.get_framebuffer_size(window)
        glViewport(0, 0, fb_w, fb_h)
        glMatrixMode(GL_PROJECTION)
        glLoadIdentity()
        gluPerspective(45.0, fb_w / fb_h, 0.1, 100.0)
        glMatrixMode(GL_MODELVIEW)
        glLoadIdentity()

        glTranslatef(0.0, 0.0, zoom)
        glRotatef(mousex, 0.0, 1.0, 0.0)
        glRotatef(mousey, 1.0, 0.0, 0.0)

    # call backs
    def mouse_callback(window, xpos, ypos):
        nonlocal mousex, mousey
        mousex = xpos
        mousey = ypos

    def key_callback(window, key, scancode, action, mods):
        if action != glfw.PRESS:
            return
        nonlocal scene_update, radius
        scene_update = True

        if key == glfw.KEY_ESCAPE:
            glfw.set_window_should_close(window, True)

        elif key == glfw.KEY_SPACE:  # create a random radius
            radius = random.randint(5, 100)
        elif key == glfw.KEY_1:
            radius = 10
        elif key == glfw.KEY_2:
            radius = 20
        elif key == glfw.KEY_3:
            radius = 30
        elif key == glfw.KEY_4:
            radius = 40
        elif key == glfw.KEY_5:
            radius = 50
        elif key == glfw.KEY_6:
            radius = 60
        elif key == glfw.KEY_7:
            radius = 70
        elif key == glfw.KEY_8:
            radius = 80
        elif key == glfw.KEY_9:
            radius = 90
        elif key == glfw.KEY_0:
            radius = 100

        elif key == glfw.KEY_KP_ADD:
            radius += 1
        elif key == glfw.KEY_KP_SUBTRACT:
            radius = max(1, radius - 1)

        elif key == glfw.KEY_LEFT_ALT or key == glfw.KEY_RIGHT_ALT:
            scene_update = True
        else:
            scene_update = False

    def scroll_callback(window, xoffset, yoffset):
        nonlocal zoom
        zoom += yoffset * 0.2

    # Initialize the GLFW library
    if not glfw.init():
        return

    # Create a windowed mode window and its OpenGL context
    window = glfw.create_window(w, h, "Waterman", None, None)
    if not window:
        glfw.terminate()
        return

    # Make the window's context current
    glfw.make_context_current(window)

    gl_init()

    # assign callbacks
    glfw.set_cursor_pos_callback(window, mouse_callback)
    glfw.set_key_callback(window, key_callback)
    glfw.set_scroll_callback(window, scroll_callback)

    #  polygon
    lap = None
    coords = colors = None
    face_flat = None

    def create_poly_flat():  # nim related
        nonlocal face_flat, coords, colors, lap

        start = time.time()

        face_flat, coords, colors = waterman.waterman_qhull(radius)

        lap = 1000 * (time.time() - start)


    # render(faces, coords, colors) # slow py version
    # fast_render_flat(face_flat, coords, colors)

    # Loop until the user closes the window
    while not glfw.window_should_close(window):
        # Render here
        w, h = glfw.get_window_size(window)
        setGeo(mousex, mousey, zoom, w, h)

        if scene_update:
            create_poly_flat()  # create the poly

            glfw.set_window_title(
                window,
                f"[mojo] Waterman - rad:{radius} - faces:{count_faces_flat(face_flat)}, vertices:{len(coords)}, lap:{lap:.0f}ms",
            )

            # display it

            if compiled_list != -1:  # create the compiled list
                glDeleteLists(compiled_list, 1)
            compiled_list = glGenLists(1)
            
            glNewList(compiled_list, GL_COMPILE)

            fast_render_flat(face_flat, coords, colors)

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
