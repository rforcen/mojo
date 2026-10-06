# python binding
PY_VER="python3"
PY_INCLUDES = $(shell $(PY_VER) -m pybind11 --includes)
PY_SUFFIX = $(shell $(PY_VER)-config --extension-suffix)
SOURCES = dc.mojo cmath.mojo expr_gen.mojo zcompiler.mojo

dc: $(SOURCES)
	@mojo build -O3 dc.mojo
	@./dc
	@display dc.pam

lib: pybind.mojo $(SOURCES)
	@mojo build -O3 pybind.mojo --emit shared-lib -o dc$(PY_SUFFIX)

cmp:
	mojo zcompiler.mojo

prof:
	@mojo build -g dc.mojo
	@sudo sysctl -w kernel.perf_event_paranoid=-1
	@sudo sysctl -w kernel.kptr_restrict=0
	# Captura las muestras de CPU a alta frecuencia
	@perf record --call-graph dwarf ./dc
	# Abre el resultado de forma visual (gráfica de llamas/flamegraph)
	@hotspot perf.data