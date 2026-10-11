# python binding
PY_VER="python3"
PY_INCLUDES = $(shell $(PY_VER) -m pybind11 --includes)
PY_SUFFIX = $(shell $(PY_VER)-config --extension-suffix)

py: $(SOURCES)
	@mojo build -O3 nqueens.mojo --emit shared-lib -o nqueens$(PY_SUFFIX) $(MOJO_LINK)
test_py:
	@python3 -c "import nqueens; b=nqueens.solve(8); print(b, nqueens.is_valid(b)); print(nqueens.generate_symmetries(b))"
	
