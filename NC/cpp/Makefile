cc = g++

includes = nc.h Timer.h

warns = -Wno-multichar -Wno-subobject-linkage -Wno-return-type
opts=-std=c++2a -O3 -march=native -fPIC -fopenmp -pthread
libs=-lquadmath -lgmp -lmpfr

PY_VER="python3"
PY_INCLUDES = $(shell $(PY_VER) -m pybind11 --includes)
PY_SUFFIX = $(shell $(PY_VER)-config --extension-suffix)

.SILENT: pylib
pylib: ncClassPy.cpp $(includes)
	$(cc) $(opts) $(warns) -shared\
	 $(PY_INCLUDES) ncClassPy.cpp\
	 $(libs)\
	 -o numc$(PY_SUFFIX) 

test: nc_test.cpp nc.h
	$(cc) $(opts) $(warns) nc_test.cpp -o nc_test $(libs)
	./nc_test

lib:
	@$(cc) $(opts) $(warns) -c nc_wrap.cpp 

clean:
	rm -f numc*.so NC libnumc.a