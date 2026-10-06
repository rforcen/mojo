lib:	 
	@g++ -O3 -c btreedx.cpp ffi_bridge.cpp	
	@mojo build -O3  btreedx.mojo -Xlinker ffi_bridge.o -Xlinker btreedx.o -Xlinker -lstdc++
	@./btreedx
