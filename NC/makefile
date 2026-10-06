LIBS = -Xlinker -lstdc++ -Xlinker -lquadmath -Xlinker -lgmp -Xlinker -lmpfr -Xlinker -lgomp -Xlinker -lm
w:
	@mojo build numojo.mojo -Xlinker ../cpp/nc_wrap.o $(LIBS)
	@./numojo