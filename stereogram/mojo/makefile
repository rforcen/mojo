MAGICWAND = `pkg-config --libs MagickWand`
empty :=
space := $(empty) $(empty)
MAGICWAND_LIBS = $(shell pkg-config --libs MagickWand)
MAGIC_LINK = -Xlinker magick.o -Xlinker $(subst $(space), -Xlinker ,$(MAGICWAND_LIBS))

stereo: stereogram.mojo magick.c
	@gcc -c  `pkg-config --cflags MagickWand` magick.c
	@mojo build stereogram.mojo $(MAGIC_LINK)
	@./stereogram
	@display textured_sird.png

magick: magick.mojo magick.c
	@gcc -c  `pkg-config --cflags MagickWand` magick.c
	@mojo build magick.mojo $(MAGIC_LINK)
	@./magick
    