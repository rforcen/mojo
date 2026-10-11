"""
n queens ui using mojo based solver
"""

import tkinter as tk
import nqueens
import numpy as np
import time

limit = 64000 - 1


class UI_NQueens:
    def __init__(self, solution):
        self.solution = solution

        self.n = len(solution)
        # self.transformed_positions = nqueens.getAllSymmetries(self.positions)
        self.lap = 0
        self.n_tr = 0
        self.draw_grid = True

        self.root = tk.Tk()

        self.disp_title()
        self.root.geometry("1800x1800")

        # Create canvas that expands with the window
        self.canvas = tk.Canvas(self.root, bg="black", highlightthickness=0)
        self.canvas.pack(fill=tk.BOTH, expand=True)

        # Re-draw whenever the window is resized
        self.canvas.bind("<Configure>", self.draw)

        self.root.bind("<KP_Add>", self.inc_n)
        self.root.bind("<KP_Subtract>", self.dec_n)
        
        self.root.bind("<Prior>", self.inc_n_100)
        self.root.bind("<Next>", self.dec_n_100)
        self.root.bind("<g>", self.toggle_grid)
        for c in range(1, 10):
            self.root.bind_all(f"{c}", self.set_n)
            self.root.bind_all(f"<KP_{c}>", self.set_n)

        self.root.bind("<Escape>", self.close)

    def solve(self):
        self.time = time.time()
        self.solution = nqueens.solve(self.n)
        self.lap = (time.time() - self.time) * 1000

    def set_n(self, event):
        n = int(event.char)
        if n < 4:
            n = n * 10
        self.n = n
        self.update_ui()

    def toggle_grid(self, event):
        self.draw_grid = not self.draw_grid
        self.draw()

    def close(self, event):
        self.root.destroy()

    def disp_title(self):
        if len(self.solution) == 0:
            return
        self.root.title(f"{self.n}-Queens, lap: {self.lap:6.0f} ms")

    def inc_n(self, event):
        if self.n < limit:  # current limit
            self.n += 1
            self.solution = list(range(self.n))  # Reset positions for new size
            self.update_ui()

    def dec_n(self, event):
        if self.n > 4:
            self.n -= 1
            self.solution = list(range(self.n))  # Reset positions for new size
            self.update_ui()

    def inc_n_100(self, event):
        if self.n < limit:  # current limit
            self.n += 100
            self.solution = list(range(self.n))  # Reset positions for new size
            self.update_ui()

    def dec_n_100(self, event):
        if self.n > 104:
            self.n -= 100
            self.solution = list(range(self.n))  # Reset positions for new size
            self.update_ui()

    def update_ui(self):
        self.lap = 0
        self.solution = []

        lap = time.time()
        self.solution = nqueens.solve(self.n)
        self.lap = (time.time() - lap) * 1000

        self.disp_title()
        self.draw()

    def draw(self, event=None):
        self.canvas.delete("all")

        # Get current window dimensions
        w = self.canvas.winfo_width()
        h = self.canvas.winfo_height()

        # Use the smaller dimension to keep the board square
        board_pixel_size = min(w, h) * 0.99  # 90% of available space
        cell_size = board_pixel_size / self.n

        # Calculate offsets to center the square board
        offset_x = (w - board_pixel_size) / 2
        offset_y = (h - board_pixel_size) / 2

        # Draw Grid
        if self.draw_grid:
            for i in range(self.n + 1):
                line_pos = i * cell_size
                # Vertical
                self.canvas.create_line(
                    offset_x + line_pos,
                    offset_y,
                    offset_x + line_pos,
                    offset_y + board_pixel_size,
                    fill="white",
                )
                # Horizontal
                self.canvas.create_line(
                    offset_x,
                    offset_y + line_pos,
                    offset_x + board_pixel_size,
                    offset_y + line_pos,
                    fill="white",
                )

        # Draw Queens (90% of cell size)
        if self.draw_grid:
            padding = cell_size * 0.1
        else:
            padding = cell_size * 1.5
            if padding < 2:
                padding = 2

        for row, col in enumerate(self.solution):
            x1 = offset_x + (col * cell_size) + padding
            y1 = offset_y + (row * cell_size) + padding
            x2 = offset_x + ((col + 1) * cell_size) - padding
            y2 = offset_y + ((row + 1) * cell_size) - padding

            self.canvas.create_oval(x1, y1, x2, y2, fill="yellow")

    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    UI_NQueens(nqueens.solve(31)).run()
