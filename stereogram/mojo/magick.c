// gcc -c  $(pkg-config --cflags --libs MagickWand) magick.c
#include <stdint.h>
#include <MagickWand/MagickWand.h>
#include <stdio.h>
#include <stdlib.h>

/**
 * open, rotate -90, resize, extract RGB
 *
 * @param input file name
 * @param width target width
 * @param height target height
 *
 * @return Pointer to the memory with the RGB pixels (3 bytes per pixel) or NULL
 * in case of error.
 */
unsigned char *process_image_to_rgb(const char *filename, int width,
                                    int height) {

  // 1. Initialize the global ImageMagick environment internally
  MagickWandGenesis();

  MagickWand *wand = NULL;
  PixelWand *bg_color = NULL;
  unsigned char *rgb_pixels = NULL;

  wand = NewMagickWand();

  // 2. Load image from disk
  if (MagickReadImage(wand, filename) == MagickFalse) {
    fprintf(stderr, "can't open image: %s\n", filename);
    goto cleanup;
  }

  // 3. Rotate always -90 degrees first
  bg_color = NewPixelWand();
  PixelSetColor(bg_color,
                "black"); // Color of background in case the canvas expands
  if (MagickRotateImage(wand, bg_color, -90.0) == MagickFalse) {
    fprintf(stderr, "can't rotate image: %s\n", filename);
    goto cleanup;
  }

  // 4. resize
  if (width > 0 && height > 0) {
    if (MagickResizeImage(wand, (size_t)width, (size_t)height,
                          LanczosFilter) == MagickFalse) {
      fprintf(stderr, "can't resize image: %s\n", filename);
      goto cleanup;
    }
  }

  // 5. Get the final dimensions exactly
  size_t final_w = MagickGetImageWidth(wand);
  size_t final_h = MagickGetImageHeight(wand);

  // 6. Reserve memory for RGB (3 bytes per pixel: R, G, B) -> must free after
  // usage
  size_t buffer_size = final_w * final_h * 3;
  rgb_pixels = (unsigned char *)malloc(buffer_size);
  if (!rgb_pixels) {
    fprintf(stderr, "can't allocate memory: %zu bytes\n", buffer_size);
    goto cleanup;
  }

  // 7. Export pixels to RGB format
  if (MagickExportImagePixels(wand, 0, 0, final_w, final_h, "RGB", CharPixel,
                              rgb_pixels) == MagickFalse) {
    fprintf(stderr, "can't export pixels RGB.\n");
    free(rgb_pixels);
    rgb_pixels = NULL;
    goto cleanup;
  }

cleanup:
  // Free local resources of the image session
  if (bg_color)
    DestroyPixelWand(bg_color);
  if (wand)
    DestroyMagickWand(wand);

  // 8. Finalize the global ImageMagick environment
  MagickWandTerminus();

  return rgb_pixels;
}

/**
 * save image to disk
 * 
 * @param filename file path to save the image
 * @param format format of the image (e.g., "RGB", "ARGB")
 * @param rgb_pixels pointer to the image data
 * @param width image width
 * @param height image height
 * @return 0 si éxito, 1 en caso de error.
 */
int save_image(const char *filename, char*format, uint32_t *rgb_pixels, int width, int height) {
    if (!rgb_pixels || width <= 0 || height <= 0) {
        fprintf(stderr, "Error: invalid parameters for saving image, w:%d, h:%d.\n", width, height);
        return 1;
    }

    // Inicializar entorno global de ImageMagick de forma autosuficiente
    MagickWandGenesis();

    MagickWand *wand = NewMagickWand();
    int status = 1;

    // 1. Crear una nueva imagen en blanco con las dimensiones especificadas
    PixelWand *bg = NewPixelWand();
    PixelSetColor(bg, "black");
    if (MagickNewImage(wand, (size_t)width, (size_t)height, bg) == MagickFalse) {
        fprintf(stderr, "Error: can't create a new image in MagickWand, w:%d, h:%d.\n", width, height);
        goto cleanup_save;
    }

    // 2. Importar los píxeles desde el puntero hacia el wand
    // Usamos "BGRA" y CharPixel asumiendo que el búfer contiene bytes planos de color
    if (MagickImportImagePixels(wand, 0, 0, (size_t)width, (size_t)height, format, CharPixel, rgb_pixels) == MagickFalse) {
        fprintf(stderr, "Error: can't import pixels to MagickWand.\n");
        goto cleanup_save;
    }

    // 3. Escribir la imagen al archivo en disco
    if (MagickWriteImage(wand, filename) == MagickFalse) {
        fprintf(stderr, "Error: can't save image to %s\n", filename);
        goto cleanup_save;
    }

    status = 0; // Éxito

cleanup_save:
    if (bg) DestroyPixelWand(bg);
    if (wand) DestroyMagickWand(wand);
    MagickWandTerminus();

    return status;
}

// free image pointer allocated prev.
void free_rgb_pixels(unsigned char *rgb_pixels) {
  if (rgb_pixels) {
    free(rgb_pixels);
  }
}
