
# python binding
PY_VER="python3"
PY_INCLUDES = $(shell $(PY_VER) -m pybind11 --includes)
PY_SUFFIX = $(shell $(PY_VER)-config --extension-suffix)

sh: sh.mojo coord.mojo sh_codes.mojo color_map.mojo
	@mojo build -O3 sh.mojo
	@./sh
	@f3d --resolution 1500,1500 sh.ply	

lib: pybind.mojo sh.mojo coord.mojo sh_codes.mojo color_map.mojo
	@mojo build -O3 pybind.mojo --emit shared-lib -o sh$(PY_SUFFIX)
# 	@python3 -c "import sh; f,c,n,col=sh.calc_sh(128,0,1); print(f[:8], c[0:6], n[:6], col[:6]); print(sh.n_codes(), sh.N_COLOR_MAPS())"
	@strip sh$(PY_SUFFIX)
	@python3 ../ui_sh_mojo.py

prof:
	@mojo build -g sh.mojo
	@sudo sysctl -w kernel.perf_event_paranoid=-1
	@sudo sysctl -w kernel.kptr_restrict=0
	# Captura las muestras de CPU a alta frecuencia
	@perf record --call-graph dwarf ./sh
	# Abre el resultado de forma visual (gráfica de llamas/flamegraph)
	@hotspot perf.data