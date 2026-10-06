# python binding
PY_VER="python3"
PY_INCLUDES = $(shell $(PY_VER) -m pybind11 --includes)
PY_SUFFIX = $(shell $(PY_VER)-config --extension-suffix)
SOURCES = polyhedron.mojo seeds.mojo common.mojo packed.mojo pybind.mojo vertex.mojo

lib: pybind.mojo $(SOURCES)
	@mojo build -O3 pybind.mojo --emit shared-lib -o poly$(PY_SUFFIX)
	@python3 poly_ui.py

prof:
	@mojo build -O3 conway.mojo 
	@sudo sysctl -w kernel.perf_event_paranoid=-1
	@sudo sysctl -w kernel.kptr_restrict=0
	# Captura las muestras de CPU a alta frecuencia
	@perf record --call-graph dwarf ./conway	
	@hotspot perf.data