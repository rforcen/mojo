import mandel
import numpy as np
from PIL import Image

w = 2048
h = 2048
iters = 100

center_re = "-0.5"
center_im = "0"
rad = "1.5"

image, lap = mandel.render(w, h, iters, center_re, center_im, rad)
print(f"F64 render time: {int(lap)} ms")
Image.fromarray(image.view(np.uint8).reshape(h, w, 4)).show()

image, lap = mandel.renderMP(
    w,
    h,
    2200,
    "-0.54280584740634268367882858449016222926907465243354029312039262030034763062217093",
    "-0.61549567328280223372696654577766177370034035939345019559741864301726447118754571",
    "1.66153499473114484112975882535043072e-59",
)
print(f"MP render time: {int(lap)} ms")
Image.fromarray(image.view(np.uint8).reshape(h, w, 4)).show()
