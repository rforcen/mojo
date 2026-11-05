f493:
    # fortran single precision f32, double precision f64
	@gfortran -c -Ofast -fdefault-double-8 493.f
	@mojo build rpoly.mojo -Xlinker 493.o -Xlinker -lm
	@./rpoly

clean:
	@rm -f rpoly 493.o
