ARCHIVE_LIB = `whereis libarchive.so | cut -d' ' -f2` # /usr/lib/x86_64-linux-gnu/libarchive.so

it: dailyIter.mojo daily.mojo common.mojo targz.mojo
	@mojo build -g dailyIter.mojo -Xlinker $(ARCHIVE_LIB)  # must build to link!!!
	@./dailyIter

a: daily.mojo common.mojo targz.mojo
	@mojo build -O3 daily.mojo -Xlinker $(ARCHIVE_LIB)  # must build to link!!!
	@./daily

c:
	@mojo -O3 common.mojo
	