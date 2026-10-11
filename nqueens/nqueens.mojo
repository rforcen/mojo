"""N-queens problems solved using min conflicts algo.
 
  @brief Solves the N-Queens problem using the Min-Conflicts local search
  heuristic.
  Algorithm Overview:
  1. Initial State: Start with a greedy or random assignment of queens (one per
  column).
  2. Iteration:
  a. Randomly select a column 'c' that has at least one conflict.
  b. Within column 'c', find the row 'r' that results in the minimum number of
  total conflicts (attacking pairs).
  c. If multiple rows have the same minimum, pick one at random to avoid local
  optima. d. Move the queen in column 'c' to row 'r'.
  3. Termination: Repeat until zero conflicts remain or the maximum step limit
  is reached.
  Complexity & Optimization:
  - Traditional lookup is O(N) per move.
  - Optimized via frequency maps (rows, main diagonals, anti-diagonals) to
  achieve O(1) conflict calculation per row, making each iteration O(N) total.
"""

from std.testing.prop.random import Rng
from std.time import perf_counter
from std.random.random import shuffle
#
comptime Board = List[Int32]
#
struct NQueens:
    var n : Int32
    var board : Board
    var col_counts : List[Int32]
    var d1_counts : List[Int32]
    var d2_counts : List[Int32]

    var conflicted_rows : List[Int32]
    var best_cols : List[Int32]

    var rand : Rng

    def __init__(out self, n: Int32):
        self.n = n
        self.board = List[Int32](length=Int(n), fill=0)
        self.col_counts = List[Int32](length=Int(n), fill=0)
        self.d1_counts = List[Int32](length=Int(2 * n - 1), fill=0)
        self.d2_counts = List[Int32](length=Int(2 * n - 1), fill=0)
        self.conflicted_rows = List[Int32](length=Int(n), fill=0)
        self.best_cols = List[Int32](length=Int(n), fill=0)
        self.rand = Rng(seed=Int(perf_counter()))

        # shuffle board[i]=i
        for i in range(n): self.board[i] = i
        shuffle(self.board)

        # fill conflict counts
        for r in range(n):
            var c = self.board[r]
            self.col_counts[c] += 1
            self.d1_counts[r + c] += 1
            self.d2_counts[r + n - 1 - c] += 1

    def __init__(out self, board : Board):
        self = Self(Int32(len(board)))
        self.board = board.copy()

    @always_inline
    def random_range(mut self, _max: Int32) raises -> Int32:
        return Int32(self.rand.rand_int(min=0, max=Int(_max)-1))

    def one_iter(mut self) raises -> Bool:
        # Find all conflicted queens
        var num_conflicted = Int32(0)
        for r in range(self.n):
            var c = self.board[r]
            # A queen is conflicted if there's more than 1 queen in its
            # column/diagonals
            if self.col_counts[c] > 1 or 
               self.d1_counts[r + c] > 1 or 
               self.d2_counts[r + self.n - 1 - c] > 1:

                self.conflicted_rows[num_conflicted] = r
                num_conflicted += 1
        
        if num_conflicted == 0: return True # got a valid board
        
        # Pick a random conflicted queen to repair
        var target_row = self.conflicted_rows[self.random_range(num_conflicted)]

        # "Lift" the queen: remove her influence before scanning for a better spot
        var old_c = self.board[target_row]

        self.col_counts[old_c]-=1
        self.d1_counts[target_row + old_c]-=1
        self.d2_counts[target_row + (self.n - 1) - old_c]-=1

        # Find columns with MINIMUM conflicts
        var min_c    = Int32(self.n + 1)
        var num_best = Int32(0)

        for c_try in range(self.n):
            # Calculate how many conflicts this queen would have in column 'c_try'
            var curr_c = self.col_counts[c_try] + self.d1_counts[target_row + c_try] + self.d2_counts[target_row + (self.n - 1) - c_try]

            if curr_c < min_c:
                min_c = curr_c
                self.best_cols[0] = c_try
                num_best = 1

                if min_c == 0: break
            elif curr_c == min_c:
                self.best_cols[num_best] = c_try
                num_best += 1

        # Move to a randomly chosen "best" column
        var new_col = self.best_cols[self.random_range(num_best)]
        self.board[target_row] = new_col

        # "Place" the queen: update counts
        self.col_counts[new_col]+=1
        self.d1_counts[target_row + new_col]+=1
        self.d2_counts[target_row + (self.n - 1) - new_col]+=1

        return False
        
    def reset(mut self):
        self = Self(self.n)
    
    def solve(mut self) raises -> Board:
        var iter=0
        while not self.one_iter():
            iter += 1
            if iter > 2000:
                self.reset()
                iter = 0
        
        return self.board.copy()

    def is_valid(self) -> Bool: return Self.is_valid(self.board)

    @staticmethod
    def is_valid(board: Board) -> Bool:
        var n        = len(board)
        
        var cols = List[Bool](length=n, fill=False)        
        var d1 = List[Bool](length=2 * n, fill=False)        
        var d2 = List[Bool](length=2 * n, fill=False)
        
        for _r in range(n):
            var r = Int32(_r)
            var c = board[r]
            if cols[c] or d1[r + c] or d2[r + (Int32(n) - 1) - c]:
                return False
            cols[c] = True
            d1[r + c] = True
            d2[r + (Int32(n) - 1) - c] = True
        return True

    def get_all_symmetries(mut self) -> List[Board]:
        var symmetries = Dict[Board, Bool]()
        var n = self.n
        var b_res = List[Int32](length=Int(n), fill=0)
        var current = self.board.copy()

        for _ in range(4):
            if current not in symmetries:            
                symmetries[current.copy()] = True
            
            # reflect, Horizontal reflection: (row, col) -> (row, n - 1 - col)
            for r in range(n): b_res[r] = (n - 1) - current[r]
            if b_res not in symmetries: symmetries[b_res.copy()] = True

            # rotate 90º
            for r in range(n): b_res[current[r]] = (n - 1) - r
            if b_res not in symmetries: symmetries[b_res.copy()] = True

            current = b_res.copy()
        
        return List[Board](symmetries.keys())

# python ffi
# python bynding
# mojo build -O3 nqueens.mojo --emit shared-lib -o nqueens$(PY_SUFFIX) 
from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder
from std.python.numpy import copy_to_numpy_array, from_numpy_array
#
from std.ffi import external_call
from std.sys.info import size_of
#

def py_solve(n: PythonObject) -> PythonObject:
    """Generate a board solution for n."""
    try:
        var nq = NQueens(Int32(py=n))
        var board = nq.solve()
        return copy_to_numpy_array(board)
    except:
        print("solve: Error generating board solution")
        return None

def py_is_valid(board: PythonObject) -> PythonObject:
    """Check if a board (numpy int32) solution is valid."""
    try: # convert numpy input to a list
        return PythonObject(NQueens.is_valid(List[Int32](from_numpy_array[DType.int32](board))))
    except:
        print("is_valid: Error checking board solution")
        return PythonObject(False)

def py_generate_symmetries(board: PythonObject) -> PythonObject:
    """Generate all symmetries for a board (numpy int32) returned by solve."""
    try: # convert numpy input to a list        
        var nq = NQueens(List[Int32](from_numpy_array[DType.int32](board)))

        var res = Python.list() # Python list of Python lists
        for sym in nq.get_all_symmetries(): # List[List[Int32]]
            var l = Python.list()
            for x in sym: l.append(x)
            res.append(l)
        return res
        
    except:
        print("generate_symmetries: Error generating symmetries")
        return PythonObject(None)

# python module init
@export
def PyInit_nqueens() abi("C") -> PythonObject:
    """Initialize the nqueens module."""
    try:
        var builder = PythonModuleBuilder("nqueens")
        builder.def_function[py_solve]("solve", "Generate a board solution for n")
        builder.def_function[py_is_valid]("is_valid", "Check if a board solution is valid")
        builder.def_function[py_generate_symmetries]("generate_symmetries", "Generate all symmetries for a board")
        return builder.finalize()
    except:
        print("PyInit_nqueens: Error building module nqueens")
        return None


# test
def test() raises:
    for i in range(4, 10000, 100):
        var lap = perf_counter()
        var nq = NQueens(Int32(i))
        var board = nq.solve()

        if not nq.is_valid(): raise Error(t"queens({i}): invalid solution")
        
        print(t"queens({i}): {board[:min(i,10)]}, lap: {Int32(1000*(perf_counter() - lap))} ms", end=', ')
    
        for s in nq.get_all_symmetries():
            print(t"{s[:min(i,5)]}, {NQueens.is_valid(s)}", end=", ")
        print()

        