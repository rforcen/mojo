#!//usr/bin/python
# Domain Coloring ui

import tkinter as tk
from tkinter import filedialog
from PIL import Image, ImageTk
import dc
import numpy as np
import os

complexity = 7
session_path = "dc-session"

bench_expr = "(((((0.25/z)+sin(0.60))/tan((z-0.11)))-c(((z^0.92)/(1.00/0.21)),((i*0.71)-(0.86/i))))+c((sin(exp(0.66))^((i^z)/log(0.93))),asin(((0.79^0.02)*acos(0.10))))) "


class DC_image_control(tk.Frame):
    def __init__(self, parent, w: int, h: int, expr_entry: tk.Entry, n_kb: int):
        super().__init__(parent)
        self.w = w
        self.h = h
        self.expr_entry = expr_entry
        self.rand_expression()
        self.expression = bench_expr
        self.expressions = [self.expression]
        self.expr_index = 0
        self.n_kb = n_kb * 1024

        if not os.path.exists(session_path):
            os.mkdir(session_path)

        # load image
        self.recalc()

        # Create the label
        self.image_label = tk.Label(self)
        self.image_label.pack(fill="both", expand=True)

        # Bind the resize event
        self.bind("<Configure>", self.resize_image)

        # Bind keyboard events to the Top Level Window (parent)
        self.winfo_toplevel().bind("<Key>", self.handle_keys)

    def set_expression(self, expr: str):
        self.expr_entry.delete(0, tk.END)
        self.expr_entry.insert(0, expr)

    def handle_keys(self, event):
        update = True

        key = event.keysym

        # random dc

        if key == "Alt_L" or key == "Alt_R":
            self.rand_expression()
            self.expressions.append(self.expression)

            self.set_expression(self.expression)

            image, self.ms = dc.generate_dc(self.w, self.w, self.expression)

            image_view = image.view(np.uint8).reshape(self.w, self.w, 4)
            img = Image.fromarray(image_view, "RGBA")
            self.original_image = img

            self.winfo_toplevel().title(
                f"Domain Coloring {self.w}x{self.w}, lap:{self.ms} ms"
            )

        elif key == "Up":
            # Go to previous expression
            if (
                len(self.expressions) > 1
                and self.expr_index < len(self.expressions) - 1
            ):
                self.expr_index += 1
                self.expression = self.expressions[self.expr_index]

                print(self.expression)
                self.winfo_toplevel().title(
                    f"Domain Coloring {self.expression} {self.w}x{self.h}, lap:{self.ms} ms"
                )
                self.recalc()
                self.update_image()

        elif key == "Down":
            # Go to next expression
            if len(self.expressions) > 1 and self.expr_index > 0:
                self.expr_index -= 1
                self.expression = self.expressions[self.expr_index]
                print(self.expression)
                self.winfo_toplevel().title(
                    f"Domain Coloring {self.expression} {self.w}x{self.h}, lap:{self.ms} ms"
                )
                self.recalc()
                self.update_image()

        elif (event.state & 0x4) and key == "l":  # ctrl-l: load session
            self.load_session()

        elif (event.state & 0x4) and key == "s":  # ctrl-s: save session
            self.save_session()

        elif (event.state & 0x4) and key == "i":  # ctrl-i: save image
            self.save_image()

        elif key == "Escape":  # quit
            self.save_session()

            self.winfo_toplevel().destroy()
            return
        else:
            update = False

        if update:
            self.update_image()

    def load_session(self):
        filename = filedialog.askopenfilename(
            title="Select a session file", filetypes=[("Text files", "dc_session*.txt")]
        )
        if filename:
            with open(filename, "r") as f:
                lines = f.readlines()
                self.expressions = [line.strip() for line in lines if line.strip()]
                if self.expressions:
                    self.expression = self.expressions[0]
                    self.expr_index = 0
                    self.recalc()
                    self.update_image()
                    self.winfo_toplevel().title(
                        f"Domain Coloring {self.expression} {self.w}x{self.h}, lap:{self.ms} ms"
                    )

    def save_session(self):
        # save session in next file (start from 0)
        index = 0
        filename = f"{session_path}/dc_session{index}.txt"

        # Keep incrementing until a filename that DOES NOT exist is found
        while os.path.exists(filename):
            index += 1
            filename = f"{session_path}/dc_session{index}.txt"

        with open(filename, "w") as f:
            for expr in self.expressions:
                f.write(expr + "\n")
        print(f"Session saved to {filename}")

    def rand_expression(self):
        self.expression = dc.random_expression(complexity)

    def update_image(self):
        self.tk_image = ImageTk.PhotoImage(self.original_image)
        self.image_label.config(image=self.tk_image)

    def recalc(self):
        self.set_expression(self.expression)

        image, self.ms = dc.generate_dc(self.w, self.w, self.expression)

        self.winfo_toplevel().title(
            f"Domain Coloring {self.w}x{self.w}, lap:{self.ms} ms"
        )
        image_view = image.view(np.uint8).reshape(self.w, self.w, 4)
        img = Image.fromarray(image_view, "RGBA")
        self.original_image = img

    def recalc_size(self, w, h):
        self.set_expression(self.expression)

        image, self.ms = dc.generate_dc(w, h, self.expression)

        self.winfo_toplevel().title(
            f"Domain Coloring {w}x{h}, lap:{self.ms} ms"
        )
        image_view = image.view(np.uint8).reshape(w, w, 4)
        img = Image.fromarray(image_view, "RGBA")
        self.original_image = img

    def resize_image(self, event):
        # 1. Get new dimensions (from the event object)
        self.w = event.width
        self.h = event.height

        self.recalc()

        self.update_image()

    def save_image(self):
        if hasattr(self, "original_image"):

            index = 0
            filename = f"{session_path}/dc_img{index}.png"

            # Keep incrementing until a filename that DOES NOT exist is found
            while os.path.exists(filename):
                index += 1
                filename = f"{session_path}/dc_img{index}.png"

            self.recalc_size(self.n_kb, self.n_kb)

            self.original_image.save(filename)
            print(f"Image saved as {filename}")

            self.recalc_size(self.w, self.h)

    def spin(self, n):
        self.n_kb = n * 1024

    def recalc_expr(self, event):
        self.expression = event.widget.get()
        self.recalc()
        self.update_image()


if __name__ == "__main__":
    w = h = int(1024 * 2)

    root = tk.Tk()
    # dpi = root.winfo_fpixels('1i')
    # scale = dpi / 72  # Tkinter usa 72 como base interna para winfo_fpixels

    # # Ajustamos el valor para compensar el escalado de Wayland
    # w = int(w / (scale / 1.333)) # 1.333 es la relación 96/72
    # h = int(h / (scale / 1.333))
    root.geometry(f"{w}x{h}")
    root.title("Domain Coloring")

    # tool bar to hold expression entry and controls
    tool_bar = tk.Frame(root)
    tool_bar.pack(side="top", fill="x", padx=5, pady=5)

    tk.Label(tool_bar, text="expression").pack(side="left")

    expr_entry = tk.Entry(tool_bar)
    expr_entry.pack(side="left", fill="x", expand=True, padx=5)
    expr_entry.bind("<Return>", lambda e: app.recalc_expr(e))

    tk.Button(tool_bar, text="save image", command=lambda: app.save_image()).pack(
        side="right"
    )
    tk.Button(tool_bar, text="save session", command=lambda: app.save_session()).pack(
        side="right"
    )
    tk.Button(tool_bar, text="load session", command=lambda: app.load_session()).pack(
        side="right"
    )

    tk.Label(tool_bar, text="img. size (mb):").pack(side="left")
    session_num = tk.Spinbox(
        tool_bar,
        from_=1,
        to=32,
        width=5,
        command=lambda: app.spin(int(session_num.get())),
    )
    session_num.pack(side="left", padx=5)

    app = DC_image_control(root, w, h, expr_entry, int(session_num.get()))
    app.pack(side="right", fill="both", expand=True)

    root.mainloop()
