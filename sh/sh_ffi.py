import ctypes
import numpy as np

# --- 1. Definición de Estructuras FFI (C-ABI) ---


class Coord(ctypes.Structure):
    _fields_ = [("x", ctypes.c_float), ("y", ctypes.c_float), ("z", ctypes.c_float)]


class CMesh(ctypes.Structure):
    _fields_ = [
        ("coords_ptr", ctypes.POINTER(Coord)),
        ("normals_ptr", ctypes.POINTER(Coord)),
        ("colors_ptr", ctypes.POINTER(Coord)),
        ("textures_ptr", ctypes.POINTER(Coord)),
        ("vertex_count", ctypes.c_size_t),
    ]


# --- 2. Cargar y Configurar la Librería Nativa ---
# Ajusta la ruta a tu archivo .so o .dll acumulado
lib = ctypes.CDLL("mojo/libsh.so")

lib.generate_mesh.argtypes = [
    ctypes.POINTER(CMesh),
    ctypes.c_uint32,
    ctypes.c_uint32,
    ctypes.c_uint32,
]
lib.generate_mesh.restype = None

lib.free_mesh.argtypes = [ctypes.POINTER(CMesh)]
lib.free_mesh.restype = None

lib.n_codes.argtypes = []
lib.n_codes.restype = ctypes.c_uint32

lib.n_color_maps.argtypes = []
lib.n_color_maps.restype = ctypes.c_uint32

lib.gen_faces.argtypes = [ctypes.c_uint32]
lib.gen_faces.restype = ctypes.POINTER(ctypes.c_uint32)

lib.free_faces.argtypes = [ctypes.POINTER(ctypes.c_uint32), ctypes.c_size_t]
lib.free_faces.restype = None


# --- 3. Clase Wrapper en Python ---


class SphericalHarmonics:
    def __init__(self, res: int, color_map: int, code: int):
        self.res = res
        self.color_map = color_map
        self.code = code

        # Creamos el contenedor en el stack de Python
        self._cmesh = CMesh()
        self._mem_released = False

        # Llamamos a Zig para rellenar la memoria
        lib.generate_mesh(ctypes.byref(self._cmesh), res, color_map, code)

        # Atajo para la cantidad de vértices
        self.vertex_count = self._cmesh.vertex_count

        # Mapeamos los arrays a NumPy usando vistas nativas (Zero-copy)
        self.coords = self._as_numpy_array(self._cmesh.coords_ptr)
        self.normals = self._as_numpy_array(self._cmesh.normals_ptr)
        self.colors = self._as_numpy_array(self._cmesh.colors_ptr)
        self.textures = self._as_numpy_array(self._cmesh.textures_ptr)

    def _as_numpy_array(self, ptr) -> np.ndarray:
        """Helper interno para mapear punteros f32 a vistas de NumPy (Nx3)."""
        if not ptr or self.vertex_count == 0:
            return np.empty((0, 3), dtype=np.float32)

        # Casteamos el puntero a float crudo y creamos la vista
        float_ptr = ctypes.cast(ptr, ctypes.POINTER(ctypes.c_float))
        return np.ctypeslib.as_array(float_ptr, shape=(self.vertex_count, 3))

    def free(self):
        """Libera explícitamente la memoria en el lado de Zig."""
        if not self._mem_released:
            lib.free_mesh(ctypes.byref(self._cmesh))
            self._mem_released = True
            # Invalidamos las vistas de NumPy para evitar leer basura accidentalmente
            self.coords = self.normals = self.colors = self.textures = None

    def __del__(self):
        """Destructor automático de Python. Se ejecuta al perder la referencia."""
        self.free()

def n_codes():
    return lib.n_codes()

def N_COLOR_MAPS():
    return lib.n_color_maps()

def calc_sh(res: int, color_map: int, code: int) -> SphericalHarmonics:
    sh = SphericalHarmonics(res, color_map, code)

    # get faces, create a copy and free
    faces_ptr = lib.gen_faces(res)
    faces_ptr_cast = ctypes.cast(faces_ptr, ctypes.POINTER(ctypes.c_uint32))
    faces_array = np.ctypeslib.as_array(faces_ptr_cast, shape=(res * res, 4)).copy()
    lib.free_faces(faces_ptr, res * res * 4)

    return (
        faces_array,
        sh.coords.copy(),
        sh.normals.copy(),
        sh.colors.copy(),
        sh.textures.copy(),
    )


if __name__ == "__main__":
    faces, coords, normals, colors, textures = calc_sh(1024, 1, 0)
    print("Vértices generados:", len(coords))
    print("Coordenadas del vértice 0:", coords[0], normals[0], colors[0])
    print("Caras generadas:", faces[:10])
