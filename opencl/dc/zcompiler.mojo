# z expression compiler & run time VM

from std.complex import ComplexFloat32
from std.math import pi, floor
from cmath import I, c_exp, c_sin, c_cos, c_tan, c_log, c_log10, c_sqrt, c_asin, c_acos, c_atan, c_pow, c_abs


comptime Lowers_letters = "abcdefghijklmnopqrstuvwxyz_"
comptime Digits = "0123456789."


@fieldwise_init
struct Token(ImplicitlyCopyable, Equatable):
    var _value : UInt32

    comptime tk_snull = Token(0)
    comptime tk_number = Token(1)
    comptime tk_ident_i = Token(2)
    comptime tk_ident_z = Token(3)	
    comptime tk_plus = Token(4)
    comptime tk_minus = Token(5)
    comptime tk_mult = Token(6)
    comptime tk_div = Token(7)
    comptime tk_oparen = Token(8)
    comptime tk_cparen = Token(9)
    comptime tk_power = Token(10)	
    comptime tk_comma = Token(11)

	# funcs
    comptime tk_fsin = Token(12)
    comptime tk_fcos = Token(13)
    comptime tk_ftan = Token(14)
    comptime tk_fexp = Token(15)
    comptime tk_flog = Token(16)
    comptime tk_flog10 = Token(17)
    comptime tk_fint = Token(18)
    comptime tk_fsqrt = Token(19)
    comptime tk_fasin = Token(20)
    comptime tk_facos = Token(21)
    comptime tk_fatan = Token(22)
    comptime tk_fabs = Token(23)
    comptime tk_c = Token(24)

    # constants
    comptime tk_spi = Token(25)	

	# upcodes
    comptime tk_pushc = Token(26) 
    comptime tk_pushz = Token(27)
    comptime tk_pushi = Token(28)
    comptime tk_neg = Token(29)
    #
    comptime tk_end = Token(30)

    # 
    @always_inline
    def value(self) -> UInt32:
        return self._value
    
    @always_inline
    def __eq__(self, other: Token) -> Bool:
        return self._value == other._value
    
    @always_inline
    def __ne__(self, other: Token) -> Bool:
        return self._value != other._value

comptime func_tokens : List[Token]= [
                Token.tk_fsin,  Token.tk_fcos, Token.tk_ftan, Token.tk_fasin, Token.tk_facos,
                Token.tk_fatan, Token.tk_fexp, Token.tk_flog, Token.tk_flog10,
                Token.tk_fsqrt, Token.tk_c, Token.tk_fabs, Token.tk_fint
        ]

comptime _operators : Dict[String, Token]= {
                "+": Token.tk_plus,    "-": Token.tk_minus,
                "*": Token.tk_mult,    "/": Token.tk_div,
                "^": Token.tk_power,
                "(": Token.tk_oparen,  ")": Token.tk_cparen,
                ",": Token.tk_comma
            }

comptime token_mnemo : Dict[Int, String] = {
        Token.tk_snull.value(): "null",
        Token.tk_number.value(): "number",        
        Token.tk_ident_i.value(): "i",
        Token.tk_ident_z.value(): "z",
        Token.tk_plus.value(): "+",
        Token.tk_minus.value(): "-",
        Token.tk_mult.value(): "*",
        Token.tk_div.value(): "/",
        Token.tk_oparen.value(): "(",
        Token.tk_cparen.value(): ")",
        Token.tk_power.value(): "^",
        Token.tk_comma.value(): ",",

        # funcs
        Token.tk_fsin.value(): "sin",
        Token.tk_fcos.value(): "cos",
        Token.tk_ftan.value(): "tan",
        Token.tk_fexp.value(): "exp",
        Token.tk_flog.value(): "log",
        Token.tk_flog10.value(): "log10",
        Token.tk_fint.value(): "int",
        Token.tk_fsqrt.value(): "sqrt",
        Token.tk_fasin.value(): "asin",
        Token.tk_facos.value(): "acos",
        Token.tk_fatan.value(): "atan",
        Token.tk_fabs.value(): "abs",
        Token.tk_c.value(): "c",

        # constants
        Token.tk_spi.value(): "spi",
            
        Token.tk_pushc.value(): "pushc",
        Token.tk_pushz.value(): "pushz",
        Token.tk_pushi.value(): "pushi",
        Token.tk_neg.value(): "neg",
        Token.tk_end.value(): "end"
    }

##
@fieldwise_init
struct FuncMapping:
    var dict : Dict[String, Token]

    def __init__(out self): self.dict = {"sin": Token.tk_fsin, "cos": Token.tk_fcos, "tan": Token.tk_ftan, "exp": Token.tk_fexp, "log": Token.tk_flog, "log10": Token.tk_flog10, "int": Token.tk_fint, "sqrt": Token.tk_fsqrt, "asin": Token.tk_fasin, "acos": Token.tk_facos, "atan": Token.tk_fatan, "abs": Token.tk_fabs, "pi": Token.tk_spi, "c": Token.tk_c}
    def get_token(self, name: String) raises -> Token:  return self.dict[name]
    def get_value(self, name: String) raises -> Int:    return self.dict[name].value()

@fieldwise_init
struct ZCompiler:
    var expr : String    
    var ix : Int
    var sym : Token
    var ch : String
    var nval : Float32
    var id : String
    var consts : List[Float32]
    var err : Bool
    var err_msg : String
    var code : List[UInt32]

    var func_map : FuncMapping

    def __init__(out self, expr:String):
        
        self.expr = expr.lower()
        self.ix = 0
        self.sym = Token.tk_snull
        self.ch = ""
        self.nval = 0.0
        self.id = ""
        self.consts = []
        self.err = False
        self.err_msg = ""
        self.code = []

        self.func_map = FuncMapping()

        _ = self.getch()

        _=self.getsym()
        self.ce0()

        self.gen(Token.tk_end) # code ends with tk_end

    def has_errors(self) -> Bool : return self.err
    
    def gen(mut self, token: Token):
        self.code.append(UInt32(token.value()))
    
    def gen(mut self, token: Token, value: Float32):
        self.code.append(UInt32(token.value()))
        self.code.append(UInt32(len(self.consts)))
        self.consts.append(value)    
    
    def getch(mut self) -> String:        
        if self.ix < self.expr.byte_length():
            self.ch = chr(Int(self.expr.as_bytes()[self.ix]))
            self.ix += 1
        else:
            self.ch = ""
        # print(t"getch:{self.ch}: {self.ix},, {self.expr.byte_length()}")
        return self.ch

    def ungetch(mut self):
        self.ix -= 1
    
    def getsym(mut self) -> Token:
        self.sym = Token.tk_snull
        self.id = ""

        # skip blanks
        while self.ch != "" and self.ch <= " ": 
            _ = self.getch()           

        if self.ch >= "a" and self.ch <= "z":            
            while self.ch >= "a" and self.ch <= "z" or (self.ch >= "0" and self.ch <= "9"):
                self.id += self.ch
                _ = self.getch()

            if self.id == "z":
                self.sym = Token.tk_ident_z
                
            elif self.id == "i":
                self.sym = Token.tk_ident_i
            else:
                try:
                    self.sym = self.func_map.get_token(self.id)
                except:
                    self.err = True
                    self.err_msg = "unknown token: " + self.id + " at char: " + self.ch
                    _ = self.getch()
                
        elif self.ch >= "0" and self.ch <= "9":
            self.sym = Token.tk_number
            self.nval = 0.0
            while self.ch >= "0" and self.ch <= "9" or self.ch=='.':
                self.id += self.ch
                _ = self.getch()
            try:
                self.nval = Float32(Float64(self.id))
            except:
                self.err = True
                self.err_msg = "malformed number"
        else:
            
            var operators = materialize[_operators]()

            try:
                self.sym = operators[self.ch]            
            except:
                if self.ch == "": self.sym = Token.tk_snull
                else: 
                    self.sym = Token.tk_snull
                    self.err = True
                    self.err_msg = "unknown character: " + self.ch
          
            _=self.getch()

        # print("sym=", self.sym.value())

        return self.sym

    def ce0(mut self):
        if not self.err:
            self.ce1()

            while self.sym == Token.tk_plus or self.sym == Token.tk_minus:
                var _sym = self.sym

                _=self.getsym()
                self.ce1()
                self.gen(_sym)
   
    def ce1(mut self):
        if not self.err:
            self.ce2()

            while self.sym == Token.tk_mult or self.sym == Token.tk_div:
                var _sym = self.sym

                _=self.getsym()
                self.ce2()
                self.gen(_sym)

    def ce2(mut self):
        if not self.err:
            self.ce3()

            while self.sym == Token.tk_power:
                _=self.getsym()
                self.ce3()
                self.gen(Token.tk_power)
    
    def ce3(mut self):      
        var func_tokens = materialize[func_tokens]()

        if not self.err:
            if self.sym == Token.tk_oparen: # ()
                _=self.getsym()
                self.ce0()
                _=self.getsym()
            elif self.sym == Token.tk_number: # number
                self.gen(Token.tk_pushc, self.nval)
                _=self.getsym()
            elif self.sym == Token.tk_ident_z: # z
                self.gen(Token.tk_pushz)
                _=self.getsym()
            elif self.sym == Token.tk_ident_i: # i
                self.gen(Token.tk_pushi)
                _=self.getsym()
            elif self.sym == Token.tk_plus: # +
                _=self.getsym()
                self.ce3()
            elif self.sym == Token.tk_minus: # -
                _=self.getsym()
                self.ce3()
                self.gen(Token.tk_neg)

            elif self.sym == Token.tk_spi: # pi
                self.gen(Token.tk_pushc, pi)
                _=self.getsym()
            elif self.sym == Token.tk_c: # c
                _=self.getsym() # (
                _=self.getsym() # (
                self.ce3()
                _=self.getsym() # ,
                self.ce3()
                _=self.getsym() # )
                self.gen(Token.tk_c)

            
            elif self.sym in func_tokens: # functions
                var _sym = self.sym
                _=self.getsym()
                self.ce3()
                self.gen(_sym)
            else:
                self.err = True
                self.err_msg = "** unknown symbol : "
            
    @always_inline
    def evaluate(self, z : ComplexFloat32) -> ComplexFloat32:
        var stack = Array[ComplexFloat32, 64](uninitialized=True)
        var sp : Int = 0
        var pc : Int = 0

        while self.code[pc]!= UInt32(Token.tk_end.value()):
            var code = Token(Int(self.code[pc]))

            if code == Token.tk_pushc:
                stack[sp] = ComplexFloat32(self.consts[self.code[pc + 1]], 0.0)
                sp += 1
                pc += 2
            elif code == Token.tk_pushz:
                stack[sp] = z
                sp += 1
                pc += 1
            elif code == Token.tk_pushi:
                stack[sp] = ComplexFloat32(0.0, 1.0)
                sp += 1
                pc += 1
            elif code == Token.tk_neg:
                stack[sp - 1] = -stack[sp - 1]
                pc += 1
            elif code == Token.tk_plus:
                stack[sp - 2] = stack[sp - 2] + stack[sp - 1]
                sp -= 1
                pc += 1
            elif code == Token.tk_minus:
                stack[sp - 2] = stack[sp - 2] - stack[sp - 1]
                sp -= 1
                pc += 1
            elif code == Token.tk_mult:
                stack[sp - 2] = stack[sp - 2] * stack[sp - 1]
                sp -= 1
                pc += 1
            elif code == Token.tk_div:
                stack[sp - 2] = stack[sp - 2] / stack[sp - 1]
                sp -= 1
                pc += 1
            elif code == Token.tk_power:
                stack[sp - 2] = c_pow(stack[sp - 2], stack[sp - 1])
                sp -= 1
                pc += 1
            elif code == Token.tk_fexp:
                stack[sp - 1] = c_exp(stack[sp - 1])
                pc += 1
            elif code == Token.tk_fsin:
                stack[sp - 1] = c_sin(stack[sp - 1])
                pc += 1
            elif code == Token.tk_fcos:
                stack[sp - 1] = c_cos(stack[sp - 1])
                pc += 1
            elif code == Token.tk_ftan:
                stack[sp - 1] = c_tan(stack[sp - 1])
                pc += 1
            elif code == Token.tk_flog:
                stack[sp - 1] = c_log(stack[sp - 1])
                pc += 1
            elif code == Token.tk_flog10:
                stack[sp - 1] = c_log10(stack[sp - 1])
                pc += 1
            elif code == Token.tk_fsqrt:
                stack[sp - 1] = c_sqrt(stack[sp - 1])
                pc += 1
            elif code == Token.tk_fasin:
                stack[sp - 1] = c_asin(stack[sp - 1])
                pc += 1
            elif code == Token.tk_facos:
                stack[sp - 1] = c_acos(stack[sp - 1])
                pc += 1
            elif code == Token.tk_fatan:
                stack[sp - 1] = c_atan(stack[sp - 1])
                pc += 1
            elif code == Token.tk_fabs:
                stack[sp - 1] = ComplexFloat32(c_abs(stack[sp - 1]), 0.0)
                pc += 1
            elif code == Token.tk_fint:
                stack[sp - 1] = ComplexFloat32(floor(stack[sp - 1].re), floor(stack[sp - 1].im))
                pc += 1
            elif code == Token.tk_c:
                sp -= 1
                stack[sp - 1] = ComplexFloat32(stack[sp - 1].re, stack[sp].im)
                pc += 1
            else:
                print("evaluate: unknown token:", self.code[pc])
                pc += 1
                break
        return stack[0]

##  
def main():
    from expr_gen import ExpressionGenerator
    
    var gen = ExpressionGenerator()
    var expr = gen.generate(5)
    print("generated:", expr)
    
    var c = ZCompiler(expr)
    print("code:", c.code)
    print("consts:", c.consts)
    print("err:", c.err)
    print("err_msg:", c.err_msg)
    
    var token_mnemo_copy = materialize[token_mnemo]()
    for cd in c.code:
        try:
            print(token_mnemo_copy[Int(cd)], end=",")
        except:
            print("unknown token:", cd)
    print()
    
    var ev = c.evaluate(ComplexFloat32(1.0, 0.0))
    print("result:", ev)
    