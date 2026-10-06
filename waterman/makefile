#
# Qhull library path
qhpath = /home/asd/code/waterman/qhull/qhull-2020.2
qhlib = $(qhpath)/lib/libqhullstatic_r.a
qhinclude = $(qhpath)/src

# python binding
PY_VER="python3"
PY_INCLUDES = $(shell $(PY_VER) -m pybind11 --includes)
PY_SUFFIX = $(shell $(PY_VER)-config --extension-suffix)

SOURCES = qhull.mojo waterman_f64.mojo vector3d_f64.mojo
MOJO_SRC = quickhull3d.mojo face.mojo facelist.mojo halfedge.mojo mempool.mojo vector3d.mojo vertex.mojo vertexlist.mojo waterman.mojo

# mojo bind
MOJO_LINK = -Xlinker qhull_wrapper.o -Xlinker $(qhlib) -Xlinker -lm

ui: ui.mojo glfw.mojo $(MOJO_SRC)
	@mojo build -O3 ui.mojo -Xlinker -lglfw -Xlinker -lGL -Xlinker -lGLU
	@./ui
	
mlib: $(MOJO_SRC)
	@mojo build -O3 quickhull3d.mojo --emit shared-lib -o waterman$(PY_SUFFIX) 
	@python3 poly_ui.py

lib: $(SOURCES)
	@gcc -O3 -fPIC -c qhull_wrapper.c -I$(qhinclude)  -o qhull_wrapper.o
	@mojo build -O3 qhull.mojo --emit shared-lib -o waterman$(PY_SUFFIX) $(MOJO_LINK)
	@python3 poly_ui.py

qhull:
	@gcc -O3 -fPIC -c qhull_wrapper.c -I$(qhinclude)  -o qhull_wrapper.o
	@mojo build qhull.mojo $(MOJO_LINK)
	@./qhull

test:
	@mojo quickhull3d.mojo

py:
	@python3 poly_ui.py