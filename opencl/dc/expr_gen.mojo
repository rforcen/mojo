# random expression generator
from  std.testing.prop import Rng
from std.time import perf_counter
from std.math import round

struct ExpressionGenerator:
    var rand: Rng
    var vars: Array[String, 2]
    var ops: Array[String, 5]
    var funcs : Array[String, 12]
    
    def __init__(out self):
        self.rand = Rng(seed=Int(perf_counter()))

        self.vars = ["z", "i"]
        self.ops = ["+", "-", "*", "/", "^"]
        self.funcs = ["sin", "cos", "tan", "exp", "log", "log10", "int", "sqrt", "asin", "acos", "atan", "abs"]
    
    def randint(mut self, top: Int) -> Int:
        try:
            return self.rand.rand_int(min=0, max=top-1)
        except:
            return 0
    
    def generate(mut self, complexity: Int) -> String:
        if complexity == 0: return self.generateTerminal()
        
        var choice = self.randint(6)
        
        if choice>=0 and choice<=2:         
            # Binary operation: (left op right)
            var left = self.generate(complexity - 1)
            var right = self.generate(complexity - 1)
            var op = self.ops[self.randint(len(self.ops))]
            return String(t"({left}{op}{right})")

        elif choice>=3 and choice<=4:       
            # Unary function: func(expr)
            var inner = self.generate(complexity - 1)
            var func = self.funcs[self.randint(len(self.funcs))]
            return String(t"{func}({inner})")
        elif choice==5:       
            # Function 'c': c(left, right)
            var left = self.generate(complexity - 1)
            var right = self.generate(complexity - 1)
            return String(t"c({left},{right})")
        else:            
            return ""
        
    
    def generateTerminal(mut self) -> String:
        var choice = self.randint(6)
        if choice>=0 and choice<=2:    return "z"
        elif choice==3:                return "i"
        elif choice>=4 and choice<=5:
            # Returns a random constant between 0.00 and 1.00 with 2 decimal places
            try:                
                var val = round(self.rand.rand_scalar[DType.float64](min = 0.0, max = 100.0), 2)
                return String(val)
            except:
                return ""
        else:
            return ""


def random_expression(complexity: Int) -> String:
    var e = ExpressionGenerator()
    return e.generate(complexity)

def main():
    print(random_expression(9))
    
    
    