GMP_LIB = `whereis libgmp.so | cut -d' ' -f2` # /usr/lib/x86_64-linux-gnu/libgmp.so

# python binding
PY_VER="python3"
PY_INCLUDES = $(shell $(PY_VER) -m pybind11 --includes)
PY_SUFFIX = $(shell $(PY_VER)-config --extension-suffix)

mm:
	@mojo build -O3 mandelMP.mojo -Xlinker $(GMP_LIB)
	@./mandelMP
	@display mandelMP.pam

mp: mp.mojo
	@ mojo build -O3 mp.mojo -Xlinker $(GMP_LIB)
	@ ./mp

test:
	@mojo build -O3 mandel_test.mojo -Xlinker $(GMP_LIB)
	@./mandel_test
	@display mandel.pam

lib: pybind.mojo mandel.mojo mandelMP.mojo mp.mojo file_palette.mojo
	@mojo build -O3 pybind.mojo --emit shared-lib -Xlinker $(GMP_LIB) -o mandel$(PY_SUFFIX)
	@strip mandel$(PY_SUFFIX)
	@python3 test_mandel.py

clean:
	@rm -f *so *pam