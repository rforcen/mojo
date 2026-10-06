import mandel

import tkinter as tk
from PIL import Image, ImageTk
import time
import mpmath as mp
import numpy as np

# limit of f80
# center: (-0.542805847406342666821611742111741705230087973177433013916015625 - 0.61549567328280223158822048734606369180255569517612457275390625j), rad: 0.000000000000000166533453693773481063544750213623046875, iters: 500,

# limit of f128
# self.center =mp.mpc('-0.56243406072426728889959298187470929219291017913493731472946858736909456655666942', '-0.64294368894408500246476973387697065012415018769458309668738717276440723557101534'); self.rad = '1.2556741490464070167364356043671896217516462637174221962231449863715051380370347e-32'; self.iters = 300

# zoom 1.5e40
# (-0.542805847406342683678828584490162229269065807448894621033163509607757194089559636243463532528417842004143933909432462314725853502750396728515625 - 0.615495673282802233726966545777661773700339259461363014147518667123822349678220697584436465119128075178418779689337725358200259506702423095703125j), rad: 0.000000000000000000000000000000000000000068876622118493408670043156477865957684687434967114503213403420289751011296175420284271240234375, iters: 1250,

# zoom 1e55
# center: (-0.542805847406342683678828584490162229269074652433540293134606054681076942716990974084563983493087233939896823717332335972873414781533773778047377126066233045398323753261138335801661014556884765625 - 0.615495673282802233726966545777661773700340359393450195587639991075346569264788323671923575231253517874497665530635200314630806097343501171886937881552064912027422138862675637938082218170166015625j), rad: 0.0000000000000000000000000000000000000000000000000000000152936823468715418594772518185700333336746037298491403463093041925071638545253583450536627973137537850334410904906690120697021484375, iters: 1900

# nice area
# center = mp.mpf('-0.74971801248306408714983832286966036960283591220055576798131369287148118019104004', '-0.034211081890803868037028806047094334751859038418198011299864447209984064102172852')
# rad = mp.mpf('0.0000000000000000000000397046694025453283938276172193582169711589813232421875')
# iters = 2050


class MandelbrotUI(tk.Frame):
    def __init__(self, root, w, h, iters):
        self.default_center = mp.mpc("-0.5", "0")
        self.default_radius = mp.mpf("1.5")

        self.root = root
        self.lap = 0.0

        self.mandel_func = mandel.renderMP
        self.precission_desc = "fMP"
        self.precission_mp = mp.mp.dps

        self.default_geo(w, h, iters)

        # Create canvas for displaying the fractal
        self.canvas = tk.Canvas(root, width=w, height=h)
        self.canvas.pack(fill="both", expand=True)
        # set key/mouse bindings
        self.canvas.bind("<Key>", self.handle_keys)
        self.canvas.bind("<Button-1>", self.on_click)
        self.canvas.bind("<Button-3>", self.on_click_right)
        self.canvas.bind("<Button-4>", self.on_click)
        self.canvas.bind("<Button-5>", self.on_click)
        self.canvas.bind("<MouseWheel>", self.on_click)
        self.canvas.focus_set()

        # Generate and display the fractal
        self.generate_and_display()

    def default_geo(self, w, h, iters):
        self.w = w
        self.h = h
        self.iters = iters
        self.rad = self.default_radius
        self.center = self.default_center
        self.geo = []

    def handle_keys(self, event):
        if event.keysym == "Escape":
            self.root.destroy()
        elif event.keysym == "plus" or event.keysym == "equal":
            self.iters += 50
            self.generate_and_display()
        elif event.keysym == "minus" or event.keysym == "underscore":
            self.iters = max(50, self.iters - 50)
            self.generate_and_display()
        elif event.keysym == "a":
            self.center += self.rad / 2
            self.generate_and_display()
        elif event.keysym == "s":
            self.center -= self.rad / 2
            self.generate_and_display()

        elif event.keysym == "l":
            mp.mp.dps = 80
            self.center = mp.mpc(
                "-0.54280584740634268367882858449016222926907465243354029312039262030034763062217093",
                "-0.61549567328280223372696654577766177370034035939345019559741864301726447118754571",
            )
            self.rad = mp.mpf("1.66153499473114484112975882535043072e-59")
            self.iters = 2200
            self.precission_desc = "MP"
            self.mandel_func = mandel.renderMP
            self.precission_mp = mp.mp.dps
            # cpp.mandel.set_dps(self.precission_mp)

            self.generate_and_display()
        elif event.keysym == "m":  # f64 145
            self.center = mp.mpc(
                "0.25476641952991485595703125", "0.0005311667919158935546875"
            )
            self.rad = mp.mpf("0.000011444091796875")
            self.iters = 350
            self.generate_and_display()
        elif event.keysym == "n":
            self.center = mp.mpc(
                "-0.56220202130123957816449023695910543180251555548638877144858663740558269503842871",
                "-0.64281611907930380064599567644262307765213085815705577558092218834250488108602323",
            )
            self.rad = mp.mpf(
                "0.000000000000013308814531779911325976388083886801776494897961803919560818301986950182277467004"
            )
            self.iters = 450
            self.precission_desc = "MP"
            self.mandel_func = mandel.renderMP
            self.generate_and_display()

        elif event.keysym == "space":
            self.iters = 300
            self.center = self.default_center
            self.rad = self.default_radius
            self.generate_and_display()
        elif event.keysym == "p":
            print(
                f"self.center =mp.mpc('{mp.nstr(self.center.real, mp.mp.dps)}', '{mp.nstr(self.center.imag, mp.mp.dps)}'); self.rad = mp.mpf('{mp.nstr(self.rad, mp.mp.dps)}'); self.iters = {self.iters}"
            )
        elif event.keysym in ["1", "2"]:
            funcs = [
                mandel.render,
                mandel.renderMP,
            ]
            desc = ["f64", "fmp"]

            self.precission_desc = desc[int(event.keysym) - 1]
            self.mandel_func = funcs[int(event.keysym) - 1]

            self.generate_and_display()

    def on_click(self, event):
        if event.num == 1:
            self.zoom(event, positive=True)
        elif event.num == 3:
            self.zoom(event, positive=False)
        elif event.num == 4 or event.delta > 0:
            self.zoom(event, positive=True)
        elif event.num == 5 or event.delta < 0:
            self.zoom(event, positive=False)

    def on_click_right(self, event):
        self.go_back()

    def zoom(self, event, positive=True):
        # Guardamos el estado actual (center, rad, iters)
        self.geo.append((self.center, self.rad, self.iters))

        one_half = mp.mpf("0.5")
        two = mp.mpf("2.0")

        x, y = mp.mpf(str(event.x)), mp.mpf(str(event.y))
        w, h = mp.mpf(str(self.w)), mp.mpf(str(self.h))

        zf = mp.mpf("0.8")
        factor = zf if positive else 1 / zf
        aspect_ratio = w / h

        dx = (x / w - one_half) * (two * self.rad * aspect_ratio)
        dy = (y / h - one_half) * (two * self.rad * aspect_ratio)

        self.center += mp.mpc(dx, dy)
        self.rad *= factor
        # print(
        #     f"center: {mp.nstr(self.center, mp.mp.dps)}, rad: {mp.nstr(self.rad, mp.mp.dps)}, iters: {self.iters}, prec:{self.precission_mp}/{mp.mp.dps} {type(self.center)}"
        # )

        self.generate_and_display()

    def generate_and_display(self):
        # Generate the Mandelbrot set

        def mpstr(x):
            return mp.nstr(x, mp.mp.dps)
       
        image, self.lap = self.mandel_func(
            self.w,
            self.h,
            self.iters,
            mpstr(self.center.real),
            mpstr(self.center.imag),
            mpstr(self.rad),
        )

        # Convert to PIL Image and display
        pil_image = Image.fromarray(image.view(np.uint8).reshape((self.h, self.w, 4)))

        # Convert to PhotoImage for tkinter
        self.photo = ImageTk.PhotoImage(pil_image)

        # Display on canvas
        self.canvas.delete("all")
        self.canvas.create_image(0, 0, anchor="nw", image=self.photo)

        self.root.title(
            f"Mandelbrot Set ({self.precission_desc}) zoom:{mp.nstr(1 / self.rad, 2)} {self.w}x{self.h}, iters:{self.iters}, lap:{self.lap} ms {len(self.geo)}, prec:{self.precission_mp}"
        )

    def go_back(self):
        if self.geo:
            self.center, self.rad, self.iters = self.geo.pop()
            self.generate_and_display()


def ui():
    ks = 2
    w = int(ks * 1024)
    h = int(ks * 1024)
    iters = 1500

    mp.mp.dps = 80  # upto 1e77 zoom
    print(f"Mandelbrot renderer, working with {mp.mp.dps} digits of precision")

    root = tk.Tk()
    MandelbrotUI(root, w, h, iters)
    root.mainloop()


if __name__ == "__main__":
    ui()
